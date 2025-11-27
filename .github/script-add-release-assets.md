# Add Release Assets Script

## Overview

This script uploads NuGet packages to GitHub release assets using the GitHub CLI.

## Script Location

`.github/workflows/powershell/Add-ReleaseAssets.ps1`

## Purpose

Attaches .nupkg files to the GitHub release for download alongside the release notes.

## When It's Used

- **Release Workflow**: After packages are published to NuGet.org

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ReleaseTag` | string | Yes | - | The GitHub release tag to upload assets to |
| `PackagesPath` | string | No | `.artifacts/nuget` | Path to directory containing .nupkg files |

## What It Does

1. **Finds Packages** - Gets all .nupkg files from artifacts
2. **Uploads Each** - Uses `gh release upload` with `--clobber`
3. **Reports Status** - Shows success/warning for each package

## Output

```
================================================
Uploading packages to GitHub Release
================================================
Uploading Clean.Core.7.0.0.nupkg...
✅ Uploaded Clean.Core.7.0.0.nupkg

Uploading Clean.7.0.0.nupkg...
✅ Uploaded Clean.7.0.0.nupkg
```

## Usage Examples

```powershell
.\Add-ReleaseAssets.ps1 -ReleaseTag "v7.0.0"
```

## Related Documentation

- [workflow-versioning-releases.md](workflow-versioning-releases.md) - Parent workflow

## Notes

- Uses **--clobber** to replace existing assets
- **Non-failing** - warnings only
- Requires **GITHUB_TOKEN** with release write permissions
