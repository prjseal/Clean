# Draft issue for umbraco/Umbraco-CMS

Not filed. Paul files it on GitHub. Everything below the line is the issue text.

---

## Title

SQLite: first boot after a package migration fails with DistributedWriteLockTimeoutException when Umbraco Search indexing overlaps the URL rebuild

## Which Umbraco version are you using?

19.0.0-rc1

## Bug summary

On a fresh SQLite site, an unattended package migration that publishes content can make the first
boot fail. After the package migration, `UnattendedUpgrader.RunPackageMigrationsAsync` refreshes
the published snapshot, and `ContentCacheRefresher.HandleRouting` rebuilds all document URLs (or URL
aliases) on the upgrade thread. The publishes in the package's migration handler have queued
Umbraco Search indexing on a background thread. When that indexing starts while the URL rebuild is
running, the rebuild cannot get its write lock, times out after 5 seconds, and the boot fails:

```
BootFailedException: Boot failed: Umbraco cannot run. See Umbraco's log file for more details.
-> Umbraco.Cms.Core.Exceptions.BootFailedException: Failed to acquire write lock for id: -348.
-> Umbraco.Cms.Core.DistributedLocking.Exceptions.DistributedWriteLockTimeoutException: Failed to acquire write lock for id: -348.
   at ...SqliteDistributedLockingMechanism.SqliteDistributedLock.ObtainWriteLock()
   ...
   at Umbraco.Cms.Infrastructure.Persistence.Repositories.Implement.DocumentUrlAliasRepository.DeleteAll()
   at Umbraco.Cms.Core.Services.DocumentUrlAliasService.RebuildAllAliasesAsync()
   at Umbraco.Cms.Core.Cache.ContentCacheRefresher.HandleRouting(JsonPayload payload)
   ...
   at Umbraco.Extensions.DistributedCacheExtensions.RefreshAllPublishedSnapshot(DistributedCache dc)
   at Umbraco.Cms.Infrastructure.Install.UnattendedUpgrader.RunPackageMigrationsAsync(RuntimeUnattendedUpgradeNotification notification)
```

The lock id varies: -348 (`DocumentUrlAliasRepository.DeleteAll`, URL aliases) on a GitHub Actions
runner, and -345 (`DocumentUrlRepository.Save`, document URLs) in a local repro. Both fail in the
same place, the cache refresh after the package migration. Every request then returns the boot
failure page.

It is intermittent and needs a slow boot (a CI runner, or a local machine under disk load).

## Specifics

- Umbraco 19.0.0-rc1, .NET 11, Windows 11 and the GitHub Actions Windows runner
- SQLite (`--development-database-type SQLite`), unattended install and unattended package migrations
- Umbraco Search with the Examine provider (the default)
- Real example: the [Clean starter kit](https://github.com/prjseal/Clean) package, 19.0.0-rc02.
  Its `MigrationPlansExecutedNotification` handler
  ([`PostMigrationNotification.cs`](https://github.com/prjseal/Clean/blob/ea1448b/template/Clean/Migrations/PostMigrationNotification.cs))
  publishes 8 Library elements with `IElementPublishingService` and then the Home branch (17
  pages) with `IContentService.PublishBranch`.

### What is proven

The two pieces of work overlap in every failing run and never in a passing one.

Timeline of a failing local run, with Debug logging on `SqliteDistributedLockingMechanism` and
Umbraco Search (T14 is the upgrade thread, T16 the Umbraco Search indexing thread):

```
18:12:41.757 T14  Package migration completed for Clean (4448ms)
18:12:42-43  T14  publishes the 8 Library elements and the 17 pages (write locks -349, -351, -333)
18:12:43.926 T14  DocumentUrlService: Rebuilding all document URLs.
18:12:43.930 T14  Acquired ReadLock for id -333
18:12:43.937 T14  Requesting WriteLock for id -345
18:12:44.104 T16  Acquired ReadLock for id -333        <- Umbraco Search indexing starts
18:12:44.147 T16  PropertyValueFieldsContentIndexer ...
18:12:44.168 T16  Dropped ReadLock for id -349        <- indexing finished
18:12:48.992 T14  Dropped ReadLock for id -333
18:12:48.996 T14  Unattended upgrade failed. Failed to acquire write lock for id: -345.
```

In the passing runs, indexing starts 0.35 to 0.43 seconds after the URL rebuild starts, once the
rebuild has finished:

| Run | URL rebuild started | First indexing | Result |
|---|---|---|---|
| 1 | 17:56:54.731 | 17:56:55.112 | ok |
| 3 | 18:10:05.465 | 18:10:05.893 | ok |
| 9 | 18:12:12.973 | 18:12:13.331 | ok |
| 10 | 18:12:43.927 | 18:12:44.147 (during the rebuild) | **failed** |

Without disk load, 11 installs in a row booted. With disk load during the boot, about 1 in 10
failed.

Ruled out as the other party: the startup index rebuild (`IndexRebuildJob`, starts 2 minutes
after startup), and `TouchServerJob` and the other recurring jobs (they start 15 seconds or more
after startup, after the failure).

### What is likely but not proven

The indexing thread is finished within about 70 ms, yet the rebuild keeps failing to get its write
lock until the full 5-second timeout. That fits SQLite's WAL behaviour (`SQLITE_BUSY_SNAPSHOT`):
the rebuild's scope takes a read lock on -333 and reads first, then asks for the write lock on -345
or -348. A transaction that has started reading cannot be upgraded to a write once another
connection has committed a write after its read began, so every retry fails until the timeout.
The indexing thread's write (Umbraco Search saving its index document snapshots) takes no Umbraco
distributed write lock, so it does not appear in the lock log. The SQLite error code was not
logged, so this is an explanation that fits, not a confirmed one. If it is right, raising
`Umbraco:CMS:Global:DistributedLockingWriteLockDefaultTimeout` would not help.

## Steps to reproduce

1. Create a package whose migration imports content, with a `MigrationPlansExecutedNotification`
   handler that publishes it (the Clean package does this: `dotnet add package Clean --version
   19.0.0-rc02`).
2. Create a fresh SQLite site and add the package:

   ```bash
   dotnet new umbraco -n ReproSite --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
   dotnet add ReproSite package Clean --version 19.0.0-rc02
   dotnet build ReproSite
   ```

3. Put the machine under disk load (for example, copy a large folder in a loop) and run the site
   with `dotnet run --no-build --project ReproSite`.
4. Delete `ReproSite/umbraco/Data` and repeat step 3 until a boot fails (about 1 run in 10 here).
   Debug logging on `Umbraco.Cms.Core.DistributedLocking`, `Umbraco.Cms.Persistence.Sqlite` and
   `Umbraco.Cms.Search` shows the overlap above.

## Expected result / actual result

Expected: the first boot completes and the package's published content is routable.

Actual: the unattended upgrade fails with `DistributedWriteLockTimeoutException` and the site
returns `BootFailedException` on every request until it is restarted.

Restarting the site on the same database recovers it: the package migration is not run again, the
URLs are rebuilt at startup, and the package's content is published and renders.

## Suggestions

These are only suggestions; the maintainers will know the better place for a fix.

- In the URL and URL alias rebuild, take the write lock (-345 or -348) before the first read in
  the scope, so the scope never needs to upgrade a read transaction to a write on SQLite.
- Or keep Umbraco Search's background index writes from running while the runtime is still
  upgrading (for example, queue them until the unattended upgrade has finished).
