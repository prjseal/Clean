<#
.SYNOPSIS
    Publishes NuGet packages to NuGet.org.

.DESCRIPTION
    This script publishes all NuGet packages from the artifacts directory to NuGet.org.
    It verifies the API key, validates package existence, and reports success/failure
    for each package.

.PARAMETER ApiKey
    The NuGet API key for authentication

.PARAMETER PackagesPath
    Path to the directory containing .nupkg files (default: .artifacts/nuget)

.EXAMPLE
    .\Publish-ToNuGet.ps1 -ApiKey $env:NUGET_API_KEY
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,

    [Parameter(Mandatory = $false)]
    [string]$PackagesPath = ".artifacts/nuget"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Publishing NuGet Packages to NuGet.org" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Verify API key is set
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "::error::NUGET_API_KEY secret is not set. Please add it to your repository secrets." -ForegroundColor Red
    Write-Host "To add the secret:" -ForegroundColor Yellow
    Write-Host "1. Go to https://www.nuget.org/account/apikeys to create an API key" -ForegroundColor Yellow
    Write-Host "2. Add it to GitHub: Settings -> Secrets and variables -> Actions -> New repository secret" -ForegroundColor Yellow
    Write-Host "3. Name it 'NUGET_API_KEY' and paste your NuGet API key" -ForegroundColor Yellow
    exit 1
}

# Get all package files
$packages = Get-ChildItem -Path "$PackagesPath/*.nupkg" -ErrorAction SilentlyContinue

if (-not $packages) {
    Write-Host "::error::No packages found to publish." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($packages.Count) package(s) to publish:" -ForegroundColor Green
foreach ($pkg in $packages) {
    Write-Host "  - $($pkg.Name)" -ForegroundColor White
}
Write-Host ""

# Push each package to NuGet.org
$failedPackages = @()
foreach ($pkg in $packages) {
    Write-Host "Publishing $($pkg.Name) to NuGet.org..." -ForegroundColor Cyan
    dotnet nuget push $pkg.FullName --source https://api.nuget.org/v3/index.json --api-key $ApiKey --skip-duplicate

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
