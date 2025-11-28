# Get Build Version Script

## Overview

This script queries NuGet.org for the latest published version of the Clean package, intelligently increments it, and creates a CI build version string.

## Script Location

`.github/workflows/powershell/Get-BuildVersion.ps1`

## Purpose

Generates unique, incrementing version numbers for CI builds that don't conflict with published versions and follow semantic versioning precedence rules.

## When It's Used

- **PR Workflow**: After custom NuGet sources are configured, before creating packages

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `PackageId` | string | No | "Clean" | The NuGet package ID to query |
| `BuildNumber` | string | Yes | - | The GitHub Actions build/run number |
| `WorkspacePath` | string | Yes | - | The GitHub workspace path for fallback |

## How It Works

```mermaid
flowchart TD
    Start([Script Start]) --> QueryNuGet[Query NuGet API<br/>api.nuget.org/v3-flatcontainer]
    QueryNuGet --> QuerySuccess{Query<br/>Successful?}

    QuerySuccess -->|No| Fallback[Fallback to .csproj Files<br/>Search multiple files]
    Fallback --> FallbackVersion[Extract Version<br/>Use base version]
    FallbackVersion --> CreateFallbackBuild[Create Build Version<br/>base-ci.buildNumber]
    CreateFallbackBuild --> SetOutput

    QuerySuccess -->|Yes| ParseVersions[Parse All Versions<br/>Separate base from prerelease]
    ParseVersions --> SortVersions[Sort Versions<br/>By base version DESC<br/>Then stable first]
    SortVersions --> GetLatest[Get Latest Version]
    GetLatest --> CheckPrerelease{Is Latest<br/>Prerelease?}

    CheckPrerelease -->|Yes| UseBase[Use Base Version<br/>Strip prerelease suffix]
    CheckPrerelease -->|No| IncrementPatch[Increment Patch Version<br/>X.Y.Z → X.Y.(Z+1)]

    UseBase --> CreateBuildVersion[Create Build Version<br/>base-ci.buildNumber]
    IncrementPatch --> CreateBuildVersion

    CreateBuildVersion --> SetOutput[Set GITHUB_OUTPUT:<br/>version<br/>base_version]
    SetOutput --> End([Exit: Success])

    style Fallback fill:#ffffcc
    style QuerySuccess fill:#e6e6fa
    style CheckPrerelease fill:#e6e6fa
```

## What It Does

1. **NuGet Query**
   - Queries https://api.nuget.org/v3-flatcontainer/clean/index.json
   - Gets all published versions
   - Parses version numbers and prerelease tags

2. **Version Sorting**
   - Sorts by base version (descending)
   - Stable versions prioritized over prerelease
   - Ensures latest version is found correctly

3. **Version Logic**
   - **If latest is stable (e.g., 7.0.0)**: Increment patch → 7.0.1
   - **If latest is prerelease (e.g., 7.0.0-rc.1)**: Use base → 7.0.0
   - This ensures CI builds don't interfere with stable releases

4. **Build Version Format**
   - Format: `{base}-ci.{ci-build-number}` (7-digit zero-padded)
   - Example: `7.0.1-ci.0000123`
   - Sorts after stable, before next version

5. **Fallback Mechanism**
   - Searches for .csproj files if NuGet query fails
   - Priority order: Clean.Blog.csproj, Clean.csproj, Clean.Core.csproj, etc.
   - Extracts version from first found file

## Output

### GitHub Actions Output

```
version=7.0.1-ci.0000123
base_version=7.0.1
```

### Console Output

**Successful Query**:
```
Fetching latest version for package: Clean
Found 150 total versions
Latest version found: 7.0.0
  Version number: 7.0.0
  Is prerelease: False
  Base version for builds: 7.0.1
Build version: 7.0.1-ci.0000123
```

**Latest is Prerelease**:
```
Fetching latest version for package: Clean
Found 160 total versions
Latest version found: 7.0.0-rc.1
  Version number: 7.0.0
  Is prerelease: True
  Base version for builds: 7.0.0
Latest is prerelease, using base version without suffix
Build version: 7.0.0-ci.0000123
```

**Fallback to .csproj**:
```
Error fetching version from NuGet: ...
Falling back to version from .csproj files...
Checking Clean.Blog.csproj...
✓ Found version in Clean.Blog.csproj: 7.0.0
  Using base version: 7.0.0
Using fallback version: 7.0.0-ci.0000123
```

## Usage Examples

### Example 1: In Workflow

```yaml
- name: Get latest NuGet version and create build version
  id: version
  shell: pwsh
  run: |
    ./.github/workflows/powershell/Get-BuildVersion.ps1 `
      -BuildNumber "${{ github.run_number }}" `
      -WorkspacePath "${{ github.workspace }}"
```

### Example 2: Manual Run

```powershell
.\Get-BuildVersion.ps1 `
  -PackageId "Clean" `
  -BuildNumber "123" `
  -WorkspacePath "C:\Projects\Clean"
```

## Version Precedence

The script ensures CI builds sort correctly:

```
7.0.0              (stable release)
7.0.1-ci.0000001   (CI build - next version)
7.0.1-ci.0000002   (CI build - next version)
7.0.1-ci.0000123   (CI build - next version)
7.0.1              (next stable release)
```

**Why this matters**:
- CI builds don't interfere with stable package resolution
- NuGet clients prefer stable over prerelease
- Clear separation between CI and production versions

## Implementation Details

### NuGet API Endpoint

```
https://api.nuget.org/v3-flatcontainer/{packageId}/index.json
```

Returns JSON array of all versions:
```json
{
  "versions": [
    "1.0.0",
    "1.0.1",
    "2.0.0-beta.1",
    "2.0.0"
  ]
}
```

### Version Parsing

```powershell
if ($versionString -match '^([0-9]+\.[0-9]+\.[0-9]+)(.*)$') {
    $baseVersion = $matches[1]
    $prerelease = $matches[2]
}
```

### Sorting Logic

```powershell
$sortedVersions = $parsedVersions | Sort-Object `
  -Property @{Expression = { $_.Version }; Descending = $true}, `
            @{Expression = { $_.IsPrerelease }; Descending = $false}
```

**Result**: 7.0.0 before 7.0.0-rc.1, but 7.0.0-rc.1 before 6.x.x

### Fallback Files (Priority Order)

1. Clean.Blog.csproj
2. Clean.csproj
3. Clean.Core.csproj
4. Clean.Headless.csproj
5. template-pack.csproj

## Troubleshooting

### Issue: NuGet Query Fails

**Solution**: Script falls back to .csproj files automatically

### Issue: Wrong Version Used

**Symptoms**: CI build version doesn't match latest

**Solution**: Check NuGet.org for actual latest version, verify sorting logic

### Issue: No .csproj Files Found

**Symptoms**:
```
⚠ Could not find version in any .csproj file, using default: 1.0.0
```

**Solution**: Ensure at least one .csproj file exists in repository

## Related Documentation

- [workflow-pr.md](workflow-pr.md) - Parent workflow
- [script-show-build-version-info.md](script-show-build-version-info.md) - Next step

## Notes

- **Queries NuGet.org** for latest version
- **Intelligent versioning** - increments or uses base depending on latest
- **CI suffix** ensures builds don't conflict with releases
- **Fallback mechanism** for offline/error scenarios
- **Semantic versioning** compliant
- **Auto-incrementing** - no manual version management needed
