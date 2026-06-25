# Umbraco 18 Beta Upgrade Plan for Clean

Investigation of Umbraco 18 beta breaking changes and the plan to make Clean
compatible. Target: Umbraco `18.0.0-beta2`, Clean package version `8.0.0-beta1`.

## Current state

All 5 projects (`Clean`, `Clean.Core`, `Clean.Headless`, `Clean.Blog`,
`Clean.Models`) target `net10.0` and reference Umbraco `17.1.0`. Package
version is stamped at `7.0.5`. Compatible extras: `uSync 17.0.1` and
`uSync.Command.Setup 16.1.0`.

## Decisions

- **Target Umbraco version**: `18.0.0-beta2` (latest beta as of 2026-05-14).
- **Clean package version**: bump to `8.0.0-beta1` (matches the existing
  convention: Umbraco 17 → Clean 7, Umbraco 18 → Clean 8).
- **uSync**: keep current pins (`uSync 17.0.1`, `uSync.Command.Setup 16.1.0`)
  in `Clean.Blog`. No v18-compatible release exists yet on NuGet; expect a
  follow-up bump once Kevin Jump publishes one.

## Breaking changes that affect Clean

### 1. OpenAPI: Swashbuckle removed, replaced by `Microsoft.AspNetCore.OpenApi`

- `template/Clean.Headless/Startup/ConfigureSwaggerGenOptions.cs` uses
  `IConfigureOptions<SwaggerGenOptions>` + `SwaggerDoc(...)` — rewrite using
  `builder.Services.AddOpenApi("clean-starter", options =>
  options.AddDocumentTransformer(...))`, setting
  `Title = "Clean starter kit"`, `Version = "Latest"`,
  `Description = "Contains headless endpoints for search, dictionaries and forms"`,
  plus `AddOpenApiDocumentToUi("clean-starter", "Clean starter kit")`.
- `template/Clean.Headless/Startup/WorkshopComposer.cs` (line 11) — replace
  the `ConfigureOptions<ConfigureSwaggerGenOptions>()` call with the new
  registration. The `ConfigureSwaggerGenOptions` class can collapse into the
  composer or be kept as a small helper.
- The Swagger UI URL changes from `/umbraco/swagger` to `/umbraco/openapi`.

### 2. `IPublishedContent.Parent` / `.Children` properties removed

Both are now extension methods in `Umbraco.Extensions` (already imported via
`_ViewImports.cshtml`). Razor views need `()` added:

- `template/Clean.Blog/Views/Author.cshtml:8` —
  `Model.Parent as AuthorList` → `Model.Parent() as AuthorList`
- `template/Clean.Blog/Views/Partials/mainNavigation.cshtml:21` —
  `homePage.Children.Where(...)` → `homePage.Children().Where(...)`
- `template/Clean.Blog/Views/Partials/xmlSitemap.cshtml:14,16,29` — three
  `.Children` references → `.Children()`

Existing `Children<T>()` calls in `Partials/authors.cshtml` and
`latestArticlesRow.cshtml` are already method calls and don't need changes.

### 3. csproj package bumps

For every csproj, bump `Umbraco.Cms.*` from `17.1.0` to `18.0.0-beta2`:

- `template/Clean.Models/Clean.Models.csproj`
- `template/Clean.Core/Clean.Core.csproj`
- `template/Clean.Headless/Clean.Headless.csproj`
- `template/Clean/Clean.csproj` (also bump the two `Clean.Core` /
  `Clean.Headless` PackageReferences to `8.0.0-beta1`)
- `template/Clean.Blog/Clean.Blog.csproj` (bump `Umbraco.Cms` and
  `Umbraco.Cms.DevelopmentMode.Backoffice`; leave uSync untouched)

Bump `<Version>`, `<AssemblyVersion>`, `<InformationalVersion>` from `7.0.5`
to `8.0.0-beta1` on the four packaged projects (`Clean.Models` is unversioned).

## Confirmed NOT broken (do not change)

- **`IEmailSender`** — interface remains; only obsolete `SendAsync` overloads
  without an `expires` parameter were removed. Current call
  `_emailSender.SendAsync(message, emailType: "Contact")` still binds to the
  surviving overload. No change needed in `ContactSurfaceController.cs` or
  `ContactV1Controller.cs`.
- **`IContentTypeBaseServiceProvider`** in `ImportPackageXmlMigration.cs` —
  the `Provider` variant survived; only `IContentTypeBaseService` (without
  "Provider") was removed.
- **`AsyncPackageMigrationBase`** — kept in v18; only the sync
  `MigrationBase` and `PackageMigrationBase` were removed.
- **`IDictionaryItemService.GetAtRootAsync()`** in
  `DictionaryApiV1Controller.cs` and `PackageController.cs` — a different
  API from the removed `GetAtRoot()` (which was on `UmbracoHelper`,
  `IPublishedContentCache`, `IUmbracoContext.Content`).

## Phased execution

1. **Phase 1 — packaged libraries**: bump `Umbraco.Cms.*` to
   `18.0.0-beta2` in all 5 csproj files. Rewrite `ConfigureSwaggerGenOptions.cs`
   and update `WorkshopComposer.cs`. Bump package `<Version>` to
   `8.0.0-beta1`.
2. **Phase 2 — `Clean.Blog` test host**: bump `Umbraco.Cms` and
   `Umbraco.Cms.DevelopmentMode.Backoffice`. Update the four Razor views to
   call `Parent()` / `Children()`.
3. **Phase 3 — verification + docs**: local `dotnet build`, smoke test
   (login, publish home, hit OpenAPI UI at `/umbraco/openapi`). Add an
   "Umbraco 18" install section to `README.md`.

## Risks and open items

- **uSync 17 against Umbraco 18 may fail at runtime.** The pins are kept per
  the chosen strategy; expect a follow-up bump when
  [uSync](https://www.nuget.org/packages/uSync) ships a v18 build (see
  [KevinJump/uSync releases](https://github.com/KevinJump/uSync/releases)).
- **Workflows** under `.github/workflows/` (e.g.
  `test-umbraco-latest-nuget.yml`, `update-packages.yml`) may need a separate
  look if they pin to non-prerelease versions — out of scope for this plan.

## Sources

- [Breaking Changes Overview — CMS 18.latest (Beta)](https://docs.umbraco.com/umbraco-cms/18.latest/get-started/upgrading-and-migrating/version-specific)
- [Umbraco-CMS v18.0.0 release notes](https://releases.umbraco.com/release/umbraco/Umbraco-CMS/18.0.0)
- [API versioning and OpenAPI — CMS 18.latest](https://docs.umbraco.com/umbraco-cms/18.latest/extend-your-project/server-side-extensions/api-versioning-and-openapi)
- [Umbraco.Cms on NuGet](https://www.nuget.org/packages/Umbraco.Cms)
- [uSync on NuGet](https://www.nuget.org/packages/uSync)
