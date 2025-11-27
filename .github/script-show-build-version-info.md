# Show Build Version Info Script

## Overview

This simple script displays build version information in a formatted way for workflow logs.

## Script Location

`.github/workflows/powershell/Show-BuildVersionInfo.ps1`

## Purpose

Outputs formatted build version information including base version, build number, and full CI version string for easy visibility in workflow logs.

## When It's Used

- **PR Workflow**: Immediately after version generation to display version info

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `BaseVersion` | string | Yes | The base version number |
| `BuildNumber` | string | Yes | The build/run number |
| `FullVersion` | string | Yes | The complete version string with build number |

## Output

```
================================================
Build Version Information
================================================
Base Version: 7.0.1
Build Number: 123
Full Version: 7.0.1-ci.123
================================================
```

## Usage Examples

```yaml
- name: Display version info
  shell: pwsh
  run: |
    ./.github/workflows/powershell/Show-BuildVersionInfo.ps1 `
      -BaseVersion "${{ steps.version.outputs.base_version }}" `
      -BuildNumber "${{ github.run_number }}" `
      -FullVersion "${{ steps.version.outputs.version }}"
```

## Related Documentation

- [workflow-pr.md](workflow-pr.md) - Parent workflow
- [script-get-build-version.md](script-get-build-version.md) - Version generation

## Notes

- **Informational only** - no actions taken
- **Color-coded output** for readability
- **Always succeeds** (no error conditions)
