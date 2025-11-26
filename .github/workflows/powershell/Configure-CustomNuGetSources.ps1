<#
.SYNOPSIS
    Configures custom NuGet sources from a GitHub PR description.

.DESCRIPTION
    This script reads a GitHub PR description and extracts custom NuGet source URLs
    in the format "nuget-source: <url>". It then adds these sources to the local
    NuGet configuration.

.PARAMETER PrNumber
    The GitHub pull request number

.EXAMPLE
    .\Configure-CustomNuGetSources.ps1 -PrNumber 123
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$PrNumber
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Checking PR Description for Custom NuGet Sources" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Get PR description using GitHub CLI
$prBody = gh pr view $PrNumber --json body --jq .body

if (-not $prBody) {
    Write-Host "No PR description found or PR description is empty." -ForegroundColor Yellow
    Write-Host "To add custom NuGet sources, include them in the PR description using this format:" -ForegroundColor Yellow
    Write-Host "  nuget-source: https://www.myget.org/F/umbraco-dev/api/v3/index.json" -ForegroundColor Cyan
    Write-Host "  nuget-source: https://pkgs.dev.azure.com/myorg/_packaging/myfeed/nuget/v3/index.json" -ForegroundColor Cyan
    exit 0
}

Write-Host "`nPR Description:" -ForegroundColor Yellow
Write-Host "---" -ForegroundColor DarkGray
Write-Host $prBody -ForegroundColor White
Write-Host "---`n" -ForegroundColor DarkGray

# Debug: Show PR body as bytes to check for hidden characters
Write-Host "`nPR Body Analysis:" -ForegroundColor Cyan
Write-Host "  Length: $($prBody.Length) characters" -ForegroundColor White
Write-Host "  Contains 'nuget-source': $($prBody -like '*nuget-source*')" -ForegroundColor White

# Split by lines and show each line
Write-Host "`nPR Body Lines:" -ForegroundColor Cyan
$lines = $prBody -split "`n"
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    Write-Host "  Line $($i + 1): '$line'" -ForegroundColor White
}

# Extract NuGet sources from PR description
# Format: nuget-source: https://example.com/nuget/v3/index.json
# Note: Can have leading whitespace or be on its own line
# Try multiple patterns to handle different formats
$patterns = @(
    'nuget-source:\s*(\S+)',                    # Pattern 1: simple pattern matching URL (no whitespace)
    '(?m)^\s*nuget-source:\s*(.+?)[\r\n]',      # Pattern 2: with optional leading whitespace
    '(?m)^\s*nuget-source:\s*(.+)$',            # Pattern 3: with optional leading whitespace, end of line
    '(?m)^nuget-source:\s*(.+)$'                # Pattern 4: original pattern (no leading spaces)
)

$matches = $null
foreach ($pattern in $patterns) {
    Write-Host "`nTrying regex pattern: $pattern" -ForegroundColor Cyan
    $matches = [regex]::Matches($prBody, $pattern)
    Write-Host "  Regex matches found: $($matches.Count)" -ForegroundColor White

    if ($matches.Count -gt 0) {
        Write-Host "  ✅ Pattern matched!" -ForegroundColor Green
        break
    }
}

if (-not $matches -or $matches.Count -eq 0) {
    Write-Host "`nNo custom NuGet sources found in PR description." -ForegroundColor Yellow
    Write-Host "To add custom NuGet sources, include them in the PR description using this format:" -ForegroundColor Yellow
    Write-Host "  nuget-source: https://www.myget.org/F/umbraco-dev/api/v3/index.json" -ForegroundColor Cyan
    Write-Host "`nMake sure the line starts at the beginning (no leading spaces) and uses the exact format." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($matches.Count) custom NuGet source(s):" -ForegroundColor Green

# Add each NuGet source
$sourceIndex = 1
foreach ($match in $matches) {
    $sourceUrl = $match.Groups[1].Value.Trim()
    $sourceName = "CustomSource$sourceIndex"

    Write-Host "`nAdding NuGet source:" -ForegroundColor Cyan
    Write-Host "  Name: $sourceName" -ForegroundColor White
    Write-Host "  URL:  $sourceUrl" -ForegroundColor White

    try {
        # Check if source already exists and remove it
        $existingSources = dotnet nuget list source
        if ($existingSources -match $sourceName) {
            Write-Host "  Removing existing source..." -ForegroundColor Yellow
            dotnet nuget remove source $sourceName
        }

        # Add the source
        dotnet nuget add source $sourceUrl --name $sourceName

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Successfully added $sourceName" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠️  Failed to add $sourceName (exit code: $LASTEXITCODE)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ⚠️  Error adding source: $($_.Exception.Message)" -ForegroundColor Red
    }

    $sourceIndex++
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "NuGet Source Configuration Complete" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# List all configured sources
Write-Host "`nAll configured NuGet sources:" -ForegroundColor Yellow
dotnet nuget list source
