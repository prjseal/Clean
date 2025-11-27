# Publish to NuGet Script

## Overview

This script publishes all NuGet packages from the artifacts directory to NuGet.org with comprehensive error handling and reporting.

## Script Location

`.github/workflows/powershell/Publish-ToNuGet.ps1`

## Purpose

Publishes Clean packages to NuGet.org for public consumption, with validation and failure tracking.

## When It's Used

- **Release Workflow**: After packages are created and uploaded as artifacts

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ApiKey` | string | Yes | - | The NuGet API key for authentication |
| `PackagesPath` | string | No | `.artifacts/nuget` | Path to directory containing .nupkg files |

## What It Does

1. **API Key Validation** - Verifies API key is set
2. **Package Discovery** - Finds all .nupkg files
3. **Package Publishing** - Pushes each to NuGet.org with `--skip-duplicate`
4. **Failure Tracking** - Tracks which packages fail
5. **Error Reporting** - Fails workflow if any package fails

## Output

```
================================================
Publishing NuGet Packages to NuGet.org
================================================
Found 4 package(s) to publish:
  - Clean.Core.7.0.0.nupkg
  - Clean.Headless.7.0.0.nupkg
  - Clean.7.0.0.nupkg
  - Umbraco.Community.Templates.Clean.7.0.0.nupkg

Publishing Clean.Core.7.0.0.nupkg to NuGet.org...
✅ Successfully published Clean.Core.7.0.0.nupkg

================================================
Package Publishing Complete
================================================
✅ All packages published successfully!
```

## Usage Examples

```powershell
.\Publish-ToNuGet.ps1 -ApiKey $env:NUGET_API_KEY
```

## Troubleshooting

### Issue: API Key Not Set

**Solution**: Add NUGET_API_KEY to repository secrets

### Issue: Package Already Exists

**Solution**: Use --skip-duplicate (already included)

## Related Documentation

- [workflow-versioning-releases.md](workflow-versioning-releases.md) - Parent workflow
- [script-create-nuget-packages.md](script-create-nuget-packages.md) - Package creation

## Notes

- **Fails workflow** if any package fails to publish
- **Uses --skip-duplicate** to handle existing versions
- **Tracks failures** and reports at end
- **Provides setup instructions** if API key missing
