# Test Package Installation Script

## Overview

This comprehensive script tests the Clean package installation from local artifacts by creating an Umbraco project, installing the package, starting the site, and running Playwright tests.

## Script Location

`.github/workflows/powershell/Test-PackageInstallation.ps1`

## Purpose

Validates that the Clean package can be successfully installed into a fresh Umbraco project and that the resulting site functions correctly.

## When It's Used

- **PR Workflow**: After publishing to GitHub Packages, before template tests

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Version` | string | Yes | The package version to test (e.g., 7.0.1-ci.123) |
| `WorkspacePath` | string | Yes | The GitHub workspace path |

## What It Does

1. **Test Environment Setup**
   - Creates `test-installation` directory
   - Configures local NuGet packages as source
   - Detects Umbraco version from Clean.csproj

2. **Umbraco Project Creation**
   - Installs appropriate Umbraco templates
   - Creates new Umbraco project with SQLite database
   - Adds to solution file

3. **Package Installation**
   - Installs Clean package from local artifacts
   - Uses exact version being tested

4. **Site Startup**
   - Starts Umbraco site in background
   - Waits for site to become responsive (180s timeout)
   - Extracts HTTPS URL from logs

5. **Playwright Testing**
   - Generates PowerShell-based Playwright test script
   - Tests frontend and backoffice functionality
   - Takes screenshots of key pages
   - Verifies Clean components are working

6. **Cleanup**
   - Stops site process
   - Removes LocalPackages NuGet source

## Test Scenarios

### Frontend Tests
- Homepage loads successfully
- Clean branding visible
- Navigation works

### Backoffice Tests
- Login page accessible
- Credentials work (admin@example.com / 1234567890)
- Umbraco backoffice loads
- Clean menu items present

## Output

```
================================================
Testing Package Installation from Local Packages
================================================

Configuring local NuGet packages folder as source...
Local packages path: D:\a\Clean\Clean\.artifacts\nuget

Determining Umbraco version from Clean package...
Umbraco version: 17.0.1

Installing Umbraco templates version 17.0.1...
Creating test Umbraco project...
Installing Clean package version 7.0.1-ci.123 from local packages...

Starting Umbraco site...
Site process started with PID: 12345
Waiting for site to start (timeout: 180s)...
Site is responding at: https://localhost:44321

Running Playwright tests...
✅ Test completed successfully

Screenshots saved to: test-installation/screenshots/
```

## Screenshots Generated

- `homepage.png` - Frontend homepage
- `login-page.png` - Backoffice login
- `backoffice-dashboard.png` - Umbraco dashboard
- Additional screenshots as tests execute

## Playwright Test Script

The script generates and executes a PowerShell-based Playwright test:

```powershell
# Generated test script content includes:
- Installing Playwright
- Creating browser context
- Navigating to homepage
- Taking screenshot
- Logging into backoffice
- Navigating backoffice
- Taking screenshots of key areas
```

## Troubleshooting

### Issue: Site Fails to Start

**Symptoms**:
```
Timeout reached! Site failed to start.
```

**Possible Causes**:
- Port conflict
- Build errors
- Missing dependencies

**Solution**:
- Check site.log and site.err files
- Verify package installed correctly
- Check for port conflicts

### Issue: Playwright Tests Fail

**Symptoms**:
Test script exits with non-zero code

**Possible Causes**:
- Site not fully started
- Login credentials incorrect
- Clean components not installed

**Solution**:
- Review test output
- Check screenshots for clues
- Verify package installation

### Issue: Package Not Found

**Symptoms**:
```
error: Unable to find package 'Clean' with version '7.0.1-ci.123'
```

**Cause**:
- Package not in local artifacts
- LocalPackages source not configured

**Solution**:
- Ensure CreateNuGetPackages ran successfully
- Verify .artifacts/nuget contains packages

## Related Documentation

- [workflow-pr.md](workflow-pr.md) - Parent workflow
- [script-test-template-installation.md](script-test-template-installation.md) - Template testing
- [script-create-nuget-packages.md](script-create-nuget-packages.md) - Package creation

## Notes

- **Full end-to-end test** of package installation
- **Uses Playwright** for automated browser testing
- **Generates screenshots** for verification
- **Tests both frontend and backoffice**
- **SQLite database** for faster setup
- **180-second timeout** for site startup
- **Cleans up** after execution
