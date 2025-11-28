<#
.SYNOPSIS
    Tests latest Clean package from NuGet with latest Umbraco version.

.DESCRIPTION
    This script tests installing the latest Clean package from NuGet.org or GitHub Packages with
    the latest stable Umbraco version, creates an Umbraco project, installs Clean,
    starts the site, and runs Playwright tests to verify functionality.

.PARAMETER WorkspacePath
    The GitHub workspace path

.PARAMETER PackageSource
    Optional package source to use: 'nuget' or 'github-packages'. Defaults to 'nuget'.

.PARAMETER UmbracoTemplateSource
    Optional Umbraco template source: 'nuget' or 'nightly-feed'. Defaults to 'nuget'.

.PARAMETER UmbracoVersion
    Optional specific Umbraco version to test. If not provided, uses latest stable version.

.PARAMETER CleanVersion
    Optional specific Clean package version to test. If not provided, uses latest stable version.

.EXAMPLE
    .\Test-LatestNuGetPackages.ps1 -WorkspacePath "/workspace"

.EXAMPLE
    .\Test-LatestNuGetPackages.ps1 -WorkspacePath "/workspace" -UmbracoVersion "15.0.0" -CleanVersion "7.0.0"

.EXAMPLE
    .\Test-LatestNuGetPackages.ps1 -WorkspacePath "/workspace" -PackageSource "github-packages"

.EXAMPLE
    .\Test-LatestNuGetPackages.ps1 -WorkspacePath "/workspace" -UmbracoTemplateSource "nightly-feed"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('nuget', 'github-packages')]
    [string]$PackageSource = 'nuget',

    [Parameter(Mandatory = $false)]
    [ValidateSet('nuget', 'nightly-feed')]
    [string]$UmbracoTemplateSource = 'nuget',

    [Parameter(Mandatory = $false)]
    [string]$UmbracoVersion,

    [Parameter(Mandatory = $false)]
    [string]$CleanVersion
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Testing NuGet Packages" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$packageSourceDisplay = if ($PackageSource -eq 'github-packages') { "GitHub Packages" } else { "NuGet.org" }
Write-Host "Clean Package Source: $packageSourceDisplay" -ForegroundColor Cyan

$templateSourceDisplay = if ($UmbracoTemplateSource -eq 'nightly-feed') { "Umbraco Nightly Feed (MyGet)" } else { "NuGet.org" }
Write-Host "Umbraco Template Source: $templateSourceDisplay" -ForegroundColor Cyan

# Get Umbraco version (use provided or fetch latest)
if ([string]::IsNullOrWhiteSpace($UmbracoVersion)) {
    if ($UmbracoTemplateSource -eq 'nightly-feed') {
        Write-Host "`nFetching latest Umbraco.Cms version from MyGet nightly feed..." -ForegroundColor Yellow
        try {
            $nightlyFeedUrl = "https://www.myget.org/f/umbracoprereleases/api/v3/index.json"
            $serviceIndex = Invoke-RestMethod -Uri $nightlyFeedUrl
            $packageBaseAddress = ($serviceIndex.resources | Where-Object { $_.'@type' -eq 'PackageBaseAddress/3.0.0' }).'@id'

            if ($packageBaseAddress) {
                $versionsUrl = "${packageBaseAddress}umbraco.cms/index.json"
                $umbracoResponse = Invoke-RestMethod -Uri $versionsUrl
                # Get latest version (including pre-releases)
                $umbracoVersion = $umbracoResponse.versions | Select-Object -Last 1
                Write-Host "Latest Umbraco version from nightly feed: $umbracoVersion" -ForegroundColor Green
            } else {
                Write-Host "Could not determine latest version from nightly feed, please specify version manually" -ForegroundColor Yellow
                exit 1
            }
        } catch {
            Write-Host "Error fetching from nightly feed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Please specify version manually using -UmbracoVersion parameter" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "`nFetching latest Umbraco.Cms version from NuGet..." -ForegroundColor Yellow
        $umbracoResponse = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/umbraco.cms/index.json"
        $umbracoVersion = $umbracoResponse.versions | Where-Object { $_ -notmatch '-' } | Select-Object -Last 1
        Write-Host "Latest Umbraco version: $umbracoVersion" -ForegroundColor Green
    }
} else {
    $umbracoVersion = $UmbracoVersion
    Write-Host "`nUsing specified Umbraco version: $umbracoVersion" -ForegroundColor Green
}

# Get Clean package version (use provided or fetch latest)
if ([string]::IsNullOrWhiteSpace($CleanVersion)) {
    if ($PackageSource -eq 'nuget') {
        Write-Host "`nFetching latest Clean package version from NuGet..." -ForegroundColor Yellow
        $cleanResponse = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/clean/index.json"
        $cleanVersion = $cleanResponse.versions | Where-Object { $_ -notmatch '-' } | Select-Object -Last 1
        Write-Host "Latest Clean version: $cleanVersion" -ForegroundColor Green
    } else {
        Write-Host "`nFetching latest Clean package version from GitHub Packages..." -ForegroundColor Yellow
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
                # Try to fetch versions for the Clean package
                # Ensure there's a trailing slash on the base address
                if (-not $packageBaseAddress.EndsWith('/')) {
                    $packageBaseAddress += '/'
                }
                $versionsUrl = "${packageBaseAddress}clean/index.json"
                Write-Host "Querying: $versionsUrl" -ForegroundColor Gray

                $cleanResponse = Invoke-RestMethod -Uri $versionsUrl -Headers $headers

                # Get latest version, preferring stable versions
                $stableVersions = $cleanResponse.versions | Where-Object { $_ -notmatch '-' }
                if ($stableVersions) {
                    $cleanVersion = $stableVersions | Select-Object -Last 1
                    Write-Host "Latest stable Clean version from GitHub Packages: $cleanVersion" -ForegroundColor Green
                } else {
                    # If no stable versions, get the latest including pre-release
                    $cleanVersion = $cleanResponse.versions | Select-Object -Last 1
                    Write-Host "Latest Clean version from GitHub Packages (pre-release): $cleanVersion" -ForegroundColor Green
                }
            } else {
                Write-Host "Could not find PackageBaseAddress in GitHub Packages service index" -ForegroundColor Yellow
                Write-Host "Please specify version manually using -CleanVersion parameter" -ForegroundColor Yellow
                exit 1
            }
        } catch {
            Write-Host "Error fetching from GitHub Packages: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Please specify version manually using -CleanVersion parameter" -ForegroundColor Yellow
            exit 1
        }
    }
} else {
    $cleanVersion = $CleanVersion
    Write-Host "`nUsing specified Clean version: $cleanVersion" -ForegroundColor Green
}

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

# Configure MyGet nightly feed as NuGet source if needed (BEFORE creating project)
if ($UmbracoTemplateSource -eq 'nightly-feed') {
    Write-Host "`nConfiguring MyGet nightly feed as NuGet source..." -ForegroundColor Yellow

    $nightlyFeedUrl = "https://www.myget.org/f/umbracoprereleases/api/v3/index.json"

    # Check if source already exists
    $existingSources = dotnet nuget list source
    if ($existingSources -match "UmbracoNightly") {
        Write-Host "UmbracoNightly source already exists, removing it first..." -ForegroundColor Yellow
        dotnet nuget remove source "UmbracoNightly"
    }

    # Add MyGet nightly feed source
    dotnet nuget add source $nightlyFeedUrl --name "UmbracoNightly"

    Write-Host "MyGet nightly feed source configured successfully" -ForegroundColor Green
}

# Install Umbraco templates
Write-Host "`nInstalling Umbraco templates version $umbracoVersion..." -ForegroundColor Yellow

if ($UmbracoTemplateSource -eq 'nightly-feed') {
    $nightlyFeedUrl = "https://www.myget.org/f/umbracoprereleases/api/v3/index.json"
    Write-Host "Using Umbraco nightly feed: $nightlyFeedUrl" -ForegroundColor Yellow
    dotnet new install Umbraco.Templates@$umbracoVersion --add-source $nightlyFeedUrl --force
} else {
    dotnet new install Umbraco.Templates@$umbracoVersion --force
}

# Create Umbraco project
Write-Host "`nCreating test Umbraco project..." -ForegroundColor Yellow
dotnet new sln --name "TestLatestSolution"
dotnet new umbraco --force -n "TestLatestProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "TestLatestProject"

# Configure package source
$ghPackagesUrl = $null
if ($PackageSource -eq 'github-packages') {
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

# ============================================================================
# Explicit restore with all configured sources
# This prevents NuGet from hanging when searching for packages across sources
# ============================================================================
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Restoring Project with All Configured Sources" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$allSourcesOutput = dotnet nuget list source
$sourceUrls = @()

# Parse the output to extract source URLs
foreach ($line in $allSourcesOutput) {
    # Match URLs (http/https)
    if ($line -match '^\s+(https?://\S+)') {
        $url = $matches[1].Trim()
        $sourceUrls += $url
        Write-Host "  Found source: $url" -ForegroundColor Cyan
    }
}

if ($sourceUrls.Count -eq 0) {
    Write-Host "  Warning: No NuGet sources found, using default behavior" -ForegroundColor Yellow
} else {
    Write-Host "`nFound $($sourceUrls.Count) NuGet source(s)" -ForegroundColor Green
}

# Explicitly restore the project with all configured sources
if ($sourceUrls.Count -gt 0) {
    $restoreArgs = @("restore", "TestLatestProject/TestLatestProject.csproj")
    foreach ($sourceUrl in $sourceUrls) {
        $restoreArgs += "--source"
        $restoreArgs += $sourceUrl
    }

    Write-Host "`nRunning: dotnet $($restoreArgs -join ' ')" -ForegroundColor Yellow
    & dotnet $restoreArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Restore failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "Restore completed successfully" -ForegroundColor Green
    }
} else {
    Write-Host "`nRunning: dotnet restore TestLatestProject/TestLatestProject.csproj" -ForegroundColor Yellow
    dotnet restore TestLatestProject/TestLatestProject.csproj

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Restore failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
}

Write-Host "================================================`n" -ForegroundColor Cyan

# Install Clean package
$sourceMessage = if ($PackageSource -eq 'github-packages') { "GitHub Packages" } else { "NuGet" }
Write-Host "`nInstalling Clean package version $cleanVersion from $sourceMessage..." -ForegroundColor Yellow

if ($PackageSource -eq 'github-packages') {
    # Use the full URL instead of source name to avoid path resolution issues
    dotnet add "TestLatestProject" package Clean --version $cleanVersion --source $ghPackagesUrl
} else {
    # Explicitly specify NuGet.org source to avoid searching MyGet feed
    dotnet add "TestLatestProject" package Clean --version $cleanVersion --source "https://api.nuget.org/v3/index.json"
}

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
Write-Host "NuGet Package Testing Complete" -ForegroundColor Cyan
Write-Host "Umbraco Version: $umbracoVersion" -ForegroundColor Green
Write-Host "Clean Package Version: $cleanVersion" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
