# Scheduled - Test Umbraco Latest with NuGet Workflow Documentation

This document describes the automated testing workflow that validates the Clean package with the latest stable Umbraco releases from NuGet.org, ensuring continuous compatibility with production-ready versions.

## Overview

The test workflow runs daily to test the Clean package against the latest stable Umbraco releases from NuGet.org. It provides continuous validation that Clean works correctly with officially published Umbraco versions that users are running in production.

**Key Features**:
- ✅ Daily automated testing against stable Umbraco releases
- ✅ Flexible source selection for both Umbraco and Clean packages
- ✅ Support for testing specific versions
- ✅ Automated end-to-end testing with Playwright
- ✅ Screenshot capture for visual verification
- ✅ Production readiness validation

## Workflow File

Location: `.github/workflows/test-umbraco-latest-nuget.yml`

## When Does It Run?

The workflow triggers in two ways:

### 1. Scheduled Execution (Default)

Runs automatically **daily at 10:00 AM UTC** with NuGet stable configuration:
- **Umbraco source**: `nuget` (NuGet.org stable releases)
- **Package source**: `nuget` (NuGet.org)

This provides daily validation against stable Umbraco releases that users run in production.

### 2. Manual Trigger (workflow_dispatch)

Navigate to **Actions** tab → Select **"Scheduled - Test Umbraco Latest with NuGet"** → Click **"Run workflow"**

Configure test parameters:
- **Umbraco source**: Choose between `nuget` or `nightly-feed` (default: `nuget`)
- **Package source**: Choose between `nuget` or `github-packages` (default: `nuget`)
- **Umbraco version**: Specify exact version or leave blank for latest
- **Package version**: Specify exact version or leave blank for latest

## What It Does

The test workflow performs comprehensive integration testing focused on stable releases:

### 1. **Version Detection**

For scheduled runs, automatically uses:
- **Umbraco**: Latest stable version from NuGet.org (excludes pre-releases)
- **Clean**: Latest stable version from NuGet.org (excludes pre-releases)

For manual runs, respects the input parameters.

### 2. **Project Setup**

1. Installs Umbraco templates from selected source
2. Creates fresh Umbraco project with SQLite database
3. Installs Clean package from selected source
4. Configures authentication for GitHub Packages if needed

### 3. **Site Testing**

1. Starts Umbraco site in background (max 180 seconds timeout)
2. Waits for site to become available
3. Validates site is running and accessible
4. Ensures process stability with additional wait time

### 4. **Browser Automation Testing**

Uses Playwright with Chromium to:
- Navigate the home page
- Discover internal links automatically
- Visit up to 10 pages across the site
- Test Umbraco admin login page
- Capture full-page screenshots of each page
- Verify content keys from uSync files
- Test data type keys from uSync files

### 5. **Artifact Upload**

Screenshots are uploaded as workflow artifacts with naming pattern:
`umbraco-latest-nuget-screenshots-{umbraco-version}-clean-{clean-version}`

## Process Flow

```mermaid
flowchart TD
    Start([Trigger:<br/>Scheduled or Manual]) --> Checkout[1. Checkout Repository<br/>Fetch workflow scripts]

    Checkout --> SetupDotNet[2. Setup .NET 10<br/>Install .NET 10 SDK]

    SetupDotNet --> SetupNode[3. Setup Node.js 20<br/>For Playwright]

    SetupNode --> DetermineMode{Trigger<br/>Type?}

    DetermineMode -->|Scheduled| ScheduledConfig[Use Scheduled Defaults<br/>- Umbraco: nuget<br/>- Package: nuget]
    DetermineMode -->|Manual| ManualConfig[Use Manual Inputs<br/>Or specified parameters]

    ScheduledConfig --> RunScript
    ManualConfig --> RunScript

    RunScript[4. Run Test-LatestNuGetPackages Script<br/>Pass configured parameters]

    RunScript --> FetchUmbraco[5. Fetch Latest Umbraco Version<br/>Query NuGet.org API<br/>Filter stable only (exclude pre-releases)]

    FetchUmbraco --> FetchClean{Clean<br/>Source?}

    FetchClean -->|NuGet| FetchCleanNuGet[Fetch Latest from NuGet<br/>Filter stable only]
    FetchClean -->|GitHub Packages| FetchCleanGH[Fetch Latest from GitHub Packages<br/>With authentication]
    FetchClean -->|Specific Version| UseCleanVersion[Use Specified Version]

    FetchCleanNuGet --> InstallTemplates
    FetchCleanGH --> ConfigureGH[Configure GitHub Packages<br/>Add authenticated source]
    ConfigureGH --> InstallTemplates
    UseCleanVersion --> InstallTemplates

    InstallTemplates[6. Install Umbraco Templates<br/>From NuGet with version]

    InstallTemplates --> CreateProject[7. Create Umbraco Project<br/>- dotnet new umbraco<br/>- SQLite database<br/>- Admin credentials]

    CreateProject --> RestoreProject[8. Restore Project<br/>Explicit restore with all sources<br/>Prevents NuGet hang]

    RestoreProject --> InstallClean[9. Install Clean Package<br/>From selected source]

    InstallClean --> StartSite[10. Start Umbraco Site<br/>- Background process<br/>- Monitor logs<br/>- Max 180s timeout]

    StartSite --> WaitSite{Site Started<br/>Successfully?}

    WaitSite -->|No - Timeout| ShowLogs[Display Error Logs]
    ShowLogs --> End1([End: Site Failed to Start])

    WaitSite -->|Yes| VerifyRunning[11. Verify Site Still Running<br/>Wait additional 5 seconds]

    VerifyRunning --> ProcessCheck{Site Process<br/>Still Active?}

    ProcessCheck -->|No| ProcessFail[Log Exit Code<br/>Display site logs]
    ProcessFail --> End2([End: Process Exited])

    ProcessCheck -->|Yes| InstallPlaywright[12. Install Playwright<br/>- npm init<br/>- npm install playwright<br/>- Install Chromium browser]

    InstallPlaywright --> ExtractKeys[13. Extract uSync Keys<br/>- Content keys (published only)<br/>- Data type keys]

    ExtractKeys --> CreateTestScript[14. Create Playwright Test Script<br/>Call Write-PlaywrightTestScript.ps1<br/>With content keys]

    CreateTestScript --> RunTests[15. Run Playwright Tests<br/>- node test.js<br/>- Navigate pages<br/>- Capture screenshots]

    RunTests --> TestResult{Tests<br/>Passed?}

    TestResult -->|Failed| StopSiteFail[Stop Umbraco Site]
    StopSiteFail --> End3([End: Tests Failed])

    TestResult -->|Passed| StopSiteSuccess[16. Stop Umbraco Site<br/>Graceful shutdown]

    StopSiteSuccess --> UploadScreenshots[17. Upload Screenshots as Artifacts<br/>Name includes both versions]

    UploadScreenshots --> End4([End: Success])

    style ShowLogs fill:#ffcccc
    style ProcessFail fill:#ffcccc
    style End1 fill:#ffcccc
    style End2 fill:#ffcccc
    style End3 fill:#ffcccc
    style UploadScreenshots fill:#ccffcc
    style End4 fill:#ccffcc
    style FetchUmbraco fill:#e6f3ff
    style FetchCleanNuGet fill:#e6f3ff
```

## Input Parameters

All input parameters are optional with defaults optimized for stable testing:

### umbraco-source

**Type**: Choice (radio button)
**Options**: `nuget`, `nightly-feed`
**Default**: `nuget` (for manual runs)
**Scheduled Run Default**: `nuget`
**Description**: Source to download Umbraco templates from

**Use Cases**:
- `nuget`: Test with stable Umbraco releases (default, recommended)
- `nightly-feed`: Test with latest Umbraco pre-releases from MyGet

### package-source

**Type**: Choice (radio button)
**Options**: `nuget`, `github-packages`
**Default**: `nuget` (for manual runs)
**Scheduled Run Default**: `nuget`
**Description**: Source to download Clean package from

**Use Cases**:
- `nuget`: Test with official published releases (default, recommended)
- `github-packages`: Test with CI builds from pull requests

### umbraco-version

**Type**: String
**Default**: Empty (uses latest stable)
**Description**: Specific Umbraco version to test

**Examples**:
- Leave blank: Auto-detect latest stable version from NuGet.org
- `15.0.0`: Test with Umbraco 15.0.0
- `15.1.2`: Test with specific patch version

### package-version

**Type**: String
**Default**: Empty (uses latest stable)
**Description**: Specific Clean package version to test

**Examples**:
- Leave blank: Auto-detect latest stable version from NuGet.org
- `7.0.0`: Test with Clean 7.0.0
- `7.0.1`: Test with specific patch version

## Scripts Used

The workflow uses the following PowerShell scripts:

### Test-LatestNuGetPackages.ps1

**Purpose**: Main testing script that orchestrates the entire test process.

**Location**: `.github/workflows/powershell/Test-LatestNuGetPackages.ps1`

**Documentation**: [script-test-latest-nuget-packages.md](script-test-latest-nuget-packages.md)

**Parameters Used**:
- `-WorkspacePath`: GitHub workspace path
- `-UmbracoTemplateSource`: Set to `nuget` for scheduled runs
- `-PackageSource`: Set to `nuget` for scheduled runs
- `-UmbracoVersion`: Optional specific version
- `-CleanVersion`: Optional specific Clean version

### Get-UsyncKeys.ps1

**Purpose**: Extracts content and data type keys from uSync files for testing.

**Location**: `.github/workflows/powershell/Get-UsyncKeys.ps1`

**Features**:
- Extracts published content keys
- Extracts data type keys
- Used for comprehensive page testing

### Write-PlaywrightTestScript.ps1

**Purpose**: Generates the Playwright JavaScript test file for browser automation.

**Location**: `.github/workflows/powershell/Write-PlaywrightTestScript.ps1`

**Documentation**: [script-write-playwright-test-script.md](script-write-playwright-test-script.md)

## Example Usage Scenarios

### Scenario 1: Default Scheduled Run

**Configuration**: (Automatic daily run)
- Umbraco source: `nuget`
- Package source: `nuget`
- Versions: Latest stable from each source

**Result**: Tests latest stable Umbraco with latest stable Clean from NuGet.org

**Use Case**: Daily validation that Clean works with production Umbraco versions

### Scenario 2: Test Specific Stable Version

**Configuration**:
```yaml
umbraco-source: nuget
package-source: nuget
umbraco-version: 15.0.0
package-version: (blank)
```

**Result**: Tests specific Umbraco stable version with latest Clean

**Use Case**: Regression testing or validation of specific version compatibility

### Scenario 3: Test CI Build Against Stable

**Configuration**:
```yaml
umbraco-source: nuget
package-source: github-packages
umbraco-version: (blank)
package-version: 7.0.1-ci.42
```

**Result**: Tests Clean CI build against latest stable Umbraco

**Use Case**: Validate PR changes work with current stable Umbraco version

### Scenario 4: Test Patch Version

**Configuration**:
```yaml
umbraco-source: nuget
package-source: nuget
umbraco-version: 15.1.2
package-version: 7.0.1
```

**Result**: Tests exact patch versions

**Use Case**: Validate compatibility with specific patch releases

### Scenario 5: Pre-Release Testing

**Configuration**:
```yaml
umbraco-source: nightly-feed
package-source: nuget
umbraco-version: (blank)
package-version: (blank)
```

**Result**: Tests against Umbraco nightly with stable Clean

**Use Case**: Compare stable vs nightly behavior (usually done with nightly workflow)

## Scheduled Testing

### Daily Stable Testing

The workflow runs automatically **daily at 10:00 AM UTC** (one hour after the nightly workflow) with:
- **Umbraco source**: NuGet.org stable releases
- **Package source**: NuGet.org
- **Versions**: Latest stable versions (excludes pre-releases)

This ensures continuous validation that Clean works with the Umbraco versions users run in production environments.

### Coordination with Other Workflows

This workflow complements:
- **test-umbraco-latest-nightly.yml**: Runs at 9:00 AM UTC with nightly Umbraco
- **test-umbraco-latest.yml**: Runs weekly on Monday with stable Umbraco

Together, they provide comprehensive coverage:
- **Nightly workflow**: Early warning of breaking changes
- **NuGet workflow**: Production readiness validation
- **Weekly workflow**: Weekly regression check

## Artifacts

### Screenshots

**Artifact Name**: `umbraco-latest-nuget-screenshots-{umbraco-version}-clean-{clean-version}`

**Example**: `umbraco-latest-nuget-screenshots-15.0.0-clean-7.0.0`

**Contents**: Full-page PNG screenshots of:
- `01-home.png`: Home page
- `02-{page}.png` through `11-{page}.png`: Discovered pages
- `{N}-umbraco-login.png`: Umbraco admin login page

**Retention**: 90 days (GitHub default)

**Access**: Actions tab → Workflow run → Artifacts section

## Permissions

The workflow requires the following GitHub permissions:

- **contents: read** - To checkout repository and access scripts
- **packages: read** - To download packages from GitHub Packages (when using that source)
- **pull-requests: read** - To access PR-related information if triggered from PR context

## Troubleshooting

### Latest Version Not Found

**Error**: "No latest version found for Umbraco.Cms"

**Causes**:
- NuGet.org API temporarily unavailable
- Network connectivity issues
- API response format changed

**Solution**:
1. Verify NuGet.org is accessible: `https://api.nuget.org/v3-flatcontainer/umbraco.cms/index.json`
2. Specify exact version instead of using latest
3. Try again later if API is temporarily down
4. Check workflow logs for detailed error messages

### Stable Version Compatibility Issue

**Error**: "Site process exited prematurely" with stable versions

**Causes**:
- Bug in specific stable Umbraco version
- Clean package incompatibility
- Dependency version conflicts

**Solution**:
1. Review site error logs for specific errors
2. Test same version combination locally
3. Check Clean package release notes for known issues
4. Report bug if issue is reproducible
5. Consider pinning to previous working stable version

### Pre-Release Filtered Out

**Observation**: Workflow uses older version when latest has pre-release

**Cause**: This is expected behavior - scheduled runs filter out pre-releases

**Solution**:
- This is working as designed for production stability
- Use `test-umbraco-latest-nightly.yml` for pre-release testing
- Manually specify pre-release version if needed for testing

### Screenshots Show Production Issues

**Observation**: Screenshots reveal visual or functional issues

**Causes**:
- CSS rendering issues
- JavaScript errors
- Content rendering problems
- Theme compatibility issues

**Solution**:
1. Download and review screenshot artifacts
2. Test locally with same Umbraco version
3. Investigate browser console errors
4. Fix identified issues and re-test

## Related Documentation

- [workflow-test-umbraco-latest-nightly.md](workflow-test-umbraco-latest-nightly.md) - Nightly pre-release testing workflow
- [workflow-test-umbraco-latest.md](workflow-test-umbraco-latest.md) - Weekly stable testing workflow
- [script-test-latest-nuget-packages.md](script-test-latest-nuget-packages.md) - Main test script
- [script-write-playwright-test-script.md](script-write-playwright-test-script.md) - Playwright test generator
- [general-consuming-packages.md](general-consuming-packages.md) - Installing packages guide

## Best Practices

1. **Monitor daily runs**: Check results each day to catch stable version issues
2. **Compare with nightly**: Cross-reference failures between nightly and stable workflows
3. **Test before releasing**: Run manually before publishing new Clean versions
4. **Use for regression testing**: Specify exact versions to validate bug fixes
5. **Document stable incompatibilities**: Track issues with specific Umbraco stable versions
6. **Validate user reports**: Reproduce user-reported issues with specific stable versions
7. **Keep stable as default**: Always prefer stable testing over pre-release for production validation

## Configuration Differences

This workflow differs from other test workflows:

| Aspect | test-umbraco-latest-nuget.yml | test-umbraco-latest-nightly.yml | test-umbraco-latest.yml |
|--------|------------------------------|----------------------------------|-------------------------|
| Schedule | Daily at 10:00 AM UTC | Daily at 9:00 AM UTC | Weekly Monday 9:00 AM UTC |
| Default Umbraco Source | nuget (stable) | nightly-feed (pre-release) | nuget (stable) |
| Default Package Source | nuget | nuget | nuget |
| Artifact Prefix | umbraco-latest-nuget- | umbraco-latest-nightly- | umbraco-latest- |
| Primary Purpose | Production stability validation | Early breaking change detection | Weekly regression testing |
| Version Filter | Stable only (no pre-releases) | Latest including pre-releases | Stable only (no pre-releases) |

## Production Readiness Validation

This workflow serves as the **production readiness gate** by:

### 1. Testing Real-World Scenarios
- Uses stable Umbraco versions that users run in production
- Tests with official NuGet packages, not CI builds
- Validates the exact packages users will install

### 2. Ensuring Compatibility
- Confirms Clean works with current stable Umbraco
- Detects package dependency conflicts
- Validates all Clean features function correctly

### 3. Preventing Regressions
- Catches breaking changes before they affect users
- Validates each Clean release against stable Umbraco
- Ensures patches don't introduce new issues

### 4. Supporting Users
- Provides confidence that Clean + stable Umbraco works
- Validates version combinations users request support for
- Reproduces user-reported issues with specific versions

## Summary

The test Umbraco latest with NuGet workflow provides:
- ✅ Daily automated testing against stable Umbraco releases
- ✅ Production readiness validation for Clean package
- ✅ Flexible source configuration for testing scenarios
- ✅ Comprehensive browser-based testing with Playwright
- ✅ Visual verification through screenshot artifacts
- ✅ Support for testing specific stable version combinations
- ✅ Integration with uSync content and data type testing
- ✅ Detailed logging and error reporting
- ✅ Filtering of pre-release versions for production stability

This ensures Clean works reliably with stable Umbraco versions that users run in production environments, providing confidence that the package is production-ready and compatible with officially released Umbraco versions.
