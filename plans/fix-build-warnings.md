# Fix build and CI warnings before the Clean 19 beta release

## Context

Before releasing Clean 19.0.0-beta01, the build and CI should run without warnings.
`dotnet build template/Clean.sln --no-incremental` currently reports **20 warnings** in four groups,
and every GitHub Actions run adds a **"Node.js 20 is deprecated"** annotation. The workflows that
install Node for Playwright and ZAP also pin Node 20, which is no longer the latest LTS.
Node **26** has been the latest LTS since October 2026 (v26.13.1, released 2026-11-10).

### Warnings found

| # | Warning | Where | Cause |
|---|---------|-------|-------|
| 1 | NU1903 `System.Security.Cryptography.Xml` 10.0.11 (GHSA-7hqp-7c5m-4vq6, GHSA-c399-9853-6jmj, GHSA-r955-8q5j-3h83). Fixed in 10.0.13 and in 11.0.0-rc.2 onwards | `Clean.Headless`, `Clean` (via the project reference) | Transitive: `Umbraco.Cms.Api.Common 19.0.0-beta1` > `OpenIddict.AspNetCore 7.7.2` > `Microsoft.AspNetCore.DataProtection 10.0.11` |
| 2 | NU1903 `Microsoft.AspNetCore.WebUtilities` 11.0.0-rc.3 (GHSA-x33c-w48q-qrgc). Fixed in 11.0.0 | `Clean.Headless`, `Clean` | Transitive: `Umbraco.Cms.Api.Common 19.0.0-beta1` > `Microsoft.AspNetCore.OpenApi 11.0.0-rc.3` |
| 3 | CS8602 "Dereference of a possibly null reference" | `template/Clean.Core/TagHelpers/InlineSvgTagHelper.cs:208` | HtmlAgilityPack's `SelectNodes("//svg")` returns `null` when nothing matches. This is a real bug: an SVG file with no `<svg>` node throws a `NullReferenceException` when `EnsureViewBox` or `CssClass` is set |
| 4 | CS8632 nullable annotation outside a `#nullable` context (x2) | `template/Clean/Migrations/PostMigrationNotification.cs:79-80` | `Clean.csproj` has no `<Nullable>enable</Nullable>`, unlike `Clean.Headless` and `Clean.Blog` |
| 5 | CS0618 `Constants.Security.SuperUserId` is obsolete ("Use SuperUserKey instead") | `template/Clean/Migrations/PostMigrationNotification.cs:91` | `_elementService.Publish(element, ["*"], Constants.Security.SuperUserId)` |
| 6 | CI: "Node.js 20 is deprecated … actions/checkout@v4, actions/setup-dotnet@v4, actions/upload-artifact@v4" | every workflow run | These action majors run on node20 |
| 7 | Workflows install Node 20 (`node-version: '20'`) | 4 workflows | Old pin; the latest LTS is 26 |

`Umbraco.Cms.*` 19.0.0-beta1 is still the newest Umbraco 19 build on NuGet, so warnings 1 and 2 can't
be cleared by an Umbraco upgrade. They need direct package pins.

## Implementation

### 0. Branch

There is no `develop` branch. Clean 19 work targets `dev/v19` (PRs #499-#501 merged into it).

```
git checkout dev/v19
git pull
git checkout -b feature/v19-fix-warnings
```

### 1. NuGet vulnerability warnings (NU1903)

In `template/Clean.Headless/Clean.Headless.csproj`, next to the `Umbraco.Cms.Api.Common` reference, add
direct references that lift the vulnerable transitive packages to patched versions:

```xml
<!-- Pin patched versions of vulnerable transitive dependencies of Umbraco.Cms.Api.Common 19.0.0-beta1.
     Remove once Umbraco ships a build that references fixed versions. -->
<PackageReference Include="System.Security.Cryptography.Xml" Version="11.0.0" />
<PackageReference Include="Microsoft.AspNetCore.WebUtilities" Version="11.0.0" />
```

- Use 11.0.0 for both, because the projects target `net11.0` and both packages have a GA 11.0.0 on NuGet.
- `Clean` references `Clean.Headless`, so the pins flow through to it, and to the packed `Clean.Headless`
  nupkg as dependencies. That protects consumers of the package too. No change is needed in `Clean.csproj`.
- Check that the pins don't trigger an NU1605 downgrade or NU1608 warning against Umbraco's own constraints.

### 2. CS8602 in `InlineSvgTagHelper`

`template/Clean.Core/TagHelpers/InlineSvgTagHelper.cs` around line 207: guard the `null` result rather
than suppressing it.

```csharp
var svgs = doc.DocumentNode.SelectNodes("//svg");
if (svgs is not null)
{
    foreach (var svgNode in svgs) { ...unchanged... }
}
sanitizedFileContents = doc.DocumentNode.OuterHtml;
```

A shorter alternative is `foreach (var svgNode in svgs ?? Enumerable.Empty<HtmlNode>())`. Either is
fine; keep the behaviour otherwise identical.

### 3. CS8632 in `Clean` project

Add `<Nullable>enable</Nullable>` to the first `PropertyGroup` of `template/Clean/Clean.csproj`, matching
`Clean.Headless.csproj` and `Clean.Blog.csproj`. The project has only five small `.cs` files
(`CleanComposer.cs`, `CleanManifestReader.cs`, `Migrations/*.cs`), so fix any new nullable warnings this
surfaces in those files. Views are not compiled in this project, so the setting doesn't affect them.

### 4. CS0618 `SuperUserId`

In `template/Clean/Migrations/PostMigrationNotification.cs:91`, drop the obsolete argument so the call
matches the existing `PublishBranch` call at line 46, which already relies on the default user:

```csharp
var publishResult = _elementService.Publish(element, ["*"]);
```

First confirm (go to definition / decompile) that `IPublishableContentService<T>.Publish`'s `userId`
parameter defaults to the super user in 19.0.0-beta1.

If it doesn't have that default, or the int overload is itself obsolete, switch to the key-based API:
inject `IElementPublishingService` and call
`PublishAsync(element.Key, [new CulturePublishScheduleModel { Culture = "*" }], Constants.Security.SuperUserKey)`.
That makes `PublishPackageElements` async, so `HandleAsync` must await it. Check how invariant elements
expect the culture to be passed (likely `"*"` or `null`).

### 5. GitHub Actions: Node 20 deprecation and Node LTS

All edits are in `.github/workflows/*.yml`. The latest majors below all declare `runs.using: node24`, which
clears the deprecation annotation.

| Action | From | To |
|--------|------|----|
| `actions/checkout` | `@v4` (8x), `@v3` (1x, `update-packages.yml:37`) | `@v7`, **except `pr-build-packages.yml`, which goes to `@v6`** |
| `actions/setup-dotnet` | `@v4` (7x) | `@v6` |
| `actions/setup-node` | `@v4` (4x) | `@v7` |
| `actions/upload-artifact` | `@v4` (18x) | `@v7` |

`NuGet/login@v1` and `zaproxy/action-full-scan@v0.13.0` already run on node24, so leave them.

Notes for the implementer:

- **`pr-build-packages.yml` stays on `actions/checkout@v6` (decided).** It runs on `pull_request_target`
  and checks out `github.event.pull_request.head.sha`. checkout@v7 refuses to do that for fork PRs unless
  `allow-unsafe-pr-checkout: true` is set. v6 keeps fork PR builds working as they do today and still
  runs on node24. Add a one-line YAML comment there explaining why it is pinned to v6.
- checkout v6+ stores persisted credentials in a separate file instead of `.git/config`. `update-packages.yml`
  (via `powershell/Invoke-CommitAndPush.ps1`) pushes with the checkout credentials. Plain `git push`
  still works with this, but watch that workflow's first run.
- setup-node v5+ auto-caches only when `package.json` has a `packageManager` field. None of these workflows
  have that field, so nothing changes.
- upload-artifact v7 keeps zipping by default (`archive: true`), so existing `upload-artifact` steps behave the same.

Node version: change `node-version: '20'` to `node-version: '26'` in
`test-umbraco-latest.yml`, `test-umbraco-latest-nightly.yml`, `test-umbraco-latest-nuget.yml` and
`zap-security-scan.yml`. Pin the major rather than `lts/*`, so CI doesn't change silently at the next
LTS hand-over.

### 6. Docs that mention these versions

Update text that would otherwise be stale:

- "Setup Node.js 20" in the Mermaid diagrams: `.github/workflow-test-umbraco-latest.md:89`,
  `workflow-test-umbraco-latest-nightly.md:96`, `workflow-test-umbraco-latest-nuget.md:93`,
  `workflow-zap-security-scan.md:157`. Change to "Node.js 26".
- "Node.js 20+" in `.github/script-test-latest-nuget-packages.md:553` and `script-test-latest-with-zap.md:608`.
  Change to "Node.js 26".
- Any YAML snippets with `actions/*@v4` or `setup-node … '20'` in the `.github/*.md` workflow and script
  docs (e.g. `script-test-latest-with-zap.md`, `workflow-zap-security-scan.md`, which also cite
  `zaproxy/action-full-scan@v0.10.0`). Align them with the real workflows.

### Out of scope

- No schema or `Umbraco.Cms.*` version change, so there's no Models Builder regeneration.
- No version bump: this ships inside 19.0.0-beta01.

## Verification

1. `dotnet build template/Clean.sln --no-incremental` reports **0 warnings** and 0 errors.
2. `dotnet nuget why template/Clean/Clean.csproj System.Security.Cryptography.Xml` and
   `dotnet nuget why template/Clean/Clean.csproj Microsoft.AspNetCore.WebUtilities` both resolve to 11.0.0.
3. `dotnet list template/Clean.sln package --vulnerable --include-transitive` reports no vulnerable packages.
4. Run Clean.Blog (`dotnet run` in `template/Clean.Blog`) and check that the home page and an article
   with inline SVG icons render as before.
5. To check the migration change, install the starter kit into a fresh site: build the packages and run
   `.github/workflows/powershell/Test-PackageInstallation.ps1`, or let the PR build do it. Confirm that the
   element library items come out published and that the log line "Result of publishing element …" shows success.
6. `grep -rn "@v4\|@v3\|node-version: '20'" .github/workflows` returns nothing, apart from the deliberate
   `actions/checkout@v6` in `pr-build-packages.yml`.
7. Open a PR into `dev/v19`. The PR build should show no "Node.js 20 is deprecated" or CS8602
   annotations. Also run "Test Umbraco Latest" manually with `workflow_dispatch` to check the Node 26 +
   Playwright path.
8. Commit locally as `Paul Seal <prjseal@gmail.com>`. Push and open the PR only when asked.
