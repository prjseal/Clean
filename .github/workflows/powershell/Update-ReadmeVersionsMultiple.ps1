<#
.SYNOPSIS
    Updates README files with latest Umbraco versions for multiple major versions.

.DESCRIPTION
    This script processes multiple Umbraco major versions and updates README files
    with the latest version information. It supports both stable and prerelease versions.

.PARAMETER IsScheduled
    Whether this is a scheduled run (vs manual trigger)

.PARAMETER ManualVersionInput
    Manual version input (comma-separated, e.g., "13" or "13-,17")

.PARAMETER EnvVersions
    Environment variable versions (fallback for scheduled runs)

.PARAMETER WorkspacePath
    The GitHub workspace path

.EXAMPLE
    .\Update-ReadmeVersionsMultiple.ps1 -IsScheduled $false -ManualVersionInput "13-,17" -EnvVersions "13" -WorkspacePath "/workspace"
#>

param(
    [Parameter(Mandatory = $true)]
    [bool]$IsScheduled,

    [Parameter(Mandatory = $false)]
    [string]$ManualVersionInput = "",

    [Parameter(Mandatory = $true)]
    [string]$EnvVersions,

    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath
)

# Determine which versions to process
# For manual runs with input provided, use the input; otherwise use env variable
if (-not $IsScheduled -and -not [string]::IsNullOrWhiteSpace($ManualVersionInput)) {
    # Manual run with version input provided
    $versionsString = $ManualVersionInput
    Write-Host "Manual run - using umbracoVersions input: $versionsString" -ForegroundColor Cyan
}
else {
    # Scheduled run or manual run without version input - use env variable
    $versionsString = $EnvVersions
    if ($IsScheduled) {
        Write-Host "Scheduled run - using UMBRACO_MAJOR_VERSIONS env variable: $versionsString" -ForegroundColor Cyan
    }
    else {
        Write-Host "Manual run (no version input) - using UMBRACO_MAJOR_VERSIONS env variable: $versionsString" -ForegroundColor Cyan
    }
}

# Parse comma-separated versions into entries and detect hyphen suffix for prerelease intent
# Convention: `13` -> stable-only; `17-` -> include prerelease for major 17
$rawTokens = $versionsString -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

$versionEntries = @()
foreach ($tok in $rawTokens) {
    $entry = [PSCustomObject]@{
        Major             = $null
        IncludePrerelease = $false
    }

    # If token ends with '-', treat as prerelease-enabled for that major
    if ($tok.EndsWith('-')) {
        $entry.Major = $tok.TrimEnd('-').Trim()
        $entry.IncludePrerelease = $true
    }
    else {
        $entry.Major = $tok
        $entry.IncludePrerelease = $false
    }

    if (-not [string]::IsNullOrWhiteSpace($entry.Major)) {
        $versionEntries += $entry
    }
}

# Prepare overall values for later steps
$anyUpdated = $false
$updatedVersions = @()

Write-Host "Processing Umbraco versions: $($versionEntries.Major -join ', ')" -ForegroundColor Yellow
Write-Host ""

foreach ($entry in $versionEntries) {
    $version = $entry.Major
    $prFlag = $entry.IncludePrerelease
    Write-Host "Processing Umbraco version $version (IncludePrerelease=$prFlag)..." -ForegroundColor Yellow
    $result = & "$WorkspacePath\.github\workflows\powershell\UpdateReadmeUmbracoVersion.ps1" `
        -RootPath $WorkspacePath `
        -UmbracoMajorVersion $version `
        -IncludePrerelease:$prFlag

    if ($result.Updated) {
        $anyUpdated = $true
        $updatedVersions += $version
        Write-Host "✅ Umbraco $version section updated" -ForegroundColor Green
    }
    else {
        Write-Host "ℹ️  Umbraco $version section unchanged" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "README Update Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Any updates made: $anyUpdated" -ForegroundColor Yellow
if ($updatedVersions.Count -gt 0) {
    Write-Host "Updated versions: $($updatedVersions -join ', ')" -ForegroundColor Yellow
}
else {
    Write-Host "Updated versions: None" -ForegroundColor Yellow
}
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if ($anyUpdated) {
    $versionsText = $updatedVersions -join ','
    Write-Host "Setting readme_updated=true and updated_versions=$versionsText" -ForegroundColor Green
    echo "readme_updated=true" >> $env:GITHUB_OUTPUT
    echo "updated_versions=$versionsText" >> $env:GITHUB_OUTPUT
}
else {
    Write-Host "Setting readme_updated=false and updated_versions=" -ForegroundColor Yellow
    echo "readme_updated=false" >> $env:GITHUB_OUTPUT
    echo "updated_versions=" >> $env:GITHUB_OUTPUT
}
