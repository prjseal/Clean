# Show Pull Request Skipped Summary Script

## Overview

This script displays a formatted summary when PR creation is skipped because an existing PR already has identical package updates.

## Script Location

`.github/workflows/powershell/Show-PullRequestSkippedSummary.ps1`

## Purpose

Provides clear feedback to workflow runners when duplicate PR detection prevents creating a new PR, avoiding confusion and showing the link to the existing PR.

## When It's Used

- **Update Packages Workflow**: When changes are found but Test-ExistingPullRequest detects a duplicate PR

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ExistingPrNumber` | string | Yes | The number of the existing PR with identical updates |
| `Repository` | string | Yes | The GitHub repository in owner/repo format |

## How It Works

```mermaid
flowchart TD
    Start([Script Start]) --> DisplayBanner[Display Yellow Banner<br/>PR CREATION SKIPPED]
    DisplayBanner --> Explain[Explain:<br/>Existing PR has identical updates]
    Explain --> ShowPR[Show Existing PR Link<br/>https://github.com/{repo}/pull/{number}]
    ShowPR --> End([Exit: Success])

    style DisplayBanner fill:#ffffcc
    style Explain fill:#cceeff
    style ShowPR fill:#ccffcc
```

## What It Does

1. **Displays Skip Banner**
   - Yellow-highlighted header
   - Clear "PR CREATION SKIPPED" message

2. **Explains Reason**
   - States existing PR has identical updates
   - Clarifies no duplicate needed

3. **Shows Existing PR**
   - Provides clickable GitHub URL
   - Links to the existing PR with same changes

## Output

### Console Output

```
================================================
PR CREATION SKIPPED
================================================

An existing PR (#123) already has identical package updates.
No need to create a duplicate PR.

Existing PR: https://github.com/prjseal/Clean/pull/123
================================================
```

### Color Coding

- **Yellow**: Section borders and header
- **Cyan**: Informational messages
- **Green**: PR link

## Usage Examples

### Example 1: Basic Usage

```powershell
.\Show-PullRequestSkippedSummary.ps1 `
  -ExistingPrNumber "123" `
  -Repository "prjseal/Clean"
```

### Example 2: In Workflow

```yaml
- name: Summary - PR Skipped
  if: ${{ github.event.inputs.dryRun != 'true' && steps.check-changes.outputs.has_changes == 'true' && steps.check-existing-pr.outputs.skip == 'true' }}
  shell: pwsh
  run: |
    ./.github/workflows/powershell/Show-PullRequestSkippedSummary.ps1 `
      -ExistingPrNumber "${{ steps.check-existing-pr.outputs.existing_pr_number }}" `
      -Repository "${{ github.repository }}"
```

## Implementation Details

### URL Construction

**Format**:
```
https://github.com/{owner}/{repo}/pull/{number}
```

**Example**:
```
https://github.com/prjseal/Clean/pull/123
```

**PowerShell**:
```powershell
Write-Host "Existing PR: https://github.com/$Repository/pull/$ExistingPrNumber" -ForegroundColor Green
```

### Color Scheme

```powershell
Write-Host "Text" -ForegroundColor Yellow   # Borders and headers
Write-Host "Text" -ForegroundColor Cyan     # Informational messages
Write-Host "Text" -ForegroundColor Green    # Success/link
```

### Exit Behavior

- Script **always exits with code 0** (success)
- Workflow continues normally
- No PR created but workflow completes successfully

## Workflow Conditional Logic

**When this script runs**:
```yaml
if: ${{ github.event.inputs.dryRun != 'true' &&
        steps.check-changes.outputs.has_changes == 'true' &&
        steps.check-existing-pr.outputs.skip == 'true' }}
```

**Conditions**:
1. Not a dry run
2. Changes were detected
3. Existing PR found with same updates

**Mutually exclusive with**:
```yaml
- name: Create Pull Request
  if: ${{ steps.check-existing-pr.outputs.skip != 'true' }}
```

## Sample Workflow Run Output

**Full sequence**:
```
✅ Umbraco 13 section updated
✅ Package updates found
✅ Branch created: update-nuget-packages-20251126120000
✅ Changes committed and pushed
🔍 Checking for existing PRs...
Found existing PR #123 with identical package updates. Skipping PR creation.

================================================
PR CREATION SKIPPED
================================================

An existing PR (#123) already has identical package updates.
No need to create a duplicate PR.

Existing PR: https://github.com/prjseal/Clean/pull/123
================================================
```

## Troubleshooting

### Issue: Wrong PR Number

**Symptoms**:
Links to different PR than expected.

**Cause**:
- Test-ExistingPullRequest found wrong match
- Table comparison issue

**Solution**:
- Check Test-ExistingPullRequest output
- Verify table comparison logic
- Review existing PR body format

### Issue: Dead Link

**Symptoms**:
PR link returns 404.

**Possible Causes**:
1. PR was closed/merged after detection
2. Repository parameter incorrect
3. PR number wrong

**Solution**:
- Verify repository parameter format (owner/repo)
- Check PR still exists
- Review Test-ExistingPullRequest logs

### Issue: Script Runs When Shouldn't

**Symptoms**:
Skip message shown but updates are different.

**Cause**:
- False positive in Test-ExistingPullRequest
- Table comparison too lenient

**Solution**:
- Review Test-ExistingPullRequest logic
- Check whitespace normalization
- Verify table extraction regex

## User Actions After Skip

**What to do**:
1. **Review existing PR**: Click the link to view it
2. **Compare changes**: Verify updates are truly identical
3. **Merge or close**: Handle the existing PR appropriately
4. **Re-run if needed**: If changes differ, close existing and re-run

**If updates differ**:
- Close existing PR
- Re-run workflow to create new PR with current updates

## Related Documentation

- [workflow-update-nuget-packages.md](workflow-update-nuget-packages.md) - Parent workflow
- [script-test-existing-pull-request.md](script-test-existing-pull-request.md) - Duplicate detection
- [script-new-package-update-pull-request.md](script-new-package-update-pull-request.md) - PR creation (alternative path)

## Notes

- **Informational only** - no actions taken
- Provides **clear explanation** of why PR not created
- Includes **direct link** to existing PR
- **Always succeeds** (exit code 0)
- **Yellow color scheme** for warning/info
- Part of **workflow optimization** to avoid duplicate PRs
- Runs **mutually exclusively** with New-PackageUpdatePullRequest
- Helps **workflow runners** understand the outcome
