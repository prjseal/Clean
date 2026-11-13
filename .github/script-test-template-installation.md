# Test Template Installation Script

## Overview

This comprehensive script tests the Clean template installation from local artifacts by installing the template, creating a project, starting the site, and running Playwright tests.

## Script Location

`.github/workflows/powershell/Test-TemplateInstallation.ps1`

## Purpose

Validates that the Clean template can be successfully installed and used to create a new project, and that the resulting site functions correctly.

## When It's Used

- **PR Workflow**: After package installation tests, when the `run-template-tests` input is set on a manual run

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Version` | string | Yes | - | The template version to test |
| `WorkspacePath` | string | Yes | - | The GitHub workspace path |
| `ProjectName` | string | No | TestTemplateProject | The name for the test project |

## What It Does

1. **Test Environment Setup**
   - Creates test directory (based on safe project name)
   - Configures local NuGet packages as source
   - Uninstalls existing Clean templates to avoid conflicts

2. **Template Installation**
   - Installs Clean template from local artifacts
   - Uses exact version being tested
   - Force install to overwrite existing

3. **Project Creation**
   - Creates project using `dotnet new umbraco-starter-clean`
   - Supports custom project names (including periods)
   - Navigates to project directory

4. **Site Startup**
   - Starts Umbraco site in background
   - Waits for site to become responsive (180s timeout)
   - Extracts HTTPS URL from logs

5. **Playwright Testing**
   - Generates PowerShell-based Playwright test script
   - Tests frontend and backoffice functionality
   - Takes screenshots of key pages
   - Verifies template-generated site works correctly
   - Fails straight away if the home page shows that the site did not boot

6. **Cleanup**
   - Stops site process
   - Removes LocalPackages NuGet source

7. **Failure Report**
   - If the Playwright tests fail, prints the warnings and errors from the newest Umbraco log (`UmbracoTraceLog*.json` under the test directory), with each message's placeholders filled in and any exception
   - Exits with the Playwright test's exit code

When the PR workflow runs the template tests, it uploads `site.log`, `site.err` and the Umbraco logs as the `template-test-logs-<version>` artifact, whether the test passes or fails.

## Project Name Handling

The script handles various project name formats:

- **Default**: `TestTemplateProject`
- **Custom**: Any name (e.g., `MyProject`)
- **With Periods**: `Company.Website`

Project names with special characters are sanitized for directory names:
- `Company.Website` → directory: `test-template-Company-Website`

## Test Scenarios

### Template Tests
- Template installs successfully
- Project creates from template
- All required files generated
- Solution structure correct

### Frontend Tests
- Homepage loads
- Clean branding visible
- Navigation works
- Content displays correctly

### Backoffice Tests
- Login page accessible
- Authentication works
- Umbraco backoffice loads
- Clean configuration present

## Output

```
================================================
Testing Template Installation from Local Packages
================================================

Configuring local NuGet packages folder as source...
Local packages path: D:\a\Clean\Clean\.artifacts\nuget

Uninstalling any existing Clean templates...

Installing Clean template version 7.0.1-ci.123 from local packages...

Creating test project using template...
Project name: TestTemplateProject

Starting Umbraco site from template...
Site process started with PID: 12345
Waiting for site to start (timeout: 180s)...
Site is responding at: https://localhost:44321

Running Playwright tests...
✅ Test completed successfully

Screenshots saved to: test-template-TestTemplateProject/TestTemplateProject/screenshots/
```

## Screenshots Generated

- Located in: `test-template-TestTemplateProject/TestTemplateProject/screenshots/`
- Files: homepage.png, login-page.png, backoffice-dashboard.png

## Template Installation Command

```powershell
dotnet new install Umbraco.Community.Templates.Clean::$Version `
  --nuget-source $localPackagesPath `
  --force
```

## Project Creation Command

```powershell
dotnet new umbraco-starter-clean -n $ProjectName
```

Creates:
- `{ProjectName}.sln`
- `{ProjectName}/` directory
- `{ProjectName}.Blog/` project directory
- All template files and structure

## Troubleshooting

### Issue: Template Not Found

**Symptoms**:
```
Unable to find template 'umbraco-starter-clean'
```

**Cause**:
- Template not installed
- Installation failed silently

**Solution**:
- Check template installation output
- Verify package exists in local artifacts

### Issue: Site Fails to Start

**Symptoms**:
```
Timeout reached! Site failed to start.
```

**Possible Causes**:
- Template generated invalid code
- Missing dependencies
- Port conflict

**Solution**:
- Check site.log and site.err files
- Verify template generated correctly
- Check for port conflicts

### Issue: Site Did Not Boot

**Symptoms**:
```
Error during testing: Error: The home page returned HTTP 500 and did not render. The site did not boot:
```

The site process started and listens, but Umbraco failed to boot.

**Solution**:
- Read the Umbraco log errors printed after the test, then the full logs in the `template-test-logs-<version>` artifact
- Check `01-home.png` for the error page

## Related Documentation

- [workflow-pr.md](workflow-pr.md) - Parent workflow
- [script-test-package-installation.md](script-test-package-installation.md) - Package testing

## Notes

- **Tests template installation and usage**
- **Supports custom project names**
- **Uses Playwright** for automated testing
- **Generates screenshots** for verification
- **Uninstalls existing templates** to avoid conflicts
- **Tests both frontend and backoffice**
- **180-second timeout** for site startup
- **Cleans up** after execution
