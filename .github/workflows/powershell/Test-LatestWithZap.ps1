<#
.SYNOPSIS
    Sets up Clean template project for OWASP ZAP security testing.

.DESCRIPTION
    This script installs the latest Umbraco.Community.Templates.Clean template,
    creates a Clean Blog project, starts the site, and prepares it for OWASP ZAP security scanning.
    This allows testing security configurations directly in the Clean.Blog starter project.

.PARAMETER WorkspacePath
    The GitHub workspace path

.PARAMETER TemplateSource
    Optional template source to use: 'nuget' or 'github-packages'. Defaults to 'nuget'.

.PARAMETER TemplateVersion
    Optional specific Clean template version to test. If not provided, uses latest stable version.

.EXAMPLE
    .\Test-LatestWithZap.ps1 -WorkspacePath "/workspace"

.EXAMPLE
    .\Test-LatestWithZap.ps1 -WorkspacePath "/workspace" -TemplateVersion "7.0.0"

.EXAMPLE
    .\Test-LatestWithZap.ps1 -WorkspacePath "/workspace" -TemplateSource "github-packages"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('nuget', 'github-packages')]
    [string]$TemplateSource = 'nuget',

    [Parameter(Mandatory = $false)]
    [string]$TemplateVersion
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Setting up Clean Template for ZAP Security Testing" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$templateSourceDisplay = if ($TemplateSource -eq 'github-packages') { "GitHub Packages" } else { "NuGet.org" }
Write-Host "Clean Template Source: $templateSourceDisplay" -ForegroundColor Cyan

# Get Clean template version (use provided or fetch latest)
if ([string]::IsNullOrWhiteSpace($TemplateVersion)) {
    if ($TemplateSource -eq 'nuget') {
        Write-Host "`nFetching latest Clean template version from NuGet..." -ForegroundColor Yellow
        $templateResponse = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/umbraco.community.templates.clean/index.json"
        $templateVersion = $templateResponse.versions | Where-Object { $_ -notmatch '-' } | Select-Object -Last 1
        Write-Host "Latest Clean template version: $templateVersion" -ForegroundColor Green
    } else {
        Write-Host "`nFetching latest Clean template version from GitHub Packages..." -ForegroundColor Yellow
        # Extract repository owner from current repository
        $repoOwner = if ($env:GITHUB_REPOSITORY) {
            $env:GITHUB_REPOSITORY.Split('/')[0]
        } else {
            "prjseal"
        }

        try {
            $headers = @{}
            if ($env:GITHUB_TOKEN) {
                $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
            }

            $ghPackagesUrl = "https://nuget.pkg.github.com/$repoOwner/index.json"
            $serviceIndex = Invoke-RestMethod -Uri $ghPackagesUrl -Headers $headers
            $packageBaseAddress = ($serviceIndex.resources | Where-Object { $_.'@type' -match 'PackageBaseAddress' }).'@id'

            if ($packageBaseAddress) {
                # Ensure there's a trailing slash on the base address
                if (-not $packageBaseAddress.EndsWith('/')) {
                    $packageBaseAddress += '/'
                }
                $versionsUrl = "${packageBaseAddress}umbraco.community.templates.clean/index.json"
                Write-Host "Querying: $versionsUrl" -ForegroundColor Gray

                $templateResponse = Invoke-RestMethod -Uri $versionsUrl -Headers $headers

                # Get latest version, preferring stable versions
                $stableVersions = $templateResponse.versions | Where-Object { $_ -notmatch '-' }
                if ($stableVersions) {
                    $templateVersion = $stableVersions | Select-Object -Last 1
                    Write-Host "Latest stable Clean template version from GitHub Packages: $templateVersion" -ForegroundColor Green
                } else {
                    # If no stable versions, get the latest including pre-release
                    $templateVersion = $templateResponse.versions | Select-Object -Last 1
                    Write-Host "Latest Clean template version from GitHub Packages (pre-release): $templateVersion" -ForegroundColor Green
                }
            } else {
                Write-Host "Could not find PackageBaseAddress in GitHub Packages service index" -ForegroundColor Yellow
                Write-Host "Please specify version manually using -TemplateVersion parameter" -ForegroundColor Yellow
                exit 1
            }
        } catch {
            Write-Host "Error fetching from GitHub Packages: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Please specify version manually using -TemplateVersion parameter" -ForegroundColor Yellow
            exit 1
        }
    }
} else {
    $templateVersion = $TemplateVersion
    Write-Host "`nUsing specified Clean template version: $templateVersion" -ForegroundColor Green
}

# Save version to GitHub output if running in GitHub Actions
if ($env:GITHUB_OUTPUT) {
    "clean_template_version=$templateVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}

# Create test directory
$testDir = Join-Path $WorkspacePath "test-clean-template-zap"
if (Test-Path $testDir) {
    Remove-Item $testDir -Recurse -Force
}
New-Item -ItemType Directory -Path $testDir | Out-Null
Set-Location $testDir

# Configure package source if using GitHub Packages
$ghPackagesUrl = $null
if ($TemplateSource -eq 'github-packages') {
    Write-Host "`nConfiguring GitHub Packages as NuGet source..." -ForegroundColor Yellow

    # Extract repository owner
    $repoOwner = if ($env:GITHUB_REPOSITORY) {
        $env:GITHUB_REPOSITORY.Split('/')[0]
    } else {
        "prjseal"
    }

    $ghPackagesUrl = "https://nuget.pkg.github.com/$repoOwner/index.json"

    # Check if source already exists
    $existingSources = dotnet nuget list source
    if ($existingSources -match "GitHubPackages") {
        Write-Host "GitHubPackages source already exists, removing it first..." -ForegroundColor Yellow
        dotnet nuget remove source "GitHubPackages"
    }

    # Add GitHub Packages source
    dotnet nuget add source $ghPackagesUrl --name "GitHubPackages" --username "github" --password "$env:GITHUB_TOKEN" --store-password-in-clear-text

    Write-Host "GitHub Packages source configured successfully" -ForegroundColor Green
}

# Install Clean templates
Write-Host "`nInstalling Clean template version $templateVersion..." -ForegroundColor Yellow

if ($TemplateSource -eq 'github-packages') {
    # Use the full URL for GitHub Packages
    dotnet new install Umbraco.Community.Templates.Clean@$templateVersion --add-source $ghPackagesUrl --force
} else {
    # Use NuGet.org
    dotnet new install Umbraco.Community.Templates.Clean@$templateVersion --force
}

# Check if template was installed successfully
Write-Host "`nVerifying template installation..." -ForegroundColor Yellow
Write-Host "Installed templates:" -ForegroundColor Gray
dotnet new list

$templateList = dotnet new list
if ($templateList -match "umbraco-starter-clean") {
    Write-Host "`nClean template installed successfully" -ForegroundColor Green
    $templateShortName = "umbraco-starter-clean"
} else {
    Write-Host "ERROR: Clean template not found in installed templates" -ForegroundColor Red
    Write-Host "Expected template short name 'umbraco-starter-clean' not found" -ForegroundColor Red
    exit 1
}

# Create Clean project using the template
Write-Host "`nCreating Clean Blog project from template..." -ForegroundColor Yellow
dotnet new $templateShortName -n "TestCleanProject"

# The template creates a .Blog project, so we need to reference that
$projectPath = "TestCleanProject/TestCleanProject.Blog"
if (-not (Test-Path "$projectPath/TestCleanProject.Blog.csproj")) {
    Write-Host "ERROR: Expected project not found at $projectPath" -ForegroundColor Red
    Write-Host "Directory contents:" -ForegroundColor Yellow
    Get-ChildItem -Recurse
    exit 1
}

Write-Host "Clean Blog project created successfully at $projectPath" -ForegroundColor Green

# Restore the project
Write-Host "`nRestoring Clean Blog project..." -ForegroundColor Yellow
dotnet restore "$projectPath/TestCleanProject.Blog.csproj"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Restore failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Restore completed successfully" -ForegroundColor Green
}

# Start the site in background
Write-Host "`nStarting Clean Blog site..." -ForegroundColor Yellow
$logFile = Join-Path $testDir "site.log"
$errFile = Join-Path $testDir "site.err"
$pidFile = Join-Path $testDir "site.pid"

# Start the site process (using the .Blog project)
$runProjectPath = Join-Path $testDir "TestCleanProject" "TestCleanProject.Blog"
$process = Start-Process -FilePath "dotnet" `
    -ArgumentList "run --project `"$runProjectPath`"" `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $errFile `
    -NoNewWindow `
    -PassThru

Write-Host "Site process started with PID: $($process.Id)" -ForegroundColor Green

# Save PID to file and GitHub output for later cleanup
$process.Id | Out-File -FilePath $pidFile -NoNewline
if ($env:GITHUB_OUTPUT) {
    "site_pid=$($process.Id)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    "test_dir=$testDir" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}

# Wait for site to start and extract URL
$startTime = Get-Date
$timeoutSeconds = 180
$siteStarted = $false
$siteUrl = $null

Write-Host "Waiting for site to start (timeout: ${timeoutSeconds}s)..." -ForegroundColor Yellow

while (-not $siteStarted) {
    if ((Get-Date) - $startTime -gt (New-TimeSpan -Seconds $timeoutSeconds)) {
        Write-Host "Timeout reached! Site failed to start." -ForegroundColor Red

        # Output logs for debugging
        if (Test-Path $logFile) {
            Write-Host "`nSite output log:" -ForegroundColor Yellow
            Get-Content $logFile
        }
        if (Test-Path $errFile) {
            Write-Host "`nSite error log:" -ForegroundColor Yellow
            Get-Content $errFile
        }

        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
        }
        exit 1
    }

    # Check if process has exited prematurely
    if ($process.HasExited) {
        Write-Host "Site process exited prematurely with exit code: $($process.ExitCode)" -ForegroundColor Red

        # Output logs for debugging
        if (Test-Path $logFile) {
            Write-Host "`nSite output log:" -ForegroundColor Yellow
            Get-Content $logFile
        }
        if (Test-Path $errFile) {
            Write-Host "`nSite error log:" -ForegroundColor Yellow
            Get-Content $errFile
        }

        exit 1
    }

    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile -Raw

        # Check if site is listening on HTTP or HTTPS
        if ($logContent -match "Now listening on:\s*(https?://[^\s]+)") {
            $siteUrl = $matches[1]
            $siteStarted = $true
            Write-Host "Site is running at: $siteUrl" -ForegroundColor Green
            break
        }
    }

    Start-Sleep -Seconds 2
}

# Additional wait to ensure site is fully ready
Write-Host "Waiting additional 10 seconds for site to be fully ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Verify process is still running
if ($process.HasExited) {
    Write-Host "Site process exited after detection. Exit code: $($process.ExitCode)" -ForegroundColor Red

    if (Test-Path $logFile) {
        Write-Host "`nSite output log:" -ForegroundColor Yellow
        Get-Content $logFile
    }
    if (Test-Path $errFile) {
        Write-Host "`nSite error log:" -ForegroundColor Yellow
        Get-Content $errFile
    }

    exit 1
}

Write-Host "Site process is still running (PID: $($process.Id))" -ForegroundColor Green

# Export site URL for ZAP to use
if ($env:GITHUB_OUTPUT) {
    "site_url=$siteUrl" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Clean Blog Site Ready for ZAP Security Scanning" -ForegroundColor Cyan
Write-Host "Clean Template Version: $templateVersion" -ForegroundColor Green
Write-Host "Site URL: $siteUrl" -ForegroundColor Green
Write-Host "Process ID: $($process.Id)" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
