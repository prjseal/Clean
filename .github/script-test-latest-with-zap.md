# Test-LatestWithZap.ps1 Documentation

PowerShell script that sets up a Clean Blog site from the Umbraco.Community.Templates.Clean template and prepares it for OWASP ZAP security testing.

## Synopsis

```powershell
Test-LatestWithZap.ps1
    -WorkspacePath <String>
    [-TemplateSource <String>]
    [-TemplateVersion <String>]
```

## Description

This script installs and configures the Umbraco.Community.Templates.Clean template, creates a Clean Blog project, starts the site, and prepares it for OWASP ZAP security scanning. It handles version detection, template installation, project creation, and site startup with comprehensive error handling and logging.

The script is designed specifically for security testing scenarios where a running Clean Blog site is needed for automated vulnerability scanning.

## Location

`.github/workflows/powershell/Test-LatestWithZap.ps1`

## Parameters

### -WorkspacePath

**Type**: String
**Required**: Yes
**Description**: The GitHub workspace root path where the test Clean Blog site will be created.

**Example**:
```powershell
-WorkspacePath "${{ github.workspace }}"
-WorkspacePath "C:\Projects\Clean"
```

### -TemplateSource

**Type**: String
**Required**: No
**Default**: `nuget`
**Valid Values**: `nuget`, `github-packages`
**Description**: Source to download the Clean template package from.

**Examples**:
```powershell
-TemplateSource "nuget"           # Official NuGet.org releases
-TemplateSource "github-packages" # CI builds from GitHub Packages
```

### -TemplateVersion

**Type**: String
**Required**: No
**Default**: Empty (auto-detect latest)
**Description**: Specific Clean template version to install. If not provided, fetches latest from selected source.

**Examples**:
```powershell
-TemplateVersion "7.0.0"         # Stable release
-TemplateVersion "7.0.1-ci.42"   # CI build
-TemplateVersion ""              # Auto-detect latest
```

## Environment Variables

The script uses the following environment variables:

### GITHUB_TOKEN

**Required**: When using `github-packages` source
**Description**: GitHub authentication token with `packages:read` permission.

**Example**:
```powershell
$env:GITHUB_TOKEN = ${{ secrets.GITHUB_TOKEN }}
```

### GITHUB_REPOSITORY

**Optional**: Auto-detected in GitHub Actions
**Description**: Repository in format `owner/repo`, used to determine package owner for GitHub Packages.

**Example**:
```powershell
$env:GITHUB_REPOSITORY = "prjseal/Clean"
```

### GITHUB_OUTPUT

**Optional**: Auto-provided in GitHub Actions
**Description**: File path for workflow outputs that subsequent steps can use.

**Outputs Written**:
- `clean_template_version`: Version of template being tested
- `site_url`: URL where site is running
- `site_pid`: Process ID for cleanup
- `test_dir`: Test directory path

## Examples

### Example 1: Setup with Latest Stable Template

```powershell
./Test-LatestWithZap.ps1 -WorkspacePath "C:\workspace"
```

**Result**: Installs latest stable Clean template from NuGet.org and creates Clean Blog site

### Example 2: Setup with Specific Template Version

```powershell
./Test-LatestWithZap.ps1 `
  -WorkspacePath "C:\workspace" `
  -TemplateVersion "7.0.0"
```

**Result**: Installs Clean template version 7.0.0 and creates Clean Blog site

### Example 3: Setup with GitHub Packages CI Build

```powershell
$env:GITHUB_TOKEN = "ghp_your_token"
$env:GITHUB_REPOSITORY = "prjseal/Clean"

./Test-LatestWithZap.ps1 `
  -WorkspacePath "C:\workspace" `
  -TemplateSource "github-packages" `
  -TemplateVersion "7.0.1-ci.42"
```

**Result**: Installs Clean template CI build from GitHub Packages

### Example 4: GitHub Actions Usage

```yaml
- name: Setup Clean Template Site for ZAP Testing
  id: setup-site
  shell: pwsh
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    $params = @{
      WorkspacePath = "${{ github.workspace }}"
    }
    if ("${{ inputs.template-source }}" -ne "") {
      $params.TemplateSource = "${{ inputs.template-source }}"
    }
    if ("${{ inputs.template-version }}" -ne "") {
      $params.TemplateVersion = "${{ inputs.template-version }}"
    }
    ./.github/workflows/powershell/Test-LatestWithZap.ps1 @params
```

## Process Flow

```mermaid
flowchart TD
    Start([Script Start]) --> ParseParams[Parse Parameters<br/>Set defaults]

    ParseParams --> DisplayHeader[Display Header<br/>- Script purpose<br/>- Template source]

    DisplayHeader --> GetVersion{Template<br/>Version Provided?}

    GetVersion -->|No| DetectSource{Template<br/>Source?}

    DetectSource -->|NuGet| FetchNuGet[Fetch from NuGet API<br/>Filter stable versions<br/>Select latest]
    DetectSource -->|GitHub Packages| FetchGH[Fetch from GitHub Packages<br/>Authenticate with token<br/>Prefer stable versions]

    GetVersion -->|Yes| UseVersion[Use Provided Version]

    FetchNuGet --> SetOutput
    FetchGH --> SetOutput
    UseVersion --> SetOutput

    SetOutput[Save Version to GITHUB_OUTPUT<br/>For workflow artifact naming]

    SetOutput --> CreateDir[Create Test Directory<br/>- Name: test-clean-template-zap<br/>- Remove if exists<br/>- Set as working directory]

    CreateDir --> ConfigureSource{Template<br/>Source?}

    ConfigureSource -->|NuGet| InstallFromNuGet[Install Template from NuGet<br/>dotnet new install]
    ConfigureSource -->|GitHub Packages| ConfigureGH[Configure GitHub Packages<br/>- Extract repo owner<br/>- Add authenticated source<br/>- Store credentials]

    ConfigureGH --> InstallFromGH[Install Template from GitHub Packages<br/>dotnet new install --add-source]

    InstallFromNuGet --> VerifyInstall
    InstallFromGH --> VerifyInstall

    VerifyInstall[Verify Template Installation<br/>- dotnet new list<br/>- Search for umbraco-starter-clean]

    VerifyInstall --> TemplateFound{Template<br/>Installed?}

    TemplateFound -->|No| ShowError[Display Error<br/>- Expected short name<br/>- List installed templates]
    ShowError --> End1([Exit Code 1:<br/>Template Not Found])

    TemplateFound -->|Yes| CreateProject[Create Clean Blog Project<br/>dotnet new umbraco-starter-clean -n TestCleanProject]

    CreateProject --> VerifyProject[Verify Project Structure<br/>Check for TestCleanProject.Blog.csproj]

    VerifyProject --> ProjectOK{Project<br/>Created?}

    ProjectOK -->|No| ShowProjectError[Display Error<br/>- Expected path<br/>- Show directory contents]
    ShowProjectError --> End2([Exit Code 1:<br/>Project Not Found])

    ProjectOK -->|Yes| RestoreProject[Restore Project<br/>dotnet restore TestCleanProject.Blog.csproj]

    RestoreProject --> RestoreOK{Restore<br/>Success?}

    RestoreOK -->|No| ShowRestoreError[Display Error<br/>Exit code]
    ShowRestoreError --> End3([Exit Code 1:<br/>Restore Failed])

    RestoreOK -->|Yes| StartSite[Start Clean Blog Site<br/>- Start-Process dotnet run<br/>- Redirect to logs<br/>- Background process<br/>- Save PID]

    StartSite --> SavePID[Save PID to Files<br/>- site.pid file<br/>- GITHUB_OUTPUT<br/>- test_dir output]

    SavePID --> WaitLoop[Wait for Site Startup<br/>- Max 180 seconds<br/>- Monitor site.log<br/>- Look for "Now listening"]

    WaitLoop --> CheckStatus{Site<br/>Status?}

    CheckStatus -->|Timeout| ShowTimeout[Display Error<br/>- Show site.log<br/>- Show site.err<br/>- Stop process]
    ShowTimeout --> End4([Exit Code 1:<br/>Startup Timeout])

    CheckStatus -->|Process Exited| ShowExit[Display Error<br/>- Show exit code<br/>- Show logs]
    ShowExit --> End5([Exit Code 1:<br/>Process Died])

    CheckStatus -->|Listening| ExtractURL[Extract Site URL<br/>Parse "Now listening on:" from logs]

    ExtractURL --> WaitBuffer[Wait Additional Time<br/>10 seconds for full readiness]

    WaitBuffer --> VerifyProcess{Process<br/>Still Running?}

    VerifyProcess -->|No| ShowPostExit[Display Error<br/>- Exit code<br/>- Logs]
    ShowPostExit --> End6([Exit Code 1:<br/>Premature Exit])

    VerifyProcess -->|Yes| ExportURL[Export Site URL<br/>Write to GITHUB_OUTPUT]

    ExportURL --> DisplaySuccess[Display Success Summary<br/>- Template version<br/>- Site URL<br/>- Process ID<br/>- Ready for ZAP]

    DisplaySuccess --> End7([Exit Code 0:<br/>Success])

    style ShowError fill:#ffcccc
    style ShowProjectError fill:#ffcccc
    style ShowRestoreError fill:#ffcccc
    style ShowTimeout fill:#ffcccc
    style ShowExit fill:#ffcccc
    style ShowPostExit fill:#ffcccc
    style End1 fill:#ffcccc
    style End2 fill:#ffcccc
    style End3 fill:#ffcccc
    style End4 fill:#ffcccc
    style End5 fill:#ffcccc
    style End6 fill:#ffcccc
    style DisplaySuccess fill:#ccffcc
    style End7 fill:#ccffcc
```

## Output

The script produces detailed console output:

### Header
```
================================================
Setting up Clean Template for ZAP Security Testing
================================================
Clean Template Source: NuGet.org
```

### Version Detection
```
Fetching latest Clean template version from NuGet...
Latest Clean template version: 7.0.0
```

### Template Installation
```
Installing Clean template version 7.0.0...
Template installed successfully

Verifying template installation...
Clean template installed successfully
```

### Project Creation
```
Creating Clean Blog project from template...
Clean Blog project created successfully at TestCleanProject/TestCleanProject.Blog
```

### Project Restore
```
Restoring Clean Blog project...
Restore completed successfully
```

### Site Startup
```
Starting Clean Blog site...
Site process started with PID: 12345
Waiting for site to start (timeout: 180s)...
Site is running at: https://localhost:44359
Waiting additional 10 seconds for site to be fully ready...
Site process is still running (PID: 12345)
```

### Completion
```
================================================
Clean Blog Site Ready for ZAP Security Scanning
Clean Template Version: 7.0.0
Site URL: https://localhost:44359
Process ID: 12345
================================================
```

## Key Features

### 1. Multi-Source Version Detection

Automatically fetches latest template versions from different sources:

```powershell
# NuGet: Stable versions only
$templateResponse = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/umbraco.community.templates.clean/index.json"
$templateVersion = $templateResponse.versions | Where-Object { $_ -notmatch '-' } | Select-Object -Last 1

# GitHub Packages: With authentication, prefer stable
$headers = @{ Authorization = "Bearer $env:GITHUB_TOKEN" }
$templateResponse = Invoke-RestMethod -Uri $versionsUrl -Headers $headers
$stableVersions = $templateResponse.versions | Where-Object { $_ -notmatch '-' }
$templateVersion = if ($stableVersions) { $stableVersions | Select-Object -Last 1 } else { $templateResponse.versions | Select-Object -Last 1 }
```

### 2. GitHub Packages Authentication

Securely configures GitHub Packages with credentials:

```powershell
# Extract repository owner
$repoOwner = if ($env:GITHUB_REPOSITORY) {
    $env:GITHUB_REPOSITORY.Split('/')[0]
} else {
    "prjseal"
}

# Add authenticated source
dotnet nuget add source $ghPackagesUrl `
  --name "GitHubPackages" `
  --username "github" `
  --password "$env:GITHUB_TOKEN" `
  --store-password-in-clear-text

# Install template with authentication
dotnet new install Umbraco.Community.Templates.Clean@$templateVersion `
  --add-source $ghPackagesUrl --force
```

### 3. Template Verification

Verifies template was installed correctly:

```powershell
# List installed templates
Write-Host "`nVerifying template installation..." -ForegroundColor Yellow
$templateList = dotnet new list

# Check for expected short name
if ($templateList -match "umbraco-starter-clean") {
    Write-Host "`nClean template installed successfully" -ForegroundColor Green
    $templateShortName = "umbraco-starter-clean"
} else {
    Write-Host "ERROR: Clean template not found in installed templates" -ForegroundColor Red
    exit 1
}
```

### 4. Project Structure Validation

Ensures project was created with correct structure:

```powershell
# The template creates a .Blog project
$projectPath = "TestCleanProject/TestCleanProject.Blog"

if (-not (Test-Path "$projectPath/TestCleanProject.Blog.csproj")) {
    Write-Host "ERROR: Expected project not found at $projectPath" -ForegroundColor Red
    Write-Host "Directory contents:" -ForegroundColor Yellow
    Get-ChildItem -Recurse
    exit 1
}
```

### 5. Site Startup Monitoring

Monitors site startup with timeout and health checks:

```powershell
# Wait for site to start (max 180 seconds)
while (-not $siteStarted) {
    # Check timeout
    if ((Get-Date) - $startTime -gt (New-TimeSpan -Seconds $timeoutSeconds)) {
        # Output logs and exit
        exit 1
    }

    # Check if process exited prematurely
    if ($process.HasExited) {
        # Output logs and exit
        exit 1
    }

    # Look for "Now listening on:" in logs
    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile -Raw
        if ($logContent -match "Now listening on:\s*(https?://[^\s]+)") {
            $siteUrl = $matches[1]
            $siteStarted = $true
            break
        }
    }

    Start-Sleep -Seconds 2
}
```

### 6. Output Management

Saves outputs for use by workflow:

```powershell
# Save to GitHub output if running in GitHub Actions
if ($env:GITHUB_OUTPUT) {
    "clean_template_version=$templateVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    "site_url=$siteUrl" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    "site_pid=$($process.Id)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    "test_dir=$testDir" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}

# Also save PID to file for reference
$process.Id | Out-File -FilePath $pidFile -NoNewline
```

## API Endpoints Used

### NuGet.org Package Index
**Method**: GET
**URL**: `https://api.nuget.org/v3-flatcontainer/umbraco.community.templates.clean/index.json`
**Response**: JSON array of version strings

### GitHub Packages
**Method**: GET
**URL**: `https://nuget.pkg.github.com/{owner}/index.json`
**Headers**: `Authorization: Bearer {token}`
**Response**: NuGet v3 service index

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - Site is running and ready for ZAP scan |
| 1 | Error - Template not found, project creation failed, site failed to start, or process exited prematurely |

## Output Files

The script creates the following in the test directory:

| File/Directory | Description |
|----------------|-------------|
| `test-clean-template-zap/` | Test workspace directory |
| `test-clean-template-zap/site.log` | Clean Blog site standard output |
| `test-clean-template-zap/site.err` | Clean Blog site error output |
| `test-clean-template-zap/site.pid` | Process ID file |
| `test-clean-template-zap/TestCleanProject/` | Clean Blog project directory |
| `test-clean-template-zap/TestCleanProject/TestCleanProject.Blog/` | Blog project files |

## Workflow Integration

The script is designed to integrate with OWASP ZAP security scanning workflows:

### Step 1: Setup Site (This Script)

```yaml
- name: Setup Clean Template Site for ZAP Testing
  id: setup-site
  shell: pwsh
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    $params = @{
      WorkspacePath = "${{ github.workspace }}"
    }
    ./.github/workflows/powershell/Test-LatestWithZap.ps1 @params
```

### Step 2: Wait for Readiness

```yaml
- name: Wait for Site Readiness
  run: |
    sleep 5
    # Poll site URL to ensure it's responding
```

### Step 3: Run ZAP Scan

```yaml
- name: Run OWASP ZAP Full Scan
  uses: zaproxy/action-full-scan@v0.10.0
  with:
    target: ${{ steps.setup-site.outputs.site_url }}
```

### Step 4: Cleanup

```yaml
- name: Cleanup - Stop Umbraco Site
  if: always()
  shell: pwsh
  run: |
    $sitePid = "${{ steps.setup-site.outputs.site_pid }}"
    if ($sitePid) {
      Stop-Process -Id $sitePid -Force -ErrorAction SilentlyContinue
    }
```

## Troubleshooting

### Template Version Detection Failed

**Error**: "Could not find PackageBaseAddress in GitHub Packages service index"

**Causes**:
- GitHub Packages API endpoint changed
- Missing authentication token
- Package not published yet

**Solution**:
- Specify exact version using `-TemplateVersion`
- Verify `GITHUB_TOKEN` is set
- Check package exists in GitHub Packages UI

### Template Not Found After Installation

**Error**: "ERROR: Clean template not found in installed templates"

**Causes**:
- Template installation failed
- Template short name changed
- Incorrect package name

**Solution**:
- Check installation output for errors
- Verify package name is `Umbraco.Community.Templates.Clean`
- Check if template short name changed from `umbraco-starter-clean`

### Project Creation Failed

**Error**: "ERROR: Expected project not found at TestCleanProject/TestCleanProject.Blog"

**Causes**:
- Template structure changed
- Template creation failed
- Incorrect project path

**Solution**:
- Review directory contents in error output
- Test template locally
- Check if template structure changed in new versions

### Site Startup Timeout

**Error**: "Timeout reached! Site failed to start."

**Causes**:
- Database initialization failure
- Port already in use
- Missing dependencies
- Template compatibility issues

**Solution**:
1. Review `site.log` and `site.err` in output
2. Check for error messages
3. Verify template version compatibility
4. Test locally with same template version

### Site Process Exited Prematurely

**Error**: "Site process exited prematurely with exit code: 1"

**Causes**:
- Runtime error in Clean Blog template
- Configuration issues
- Database access problems

**Solution**:
1. Check `site.log` and `site.err` for error details
2. Look for exception stack traces
3. Test template locally
4. Report bug if template issue

## Dependencies

The script requires the following to be pre-installed:

- **.NET 10 SDK**: For template installation and project creation
- **Node.js 20+**: Required by Clean Blog template
- **PowerShell 7+**: For script execution

## Related Documentation

- [workflow-zap-security-scan.md](workflow-zap-security-scan.md) - ZAP workflow documentation
- [OWASP ZAP Documentation](https://www.zaproxy.org/docs/)
- [dotnet new documentation](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-new)
- [GitHub Packages Documentation](https://docs.github.com/en/packages)

## Best Practices

1. **Use latest by default**: Let script auto-detect unless debugging specific versions
2. **Specify versions for audits**: Pin versions when performing security audits
3. **Test locally first**: Verify template works locally before running in CI
4. **Monitor site logs**: Check logs even on successful runs for warnings
5. **Clean workspace**: Script automatically removes old test directory
6. **Verify outputs**: Check that all outputs are set for workflow use

## Differences from Test-LatestNuGetPackages.ps1

This script differs from `Test-LatestNuGetPackages.ps1`:

| Aspect | Test-LatestWithZap.ps1 | Test-LatestNuGetPackages.ps1 |
|--------|------------------------|------------------------------|
| Purpose | Setup for ZAP security scanning | Full integration testing with Playwright |
| Template | Umbraco.Community.Templates.Clean | Umbraco.Templates (standard) |
| Project Type | Clean Blog | Standard Umbraco |
| Package Installation | No Clean package (it's the template) | Installs Clean package |
| Testing | None (just setup) | Playwright browser tests |
| Output | Site URL and PID | Screenshots |
| Cleanup | Delegated to workflow | Built-in cleanup |

## Version History

- **v1.0**: Initial version with NuGet support
- **v2.0**: Added GitHub Packages support
- **v3.0**: Added template verification and improved error handling
- **v4.0**: Enhanced logging and output management

## Summary

The Test-LatestWithZap script provides:
- ✅ Automated Clean template installation
- ✅ Version detection from multiple sources
- ✅ GitHub Packages authentication support
- ✅ Template verification and validation
- ✅ Clean Blog project creation
- ✅ Site startup with monitoring
- ✅ Comprehensive error handling and logging
- ✅ Workflow integration via GitHub outputs
- ✅ Ready-to-scan site for OWASP ZAP

This script is specifically designed for security testing scenarios, providing a reliable way to set up a Clean Blog site that can be scanned by OWASP ZAP for vulnerabilities.
