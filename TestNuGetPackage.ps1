param (
    [string]$UmbracoVersion,
    [string]$Version
)

# Validate required parameters
if (-not $UmbracoVersion) { Write-Host "Error: Umbraco Version parameter is required." -ForegroundColor Red; exit 1 }
if (-not $Version) { Write-Host "Error: Version parameter is required." -ForegroundColor Red; exit 1 }

# Set working directories
$CurrentDir = Get-Location
$artifactsRoot = Join-Path $CurrentDir ".artifacts"

Write-Host "Checking for running processes to stop..."

# Get current process ID
$currentPid = $PID

# Find processes related to the template path
$processes = Get-Process | Where-Object {
    $_.Path -like "*$CurrentDir*" -and $_.Id -ne $currentPid
}

foreach ($proc in $processes) {
    Write-Host "Stopping process: $($proc.ProcessName) (PID: $($proc.Id))"
    Stop-Process -Id $proc.Id -Force
}


if (-not (Test-Path -Path $artifactsRoot)) {
    New-Item -ItemType Directory -Path $artifactsRoot | Out-Null
}

# Prepare payload for API
$payload = @{
    TemplateName          = "Umbraco.Templates"
    TemplateVersion       = $UmbracoVersion
    Packages              = "clean|$Version"
    SolutionName          = "MySolution"
    ProjectName           = "MyProject"
    UserFriendlyName      = "Administrator"
    UserEmail             = "admin@example.com"
    UserPassword          = "1234567890"
    IncludeStarterKit     = $false
    UseUnattendedInstall  = $true
    DatabaseType          = "SQLite"
} | ConvertTo-Json -Depth 3

Write-Host "`nCalling ScriptGenerator API with payload:"
Write-Host $payload

$response = Invoke-RestMethod -Uri "https://psw.codeshare.co.uk/api/ScriptGeneratorApi/generatescript" -Method Post -Body $payload -ContentType "application/json"

Write-Host "`nExecuting Script Commands from API:"

# Split commands and filter out comments/empty lines
$commands = $response -split "`r?`n" | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_) -and -not $_.TrimStart().StartsWith("#")
}

foreach ($cmd in $commands) {
    if (-not $cmd.TrimStart().StartsWith("dotnet")) {
        Write-Host "Error: Unexpected command received from API: $cmd" -ForegroundColor Red
        exit 1
    }

    Write-Host "Running: $cmd"

    if ($cmd.TrimStart().StartsWith("dotnet run")) {
        # Run dotnet in same console, redirect output
        $arguments = $cmd.Replace("dotnet ", "")
        $process = Start-Process -FilePath "dotnet" `
            -ArgumentList $arguments `
            -RedirectStandardOutput "$artifactsRoot\site.log" `
            -RedirectStandardError "$artifactsRoot\site.err" `
            -NoNewWindow `
            -PassThru

        # Funny messages
        $messages = @(
            "Still brewing the coffee for your site...",
            "Polishing the pixels...",
            "Convincing the servers to wake up...",
            "Teaching Umbraco some new tricks...",
            "Loading... because good things take time!",
            "Almost there, just feeding the hamsters...",
            "Your site is stretching its legs...",
            "Preparing the magic spells...",
            "Warming up the engines...",
            "Hang tight, greatness is coming!",
            "Dusting off the code cobwebs...",
            "Summoning the digital wizards...",
            "Aligning the bits and bytes...",
            "Feeding the unicorns that power the cloud...",
            "Installing extra awesomeness...",
            "Calibrating the flux capacitor...",
            "Negotiating with the database...",
            "Teaching the CSS to behave...",
            "Convincing JavaScript to cooperate...",
            "Adding sprinkles to your site...",
            "Running with scissors (carefully)...",
            "Counting all the pixels twice...",
            "Making sure the hamsters have snacks...",
            "Checking if the internet is plugged in...",
            "Applying the magic sauce...",
            "Turning the site up to 11...",
            "Doing a little victory dance...",
            "Double-checking the spellbook...",
            "Whispering sweet nothings to the server...",
            "Almost ready to blow your mind!"
        )

        # Timeout and monitoring
        $startTime = Get-Date
        $timeoutSeconds = 180 # 3 minutes
        $siteStarted = $false

        while (-not $siteStarted) {
            # Check timeout
            if ((Get-Date) - $startTime -gt (New-TimeSpan -Seconds $timeoutSeconds)) {
                Write-Host "Timeout reached! The site took too long to start. Maybe the hamsters went on strike." -ForegroundColor Red
                exit 1
            }

            if (Test-Path "$artifactsRoot\site.log") {
                # Show last 10 lines of the log
                $logTail = Get-Content "$artifactsRoot\site.log" -Tail 10

                # Check if site is listening
                if ($logTail | Select-String "Now listening on:") {
                    $siteStarted = $true
                    break
                }
            }

            # Show random funny message
            Write-Host (Get-Random -InputObject $messages)
            Start-Sleep -Seconds 2
        }

        # Extract URL
        $logContent = Get-Content "$artifactsRoot\site.log"
        $urlLine = $logContent | Select-String "Now listening on: https"
        if ($urlLine) {
            $siteUrl = ($urlLine -split "Now listening on:\s*")[1].Trim()
            Write-Host "Success! Your site is live at: $siteUrl"
            "siteUrl=$siteUrl" | Out-File -FilePath "$artifactsRoot\siteUrl.txt" -Append
        } else {
            Write-Host "Could not find site URL in output" -ForegroundColor Yellow
        }
    } else {
        Invoke-Expression $cmd
    }
}
