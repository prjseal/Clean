<#
.SYNOPSIS
  Update Umbraco/uSync NuGet packages in the template folder, optionally include prerelease, build, and run Clean.Blog.
.DESCRIPTION
Scans for .csproj files in the template folder and updates Umbraco/uSync packages
Queries NuGet for latest (or prerelease) versions
Updates csproj files, builds solutions, and runs Clean.Blog project
Outputs results as color-coded lists
#>
param(
    [string]$RootPath = (Get-Location).Path,
    [switch]$DryRun,
    [switch]$IncludePrerelease
)

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = (Get-Date).ToString('s')
    Write-Host "[$ts] [$Level] $Message"
}

function Fail-Fast {
    param([string]$Message)
    Write-Log $Message "ERROR"
    exit 1
}

function Get-LatestNuGetVersion {
    param(
        [string]$packageId,
        [ref]$cache,
        [switch]$IncludePrerelease
    )
    if ($cache.Value.ContainsKey($packageId.ToLower())) {
        return $cache.Value[$packageId.ToLower()]
    }
    $lowerId = $packageId.ToLower()
    $url = "https://api.nuget.org/v3-flatcontainer/$lowerId/index.json" 
    try {
        Write-Log "Querying NuGet for ${packageId}"
        $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
        if (-not $resp.versions) {
            Write-Log "No versions found for ${packageId}" "WARN"
            $cache.Value[$lowerId] = $null
            return $null
        }
        $versions = $resp.versions | ForEach-Object { $_ }
        if (-not $IncludePrerelease) {
            $stable = $versions | Where-Object { $_ -notmatch '-' }
            $chosen = if ($stable.Count -gt 0) { $stable[-1] } else { $versions[-1] }
        } else {
            $chosen = $versions[-1]
        }
        $cache.Value[$lowerId] = $chosen
        return $chosen
    } catch {
        Write-Log "Failed to query NuGet for ${packageId}: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Update-Csproj-PackageReferences {
    param(
        [string]$csprojPath,
        [ref]$versionCache,
        [switch]$DryRunFlag,
        [switch]$IncludePrerelease
    )
    $result = [ordered]@{
        Path     = $csprojPath
        Updated  = $false
        Changes  = @()
        Errors   = @()
    }
    try {
        [xml]$xml = Get-Content -Path $csprojPath -Raw
    } catch {
        $result.Errors += "Failed to read XML: $($_.Exception.Message)"
        return $result
    }
    $pattern = '^(?i)^(Umbraco\..*|uSync|usync)$'
    $prNodes = $xml.SelectNodes("//PackageReference")
    foreach ($pr in $prNodes) {
        $pkgId = $pr.Include
        if (-not $pkgId) { continue }
        if ($pkgId -match $pattern) {
            $existingVersion = if ($pr.HasAttribute("Version")) { $pr.Version } else {
                ($pr.SelectSingleNode("Version")).InnerText
            }
            $latest = Get-LatestNuGetVersion -packageId $pkgId -cache ([ref]$versionCache.Value) -IncludePrerelease:$IncludePrerelease
            if (-not $latest) { continue }
            if ($existingVersion -and ($existingVersion -ieq $latest)) { continue }
            if (-not $DryRunFlag) {
                if ($pr.HasAttribute("Version")) {
                    $pr.SetAttribute("Version", $latest)
                } else {
                    $verNode = $pr.SelectSingleNode("Version")
                    if ($verNode) {
                        $verNode.InnerText = $latest
                    } else {
                        $verNode = $xml.CreateElement("Version")
                        $verNode.InnerText = $latest
                        $pr.AppendChild($verNode) | Out-Null
                    }
                }
            }
            $result.Updated = $true
            $result.Changes += [ordered]@{
                Package     = $pkgId
                OldVersion  = $existingVersion
                NewVersion  = $latest
            }
        }
    }
    if ($result.Updated -and -not $DryRunFlag) {
        try { $xml.Save($csprojPath) }
        catch { $result.Errors += "Failed to save XML: $($_.Exception.Message)" }
    }
    return $result
}

function Run-DotNet {
    param(
        [string]$Command,
        [string]$Path,
        [switch]$DryRunFlag
    )
    $result = [ordered]@{
        Command = $Command
        Path    = $Path
        Success = $true
        ExitCode = 0
        Output = ""
        Error  = ""
    }
    if ($DryRunFlag) {
        $result.Output = "DryRun"
        return $result
    }
    try {
        Push-Location $Path
        $output = & dotnet $Command 2>&1
        $result.Output = $output -join "`n"
        $result.ExitCode = $LASTEXITCODE
        $result.Success = ($LASTEXITCODE -eq 0)
    } catch {
        $result.Success = $false
        $result.Error = $_.Exception.Message
    } finally {
        Pop-Location
    }
    return $result
}

# MAIN
Write-Log "Starting package update... IncludePrerelease=$IncludePrerelease, DryRun=$DryRun"

$templatePath = Join-Path $RootPath "template"
if (-not (Test-Path $templatePath)) {
    Fail-Fast "Template folder not found at '$templatePath'."
}

Write-Log "Scanning for csproj files in template folder..."
$csprojFiles = Get-ChildItem -Path $templatePath -Filter *.csproj -Recurse -File
if ($csprojFiles.Count -eq 0) { Fail-Fast "No .csproj files found in '$templatePath'." }
Write-Log "Found $($csprojFiles.Count) csproj files."

$versionCache = @{}
$updateResults = @()
foreach ($csproj in $csprojFiles) {
    $updateResults += Update-Csproj-PackageReferences -csprojPath $csproj.FullName -versionCache ([ref]$versionCache) -DryRunFlag:$DryRun -IncludePrerelease:$IncludePrerelease
}

Write-Host "`n===== PACKAGE UPDATE RESULTS ====="
foreach ($result in $updateResults) {
    $projName = [System.IO.Path]::GetFileName($result.Path)
    if ($result.Updated) {
        Write-Host "`n${projName}" -ForegroundColor Cyan
        foreach ($change in $result.Changes) {
            Write-Host "  " -NoNewline
            Write-Host "$($change.Package)" -ForegroundColor Green -NoNewline
            Write-Host " updated from " -NoNewline
            Write-Host "$($change.OldVersion)" -ForegroundColor Yellow -NoNewline
            Write-Host " to " -NoNewline
            Write-Host "$($change.NewVersion)" -ForegroundColor Green
        }
    } else {
        Write-Host "`n${projName}: No packages to update" -ForegroundColor DarkGray
    }
}

Write-Log "Scanning for sln files..."
$slnFiles = Get-ChildItem -Path $RootPath -Filter *.sln -Recurse -File
Write-Log "Found $($slnFiles.Count) sln files."

$buildResults = @()
foreach ($sln in $slnFiles) {
    $cleanResult = Run-DotNet -Command "clean `"$($sln.FullName)`"" -Path $sln.DirectoryName -DryRunFlag:$DryRun
    $buildResult = Run-DotNet -Command "build `"$($sln.FullName)`"" -Path $sln.DirectoryName -DryRunFlag:$DryRun
    $buildResults += [ordered]@{
        Solution = $sln.FullName
        Success  = $buildResult.Success
    }
}

Write-Host "`n===== BUILD RESULTS ====="
foreach ($br in $buildResults) {
    $slnName = [System.IO.Path]::GetFileName($br.Solution)
    $status = if ($br.Success) { "SUCCESS" } else { "FAILED" }
    $color = if ($br.Success) { "Green" } else { "Red" }
    Write-Host "${slnName}: $status" -ForegroundColor $color
}

$blogProj = Get-ChildItem -Path $templatePath -Recurse -Filter *.csproj | Where-Object { $_.Name -match '(?i)clean\.blog' } | Select-Object -First 1
if ($blogProj) {
    Write-Host "`nClean.Blog project found: $($blogProj.Name)" -ForegroundColor Cyan
    if (-not $DryRun) {
        $runResult = Run-DotNet -Command "run --project `"$($blogProj.FullName)`"" -Path $blogProj.DirectoryName
        $status = if ($runResult.Success) { "SUCCESS" } else { "FAILED" }
        $color = if ($runResult.Success) { "Green" } else { "Red" }
        Write-Host "Run result: $status" -ForegroundColor $color
    } else {
        Write-Host "Run skipped (DryRun)" -ForegroundColor DarkGray
    }
}