# Remove-GitHubPackageCIVersions.ps1 Documentation

PowerShell script that removes CI (Continuous Integration) versions from GitHub Packages while preserving stable releases and package containers.

## Synopsis

```powershell
Remove-GitHubPackageCIVersions.ps1 -RepositoryOwner <String> -Packages <String[]>
```

## Description

This script connects to the GitHub Packages API to delete all package versions containing "-ci" in their version string. It handles pagination to process packages with large numbers of versions and includes rate limiting protection to avoid API throttling.

The script is designed to clean up accumulated PR build packages from GitHub Packages while preserving:
- Stable release versions (e.g., `7.0.0`)
- RC/beta/alpha versions (e.g., `7.1.0-rc.1`)
- Package containers (allowing future version publishing)

## Location

`.github/workflows/powershell/Remove-GitHubPackageCIVersions.ps1`

## Parameters

### -RepositoryOwner

**Type**: String
**Required**: Yes
**Description**: The GitHub repository owner or organization name.

**Example**:
```powershell
-RepositoryOwner "prjseal"
```

### -Packages

**Type**: String[]
**Required**: Yes
**Description**: Array of package names to clean up. Package names are case-sensitive and must match exactly as they appear in GitHub Packages.

**Example**:
```powershell
-Packages @("Clean", "Clean.Core", "Clean.Headless")
```

## Environment Variables

The script requires the following environment variable to be set:

### GITHUB_TOKEN

**Type**: String
**Required**: Yes
**Description**: GitHub Personal Access Token or workflow token with `packages:write` permission.

**In GitHub Actions**:
```yaml
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Local Testing**:
```powershell
$env:GITHUB_TOKEN = "ghp_your_token_here"
```

## Examples

### Example 1: Clean Up Single Package

```powershell
$env:GITHUB_TOKEN = ${{ secrets.GITHUB_TOKEN }}

./Remove-GitHubPackageCIVersions.ps1 `
  -RepositoryOwner "prjseal" `
  -Packages @("Clean")
```

### Example 2: Clean Up Multiple Packages

```powershell
$env:GITHUB_TOKEN = ${{ secrets.GITHUB_TOKEN }}

./Remove-GitHubPackageCIVersions.ps1 `
  -RepositoryOwner "prjseal" `
  -Packages @("Clean", "Clean.Core", "Clean.Headless", "Umbraco.Community.Templates.Clean")
```

### Example 3: Clean Up with Custom Owner

```powershell
$env:GITHUB_TOKEN = ${{ secrets.GITHUB_TOKEN }}

./Remove-GitHubPackageCIVersions.ps1 `
  -RepositoryOwner "myorganization" `
  -Packages @("MyPackage")
```

## Process Flow

```mermaid
flowchart TD
    Start([Script Start]) --> Setup[Setup API Headers<br/>- Authorization: Bearer token<br/>- Accept: application/vnd.github+json<br/>- API Version: 2022-11-28]

    Setup --> Loop[For Each Package in Array]

    Loop --> FetchStart[Build API URL<br/>per_page=100 for efficiency]

    FetchStart --> PageLoop{More Pages<br/>to Fetch?}

    PageLoop -->|Yes| FetchPage[Invoke-WebRequest<br/>- GET versions endpoint<br/>- Include headers for pagination]

    FetchPage --> ParseJSON[Parse JSON Response<br/>Convert to PowerShell objects]

    ParseJSON --> AddVersions[Add to Versions Array<br/>Accumulate across pages]

    AddVersions --> CheckLink{Link Header<br/>Contains 'next'?}

    CheckLink -->|Yes| ParseLink[Extract Next Page URL<br/>From Link header]
    ParseLink --> PageLoop

    CheckLink -->|No| FilterCI[Filter Versions<br/>Where name matches '-ci']

    FilterCI --> HasCI{CI Versions<br/>Found?}

    HasCI -->|No| LogNoCI[Log: No CI versions]
    LogNoCI --> NextPkg

    HasCI -->|Yes| LogCount[Log: Found X CI versions<br/>out of Y total]

    LogCount --> DeleteLoop[For Each CI Version]

    DeleteLoop --> DeleteAPI[DELETE API Call<br/>- Build URL with version ID<br/>- Invoke-RestMethod DELETE]

    DeleteAPI --> CheckDelete{Delete<br/>Successful?}

    CheckDelete -->|Yes| LogSuccess[Log: ✓ Deleted version]
    CheckDelete -->|No| LogFail[Log: ✗ Failed to delete]

    LogSuccess --> Delay[Sleep 100ms<br/>Rate limit protection]
    LogFail --> Delay

    Delay --> MoreVersions{More CI<br/>Versions?}

    MoreVersions -->|Yes| DeleteLoop
    MoreVersions -->|No| LogSummary[Log Package Summary<br/>X deleted, Y failed]

    LogSummary --> NextPkg{More<br/>Packages?}

    NextPkg -->|Yes| Loop
    NextPkg -->|No| Complete[Display Completion Summary<br/>- CI versions deleted<br/>- Stable versions intact<br/>- Containers remain]

    Complete --> End([Script End])

    FetchPage -.->|404 Error| Handle404[Package Not Found<br/>Log: May not exist yet]
    Handle404 --> NextPkg

    FetchPage -.->|Other Error| HandleError[Log Error Message<br/>Show exception details]
    HandleError --> NextPkg

    style LogSuccess fill:#ccffcc
    style LogFail fill:#ffcccc
    style Complete fill:#ccffcc
    style Handle404 fill:#ffffcc
    style HandleError fill:#ffcccc
```

## Output

The script produces detailed console output during execution:

### Header
```
================================================
GitHub Packages CI Versions Cleanup
================================================
Repository Owner: prjseal
Target Pattern: Versions containing '-ci'
Supports both formats:
  - Legacy: X.Y.Z-ci.N
  - Current: X.Y.Z-ci.bNNNNNNN (SemVer-compliant)
```

### Processing Each Package
```
Processing package: Clean
  Fetching versions from: https://api.github.com/users/prjseal/packages/nuget/clean/versions?per_page=100
    Fetched 100 versions (Total so far: 100)
    Found next page, continuing...
    Fetched 50 versions (Total so far: 150)
  Total versions retrieved: 150

  Sample of all versions (first 10):
    [CI] 7.0.1-ci.b0000215 (ID: 789012)
    [CI] 7.0.1-ci.b0000214 (ID: 789011)
    [CI] 7.0.1-ci.0000213 (ID: 789010)
    [  ] 7.0.0 (ID: 123450)
    [  ] 7.0.0-rc.1 (ID: 123449)
    ... and 140 more

  Filtering for CI versions (pattern: '-ci')...
  ✓ Found 95 CI version(s) out of 150 total versions
    Format breakdown:
      - Legacy format (X.Y.Z-ci.N): 42
      - New format (X.Y.Z-ci.bNNNNNNN): 53

  Starting deletion of 95 CI versions...
    [1/95] [NEW] Deleting: 7.0.1-ci.b0000215 (ID: 789012)
    ✓ Deleted: 7.0.1-ci.b0000215
    [2/95] [NEW] Deleting: 7.0.1-ci.b0000214 (ID: 789011)
    ✓ Deleted: 7.0.1-ci.b0000214
    [3/95] [OLD] Deleting: 7.0.1-ci.0000213 (ID: 789010)
    ✓ Deleted: 7.0.1-ci.0000213
    ...

  ═══════════════════════════════════════════
  Summary for Clean
  ═══════════════════════════════════════════
    Total deleted: 95
      - Legacy format: 42
      - New format: 53
```

### Package Not Found
```
Processing package: NonExistentPackage
  Package 'NonExistentPackage' not found (may not exist yet)
```

### No CI Versions
```
Processing package: Clean.Core
  Fetching versions from: https://api.github.com/users/prjseal/packages/nuget/clean.core/versions?per_page=100
    Fetched 5 versions (Total so far: 5)
  Total versions retrieved: 5

  Sample of all versions (first 10):
    [  ] 7.0.0 (ID: 123450)
    [  ] 7.0.0-rc.1 (ID: 123449)
    [  ] 6.0.0 (ID: 123448)
    [  ] 5.0.0 (ID: 123447)
    [  ] 4.0.0 (ID: 123446)

  Filtering for CI versions (pattern: '-ci')...
  ✓ No CI versions found for Clean.Core
    All 5 version(s) are stable/release versions
```

### Completion Summary
```
═══════════════════════════════════════════════════
    CI Versions Cleanup Complete
═══════════════════════════════════════════════════

✓ Cleanup Summary:
  - Only CI versions (containing '-ci') were deleted
  - Both legacy (X.Y.Z-ci.N) and new (X.Y.Z-ci.bNNNNNNN) formats handled
  - Stable/release versions remain intact
  - Package containers remain intact
  - You can still publish new versions to these packages
```

## Key Features

### 1. Pagination Support

Handles packages with unlimited numbers of versions by following GitHub API pagination:

```powershell
# Fetches 100 versions per page (maximum allowed)
$versionsUrl = "https://api.github.com/users/$RepositoryOwner/packages/nuget/$packageName/versions?per_page=100"

# Follows 'next' links in Link header
while ($currentUrl) {
    $response = Invoke-WebRequest -Uri $currentUrl -Headers $headers
    # ... extract 'next' URL from Link header
}
```

### 2. Selective Deletion

Only deletes versions matching the CI pattern:

```powershell
# Filter for CI versions only
$ciVersions = $versions | Where-Object { $_.name -match '-ci' }
```

### 3. Rate Limiting Protection

Adds delay between deletions to avoid API throttling:

```powershell
# Small delay to avoid rate limiting
Start-Sleep -Milliseconds 100
```

### 4. Error Handling

Gracefully handles missing packages and deletion failures:

```powershell
try {
    # API call
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        # Package not found - expected for new packages
    } else {
        # Other error - log and continue
    }
}
```

## API Endpoints Used

### List Package Versions

**Method**: GET
**URL**: `https://api.github.com/users/{owner}/packages/nuget/{package}/versions`
**Query Parameters**:
- `per_page=100`: Maximum versions per page

**Response Headers**:
- `Link`: Contains pagination URLs (next, last, etc.)

### Delete Package Version

**Method**: DELETE
**URL**: `https://api.github.com/users/{owner}/packages/nuget/{package}/versions/{version_id}`

**Response**: 204 No Content on success

## Permissions Required

The `GITHUB_TOKEN` must have the following permission:

- **packages:write** - Required to delete package versions

In GitHub Actions workflows, this permission is automatically granted to the workflow token.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - All CI versions deleted (or none found) |
| 1 | Error - Failed to fetch versions or authentication error |

## Limitations

- **No undo**: Deleted versions cannot be recovered
- **CI pattern only**: Only deletes versions matching `-ci` pattern
- **Public packages**: Does not support authenticated private feeds
- **Rate limits**: GitHub API has rate limits (typically 5000 requests/hour for authenticated users)
- **No dry run**: Always performs actual deletions (no preview mode)

## Troubleshooting

### Authentication Errors

**Error**: `Response status code does not indicate success: 401 (Unauthorized)`

**Cause**: Missing or invalid `GITHUB_TOKEN`

**Solution**:
```powershell
# Ensure token is set
$env:GITHUB_TOKEN = "your-token-here"

# Verify token has packages:write scope
```

### Package Not Found (404)

**Message**: "Package 'PackageName' not found (may not exist yet)"

**Cause**: Package hasn't been published to GitHub Packages

**Solution**: This is expected behavior. The package will be skipped.

### Rate Limiting (429)

**Error**: `Response status code does not indicate success: 429 (Too Many Requests)`

**Cause**: Exceeded GitHub API rate limit

**Solution**:
- Wait for rate limit to reset (typically 1 hour)
- The script already includes 100ms delays; for very large cleanups, consider increasing the delay

### Deletion Failures

**Error**: `Failed to delete version X.X.X-ci.X`

**Causes**:
- Network error
- Insufficient permissions
- Version already deleted

**Solution**: Check the error message for specifics. The script continues with remaining versions even if one fails.

## Related Documentation

- [workflow-cleanup-github-packages.md](workflow-cleanup-github-packages.md) - Workflow documentation
- [GitHub Packages API Documentation](https://docs.github.com/en/rest/packages)
- [GitHub API Rate Limiting](https://docs.github.com/en/rest/overview/rate-limits-for-the-rest-api)

## Best Practices

1. **Test with small package first**: Start with a package that has few versions to verify behavior
2. **Check package list**: Review GitHub Packages UI before running to see what will be deleted
3. **Monitor output**: The script provides verbose logging including:
   - Version samples showing which are CI vs. stable
   - Format breakdown (legacy vs. new SemVer-compliant format)
   - Progress counter showing deletion status ([N/total])
   - Detailed summary showing deletions by format
4. **Handle failures**: The script logs failures but continues; review the summary to identify issues
5. **Rate limit awareness**: For packages with 1000+ CI versions, the cleanup may take 2-3 minutes
6. **Version format compatibility**: The script automatically detects and handles both legacy (`X.Y.Z-ci.N`) and new (`X.Y.Z-ci.bNNNNNNN`) CI version formats

## Version History

- **v1.1**: Enhanced logging with version samples, format breakdown, progress counters, and detailed summaries
- **v1.0**: Initial version with pagination support and selective CI version deletion
