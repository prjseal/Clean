<#
.SYNOPSIS
 Update NuGet packages in the RootPath folder, optionally include prerelease and build
 Outputs a console table of package updates and detailed per-solution diagnostics (stdout/stderr and inline error summaries).

.PARAMETER RootPath
 Repository root. It defaults to the current working directory.

.PARAMETER DryRun
 If set, no files are changed and no dotnet commands are executed (logic still runs).

.PARAMETER IncludePrerelease
 If set, uses latest including prerelease versions; otherwise uses latest stable where possible.

.PARAMETER IgnorePackages
 Exact package IDs to skip (case-insensitive). Example: -IgnorePackages "Newtonsoft.Json","Microsoft.NET.Test.Sdk"

.PARAMETER IgnorePatterns
 One or more regex patterns applied to package IDs (case-insensitive). Example: -IgnorePatterns "^Microsoft\.", "Analyzers$"

.PARAMETER InternalPackages
 Exact package IDs considered internal (skip updating), case-insensitive.

.PARAMETER InternalPatterns
 Regex patterns to identify internal packages (skip updating), case-insensitive.

.PARAMETER KillRunning
 If set, the script will stop any running processes that appear to be executing from the RootPath folder before building.
#>
param(
  [string]$RootPath = (Get-Location).Path,
  [switch]$DryRun,
  [switch]$IncludePrerelease,
  [string[]]$IgnorePackages   = @(),
  [string[]]$IgnorePatterns   = @(),
  [string[]]$InternalPackages = @(),
  [string[]]$InternalPatterns = @(),
  [switch]$KillRunning
)

# ----------------------------- Utilities -----------------------------
function Write-Log {
    param(
        [string]$Prefix,
        [string]$Value,
        [string]$Suffix,
        [ValidateSet("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta","DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")]
        [string]$ValueColor = "White",
        [string]$Level = 'INFO'
    )

    $ts = (Get-Date).ToString('s')
    Write-Host "[${ts}] [$Level] " -NoNewline
    if ($Prefix) { Write-Host $Prefix -NoNewline }
    if ($Value) { Write-Host $Value -ForegroundColor $ValueColor -NoNewline }
    if ($Suffix) { Write-Host $Suffix -NoNewline }
    Write-Host ""  # Move to next line
}


function Fail-Fast {
  Write-Log $Message "ERROR"
  exit 1
}
function Ensure-Directory {
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )
  try {
    if ([string]::IsNullOrWhiteSpace($Path)) {
      throw "Path argument is null or whitespace."
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
      New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    return $resolved.Path
  }
  catch {
    Write-Log ("Failed to ensure directory '{0}': {1}" -f $Path, $_.Exception.Message) "ERROR"
    throw
  }
}

# ---------------- Process discovery/termination (NEW) -----------------
function Get-TemplateProcesses {
  param(
    [Parameter(Mandatory)][string]$TemplatePath
  )
  # Use CIM so we can filter on CommandLine reliably
  $tpl = $TemplatePath.ToLowerInvariant()
  try {
    $currentPid = $PID

    $procs = Get-CimInstance Win32_Process | Where-Object {
      # Either the command line references the template folder, or the process name is one we know
      ($_.CommandLine -and $_.CommandLine.ToLower().Contains($tpl)) -and $_.Id -ne $currentPid
    }
    return $procs
  } catch {
    Write-Log ("Failed to enumerate processes: {0}" -f $_.Exception.Message) "WARN"
    return @()
  }
}

function Stop-TemplateProcesses {
  param(
    [Parameter(Mandatory)][string]$TemplatePath,
    [int]$GraceMs = 1500
  )
  $procs = Get-TemplateProcesses -TemplatePath $TemplatePath
  if (-not $procs -or $procs.Count -eq 0) {
    Write-Log "No running template-related processes detected."
    return
  }
Write-Log -Prefix "Found " -Value $procs.Count -ValueColor Cyan -Suffix " template-related process(es) to stop..."
  foreach ($p in $procs) {
    try {
      Write-Log ("Stopping PID {0} '{1}' (soft)" -f $p.ProcessId, $p.Name)
      Stop-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
    } catch { }
  }
  Start-Sleep -Milliseconds $GraceMs
  # Force kill anything still running
  foreach ($p in Get-TemplateProcesses -TemplatePath $TemplatePath) {
    try {
      Write-Log ("Killing PID {0} '{1}' (hard)" -f $p.ProcessId, $p.Name) "WARN"
      Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    } catch { }
  }
}

# ----------------------- Console ASCII Table Helper -------------------
function Write-AsciiTable {
<#
      .SYNOPSIS
        Renders a simple ASCII table with borders, similar to benchmarking tools.
      .PARAMETER Rows
        Enumerable of objects that share the same property names as the headers.
      .PARAMETER Headers
        Ordered list of headers (strings) that map to property names in each row.
      .PARAMETER AlignRight
        Property names to right-align (e.g., versions).
      .PARAMETER OutputFile
        Optional file path to write the table to (in addition to console output).
    #>
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Rows,
        [Parameter(Mandatory)]
        [string[]]$Headers,
        [string[]]$AlignRight = @(),
        [string]$OutputFile
    )

    $rowsArray = @($Rows)
    $outputLines = @()

    if ($rowsArray.Count -eq 0) {
        $msg = "(no rows)"
        Write-Host $msg -ForegroundColor DarkGray
        if ($OutputFile) {
            $msg | Out-File -FilePath $OutputFile -Encoding UTF8
        }
        return
    }

    $columns = foreach ($h in $Headers) {
        [pscustomobject]@{
            Name  = $h
            Width = [math]::Max($h.Length, 1)
            Align = $(if ($AlignRight -contains $h) { 'Right' } else { 'Left' })
        }
    }

    foreach ($row in $rowsArray) {
        foreach ($col in $columns) {
            $val = $row | Select-Object -ExpandProperty $col.Name
            if ($val.Length -gt $col.Width) { $col.Width = $val.Length }
        }
    }

    function Border($columns) {
        $parts = @('+')
        foreach ($c in $columns) {
            $parts += ('{0}' -f ('-' * ($c.Width + 2)))
            $parts += '+'
        }
        return ($parts -join '')
    }

    function Cell($text, $width, $align) {
        $text = [string]$text
        $w = [int]$width
        if ($align -eq 'Right') {
            return ((' {0,'  + $w + '} ') -f $text)
        } else {
            return ((' {0,-' + $w + '} ') -f $text)
        }
    }

    $top    = Border $columns

    # Build header row with pipes between each column (same pattern as data rows)
    $headerParts = @('|')
    foreach ($c in $columns) {
        $headerParts += (Cell $c.Name $c.Width 'Left')
        $headerParts += '|'
    }
    $header = ($headerParts -join '')

    $sep    = Border $columns

    $outputLines += $top
    $outputLines += $header
    $outputLines += $sep

    $lastFile = ''
    foreach ($row in $rowsArray) {
        $file = $row.'File Name'
        if ($lastFile -ne '' -and $file -ne $lastFile) {
            $outputLines += $sep
        }
        $lastFile = $file

        $lineParts = @('|')
        foreach ($c in $columns) {
            $val = $row | Select-Object -ExpandProperty $c.Name
            $lineParts += (Cell $val $c.Width $c.Align)
            $lineParts += '|'
        }
        $outputLines += ($lineParts -join '')
    }

    $outputLines += $top

    # Write to console
    foreach ($line in $outputLines) {
        Write-Host $line
    }

    # Write to file if specified
    if ($OutputFile) {
        $outputLines | Out-File -FilePath $OutputFile -Encoding UTF8
    }
}

# ------------------------- NuGet Version Helper -----------------------
function Get-LatestNuGetVersion {
  param(
    [string]$packageId,
    [hashtable]$cache,
    [switch]$IncludePrerelease
  )
  if (-not ($cache -is [hashtable])) {
    throw "cache parameter must be a [hashtable]"
  }
  $key = $packageId.ToLower()
  if ($cache.ContainsKey($key)) {
    return $cache[$key]
  }
  $url = ('https://api.nuget.org/v3-flatcontainer/{0}/index.json' -f $key)
  try {
    Write-Log ('Querying NuGet for {0}' -f $packageId)
    $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 20 -ErrorAction Stop
    $versions = @($resp.versions | ForEach-Object { [string]$_ })
    if ($versions.Count -eq 0) {
      Write-Log ('No versions found for {0}' -f $packageId) -Level "WARN"
      $cache[$key] = $null
      return $null
    }
    if ($IncludePrerelease) {
      $chosen = $versions[-1]
    } else {
      $stable = @($versions | Where-Object { $_ -notmatch '-' })
      $chosen = if ($stable.Count -gt 0) { $stable[-1] } else { $versions[-1] }
    }
    $cache[$key] = $chosen
    return $chosen
  }
  catch {
    Write-Log ('Failed to query NuGet for {0}: {1}' -f $packageId, $_.Exception.Message) -Level "ERROR"
    throw
  }
}

# ---------------------- .csproj Package Updating ----------------------
function Update-Csproj-PackageReferences {
  param(
    [string]$csprojPath,
    [hashtable]$versionCache,
    [switch]$DryRunFlag,
    [switch]$IncludePrerelease,
    [string[]]$IgnorePackages   = @(),
    [string[]]$IgnorePatterns   = @(),
    [string[]]$InternalPackages = @(),
    [string[]]$InternalPatterns = @()
  )

  $result = [ordered]@{
    Path    = $csprojPath
    Updated = $false
    Changes = @()
    Errors  = @()
  }

  try { [xml]$xml = Get-Content -Path $csprojPath -Raw }
  catch {
    $result.Errors += ('Failed to read XML: {0}' -f $_.Exception.Message)
    return $result
  }

  # Consider ALL PackageReference nodes
  $prNodes = $xml.SelectNodes("//PackageReference")
  foreach ($pr in $prNodes) {
    $pkgId = $pr.Include
    if (-not $pkgId) { continue }

    # Only attempt updates if there is a Version *attribute* (skip <Version> child and CPM)
    if (-not $pr.HasAttribute("Version")) { continue }

    # ---- EARLY SKIPS: DO NOT call NuGet for any of the following ----

    $idLower = $pkgId.ToLowerInvariant()

    # Ignore: exact
    $ignoredByExact = $false
    if ($IgnorePackages.Count -gt 0) {
      $ignoredByExact = $IgnorePackages |
        ForEach-Object { $_.ToLowerInvariant() } |
        Where-Object { $_ -eq $idLower } |
        Select-Object -First 1
    }

    # Ignore: regex
    $ignoredByPattern = $false
    foreach ($pat in $IgnorePatterns) {
      if ([string]::IsNullOrWhiteSpace($pat)) { continue }
      if ($pkgId -imatch $pat) { $ignoredByPattern = $true; break }
    }

    if ($ignoredByExact -or $ignoredByPattern) { continue }

    # Internal: exact
    $internalByExact = $false
    if ($InternalPackages.Count -gt 0) {
      $internalByExact = $InternalPackages |
        ForEach-Object { $_.ToLowerInvariant() } |
        Where-Object { $_ -eq $idLower } |
        Select-Object -First 1
    }

    # Internal: regex
    $internalByPattern = $false
    foreach ($pat in $InternalPatterns) {
      if ([string]::IsNullOrWhiteSpace($pat)) { continue }
      if ($pkgId -imatch $pat) { $internalByPattern = $true; break }
    }

    if ($internalByExact -or $internalByPattern) { continue }

    # ---- ONLY NOW query NuGet ----
    $existingVersion = $pr.Version
    $latest = Get-LatestNuGetVersion -packageId $pkgId -cache $versionCache -IncludePrerelease:$IncludePrerelease
    if (-not $latest) { continue }
    if ($existingVersion -and ($existingVersion -ieq $latest)) { continue }

    if (-not $DryRunFlag) {
      $pr.SetAttribute("Version", $latest)
    }

    $result.Updated = $true
    $result.Changes += [ordered]@{
      Package    = $pkgId
      OldVersion = $existingVersion
      NewVersion = $latest
    }
  }

  if ($result.Updated -and -not $DryRunFlag) {
    try { $xml.Save($csprojPath) }
    catch { $result.Errors += ('Failed to save XML: {0}' -f $_.Exception.Message) }
  }

  return $result
}

# ----------------------------- dotnet Runner --------------------------
function Run-DotNet {
  param(
    [string]$Command, # e.g., 'build "My.sln" -c Release'
    [string]$Path,
    [switch]$DryRunFlag,
    [string]$StdOutFile,
    [string]$StdErrFile
  )
  $result = [ordered]@{
    Command  = $Command
    Path     = $Path
    Success  = $true
    ExitCode = 0
    StdOut   = ""
    StdErr   = ""
  }
  if ($DryRunFlag) {
    $result.StdOut = "DryRun"
    return $result
  }
  try {
    Push-Location $Path
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "dotnet"
    $psi.Arguments = $Command
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $stdOut = $proc.StandardOutput.ReadToEnd()
    $stdErr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $result.ExitCode = $proc.ExitCode
    $result.Success  = ($proc.ExitCode -eq 0)
    $result.StdOut   = $stdOut
    $result.StdErr   = $stdErr
    if ($StdOutFile) { $stdOut | Out-File -FilePath $StdOutFile -Encoding UTF8 }
    if ($StdErrFile) { $stdErr | Out-File -FilePath $StdErrFile -Encoding UTF8 }
  }
  catch {
    $result.Success = $false
    $result.StdErr  = $_.Exception | Out-String
  }
  finally {
    Pop-Location
  }
  return $result
}

# =============================== MAIN =================================
Write-Log ('Starting package update... IncludePrerelease={0}, DryRun={1}' -f $IncludePrerelease, $DryRun)

$templatePath = $RootPath
if (-not (Test-Path $templatePath)) {
  Fail-Fast ("Template folder not found at '{0}'." -f $templatePath)
}

if ($KillRunning) {
    Write-Log "Checking for running template processes to stop..."

    # Get current process ID
    $currentPid = $PID

    # Find processes related to the template path
    $processes = Get-Process | Where-Object {
        $_.Path -like "*$templatePath*" -and $_.Id -ne $currentPid
    }

    foreach ($proc in $processes) {
        Write-Log "Stopping process: $($proc.ProcessName) (PID: $($proc.Id))"
        Stop-Process -Id $proc.Id -Force
    }
}


# Artifacts layout
$artifactsRoot = Join-Path $RootPath ".artifacts"
$logsDir       = Join-Path $artifactsRoot "logs"
$null = Ensure-Directory $artifactsRoot
$null = Ensure-Directory $logsDir

Write-Log ('Scanning for csproj files in template folder...')
$csprojFiles = Get-ChildItem -Path $templatePath -Filter *.csproj -Recurse -File
if ($csprojFiles.Count -eq 0) {
  Fail-Fast ("No .csproj files found in '{0}'." -f $templatePath)
}
Write-Log -Prefix "Found " -Value $csprojFiles.Count -ValueColor Cyan -Suffix " csproj files."

$versionCache  = @{}
$updateResults = @()

foreach ($csproj in $csprojFiles) {
  $updateResults += Update-Csproj-PackageReferences `
    -csprojPath $csproj.FullName `
    -versionCache $versionCache `
    -DryRunFlag:$DryRun `
    -IncludePrerelease:$IncludePrerelease `
    -IgnorePackages $IgnorePackages `
    -IgnorePatterns $IgnorePatterns `
    -InternalPackages $InternalPackages `
    -InternalPatterns $InternalPatterns
}

# ---------------------- PACKAGE UPDATE RESULTS (TABLE) ---------------------

# Flatten changes into rows for the table
$packageChanges = New-Object System.Collections.Generic.List[object]

foreach ($result in $updateResults) {
    $projName = [System.IO.Path]::GetFileName($result.Path)

    foreach ($change in $result.Changes) {
        $packageChanges.Add([pscustomobject]@{
            'File Name'    = $projName
            'Package Name' = $change.Package
            'Old Version'  = $change.OldVersion
            'New Version'  = $change.NewVersion
        })
    }

    # Surface any XML errors per file (rare but useful)
    foreach ($err in $result.Errors) {
        Write-Host ('XML Error in {0}: {1}' -f $projName, $err) -ForegroundColor Red
    }
}


# ------------------------------ BUILD SECTION -----------------------------

# Skip build if there are no packages to update
if ($packageChanges.Count -eq 0) {
    Write-Log "No packages to update - skipping build section" -Level "INFO"
    $buildResults = @()
    $buildSummaryRows = New-Object System.Collections.Generic.List[object]
} else {
    Write-Log ('Scanning for sln files...')
    $slnFiles = Get-ChildItem -Path $RootPath -Filter *.sln -Recurse -File
    Write-Log -Prefix "Found " -Value $slnFiles.Count -ValueColor Cyan -Suffix " sln files."

    $buildResults = @()
    $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $buildSummaryRows = New-Object System.Collections.Generic.List[object]

foreach ($sln in $slnFiles) {
    $slnName = [System.IO.Path]::GetFileNameWithoutExtension($sln.FullName)
    $safeName = ($slnName -replace '[^\w\.-]','_')

    $slnLogBase   = Join-Path $logsDir    ("{0}__{1}" -f $safeName, $timestamp)
    $stdoutClean  = ("{0}.clean.stdout.txt" -f $slnLogBase)
    $stderrClean  = ("{0}.clean.stderr.txt" -f $slnLogBase)
    $stdoutBuild  = ("{0}.build.stdout.txt" -f $slnLogBase)
    $stderrBuild  = ("{0}.build.stderr.txt" -f $slnLogBase)

    # CLEAN
    Write-Log ('Cleaning {0}' -f $sln.FullName)
    $cleanCmd = ('clean "{0}" -clp:Summary -v:m' -f $sln.FullName)
    $cleanResult = Run-DotNet -Command $cleanCmd -Path $sln.DirectoryName -DryRunFlag:$DryRun -StdOutFile $stdoutClean -StdErrFile $stderrClean

    if($cleanResult.Success) {
        Write-Log ('Clean succeeded for {0}' -f $sln.Name)
    } else {
        Write-Log ('Clean FAILED for {0}' -f $sln.Name) "WARN"
    }

    # BUILD (no binlog per your preference)
    Write-Log ('Building {0}' -f $sln.FullName)
    $buildCmd = ('build "{0}" -clp:Summary -v:m' -f $sln.FullName)
    $buildResult = Run-DotNet -Command $buildCmd -Path $sln.DirectoryName -DryRunFlag:$DryRun -StdOutFile $stdoutBuild -StdErrFile $stderrBuild

    if($buildResult.Success) {
        Write-Log ('Build succeeded for {0}' -f $sln.Name)
    } else {
        Write-Log ('Build FAILED for {0}' -f $sln.Name) "WARN"
    }


    # Extract top error lines from both streams
    $errorLines = @(
        ($buildResult.StdErr -split "`r?`n"),
        ($buildResult.StdOut -split "`r?`n")
    ) | Where-Object { $_ -match "(:\s*error\s*[A-Z]?\d{3,}|^error\s)" } |
        Select-Object -Unique -First 20

    $buildResults += [ordered]@{
        Solution     = $sln.FullName
        CleanSuccess = $cleanResult.Success
        BuildSuccess = $buildResult.Success
        ExitCode     = $buildResult.ExitCode
        StdOutFile   = $stdoutBuild
        StdErrFile   = $stderrBuild
        ErrorLines   = $errorLines
    }

    
    # --- Parse Errors/Warnings from build output ---
    # Prefer the MSBuild summary counts; fallback to counting diagnostics if missing.
    $combinedOut = ($buildResult.StdOut + "`n" + $buildResult.StdErr)

    # Try summary-style extraction first (e.g., "X Warning(s)", "Y Error(s)")
    $errCount = 0
    $warnCount = 0

    $errSummaryMatch = [regex]::Match($combinedOut, '(?mi)^\s*(\d+)\s+Error\(s\)')
    $warnSummaryMatch = [regex]::Match($combinedOut, '(?mi)^\s*(\d+)\s+Warning\(s\)')

    if ($errSummaryMatch.Success) { $errCount = [int]$errSummaryMatch.Groups[1].Value }
    if ($warnSummaryMatch.Success) { $warnCount = [int]$warnSummaryMatch.Groups[1].Value }

    # Fallback: count diagnostics if summary lines are not found
    if (-not $errSummaryMatch.Success) {
        $errCount = ([regex]::Matches($combinedOut, '(?i)(^|\s)error\s[A-Z]?\d{3,}\b')).Count
    }
    if (-not $warnSummaryMatch.Success) {
        $warnCount = ([regex]::Matches($combinedOut, '(?i)(^|\s)warning\s[A-Z]?\d{3,}\b')).Count
    }

    
    $buildSummaryRows.Add([pscustomobject]@{
        'Solution Name' = [System.IO.Path]::GetFileName($sln.FullName)
        'Clean Result'  = if ($cleanResult.Success) { 'Success' } else { 'Failed' }
        'Build Result'  = if ($buildResult.Success) { 'Success' } else { 'Failed' }
        'Errors'        = $errCount
        'Warnings'      = $warnCount
    })


    # # Inline summary per solution
    # $status = if ($buildResult.Success) { "SUCCESS" } else { "FAILED" }
    # $color  = if ($buildResult.Success) { "Green" } else { "Red" }
    # Write-Host ('{0}: {1} (ExitCode={2})' -f $slnName, $status, $buildResult.ExitCode) -ForegroundColor $color

    if (-not $buildResult.Success) {
        if ($cleanResult.Success -eq $false) {
            Write-Host ("  Clean failed. See:") -ForegroundColor Yellow
            Write-Host ("    {0}" -f $stdoutClean)
            Write-Host ("    {0}" -f $stderrClean)
        }
        if ($errorLines.Count -gt 0) {
            Write-Host ("  Top error lines:") -ForegroundColor Yellow
            foreach ($line in $errorLines) {
                Write-Host ("    {0}" -f $line) -ForegroundColor Red
            }
        } else {
            Write-Host ("  No error lines detected; check full logs.") -ForegroundColor Yellow
        }
        Write-Host ("  Full logs:") -ForegroundColor Yellow
        Write-Host ("    StdOut: {0}" -f $stdoutBuild)
        Write-Host ("    StdErr: {0}" -f $stderrBuild)
    }
}

    if ($KillRunning) {
        Write-Log "Checking for running template processes to stop..."

        # Get current process ID
        $currentPid = $PID

        # Find processes related to the template path
        $processes = Get-Process | Where-Object {
            $_.Path -like "*$templatePath*" -and $_.Id -ne $currentPid
        }

        foreach ($proc in $processes) {
            Write-Log "Stopping process: $($proc.ProcessName) (PID: $($proc.Id))"
            Stop-Process -Id $proc.Id -Force
        }
    }
}

Write-Log "Package update script completed."
Write-Host ""
Write-Host "`n===== PACKAGE UPDATE RESULTS ====="
$packageUpdateFile = Join-Path $artifactsRoot "package-summary.txt"
if ($packageChanges.Count -gt 0) {

$sorted = $packageChanges |
    Sort-Object `
        @{ Expression = 'File Name';    Ascending = $true }, `
        @{ Expression = 'Package Name'; Ascending = $true }

    Write-AsciiTable -Rows $sorted `
                     -Headers @('File Name','Package Name','Old Version','New Version') `
                     -AlignRight @('Old Version','New Version') `
                     -OutputFile $packageUpdateFile
} else {
    $msg = "No packages to update"
    Write-Host $msg -ForegroundColor DarkGray
    $msg | Out-File -FilePath $packageUpdateFile -Encoding UTF8
}
Write-Host ""

Write-Host "`n===== BUILD SUMMARY ====="
$buildSummaryFile = Join-Path $artifactsRoot "build-summary.txt"
if ($buildSummaryRows.Count -gt 0) {
    $summarySorted = $buildSummaryRows | Sort-Object 'Solution Name'
    Write-AsciiTable -Rows $summarySorted `
        -Headers @('Solution Name','Clean Result','Build Result','Errors','Warnings') `
        -AlignRight @('Errors','Warnings') `
        -OutputFile $buildSummaryFile
} else {
    $msg = "(no solutions found)"
    Write-Host $msg -ForegroundColor DarkGray
    $msg | Out-File -FilePath $buildSummaryFile -Encoding UTF8
}

