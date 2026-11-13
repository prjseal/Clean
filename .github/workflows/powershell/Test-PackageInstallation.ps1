<#
.SYNOPSIS
    Tests Clean package installation from local packages.

.DESCRIPTION
    This script tests installing the Clean package from local NuGet packages,
    creates an Umbraco project, installs Clean, starts the site, and runs
    Playwright tests to verify functionality.

.PARAMETER Version
    The package version to test

.PARAMETER WorkspacePath
    The GitHub workspace path

.EXAMPLE
    .\Test-PackageInstallation.ps1 -Version "7.0.0-ci.123" -WorkspacePath "/workspace"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Testing Package Installation from Local Packages" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Create test directory
$testDir = "$WorkspacePath\test-installation"
if (Test-Path $testDir) {
    Remove-Item $testDir -Recurse -Force
}
New-Item -ItemType Directory -Path $testDir | Out-Null
Set-Location $testDir

# Configure local NuGet packages folder as source
Write-Host "`nConfiguring local NuGet packages folder as source..." -ForegroundColor Yellow
$localPackagesPath = "$WorkspacePath\.artifacts\nuget"
Write-Host "Local packages path: $localPackagesPath" -ForegroundColor Cyan

# Check if source already exists
$existingSources = dotnet nuget list source
if ($existingSources -match "LocalPackages") {
    Write-Host "LocalPackages source already exists, removing it first..." -ForegroundColor Yellow
    dotnet nuget remove source "LocalPackages"
}

dotnet nuget add source $localPackagesPath --name "LocalPackages"

# Read Umbraco version from Clean.csproj to determine which template version to use
Write-Host "`nDetermining Umbraco version from Clean package..." -ForegroundColor Yellow
$cleanCsprojPath = "$WorkspacePath\template\Clean\Clean.csproj"
[xml]$cleanCsproj = Get-Content $cleanCsprojPath
$umbracoPackageRef = $cleanCsproj.Project.ItemGroup.PackageReference | Where-Object { $_.Include -eq "Umbraco.Cms.Web.Website" }
$umbracoVersion = $umbracoPackageRef.Version
Write-Host "Umbraco version: $umbracoVersion" -ForegroundColor Green

# Install Umbraco templates for the detected version
Write-Host "`nInstalling Umbraco templates version $umbracoVersion..." -ForegroundColor Yellow
dotnet new install Umbraco.Templates@$umbracoVersion --force

# Create Umbraco project
Write-Host "`nCreating test Umbraco project..." -ForegroundColor Yellow
dotnet new sln --name "TestSolution"
dotnet new umbraco --force -n "TestProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "TestProject"

# Install Clean package from local packages
Write-Host "`nInstalling Clean package version $Version from local packages..." -ForegroundColor Yellow
dotnet add "TestProject" package Clean --version $Version --source $localPackagesPath

# Start the site in background
Write-Host "`nStarting Umbraco site..." -ForegroundColor Yellow
$logFile = "$testDir\site.log"
$errFile = "$testDir\site.err"

$process = Start-Process -FilePath "dotnet" `
    -ArgumentList "run --project TestProject" `
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
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
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

# Install Node.js dependencies for Playwright
Write-Host "`nInstalling Playwright..." -ForegroundColor Yellow
npm init -y
npm install --save-dev playwright

# Install Playwright browsers
Write-Host "Installing Playwright browsers..." -ForegroundColor Yellow
npx playwright install chromium

# Extract content keys from uSync files
Write-Host "`nExtracting content keys from uSync files..." -ForegroundColor Yellow
$contentKeys = & "$WorkspacePath\.github\workflows\powershell\Get-UsyncKeys.ps1" `
    -WorkspacePath $WorkspacePath `
    -UsyncFileType "Content" `
    -PublishedOnly

if ($contentKeys.Count -eq 0) {
    Write-Host "WARNING: No content keys found in uSync files" -ForegroundColor Yellow
}

# Create Playwright test script
Write-Host "`nCreating Playwright test script..." -ForegroundColor Yellow
& "$WorkspacePath\.github\workflows\powershell\Write-PlaywrightTestScript.ps1" `
    -OutputPath "$testDir\test.js" `
    -ContentKeys $contentKeys

# Run Playwright tests
Write-Host "`nRunning Playwright tests..." -ForegroundColor Yellow
$env:SITE_URL = "$siteUrl"
$env:CONTENT_KEYS = ($contentKeys | ConvertTo-Json -Compress)
node test.js
$playwrightExitCode = $LASTEXITCODE

# Stop the site process
Write-Host "`nStopping site process..." -ForegroundColor Yellow
if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force
    Write-Host "Site process stopped" -ForegroundColor Green
}

if ($playwrightExitCode -ne 0) {
    Write-Host "`nPlaywright tests failed with exit code: $playwrightExitCode" -ForegroundColor Red

    # Show the Umbraco log's warnings and errors, so a site that failed to boot can be diagnosed
    # from the run log. The workflow uploads the full logs as an artifact.
    $umbracoLog = Get-ChildItem -Path $testDir -Recurse -Filter "UmbracoTraceLog*.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\node_modules\\' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($umbracoLog) {
        Write-Host "`nWarnings and errors in $($umbracoLog.FullName):" -ForegroundColor Yellow
        foreach ($line in Get-Content $umbracoLog.FullName) {
            try {
                $entry = $line | ConvertFrom-Json
            }
            catch {
                continue
            }

            if ($entry.'@l' -notin @('Warning', 'Error', 'Fatal')) {
                continue
            }

            # Fill the message template's placeholders from the entry's properties
            $message = [regex]::Replace($entry.'@mt', '\{@?(\w+)(:[^}]*)?\}', {
                param($match)
                $value = $entry.($match.Groups[1].Value)
                if ($null -ne $value) { "$value" } else { $match.Value }
            })

            Write-Host "[$($entry.'@t')] $($entry.'@l'): $message"
            if ($entry.'@x') {
                Write-Host $entry.'@x'
            }
        }
    }
    else {
        Write-Host "No Umbraco log found under $testDir" -ForegroundColor Yellow
    }

    exit $playwrightExitCode
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Package Testing Complete" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
