<#
.SYNOPSIS
    Creates a pull request with version updates.

.DESCRIPTION
    This script creates a pull request to merge version updates back to the main branch.
    It commits .csproj and README file changes and creates a PR using the GitHub CLI.

.PARAMETER Version
    The version number being released

.PARAMETER IsPrerelease
    Boolean string indicating if this is a prerelease

.PARAMETER ReleaseUrl
    URL to the GitHub release

.EXAMPLE
    .\New-VersionUpdatePullRequest.ps1 -Version "7.0.0" -IsPrerelease "false" -ReleaseUrl "https://github.com/..."
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$IsPrerelease,

    [Parameter(Mandatory = $true)]
    [string]$ReleaseUrl
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Creating PR with Version Updates" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Configure git with bot user
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Fetch main branch
Write-Host "Fetching main branch..." -ForegroundColor Yellow
git fetch origin main

# Check if there are any changes to commit
$gitStatus = git status --porcelain
if ([string]::IsNullOrWhiteSpace($gitStatus)) {
    Write-Host "No changes to commit - versions are already up to date" -ForegroundColor Yellow
    exit 0
}

# Show what files will be committed
Write-Host "`nModified files:" -ForegroundColor Cyan
git status --short

# Create a new branch for the version update
$branchName = "release/update-versions-$Version"
Write-Host "`nCreating branch: $branchName" -ForegroundColor Yellow
git checkout -b $branchName

# Stage all .csproj and README.md files
Write-Host "`nStaging .csproj files..." -ForegroundColor Yellow
git add "*.csproj" "**/*.csproj"

Write-Host "Staging README.md file..." -ForegroundColor Yellow
git add "README.md"

Write-Host "Staging Umbraco marketplace README files..." -ForegroundColor Yellow
git add "umbraco-marketplace-readme.md" "umbraco-marketplace-readme-clean.md"

# Commit with skip ci flag to prevent triggering other workflows
$commitMessage = "chore: Update versions to $Version [skip ci]"
Write-Host "`nCommitting changes with message: $commitMessage" -ForegroundColor Yellow
git commit -m $commitMessage

# Push the branch
Write-Host "`nPushing branch to origin..." -ForegroundColor Yellow
git push -u origin $branchName

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to push branch (exit code: $LASTEXITCODE)" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Successfully pushed branch $branchName" -ForegroundColor Green

# Create pull request
Write-Host "`nCreating pull request..." -ForegroundColor Yellow
$prTitle = "chore: Update versions to $Version"
$prBody = @"
## Summary
This PR updates version references in the codebase following the release of version $Version.

## Changes
- Updated version references in .csproj files
- Updated README.md with the latest version information
- Updated Umbraco marketplace README files with the latest version information

## Additional Info
- Release: [$ReleaseUrl]($ReleaseUrl)
- Prerelease: $IsPrerelease

---
*This PR was automatically created by the release workflow.*
"@

gh pr create --title $prTitle --body $prBody --base main --head $branchName

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully created pull request" -ForegroundColor Green
}
else {
    Write-Host "❌ Failed to create pull request (exit code: $LASTEXITCODE)" -ForegroundColor Red
    exit 1
}

Write-Host "================================================" -ForegroundColor Cyan
