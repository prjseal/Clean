# New Version Update Pull Request Script

## Overview

This script creates a pull request to merge version updates back to the main branch after a release.

## Script Location

`.github/workflows/powershell/New-VersionUpdatePullRequest.ps1`

## Purpose

Automates PR creation for version bumps in .csproj and README files, ensuring main branch stays up-to-date with release versions.

## When It's Used

- **Release Workflow**: After packages are uploaded to release assets

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Version` | string | Yes | The version number being released |
| `IsPrerelease` | string | Yes | Boolean string indicating if this is a prerelease |
| `ReleaseUrl` | string | Yes | URL to the GitHub release |

## What It Does

1. **Configures Git** - Sets github-actions[bot] as committer
2. **Checks for Changes** - Exits if no changes to commit
3. **Creates Branch** - `release/update-versions-{version}`
4. **Stages Files** - All .csproj and README files
5. **Commits** - With `[skip ci]` flag
6. **Pushes Branch** - To remote
7. **Creates PR** - With detailed description

## Output

```
================================================
Creating PR with Version Updates
================================================
Fetching main branch...

Modified files:
 M Clean/Clean.csproj
 M README.md

Creating branch: release/update-versions-7.0.0
Staging .csproj files...
Staging README.md file...
Committing changes with message: chore: Update versions to 7.0.0 [skip ci]
Pushing branch to origin...
✅ Successfully pushed branch release/update-versions-7.0.0

Creating pull request...
✅ Successfully created pull request
================================================
```

## PR Description Format

```markdown
## Summary
This PR updates version references in the codebase following the release of version 7.0.0.

## Changes
- Updated version references in .csproj files
- Updated README.md with the latest version information
- Updated Umbraco marketplace README files with the latest version information

## Additional Info
- Release: [https://github.com/...](https://github.com/...)
- Prerelease: false

---
*This PR was automatically created by the release workflow.*
```

## Usage Examples

```powershell
.\New-VersionUpdatePullRequest.ps1 `
  -Version "7.0.0" `
  -IsPrerelease "false" `
  -ReleaseUrl "https://github.com/prjseal/Clean/releases/tag/v7.0.0"
```

## Related Documentation

- [workflow-versioning-releases.md](workflow-versioning-releases.md) - Parent workflow

## Notes

- Creates **automatic PR** for version updates
- Uses **[skip ci]** to avoid circular workflows
- **Bot identity** for commits
- **Exits gracefully** if no changes
