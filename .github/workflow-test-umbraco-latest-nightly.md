# Scheduled - Test Umbraco Latest with Nightly Feed Workflow Documentation

This document describes the automated testing workflow that validates the Clean package with the latest Umbraco nightly builds from MyGet, ensuring early detection of compatibility issues.

## Overview

The test workflow runs daily to test the Clean package against the latest Umbraco pre-release builds from the MyGet nightly feed. It provides early warning of breaking changes in upcoming Umbraco versions before stable releases.

**Key Features**:
- ✅ Daily automated testing against Umbraco nightly builds
- ✅ Flexible source selection for both Umbraco and Clean packages
- ✅ Support for testing specific versions
- ✅ Automated end-to-end testing with Playwright
- ✅ Screenshot capture for visual verification
- ✅ Early detection of Umbraco breaking changes

## Workflow File

Location: `.github/workflows/test-umbraco-latest-nightly.yml`

## When Does It Run?

The workflow triggers in two ways:

### 1. Scheduled Execution (Default)

Runs automatically **daily at 9:00 AM UTC** with nightly feed configuration:
- **Umbraco source**: `nightly-feed` (MyGet)
- **Package source**: `nuget` (NuGet.org)

This provides daily validation against upcoming Umbraco releases.

### 2. Manual Trigger (workflow_dispatch)

Navigate to **Actions** tab → Select **"Scheduled - Test Umbraco Latest with Nightly Feed"** → Click **"Run workflow"**

Configure test parameters:
- **Umbraco source**: Choose between `nuget` or `nightly-feed` (default: `nightly-feed`)
- **Package source**: Choose between `nuget` or `github-packages` (default: `nuget`)
- **Umbraco version**: Specify exact version or leave blank for latest
- **Package version**: Specify exact version or leave blank for latest

## What It Does

The test workflow performs comprehensive integration testing focused on nightly builds:

### 1. **Version Detection**

For scheduled runs, automatically uses:
- **Umbraco**: Latest nightly build from MyGet (includes RC, beta, alpha)
- **Clean**: Latest stable version from NuGet.org

For manual runs, respects the input parameters.

**Umbraco Nightly Feed**: `https://www.myget.org/f/umbracoprereleases/api/v3/index.json`

### 2. **Project Setup**

1. Configures MyGet nightly feed as NuGet source
2. Installs Umbraco templates from selected source
3. Creates fresh Umbraco project with SQLite database
4. Installs Clean package from selected source
5. Configures authentication for GitHub Packages if needed

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
`umbraco-latest-nightly-screenshots-{umbraco-version}-clean-{clean-version}`

## Process Flow

```mermaid
flowchart TD
    Start([Trigger:<br/>Scheduled or Manual]) --> Checkout[1. Checkout Repository<br/>Fetch workflow scripts]

    Checkout --> SetupDotNet[2. Setup .NET 10<br/>Install .NET 10 SDK]

    SetupDotNet --> SetupNode[3. Setup Node.js 20<br/>For Playwright]

    SetupNode --> DetermineMode{Trigger<br/>Type?}

    DetermineMode -->|Scheduled| ScheduledConfig[Use Scheduled Defaults<br/>- Umbraco: nightly-feed<br/>- Package: nuget]
    DetermineMode -->|Manual| ManualConfig[Use Manual Inputs<br/>Or specified parameters]

    ScheduledConfig --> RunScript
    ManualConfig --> RunScript

    RunScript[4. Run Test-LatestNuGetPackages Script<br/>Pass configured parameters]

    RunScript --> ConfigureMyGet[5. Configure MyGet Feed<br/>Add nightly feed as source<br/>If nightly-feed selected]

    ConfigureMyGet --> FetchNightly[6. Fetch Latest Nightly Version<br/>Query MyGet service index<br/>Select latest (includes pre-releases)]

    FetchNightly --> FetchClean{Clean<br/>Source?}

    FetchClean -->|NuGet| FetchCleanNuGet[Fetch Latest from NuGet<br/>Stable versions only]
    FetchClean -->|GitHub Packages| FetchCleanGH[Fetch Latest from GitHub Packages<br/>With authentication]
    FetchClean -->|Specific Version| UseCleanVersion[Use Specified Version]

    FetchCleanNuGet --> InstallTemplates
    FetchCleanGH --> ConfigureGH[Configure GitHub Packages<br/>Add authenticated source]
    ConfigureGH --> InstallTemplates
    UseCleanVersion --> InstallTemplates

    InstallTemplates[7. Install Umbraco Templates<br/>From nightly feed with version]

    InstallTemplates --> CreateProject[8. Create Umbraco Project<br/>- dotnet new umbraco<br/>- SQLite database<br/>- Admin credentials]

    CreateProject --> RestoreProject[9. Restore Project<br/>Explicit restore with all sources<br/>Prevents NuGet hang]

    RestoreProject --> InstallClean[10. Install Clean Package<br/>From selected source]

    InstallClean --> StartSite[11. Start Umbraco Site<br/>- Background process<br/>- Monitor logs<br/>- Max 180s timeout]

    StartSite --> WaitSite{Site Started<br/>Successfully?}

    WaitSite -->|No - Timeout| ShowLogs[Display Error Logs]
    ShowLogs --> End1([End: Site Failed to Start])

    WaitSite -->|Yes| VerifyRunning[12. Verify Site Still Running<br/>Wait additional 5 seconds]

    VerifyRunning --> ProcessCheck{Site Process<br/>Still Active?}

    ProcessCheck -->|No| ProcessFail[Log Exit Code<br/>Display site logs]
    ProcessFail --> End2([End: Process Exited])

    ProcessCheck -->|Yes| InstallPlaywright[13. Install Playwright<br/>- npm init<br/>- npm install playwright<br/>- Install Chromium browser]

    InstallPlaywright --> ExtractKeys[14. Extract uSync Keys<br/>- Content keys (published only)<br/>- Data type keys]

    ExtractKeys --> CreateTestScript[15. Create Playwright Test Script<br/>Call Write-PlaywrightTestScript.ps1<br/>With content keys]

    CreateTestScript --> RunTests[16. Run Playwright Tests<br/>- node test.js<br/>- Navigate pages<br/>- Capture screenshots]

    RunTests --> TestResult{Tests<br/>Passed?}

    TestResult -->|Failed| StopSiteFail[Stop Umbraco Site]
    StopSiteFail --> End3([End: Tests Failed])

    TestResult -->|Passed| StopSiteSuccess[17. Stop Umbraco Site<br/>Graceful shutdown]

    StopSiteSuccess --> UploadScreenshots[18. Upload Screenshots as Artifacts<br/>Name includes both versions]

    UploadScreenshots --> End4([End: Success])

    style ShowLogs fill:#ffcccc
    style ProcessFail fill:#ffcccc
    style End1 fill:#ffcccc
    style End2 fill:#ffcccc
    style End3 fill:#ffcccc
    style UploadScreenshots fill:#ccffcc
    style End4 fill:#ccffcc
    style ConfigureMyGet fill:#e6f3ff
    style FetchNightly fill:#e6f3ff
```

## Input Parameters

All input parameters are optional with defaults optimized for nightly testing:

### umbraco-source

**Type**: Choice (radio button)
**Options**: `nuget`, `nightly-feed`
**Default**: `nightly-feed` (for manual runs)
**Scheduled Run Default**: `nightly-feed`
**Description**: Source to download Umbraco templates from

**Use Cases**:
- `nightly-feed`: Test with latest Umbraco pre-releases from MyGet
- `nuget`: Test with stable Umbraco releases

**MyGet Feed**: `https://www.myget.org/f/umbracoprereleases/api/v3/index.json`

### package-source

**Type**: Choice (radio button)
**Options**: `nuget`, `github-packages`
**Default**: `nuget` (for manual runs)
**Scheduled Run Default**: `nuget`
**Description**: Source to download Clean package from

**Use Cases**:
- `nuget`: Test with official published releases
- `github-packages`: Test with CI builds from pull requests

### umbraco-version

**Type**: String
**Default**: Empty (uses latest)
**Description**: Specific Umbraco version to test

**Examples**:
- Leave blank: Auto-detect latest version from selected source
- `17.0.0-rc.1`: Test with specific release candidate
- `17.0.0-beta.2`: Test with specific beta version

### package-version

**Type**: String
**Default**: Empty (uses latest)
**Description**: Specific Clean package version to test

**Examples**:
- Leave blank: Auto-detect latest version from selected source
- `7.0.0`: Test with Clean 7.0.0 stable
- `7.0.1-ci.42`: Test with specific CI build

## Scripts Used

The workflow uses the following PowerShell scripts:

### Test-LatestNuGetPackages.ps1

**Purpose**: Main testing script that orchestrates the entire test process.

**Location**: `.github/workflows/powershell/Test-LatestNuGetPackages.ps1`

**Documentation**: [script-test-latest-nuget-packages.md](script-test-latest-nuget-packages.md)

**Parameters Used**:
- `-WorkspacePath`: GitHub workspace path
- `-UmbracoTemplateSource`: Set to `nightly-feed` for scheduled runs
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
- Umbraco source: `nightly-feed`
- Package source: `nuget`
- Versions: Latest from each source

**Result**: Tests latest Umbraco nightly build with latest stable Clean from NuGet.org

**Use Case**: Daily validation that Clean is compatible with upcoming Umbraco versions

### Scenario 2: Test Specific Nightly Build

**Configuration**:
```yaml
umbraco-source: nightly-feed
package-source: nuget
umbraco-version: 17.0.0-rc.2
package-version: (blank)
```

**Result**: Tests specific Umbraco RC with latest stable Clean

**Use Case**: Validate compatibility with a specific Umbraco release candidate

### Scenario 3: Test CI Build Against Nightly

**Configuration**:
```yaml
umbraco-source: nightly-feed
package-source: github-packages
umbraco-version: (blank)
package-version: 7.0.1-ci.42
```

**Result**: Tests Clean CI build against latest Umbraco nightly

**Use Case**: Validate PR changes work with upcoming Umbraco version

### Scenario 4: Compare Nightly vs Stable

Run this workflow, then run test-umbraco-latest-nuget.yml and compare results.

**Use Case**: Identify differences between nightly and stable Umbraco builds

## Scheduled Testing

### Daily Nightly Testing

The workflow runs automatically **daily at 9:00 AM UTC** with:
- **Umbraco source**: MyGet nightly feed
- **Package source**: NuGet.org
- **Versions**: Latest from each source

This ensures continuous validation that Clean works with the latest Umbraco development builds, providing early warning of potential breaking changes.

### Coordination with Other Workflows

This workflow complements:
- **test-umbraco-latest-nuget.yml**: Runs at 10:00 AM UTC with stable Umbraco
- **test-umbraco-latest.yml**: Runs weekly on Monday with stable Umbraco

Together, they provide comprehensive coverage across different Umbraco release channels.

## Artifacts

### Screenshots

**Artifact Name**: `umbraco-latest-nightly-screenshots-{umbraco-version}-clean-{clean-version}`

**Example**: `umbraco-latest-nightly-screenshots-17.0.0-rc.2-clean-7.0.0`

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

### MyGet Feed Unavailable

**Error**: "Error fetching from nightly feed"

**Causes**:
- MyGet feed temporarily unavailable
- Network connectivity issues
- Version doesn't exist in feed

**Solution**:
1. Verify MyGet feed URL is accessible: `https://www.myget.org/f/umbracoprereleases/api/v3/index.json`
2. Specify exact version instead of using latest
3. Try again later if feed is temporarily down
4. Check MyGet status page for service issues

### Nightly Build Compatibility Issues

**Error**: "Site process exited prematurely" or build errors

**Causes**:
- Breaking changes in Umbraco nightly build
- API changes not yet compatible with Clean
- Dependency conflicts

**Solution**:
1. Review site error logs for specific errors
2. Check Umbraco nightly build release notes
3. Create issue to track compatibility work
4. Consider pinning to last working nightly version

### Version Detection from MyGet Failed

**Error**: "Could not determine latest version from nightly feed"

**Causes**:
- MyGet service index format changed
- Network timeout
- Authentication required (rare)

**Solution**:
1. Manually specify version using `umbraco-version` parameter
2. Check if feed requires authentication
3. Verify service index structure hasn't changed

### Screenshots Show Broken Pages

**Observation**: Artifacts contain screenshots with errors or blank pages

**Causes**:
- JavaScript errors in nightly build
- Missing assets or resources
- Umbraco initialization issues

**Solution**:
1. Download screenshots to identify specific pages affected
2. Check browser console in Playwright output
3. Test same version combination locally
4. Report issues to Umbraco if bug in nightly build

## Related Documentation

- [workflow-test-umbraco-latest-nuget.md](workflow-test-umbraco-latest-nuget.md) - NuGet stable testing workflow
- [workflow-test-umbraco-latest.md](workflow-test-umbraco-latest.md) - Weekly stable testing workflow
- [script-test-latest-nuget-packages.md](script-test-latest-nuget-packages.md) - Main test script
- [script-write-playwright-test-script.md](script-write-playwright-test-script.md) - Playwright test generator
- [MyGet Umbraco Feed](https://www.myget.org/feed/umbracoprereleases/package/nuget/Umbraco.Cms)

## Best Practices

1. **Monitor daily runs**: Check for failures each morning to catch breaking changes early
2. **Pin working versions**: When a breaking change is found, pin to last working version
3. **Report upstream issues**: File bugs with Umbraco team when nightly builds break compatibility
4. **Update Clean proactively**: Address compatibility issues before Umbraco stable release
5. **Compare with stable**: Use test-umbraco-latest-nuget.yml to identify nightly-specific issues
6. **Document breaking changes**: Track API changes and required Clean updates
7. **Test PRs against nightly**: Ensure new Clean features work with upcoming Umbraco versions

## Configuration Differences

This workflow differs from other test workflows:

| Aspect | test-umbraco-latest-nightly.yml | test-umbraco-latest-nuget.yml | test-umbraco-latest.yml |
|--------|----------------------------------|-------------------------------|-------------------------|
| Schedule | Daily at 9:00 AM UTC | Daily at 10:00 AM UTC | Weekly Monday 9:00 AM UTC |
| Default Umbraco Source | nightly-feed | nuget | nuget |
| Default Package Source | nuget | nuget | nuget |
| Artifact Prefix | umbraco-latest-nightly- | umbraco-latest-nuget- | umbraco-latest- |
| Primary Purpose | Early breaking change detection | Stable version validation | Weekly regression testing |

## Summary

The test Umbraco latest with nightly feed workflow provides:
- ✅ Daily automated testing against Umbraco nightly builds
- ✅ Early detection of breaking changes before stable releases
- ✅ Flexible source configuration for both Umbraco and Clean
- ✅ Comprehensive browser-based testing with Playwright
- ✅ Visual verification through screenshot artifacts
- ✅ Support for testing specific version combinations
- ✅ Integration with uSync content and data type testing
- ✅ Detailed logging and error reporting

This ensures Clean stays compatible with upcoming Umbraco versions and provides early warning of necessary changes before stable releases, reducing the risk of breaking changes affecting users.
