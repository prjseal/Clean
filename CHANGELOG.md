# Changelog

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
