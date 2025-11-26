<#
.SYNOPSIS
    Updates README files with the latest version information.

.DESCRIPTION
    This script updates version references in README files based on the Clean
    release version. It maps Clean versions to Umbraco versions and updates
    package version references in README.md and marketplace README files.

.PARAMETER Version
    The Clean package version (e.g., 7.0.0 or 7.0.0-rc1)

.EXAMPLE
    .\Update-ReadmeVersions.ps1 -Version "7.0.0"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Updating README Files with Latest Versions" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$cleanVersion = $Version
Write-Host "Clean version: $cleanVersion" -ForegroundColor Green

# Extract Clean major version (e.g., "7.0.0-rc1" -> 7)
if ($cleanVersion -match '^(\d+)\.') {
    $cleanMajor = [int]$matches[1]
}
else {
    Write-Host "⚠️  Could not extract major version from $cleanVersion" -ForegroundColor Yellow
    exit 0
}

# Map Clean major version to Umbraco major version
# Note: Only Clean v4.x (Umbraco 13) and v7.x (Umbraco 17) are actively maintained
# Clean v5 (Umbraco 15) and v6 (Umbraco 16) are no longer maintained
$umbracoMajorMap = @{
    4 = 13
    7 = 17
}

if (-not $umbracoMajorMap.ContainsKey($cleanMajor)) {
    Write-Host "⚠️  No Umbraco version mapping found for Clean $cleanMajor.x" -ForegroundColor Yellow
    exit 0
}

$umbracoMajor = $umbracoMajorMap[$cleanMajor]
Write-Host "Mapped Clean $cleanMajor.x -> Umbraco $umbracoMajor.x" -ForegroundColor Cyan

# Read Umbraco version from Clean.csproj
$cleanCsprojPath = "template/Clean/Clean.csproj"
Write-Host "`nReading Umbraco version from $cleanCsprojPath..." -ForegroundColor Yellow

$umbracoVersion = $null
try {
    if (-not (Test-Path $cleanCsprojPath)) {
        Write-Host "⚠️  File not found: $cleanCsprojPath" -ForegroundColor Yellow
    }
    else {
        [xml]$cleanCsproj = Get-Content $cleanCsprojPath
        $umbracoPackageRef = $cleanCsproj.Project.ItemGroup.PackageReference | Where-Object { $_.Include -eq "Umbraco.Cms.Web.Website" }

        if (-not $umbracoPackageRef) {
            Write-Host "⚠️  Could not find Umbraco.Cms.Web.Website PackageReference in $cleanCsprojPath" -ForegroundColor Yellow
        }
        elseif ([string]::IsNullOrWhiteSpace($umbracoPackageRef.Version)) {
            Write-Host "⚠️  Umbraco.Cms.Web.Website version is empty" -ForegroundColor Yellow
        }
        else {
            $umbracoVersion = $umbracoPackageRef.Version
            Write-Host "Found Umbraco version: $umbracoVersion" -ForegroundColor Green
        }
    }

    # Update README files
    $readmeFiles = @(
        "README.md",
        "umbraco-marketplace-readme.md",
        "umbraco-marketplace-readme-clean.md"
    )

    $umbracoSectionHeader = "## Umbraco $umbracoMajor"

    foreach ($readmeFile in $readmeFiles) {
        if (-not (Test-Path $readmeFile)) {
            Write-Host "⚠️  File not found: $readmeFile" -ForegroundColor Yellow
            continue
        }

        Write-Host "`nUpdating $readmeFile..." -ForegroundColor Cyan
        $content = Get-Content $readmeFile -Raw
        $originalContent = $content

        # Find the section for this Umbraco version
        # Pattern matches from "## Umbraco X" to the next "## " (at line start) or end of file
        # Using (?m) for multiline mode and (?s) for dotall mode
        if ($content -match "(?ms)$umbracoSectionHeader.*?(?=(^## |\z))") {
            $section = $matches[0]
            $updatedSection = $section

            # Update Umbraco.Templates version (only if we have it)
            if ($umbracoVersion) {
                $updatedSection = $updatedSection -replace "dotnet new install Umbraco\.Templates::\S+", "dotnet new install Umbraco.Templates::$umbracoVersion"
            }

            # Update Clean package version
            $updatedSection = $updatedSection -replace "(dotnet add .* package Clean --version )\S+", "`${1}$cleanVersion"

            # Update Clean.Core package version (in warning sections)
            $updatedSection = $updatedSection -replace "(dotnet add .* package Clean\.Core --version )\S+", "`${1}$cleanVersion"

            # Update Clean template package version
            $updatedSection = $updatedSection -replace "dotnet new install Umbraco\.Community\.Templates\.Clean::\S+", "dotnet new install Umbraco.Community.Templates.Clean::$cleanVersion"

            # Replace the section in the content
            $content = $content -replace [regex]::Escape($section), $updatedSection

            # Write back to file only if content changed
            if ($content -ne $originalContent) {
                Set-Content -Path $readmeFile -Value $content -NoNewline
            }

            Write-Host "✅ Updated $readmeFile" -ForegroundColor Green
            if ($umbracoVersion) {
                Write-Host "   - Umbraco.Templates: $umbracoVersion" -ForegroundColor White
            }
            Write-Host "   - Clean: $cleanVersion" -ForegroundColor White
            Write-Host "   - Clean.Core: $cleanVersion" -ForegroundColor White
            Write-Host "   - Umbraco.Community.Templates.Clean: $cleanVersion" -ForegroundColor White
        }
        else {
            Write-Host "⚠️  Could not find section '$umbracoSectionHeader' in $readmeFile" -ForegroundColor Yellow
        }
    }

    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "README files updated successfully" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Cyan

}
catch {
    Write-Host "⚠️  Error querying NuGet or updating READMEs: $_" -ForegroundColor Yellow
    Write-Host "Continuing with release process..." -ForegroundColor Yellow
}
