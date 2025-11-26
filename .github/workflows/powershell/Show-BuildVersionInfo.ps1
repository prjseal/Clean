<#
.SYNOPSIS
    Displays build version information in a formatted way.

.DESCRIPTION
    This script outputs formatted build version information including
    base version, build number, and full version string.

.PARAMETER BaseVersion
    The base version number

.PARAMETER BuildNumber
    The build/run number

.PARAMETER FullVersion
    The complete version string with build number

.EXAMPLE
    .\Show-BuildVersionInfo.ps1 -BaseVersion "7.0.0" -BuildNumber "123" -FullVersion "7.0.0-ci.123"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$BaseVersion,

    [Parameter(Mandatory = $true)]
    [string]$BuildNumber,

    [Parameter(Mandatory = $true)]
    [string]$FullVersion
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Build Version Information" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Base Version: $BaseVersion" -ForegroundColor Green
Write-Host "Build Number: $BuildNumber" -ForegroundColor Green
Write-Host "Full Version: $FullVersion" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
