# Rebuild Clean as a native Umbraco 19 starter kit

## Context

Clean is on Umbraco 19.0.0-rc1 and .NET 11, but it got there by upgrading through 13, 17 and 18. The
schema, stored values, config and code still carry that history:

- The built-in Data Types in `uSync/v19` keep their pre-19 names ("Content Picker", "Multiple Media
  Picker", "Dropdown") and include ones a fresh install may not have ("Media Picker (legacy)",
  an AngularJS-shaped "List View - Members").
- Clean's own Data Types still use the deprecated Multi Node Tree Picker, carry leftover config keys
  (`useSingleBlockMode`, MediaPicker3 keys on a single picker) and old names.
- Content values for single-item editors are stored in upgraded shapes.
- Search calls `IPublishedContentQuery.Search` and filters in memory, instead of Umbraco Search.
- `appsettings`, `launchSettings.json`, views and the committed `package.zip` (still the v17
  "Clean v7" export) hold pre-19 leftovers.

The goal is that all four NuGet packages look as if Clean had been built on a fresh Umbraco 19
install: `Clean`, `Clean.Core`, `Clean.Headless` and `Umbraco.Community.Templates.Clean`.

### Decisions already made

- Remove the leftover `category` and `categoryList` document types and the empty `listPageSettings`
  element type.
- Restore the built-in "Richtext editor" to stock; move Clean's toolbar and `/dropdownStyles.css`
  into a new `Rich Text (Standard)` Data Type.
- Release as **19.0.0-rc02**.
- Search moves to Umbraco Search (`ISearcher`, Examine 4 as the default provider). No direct Examine
  code.
- **Drop the `[Kind] Purpose` bracket naming.** Clean's Data Types follow the ClerksWell convention
  (`D:\Code\GitHub\clerkswell\clerkswell\schema\CONVENTIONS.md`, sections 6 and 7): plain Title Case
  names that say what the Data Type is for, with any constraint in brackets at the end
  (`Link Picker (single)`, `Toggle (default on)`), filed in a folder per family.
- **The package export must not depend on a name prefix.** It exports every Data Type Clean uses.

### Rules that apply throughout

- **Built-in Data Types are never customised.** Anything Clean needs that differs from stock is
  its own Data Type in the `Clean` folder. Validation and limits live in the Data Type, so one
  Data Type is reused wherever that constraint applies.
- **Folders, as in the ClerksWell site.** Two folders at the root of the Data Types tree, each
  with one sub-folder per family: `Clean` for Clean's own Data Types and `Umbraco Defaults` for
  Umbraco's built-ins. (ClerksWell's are `ClerksWell Main Site` and `Umbraco Defaults`.)
- **The fresh v19 install is the reference.** Where this plan and the baseline (step 1) disagree,
  the baseline wins; note the difference in the PR.
- **Public surface stays stable:** document type and property aliases, API routes, package IDs,
  the root `home` alias, the `Image` media type alias, and the content node keys (used by
  `Get-UsyncKeys.ps1`). Data Type keys stay the same when a Data Type is only renamed or moved.

## Implementation

### 0. Branch

`git checkout dev/v19`, `git pull`, `git checkout -b feature/v19-native-rebuild`.
(The repo has no `develop`; `dev/v19` is the v19 integration branch, as in
`plans/fix-build-warnings.md`.) One branch, one commit per numbered step below.

### 1. Capture the fresh Umbraco 19 baseline (outside the repo)

In the scratchpad or another temp folder, never inside the repo:

1. `dotnet new install Umbraco.Templates::19.0.0-rc1`, then
   `dotnet new umbraco -n Baseline --development-database-type SQLite` with unattended install
   values. Add `uSync` 19.0.0-rc1, run it, and do a full uSync export.
2. Keep two things as the reference for every later step:
   - **Schema baseline:** the exported `DataTypes`, `MediaTypes`, `MemberTypes`, `RelationTypes`
     and `Languages` files (names, keys, editor aliases, config).
   - **Project baseline:** the generated `Program.cs`, `.csproj`, `appsettings*.json`,
     `launchSettings.json`, `.gitignore` and `umbraco-package-schema.json`.
3. Record in the PR description which built-in Data Types exist on a fresh install and their names.

### 2. Rebuild the Data Types in `template/Clean.Blog/uSync/v19/DataTypes`

**Built-ins (39 today).** Match each by key against the baseline.

- Replace each file with the baseline file (new name, stock config). Expected renames, to confirm:
  Content Picker to Single Document Picker, Member Picker to Single Member Picker, Media Picker to
  Single Media Picker, Image Media Picker to Single Image Media Picker, Multiple Media Picker to
  Media Picker, Multiple Image Media Picker to Image Media Picker, Multi URL Picker to URL Picker,
  Dropdown to Single Select Dropdown, Dropdown multiple to Select List.
- Delete any built-in file whose key is not in the baseline (candidates: `MediaPickerLegacy`,
  `MultipleMediaPickerLegacy`). Add any baseline Data Type that Clean is missing.
- If a baseline key differs from Clean's key for the same Data Type, switch Clean to the baseline
  key and update every `<Definition>` that pointed at the old one.
- File names follow what uSync writes on export; let step 5 settle them.
- Move every built-in into `Umbraco Defaults/<Family>`, with the stock name and config untouched.
  Families, as ClerksWell has them: Checkbox List, Color Picker, Content Picker, Date Picker,
  Dropdown, Image Cropper, Label, List View, Media Picker, Member Picker, Multi URL Picker (name
  it URL Picker if the baseline calls the Data Type that), Number, Radiobox, Rich Text Editor,
  Tags, Text Area, Text Box, Toggle, Upload. Add a family for any baseline Data Type that fits
  none of these. No Data Type is left at the root of the tree.

**Clean's own Data Types.** Move each into `Clean/<Family>` under its new name. Keep each key.

| Today | New name | Folder (`Clean/…`) | Change |
|---|---|---|---|
| `[BlockList] Main Content` | `Main Content Block List` | Block List | Remove `useSingleBlockMode`; `validationLimit` as a new Block List writes it. Block labels unchanged. |
| `[BlockList] Icon List` | `Social Links` | Block List | Same clean-up. |
| `[MNTP] Authors` (`Umbraco.MultiNodeTreePicker`) | `Author Picker (single)` | Content Picker - Single | Single document picker (`Umbraco.ContentPicker`) with the same dynamic root (nearest `authorList` under Home). Use `Umbraco.DocumentPicker.Multiple` with a limit of 1 only if the single picker cannot hold a dynamic root. `Article.Author` must stay `IPublishedContent`. |
| `[ElementPicker] Categories` | `Category Picker (multiple)` | Taxonomy Picker | Name and folder only. |
| `[MediaPicker] SVG Image` | `Icon Media Picker` | Media Picker | Drop the MediaPicker3 leftovers (`crops`, `enableLocalFocalPoint`, `startNodeId`, `ignoreUserStartNodes`); keep the vector graphics `filter`. |
| `[MultiUrlPicker] Single Url Picker` | `Link Picker (single)` | URL Picker | Editor is already `Umbraco.UrlPicker.Single`. Config as a fresh single URL picker writes it. |
| `[Dropdown] Spacing` | `Spacing Dropdown` | Dropdown | Name and folder only. |
| `[Toggle] Default True` | `Toggle (default on)` | Toggle | Name and folder only. |
| (new) | `Rich Text (Standard)` | Rich Text Editor | `Umbraco.RichText` with Clean's current toolbar and `/dropdownStyles.css`, with the duplicate `Umb.Tiptap.Toolbar.Anchor` removed. |
| `[Slider] Spacing` | deleted | | Unused. |

- No Data Type name starts with `[` afterwards.
- uSync names each file after the Data Type, so the file names change too (for example
  `BlockListMainContent.config` becomes whatever uSync writes for `Main Content Block List`).
  Delete the old files; do not leave both.
- Where the baseline already ships an identical stock Data Type (same editor, same config), use
  the built-in and do not create a Clean copy.
- These names and families follow the live ClerksWell tree in
  `D:/Code/GitHub/ClerksWell/ClerksWell.Site/umbraco/Deploy/Revision` (`data-type__*.uda` and
  `data-type-container__*.uda`). Check against it when a name or family is in doubt.

### 3. Update the types that use them (`uSync/v19/ContentTypes`, `MediaTypes`, `MemberTypes`)

- Point `articleControls.author` at `Author Picker (single)`, and `richTextRow.richContent` plus
  the three `contactFormControls` messages at `Rich Text (Standard)`. Update each `<Type>` to match.
- Delete `category`, `categoryList` and `listPageSettings`; remove them from `home`'s allowed
  children and from the compositions of `article` and `articleList`.
- Media and member types: take the baseline files, then re-apply Clean's one addition, the
  `altText` (Textarea) property on `Image`. This also aligns which Label Data Types the media
  types use.
- `RelationTypes` and `Languages`: take the baseline, keeping `en-us`.

### 4. Rewrite stored values in v19's native shape

- Author values move from the Multi Node Tree Picker to the new picker; keep the same author.
- On the running site (step 5), open and re-save and publish every content node and Library
  Element so each value is written by the v19 editor (single media pickers, single URL picker,
  dropdowns, block lists). Content node and element keys must not change.

### 5. Import, normalise and re-export

1. Delete `template/Clean.Blog/umbraco/Data` (SQLite DB and TEMP).
2. `dotnet run` in `template/Clean.Blog`; uSync first-boot import must finish with no errors.
3. Do step 4's re-save, then a clean uSync export (export with "clean" so removed items go).
4. Review the whole `uSync/v19` diff. Expected: renamed and removed Data Types, three removed
   types, repointed properties, reshaped values. Anything else needs explaining in the PR.
5. Delete the DB again and boot once more: the import must report **no changes** on a second
   import, and the site must render.

### 6. Regenerate Models Builder models

Follow `CLAUDE.md` ("How to regenerate"). Expected diff in `template/Clean.Models`: `Category`,
`CategoryList`, `ListPageSettings`/`IListPageSettings` removed; nothing else changes type
(`Author` stays `IPublishedContent`, `Link` stays `Link`, images stay `MediaWithCrops`). Call out
anything different.

### 7. Search on Umbraco Search

Read `develop-with-umbraco/search/getting-started` in the v19 docs and the `ISearcher` XML docs in
the NuGet cache first; use the signatures found there.

- New `Clean.Core/Services/ISiteSearchService.cs` and `SiteSearchService.cs`: wraps `ISearcher`
  against the published content index (`Constants.Search.IndexAliases.PublishedContent`), takes
  term, culture, page and page size, excludes `error`, `search` and `xMLSitemap` **in the query**
  (content type filter), and returns a paged result of `IPublishedContent`. Register it in a
  composer in Clean.Core. If `ISearcher` is not reachable from `Umbraco.Cms.Web.Website`, add the
  Umbraco package reference that carries it rather than Examine.
- `Clean.Blog/Views/search.cshtml`: use the service, typed `IArticleControls`/`IHeaderControls`
  properties instead of string aliases, and the existing `Pagination` view component.
- `Clean.Headless/Controllers/SeachApiV1Controller.cs`: rename the file to
  `SearchApiV1Controller.cs`, make the action async on the same service, keep the route and the
  response shape, add optional `page`/`pageSize`.
- Mirror the view into the `Clean` package content (`template/Clean/Views`) if it ships there, and
  it is otherwise carried by `package.zip`.

### 8. Code and views: v19 and .NET 11 patterns

- **Views**
  - Delete the legacy `Views/Partials/grid/**` partials and the unused `Views/Partials/blockgrid/**`.
  - `xmlSitemap.cshtml`: read `hideFromXMLSitemap` (typed, via `IVisibilityControls`) instead of
    the non-existent `excludeFromSitemap`.
  - `latestArticlesRow.cshtml`: remove the read of the non-existent `showFullArticleOnListPage`.
  - Replace string-alias reads with typed properties in `mainNavigation.cshtml`,
    `metaData.cshtml` and `NextJsRevalidateContentNotificationHandler.cs`.
  - `PageHeaderViewModel.BackgroundImage` becomes `MediaWithCrops?`; null-check `Model.Author`
    in `article.cshtml` and `latestArticlesRow.cshtml`.
- **`Clean` package**
  - `PostMigrationNotification.cs`: make the handler properly async, and pass a real user to the
    publish calls (v19 needs an existing user for access checks; use the super user key overloads).
  - `ImportPackageXmlMigration.cs`: no fake `async`.
  - `Clean.csproj`: fix the `default.cshtml` / `Default.cshtml` case mismatch.
  - Re-sync `template/Clean/wwwroot` and `template/Clean/Views` with Clean.Blog.
- **`Clean.Headless`**
  - `NextJsRevalidateService`: `IHttpClientFactory` instead of `new HttpClient()`.
  - Rename `Startup/WorkshopComposer.cs` to `HeadlessApiComposer.cs`; fix the copied XML summary
    on the contact controller; `GetById` by key, not int id.
  - Confirm the OpenAPI registration compiles cleanly against `Microsoft.OpenApi` 3.x with no
    obsolete warnings.
- **`Clean.Core`**: enable `Nullable`, fix the resulting warnings, remove the leftover
  `<Folder Include=...>` items (also in Headless).
- **`Clean.Blog`**
  - `PackageController`: use the async service methods; drop the `null!` arguments.
  - `PackageController` **Data Type export:** remove the `Name.StartsWith("[")` filter
    (line 151) and export **every** Data Type on the site, in both the `Clean` and
    `Umbraco Defaults` folders, with their folders. Nothing is selected by name.

    Add a guard that fails the export with a clear message if an exported document, element or
    media type references a Data Type that is not in the export. The built-ins keep Umbraco's
    keys and stock config, so on a fresh site the import only moves them into their folders.
    Note in the CHANGELOG and README that installing the package files Umbraco's built-in Data
    Types under `Umbraco Defaults`.
  - Confirm the exported `package.xml` keeps both folder trees (`Clean/<Family>` and `Umbraco Defaults/<Family>`), and that a package
    install recreates them. If Umbraco's package format does not carry Data Type folders, say so
    in the PR and create the folders in the package migration instead.
- **`CreateNuGetPackages.ps1`** (the block label workaround for Umbraco issue #20801): it matches
  the Data Type name `[BlockList] Main Content` (line 46) and the file
  `uSync\v19\DataTypes\BlockListMainContent.config` (line 439). Change both to the new name
  `Main Content Block List` and the file uSync now writes for it. Better, look the file up by the
  Data Type key (`b5922818-d8d8-43df-88ed-4582a24c0fa6`) so a later rename cannot break the build.
  First check whether issue #20801 is fixed in 19.0.0-rc1; if it is, remove the workaround.
  - `ApiClientSetup.cs`: correct the stale "no Umbraco 18 release" comment.
- New code uses file-scoped namespaces and primary constructors; do not reformat untouched files.
- Build with zero warnings.

### 9. Project and config files, against the project baseline

- `appsettings.json`: remove `Global:SanitizeTinyMce` and `Content:AllowEditInvariantFromNonDefault`
  (replaced by the "Allow editing shared content" permission; Administrators have it).
- `appsettings.Development.json`: remove `Content:MacroErrors` and `RuntimeMinification`; use
  `Umbraco:CMS:Debug` where the baseline does.
- `Properties/launchSettings.json`: Kestrel profile first, as the baseline has it; keep ports 38357
  and 44340 (the template replaces them).
- `Clean.Blog.csproj`, `Program.cs`, `.gitignore`: adopt baseline differences (for example the
  Razor compile properties and comment) while keeping Clean's additions (`ApiClientSetup`,
  `SecurityHeadersMiddleware`, ICU, `SourceCodeManual` models).
- Refresh `umbraco-package-schema.json` from the baseline.
- `template-pack.csproj`: fix the exclude list (the comma between the `obj` and `.vs` patterns)
  and also exclude `template\**\umbraco\Data\**` and `template\**\umbraco\Logs\**`, so the template
  package stops shipping a database, logs and build output.
- Versions: `19.0.0-rc02` in `Clean.csproj`, `Clean.Core.csproj`, `Clean.Headless.csproj` and
  `template-pack.csproj`.

### 10. Regenerate the embedded package

Run `.github/workflows/powershell/CreateNuGetPackages.ps1` locally with version `19.0.0-rc02`
(it starts Clean.Blog and calls the local Management API). Commit the regenerated
`template/Clean/Migrations/package.zip`, replacing the v17 one. Check its `package.xml` lists every
Data Type from step 2's table plus each built-in Clean uses, with their folders, that every Data
Type key referenced by an exported type is present, and that there is an `<Elements>` section with
the seven categories.

### 11. Docs

- `CHANGELOG.md`: new `## [19.0.0-rc02] - <date>` entry in the existing format.
- `README.md`: rc02 install commands; fix the "currently in beta" line.
- `.github/general-contributing.md`: .NET 11 prerequisite, the real SQLite path, `/umbraco/openapi`
  if that is the v19 URL, the `Element/` folder in the uSync tree, the "built-ins are never
  customised" rule, and the Data Type naming and `Clean/<Family>` folder convention (replacing any
  mention of `[Kind] Purpose` names).
- `.github/clean-headless-api.md`, both `umbraco-marketplace-readme*.md` and both
  `umbraco-marketplace*.json`: Search section instead of Examine Management, v19 rows, correct
  `Umbraco:CMS:DeliveryApi` path.
- `.github/workflow-versioning-releases.md`: the `-rcNN` version format actually used.

### Out of scope

- Converting articles' rich text or blocks to reusable Library blocks, or adding Document
  Blueprints or segments.
- Adding backoffice extensions (Clean has none).
- CI workflow behaviour, other than what the version bump needs.
- Opting projects into runtime async, unless the project baseline does.

## Verification

1. `dotnet build template/Clean.sln` and `template-pack.sln`: zero warnings, zero errors.
2. **Template path:** delete `umbraco/Data`, run Clean.Blog; first-boot import clean; a second
   import reports no changes; every page in the Home tree renders, including search (results,
   paging, no excluded types) and the XML sitemap.
3. **Backoffice:** no deprecated editors in use; Data Type names match the baseline; the Data Types
   tree has only the `Clean` and `Umbraco Defaults` folders at its root, with nothing loose; Settings >
   Search shows healthy indexes; each article shows its author and categories.
4. **Headless:** `GET /api/v1/search`, dictionary and contact endpoints respond; the
   `clean-starter` OpenAPI document loads.
5. **Models:** `models-builder/dashboard` reports `"lastError": null`; `Clean.Models` builds.
6. **Package path:** run `Test-PackageInstallation.ps1` (fresh `dotnet new umbraco` 19.0.0-rc1 plus
   the local `Clean` 19.0.0-rc02 package). The site must start, publish Home and the categories,
   and render. Confirm the installed site has no duplicate or renamed built-in Data Types, that the built-ins are under
   `Umbraco Defaults/<Family>`, that all of
   Clean's Data Types are present under `Clean/<Family>`, and that no property is missing its
   Data Type.
7. **Template package:** run `Test-TemplateInstallation.ps1`; confirm the `.nupkg` contains no
   `umbraco/Data`, `obj` or `.vs` entries and is far smaller than 329 MB.
8. `git grep` finds no `MultiNodeTreePicker`, `useSingleBlockMode`, `IPublishedContentQuery` search
   calls, `SanitizeTinyMce`, `MacroErrors` or `RuntimeMinification` under `template/`, no Data Type
   name starting with `[` in `uSync/v19`, and no `StartsWith("[")` in `PackageController.cs`.
9. Commit per step as `Paul Seal <prjseal@gmail.com>`, with no assistant attribution. Do not push
   or open a PR unless asked.
