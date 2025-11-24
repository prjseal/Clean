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
  [Alias('UmbracoVersions')]
  [object]$UmbracoMajorVersion = "13"
)

  Write-Host "================================================" -ForegroundColor Cyan
  Write-Host "Updating README with Latest Umbraco version(s): $UmbracoMajorVersion" -ForegroundColor Cyan
  Write-Host "================================================" -ForegroundColor Cyan

$result = @{
  Updated = $false
  Version = $null
  Error = $null
}

try {
  # Normalize requested majors into a string array (accepts string[] or comma-separated string)
  if ($UmbracoMajorVersion -is [System.Array]) {
    $majors = @($UmbracoMajorVersion) | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne '' }
  } else {
    $majors = $UmbracoMajorVersion.ToString().Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
  }

  if ($majors.Count -eq 0) {
    Write-Host "⚠️  No Umbraco major versions specified" -ForegroundColor Yellow
    $result.Error = "No Umbraco major versions specified"
    return $result
  }

  Write-Host "Processing Umbraco major versions: $($majors -join ', ')" -ForegroundColor Yellow

  # Read README once and update in-memory for each major
  if ([string]::IsNullOrWhiteSpace($ReadmePath)) { $ReadmePath = Join-Path $RootPath "README.md" }
  if (-not (Test-Path $ReadmePath)) {
    Write-Host "Warning: README.md not found at $ReadmePath" -ForegroundColor Yellow
    $result.Error = "README.md not found at $ReadmePath"
    return $result
  }

  $readmeContent = Get-Content $ReadmePath -Raw
  $originalContent = $readmeContent

  $updatedMajors = @()

  foreach ($major in $majors) {
    # Query NuGet API for the latest Umbraco $major version
    $packageId = "Umbraco.Cms.Web.Website"
    $nugetApiUrl = "https://api.nuget.org/v3-flatcontainer/$packageId/index.json"
    Write-Host "`nQuerying NuGet for latest Umbraco $major.x version..." -ForegroundColor Yellow
    try {
      $response = Invoke-RestMethod -Uri $nugetApiUrl -ErrorAction Stop
      $versions = $response.versions
    } catch {
      Write-Host ("⚠️  Failed to query NuGet for {0}: {1}" -f $packageId, $_.Exception.Message) -ForegroundColor Yellow
      $result.Error = $_.Exception.Message
      continue
    }

    $umbracoVersions = $versions | Where-Object { $_ -match "^$major\." }
    if ($umbracoVersions.Count -eq 0) {
      Write-Host "⚠️  No Umbraco $major.x versions found" -ForegroundColor Yellow
      $result.Error = "No Umbraco $major.x versions found"
      continue
    }

    # Parse and sort versions for this major
    $parsedVersions = $umbracoVersions | ForEach-Object {
      $versionString = $_
      $prTag = ""
      $prNum = 0
      if ($versionString -match '^([0-9]+\.[0-9]+\.[0-9]+)(?:-([A-Za-z]+)([0-9]*))?$') {
        $baseVersion = $matches[1]
        if ($matches[2]) { $prTag = $matches[2].ToLower() }
        if ($matches[3] -and $matches[3] -ne '') { $prNum = [int]$matches[3] }
      } else {
        $baseVersion = $versionString
      }
      switch ($prTag) {
        'rc'    { $prPriority = 70 }
        'beta'  { $prPriority = 50 }
        'alpha' { $prPriority = 30 }
        default { if ($prTag -ne '') { $prPriority = 40 } else { $prPriority = 100 } }
      }
      [pscustomobject]@{
        Original = $versionString
        Version = [Version]$baseVersion
        PrTag = $prTag
        PrNum = $prNum
        EffectivePriority = $prPriority + $prNum
      }
    }
    $sortedVersions = $parsedVersions | Sort-Object -Property @{Expression={$_.Version}; Descending=$true}, @{Expression={$_.EffectivePriority}; Descending=$true}
    $latestUmbracoVersion = $sortedVersions[0].Original
    Write-Host "Latest Umbraco $major.x version: $latestUmbracoVersion" -ForegroundColor Green

    # Apply targeted update for this major in the in-memory readme
    $sectionHeaderPattern = "(?m)^##\s+Umbraco\s+$major\b.*$"
    if ($readmeContent -match $sectionHeaderPattern) {
      $headerMatch = [regex]::Match($readmeContent, $sectionHeaderPattern)
      $startIndex = $headerMatch.Index
      $afterHeader = $readmeContent.Substring($startIndex)
      $endMarkerMatch = [regex]::Match($afterHeader, "(?s)---")
      if ($endMarkerMatch.Success) { $sectionLength = $endMarkerMatch.Index } else { $sectionLength = $afterHeader.Length }
      $umbracoSection = $readmeContent.Substring($startIndex, $sectionLength)
      $pattern0 = '(dotnet new install Umbraco\.Templates::)([0-9]+(?:\.[0-9]+){2}(?:-[A-Za-z0-9]+)?)( --force)'
      if ($umbracoSection -match $pattern0) {
        $oldLine0 = $matches[0]
        $currentVersion = $matches[2]
        # Replace version safely
        $replacementLine = $oldLine0.Replace($currentVersion, $latestUmbracoVersion)
        $umbracoSection = $umbracoSection.Replace($oldLine0, $replacementLine)
        # Update the readmeContent in-memory
        $readmeContent = $readmeContent.Substring(0, $startIndex) + $umbracoSection + $readmeContent.Substring($startIndex + $sectionLength)
        Write-Host "  Updated Umbraco $major section: $oldLine0 -> $replacementLine" -ForegroundColor Green
        $updatedMajors += $major
      } else {
        Write-Host "  Warning: Could not find Umbraco.Templates pattern in Umbraco $major section" -ForegroundColor Yellow
      }
    } else {
      Write-Host "Warning: Could not find Umbraco $major section in README.md" -ForegroundColor Yellow
    }
  }

  # After processing all majors, write back if changed
  if ($readmeContent -ne $originalContent) {
    Set-Content -Path $ReadmePath -Value $readmeContent -NoNewline
    Write-Host "`n✅ README.md updated successfully" -ForegroundColor Green
    $result.Updated = $true
    $result.Version = $updatedMajors -join ','
  } else {
    Write-Host "`nℹ️  README.md already has the correct version(s) or no changes were needed" -ForegroundColor Yellow
    $result.Updated = $false
    $result.Version = $updatedMajors -join ','
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
