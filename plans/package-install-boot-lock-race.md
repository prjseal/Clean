# Package install boot failure: SQLite lock race after the package migration

Findings from 2026-11-13 and the plan for the next session. Branch: `feature/v19-native-rebuild`
(Clean 19.0.0-rc02 on Umbraco 19.0.0-rc1, PR #509).

## The problem

A fresh Umbraco 19.0.0-rc1 site that installs the `Clean` package sometimes fails to boot. Every
request then returns:

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

The lock id varies between failures: -348 (`DocumentUrlAliasRepository`, URL aliases) on CI, and
-345 (`DocumentUrlRepository.Save`, document URLs) in the local repro. Both fail at the same point:
the cache refresh `UnattendedUpgrader.RunPackageMigrationsAsync` runs after the package migration.

Where it has been seen:

- PR #509 CI run 43405050136 (build 19.0.0-ci.b0000366, commit `08fb7c4`): the home page
  screenshot in the PR comment is the boot failure page. This was before the reusable-blocks work
  (work item A), so `IndexExternalBlockElements` is not the cause.
- PR #509 CI run 43472036481 (build 19.0.0-ci.b0000367, commit `ea1448b`) booted and passed.
- Locally, one run of `Test-PackageInstallation.ps1` failed (lock -345). The two before it passed.

It is intermittent. It needs the boot to be slow, as on a CI runner or a busy machine.

## What was done already

Commit `99bd925` (local, not pushed when this was written): the Playwright test fails straight away
when the home page shows a `BootFailedException` or returns HTTP 5xx; `Test-PackageInstallation.ps1`
and `Test-TemplateInstallation.ps1` print the Umbraco log's warnings and errors when the tests
fail; `pr-build-packages.yml` uploads `site.log`, `site.err` and the Umbraco logs as the
`package-test-logs-<version>` and `template-test-logs-<version>` artifacts.

## Cause

Two pieces of Umbraco work overlap during the first boot:

1. **The URL rebuild.** After the package migration, `UnattendedUpgrader.RunPackageMigrationsAsync`
   calls `RefreshAllPublishedSnapshot`. `ContentCacheRefresher.HandleRouting` then runs
   `DocumentUrlService.RebuildAllUrlsAsync` (and `DocumentUrlAliasService.RebuildAllAliasesAsync`)
   on the upgrade thread. In one scope it takes a read lock on -333 first, then asks for a write
   lock (-345 for URLs, -348 for aliases).
2. **Umbraco Search indexing.** `PostMigrationNotificationHandler` (in
   `template/Clean/Migrations/PostMigrationNotification.cs`) publishes the Library elements and the
   Home branch while handling `MigrationPlansExecutedNotification`. Those publishes queue
   background indexing in Umbraco Search, which runs on another thread.

If the indexing starts while the URL rebuild is in progress, the rebuild never gets its write
lock. It waits for the full write-lock timeout (5 seconds by default), throws
`DistributedWriteLockTimeoutException`, and the boot fails.

Evidence from the failing local run (Debug logging on `SqliteDistributedLockingMechanism` and
Umbraco Search; T14 is the upgrade thread, T16 the indexing thread):

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

In every successful run, indexing starts 0.35 to 0.43 seconds after the URL rebuild started and
after it has finished, so they never overlap:

| Run | URL rebuild started | First indexing | Result |
|---|---|---|---|
| ok-first | 17:56:54.731 | 17:56:55.112 | ok |
| run 3 | 18:10:05.465 | 18:10:05.893 | ok |
| run 9 | 18:12:12.973 | 18:12:13.331 | ok |
| run 10 | 18:12:43.927 | 18:12:44.147 (during the rebuild) | **failed** |

**Why the rebuild waits the whole 5 seconds, not confirmed.** The indexing thread is done within
70 ms, yet the rebuild keeps failing until its timeout. That fits SQLite's WAL behaviour
(`SQLITE_BUSY_SNAPSHOT`): a transaction that has started reading cannot upgrade to a write once
another connection has committed a write after its read began, so every retry fails until the
timeout. The indexing thread's write (Umbraco Search saving its index document snapshots) takes no
Umbraco write lock, so it does not show in the lock log. The SQLite error code was not logged, so
this part is a likely explanation, not a proven one. Raising the write-lock timeout would not help
if it is right.

Ruled out:

- The startup index rebuild (`IndexRebuildJob`): it starts 2 minutes after startup.
- `TouchServerJob` and the other recurring jobs: they start 15 seconds or more after startup, after
  the failure.
- `IndexExternalBlockElements` (work item A): CI run 366 failed without it.

## How to reproduce it

Without load, 0 failures in 11 installs. With disk load during the boot, 1 failure in 10.

1. Build the packages: `.github/workflows/powershell/CreateNuGetPackages.ps1 -Version 19.0.0-rc02`
   (writes `.artifacts/nuget`). If the global NuGet cache already has `Clean*` 19.0.0-rc02, delete
   `~/.nuget/packages/clean*/19.0.0-rc02` first, or the old build is used.
2. Outside the repo (for example in the session scratchpad):

   ```bash
   dotnet new umbraco --force -n ReproSite --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
   dotnet add ReproSite package Clean --version 19.0.0-rc02 --source "D:/Code/GitHub/Clean/.artifacts/nuget"
   ```

3. Add Debug logging to `ReproSite/appsettings.Development.json` under `Serilog:MinimumLevel`:

   ```json
   "Override": {
     "Umbraco.Cms.Core.Scoping": "Debug",
     "Umbraco.Cms.Infrastructure.Scoping": "Debug",
     "Umbraco.Cms.Persistence.Sqlite": "Debug",
     "Umbraco.Cms.Core.DistributedLocking": "Debug",
     "Umbraco.Cms.Search": "Debug",
     "Umbraco.Cms.Core.Search": "Debug",
     "Umbraco.Cms.Search.Provider.Examine": "Debug"
   }
   ```

4. `dotnet build ReproSite`, then run this loop next to `ReproSite` (Git Bash). Each run deletes the
   database, boots the site while copying a large folder in the background, and keeps the log in
   `runs/`. It stops at the first failure.

   ```bash
   #!/usr/bin/env bash
   # Usage: loop.sh <max runs>
   R="$(cd "$(dirname "$0")" && pwd)"
   cd "$R"
   max="${1:-10}"
   mkdir -p runs; rm -f runs/run*
   for i in $(seq 1 "$max"); do
     taskkill //F //IM ReproSite.exe >/dev/null 2>&1
     sleep 2
     rm -rf ReproSite/umbraco/Data ReproSite/umbraco/Logs
     ( for k in 1 2 3; do cp -r ~/.nuget/packages/umbraco.cms.staticassets/19.0.0-rc1 "$R/stress$k" && rm -rf "$R/stress$k"; done ) &
     dotnet run --no-build --project ReproSite > "runs/run$i.out" 2>&1 &
     outcome="timeout"
     for t in $(seq 1 120); do
       log=$(ls ReproSite/umbraco/Logs/UmbracoTraceLog*.json 2>/dev/null | head -1)
       if [ -n "$log" ]; then
         if grep -q 'Unattended upgrade failed' "$log"; then outcome="FAILED"; break; fi
         if grep -q '"nodeName":"Home"' "$log" && grep -q 'Now listening' "runs/run$i.out"; then
           sleep 10
           if grep -q 'Unattended upgrade failed' "$log"; then outcome="FAILED"; else outcome="ok"; fi
           break
         fi
       fi
       sleep 2
     done
     [ -n "$log" ] && cp "$log" "runs/run$i.json"
     echo "run $i: $outcome"
     taskkill //F //IM ReproSite.exe >/dev/null 2>&1
     [ "$outcome" = "FAILED" ] && break
   done
   ```

5. To read a log as a timeline (Node.js; usage `node timeline.mjs runs/run10.json [from] [to]`,
   times as `HH:MM:SS.mmm`):

   ```js
   import fs from 'node:fs';
   const [file, from = '', to = '99'] = process.argv.slice(2);
   for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
     if (!line.trim()) continue;
     let e; try { e = JSON.parse(line); } catch { continue; }
     const t = e['@t'].slice(11, 23);
     if (t < from || t > to) continue;
     const msg = e['@mt'].replace(/\{@?(\w+)(:[^}]*)?\}/g, (m, k) => (e[k] !== undefined ? e[k] : m));
     if (/^(Create (table|Index)|New table|Creating data|Completed creating data)/.test(msg)) continue;
     const src = (e.SourceContext || '').split('.').pop();
     console.log(`${t} T${String(e.ThreadId).padEnd(3)} ${(e['@l'] || 'Info').padEnd(7)} ${src}: ${msg.slice(0, 170).replace(/\s+/g, ' ')}`);
   }
   ```

## Plan for the next session

### 0. Branch

All of this is on `feature/v19-native-rebuild`, the Clean 19.0.0-rc02 branch, like the other
Umbraco 19 work items (see `plans/umbraco-19-feature-adoption.md`, "Work items"). Commit straight
onto it. Do not create a feature branch, a second PR or a merge: the commits become part of the
branch's existing PR #509 (into `dev/v19`) when it is pushed.

```
git checkout feature/v19-native-rebuild
git pull
```

### 1. Draft the Umbraco issue

Write the issue text to `plans/umbraco-issue-sqlite-url-rebuild-lock-race.md`, ready for Paul to
file on `umbraco/Umbraco-CMS`. Do not file it. Include:

- Title along the lines of "SQLite: first boot after a package migration fails with
  DistributedWriteLockTimeoutException when Umbraco Search indexing overlaps the URL rebuild".
- Versions: Umbraco 19.0.0-rc1, .NET 11, SQLite, Umbraco Search with the Examine provider.
- The stack trace, the failing-run timeline and the run table from "Cause" above.
- Minimal steps: a package whose migration publishes content in a
  `MigrationPlansExecutedNotification` handler, installed unattended on a fresh SQLite site with
  the machine under disk load. Point at the Clean package as a real example.
- What is proven (the overlap and the timing) and what is likely but unproven
  (`SQLITE_BUSY_SNAPSHOT`), kept separate.
- Suggestions, marked as suggestions: take the URL/alias write lock before the first read in the
  rebuild scope, or keep Umbraco Search's background writes from running while the runtime is
  still upgrading.

### 2. Known issue in the CHANGELOG and the tracker

- `CHANGELOG.md`, existing `[19.0.0-rc02]` entry, `### Known issues`: one line saying that on
  SQLite the first boot after installing the `Clean` package can fail with "Failed to acquire write
  lock" on a slow machine, because Umbraco Search indexing overlaps Umbraco's URL rebuild; restart
  the site to finish the boot. Match the entry's style and do not start a new version. If step 3
  below fixes it, change or remove this line in that step.
- `plans/umbraco-19-feature-adoption.md`: add a row to the Platform table (or a short note under the
  Search table) for the issue, linking this file, with status "Known issue, Umbraco rc1".
- Before writing "restart the site": check it on the repro. After a failed boot, run the site again
  without deleting the database and confirm it boots, the pages render and Home is published. If it
  does not, describe what does work instead.

Commit steps 1 and 2 separately, author `Paul Seal <prjseal@gmail.com>`, no assistant attribution.

### 3. Try a Clean-side workaround

Goal: Clean's package install never triggers Umbraco Search indexing while the post-migration URL
rebuild runs. Change only `template/Clean/Migrations/PostMigrationNotification.cs` (and its
registration in `template/Clean`, if needed).

Approaches to evaluate, in order:

1. **Publish after the upgrade instead of during it.** Record that the Clean migration ran (in
   `HandleAsync`), and do the element publishing and `PublishBranch` later, once the unattended
   upgrade has finished and the URL rebuild is done. Check how to detect that point reliably: the
   site logs "Now listening" and can raise `UmbracoApplicationStartedNotification` before the
   background unattended upgrade has finished, so that notification alone is probably not enough.
   Look in Umbraco 19.0.0-rc1 (`Umbraco.Core.xml` in the NuGet cache, and the
   `UnattendedUpgradeBackgroundService` behaviour) for a notification or runtime-state check
   that fires after "Unattended upgrade completed successfully". Do not add a fixed delay.
2. **Keep publishing where it is, but stop it from indexing during the upgrade**, then rebuild or
   refresh the published content index once the boot is complete. Only if approach 1 does not work.

Whatever is chosen:

- The installed site must still publish Home, the categories and the Library block, keep the
  reusable block references, and render (the same checks as work item A in
  `plans/umbraco-19-feature-adoption.md`).
- Prove it with the repro loop under disk load: at least 30 runs with no failure, against the
  baseline of about 1 in 10. Record the numbers.
- Then run `dotnet build template/Clean.sln` and `template-pack.sln` (0 warnings, 0 errors),
  `CreateNuGetPackages.ps1 -Version 19.0.0-rc02` (clear the NuGet cache entries first),
  `Test-PackageInstallation.ps1` and `Test-TemplateInstallation.ps1`.
- If it works: commit it separately, update this file with what was done, and update the
  CHANGELOG known issue from step 2 (remove it, or move it to Fixed).
- If no approach works within reason: do not commit a partial change. Write down what was tried and
  why it failed in this file.

### Done

- Step 1: the issue draft is in `plans/`, not filed.
- Step 2: CHANGELOG and tracker updated and committed.
- Step 3: either a committed fix proven by the loop (30+ runs, no failure) and both install tests,
  or a written record of what was tried.
- Nothing pushed. Tell Paul the push command at the end.
