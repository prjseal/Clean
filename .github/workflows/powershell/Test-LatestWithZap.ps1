<#
.SYNOPSIS
    Sets up Umbraco site for OWASP ZAP security testing.

.DESCRIPTION
    This script tests installing the latest Clean package from NuGet.org or GitHub Packages with
    the latest stable Umbraco version, creates an Umbraco project, installs Clean,
    starts the site, and prepares it for OWASP ZAP security scanning.

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
    .\Test-LatestWithZap.ps1 -WorkspacePath "/workspace"

.EXAMPLE
    .\Test-LatestWithZap.ps1 -WorkspacePath "/workspace" -UmbracoVersion "15.0.0" -CleanVersion "7.0.0"

.EXAMPLE
    .\Test-LatestWithZap.ps1 -WorkspacePath "/workspace" -PackageSource "github-packages"
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
Write-Host "Setting up Umbraco for ZAP Security Testing" -ForegroundColor Cyan
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
    "umbraco_version=$umbracoVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    "clean_version=$cleanVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}

# Create test directory
$testDir = Join-Path $WorkspacePath "test-latest-zap"
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
dotnet new sln --name "TestZapSolution"
dotnet new umbraco --force -n "TestZapProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "TestZapProject"

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
    $restoreArgs = @("restore", "TestZapProject/TestZapProject.csproj")
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
    Write-Host "`nRunning: dotnet restore TestZapProject/TestZapProject.csproj" -ForegroundColor Yellow
    dotnet restore TestZapProject/TestZapProject.csproj

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
    dotnet add "TestZapProject" package Clean --version $cleanVersion --source $ghPackagesUrl
} else {
    # Explicitly specify NuGet.org source to avoid searching MyGet feed
    dotnet add "TestZapProject" package Clean --version $cleanVersion --source "https://api.nuget.org/v3/index.json"
}

# Start the site in background
Write-Host "`nStarting Umbraco site..." -ForegroundColor Yellow
$logFile = Join-Path $testDir "site.log"
$errFile = Join-Path $testDir "site.err"
$pidFile = Join-Path $testDir "site.pid"

# Start the site process
$projectPath = Join-Path $testDir "TestZapProject"
$process = Start-Process -FilePath "dotnet" `
    -ArgumentList "run --project `"$projectPath`"" `
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
Write-Host "Site Ready for ZAP Security Scanning" -ForegroundColor Cyan
Write-Host "Umbraco Version: $umbracoVersion" -ForegroundColor Green
Write-Host "Clean Package Version: $cleanVersion" -ForegroundColor Green
Write-Host "Site URL: $siteUrl" -ForegroundColor Green
Write-Host "Process ID: $($process.Id)" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
