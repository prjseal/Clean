<#
.SYNOPSIS
    Commits and pushes changes to a new branch.

.DESCRIPTION
    This script creates a new branch, commits changes with an appropriate message
    based on what was updated, and pushes to the remote repository.

.PARAMETER ReadmeUpdated
    Boolean string indicating if README was updated

.PARAMETER UpdatedVersions
    Comma-separated list of updated Umbraco versions

.PARAMETER WorkspacePath
    The GitHub workspace path

.PARAMETER Repository
    The GitHub repository in owner/repo format

.PARAMETER PatToken
    Personal Access Token for authentication

.EXAMPLE
    .\Invoke-CommitAndPush.ps1 -ReadmeUpdated "true" -UpdatedVersions "13" -WorkspacePath "/workspace" -Repository "owner/repo" -PatToken "token"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ReadmeUpdated,

    [Parameter(Mandatory = $false)]
    [string]$UpdatedVersions = "",

    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$PatToken
)

# Early exit: Check if there are actually any changes to commit
# Explicitly convert string to boolean using if statement to guarantee proper boolean type
if ($ReadmeUpdated -eq 'true') {
    $readmeUpdated = $true
} else {
    $readmeUpdated = $false
}

$summaryPath = "$WorkspacePath\.artifacts\package-summary.txt"
$packagesUpdated = $false
if (Test-Path $summaryPath) {
    $content = Get-Content $summaryPath -Raw
    $packagesUpdated = $content -notmatch 'No packages to update'
}

Write-Host "Commit check - README updated: $readmeUpdated (type: $($readmeUpdated.GetType().Name)), Packages updated: $packagesUpdated"

if (-not $readmeUpdated -and -not $packagesUpdated) {
    Write-Host "No changes detected (neither README nor packages updated). Exiting without creating branch." -ForegroundColor Yellow
    exit 0
}

$branchName = "update-nuget-packages-$(Get-Date -Format 'yyyyMMddHHmmss')"
echo "branchName=$branchName" >> $env:GITHUB_OUTPUT

git config user.name "github-actions"
git config user.email "github-actions@github.com"
git checkout -b $branchName
git add .
if (git diff --cached --quiet) {
    Write-Host "No changes detected in git. Skipping commit and PR."
    exit 0
}

# Create appropriate commit message
if ($readmeUpdated -and -not $packagesUpdated) {
    # Only README updated - skip CI builds
    $updatedVersions = $UpdatedVersions -split ',' | ForEach-Object { $_.Trim() }
    if ($updatedVersions.Count -eq 1) {
        $versionText = "Umbraco $($updatedVersions[0])"
    }
    else {
        $versionText = "Umbraco $($updatedVersions -join ' and ')"
    }
    $commitMessage = "Update README with latest $versionText version [skip ci]"
    Write-Host "Only README updated - adding [skip ci] to commit message" -ForegroundColor Cyan
}
elseif (-not $readmeUpdated -and $packagesUpdated) {
    # Only packages updated
    $commitMessage = "Update NuGet packages"
}
else {
    # Both updated
    $commitMessage = "Update README and NuGet packages"
}

git commit -m $commitMessage
git push https://x-access-token:$PatToken@github.com/$Repository.git $branchName
