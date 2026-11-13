# Changelog

## [19.0.0-rc02] - 2026-11-13

Clean rebuilt as if it had been made on a fresh Umbraco 19 install, rather than upgraded through 13, 17 and 18.

### Added
- Reusable blocks: Rich Text blocks in Content Rows can come from the Library. The sample content has a `Reusable Blocks` Library folder with a `Join the Umbraco Community` block, placed on the Codegarden 2026 and Meetups articles, so editing it once updates both. The Rich Text Row element type has Allow in Library turned on, which is how Umbraco 19 offers a block type from the Library tab of the block picker
- `Clean.Core` turns on `Umbraco:CMS:Indexing:IndexExternalBlockElements` unless the site sets it, so the search page and the search API find a page by the text of its reusable blocks

### Changed
- Umbraco's built-in Data Types match a fresh Umbraco 19.0.0-rc1 install: stock names (for example `Single Document Picker`, `Single Media Picker`, `URL Picker`, `Single Select Dropdown`) and stock config. They are filed under `Umbraco Defaults/<Family>` in the Data Types tree
- Clean's own Data Types have plain Title Case names and are filed under `Clean/<Family>`. Their keys are unchanged:
  - `[BlockList] Main Content` is now `Main Content Block List`
  - `[BlockList] Icon List` is now `Social Links`
  - `[MNTP] Authors` is now `Author Picker (single)`, a single document picker instead of the deprecated Multi Node Tree Picker
  - `[ElementPicker] Categories` is now `Category Picker (multiple)`
  - `[MediaPicker] SVG Image` is now `Icon Media Picker`
  - `[MultiUrlPicker] Single Url Picker` is now `Link Picker (single)`
  - `[Dropdown] Spacing` is now `Spacing Dropdown`
  - `[Toggle] Default True` is now `Toggle (default on)`
- The built-in `Richtext editor` Data Type is back to stock. Clean's toolbar and `/dropdownStyles.css` moved to a new `Rich Text (Standard)` Data Type, used by the rich text row and the contact form messages
- Installing the `Clean` package files Umbraco's built-in Data Types under `Umbraco Defaults`. The package now exports every Data Type with its folder, instead of only the ones whose name started with `[`
- Search uses Umbraco Search (`ISearcher`, with Examine as the default provider) through a new `ISiteSearchService` in `Clean.Core`. The search page has paging, and `GET /api/v1/search/getSearchResults` accepts optional `page` and `pageSize` parameters
- `Clean.Headless` now depends on `Clean.Core`
- Sample content and Library Elements were saved again on Umbraco 19, so their stored values are in the shape the Umbraco 19 editors write
- The media types match a fresh install, with Clean's `altText` property on `Image`
- `PageHeaderViewModel.BackgroundImage` is a `MediaWithCrops`
- `Clean.Core` has nullable reference types enabled
- The package install publishes the category elements through the element publishing service, before it publishes the Home branch
- `NextJsRevalidateService` uses `IHttpClientFactory`
- `Clean.Blog` loads an optional `appsettings.Local.json` in debug builds, as a fresh Umbraco 19 project does
- The embedded `package.zip` was regenerated on Umbraco 19. It was still the Umbraco 17 export

### Fixed
- The XML sitemap now leaves out pages with "Hide from XML sitemap" switched on. It read a property that does not exist
- Pagination links keep an existing query string
- Articles without an author no longer throw on the article page, the article list and the search page
- The template package no longer ships a database, logs or build output, which takes it from about 280 MB to about 116 MB
- Missing pages show the Clean Error page with a 404 status, unless `Error404Collection` sets another page
- Pages with Hide From Search turned on are left out of the search page and the search API
- The social sharing image tags use the page's Main Image instead of a `/socialimage.png` that did not exist
- The Delivery API setup steps in the marketplace readmes, the headless guide and the contributing guide include `.AddDeliveryApi()` in `Program.cs`. Umbraco 19 projects, including `Clean.Blog` and sites created from the template, leave it out unless they were created with `--use-delivery-api`, and the Delivery API returns a 500 error without it
- On SQLite, the first boot after installing the `Clean` package could fail with "Failed to acquire write lock" on a slow machine, because Umbraco Search indexing overlapped the URL rebuild Umbraco 19.0.0-rc1 runs after the package migration. During an unattended install, the package now publishes its content once Umbraco has finished starting

### Removed
- The unused `category` and `categoryList` document types and the empty `listPageSettings` element type, with their generated models. Categories are Library Elements
- The `Media Picker (legacy)`, `Multiple Media Picker (legacy)` and `List View - Members` Data Types, which a fresh Umbraco 19 install does not have, and the unused `[Slider] Spacing`
- The legacy grid and unused block grid partial views
- The `Global:SanitizeTinyMce`, `Content:AllowEditInvariantFromNonDefault`, `Content:MacroErrors` and `RuntimeMinification` settings, which Umbraco 19 does not use. Editing shared content from a non-default language is now the "Allow editing shared content" permission
- The block label workaround in `CreateNuGetPackages.ps1`. Umbraco 19.0.0-rc1 exports block labels in the package
- The unused `ArticleList.ViewAll`, `Paging.Page` and `Paging.Of` dictionary items

### Upgrade notes
- Umbraco 19 on .NET 11 does not start if `Umbraco:CMS:Imaging:HMACSecretKey` is not canonical Base64. Correct the key's final character rather than generating a new key, so signed image URLs stay valid. The README shows how
- Umbraco 19 sets `Umbraco:CMS:ModelsBuilder:ModelsMode` to `Nothing` by default unless the site references `Umbraco.Cms.DevelopmentMode.Backoffice`. Clean's views need generated models, so keep that package, which `dotnet new umbraco` adds by default
- `Umbraco:CMS:Imaging:Memory:Enabled` and `Umbraco:CMS:ScheduledPublishing:AlignToClock` now default to `true` in Umbraco 19. Set them to `false` to keep the Umbraco 18 behaviour
- `Connect Timeout` in the connection string no longer sets the database command timeout, which drops to 30 seconds. Set `Command Timeout` or `Umbraco:CMS:Global:DatabaseCommandTimeout` if a site relied on it
- An existing site that upgrades `Clean.Core` gets `IndexExternalBlockElements` turned on. Rebuild the indexes in Settings > Search, then save and publish the pages that use reusable blocks, so the search finds them by the reusable blocks' text

### Known issues
- Umbraco 19 is still a release candidate
- A fresh install writes an `Imaging:HMACSecretKey` into `appsettings.json` on first run
- An existing site that upgrades the `Clean` package does not get the renamed Data Types or folders, because the package import only runs on a site that has not installed Clean before
- In the block list, a reusable block is labelled with its Library element's name, so a hidden reusable block does not show `[HIDDEN]` in the list. The label is shown in the block's Settings dialog
- On Umbraco 19.0.0-rc1, opening a reusable block's Settings in the page editor and saving the page stores a copy of the Library element's content in the page. The page still renders the Library element, but the search index also picks up the copy, so a page can still be found by text that was later removed from the Library element

## [19.0.0-rc01] - 2026-11-12

Release candidate of Clean for Umbraco 19.

### Changed
- Updated Umbraco CMS from 19.0.0-beta1 to 19.0.0-rc1
- Updated uSync from 19.0.0-beta01 to 19.0.0-rc1
- Regenerated ModelsBuilder models for Umbraco 19.0.0-rc1
- Updated the Umbraco package schema (`umbraco-package-schema.json`) for Umbraco 19.0.0-rc1
- README and Umbraco Marketplace install commands use Umbraco.Templates 19.0.0-rc1 and Clean 19.0.0-rc01

### Security
- `Clean.Headless` no longer pins `Microsoft.AspNetCore.WebUtilities`, because Umbraco 19.0.0-rc1 references a fixed version
- `Clean.Headless` still pins `System.Security.Cryptography.Xml` at 11.0.0, because Umbraco 19.0.0-rc1 still brings in the vulnerable 10.0.11 through OpenIddict

### Known issues
- Umbraco 19 is still a release candidate
- A fresh install writes an `Imaging:HMACSecretKey` into `appsettings.json` on first run

## [19.0.0-beta01] - 2026-11-11

Pre-release of Clean for Umbraco 19. From this release, the Clean major version matches the Umbraco major version, so Clean 8.x is followed by Clean 19.x.

### Changed
- Upgraded to Umbraco 19.0.0-beta1 and .NET 11
- Updated uSync to 19.0.0-beta01
- Moved uSync seed data from `uSync/v18` to `uSync/v19`, re-exported by uSync 19
- Regenerated ModelsBuilder models for Umbraco 19
- Element library items now use Umbraco's own package support instead of a custom migration. After install, the package's Elements are published, because the import creates them unpublished
- `Clean` now references `Clean.Core` and `Clean.Headless` as projects, which `dotnet pack` turns into package dependencies
- All GitHub workflows set up .NET 11
- README and Umbraco Marketplace files cover Umbraco 19, with Umbraco 18 now pointing to the `8.x` releases and the `dev/v8` branch
- The release workflow updates the README install commands for Clean 8.x and 19.x releases
- GitHub workflows use the latest action versions (`actions/checkout`, `setup-dotnet`, `setup-node` and `upload-artifact`), which run on Node.js 24 instead of the deprecated Node.js 20, and the test workflows install Node.js 26
- The PR build now runs for pull requests into `dev/` branches as well as `main`

### Security
- `Clean.Headless` pins `System.Security.Cryptography.Xml` and `Microsoft.AspNetCore.WebUtilities` at 11.0.0, which fixes [GHSA-7hqp-7c5m-4vq6](https://github.com/advisories/GHSA-7hqp-7c5m-4vq6), [GHSA-c399-9853-6jmj](https://github.com/advisories/GHSA-c399-9853-6jmj), [GHSA-r955-8q5j-3h83](https://github.com/advisories/GHSA-r955-8q5j-3h83) and [GHSA-x33c-w48q-qrgc](https://github.com/advisories/GHSA-x33c-w48q-qrgc) in Umbraco 19.0.0-beta1's own dependencies

### Fixed
- The inline SVG tag helper no longer throws when an SVG file has no `<svg>` element and a CSS class or `ensure-viewbox` is set
- The build no longer shows nullable or obsolete-API warnings

### Removed
- The custom Element library migration and its embedded config files. Its migration step now runs a no-op, so sites that already ran it can still upgrade
- `Cache=Shared` from the development SQLite connection string, which Umbraco 19 removes on every start

### Known issues
- Umbraco 19 is still in beta
- A fresh install writes an `Imaging:HMACSecretKey` into `appsettings.json` on first run

## [8.0.2] - 2026-11-11

### Changed
- Updated Umbraco CMS from 18.0.1 to 18.3.1
- Updated uSync from 18.0.0 to 18.3.1
- Regenerated ModelsBuilder models for Umbraco 18.3.1
- Release script now keeps `FileVersion` in step with the package version
- Release workflow publishes to NuGet.org with trusted publishing (OIDC) instead of a long-lived API key

### Security
- Fixed Delivery API leaking Public Access protected content through Content Picker / Multi-Node Tree Picker expansion ([GHSA-wr57-hqmp-fgvh](https://github.com/advisories/GHSA-wr57-hqmp-fgvh)), via the Umbraco 18.3.1 update
- `Microsoft.OpenApi` now resolves to 2.12.2, which fixes [GHSA-v5pm-xwqc-g5wc](https://github.com/advisories/GHSA-v5pm-xwqc-g5wc)

### Added
- Contributing guide section on regenerating ModelsBuilder models after schema changes or Umbraco package updates

## [8.0.0] - 2026-06-25

### Changed
- Upgraded to Umbraco 18 (STS)
- Migrated uSync seed data to v18 folder structure
- Regenerated ModelsBuilder models for Umbraco 18

### Fixed
- Resolved build errors introduced by Umbraco 18 breaking changes
- Fixed block list labels not rendering correctly in Umbraco 18
- Fixed Rich Text block label showing `[object Object]`
- Fixed Image Carousel count display in block list labels
- Restored block list label workaround for Umbraco issue #20801

### Added
- API client provisioning at startup with package migration support
- Delivery API setup documentation

## [7.0.6] - 2026-05-14

See [GitHub Releases](https://github.com/prjseal/Clean/releases) for earlier release notes.
