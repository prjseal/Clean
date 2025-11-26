<#
.SYNOPSIS
    Uploads NuGet packages to GitHub release assets.

.DESCRIPTION
    This script uploads all NuGet packages from the artifacts directory
    to a GitHub release as assets using the GitHub CLI.

.PARAMETER ReleaseTag
    The GitHub release tag to upload assets to

.PARAMETER PackagesPath
    Path to the directory containing .nupkg files (default: .artifacts/nuget)

.EXAMPLE
    .\Add-ReleaseAssets.ps1 -ReleaseTag "v7.0.0"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $false)]
    [string]$PackagesPath = ".artifacts/nuget"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Uploading packages to GitHub Release" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$packages = Get-ChildItem -Path "$PackagesPath/*.nupkg"

foreach ($pkg in $packages) {
    Write-Host "Uploading $($pkg.Name)..." -ForegroundColor Cyan
    gh release upload "$ReleaseTag" $pkg.FullName --clobber

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Uploaded $($pkg.Name)" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Failed to upload $($pkg.Name)" -ForegroundColor Yellow
    }
}
