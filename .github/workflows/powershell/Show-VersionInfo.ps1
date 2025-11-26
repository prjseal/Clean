<#
.SYNOPSIS
    Displays release version information in a formatted way.

.DESCRIPTION
    This script outputs formatted version information for a GitHub release,
    including the release tag, version, prerelease status, and release name.

.PARAMETER ReleaseTag
    The GitHub release tag

.PARAMETER Version
    The extracted version number

.PARAMETER IsPrerelease
    Boolean string indicating if this is a prerelease

.PARAMETER ReleaseName
    The name of the GitHub release

.EXAMPLE
    .\Show-VersionInfo.ps1 -ReleaseTag "v7.0.0" -Version "7.0.0" -IsPrerelease "false" -ReleaseName "Release 7.0.0"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$IsPrerelease,

    [Parameter(Mandatory = $true)]
    [string]$ReleaseName
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Release Version Information" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Release Tag: $ReleaseTag" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Prerelease: $IsPrerelease" -ForegroundColor Yellow
Write-Host "Release Name: $ReleaseName" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
