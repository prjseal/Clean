# Invoke Commit and Push Script

## Overview

This script creates a new branch, commits changes with an appropriate message based on what was updated, and pushes to the remote repository.

## Script Location

`.github/workflows/powershell/Invoke-CommitAndPush.ps1`

## Purpose

Automates the git commit and push process for package and README updates, using smart commit messages and branch naming conventions.

## When It's Used

- **Update Packages Workflow**: When changes are detected and dry run is disabled

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ReadmeUpdated` | string | Yes | Boolean string indicating if README was updated |
| `UpdatedVersions` | string | No | Comma-separated list of updated Umbraco versions |
| `WorkspacePath` | string | Yes | The GitHub workspace path |
| `Repository` | string | Yes | The GitHub repository in owner/repo format |
| `PatToken` | string | Yes | Personal Access Token for authentication |

## How It Works

```mermaid
flowchart TD
    Start([Script Start]) --> GenBranch[Generate Branch Name<br/>update-nuget-packages-{timestamp}]
    GenBranch --> ConfigGit[Configure Git<br/>Set user name and email]
    ConfigGit --> CreateBranch[Create and checkout branch]
    CreateBranch --> StageFiles[git add .<br/>Stage all changes]
    StageFiles --> CheckStaged{Changes<br/>Staged?}

    CheckStaged -->|No| Exit[Exit: No changes to commit]
    Exit --> End1([Exit: Success])

    CheckStaged -->|Yes| DetermineType{What was<br/>Updated?}

    DetermineType -->|README Only| ReadmeMessage[Commit Message:<br/>Update README with latest Umbraco X version<br/>Add [skip ci]]
    DetermineType -->|Packages Only| PackagesMessage[Commit Message:<br/>Update NuGet packages]
    DetermineType -->|Both| BothMessage[Commit Message:<br/>Update README and NuGet packages]

    ReadmeMessage --> Commit[git commit]
    PackagesMessage --> Commit
    BothMessage --> Commit

    Commit --> Push[git push with PAT token<br/>Set upstream branch]
    Push --> OutputBranch[Set GITHUB_OUTPUT:<br/>branchName]
    OutputBranch --> End2([Exit: Success])

    style ReadmeMessage fill:#ffffcc
    style PackagesMessage fill:#ffffcc
    style BothMessage fill:#ffffcc
    style Exit fill:#e6e6e6
    style CheckStaged fill:#e6e6fa
    style DetermineType fill:#e6e6fa
```

## What It Does

1. **Branch Creation**
   - Generates timestamped branch name
   - Format: `update-nuget-packages-yyyyMMddHHmmss`
   - Example: `update-nuget-packages-20251126143025`

2. **Git Configuration**
   - Sets user name: `github-actions`
   - Sets user email: `github-actions@github.com`

3. **Change Detection**
   - Checks if any files are staged
   - Exits early if no changes

4. **Commit Message Logic**
   - **README only**: Adds `[skip ci]` to avoid triggering workflows
   - **Packages only**: Simple "Update NuGet packages" message
   - **Both**: Combined message

5. **Push to Remote**
   - Uses PAT token for authentication
   - Sets upstream tracking branch

6. **Output**
   - Outputs branch name for PR creation step

## Output

### Console Output

**README Only Update**:
```
branchName=update-nuget-packages-20251126143025
[main abc1234] Update README with latest Umbraco 13 version [skip ci]
 3 files changed, 6 insertions(+), 6 deletions(-)
 * [new branch]      update-nuget-packages-20251126143025 -> update-nuget-packages-20251126143025
Only README updated - adding [skip ci] to commit message
```

**Packages Only Update**:
```
branchName=update-nuget-packages-20251126143025
[main abc1234] Update NuGet packages
 12 files changed, 24 insertions(+), 24 deletions(-)
 * [new branch]      update-nuget-packages-20251126143025 -> update-nuget-packages-20251126143025
```

**Both Updated**:
```
branchName=update-nuget-packages-20251126143025
[main abc1234] Update README and NuGet packages
 15 files changed, 30 insertions(+), 30 deletions(-)
 * [new branch]      update-nuget-packages-20251126143025 -> update-nuget-packages-20251126143025
```

**No Changes**:
```
No changes detected. Skipping commit and PR.
```

### GitHub Actions Output

```
branchName=update-nuget-packages-20251126143025
```

## Usage Examples

### Example 1: README Only

```powershell
.\Invoke-CommitAndPush.ps1 `
  -ReadmeUpdated "true" `
  -UpdatedVersions "13" `
  -WorkspacePath "C:\Projects\Clean" `
  -Repository "prjseal/Clean" `
  -PatToken $env:PAT_TOKEN
```

### Example 2: Packages Only

```powershell
.\Invoke-CommitAndPush.ps1 `
  -ReadmeUpdated "false" `
  -UpdatedVersions "" `
  -WorkspacePath "C:\Projects\Clean" `
  -Repository "prjseal/Clean" `
  -PatToken $env:PAT_TOKEN
```

### Example 3: Multiple Umbraco Versions

```powershell
.\Invoke-CommitAndPush.ps1 `
  -ReadmeUpdated "true" `
  -UpdatedVersions "13,17" `
  -WorkspacePath "C:\Projects\Clean" `
  -Repository "prjseal/Clean" `
  -PatToken $env:PAT_TOKEN
```

### Example 4: In Workflow

```yaml
- name: Commit and push changes
  id: commit-and-push
  if: ${{ github.event.inputs.dryRun != 'true' && steps.check-changes.outputs.has_changes == 'true' }}
  shell: pwsh
  env:
    PAT_TOKEN: ${{ secrets.PAT_TOKEN }}
  run: |
    ./.github/workflows/powershell/Invoke-CommitAndPush.ps1 `
      -ReadmeUpdated "${{ steps.update-readme.outputs.readme_updated }}" `
      -UpdatedVersions "${{ steps.update-readme.outputs.updated_versions }}" `
      -WorkspacePath "${{ github.workspace }}" `
      -Repository "${{ github.repository }}" `
      -PatToken $env:PAT_TOKEN
```

## Implementation Details

### Branch Naming

**Format**:
```powershell
$branchName = "update-nuget-packages-$(Get-Date -Format 'yyyyMMddHHmmss')"
```

**Example**:
- Date: November 26, 2025, 2:30:25 PM
- Branch: `update-nuget-packages-20251126143025`

### Commit Message Logic

**README only with single version**:
```
Update README with latest Umbraco 13 version [skip ci]
```

**README only with multiple versions**:
```
Update README with latest Umbraco 13 and 17 version [skip ci]
```

**Packages only**:
```
Update NuGet packages
```

**Both**:
```
Update README and NuGet packages
```

### [skip ci] Behavior

Added when:
- Only README updated
- No package changes

Why:
- README-only updates don't need CI builds
- Saves workflow minutes
- Prevents circular triggers

### Git Push Authentication

**URL format**:
```
https://x-access-token:{PAT_TOKEN}@github.com/{OWNER}/{REPO}.git
```

**Example**:
```powershell
git push https://x-access-token:ghp_abc123@github.com/prjseal/Clean.git update-nuget-packages-20251126143025
```

### Change Detection

**Command**:
```powershell
git diff --cached --quiet
```

**Returns**:
- Exit code 0: No changes staged
- Exit code 1: Changes staged

## Git Configuration

### User Identity

Set for this commit only:

```bash
git config user.name "github-actions"
git config user.email "github-actions@github.com"
```

Shows as "github-actions" in commit history.

## Troubleshooting

### Issue: Authentication Failed

**Symptoms**:
```
fatal: Authentication failed
```

**Possible Causes**:
1. PAT token invalid or expired
2. PAT token missing required scopes
3. Repository name incorrect

**Solution**:
- Verify PAT token has `repo` and `workflow` scopes
- Check token expiration in GitHub settings
- Ensure `Repository` parameter matches exactly

### Issue: No Changes to Commit

**Symptoms**:
```
No changes detected. Skipping commit and PR.
```

**Possible Causes**:
1. Files not modified by previous steps
2. All changes already committed
3. .gitignore excluding files

**Solution**:
- Check if UpdateThirdPartyPackages made changes
- Verify files are not in .gitignore
- Review git status manually

### Issue: [skip ci] Not Working

**Symptoms**:
PR build workflow still triggers for README-only changes.

**Possible Causes**:
1. Workflow doesn't respect [skip ci]
2. Different trigger configured

**Solution**:
- Check workflow trigger configuration
- Verify GitHub Actions honors [skip ci]
- May need to update workflow triggers

### Issue: Branch Already Exists

**Symptoms**:
```
fatal: A branch named 'update-nuget-packages-...' already exists
```

**Possible Causes**:
- Workflow ran multiple times in same second
- Previous run didn't clean up

**Solution**:
- Very rare due to timestamp precision
- Manually delete branch if needed
- Retry workflow

## Related Documentation

- [workflow-update-nuget-packages.md](workflow-update-nuget-packages.md) - Parent workflow
- [script-test-workflow-changes.md](script-test-workflow-changes.md) - Pre-commit check
- [script-new-package-update-pull-request.md](script-new-package-update-pull-request.md) - PR creation

## Notes

- Uses **timestamped branch names** to avoid conflicts
- Adds **[skip ci]** for README-only updates to save resources
- Outputs **branch name** for PR creation step
- **Authenticates with PAT token** for push permissions
- **Configures git identity** as github-actions bot
- **Early exits** if no changes detected
- Supports **multiple Umbraco versions** in commit message
