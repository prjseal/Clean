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

$readmeUpdated = $ReadmeUpdated -eq 'true'

# Check if packages were updated by reading the summary file
$summaryPath = "$WorkspacePath\.artifacts\package-summary.txt"
$packagesUpdated = $false
if (Test-Path $summaryPath) {
    $content = Get-Content $summaryPath -Raw
    $packagesUpdated = $content -notmatch 'No packages to update'
}

Write-Host "README updated: $readmeUpdated"
Write-Host "Packages updated: $packagesUpdated"

if (-not $readmeUpdated -and -not $packagesUpdated) {
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

    echo "has_changes=false" >> $env:GITHUB_OUTPUT
    exit 0
}
else {
    echo "has_changes=true" >> $env:GITHUB_OUTPUT
}
