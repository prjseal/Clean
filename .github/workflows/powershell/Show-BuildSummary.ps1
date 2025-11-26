<#
.SYNOPSIS
    Displays a comprehensive build summary.

.DESCRIPTION
    This script outputs a formatted summary of the build including version,
    PR number, branch, triggered by, and generated packages.

.PARAMETER Version
    The build version

.PARAMETER PrNumber
    The pull request number

.PARAMETER Branch
    The branch name

.PARAMETER Actor
    The GitHub actor who triggered the build

.PARAMETER Repository
    The GitHub repository in owner/repo format

.PARAMETER PackagesPath
    Path to the directory containing .nupkg files (default: .artifacts/nuget)

.EXAMPLE
    .\Show-BuildSummary.ps1 -Version "7.0.0-ci.123" -PrNumber "456" -Branch "feature/test" -Actor "user" -Repository "owner/repo"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$PrNumber,

    [Parameter(Mandatory = $true)]
    [string]$Branch,

    [Parameter(Mandatory = $true)]
    [string]$Actor,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $false)]
    [string]$PackagesPath = ".artifacts/nuget"
)

Write-Host "================================================" -ForegroundColor Green
Write-Host "Build Summary" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host "PR Number: $PrNumber" -ForegroundColor Cyan
Write-Host "Branch: $Branch" -ForegroundColor Cyan
Write-Host "Triggered by: $Actor" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Green

# List generated packages
$packages = Get-ChildItem -Path "$PackagesPath/*.nupkg" -ErrorAction SilentlyContinue
if ($packages) {
    Write-Host "`nGenerated Packages:" -ForegroundColor Yellow
    foreach ($pkg in $packages) {
        Write-Host "  - $($pkg.Name)" -ForegroundColor White
    }
    Write-Host "`nPublished to: https://github.com/$Repository/packages" -ForegroundColor Cyan
}
else {
    Write-Host "`nNo packages were generated." -ForegroundColor Red
}
