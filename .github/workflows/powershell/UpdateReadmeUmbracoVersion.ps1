<#
.SYNOPSIS
 Updates README.md with the latest Umbraco version from NuGet.

.PARAMETER RootPath
 Repository root where README.md is located. Defaults to current directory.

.PARAMETER ReadmePath
 Path to the README.md file. If not provided, looks for README.md in RootPath.

.PARAMETER UmbracoMajorVersion
 The Umbraco major version to update (e.g., "13", "17"). Defaults to "13".

.OUTPUTS
 Returns a hashtable with:
 - Updated: $true if README was modified, $false otherwise
 - Version: The latest Umbraco version found
 - Error: Error message if something went wrong
#>
param(
  [string]$RootPath = (Get-Location).Path,
  [string]$ReadmePath = "",
  [string]$UmbracoMajorVersion = "13"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Updating README with Latest Umbraco $UmbracoMajorVersion Version" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$result = @{
  Updated = $false
  Version = $null
  Error = $null
}

try {
  # Query NuGet API for the latest Umbraco version
  $packageId = "Umbraco.Cms.Web.Website"
  $nugetApiUrl = "https://api.nuget.org/v3-flatcontainer/$packageId/index.json"

  Write-Host "`nQuerying NuGet for latest Umbraco $UmbracoMajorVersion.x version..." -ForegroundColor Yellow

  $response = Invoke-RestMethod -Uri $nugetApiUrl -ErrorAction Stop
  $versions = $response.versions

  # Filter to only Umbraco versions matching the major version
  $umbracoVersions = $versions | Where-Object { $_ -match "^$UmbracoMajorVersion\." }

  if ($umbracoVersions.Count -eq 0) {
    Write-Host "⚠️  No Umbraco $UmbracoMajorVersion.x versions found" -ForegroundColor Yellow
    $result.Error = "No Umbraco $UmbracoMajorVersion.x versions found"
    return $result
  }

  # Parse versions and compute a priority so we pick stable > rc > beta > alpha (and respect numeric suffixes)
  $parsedVersions = $umbracoVersions | ForEach-Object {
    $versionString = $_
    $prerelease = ""
    $prTag = ""
    $prNum = 0

    # Split base version and prerelease (e.g. 17.0.0-rc3)
    if ($versionString -match '^([0-9]+\.[0-9]+\.[0-9]+)(?:-([A-Za-z]+)([0-9]*))?$') {
      $baseVersion = $matches[1]
      if ($matches[2]) { $prTag = $matches[2].ToLower() }
      if ($matches[3]) { $prNum = if ($matches[3] -ne '') { [int]$matches[3] } else { 0 } }
      if ($prTag) { $prerelease = "-$prTag$prNum" }
    } else {
      $baseVersion = $versionString
    }

    # Map prerelease tags to priorities: stable=100, rc=70, beta=50, alpha=30, other=40
    switch ($prTag) {
      'rc'    { $prPriority = 70 }
      'beta'  { $prPriority = 50 }
      'alpha' { $prPriority = 30 }
      default { if ($prTag -ne '') { $prPriority = 40 } else { $prPriority = 100 } }
    }

    # Incorporate numeric suffix into priority for ordering (higher number -> higher priority)
    $effectivePriority = $prPriority + $prNum

    [PSCustomObject]@{
      Original = $versionString
      Version = [Version]$baseVersion
      Prerelease = $prerelease
      PrTag = $prTag
      PrNum = $prNum
      PrPriority = $prPriority
      EffectivePriority = $effectivePriority
    }
  }

  # Sort by version (descending), then by EffectivePriority (descending)
  $sortedVersions = $parsedVersions | Sort-Object -Property @{Expression={$_.Version}; Descending=$true}, @{Expression={$_.EffectivePriority}; Descending=$true}

  # Get the latest version (Original string)
  $latestUmbracoVersion = $sortedVersions[0].Original
  $result.Version = $latestUmbracoVersion

  Write-Host "Latest Umbraco $UmbracoMajorVersion.x version: $latestUmbracoVersion" -ForegroundColor Green

  # Determine README path
  if ([string]::IsNullOrWhiteSpace($ReadmePath)) {
    $ReadmePath = Join-Path $RootPath "README.md"
  }

  # Update README.md with the new version for Umbraco examples
  if (Test-Path $ReadmePath) {
    Write-Host "`nUpdating README.md with version $latestUmbracoVersion for Umbraco $UmbracoMajorVersion examples..."

    $readmeContent = Get-Content $ReadmePath -Raw
    $originalContent = $readmeContent

    # Extract the Umbraco section header (## Umbraco {version}) and operate only within that section
    # We'll replace only the specific `dotnet new install` line inside the matching section to avoid accidental cross-section changes
    $sectionHeaderPattern = "(?m)^##\s+Umbraco\s+$UmbracoMajorVersion\b.*$"  # header line
    if ($readmeContent -match $sectionHeaderPattern) {
      # Find the start index of the header
      $headerMatch = [regex]::Match($readmeContent, $sectionHeaderPattern)
      $startIndex = $headerMatch.Index

      # Find the end of this section by looking for the next top-level '---' that denotes section break after the header
      $afterHeader = $readmeContent.Substring($startIndex)
      $endMarkerMatch = [regex]::Match($afterHeader, "(?s)---")
      if ($endMarkerMatch.Success) {
        $sectionLength = $endMarkerMatch.Index
      } else {
        # If no '---' found after header, operate until end of file
        $sectionLength = $afterHeader.Length
      }

      $umbracoSection = $readmeContent.Substring($startIndex, $sectionLength)
      $originalUmbracoSection = $umbracoSection

      Write-Host "Found Umbraco $UmbracoMajorVersion section, applying targeted updates..." -ForegroundColor Yellow

      # Pattern to find the dotnet install line and capture existing version
      $pattern0 = '(dotnet new install Umbraco\.Templates::)([0-9]+(?:\.[0-9]+){2}(?:-[A-Za-z0-9]+)?)( --force)'
      $currentVersion = $null
      $oldLine0 = $null
      if ($umbracoSection -match $pattern0) {
        $oldLine0 = $matches[0]
        $currentVersion = $matches[2]
        Write-Host "  Current version in README: $currentVersion" -ForegroundColor Cyan

        # Compare base versions to prevent downgrades
        if ($currentVersion -match '^([0-9]+\.[0-9]+\.[0-9]+)') { $currentBase = $matches[1] } else { $currentBase = $currentVersion }
        if ($latestUmbracoVersion -match '^([0-9]+\.[0-9]+\.[0-9]+)') { $latestBase = $matches[1] } else { $latestBase = $latestUmbracoVersion }

        try {
          $currentVer = [Version]$currentBase
          $latestVer = [Version]$latestBase
          $comparison = $latestVer.CompareTo($currentVer)
          if ($comparison -lt 0) {
            Write-Host "  ⚠️  Skipping update: Latest version ($latestUmbracoVersion) is lower than current version ($currentVersion)" -ForegroundColor Yellow
            $result.Updated = $false
            return $result
          } elseif ($comparison -eq 0) {
            if ($latestUmbracoVersion -eq $currentVersion) {
              Write-Host "  No change needed - already at version $latestUmbracoVersion" -ForegroundColor Cyan
            } else {
              Write-Host "  Updating prerelease tag from $currentVersion to $latestUmbracoVersion" -ForegroundColor Yellow
            }
          } else {
            Write-Host "  Updating from $currentVersion to $latestUmbracoVersion" -ForegroundColor Yellow
          }
        } catch {
          Write-Host "  Warning: Could not parse versions for comparison, proceeding with update" -ForegroundColor Yellow
        }

        # Replace only the version portion of the matched line using literal string replace
        $replacementLine = "$($matches[1])$latestUmbracoVersion$($matches[3])"
        $umbracoSection = $umbracoSection.Replace($oldLine0, $replacementLine)

        # Update the full readme content by replacing only this section
        $readmeContent = $readmeContent.Substring(0, $startIndex) + $umbracoSection + $readmeContent.Substring($startIndex + $sectionLength)

        Write-Host "  BEFORE: $oldLine0" -ForegroundColor Yellow
        Write-Host "  AFTER:  $replacementLine" -ForegroundColor Green
      } else {
        Write-Host "  Warning: Could not find Umbraco.Templates pattern in Umbraco $UmbracoMajorVersion section" -ForegroundColor Yellow
      }
    } else {
      Write-Host "Warning: Could not find Umbraco $UmbracoMajorVersion section in README.md" -ForegroundColor Yellow
    }

    if ($readmeContent -ne $originalContent) {
      Set-Content -Path $ReadmePath -Value $readmeContent -NoNewline
      Write-Host "`n✅ README.md updated successfully with version $latestUmbracoVersion" -ForegroundColor Green
      $result.Updated = $true
    } else {
      Write-Host "`nℹ️  README.md already has the correct version or no changes were needed" -ForegroundColor Yellow
      $result.Updated = $false
    }
  } else {
    Write-Host "Warning: README.md not found at $ReadmePath" -ForegroundColor Yellow
    $result.Error = "README.md not found at $ReadmePath"
  }

  Write-Host "`n================================================" -ForegroundColor Cyan
  Write-Host "README update complete" -ForegroundColor Green
  Write-Host "================================================" -ForegroundColor Cyan

} catch {
  Write-Host "⚠️  Error updating README: $_" -ForegroundColor Yellow
  Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
  $result.Error = $_.Exception.Message
}

return $result
