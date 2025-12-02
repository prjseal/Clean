#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Creates GitHub issues for OWASP ZAP security alerts.

.DESCRIPTION
    This script parses the ZAP JSON report and creates GitHub issues for each alert type
    if an issue doesn't already exist. Each issue includes the alert details and one URL example.

.PARAMETER ReportPath
    Path to the ZAP JSON report file.

.PARAMETER Repository
    GitHub repository in the format "owner/repo".

.PARAMETER Token
    GitHub API token with issues:write permission.

.EXAMPLE
    ./Create-ZapAlertIssues.ps1 -ReportPath "report.json" -Repository "owner/repo" -Token $env:GITHUB_TOKEN
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string]$BranchName,

    [Parameter(Mandatory = $false)]
    [string]$TemplateSource,

    [Parameter(Mandatory = $false)]
    [string]$TemplateVersion,

    [Parameter(Mandatory = $false)]
    [string]$UmbracoCmsVersion,

    [Parameter(Mandatory = $false)]
    [string]$PullRequestUrl
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

    try {
        $reportContent = Get-Content -Path $ReportPath -Raw -ErrorAction Stop
        $zapReport = $reportContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-ColorOutput "Error: Failed to parse JSON report: $($_.Exception.Message)" -Color Red
        return @()
    }

    $alerts = @()

    # Navigate through the ZAP report structure
    # Typically: site -> alerts[]
    foreach ($site in $zapReport.site) {
        if (-not $site.alerts) {
            continue
        }

        foreach ($alert in $site.alerts) {
            # Extract risk level from riskdesc (e.g., "High (Medium)" -> "High")
            $riskLevel = 'Unknown'
            if ($alert.riskdesc -match '^(High|Medium|Low|Informational)') {
                $riskLevel = $matches[1]
            }

            # Build the alert content
            $contentParts = @()

            $contentParts += "## $($alert.name)"
            $contentParts += ""
            $contentParts += "**Risk Level:** $riskLevel"
            $contentParts += ""

            if ($alert.confidence) {
                $contentParts += "**Confidence:** $($alert.confidence)"
                $contentParts += ""
            }

            if ($alert.desc) {
                $contentParts += "### Description"
                $contentParts += ""
                $contentParts += $alert.desc
                $contentParts += ""
            }

            if ($alert.solution) {
                $contentParts += "### Solution"
                $contentParts += ""
                $contentParts += $alert.solution
                $contentParts += ""
            }

            if ($alert.reference) {
                $contentParts += "### Reference"
                $contentParts += ""
                $contentParts += $alert.reference
                $contentParts += ""
            }

            if ($alert.cweid) {
                $contentParts += "**CWE ID:** $($alert.cweid)"
                $contentParts += ""
            }

            if ($alert.wascid) {
                $contentParts += "**WASC ID:** $($alert.wascid)"
                $contentParts += ""
            }

            # Get the first instance with all its properties
            $firstInstance = $null
            if ($alert.instances -and $alert.instances.Count -gt 0) {
                $firstInstance = $alert.instances[0]
            }

            $content = $contentParts -join "`n"

            $alerts += @{
                Title         = $alert.name
                RiskLevel     = $riskLevel
                Content       = $content.Trim()
                FirstInstance = $firstInstance
                PluginId      = $alert.pluginid
            }
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

    if ($alert.FirstInstance) {
        $issueBody += "`n`n### Example Instance`n`n"

        # Display all properties from the first instance
        if ($alert.FirstInstance.uri) {
            $issueBody += "**URL:** ``$($alert.FirstInstance.uri)```n`n"
        }
        elseif ($alert.FirstInstance.url) {
            $issueBody += "**URL:** ``$($alert.FirstInstance.url)```n`n"
        }

        if ($alert.FirstInstance.method) {
            $issueBody += "**Method:** $($alert.FirstInstance.method)`n`n"
        }

        if ($alert.FirstInstance.param) {
            $issueBody += "**Parameter:** ``$($alert.FirstInstance.param)```n`n"
        }

        if ($alert.FirstInstance.attack) {
            $issueBody += "**Attack:** ``$($alert.FirstInstance.attack)```n`n"
        }

        if ($alert.FirstInstance.evidence) {
            $issueBody += "**Evidence:**`n``````"
            $issueBody += "`n$($alert.FirstInstance.evidence)"
            $issueBody += "`n```````n`n"
        }

        if ($alert.FirstInstance.otherinfo) {
            $issueBody += "**Other Info:** $($alert.FirstInstance.otherinfo)`n`n"
        }
    }

    $issueBody += "`n`n---`n`n*This issue was automatically created from an OWASP ZAP security scan.*"
    $issueBody += "`n*Alert detected on: $(Get-Date -Format 'yyyy-MM-dd')*"

    if ($alert.PluginId) {
        $issueBody += "`n*Plugin ID: $($alert.PluginId)*"
    }

    # Add metadata section
    $issueBody += "`n`n### Scan Metadata"
    if ($BranchName) {
        $issueBody += "`n- **Branch:** ``$BranchName``"
    }
    if ($TemplateSource) {
        $templateSourceDisplay = switch ($TemplateSource) {
            'github-packages' { "GitHub Packages" }
            'code' { "Local Repository Code" }
            default { "NuGet.org" }
        }
        $issueBody += "`n- **Template Source:** $templateSourceDisplay"
    }
    if ($TemplateVersion) {
        $issueBody += "`n- **Clean Template Version:** $TemplateVersion"
    }
    if ($UmbracoCmsVersion) {
        $issueBody += "`n- **Umbraco CMS Version:** $UmbracoCmsVersion"
    }
    if ($PullRequestUrl) {
        $issueBody += "`n- **Related PR:** $PullRequestUrl"
    }

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

# Output the count of created issues to GitHub Actions output
if ($env:GITHUB_OUTPUT) {
    "issues_created=$created" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}
