<#
.SYNOPSIS
    Tests latest Clean package from NuGet with latest Umbraco version.

.DESCRIPTION
    This script tests installing the latest Clean package from NuGet.org with
    the latest stable Umbraco version, creates an Umbraco project, installs Clean,
    starts the site, and runs Playwright tests to verify functionality.

.PARAMETER WorkspacePath
    The GitHub workspace path

.EXAMPLE
    .\Test-LatestNuGetPackages.ps1 -WorkspacePath "/workspace"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Testing Latest NuGet Packages" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Get latest Umbraco version from NuGet
Write-Host "`nFetching latest Umbraco.Cms version from NuGet..." -ForegroundColor Yellow
$umbracoResponse = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/umbraco.cms/index.json"
$umbracoVersion = $umbracoResponse.versions | Where-Object { $_ -notmatch '-' } | Select-Object -Last 1
Write-Host "Latest Umbraco version: $umbracoVersion" -ForegroundColor Green

# Get latest Clean package version from NuGet
Write-Host "`nFetching latest Clean package version from NuGet..." -ForegroundColor Yellow
$cleanResponse = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/clean/index.json"
$cleanVersion = $cleanResponse.versions | Where-Object { $_ -notmatch '-' } | Select-Object -Last 1
Write-Host "Latest Clean version: $cleanVersion" -ForegroundColor Green

# Save versions to GitHub output if running in GitHub Actions
if ($env:GITHUB_OUTPUT) {
    echo "umbraco_version=$umbracoVersion" >> $env:GITHUB_OUTPUT
    echo "clean_version=$cleanVersion" >> $env:GITHUB_OUTPUT
}

# Create test directory
$testDir = "$WorkspacePath\test-latest"
if (Test-Path $testDir) {
    Remove-Item $testDir -Recurse -Force
}
New-Item -ItemType Directory -Path $testDir | Out-Null
Set-Location $testDir

# Install Umbraco templates
Write-Host "`nInstalling Umbraco templates version $umbracoVersion..." -ForegroundColor Yellow
dotnet new install Umbraco.Templates@$umbracoVersion --force

# Create Umbraco project
Write-Host "`nCreating test Umbraco project..." -ForegroundColor Yellow
dotnet new sln --name "TestLatestSolution"
dotnet new umbraco --force -n "TestLatestProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "TestLatestProject"

# Install Clean package from NuGet
Write-Host "`nInstalling Clean package version $cleanVersion from NuGet..." -ForegroundColor Yellow
dotnet add "TestLatestProject" package Clean --version $cleanVersion

# Start the site in background
Write-Host "`nStarting Umbraco site..." -ForegroundColor Yellow
$logFile = "$testDir\site.log"
$errFile = "$testDir\site.err"

$process = Start-Process -FilePath "dotnet" `
    -ArgumentList "run --project TestLatestProject" `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $errFile `
    -NoNewWindow `
    -PassThru

Write-Host "Site process started with PID: $($process.Id)" -ForegroundColor Green

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

        # Check if site is listening on HTTPS
        if ($logContent -match "Now listening on:\s*(https://[^\s]+)") {
            $siteUrl = $matches[1]
            $siteStarted = $true
            Write-Host "Site is running at: $siteUrl" -ForegroundColor Green
            break
        }
    }

    Start-Sleep -Seconds 2
}

# Additional wait to ensure site is fully ready
Write-Host "Waiting additional 5 seconds for site to be fully ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

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

# Install Node.js dependencies for Playwright
Write-Host "`nInstalling Playwright..." -ForegroundColor Yellow
npm init -y
npm install --save-dev playwright

# Install Playwright browsers
Write-Host "Installing Playwright browsers..." -ForegroundColor Yellow
npx playwright install chromium

# Create Playwright test script
Write-Host "`nCreating Playwright test script..." -ForegroundColor Yellow
& "$WorkspacePath\.github\workflows\powershell\Write-PlaywrightTestScript.ps1" -OutputPath "$testDir\test.js"

# Run Playwright tests
Write-Host "`nRunning Playwright tests..." -ForegroundColor Yellow
$env:SITE_URL = "$siteUrl"

# Verify process is still running before tests
if ($process.HasExited) {
    Write-Host "Site process exited before Playwright tests. Exit code: $($process.ExitCode)" -ForegroundColor Red
    exit 1
}

node test.js
$playwrightExitCode = $LASTEXITCODE

# Stop the site process
Write-Host "`nStopping site process..." -ForegroundColor Yellow
if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force
    Write-Host "Site process stopped" -ForegroundColor Green
} else {
    Write-Host "Site process had already exited" -ForegroundColor Yellow
}

if ($playwrightExitCode -ne 0) {
    Write-Host "`nPlaywright tests failed with exit code: $playwrightExitCode" -ForegroundColor Red
    exit $playwrightExitCode
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Latest NuGet Package Testing Complete" -ForegroundColor Cyan
Write-Host "Umbraco Version: $umbracoVersion" -ForegroundColor Green
Write-Host "Clean Package Version: $cleanVersion" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
