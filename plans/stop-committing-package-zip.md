# Stop committing `template/Clean/Migrations/package.zip`

Written 2026-11-14. Base branch: `dev/v19` (this repo has no `develop`; v19 PRs merge into
`dev/v19`). Independent of `bugfix/v19/package-install-dictionary-cache`.

## The problem

`template/Clean/Migrations/package.zip` is committed, but it is never the file that ships:

- `CreateNuGetPackages.ps1` exports the package from Clean.Blog and writes it to the folder that
  holds `ImportPackageXmlMigration.cs` (`template/Clean/Migrations/`), then packs `Clean`. Both
  `pr-build-packages.yml` and `release-nuget.yml` run it, so every PR build and release
  overwrites the committed copy before packing.
- Every local run of the script shows the file as modified, usually only `updateDate` or the
  package name. `CLAUDE.md` has a step to `git checkout` it back each time.
- The committed copy can silently go stale, and contributors can commit churn by accident.

## Findings

- `Clean.csproj` embeds it: `<EmbeddedResource Include="Migrations\package.zip" />`, plus a
  `<None Remove=...>` line. With the file absent, that item still points at a missing file, so
  `dotnet build` of `Clean` on a fresh clone fails (or warns, depending on the SDK). This is why it
  can't just be deleted.
- Clean.Blog references Clean.Core, Clean.Headless and Clean.Models, **not** Clean. So the script
  can run Clean.Blog to produce the zip before Clean is ever built. There is no chicken-and-egg.
- Two things read the embedded resource at runtime: `ImportPackageXmlMigration`
  (`ImportPackage.FromEmbeddedResource`) and `PostMigrationNotification`
  (`PackageMigrationResource.TryGetEmbeddedPackageDataManifest`). Only sites that install the
  `Clean` package run them, and those get the zip from the built nupkg.
- `.gitignore` has no rule for `template/Clean/Migrations/package.zip` (the existing rules cover
  `wwwroot/media/created-packages`).

## Decision

Stop tracking the file. Generate it in the build scripts only, and make a `Clean` pack fail loudly
if it is missing, so a release can never ship without it.

## Implementation

### 1. Branch

```bash
git checkout dev/v19
git pull
git checkout -b feature/v19/stop-committing-package-zip
```

Don't branch off another feature branch. If `bugfix/v19/package-install-dictionary-cache` is
unmerged when this starts, that's fine: it doesn't touch the same files except the `CLAUDE.md`
mention, so resolve that on merge.

### 2. Make the csproj tolerate a missing zip, and guard the pack

`template/Clean/Clean.csproj`:

- Make the embed conditional:
  `<EmbeddedResource Include="Migrations\package.zip" Condition="Exists('Migrations\package.zip')" />`
  and keep the `<None Remove>` line.
- Add a target that runs before `GenerateNuspec` (and `Pack`) and errors when the zip is missing:
  `<Error Condition="!Exists('Migrations\package.zip')" Text="Migrations\package.zip is missing. Run .github/workflows/powershell/CreateNuGetPackages.ps1, which exports it from Clean.Blog." />`
- Check that the order in `CreateNuGetPackages.ps1` is: export zip, then `dotnet pack` of Clean. If
  it builds Clean earlier (for example a solution-wide build), move the zip export first, or the
  build embeds nothing.

### 3. Stop tracking and ignore the file

```bash
git rm --cached template/Clean/Migrations/package.zip
```

Add `template/Clean/Migrations/package.zip` to the root `.gitignore`, next to the existing
`created-packages` rule. Leave the file on disk for local runs.

### 4. Update docs

- `CLAUDE.md`, "Test the package and template installs locally", step 2: remove the bullet about
  restoring `package.zip` with `git checkout`, and say the script generates it and git ignores it.
  Remove the "commit a regenerated package.zip" sentence.
- `.github/script-create-nuget-packages.md` and `.github/script-create-packages.md`: note the file
  is generated, ignored, and must exist before packing.
- `.github/general-contributing.md`: add a line if it mentions the file.

### 5. Verify

Use a local version such as `19.0.0-local.3`. Clear `~/.nuget/packages/clean/<v>`,
`clean.core/<v>` and `clean.headless/<v>` first, as `CLAUDE.md` describes.

1. **Fresh clone behaviour:** with the file deleted, `dotnet build template/Clean/Clean.csproj`
   succeeds (no embedded resource, no error). `dotnet pack` of `Clean` fails with the new error
   message.
2. `CreateNuGetPackages.ps1 -Version <v>` succeeds and `git status` shows **no** `package.zip`
   change.
3. Open `.artifacts/nuget/Clean.<v>.nupkg` (it's a zip) and confirm the `Clean.dll` embeds the
   resource, or just rely on step 4 passing.
4. `Test-PackageInstallation.ps1` and `Test-TemplateInstallation.ps1` both exit 0. Check the
   package site's log as `CLAUDE.md` describes (8 elements `Success`, 17 pages `SuccessPublish`,
   no errors).
5. Open a draft PR to `dev/v19` and check the `pr-build-packages.yml` build passes. It is the real
   proof that CI generates the file.
6. Delete `test-installation/`, `test-template-TestTemplateProject/` and the `<v>` NuGet cache
   folders.

### 6. CHANGELOG and commit

Add a line under `## [Unreleased]` (create it if the dictionary-cache branch isn't merged yet),
for example under `### Changed`: "`template/Clean/Migrations/package.zip` is no longer committed.
The package build script generates it". Commit as `Paul Seal <prjseal@gmail.com>` with a message
that describes only the changes. Don't push.

## Risks

- Anything that builds `Clean` without running the script, then installs it, would have no
  package content. The pack guard in step 2 covers `dotnet pack`. A plain `dotnet build` of the
  solution still succeeds without the zip, by design, because nothing runs the migration from that
  output.
- Contributors who relied on the committed zip to run the migration from a project reference to
  `Clean` get a site with no package content. Nobody does this in the repo today (Clean.Blog
  doesn't reference Clean); say so in the PR description.

## Out of scope

- Changing how the package is exported, or its contents.
- The dictionary cache fix (`plans/package-install-dictionary-cache-workaround.md`).
