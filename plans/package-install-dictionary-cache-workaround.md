# Package install: dictionary values are blank until the site restarts

Findings from 2026-11-14 and the plan for the next session. Base branch: `dev/v19`. Found while
testing the published Clean 19.0.0-rc02 package from NuGet on Umbraco 19.0.0-rc1.

## The problem

On a fresh site that installs the `Clean` NuGet package, every dictionary value renders blank on
the front end until the site restarts:

- the contact form labels and the Send button are empty
- the pagination "Next" and "Prev" links are empty
- "Posted by … on" is missing from the article dates, so they read "Paul Seal June 25, 2026"
- the footer reads "© 2026" instead of "Copyright © 2026 Clean Starter Kit"
- the site name is missing from the navbar and from page titles ("Home |" instead of
  "Home | Clean Starter Kit")

The template install (`dotnet new umbraco-starter-clean`) isn't affected: it imports with uSync,
not the package migration. The PR build doesn't catch the bug, because
`Write-PlaywrightTestScript.ps1` checks no dictionary text.

## Findings

The full write-up, with the minimal repro, is
`umbraco-bugs/package-migration-dictionary-items-stale-cache.md`. In short:

- It's Umbraco's bug. A fresh `dotnet new umbraco` 19.0.0-rc1 site with only a package migration
  that imports one dictionary item has the same problem. Clean's migration uses Umbraco's stock
  `ImportPackage.FromEmbeddedResource(GetType()).Do()`.
- After the import, the rows are in `cmsDictionary` and `cmsLanguageText`. `IDictionaryItemService.GetDescendantsAsync`
  finds the item, but `IDictionaryItemService.GetAsync(key)` returns `null` and the culture
  dictionary returns an empty string.
- It doesn't recover over time (still blank 16 minutes after boot) or from opening the dictionary
  in the backoffice. A restart fixes it.
- Tested in the repro, on fresh installs, with these steps in Umbraco notification handlers:

  | Step | Where | Fixed? |
  |---|---|---|
  | `DistributedCache.RefreshAll(DictionaryCacheRefresher.UniqueId)` | `MigrationPlansExecutedNotification` | No |
  | `DistributedCache.RefreshAll(DictionaryCacheRefresher.UniqueId)` | `UmbracoApplicationStartedNotification` | No |
  | `AppCaches.RuntimeCache.Clear()` | `UmbracoApplicationStartedNotification` | No |
  | `AppCaches.IsolatedCaches.ClearAllCaches()` | `UmbracoApplicationStartedNotification` | Yes |
  | `AppCaches.IsolatedCaches.ClearCache<IDictionaryItem>()` | `UmbracoApplicationStartedNotification` | Yes |

  The repro is in the 2026-11-14 session scratchpad, which won't survive. The table is the record.

## Decisions

- **Workaround:** clear the dictionary item isolated cache,
  `AppCaches.IsolatedCaches.ClearCache<IDictionaryItem>()`, in `PostMigrationNotificationHandler`
  at the start of `PublishPackageContentAsync()`. During an unattended install that method already
  runs from `UmbracoApplicationStartedNotification`, which is where the clear was proven to work.
  (Update, 2026-11-24: with Umbraco 19.0.0-rc2 the deferred publishing was removed, see
  `plans/package-install-boot-lock-race.md` step 5. The clear now runs in the
  `MigrationPlansExecutedNotification` handler, and both install tests' Send button check passed.)
  Don't use `DistributedCache.RefreshAll(DictionaryCacheRefresher.UniqueId)`: it was proven not to
  work.
- **Regression check:** the Playwright test fails when the contact page's Send button has no
  text. Both the package and the template tests use this script, so a blank dictionary on a fresh
  install fails the PR build.
- **The bug file** gets "Clean workaround: Yes", pointing at the handler. Remove the workaround
  when Umbraco fixes the bug.
- **CHANGELOG:** 19.0.0-rc02 is already on NuGet, so the fix goes in the next release's entry.
  None exists yet, so add `## [Unreleased]` above `## [19.0.0-rc02]`.

## Implementation

### 1. Branch

```bash
git checkout dev/v19
git pull
git checkout -b bugfix/v19/package-install-dictionary-cache
```

There's no `develop` in this repo. The v19 work merges into `dev/v19`. The bug write-up, its
README row and this plan were written on another branch and aren't committed. They carry over to
the new branch as uncommitted changes; commit them with this work.

PR #511 (`bugfix/v19/510-contact-missing-model-issue`) is open against `dev/v19`. It touches
`ContactViewComponent.cs` and the contact views, not the files below, so this work doesn't depend
on it. If both add CHANGELOG lines, the second to merge resolves the conflict.

### 2. Clear the cache in the package migration handler

`template/Clean/Migrations/PostMigrationNotification.cs`:

- Inject `AppCaches` (`Umbraco.Cms.Core.Cache`).
- At the start of `PublishPackageContentAsync()`, call
  `_appCaches.IsolatedCaches.ClearCache<IDictionaryItem>()` and log it at Information level, for
  example "Cleared the dictionary cache after the Clean package import".
- Add a comment: the package import leaves the dictionary items it creates missing from the
  by-key lookups until the cache is cleared or the site restarts, which is an Umbraco bug. Point
  at `umbraco-bugs/package-migration-dictionary-items-stale-cache.md`, and say to remove the
  workaround once Umbraco fixes it.

No schema change, so no Models Builder regeneration.

### 3. Add the regression check

`.github/workflows/powershell/Write-PlaywrightTestScript.ps1`, in the generated script, straight
after the home page's boot check:

- Go to `baseUrl + '/contact/'` and read the trimmed text of `#submitButton`.
- If it's empty, throw an error like "The contact page's Send button has no text: the dictionary
  values did not render", which fails the test with exit code 1.
- Log the button text when the check passes.

`Test-LatestNuGetPackages.ps1` uses the same script, so it will fail for the published
19.0.0-rc02 until a fixed version is released. That's expected; say so in the PR description.

### 4. Build and test locally

Follow `CLAUDE.md`, "Test the package and template installs locally", with a version that won't
clash with a real release, for example `19.0.0-local.2`:

1. Clear `~/.nuget/packages/clean/19.0.0-local.2`, `clean.core/19.0.0-local.2` and
   `clean.headless/19.0.0-local.2`.
2. `CreateNuGetPackages.ps1 -Version 19.0.0-local.2`. Restore `template/Clean/Migrations/package.zip`
   if only its `updateDate` or writer name changed.
3. Run `Test-PackageInstallation.ps1` and `Test-TemplateInstallation.ps1` with that version.
   Both must exit 0, so the new check passes on both.
4. Check the package site's Umbraco log as `CLAUDE.md` describes: 8 elements `Success`, 17 pages
   `SuccessPublish`, no `"@l":"Error"`, and the new "Cleared the dictionary cache" line.
5. Look at the contact page screenshot: Name, Email Address, Message and SEND are all there.
6. Prove the check catches the bug: comment out the cache clear, rebuild the packages (clear the
   NuGet cache again first), run `Test-PackageInstallation.ps1`, and see it fail on the new check.
   Then restore the clear.
7. Delete `test-installation/` and `test-template-TestTemplateProject/` and the
   `19.0.0-local.2` NuGet cache folders.

### 5. Optional: the non-unattended path

When package migrations don't run unattended, an admin runs them from Packages > Installed while
the site is running. Then `PublishPackageContentAsync()` runs straight from
`MigrationPlansExecutedNotification`, and it isn't known whether the clear works at that point.
If there's time, check it:

1. On a fresh package test site, set `Umbraco:CMS:Unattended:PackageMigrationsUnattended` to
   `false`.
2. Boot the site, run the pending Clean migration from the backoffice, and check the contact page
   labels without restarting.

Record the result in this plan. If the labels are blank there, note it in the bug file and the
PR, and don't widen the workaround in this branch.

### 6. CHANGELOG and bug file

- `CHANGELOG.md`: add `## [Unreleased]` above `## [19.0.0-rc02]` with a `### Fixed` line, for example
  "A fresh install of the `Clean` package shows its dictionary text (form labels, button text,
  paging links, the site name) on first boot. The package install clears Umbraco's dictionary
  cache, which Umbraco leaves stale after a package import until the site restarts".
- `umbraco-bugs/package-migration-dictionary-items-stale-cache.md`: set "Clean workaround" to
  "Yes, `template/Clean/Migrations/PostMigrationNotification.cs`". In `umbraco-bugs/README.md`,
  set the row's Clean workaround to "Yes".

### 7. Commit

Commit as `Paul Seal <prjseal@gmail.com>`. The message describes only what's in the commit. Don't
push; Paul pushes and opens the PR against `dev/v19`.

## Out of scope

- Filing the Umbraco issue. Paul does that from the bug file.
- The Codegarden 2026 article's YouTube `maxresdefault.jpg` thumbnails return 404 for all 8
  videos. The fallback image shows, so the page looks right, but the browser console shows 8
  errors.

## Implementation results (2026-11-14)

Tested locally with version `19.0.0-local.2`.

- `Test-PackageInstallation.ps1`: exit 0. Log: 8 elements `Success`, 17 pages `SuccessPublish`, no
  `"@l":"Error"` entries, and "Cleared the dictionary cache after the Clean package import". The
  contact page screenshot shows Name, Email Address, Message and SEND, and the footer reads
  "Copyright © 2026 Clean Starter Kit".
- `Test-TemplateInstallation.ps1`: exit 0 on the second run. The first run failed on the home page
  request (`page.goto` timed out after 30 seconds) while the fresh site was still cold-booting,
  before the new check ran. The rerun passed, with the Send button text logged as `Send`.
- With the cache clear commented out, `Test-PackageInstallation.ps1` exits 1 with "The contact
  page's Send button has no text: the dictionary values did not render". The clear was then
  restored.
- Step 5 (migrations run from the backoffice with `PackageMigrationsUnattended` false) was **not
  done**. It is still not known whether the clear works on that path.
- The test folders and the `19.0.0-local.2` NuGet cache folders are deleted.
