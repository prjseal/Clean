# Clean Starter Kit

## Log Umbraco bugs in `umbraco-bugs/`

When work on Clean turns up a bug in Umbraco CMS or one of its packages (Umbraco Search, uSync,
the templates), write it up in `umbraco-bugs/` so it can be raised on GitHub later. Do not file
it yourself; Paul does that.

- One markdown file per bug, named after the bug in kebab-case, e.g.
  `umbraco-bugs/sqlite-url-rebuild-lock-race.md`. Write it there, not in `plans/`.
- Start the file with a short header: status ("Not filed", "Filed: <issue link>" or
  "Fixed in <version>"), target repository, the date found with the Umbraco and Clean versions,
  whether Clean has a workaround (and where), and any background plan in `plans/`.
- Below that, the issue text ready to paste: title, version, bug summary, specifics, steps to
  reproduce, expected and actual result, and any suggestions marked as suggestions. Keep what is
  proven separate from what is likely but unproven.
- Add a row for it to the table in `umbraco-bugs/README.md`, and keep its status there in step
  with the file.

## Test the package and template installs locally

Run these after any change to the `Clean` package's install path (`template/Clean`, the embedded
`package.zip`, the migrations) or to the template. They are the same tests the PR build runs.
The scripts are in `.github/workflows/powershell/`, documented in
`.github/script-create-nuget-packages.md`, `.github/script-test-package-installation.md` and
`.github/script-test-template-installation.md`. Run them with the PowerShell tool from the repo
root, and send their output to a file in the scratchpad: they print a lot and take a few minutes.

1. **Clear the NuGet cache for the version.** NuGet uses the global packages cache before
   `.artifacts/nuget`, so an earlier build under the same version would be installed instead.
   Delete `~/.nuget/packages/clean/<version>`, `clean.core/<version>` and
   `clean.headless/<version>`.
2. **Build the packages:**
   `.github/workflows/powershell/CreateNuGetPackages.ps1 -Version <version>` (for example
   `19.0.0-rc02`). It runs Clean.Blog to export the package and writes the `.nupkg` files to
   `.artifacts/nuget`. Two things to expect:
   - It rewrites `template/Clean/Migrations/package.zip` from the local Clean.Blog database. If the
     only difference is an `updateDate` or writer name, restore it with
     `git checkout -- template/Clean/Migrations/package.zip`. Commit a regenerated `package.zip`
     only when the content or schema changed on purpose.
   - It can exit with code 1 from "Unable to find any package source(s) matching name:
     CleanLocalPackages" at the end. That is harmless if it listed the four generated packages.
3. **Run the tests:**
   - `.github/workflows/powershell/Test-PackageInstallation.ps1 -Version <version> -WorkspacePath D:\Code\GitHub\Clean`
   - `.github/workflows/powershell/Test-TemplateInstallation.ps1 -Version <version> -WorkspacePath D:\Code\GitHub\Clean`

   Exit code 0 is a pass. Each creates a site in the repo root (`test-installation/` and
   `test-template-TestTemplateProject/`, both in `.gitignore`), installs Playwright with npm, and
   saves screenshots in its `screenshots/` folder.
4. **Check the result, not just the exit code.** For the package test, the site's Umbraco log
   (`test-installation/TestProject/umbraco/Logs/UmbracoTraceLog*.json`) should have
   "Result of publishing element" `Success` for each Library element and `SuccessPublish` for each
   page (8 and 17 for Clean 19), and no `"@l":"Error"` entries. Look at a few screenshots, e.g.
   `screenshots/*codegarden-2026*.png` shows the categories and the reusable block.
5. **Delete `test-installation/` and `test-template-TestTemplateProject/`** when done
   (`test-installation/` alone is about 500 MB).

### Repeating the package install to catch intermittent boot failures

A failure that only shows on some boots needs many installs in a row. `tools/package-install-repro/`
has the scripts for that (Git Bash, plus Node.js); see its `README.md`. In short, after steps 1
and 2 above:

```bash
tools/package-install-repro/setup.sh <scratchpad>/repro 19.0.0-rc02
cd <scratchpad>/repro && ./install-loop.sh 30 nostop
node timeline.mjs runs/run5.json | grep -E "Rebuilding all|Unattended upgrade"
```

Run the loop with the Bash tool's `run_in_background`; 30 runs take about 16 minutes. Use a work
folder outside the repo (the session scratchpad). Prove a fix with at least 30 runs and 0
failures, and record the numbers in the plan.

## Regenerate Models Builder models after schema or package changes

`template/Clean.Models/*.generated.cs` is committed to source control. Clean.Blog runs
Models Builder in `SourceCodeManual` mode (`ModelsDirectory: ~/../Clean.Models`), so the models
only change when they are regenerated explicitly.

**Always regenerate the models and commit them** after either of these:

- a schema change: adding, removing or editing a document type, element type, media type,
  member type, composition or property (whether in the backoffice or through uSync files)
- a package version update: any change to the `Umbraco.Cms.*` package versions (major, minor or
  patch), so that the `Umbraco.ModelsBuilder.Embedded` version stamps match the shipped version

### How to regenerate

The same steps are documented for human contributors in
`.github/general-contributing.md` (section "Regenerating Models Builder Models"); keep the two in
sync.

1. Run Clean.Blog (`dotnet run` in `template/Clean.Blog`, https://localhost:44340). Wait for the
   site to finish starting and any unattended upgrade to complete.
2. Get a bearer token with the API client that `appsettings.Development.json` provisions
   (`uSync:Command:ClientId` / `uSync:Command:Secret`, created on startup by
   `Composing/ApiClientSetup.cs`):
   `POST https://localhost:44340/umbraco/management/api/v1/security/back-office/token`
   with form body `grant_type=client_credentials&client_id=<ClientId>&client_secret=<Secret>`.
3. Trigger generation:
   `POST https://localhost:44340/umbraco/management/api/v1/models-builder/build`
   with `Authorization: Bearer <token>`. Expect `200`.
   (Alternatively, use **Settings > Models Builder > Generate models** in the backoffice.)
4. Check `GET /umbraco/management/api/v1/models-builder/dashboard` reports `"lastError": null`.
5. Build `template/Clean.Models/Clean.Models.csproj`, review the diff in `template/Clean.Models`,
   and commit it. After a package-only update the diff should be just the version stamps; any
   other change means the schema and the committed models had drifted, so call it out.
