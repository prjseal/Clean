<#
.SYNOPSIS
    Publishes NuGet packages to GitHub Packages.

.DESCRIPTION
    This script publishes all NuGet packages from the artifacts directory to GitHub Packages.
    It configures the GitHub Packages source, validates package existence, and reports
    success/failure for each package.

.PARAMETER GitHubToken
    The GitHub token for authentication

.PARAMETER RepositoryOwner
    The GitHub repository owner

.PARAMETER PackagesPath
    Path to the directory containing .nupkg files (default: .artifacts/nuget)

.EXAMPLE
    .\Publish-ToGitHubPackages.ps1 -GitHubToken $env:GITHUB_TOKEN -RepositoryOwner "myorg"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubToken,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryOwner,

    [Parameter(Mandatory = $false)]
    [string]$PackagesPath = ".artifacts/nuget"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Publishing NuGet Packages to GitHub Packages" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Get all package files
$packages = Get-ChildItem -Path "$PackagesPath/*.nupkg" -ErrorAction SilentlyContinue

if (-not $packages) {
    Write-Host "No packages found to publish." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($packages.Count) package(s) to publish:" -ForegroundColor Green
foreach ($pkg in $packages) {
    Write-Host "  - $($pkg.Name)" -ForegroundColor White
}
Write-Host ""

# Add GitHub Packages source
$sourceUrl = "https://nuget.pkg.github.com/$RepositoryOwner/index.json"
Write-Host "Adding GitHub Packages source: $sourceUrl" -ForegroundColor Cyan
dotnet nuget add source $sourceUrl --name "GitHubPackages" --username $RepositoryOwner --password $GitHubToken --store-password-in-clear-text

# Push each package
$failedPackages = @()
foreach ($pkg in $packages) {
    Write-Host "Publishing $($pkg.Name)..." -ForegroundColor Cyan
    dotnet nuget push $pkg.FullName --source "GitHubPackages" --api-key $GitHubToken --skip-duplicate

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully published $($pkg.Name)" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Failed to publish $($pkg.Name) (exit code: $LASTEXITCODE)" -ForegroundColor Red
        $failedPackages += $pkg.Name
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Package Publishing Complete" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Check if any packages failed
if ($failedPackages.Count -gt 0) {
    Write-Host "::error::Failed to publish the following packages:" -ForegroundColor Red
    foreach ($failedPkg in $failedPackages) {
        Write-Host "  - $failedPkg" -ForegroundColor Red
    }
    exit 1
}

Write-Host "✅ All packages published successfully!" -ForegroundColor Green
