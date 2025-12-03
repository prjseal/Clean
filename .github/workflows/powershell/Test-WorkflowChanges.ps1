<#
.SYNOPSIS
    Checks if any changes were made by the workflow.

.DESCRIPTION
    This script checks if README files or NuGet packages were updated,
    and outputs a summary if no changes were made.

.PARAMETER ReadmeUpdated
    Boolean string indicating if README was updated

.PARAMETER WorkspacePath
    The GitHub workspace path

.PARAMETER EnvVersions
    Environment variable versions for display

.EXAMPLE
    .\Test-WorkflowChanges.ps1 -ReadmeUpdated "false" -WorkspacePath "/workspace" -EnvVersions "13"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ReadmeUpdated,

    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath,

    [Parameter(Mandatory = $true)]
    [string]$EnvVersions
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Checking for Workflow Changes" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "ReadmeUpdated input parameter: '$ReadmeUpdated'" -ForegroundColor Magenta

# Explicitly convert string to boolean
$readmeUpdated = [bool]($ReadmeUpdated -eq 'true')

Write-Host "After conversion - ReadmeUpdated type: $($readmeUpdated.GetType().Name), value: $readmeUpdated" -ForegroundColor Magenta

# Check if packages were updated by reading the summary file
$summaryPath = "$WorkspacePath\.artifacts\package-summary.txt"
$packagesUpdated = $false
if (Test-Path $summaryPath) {
    $content = Get-Content $summaryPath -Raw
    $packagesUpdated = $content -notmatch 'No packages to update'
    Write-Host "Package summary file found. Packages updated: $packagesUpdated" -ForegroundColor Magenta
}
else {
    Write-Host "Package summary file not found at: $summaryPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "README updated: $readmeUpdated" -ForegroundColor Yellow
Write-Host "  Type: $($readmeUpdated.GetType().Name), Value: '$readmeUpdated'" -ForegroundColor Magenta
Write-Host "Packages updated: $packagesUpdated" -ForegroundColor Yellow
Write-Host "  Type: $($packagesUpdated.GetType().Name), Value: '$packagesUpdated'" -ForegroundColor Magenta
Write-Host ""
Write-Host "Condition evaluation:" -ForegroundColor Cyan
Write-Host "  -not `$readmeUpdated = $(-not $readmeUpdated)" -ForegroundColor Magenta
Write-Host "  -not `$packagesUpdated = $(-not $packagesUpdated)" -ForegroundColor Magenta
Write-Host "  Combined: $(-not $readmeUpdated -and -not $packagesUpdated)" -ForegroundColor Magenta
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $readmeUpdated -and -not $packagesUpdated) {
    Write-Host "ENTERING: No changes block" -ForegroundColor Green
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "✅ No Changes Needed - Workflow Complete" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Summary:" -ForegroundColor Cyan
    $versions = $EnvVersions -split ',' | ForEach-Object { $_.Trim() }
    $versionText = if ($versions.Count -eq 1) { "Umbraco $($versions[0])" } else { "Umbraco $($versions -join ' and ')" }
    Write-Host "  • README: Already up-to-date with latest $versionText version(s)" -ForegroundColor Yellow
    Write-Host "  • NuGet Packages: All packages are already at their latest versions" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "No branch created, no commits made, no PR needed." -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Setting has_changes=false" -ForegroundColor Cyan

    # Add GitHub Action summary
    $summary = @"
## ✅ No Changes Needed - Workflow Complete

### 📋 Summary
- **README**: Already up-to-date with latest $versionText version(s)
- **NuGet Packages**: All packages are already at their latest versions

### 📌 Result
No branch created, no commits made, no PR needed.
"@
    $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8

    echo "has_changes=false" >> $env:GITHUB_OUTPUT
    exit 0
}
else {
    Write-Host "ENTERING: Changes detected block" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Changes detected - will proceed with commit and PR creation" -ForegroundColor Cyan
    Write-Host "Setting has_changes=true" -ForegroundColor Cyan

    # Add GitHub Action summary
    $changesList = @()
    if ($readmeUpdated) { $changesList += "README updated" }
    if ($packagesUpdated) { $changesList += "NuGet packages updated" }
    $changesText = $changesList -join ", "

    $summary = @"
## 🔄 Changes Detected

**Changes found**: $changesText

Proceeding with commit and PR creation...
"@
    $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8

    echo "has_changes=true" >> $env:GITHUB_OUTPUT
}
