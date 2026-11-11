# Publish to NuGet Script

## Overview

This script publishes all NuGet packages from the artifacts directory to NuGet.org with comprehensive error handling and reporting.

## Script Location

`.github/workflows/powershell/Publish-ToNuGet.ps1`

## Purpose

Publishes Clean packages to NuGet.org for public consumption, with validation and failure tracking.

## When It's Used

- **Release Workflow**: After packages are created and uploaded as artifacts

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ApiKey` | string | Yes | - | The short-lived nuget.org API key from the `NuGet/login` trusted publishing step (valid for 1 hour). Empty values are accepted so the script can print setup guidance |
| `PackagesPath` | string | No | `.artifacts/nuget` | Path to directory containing .nupkg files |

## What It Does

1. **API Key Validation** - Verifies the `NuGet/login` step produced a key, and prints trusted publishing setup checks if it did not
2. **Package Discovery** - Finds all .nupkg files
3. **Package Publishing** - Pushes each to NuGet.org with `--skip-duplicate`
4. **Failure Tracking** - Tracks which packages fail
5. **Error Reporting** - Fails workflow if any package fails

## Output

```
================================================
Publishing NuGet Packages to NuGet.org
================================================
Found 4 package(s) to publish:
  - Clean.Core.7.0.0.nupkg
  - Clean.Headless.7.0.0.nupkg
  - Clean.7.0.0.nupkg
  - Umbraco.Community.Templates.Clean.7.0.0.nupkg

Publishing Clean.Core.7.0.0.nupkg to NuGet.org...
✅ Successfully published Clean.Core.7.0.0.nupkg

================================================
Package Publishing Complete
================================================
✅ All packages published successfully!
```

## Usage Examples

The release workflow gets the key from nuget.org [trusted publishing](https://learn.microsoft.com/en-gb/nuget/nuget-org/trusted-publishing) and passes it in through an environment variable:

```yaml
- name: NuGet login (OIDC trusted publishing)
  id: nuget-login
  uses: NuGet/login@v1
  with:
    user: ${{ secrets.NUGET_USER }}

- name: Publish to NuGet.org
  shell: pwsh
  env:
    NUGET_API_KEY: ${{ steps.nuget-login.outputs.NUGET_API_KEY }}
  run: |
    ./.github/workflows/powershell/Publish-ToNuGet.ps1 -ApiKey $env:NUGET_API_KEY
```

The job needs `permissions: id-token: write`.

## Troubleshooting

### Issue: No NuGet API Key Provided

**Cause**: The `NuGet/login` step did not produce a key.

**Solution**: Check that:
- A trusted publishing policy exists on nuget.org for repository owner `prjseal`, repository
  `Clean`, workflow file `release-nuget.yml` (file name only), and that it is active (a new policy
  is temporary for 7 days until the first successful publish)
- The `NUGET_USER` repository secret is the nuget.org profile name, not the email address
- The job has `permissions: id-token: write`

### Issue: Package Already Exists

**Solution**: Use --skip-duplicate (already included)

## Related Documentation

- [workflow-versioning-releases.md](workflow-versioning-releases.md) - Parent workflow
- [script-create-nuget-packages.md](script-create-nuget-packages.md) - Package creation

## Notes

- **Fails workflow** if any package fails to publish
- **Uses --skip-duplicate** to handle existing versions
- **Tracks failures** and reports at end
- **Provides trusted publishing setup checks** if the API key is missing
