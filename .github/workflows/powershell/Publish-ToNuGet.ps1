<#
.SYNOPSIS
    Publishes NuGet packages to NuGet.org.

.DESCRIPTION
    This script publishes all NuGet packages from the artifacts directory to NuGet.org.
    It verifies the API key, validates package existence, and reports success/failure
    for each package.

.PARAMETER ApiKey
    The short-lived nuget.org API key from the NuGet/login step (trusted publishing).
    In the release workflow this is ${{ steps.nuget-login.outputs.NUGET_API_KEY }}, passed in
    through the NUGET_API_KEY environment variable. The key is valid for 1 hour.

.PARAMETER PackagesPath
    Path to the directory containing .nupkg files (default: .artifacts/nuget)

.EXAMPLE
    # In release-nuget.yml, after the NuGet/login step (id: nuget-login):
    #   env:
    #     NUGET_API_KEY: ${{ steps.nuget-login.outputs.NUGET_API_KEY }}
    .\Publish-ToNuGet.ps1 -ApiKey $env:NUGET_API_KEY
#>

param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$ApiKey,

    [Parameter(Mandatory = $false)]
    [string]$PackagesPath = ".artifacts/nuget"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Publishing NuGet Packages to NuGet.org" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Verify API key is set
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "::error::No NuGet API key was provided. The key comes from the 'NuGet login (OIDC trusted publishing)' step (NuGet/login), which did not produce one." -ForegroundColor Red
    Write-Host "This workflow publishes with nuget.org trusted publishing, not a stored API key. Check:" -ForegroundColor Yellow
    Write-Host "1. The nuget.org trusted publishing policy (username menu -> Trusted Publishing):" -ForegroundColor Yellow
    Write-Host "   repository owner and repository match this repo, workflow file is 'release-nuget.yml'" -ForegroundColor Yellow
    Write-Host "   (file name only), and the policy is active (it is temporary for 7 days until the first publish)" -ForegroundColor Yellow
    Write-Host "2. The 'NUGET_USER' repository secret is set to the nuget.org profile name (not the email address)" -ForegroundColor Yellow
    Write-Host "3. The job has 'permissions: id-token: write'" -ForegroundColor Yellow
    Write-Host "4. The publish step passes NUGET_API_KEY: `${{ steps.nuget-login.outputs.NUGET_API_KEY }}" -ForegroundColor Yellow
    Write-Host "See https://learn.microsoft.com/en-gb/nuget/nuget-org/trusted-publishing" -ForegroundColor Yellow
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
