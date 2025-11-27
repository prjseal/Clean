# Publish to GitHub Packages Script

## Overview

This script publishes NuGet packages to GitHub Packages for CI/development use.

## Script Location

`.github/workflows/powershell/Publish-ToGitHubPackages.ps1`

## Purpose

Publishes CI build packages to GitHub Packages, making them available for testing and internal use without publishing to public NuGet.org.

## When It's Used

- **PR Workflow**: After packages are created and uploaded as artifacts

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `GitHubToken` | string | Yes | - | The GitHub token for authentication |
| `RepositoryOwner` | string | Yes | - | The GitHub repository owner |
| `PackagesPath` | string | No | `.artifacts/nuget` | Path to directory containing .nupkg files |

## What It Does

1. **Package Discovery** - Finds all .nupkg files in artifacts
2. **Source Configuration** - Adds GitHub Packages as NuGet source
3. **Package Publishing** - Pushes each package with `--skip-duplicate`
4. **Failure Tracking** - Tracks which packages fail
5. **Error Reporting** - Fails workflow if any package fails

## Output

```
================================================
Publishing NuGet Packages to GitHub Packages
================================================
Found 4 package(s) to publish:
  - Clean.Core.7.0.1-ci.123.nupkg
  - Clean.Headless.7.0.1-ci.123.nupkg
  - Clean.7.0.1-ci.123.nupkg
  - Umbraco.Community.Templates.Clean.7.0.1-ci.123.nupkg

Adding GitHub Packages source: https://nuget.pkg.github.com/prjseal/index.json

Publishing Clean.Core.7.0.1-ci.123.nupkg...
✅ Successfully published Clean.Core.7.0.1-ci.123.nupkg

================================================
Package Publishing Complete
================================================
✅ All packages published successfully!
```

## GitHub Packages URL Format

```
https://nuget.pkg.github.com/{owner}/index.json
```

Example: `https://nuget.pkg.github.com/prjseal/index.json`

## Authentication

Uses GitHub token with `packages:write` permission:

```yaml
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Troubleshooting

### Issue: Authentication Failed

**Solution**: Ensure GITHUB_TOKEN has `packages:write` permission

### Issue: Package Already Exists

**Solution**: Use --skip-duplicate (already included)

## Related Documentation

- [workflow-pr.md](workflow-pr.md) - Parent workflow
- [general-consuming-packages.md](general-consuming-packages.md) - How to consume these packages

## Notes

- **Publishes to GitHub Packages** (not NuGet.org)
- **CI builds only** - keeps NuGet.org clean
- **Fails workflow** if any package fails to publish
- **Uses --skip-duplicate** to handle existing versions
- **Requires authentication** with GitHub token
