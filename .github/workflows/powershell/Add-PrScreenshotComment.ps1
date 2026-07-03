<#
.SYNOPSIS
    Posts the first Playwright screenshot as a comment on the pull request.

.DESCRIPTION
    GitHub's API cannot attach binary images directly to a comment, so this
    script hosts the screenshot by committing it to a dedicated orphan-style
    branch (default: "pr-screenshots") using the GitHub Contents API. The
    resulting raw URL is then embedded in a Markdown image inside a PR comment.

    The first screenshot (alphabetically, e.g. "01-home.png") is used. If no
    screenshot is found the script exits successfully without commenting so it
    never fails the build.

.PARAMETER ScreenshotsPath
    Directory containing the screenshots (*.png).

.PARAMETER PrNumber
    The pull request number to comment on.

.PARAMETER Repository
    The GitHub repository in owner/repo format.

.PARAMETER RunId
    The workflow run id, used to make the hosted screenshot path unique.

.PARAMETER Version
    The build version, shown in the comment for context.

.PARAMETER Branch
    The branch used to host screenshots (default: "pr-screenshots").

.EXAMPLE
    .\Add-PrScreenshotComment.ps1 -ScreenshotsPath "test-installation/screenshots" -PrNumber "123" -Repository "prjseal/Clean" -RunId "456" -Version "7.0.0-ci.456"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScreenshotsPath,

    [Parameter(Mandatory = $true)]
    [string]$PrNumber,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$Version = "",

    [Parameter(Mandatory = $false)]
    [string]$Branch = "pr-screenshots"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Posting first screenshot as PR comment" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($PrNumber) -or $PrNumber -eq "0") {
    Write-Host "No PR number provided - skipping screenshot comment." -ForegroundColor Yellow
    exit 0
}

# Find the first screenshot (alphabetical order, e.g. 01-home.png)
$screenshot = Get-ChildItem -Path "$ScreenshotsPath/*.png" -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object -First 1

if (-not $screenshot) {
    Write-Host "No screenshots found in '$ScreenshotsPath' - skipping screenshot comment." -ForegroundColor Yellow
    exit 0
}

Write-Host "First screenshot: $($screenshot.FullName)" -ForegroundColor Green

try {
    # Ensure the hosting branch exists; create it from the default branch if not.
    Write-Host "`nEnsuring hosting branch '$Branch' exists..." -ForegroundColor Yellow
    $refExists = $true
    gh api "repos/$Repository/git/ref/heads/$Branch" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $refExists = $false
    }

    if (-not $refExists) {
        Write-Host "Branch '$Branch' does not exist. Creating it from the default branch..." -ForegroundColor Yellow
        $defaultBranch = gh api "repos/$Repository" --jq ".default_branch"
        $baseSha = gh api "repos/$Repository/git/ref/heads/$defaultBranch" --jq ".object.sha"
        gh api --method POST "repos/$Repository/git/refs" `
            -f "ref=refs/heads/$Branch" `
            -f "sha=$baseSha" | Out-Null
        Write-Host "Created branch '$Branch' from '$defaultBranch' ($baseSha)." -ForegroundColor Green
    }

    # Build a unique path on the hosting branch for this run's screenshot.
    $hostedPath = "screenshots/pr-$PrNumber/run-$RunId/$($screenshot.Name)"
    Write-Host "`nUploading screenshot to '$Branch' at '$hostedPath'..." -ForegroundColor Yellow

    # Base64-encode the screenshot for the Contents API.
    $base64 = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($screenshot.FullName))

    # Use a temp JSON file to avoid command-line length limits with large images.
    $payload = @{
        message = "Add PR #$PrNumber screenshot (run $RunId)"
        content = $base64
        branch  = $Branch
    } | ConvertTo-Json -Compress

    $payloadFile = Join-Path ([System.IO.Path]::GetTempPath()) "screenshot-payload-$RunId.json"
    Set-Content -Path $payloadFile -Value $payload -Encoding UTF8

    $uploadOutput = gh api --method PUT "repos/$Repository/contents/$hostedPath" --input $payloadFile
    Remove-Item $payloadFile -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload screenshot to hosting branch." -ForegroundColor Red
        exit 0
    }

    $uploadResult = $uploadOutput | ConvertFrom-Json
    $imageUrl = $uploadResult.content.download_url
    Write-Host "Screenshot hosted at: $imageUrl" -ForegroundColor Green

    # Build and post the PR comment.
    $versionLine = if ([string]::IsNullOrWhiteSpace($Version)) { "" } else { " for version ``$Version``" }
    $commentBody = @"
## 📸 Home page screenshot$versionLine

Here is the home page screenshot captured during automated package installation testing:

![$($screenshot.Name)]($imageUrl)

_Generated by [workflow run](https://github.com/$Repository/actions/runs/$RunId)._
"@

    $commentFile = Join-Path ([System.IO.Path]::GetTempPath()) "screenshot-comment-$RunId.md"
    Set-Content -Path $commentFile -Value $commentBody -Encoding UTF8

    Write-Host "`nPosting comment to PR #$PrNumber..." -ForegroundColor Yellow
    gh pr comment $PrNumber --repo $Repository --body-file $commentFile
    Remove-Item $commentFile -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Screenshot comment posted to PR #$PrNumber" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Failed to post screenshot comment." -ForegroundColor Red
    }
}
catch {
    Write-Host "⚠️  Error posting screenshot comment: $($_.Exception.Message)" -ForegroundColor Red
    # Do not fail the build because of a commenting problem.
    exit 0
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Screenshot Comment Complete" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
