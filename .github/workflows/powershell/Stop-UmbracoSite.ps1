#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Stops a running Umbraco site process.

.DESCRIPTION
    This script gracefully stops an Umbraco site process by its Process ID (PID).
    It checks if the process exists and is still running before attempting to stop it,
    and handles cases where the process has already exited.

    This is typically used as a cleanup step in workflows after security scanning or
    testing is complete.

.PARAMETER SitePid
    The Process ID of the Umbraco site to stop.

.EXAMPLE
    ./Stop-UmbracoSite.ps1 -SitePid 12345

    Stops the Umbraco site process with PID 12345.

.EXAMPLE
    ./Stop-UmbracoSite.ps1 -SitePid "${{ steps.setup-site.outputs.site_pid }}"

    Stops the Umbraco site process using the PID from a previous workflow step.

.NOTES
    This script is designed to be run in GitHub Actions workflows but can also be
    run locally for manual cleanup.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SitePid
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Umbraco Site Cleanup - Stop Process" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $SitePid) {
    Write-Host "No site PID provided, skipping cleanup" -ForegroundColor Yellow
    exit 0
}

Write-Host "Stopping site process (PID: $SitePid)..." -ForegroundColor Yellow
Write-Host ""

try {
    # Check if process exists and is running
    $process = Get-Process -Id $SitePid -ErrorAction SilentlyContinue

    if ($process) {
        Write-Host "Process found: $($process.ProcessName) (PID: $SitePid)" -ForegroundColor Cyan
        Write-Host "Stopping process..." -ForegroundColor Yellow

        Stop-Process -Id $SitePid -Force -ErrorAction SilentlyContinue

        # Wait a moment and verify it stopped
        Start-Sleep -Milliseconds 500
        $stillRunning = Get-Process -Id $SitePid -ErrorAction SilentlyContinue

        if (-not $stillRunning) {
            Write-Host "✓ Site process stopped successfully" -ForegroundColor Green
        }
        else {
            Write-Host "⚠ Process may still be running" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "✓ Site process already exited" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error stopping process: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "This is usually not critical - the process may have already exited" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Cleanup Complete" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
