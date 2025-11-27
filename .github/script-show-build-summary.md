# Show Build Summary Script

## Overview

This script displays a comprehensive summary of the PR build including version, branch info, and generated packages.

## Script Location

`.github/workflows/powershell/Show-BuildSummary.ps1`

## Purpose

Provides a final formatted summary of the build process for workflow logs, always running even if previous steps fail.

## When It's Used

- **PR Workflow**: Final step (runs with `if: always()`)

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Version` | string | Yes | - | The build version |
| `PrNumber` | string | Yes | - | The pull request number |
| `Branch` | string | Yes | - | The branch name |
| `Actor` | string | Yes | - | GitHub actor who triggered the build |
| `Repository` | string | Yes | - | GitHub repository in owner/repo format |
| `PackagesPath` | string | No | `.artifacts/nuget` | Path to packages directory |

## Output

```
================================================
Build Summary
================================================
Version: 7.0.1-ci.123
PR Number: 456
Branch: feature/test
Triggered by: prjseal
================================================

Generated Packages:
  - Clean.Core.7.0.1-ci.123.nupkg
  - Clean.Headless.7.0.1-ci.123.nupkg
  - Clean.7.0.1-ci.123.nupkg
  - Umbraco.Community.Templates.Clean.7.0.1-ci.123.nupkg

Published to: https://github.com/prjseal/Clean/packages
```

## Usage Example

```yaml
- name: Build Summary
  if: always()
  shell: pwsh
  run: |
    ./.github/workflows/powershell/Show-BuildSummary.ps1 `
      -Version "${{ steps.version.outputs.version }}" `
      -PrNumber "${{ github.event.pull_request.number }}" `
      -Branch "${{ github.head_ref }}" `
      -Actor "${{ github.actor }}" `
      -Repository "${{ github.repository }}"
```

## Related Documentation

- [workflow-pr.md](workflow-pr.md) - Parent workflow

## Notes

- **Always runs** via `if: always()`
- **Informational only** - no actions taken
- Provides **quick link** to GitHub Packages
- **Green color** for success indication
- **Lists all generated packages**
