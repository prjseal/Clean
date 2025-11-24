<#
.SYNOPSIS
 Updates README.md with the latest Umbraco 13.x version from NuGet.

.PARAMETER RootPath
 Repository root where README.md is located. Defaults to current directory.

.PARAMETER ReadmePath
 Path to the README.md file. If not provided, looks for README.md in RootPath.

.OUTPUTS
 Returns a hashtable with:
 - Updated: $true if README was modified, $false otherwise
 - Version: The latest Umbraco 13.x version found
 - Error: Error message if something went wrong
#>
param(
  [string]$RootPath = (Get-Location).Path,
  [string]$ReadmePath = ""
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Updating README with Latest Umbraco 13 Version" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$result = @{
  Updated = $false
  Version = $null
  Error = $null
}

try {
  # Query NuGet API for the latest Umbraco 13.x version
  $packageId = "Umbraco.Cms.Web.Website"
  $nugetApiUrl = "https://api.nuget.org/v3-flatcontainer/$packageId/index.json"

  Write-Host "`nQuerying NuGet for latest Umbraco 13.x version..." -ForegroundColor Yellow

  $response = Invoke-RestMethod -Uri $nugetApiUrl -ErrorAction Stop
  $versions = $response.versions

  # Filter to only Umbraco 13.x versions
  $umbraco13Versions = $versions | Where-Object { $_ -match '^13\.' }

  if ($umbraco13Versions.Count -eq 0) {
    Write-Host "⚠️  No Umbraco 13.x versions found" -ForegroundColor Yellow
    $result.Error = "No Umbraco 13.x versions found"
    return $result
  }

  # Parse and sort versions to get the latest stable or prerelease
  $parsedVersions = $umbraco13Versions | ForEach-Object {
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
  $latestUmbraco13Version = $sortedVersions[0].Original
  $result.Version = $latestUmbraco13Version

  Write-Host "Latest Umbraco 13.x version: $latestUmbraco13Version" -ForegroundColor Green

  # Determine README path
  if ([string]::IsNullOrWhiteSpace($ReadmePath)) {
    $ReadmePath = Join-Path $RootPath "README.md"
  }

  # Update README.md with the new version for Umbraco 13 examples
  if (Test-Path $ReadmePath) {
    Write-Host "`nUpdating README.md with version $latestUmbraco13Version for Umbraco 13 examples..."

    $readmeContent = Get-Content $ReadmePath -Raw
    $originalContent = $readmeContent

    # Extract the Umbraco 13 section (between "## Umbraco 13" and "---")
    $umbraco13Pattern = '(?s)(## Umbraco 13.*?)(---)'
    if ($readmeContent -match $umbraco13Pattern) {
      $umbraco13Section = $matches[1]
      $originalUmbraco13Section = $umbraco13Section

      Write-Host "Found Umbraco 13 section, applying updates..." -ForegroundColor Yellow

      # Pattern: Update Umbraco.Templates version for Umbraco 13
      $pattern0 = '(dotnet new install Umbraco\.Templates::)[\d\.]+-?[\w\d]*( --force)'
      if ($umbraco13Section -match $pattern0) {
        $oldLine0 = $matches[0]
        $umbraco13Section = $umbraco13Section -replace $pattern0, "`${1}$latestUmbraco13Version`${2}"
        if ($umbraco13Section -match $pattern0) {
          $newLine0 = $matches[0]
          if ($oldLine0 -ne $newLine0) {
            Write-Host "  BEFORE: $oldLine0" -ForegroundColor Yellow
            Write-Host "  AFTER:  $newLine0" -ForegroundColor Green
          } else {
            Write-Host "  No change needed - already at version $latestUmbraco13Version" -ForegroundColor Cyan
          }
        }
      } else {
        Write-Host "  Warning: Could not find Umbraco.Templates pattern in Umbraco 13 section" -ForegroundColor Yellow
      }

      # Replace the Umbraco 13 section in the full content
      if ($originalUmbraco13Section -ne $umbraco13Section) {
        $readmeContent = $readmeContent -replace [regex]::Escape($originalUmbraco13Section), $umbraco13Section
        Write-Host "  Section was modified, updating README..." -ForegroundColor Green
      } else {
        Write-Host "  Section unchanged" -ForegroundColor Cyan
      }
    } else {
      Write-Host "Warning: Could not find Umbraco 13 section in README.md" -ForegroundColor Yellow
    }

    if ($readmeContent -ne $originalContent) {
      Set-Content -Path $ReadmePath -Value $readmeContent -NoNewline
      Write-Host "`n✅ README.md updated successfully with version $latestUmbraco13Version" -ForegroundColor Green
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
