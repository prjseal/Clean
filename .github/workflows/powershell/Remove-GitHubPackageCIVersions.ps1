<#
.SYNOPSIS
    Removes CI versions from GitHub Packages.

.DESCRIPTION
    This script deletes all package versions containing "-ci" in their name
    from the specified GitHub Packages, while preserving stable releases and
    package containers.

.PARAMETER RepositoryOwner
    The GitHub repository owner/organization name

.PARAMETER Packages
    Array of package names to clean up

.EXAMPLE
    .\Remove-GitHubPackageCIVersions.ps1 -RepositoryOwner "prjseal" -Packages @("Clean", "Clean.Core")
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryOwner,

    [Parameter(Mandatory = $true)]
    [string[]]$Packages
)

$headers = @{
    "Authorization" = "Bearer $env:GITHUB_TOKEN"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "GitHub Packages CI Versions Cleanup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Repository Owner: $RepositoryOwner" -ForegroundColor Yellow
Write-Host "Target: Versions containing '-ci'" -ForegroundColor Yellow
Write-Host ""

foreach ($packageName in $Packages) {
    Write-Host "Processing package: $packageName" -ForegroundColor Cyan

    try {
        # Get all versions of the package (with pagination support)
        $versionsUrl = "https://api.github.com/users/$RepositoryOwner/packages/nuget/$packageName/versions?per_page=100"
        Write-Host "  Fetching versions from: $versionsUrl" -ForegroundColor Gray

        $allVersions = @()
        $currentUrl = $versionsUrl

        # Handle pagination - GitHub API returns 30 items by default, max 100 per page
        while ($currentUrl) {
            $response = Invoke-WebRequest -Uri $currentUrl -Headers $headers -ErrorAction Stop
            $pageVersions = $response.Content | ConvertFrom-Json
            $allVersions += $pageVersions

            Write-Host "    Fetched $($pageVersions.Count) versions (Total so far: $($allVersions.Count))" -ForegroundColor Gray

            # Check for next page in Link header
            $linkHeader = $response.Headers['Link']
            $currentUrl = $null

            if ($linkHeader) {
                # Parse Link header to find 'next' URL
                # Format: <url>; rel="next", <url>; rel="last"
                $links = $linkHeader -split ','
                foreach ($link in $links) {
                    if ($link -match '<([^>]+)>;\s*rel="next"') {
                        $currentUrl = $matches[1]
                        Write-Host "    Found next page, continuing..." -ForegroundColor Gray
                        break
                    }
                }
            }
        }

        $versions = $allVersions

        if ($versions.Count -eq 0) {
            Write-Host "  No versions found for $packageName" -ForegroundColor Yellow
            Write-Host ""
            continue
        }

        # Filter for CI versions only (versions containing "-ci")
        $ciVersions = $versions | Where-Object { $_.name -match '-ci' }

        if ($ciVersions.Count -eq 0) {
            Write-Host "  No CI versions found for $packageName (Total versions: $($versions.Count))" -ForegroundColor Yellow
            Write-Host ""
            continue
        }

        Write-Host "  Found $($ciVersions.Count) CI version(s) out of $($versions.Count) total versions" -ForegroundColor Green

        # Delete each CI version
        $deleteCount = 0
        $failCount = 0

        foreach ($version in $ciVersions) {
            $versionId = $version.id
            $versionName = $version.name

            try {
                $deleteUrl = "https://api.github.com/users/$RepositoryOwner/packages/nuget/$packageName/versions/$versionId"
                Write-Host "    Deleting version: $versionName (ID: $versionId)" -ForegroundColor Yellow

                Invoke-RestMethod -Uri $deleteUrl -Method DELETE -Headers $headers -ErrorAction Stop | Out-Null

                Write-Host "    ✓ Deleted: $versionName" -ForegroundColor Green
                $deleteCount++

                # Small delay to avoid rate limiting
                Start-Sleep -Milliseconds 100

            } catch {
                Write-Host "    ✗ Failed to delete version $versionName : $($_.Exception.Message)" -ForegroundColor Red
                $failCount++
            }
        }

        Write-Host "  Summary for $packageName : $deleteCount deleted, $failCount failed" -ForegroundColor Cyan
        Write-Host ""

    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Host "  Package '$packageName' not found (may not exist yet)" -ForegroundColor Yellow
        } else {
            Write-Host "  Error processing package '$packageName': $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "CI Versions Cleanup Complete" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: Only CI versions (containing '-ci') were deleted." -ForegroundColor Green
Write-Host "Stable/release versions remain intact." -ForegroundColor Green
Write-Host "Package containers remain intact." -ForegroundColor Green
Write-Host "You can still publish new versions to these packages." -ForegroundColor Green
