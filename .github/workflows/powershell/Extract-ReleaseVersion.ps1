<#
.SYNOPSIS
    Extracts and validates version from a GitHub release tag.

.DESCRIPTION
    This script extracts version information from a GitHub release tag,
    validates the version format, and determines if it's a prerelease.
    Outputs version information for use in subsequent workflow steps.

.PARAMETER ReleaseTag
    The GitHub release tag (e.g., v7.0.0 or 7.0.0)

.PARAMETER IsPrerelease
    Boolean string indicating if this is a prerelease

.EXAMPLE
    .\Extract-ReleaseVersion.ps1 -ReleaseTag "v7.0.0" -IsPrerelease "false"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $true)]
    [string]$IsPrerelease
)

Write-Host "Release tag: $ReleaseTag"

# Remove 'v' prefix if present
$version = $ReleaseTag -replace '^v', ''

# Validate version format (basic SemVer check)
if ($version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9\.\-]+)?$') {
    Write-Host "::error::Invalid version format: $version. Expected format: X.Y.Z or X.Y.Z-prerelease" -ForegroundColor Red
    exit 1
}

Write-Host "Release version: $version" -ForegroundColor Green
Write-Host "Is prerelease: $IsPrerelease"

# Output the version for use in subsequent steps
echo "version=$version" >> $env:GITHUB_OUTPUT
echo "is_prerelease=$IsPrerelease" >> $env:GITHUB_OUTPUT
