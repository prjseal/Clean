# Show Release Summary Script

## Overview

This script displays a comprehensive summary of the release including version, published packages, and links.

## Script Location

`.github/workflows/powershell/Show-ReleaseSummary.ps1`

## Purpose

Provides a final formatted summary of the release process for workflow logs.

## When It's Used

- **Release Workflow**: Final step (runs even if previous steps fail with `if: always()`)

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Version` | string | Yes | - | The version number that was released |
| `ReleaseTag` | string | Yes | - | The GitHub release tag |
| `IsPrerelease` | string | Yes | - | Boolean string indicating if prerelease |
| `ReleaseUrl` | string | Yes | - | URL to the GitHub release |
| `PackagesPath` | string | No | `.artifacts/nuget` | Path to packages directory |

## What It Does

1. **Displays Header** - Green formatted banner
2. **Shows Version Info** - Version, tag, prerelease status, URL
3. **Lists Packages** - All published packages with NuGet.org links

## Output

```
================================================
Release Summary
================================================
Version: 7.0.0
Release Tag: v7.0.0
Prerelease: false
Release URL: https://github.com/prjseal/Clean/releases/tag/v7.0.0
================================================

Published Packages:
  - Clean.Core.7.0.0.nupkg
    https://www.nuget.org/packages/Clean/7.0.0
  - Clean.Headless.7.0.0.nupkg
    https://www.nuget.org/packages/Clean/7.0.0
  - Clean.7.0.0.nupkg
    https://www.nuget.org/packages/Clean/7.0.0
  - Umbraco.Community.Templates.Clean.7.0.0.nupkg
    https://www.nuget.org/packages/Clean/7.0.0
```

## Usage Examples

```powershell
.\Show-ReleaseSummary.ps1 `
  -Version "7.0.0" `
  -ReleaseTag "v7.0.0" `
  -IsPrerelease "false" `
  -ReleaseUrl "https://github.com/prjseal/Clean/releases/tag/v7.0.0"
```

## Related Documentation

- [workflow-versioning-releases.md](workflow-versioning-releases.md) - Parent workflow

## Notes

- **Always runs** via `if: always()`
- **Informational only** - no actions taken
- Provides **quick links** to NuGet.org packages
- **Green color** for success indication
