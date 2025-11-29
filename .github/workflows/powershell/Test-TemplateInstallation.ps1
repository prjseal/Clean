<#
.SYNOPSIS
    Tests Clean template installation from local packages.

.DESCRIPTION
    This script tests installing the Clean template from local NuGet packages,
    creates a project using the template, starts the site, and runs Playwright tests.

.PARAMETER Version
    The template version to test

.PARAMETER WorkspacePath
    The GitHub workspace path

.PARAMETER ProjectName
    The name for the test project (default: TestTemplateProject)

.EXAMPLE
    .\Test-TemplateInstallation.ps1 -Version "7.0.0-ci.123" -WorkspacePath "/workspace"
    .\Test-TemplateInstallation.ps1 -Version "7.0.0-ci.123" -WorkspacePath "/workspace" -ProjectName "Company.Website"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath,

    [Parameter(Mandatory = $false)]
    [string]$ProjectName = "TestTemplateProject"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Testing Template Installation from Local Packages" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Create test directory for template
$safeProjectName = $ProjectName -replace '[^a-zA-Z0-9]', '-'
$testDir = "$WorkspacePath\test-template-$safeProjectName"
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

# Uninstall any existing Clean templates to avoid conflicts (for period name test)
Write-Host "`nUninstalling any existing Clean templates..." -ForegroundColor Yellow
dotnet new uninstall Umbraco.Community.Templates.Clean 2>&1 | Out-Null

# Install the Clean template from local packages
Write-Host "`nInstalling Clean template version $Version from local packages..." -ForegroundColor Yellow
dotnet new install Umbraco.Community.Templates.Clean::$Version --nuget-source $localPackagesPath --force

# Create a new project using the template
Write-Host "`nCreating test project using template..." -ForegroundColor Yellow
Write-Host "Project name: $ProjectName" -ForegroundColor Cyan
dotnet new umbraco-starter-clean -n $ProjectName

# Navigate to project directory
Set-Location $ProjectName

# Start the site in background
Write-Host "`nStarting Umbraco site from template..." -ForegroundColor Yellow
$logFile = "$testDir\$ProjectName\site.log"
$errFile = "$testDir\$ProjectName\site.err"

$process = Start-Process -FilePath "dotnet" `
    -ArgumentList "run --project $ProjectName.Blog" `
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
    -OutputPath "$testDir\$ProjectName\test.js" `
    -ContentKeys $contentKeys

# Run Playwright tests
Write-Host "`nRunning Playwright tests..." -ForegroundColor Yellow
$env:SITE_URL = "$siteUrl"
$env:CONTENT_KEYS = ($contentKeys | ConvertTo-Json -Compress)
node test.js

# Stop the site process
Write-Host "`nStopping site process..." -ForegroundColor Yellow
if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force
    Write-Host "Site process stopped" -ForegroundColor Green
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Template Testing Complete" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
