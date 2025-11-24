# CreateNuGetPackages.ps1 Documentation

## Overview

The `CreateNuGetPackages.ps1` script automates the process of creating NuGet packages for the Clean Umbraco starter kit. It handles version management, package creation, and includes a temporary workaround for Umbraco BlockList label export issues.

**Location:** `.github/workflows/powershell/CreateNuGetPackages.ps1`

## Prerequisites

- PowerShell 5.x or PowerShell Core 6+
- .NET SDK installed
- Umbraco project must be configured and able to run
- Access to the Clean.Blog project at `https://localhost:44340`
- Valid Umbraco API credentials (configured in the script)

## Parameters

### Required Parameters

- **Version** (string, mandatory)
  - The version number to use for all NuGet packages
  - Format: `X.Y.Z` or `X.Y.Z-suffix` (e.g., `7.0.0` or `7.0.0-rc1`)
  - Used for PackageVersion in .csproj files
  - Base version (without suffix) used for AssemblyVersion and InformationalVersion

### Example Usage

```powershell
# Basic usage
.\CreateNuGetPackages.ps1 -Version "7.0.0"

# Pre-release version
.\CreateNuGetPackages.ps1 -Version "7.0.0-rc1"

# With verbose output
.\CreateNuGetPackages.ps1 -Version "7.0.0" -Verbose
```

## Workflow Integration

This script is a critical component of the CI/CD pipeline and is used by the following GitHub Actions workflows:

### 1. Pull Request Build (`pr-build-packages.yml`)

**Trigger:** Automatically runs on pull requests to the `main` branch

**Purpose:** Validates that package creation works correctly before merging changes

**How it works:**
- Queries NuGet.org to find the latest published Clean package version
- Creates a CI build version: `{base_version}-ci.{build_number}`
- Calls `CreateNuGetPackages.ps1` with the CI version
- Publishes packages to GitHub Packages for testing
- Runs automated installation tests using Playwright
- Creates screenshot artifacts to verify the site renders correctly

**Example version flow:**
- Latest NuGet: `7.0.0`
- PR build version: `7.0.1-ci.123`

**Workflow file:** `.github/workflows/pr-build-packages.yml`

**Key steps:**
```yaml
- name: Run CreateNuGetPackages script
  shell: pwsh
  run: |
    ./.github/workflows/powershell/CreateNuGetPackages.ps1 -Version "${{ steps.version.outputs.version }}"
```

### 2. Release Publishing (`release-nuget.yml`)

**Trigger:** Runs when a GitHub release is published

**Purpose:** Creates and publishes official releases to NuGet.org

**How it works:**
- Extracts version from the release tag (e.g., `v7.0.0` → `7.0.0`)
- Validates version format (SemVer)
- Updates README.md and Umbraco marketplace README files with version information
- Calls `CreateNuGetPackages.ps1` with the release version
- Publishes packages to NuGet.org
- Uploads packages as GitHub release assets
- Creates a PR to update version references in the codebase

**Example version flow:**
- Release tag: `v7.0.0`
- Package version: `7.0.0`

**Workflow file:** `.github/workflows/release-nuget.yml`

**Key steps:**
```yaml
- name: Run CreateNuGetPackages script
  shell: pwsh
  run: |
    ./.github/workflows/powershell/CreateNuGetPackages.ps1 -Version "${{ steps.version.outputs.version }}"
```

### Workflow Dependency Chain

```
┌─────────────────────────────────────────────────────────────────┐
│                     Pull Request Workflow                        │
│  (pr-build-packages.yml)                                        │
├─────────────────────────────────────────────────────────────────┤
│ 1. Get latest version from NuGet.org                            │
│ 2. Create CI version (e.g., 7.0.1-ci.123)                       │
│ 3. → CreateNuGetPackages.ps1 -Version "7.0.1-ci.123"            │
│ 4. Publish to GitHub Packages                                   │
│ 5. Test package & template installation                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Release Workflow                             │
│  (release-nuget.yml)                                            │
├─────────────────────────────────────────────────────────────────┤
│ 1. Extract version from release tag                             │
│ 2. Update README.md and marketplace README files                │
│ 3. → CreateNuGetPackages.ps1 -Version "7.0.0"                   │
│ 4. Publish to NuGet.org                                         │
│ 5. Upload to GitHub release assets                              │
│ 6. Create PR with version updates                               │
└─────────────────────────────────────────────────────────────────┘
```

### Not Used By

The `update-packages.yml` workflow does NOT use this script. It uses `UpdateThirdPartyPackages.ps1` instead to update third-party NuGet dependencies.

## What the Script Does

### 1. Repository Discovery and Setup

- Locates the repository root by searching for the `.git` directory
- Finds the solution root containing `Clean.Blog.csproj`
- Creates the `.artifacts/nuget` directory if it doesn't exist
- Terminates any existing processes related to the template path

### 2. Version Extraction and README Update

- Extracts the Umbraco version from `Clean.csproj`
- Updates `README.md`, `umbraco-marketplace-readme.md`, and `umbraco-marketplace-readme-clean.md` with the new version number
- Updates the following patterns in all README files:
  - `dotnet new install Umbraco.Templates::X.Y.Z`
  - `dotnet add "MyProject" package Clean --version X.Y.Z`
  - `dotnet add "MyProject" package Clean.Core --version X.Y.Z`
  - `dotnet new install Umbraco.Community.Templates.Clean::X.Y.Z`

### 3. Umbraco Project Startup

- Starts the Umbraco project using `dotnet run --project Clean.Blog.csproj`
- Waits for the project to become responsive (up to 12 attempts, 10 seconds each)
- Verifies that `https://localhost:44340/umbraco` is reachable
- SSL certificate validation is bypassed for localhost (necessary for CI/CD with self-signed certificates)

### 4. Package Creation via Umbraco API

**Authentication:**
- Requests a bearer token from the Umbraco Management API
- Endpoint: `/umbraco/management/api/v1/security/back-office/token`
- Uses client credentials flow with hardcoded client ID and secret

**Package Creation:**
- Calls the custom package API: `/api/v1/package/{version}`
- Downloads the package from: `/umbraco/management/api/v1/package/created/{packageId}/download/`
- Saves the package as `package.zip` in the output folder

### 5. BlockList Labels Fix (Temporary Workaround)

**Status:** Temporary workaround for [Umbraco Issue #20801](https://github.com/umbraco/Umbraco-CMS/issues/20801)

**What it does:**
- Extracts the downloaded `package.zip` to a temporary location
- Reads the `package.xml` file
- Reads the uSync configuration from `template/Clean.Blog/uSync/v17/DataTypes/BlockListMainContent.config`
- Extracts BlockList label mappings from the uSync configuration
- Injects the missing labels into the `[BlockList] Main Content` DataType configuration in `package.xml`
- Re-packs the package with the fixed configuration

**To disable:** Set `$FixBlockListLabels = $false` at the top of the script

**When to remove:** Delete the entire workaround section when Umbraco releases a fix for issue #20801

### 6. Version Updates in .csproj Files

**Target files:** All `.csproj` files except:
- `Clean.Blog.csproj`
- `Clean.Models.csproj`

**Updates performed:**
- **PackageVersion / Version:** Set to the full version (e.g., `7.0.0-rc1`)
- **InformationalVersion:** Set to base version without suffix (e.g., `7.0.0`)
- **AssemblyVersion:** Set to base version without suffix (e.g., `7.0.0`)
- **PackageReference for Clean.* packages:** Updated to match the new version

### 7. Clean Build Environment

- Empties all `bin` folders in the repository (excluding `.vs` folders)
- Ensures a clean build environment for package creation

### 8. NuGet Package Building

**Build order** (to satisfy dependencies):
1. **Clean.Core** - Built and packed first
2. **Clean.Headless** - Built and packed second (may depend on Clean.Core)
3. **Clean** - Built and packed third (depends on Clean.Core and Clean.Headless)
4. **template-pack** - Packed last (template package)

**Process:**
- Adds a temporary local NuGet source (`CleanLocalPackages`) pointing to `.artifacts/nuget`
- Builds each project with `--configuration Release`
- Packs with `--no-build` to use the existing build artifacts
- Copies intermediate packages to the local NuGet source immediately after packing
- Removes the temporary local source after all builds complete

### 9. Package Collection

- Finds all `.nupkg` files in `Release` folders matching the version
- Copies all packages to `.artifacts/nuget`
- Displays the list of generated packages

### 10. Cleanup

- Stops the Umbraco process
- Removes temporary extraction folders
- Removes the temporary local NuGet source

## Generated Packages

The script typically generates the following NuGet packages:

1. **Clean.Core.{Version}.nupkg** - Core functionality package
2. **Clean.Headless.{Version}.nupkg** - Headless CMS functionality
3. **Clean.{Version}.nupkg** - Main Clean starter kit package
4. **Umbraco.Community.Templates.Clean.{Version}.nupkg** - Template package for `dotnet new`

All packages are copied to: `.artifacts/nuget/`

## API Credentials

**Hardcoded in script:**
- **Client ID:** `umbraco-back-office-clean-api-user`
- **Client Secret:** `c9DK0CxvRWklbjR`

**Security Note:** These credentials are used for local package creation and should match the Umbraco API configuration in the Clean.Blog project.

## Known Issues and Workarounds

### 1. Umbraco BlockList Label Export (Issue #20801)

**Problem:** Umbraco doesn't export BlockList labels when creating packages via the Management API.

**Workaround:** The script includes the `Fix-BlockListLabels` function that:
- Reads labels from the uSync configuration
- Injects them into the package.xml
- Removes markdown bold markers (`**`) from labels

**Status:** Temporary - Remove when Umbraco fixes the issue

### 2. SSL Certificate Validation

**Problem:** CI/CD environments may use self-signed certificates.

**Solution:** The script bypasses SSL certificate validation for localhost requests using:
- `SkipCertificateCheck` parameter (PowerShell Core 6+)
- `TrustAllCertsPolicy` custom class (Windows PowerShell 5.x)

## Troubleshooting

### Umbraco fails to start

**Symptoms:** Script exits with "ERROR: Umbraco failed to start after 12 attempts"

**Solutions:**
- Check that the Clean.Blog project builds successfully
- Verify that port 44340 is not already in use
- Review Umbraco startup logs for errors
- Increase `$maxRetries` if the project needs more time to start

### Package download fails

**Symptoms:** HTTP errors when calling the package API

**Solutions:**
- Verify the Umbraco project is running
- Check that the API credentials match the Umbraco configuration
- Ensure the custom package API endpoint is configured correctly
- Verify the version parameter is valid

### NU1102 errors during build

**Symptoms:** NuGet package dependency errors

**Solutions:**
- The script builds packages in dependency order to prevent this
- Ensure the local NuGet source is added correctly
- Check that intermediate packages are being copied to `.artifacts/nuget`

### BlockList labels not applied

**Symptoms:** Package.xml doesn't contain BlockList labels

**Solutions:**
- Verify `$FixBlockListLabels = $true`
- Check that the uSync config exists at the expected path
- Ensure the `package.xml` contains the `[BlockList] Main Content` DataType
- Review verbose output for warnings

### Version not updated in .csproj files

**Symptoms:** Some projects still have old version numbers

**Solutions:**
- Check if the file is in the exclusion list
- Verify the .csproj file has a `<PropertyGroup>` element
- Review the script output for which files were updated
- Ensure the .csproj file is not in `bin` or `obj` folders

## Output

**Console output includes:**
- Umbraco startup status
- API authentication status
- Package download confirmation
- BlockList label fix details (before/after comparison)
- List of updated .csproj files
- Build and pack status for each project
- List of generated NuGet packages
- Final package destination path

**Artifacts:**
- All `.nupkg` files copied to `.artifacts/nuget/`
- Updated `README.md`, `umbraco-marketplace-readme.md`, and `umbraco-marketplace-readme-clean.md` with new version numbers
- Updated `.csproj` files with new version numbers

## Environment Compatibility

**PowerShell Versions:**
- Windows PowerShell 5.x
- PowerShell Core 6+
- PowerShell 7+

**Operating Systems:**
- Windows
- macOS (with PowerShell Core)
- Linux (with PowerShell Core)

**SSL Handling:**
- Windows PowerShell 5.x: Uses `ServicePointManager` and `TrustAllCertsPolicy`
- PowerShell Core 6+: Uses `-SkipCertificateCheck` parameter

## Maintenance

**When to update this script:**

1. **Remove BlockList workaround** when Umbraco fixes issue #20801
   - Delete the `Fix-BlockListLabels` function (lines 15-113)
   - Delete the workaround section (lines 474-523)
   - Set `$FixBlockListLabels = $false` or remove the variable

2. **Update API credentials** if the Umbraco configuration changes
   - Update `client_id` and `client_secret` in the `$tokenBody` (lines 405-408)

3. **Add new projects** to the build order
   - Add project discovery (similar to lines 690-700)
   - Add build/pack step in the appropriate order

4. **Change port or URL** if the Umbraco project configuration changes
   - Update all references to `https://localhost:44340`

## Related Files

- `.github/workflows/powershell/CreateNuGetPackages.ps1` - The script itself
- `Clean.Blog.csproj` - Umbraco project that gets started
- `Clean.csproj` - Main package project
- `Clean.Core.csproj` - Core functionality package
- `Clean.Headless.csproj` - Headless CMS package
- `template-pack.csproj` - Template package
- `README.md` - Updated with version numbers
- `umbraco-marketplace-readme.md` - Umbraco marketplace README, updated with version numbers
- `umbraco-marketplace-readme-clean.md` - Umbraco marketplace README for Clean package, updated with version numbers
- `template/Clean.Blog/uSync/v17/DataTypes/BlockListMainContent.config` - Source of BlockList labels

## Support

For issues or questions:
- Review the console output for error messages
- Use `-Verbose` flag for detailed logging
- Check the Umbraco logs for API-related issues
- Verify that all prerequisites are met
