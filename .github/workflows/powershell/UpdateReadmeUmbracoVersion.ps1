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

  # Parse and sort versions to get the latest stable or prerelease
  $parsedVersions = $umbracoVersions | ForEach-Object {
    $versionString = $_
    $prerelease = ""

    # Split on hyphen to separate version from prerelease tag
    if ($versionString -match '^([0-9]+\.[0-9]+\.[0-9]+)(.*)$') {
      $baseVersion = $matches[1]
      $prerelease = $matches[2]
    } else {
      $baseVersion = $versionString
    }

    # Create object for sorting
    [PSCustomObject]@{
      Original = $versionString
      Version = [Version]$baseVersion
      Prerelease = $prerelease
      IsPrerelease = $prerelease -ne ""
    }
  }

  # Sort by version (descending), then by prerelease status (stable first)
  $sortedVersions = $parsedVersions | Sort-Object -Property @{Expression={$_.Version}; Descending=$true}, @{Expression={$_.IsPrerelease}; Descending=$false}

  # Get the latest version
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

    # Extract the Umbraco section (between "## Umbraco {version}" and "---")
    $umbracoPattern = "(?s)(## Umbraco $UmbracoMajorVersion.*?)(---)"
    if ($readmeContent -match $umbracoPattern) {
      $umbracoSection = $matches[1]
      $originalUmbracoSection = $umbracoSection

      Write-Host "Found Umbraco $UmbracoMajorVersion section, applying updates..." -ForegroundColor Yellow

      # Extract current version from README to compare
      $currentVersion = $null
      $pattern0 = '(dotnet new install Umbraco\.Templates::)([\d\.]+-?[\w\d]*)( --force)'
      if ($umbracoSection -match $pattern0) {
        # Save the original line immediately before $matches gets overwritten
        $oldLine0 = $matches[0]
        $currentVersion = $matches[2]
        Write-Host "  Current version in README: $currentVersion" -ForegroundColor Cyan

        # Compare versions semantically to prevent downgrades
        # Parse both versions to compare (handle prerelease tags)
        $currentBaseVersion = $currentVersion
        $latestBaseVersion = $latestUmbracoVersion
        $currentPrerelease = ""
        $latestPrerelease = ""

        if ($currentVersion -match '^([\d\.]+)(.*)$') {
          $currentBaseVersion = $matches[1]
          $currentPrerelease = $matches[2]
        }

        if ($latestUmbracoVersion -match '^([\d\.]+)(.*)$') {
          $latestBaseVersion = $matches[1]
          $latestPrerelease = $matches[2]
        }

        try {
          $currentVer = [Version]$currentBaseVersion
          $latestVer = [Version]$latestBaseVersion

          # Compare versions
          $comparison = $latestVer.CompareTo($currentVer)

          if ($comparison -lt 0) {
            # Latest version is lower than current - don't downgrade
            Write-Host "  ⚠️  Skipping update: Latest version ($latestUmbracoVersion) is lower than current version ($currentVersion)" -ForegroundColor Yellow
            $result.Updated = $false
            return $result
          } elseif ($comparison -eq 0) {
            # Same base version - check prerelease tags
            if ($latestPrerelease -eq $currentPrerelease) {
              Write-Host "  No change needed - already at version $latestUmbracoVersion" -ForegroundColor Cyan
            } else {
              Write-Host "  Updating prerelease tag from $currentVersion to $latestUmbracoVersion" -ForegroundColor Yellow
            }
          } else {
            # Latest version is higher - proceed with update
            Write-Host "  Updating from $currentVersion to $latestUmbracoVersion" -ForegroundColor Yellow
          }
        } catch {
          Write-Host "  Warning: Could not parse versions for comparison, proceeding with update" -ForegroundColor Yellow
        }

        # Perform the replacement
        $umbracoSection = $umbracoSection -replace $pattern0, "`${1}$latestUmbracoVersion`${3}"

        # Match again to get the new line for display
        if ($umbracoSection -match $pattern0) {
          $newLine0 = $matches[0]
          if ($oldLine0 -ne $newLine0) {
            Write-Host "  BEFORE: $oldLine0" -ForegroundColor Yellow
            Write-Host "  AFTER:  $newLine0" -ForegroundColor Green
          }
        }
      } else {
        Write-Host "  Warning: Could not find Umbraco.Templates pattern in Umbraco $UmbracoMajorVersion section" -ForegroundColor Yellow
      }

      # Replace the Umbraco section in the full content
      if ($originalUmbracoSection -ne $umbracoSection) {
        $readmeContent = $readmeContent -replace [regex]::Escape($originalUmbracoSection), $umbracoSection
        Write-Host "  Section was modified, updating README..." -ForegroundColor Green
      } else {
        Write-Host "  Section unchanged" -ForegroundColor Cyan
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
