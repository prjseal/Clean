# New Package Update Pull Request Script

## Overview

This script creates a pull request with detailed information about README and package updates, including custom NuGet sources if provided.

## Script Location

`.github/workflows/powershell/New-PackageUpdatePullRequest.ps1`

## Purpose

Automates PR creation with well-formatted descriptions containing update summaries, custom source information, and package change tables.

## When It's Used

- **Update Packages Workflow**: When changes are found, no duplicate PR exists, and dry run is disabled

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ReadmeUpdated` | string | Yes | - | Boolean string indicating if README was updated |
| `UpdatedVersions` | string | No | "" | Comma-separated list of updated Umbraco versions |
| `PackageSummary` | string | Yes | - | The package summary content (ASCII table) |
| `IncludePrerelease` | string | Yes | - | Boolean string indicating if prerelease versions included |
| `NuGetSources` | string | No | "" | Comma-separated custom NuGet source URLs |
| `BranchName` | string | Yes | - | The branch name to create the PR from |
| `WorkspacePath` | string | Yes | - | The GitHub workspace path |

## How It Works

```mermaid
flowchart TD
    Start([Script Start]) --> CreateFile[Create PR Body File<br/>.artifacts/pr-body.md]
    CreateFile --> WriteTitle[Write: This PR updates the following:]
    WriteTitle --> CheckReadme{README<br/>Updated?}

    CheckReadme -->|Yes| FormatVersions{Single or<br/>Multiple Versions?}
    CheckReadme -->|No| CheckPackages

    FormatVersions -->|Single| WriteReadmeSingle[Write: ✅ README.md<br/>Updated with latest Umbraco X version]
    FormatVersions -->|Multiple| WriteReadmeMultiple[Write: ✅ README.md<br/>Updated with latest Umbraco X and Y version]

    WriteReadmeSingle --> CheckPackages
    WriteReadmeMultiple --> CheckPackages

    CheckPackages{Packages<br/>Updated?}
    CheckPackages -->|Yes| WritePackages[Write: ✅ NuGet Packages<br/>Updated to latest versions]
    CheckPackages -->|No| WriteActor

    WritePackages --> WriteActor[Write: Triggered by: USER]
    WriteActor --> CustomSources{Custom NuGet<br/>Sources Provided?}

    CustomSources -->|Yes| WriteSourcesSection[Write: ## Custom NuGet Sources<br/>Description and nuget-source: lines]
    CustomSources -->|No| PackagesSection

    WriteSourcesSection --> PackagesSection{Packages<br/>Updated?}
    PackagesSection -->|Yes| WriteIncludePrerelease[Write: IncludePrerelease: value<br/>### Updated Packages:<br/>Package table in code block]
    PackagesSection -->|No| CreatePR

    WriteIncludePrerelease --> CreatePR[gh pr create<br/>--title "Update NuGet packages"<br/>--body-file<br/>--base main<br/>--head BRANCH]
    CreatePR --> End([Exit: Success])

    style WriteReadmeSingle fill:#ccffcc
    style WriteReadmeMultiple fill:#ccffcc
    style WritePackages fill:#ccffcc
    style WriteSourcesSection fill:#cceeff
    style WriteIncludePrerelease fill:#cceeff
    style CheckReadme fill:#e6e6fa
    style FormatVersions fill:#e6e6fa
    style CheckPackages fill:#e6e6fa
    style CustomSources fill:#e6e6fa
    style PackagesSection fill:#e6e6fa
```

## What It Does

1. **PR Body Generation**
   - Creates `.artifacts/pr-body.md` file
   - Builds content based on what was updated
   - Uses checkmarks for visual clarity

2. **Update Summary**
   - Lists README updates with version info
   - Lists package updates
   - Shows who triggered the workflow

3. **Custom Sources Section**
   - Includes if custom NuGet sources used
   - Adds `nuget-source:` lines for each source
   - PR build workflow will auto-configure these sources

4. **Package Details**
   - Shows IncludePrerelease setting
   - Includes ASCII table of package changes
   - Wrapped in code block for formatting

5. **PR Creation**
   - Uses `gh pr create` command
   - Sets title: "Update NuGet packages"
   - Reads body from file
   - Targets main branch

## Output

### PR Body Examples

**README + Packages Updated**:
```markdown
This PR updates the following:

- ✅ **README.md** - Updated with latest Umbraco 13 version
- ✅ **NuGet Packages** - Updated to latest versions

**Triggered by:** github-actions

**IncludePrerelease:** false

### Updated Packages:
```
+---------------+-----------------------------+--------------+--------------+
| File Name     | Package Name                | Old Version  | New Version  |
+---------------+-----------------------------+--------------+--------------+
| Clean.csproj  | Umbraco.Cms.Web.Website     | 13.5.1       | 13.5.2       |
+---------------+-----------------------------+--------------+--------------+
```
```

**With Custom NuGet Sources**:
```markdown
This PR updates the following:

- ✅ **NuGet Packages** - Updated to latest versions

**Triggered by:** developer123

## Custom NuGet Sources

This PR was created with custom NuGet sources. The PR build will automatically use these sources:

nuget-source: https://www.myget.org/F/umbraco-dev/api/v3/index.json

**IncludePrerelease:** true

### Updated Packages:
```
+---------------+-----------------------------+--------------+--------------+
| File Name     | Package Name                | Old Version  | New Version  |
+---------------+-----------------------------+--------------+--------------+
| Clean.csproj  | Umbraco.Cms.Web.Website     | 17.0.0-rc.1  | 17.0.0-rc.2  |
+---------------+-----------------------------+--------------+--------------+
```
```

**README Only (No Packages)**:
```markdown
This PR updates the following:

- ✅ **README.md** - Updated with latest Umbraco 13 and 17 version

**Triggered by:** scheduled-workflow
```

### Console Output

```
Creating pull request for prjseal:update-nuget-packages-20251126120000 into main in prjseal/Clean

https://github.com/prjseal/Clean/pull/124
```

## Usage Examples

### Example 1: README + Packages

```powershell
.\New-PackageUpdatePullRequest.ps1 `
  -ReadmeUpdated "true" `
  -UpdatedVersions "13" `
  -PackageSummary $summary `
  -IncludePrerelease "false" `
  -NuGetSources "" `
  -BranchName "update-nuget-packages-20251126120000" `
  -WorkspacePath "C:\Projects\Clean"
```

### Example 2: With Custom Sources

```powershell
.\New-PackageUpdatePullRequest.ps1 `
  -ReadmeUpdated "false" `
  -UpdatedVersions "" `
  -PackageSummary $summary `
  -IncludePrerelease "true" `
  -NuGetSources "https://www.myget.org/F/umbraco-dev/api/v3/index.json" `
  -BranchName "update-nuget-packages-20251126120000" `
  -WorkspacePath "C:\Projects\Clean"
```

### Example 3: In Workflow

```yaml
- name: Create Pull Request
  if: ${{ github.event.inputs.dryRun != 'true' && steps.check-changes.outputs.has_changes == 'true' && steps.check-existing-pr.outputs.skip != 'true' }}
  shell: pwsh
  env:
    GITHUB_TOKEN: ${{ secrets.PAT_TOKEN }}
  run: |
    echo $env:GITHUB_TOKEN | gh auth login --with-token
    ./.github/workflows/powershell/New-PackageUpdatePullRequest.ps1 `
      -ReadmeUpdated "${{ steps.update-readme.outputs.readme_updated }}" `
      -UpdatedVersions "${{ steps.update-readme.outputs.updated_versions }}" `
      -PackageSummary "${{ steps.read-summary.outputs.summary }}" `
      -IncludePrerelease "${{ github.event.inputs.includePrerelease }}" `
      -NuGetSources "${{ github.event.inputs.nugetSources }}" `
      -BranchName "${{ steps.commit-and-push.outputs.branchName }}" `
      -WorkspacePath "${{ github.workspace }}"
```

## Implementation Details

### File Writing

**UTF-8 encoding**:
```powershell
"Content" | Out-File -FilePath $prBodyFile -Encoding UTF8
"More content" | Out-File -FilePath $prBodyFile -Encoding UTF8 -Append
```

**Append mode**: All writes after first use `-Append`

### Version Formatting

**Single version**:
```powershell
if ($updatedVersions.Count -eq 1) {
    $versionText = "Umbraco $($updatedVersions[0])"
}
```
Output: `Umbraco 13`

**Multiple versions**:
```powershell
else {
    $versionText = "Umbraco $($updatedVersions -join ' and ')"
}
```
Output: `Umbraco 13 and 17`

### Custom Sources Format

**Each source on own line**:
```powershell
foreach ($sourceUrl in $sources) {
    "nuget-source: $sourceUrl" | Out-File -FilePath $prBodyFile -Encoding UTF8 -Append
}
```

**Why this format?**
- PR build workflow parses `nuget-source:` lines
- Auto-configures sources during PR build
- See [workflow-pr.md](workflow-pr.md) for details

### Package Summary Wrapping

**Code block syntax**:
```powershell
"``````" | Out-File -FilePath $prBodyFile -Encoding UTF8 -Append
"$PackageSummary" | Out-File -FilePath $prBodyFile -Encoding UTF8 -Append
"``````" | Out-File -FilePath $prBodyFile -Encoding UTF8 -Append
```

**Six backticks escaped**: PowerShell requires doubling backticks

### gh pr create Command

**Full command**:
```powershell
gh pr create `
    --title "Update NuGet packages" `
    --body-file $prBodyFile `
    --base main `
    --head $BranchName
```

**Parameters**:
- `--title`: PR title
- `--body-file`: Path to markdown file with PR description
- `--base`: Target branch (always main)
- `--head`: Source branch (timestamped update branch)

## Package Summary Detection

**Logic**:
```powershell
$summaryContent = $PackageSummary
$packagesUpdated = ($summaryContent -notmatch 'No package summary found') -and
                   ($summaryContent -notmatch 'No packages to update')
```

**Skips package section when**:
- Summary contains "No package summary found"
- Summary contains "No packages to update"

## Authentication

**Required**:
- `GITHUB_TOKEN` environment variable
- Token with `repo` and `workflow` scopes

**Set in workflow**:
```yaml
env:
  GITHUB_TOKEN: ${{ secrets.PAT_TOKEN }}
run: |
  echo $env:GITHUB_TOKEN | gh auth login --with-token
```

## Troubleshooting

### Issue: PR Not Created

**Symptoms**:
No PR link in output, command fails silently.

**Possible Causes**:
1. Authentication failed
2. Branch doesn't exist on remote
3. Branch already has open PR

**Solution**:
- Verify GitHub token authentication
- Check branch was pushed successfully
- Review gh command output for errors

### Issue: PR Body Formatting Wrong

**Symptoms**:
Code block not rendering, sources not on separate lines.

**Possible Causes**:
1. File encoding issue
2. Backticks not escaped properly
3. Line breaks missing

**Solution**:
- Ensure UTF8 encoding
- Check backtick escaping (six backticks)
- Verify newlines between sections

### Issue: Custom Sources Not Working

**Symptoms**:
PR created but PR build doesn't use custom sources.

**Cause**:
- Format doesn't match expected pattern

**Solution**:
Each source must be on own line:
```
nuget-source: https://example.com/index.json
```

### Issue: Package Table Not Displaying

**Symptoms**:
PR shows "No package summary found" when packages were updated.

**Possible Causes**:
1. PackageSummary parameter empty
2. Get-PackageSummary step failed
3. File read error

**Solution**:
- Check `steps.read-summary.outputs.summary`
- Verify package-summary.txt exists
- Review Get-PackageSummary step logs

## Related Documentation

- [workflow-update-nuget-packages.md](workflow-update-nuget-packages.md) - Parent workflow
- [workflow-pr.md](workflow-pr.md) - PR build with custom sources
- [script-get-package-summary.md](script-get-package-summary.md) - Summary retrieval
- [script-invoke-commit-and-push.md](script-invoke-commit-and-push.md) - Branch creation
- [script-test-existing-pull-request.md](script-test-existing-pull-request.md) - Duplicate check

## Notes

- **Creates PR** using GitHub CLI
- **Generates markdown file** for PR body
- **Includes custom source hints** for PR build workflow
- Uses **checkmarks** for visual clarity
- **Wraps package table** in code block for formatting
- Shows **who triggered** the workflow
- Includes **IncludePrerelease** setting for transparency
- **Targets main branch** always
- **UTF-8 encoding** for proper character support
- PR body saved in **`.artifacts/pr-body.md`** for review
