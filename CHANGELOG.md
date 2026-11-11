# Changelog

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

### Removed
- The custom Element library migration and its embedded config files. Its migration step now runs a no-op, so sites that already ran it can still upgrade
- `Cache=Shared` from the development SQLite connection string, which Umbraco 19 removes on every start

### Known issues
- Umbraco 19 is still in beta. The build shows security warnings from Umbraco's own dependencies (`System.Security.Cryptography.Xml` 10.0.11 and the pre-release `Microsoft.AspNetCore.WebUtilities`)
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
