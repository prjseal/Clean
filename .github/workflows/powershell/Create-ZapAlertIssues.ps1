#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Creates GitHub issues for OWASP ZAP security alerts.

.DESCRIPTION
    This script parses the ZAP markdown report and creates GitHub issues for each alert type
    if an issue doesn't already exist. Each issue includes the alert details and one URL example.

.PARAMETER ReportPath
    Path to the ZAP markdown report file.

.PARAMETER Repository
    GitHub repository in the format "owner/repo".

.PARAMETER Token
    GitHub API token with issues:write permission.

.EXAMPLE
    ./Create-ZapAlertIssues.ps1 -ReportPath "report_md.md" -Repository "owner/repo" -Token $env:GITHUB_TOKEN
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Get-ExistingIssues {
    param(
        [string]$Repository,
        [string]$Token
    )

    $headers = @{
        'Authorization' = "token $Token"
        'Accept'        = 'application/vnd.github.v3+json'
        'User-Agent'    = 'PowerShell-ZAP-Issue-Creator'
    }

    $allIssues = @()
    $page = 1
    $perPage = 100

    try {
        do {
            $uri = "https://api.github.com/repos/$Repository/issues?state=all&per_page=$perPage&page=$page&labels=security,zap-scan"
            Write-ColorOutput "Fetching existing issues (page $page)..." -Color Cyan

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            $allIssues += $response
            $page++

            Start-Sleep -Milliseconds 100  # Rate limiting courtesy
        } while ($response.Count -eq $perPage)

        Write-ColorOutput "Found $($allIssues.Count) existing ZAP security issues" -Color Green
        return $allIssues
    }
    catch {
        Write-ColorOutput "Warning: Could not fetch existing issues: $($_.Exception.Message)" -Color Yellow
        return @()
    }
}

function New-GitHubIssue {
    param(
        [string]$Repository,
        [string]$Token,
        [string]$Title,
        [string]$Body,
        [string[]]$Labels
    )

    $headers = @{
        'Authorization' = "token $Token"
        'Accept'        = 'application/vnd.github.v3+json'
        'User-Agent'    = 'PowerShell-ZAP-Issue-Creator'
    }

    $issueData = @{
        title  = $Title
        body   = $Body
        labels = $Labels
    } | ConvertTo-Json -Depth 10

    try {
        $uri = "https://api.github.com/repos/$Repository/issues"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $issueData -ContentType 'application/json'
        Write-ColorOutput "✓ Created issue #$($response.number): $Title" -Color Green
        return $response
    }
    catch {
        Write-ColorOutput "✗ Failed to create issue '$Title': $($_.Exception.Message)" -Color Red
        return $null
    }
}

function Parse-ZapReport {
    param(
        [string]$ReportPath
    )

    if (-not (Test-Path $ReportPath)) {
        Write-ColorOutput "Error: Report file not found at $ReportPath" -Color Red
        return @()
    }

    $content = Get-Content -Path $ReportPath -Raw
    $alerts = @()

    # Split by alert sections (they typically start with "##" or "###")
    # ZAP reports have sections like: ## <Risk Level>: <Alert Name>
    $lines = $content -split "`n"

    $currentAlert = $null
    $currentContent = @()
    $inAlert = $false
    $capturedFirstUrl = $false

    foreach ($line in $lines) {
        # Match alert headers like "## High (Medium): Content Security Policy (CSP) Header Not Set"
        # Or "### Content Security Policy (CSP) Header Not Set"
        if ($line -match '^##\s+(High|Medium|Low|Informational)\s*(\([^)]+\))?\s*:\s*(.+)$') {
            # Save previous alert if exists
            if ($currentAlert) {
                $alerts += @{
                    Title       = $currentAlert.Title
                    RiskLevel   = $currentAlert.RiskLevel
                    Content     = ($currentContent -join "`n").Trim()
                    FirstUrl    = $currentAlert.FirstUrl
                }
            }

            # Start new alert
            $riskLevel = $matches[1]
            $alertName = $matches[3].Trim()

            $currentAlert = @{
                Title     = $alertName
                RiskLevel = $riskLevel
                FirstUrl  = $null
            }
            $currentContent = @("## $alertName", "", "**Risk Level:** $riskLevel", "")
            $inAlert = $true
            $capturedFirstUrl = $false
        }
        elseif ($line -match '^###\s+(.+)$' -and -not ($line -match 'URL|Instance')) {
            # This might be an alert without risk level prefix
            if ($currentAlert) {
                $alerts += @{
                    Title       = $currentAlert.Title
                    RiskLevel   = $currentAlert.RiskLevel
                    Content     = ($currentContent -join "`n").Trim()
                    FirstUrl    = $currentAlert.FirstUrl
                }
            }

            $alertName = $matches[1].Trim()
            $currentAlert = @{
                Title     = $alertName
                RiskLevel = 'Unknown'
                FirstUrl  = $null
            }
            $currentContent = @("## $alertName", "")
            $inAlert = $true
            $capturedFirstUrl = $false
        }
        elseif ($inAlert) {
            # Capture URL instances (only the first one)
            if (-not $capturedFirstUrl -and $line -match '^\s*\*\s*(https?://\S+)' -or $line -match '^\s*-\s*(https?://\S+)') {
                $currentAlert.FirstUrl = $matches[1]
                $capturedFirstUrl = $true
                # Add just this one URL to content
                $currentContent += $line
            }
            # Skip other URL lines if we already have one
            elseif ($capturedFirstUrl -and ($line -match '^\s*\*\s*https?://' -or $line -match '^\s*-\s*https?://')) {
                # Skip additional URLs
                continue
            }
            # Skip "Instances" headers and count lines after we have our URL
            elseif ($capturedFirstUrl -and ($line -match '^\s*\*\s*Instances:' -or $line -match 'Instances:')) {
                # Skip
                continue
            }
            else {
                # Add other content lines (description, solution, etc.)
                $currentContent += $line
            }
        }
    }

    # Save last alert
    if ($currentAlert) {
        $alerts += @{
            Title       = $currentAlert.Title
            RiskLevel   = $currentAlert.RiskLevel
            Content     = ($currentContent -join "`n").Trim()
            FirstUrl    = $currentAlert.FirstUrl
        }
    }

    Write-ColorOutput "Parsed $($alerts.Count) alerts from report" -Color Cyan
    return $alerts
}

# Main script execution
Write-ColorOutput "`n=== ZAP Alert Issue Creator ===" -Color Cyan
Write-ColorOutput "Report: $ReportPath" -Color White
Write-ColorOutput "Repository: $Repository" -Color White
Write-ColorOutput ""

# Parse the ZAP report
$alerts = Parse-ZapReport -ReportPath $ReportPath

if ($alerts.Count -eq 0) {
    Write-ColorOutput "No alerts found in report. Exiting." -Color Yellow
    exit 0
}

# Get existing issues
$existingIssues = Get-ExistingIssues -Repository $Repository -Token $Token
$existingTitles = $existingIssues | ForEach-Object { $_.title }

Write-ColorOutput "`nProcessing alerts..." -Color Cyan

$created = 0
$skipped = 0

foreach ($alert in $alerts) {
    $issueTitle = "[ZAP Security] $($alert.Title)"

    # Check if issue already exists
    if ($existingTitles -contains $issueTitle) {
        Write-ColorOutput "⊘ Skipped (exists): $issueTitle" -Color Yellow
        $skipped++
        continue
    }

    # Build issue body
    $issueBody = $alert.Content

    if ($alert.FirstUrl) {
        $issueBody += "`n`n### Example URL`n`n$($alert.FirstUrl)"
    }

    $issueBody += "`n`n---`n`n*This issue was automatically created from an OWASP ZAP security scan.*"
    $issueBody += "`n*Alert detected on: $(Get-Date -Format 'yyyy-MM-dd')*"

    # Create the issue
    $labels = @('security', 'zap-scan', $alert.RiskLevel.ToLower())
    $result = New-GitHubIssue -Repository $Repository -Token $Token -Title $issueTitle -Body $issueBody -Labels $labels

    if ($result) {
        $created++
    }

    # Rate limiting - be nice to GitHub API
    Start-Sleep -Milliseconds 500
}

Write-ColorOutput "`n=== Summary ===" -Color Cyan
Write-ColorOutput "Total alerts: $($alerts.Count)" -Color White
Write-ColorOutput "Issues created: $created" -Color Green
Write-ColorOutput "Issues skipped (already exist): $skipped" -Color Yellow
Write-ColorOutput ""
