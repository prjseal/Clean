<#
.SYNOPSIS
    Displays a comprehensive release summary.

.DESCRIPTION
    This script outputs a formatted summary of the release including version,
    release tag, prerelease status, release URL, and published packages.

.PARAMETER Version
    The version number that was released

.PARAMETER ReleaseTag
    The GitHub release tag

.PARAMETER IsPrerelease
    Boolean string indicating if this is a prerelease

.PARAMETER ReleaseUrl
    URL to the GitHub release

.PARAMETER PackagesPath
    Path to the directory containing .nupkg files (default: .artifacts/nuget)

.EXAMPLE
    .\Show-ReleaseSummary.ps1 -Version "7.0.0" -ReleaseTag "v7.0.0" -IsPrerelease "false" -ReleaseUrl "https://github.com/..."
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $true)]
    [string]$IsPrerelease,

    [Parameter(Mandatory = $true)]
    [string]$ReleaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$PackagesPath = ".artifacts/nuget"
)

Write-Host "================================================" -ForegroundColor Green
Write-Host "Release Summary" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host "Release Tag: $ReleaseTag" -ForegroundColor Cyan
Write-Host "Prerelease: $IsPrerelease" -ForegroundColor Cyan
Write-Host "Release URL: $ReleaseUrl" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Green

# List generated packages
$packages = Get-ChildItem -Path "$PackagesPath/*.nupkg" -ErrorAction SilentlyContinue
if ($packages) {
    Write-Host "`nPublished Packages:" -ForegroundColor Yellow
    foreach ($pkg in $packages) {
        Write-Host "  - $($pkg.Name)" -ForegroundColor White
        Write-Host "    https://www.nuget.org/packages/$($pkg.BaseName.Split('.')[0])/$Version" -ForegroundColor Gray
    }
}
