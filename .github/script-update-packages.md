# Update NuGet Packages Workflow Documentation

This document describes the automated NuGet package update workflow for the Clean Umbraco starter kit, which keeps third-party dependencies up-to-date through automated daily checks and pull request creation.

## Overview

The Update NuGet Packages workflow automatically checks for and applies updates to third-party NuGet package dependencies across the entire solution. It runs daily, builds the solution to verify compatibility, and creates pull requests with the changes for review.

## Workflow Files and Scripts

**Workflow Location**: `.github/workflows/update-packages.yml`

**PowerShell Scripts**:
- `.github/workflows/powershell/UpdateThirdPartyPackages.ps1` - Updates third-party NuGet packages
- `.github/workflows/powershell/UpdateReadmeUmbracoVersion.ps1` - Updates README.md with latest Umbraco versions

## When Does It Run?

The workflow can be triggered in two ways:

### 1. Scheduled Execution (Automatic)
- **Schedule**: Daily at 10:30 AM UK time (10:30 AM UTC in winter, 11:30 AM BST in summer)
- **Cron Expression**: `30 10 * * *`
- **Purpose**: Keep dependencies current with minimal maintenance overhead

### 2. Manual Execution (On-Demand)
- **Trigger**: GitHub Actions "Run workflow" button
- **Parameters**:
  - **dryRun**: Run without making changes (default: `false`)
  - **includePrerelease**: Include prerelease versions (default: `false` for manual runs)
  - **umbracoVersions**: Comma-separated Umbraco major versions to update (default: `13`)
    - Supports per-version prerelease flag: append `-` to version (e.g., `17-` to include prereleases for version 17)
    - Example: `13,17-` updates stable for version 13 and prereleases for version 17
  - **nugetSources**: Comma-separated custom NuGet source URLs (default: empty)
- **Use Cases**:
  - Emergency security updates
  - Testing before scheduled run
  - Immediate dependency refresh after major releases
  - Testing with pre-release packages from custom NuGet feeds

### Environment Variables

The workflow uses environment variables to control scheduled run behavior:

- **SCHEDULED_INCLUDE_PRERELEASE**: Controls whether scheduled runs include prerelease versions (default: `true`)
  - Set to `'false'` to only use stable releases in scheduled runs (e.g., when Umbraco 17 is officially released)
  - Manual runs use the `includePrerelease` input parameter instead
- **UMBRACO_MAJOR_VERSIONS**: Comma-separated list of Umbraco major versions to track (default: `'13'`)
  - Used by scheduled runs and manual runs without version input
  - Example: `'13,17'` to track both Umbraco 13 and 17

## Custom NuGet Sources

The Update NuGet Packages workflow supports using custom NuGet sources when checking for package updates. This is useful for testing with pre-release packages from feeds like Umbraco's development feed, MyGet, or Azure DevOps that aren't available on the public NuGet.org feed.

### How to Use

When manually triggering the workflow, provide custom NuGet source URLs in the **nugetSources** input field:

**Single Source**:
```
https://www.myget.org/F/umbraco-dev/api/v3/index.json
```

**Multiple Sources** (comma-separated):
```
https://www.myget.org/F/umbraco-dev/api/v3/index.json, https://pkgs.dev.azure.com/myorg/_packaging/myfeed/nuget/v3/index.json
```

### What Happens

When custom NuGet sources are provided:

1. **Sources are Added**: The workflow configures the custom sources before checking for package updates
2. **Package Updates**: The script checks both NuGet.org and custom sources for the latest versions
3. **PR Creation**: The created PR automatically includes `nuget-source:` lines in the description
4. **PR Build Integration**: The PR build workflow automatically detects and uses these sources

### Example Workflow

**Step 1: Trigger Update Workflow**
- Go to Actions → "Update NuGet Packages"
- Click "Run workflow"
- Set parameters:
  - **Include prerelease versions**: `true`
  - **Custom NuGet sources**: `https://www.myget.org/F/umbraco-dev/api/v3/index.json`
- Click "Run workflow"

**Step 2: Workflow Runs**
- Adds custom NuGet source
- Checks for updates (including packages from custom source)
- Creates PR with changes

**Step 3: PR is Created**
The PR description automatically includes:
```markdown
## Custom NuGet Sources

This PR was created with custom NuGet sources. The PR build will automatically use these sources:

nuget-source: https://www.myget.org/F/umbraco-dev/api/v3/index.json
```

**Step 4: PR Build Runs**
- The PR build workflow reads the `nuget-source:` line
- Automatically adds the source before building packages
- Tests with the same sources used to create the PR

### Common Use Cases

**Testing Umbraco RC Versions**:
```
https://www.myget.org/F/umbraco-dev/api/v3/index.json
```

Use this when you want to update to a release candidate version of Umbraco that hasn't been published to NuGet.org yet.

**Azure DevOps Artifacts Feed**:
```
https://pkgs.dev.azure.com/myorg/_packaging/myfeed/nuget/v3/index.json
```

Use this for testing with internal or preview packages.

**MyGet Feed**:
```
https://www.myget.org/F/myfeed/api/v3/index.json
```

Use this for packages published to MyGet before public release.

### Limitations

- Only public NuGet feeds are supported (no authentication)
- Sources are only used for the specific workflow run
- Sources are not persisted to repository configuration
- Invalid URLs will cause warnings but won't fail the workflow

### Integration with PR Workflow

The custom sources feature seamlessly integrates with the PR build workflow:

1. **Update Workflow** → Adds sources → Finds new packages → Creates PR with `nuget-source:` lines
2. **PR Workflow** → Reads `nuget-source:` lines → Adds sources → Builds with same sources
3. **Result** → Consistent package resolution across both workflows

This ensures that if you update to a package version from a custom source, the PR build can also access that version.

## What It Does

The workflow performs a comprehensive update process with multiple validation steps:

### 1. **README Version Update**

Before updating packages, the workflow updates README.md with the latest Umbraco version(s):

**Process**:
- Queries NuGet.org for the latest version of `Umbraco.Cms.Web.Website` for each configured major version
- Supports both stable and prerelease versions based on configuration
- Updates installation instructions in README.md with the latest versions
- Tracks which major versions were updated (e.g., "13", "17", or "13,17")

**Version Selection**:
- **Stable-only mode**: Uses the latest version without a prerelease suffix (e.g., `17.0.0`)
- **Prerelease mode**: Uses the latest version including prereleases, with smart sorting:
  - RC versions (highest priority)
  - Beta versions
  - Alpha versions
  - Stable versions (when no prereleases exist)

**Per-Version Configuration**:
- Can enable prerelease for specific versions using trailing `-` notation
- Example: `umbracoVersions: "13,17-"` means stable for v13, prerelease for v17

**README Patterns Updated**:
```markdown
dotnet new install Umbraco.Templates::{version} --force
```

This ensures installation instructions always reference the latest available Umbraco version.

### 2. **Package Discovery and Analysis**

Scans the repository for all `.csproj` files and analyzes their package references:

```xml
<!-- Example package reference in .csproj -->
<PackageReference Include="Umbraco.Cms.Web.Website" Version="17.0.0" />
```

**Process**:
- Recursively finds all `.csproj` files in the repository
- Parses XML to identify `<PackageReference>` elements with `Version` attributes
- Skips packages managed by Central Package Management (CPM)
- Excludes internal project packages

### 3. **Version Resolution**

For each package, queries NuGet.org to determine the latest available version:

**API Endpoint**:
```
https://api.nuget.org/v3-flatcontainer/{package-id}/index.json
```

**Version Selection Logic**:
- **With `includePrerelease: true`** (default): Uses the absolute latest version (including `-alpha`, `-beta`, `-rc`)
- **With `includePrerelease: false`**: Uses the latest stable version (no prerelease suffix)
- **Stable vs Prerelease**: Determined by presence of hyphen in version (e.g., `17.0.0` vs `17.0.0-rc.1`)

**Caching**:
- Version queries are cached per package ID to reduce API calls
- Cache persists for the duration of the script execution
- Shared across all `.csproj` files for efficiency

### 4. **Package Update Application**

Updates package references in `.csproj` files:

**Before**:
```xml
<PackageReference Include="Microsoft.Extensions.Logging" Version="8.0.0" />
```

**After**:
```xml
<PackageReference Include="Microsoft.Extensions.Logging" Version="8.0.1" />
```

**Safety Features**:
- Only updates packages where new version differs from current version
- Preserves XML formatting and structure
- Case-insensitive version comparison to avoid unnecessary changes
- Skips packages without a `Version` attribute (CPM-managed packages)

### 5. **Build Validation**

Performs comprehensive build validation to ensure updates don't break the solution:

#### Clean Phase
```powershell
dotnet clean "{solution}.sln" -clp:Summary -v:m
```

**Purpose**: Remove previous build artifacts to ensure clean state

#### Build Phase
```powershell
dotnet build "{solution}.sln" -clp:Summary -v:m
```

**Purpose**: Verify all projects compile with updated packages

**Validation Output**:
- **Success/Failure Status**: Per-solution build result
- **Error Count**: Number of compilation errors
- **Warning Count**: Number of compilation warnings
- **Detailed Logs**: Full stdout/stderr saved to `.artifacts/logs/`

**Log Files** (per solution):
```
.artifacts/logs/{solution}__{timestamp}.clean.stdout.txt
.artifacts/logs/{solution}__{timestamp}.clean.stderr.txt
.artifacts/logs/{solution}__{timestamp}.build.stdout.txt
.artifacts/logs/{solution}__{timestamp}.build.stderr.txt
```

### 6. **Summary Reporting**

Generates two comprehensive summary tables:

#### Package Update Summary

```
+------------------+----------------------------------+--------------+--------------+
| File Name        | Package Name                     | Old Version  | New Version  |
+------------------+----------------------------------+--------------+--------------+
| Clean.csproj     | Umbraco.Cms.Web.Website         | 17.0.0       | 17.0.1       |
| Clean.Core.csproj| Microsoft.Extensions.Logging    | 8.0.0        | 8.0.1        |
+------------------+----------------------------------+--------------+--------------+
```

**Saved to**: `.artifacts/package-summary.txt`

**Features**:
- Grouped by `.csproj` file with visual separators
- Shows exact version changes (old → new)
- Sorted by file name, then package name
- Used in pull request body for transparency

#### Build Summary

```
+---------------------+--------------+--------------+---------+-----------+
| Solution Name       | Clean Result | Build Result | Errors  | Warnings  |
+---------------------+--------------+--------------+---------+-----------+
| Clean.sln          | Success      | Success      | 0       | 0         |
+---------------------+--------------+--------------+---------+-----------+
```

**Saved to**: `.artifacts/build-summary.txt`

**Metrics**:
- Clean operation status
- Build operation status
- Error count (from MSBuild summary or diagnostic count)
- Warning count (from MSBuild summary or diagnostic count)

### 7. **Change Detection**

Before creating a pull request, the workflow intelligently checks for changes:

**Check Types**:
1. **README Update Status**: Checks if `UpdateReadmeUmbracoVersion.ps1` modified README.md
2. **Package Updates**: Reads `.artifacts/package-summary.txt` to verify package changes were made

**Outcomes**:
- **No changes detected**: Exits gracefully with informative message, no PR created
- **README-only changes**: Proceeds with commit including `[skip ci]` tag
- **Package-only changes**: Proceeds with standard commit
- **Both updated**: Proceeds with combined commit
- **Purpose**: Prevents empty PRs when all packages and README are already up-to-date

**Smart Exit Message**:
```
================================================
✅ No Changes Needed - Workflow Complete
================================================

Summary:
  • README: Already up-to-date with latest Umbraco version(s)
  • NuGet Packages: All packages are already at their latest versions

No branch created, no commits made, no PR needed.
================================================
```

### 8. **Commit and Push Changes**

Creates commits with smart commit messages based on what was updated:

**Commit Message Logic**:
- **README-only**: `"Update README with latest Umbraco {version} version [skip ci]"`
  - Includes `[skip ci]` to avoid unnecessary CI builds for documentation updates
- **Packages-only**: `"Update NuGet packages"`
- **Both updated**: `"Update README and NuGet packages"`

**Branch Naming**:
```
update-nuget-packages-{timestamp}
```
Example: `update-nuget-packages-20250124143045`

**Git Operations**:
```bash
git config user.name "github-actions"
git config user.email "github-actions@github.com"
git checkout -b {branch}
git add .
git commit -m "{message}"
git push
```

### 9. **Pull Request Creation**

Creates a pull request with a detailed description of what was updated:

**PR Title**:
```
Update NuGet packages
```

**PR Body** (format varies based on what was updated):
```markdown
This PR updates the following:

- ✅ **README.md** - Updated with latest Umbraco {version} version
- ✅ **NuGet Packages** - Updated to latest versions

**Triggered by:** {github.actor}

## Custom NuGet Sources

This PR was created with custom NuGet sources. The PR build will automatically use these sources:

nuget-source: https://www.myget.org/F/umbraco-dev/api/v3/index.json

**IncludePrerelease:** true

### Updated Packages:
```
{package-summary.txt contents}
```
```

**Target Branch**: `main`

**Dynamic Content**:
- Only shows README section if README was updated
- Only shows NuGet Packages section if packages were updated
- Only shows Custom NuGet Sources section if custom sources were provided
- Displays the actor who triggered the workflow (user or github-actions[bot])

### 10. **Duplicate Detection**

Advanced duplicate PR detection prevents creating redundant pull requests:

**Detection Process**:
1. Lists all open PRs with branches matching `update-nuget-packages-*`
2. Extracts package update table from each PR body
3. Normalizes whitespace for accurate comparison
4. Compares current changes with existing PR contents

**Comparison Logic**:
```powershell
# Extract content between triple backticks
$prBody -match '(?s)```(.+?)```'

# Normalize whitespace
$currentNormalized = $currentSummary.Trim() -replace '\s+', ' '
$prNormalized = $prPackages -replace '\s+', ' '

# Compare
if ($currentNormalized -eq $prNormalized) {
    # Skip creating duplicate PR
}
```

**Outcomes**:
- **Identical updates found**: Skips PR creation, displays existing PR link
- **Different updates**: Creates new PR with latest changes
- **Purpose**: Avoid spam when scheduled job runs but packages haven't changed since last PR

**Skip Message**:
```
================================================
PR CREATION SKIPPED
================================================

An existing PR (#123) already has identical package updates.
No need to create a duplicate PR.

Existing PR: https://github.com/{owner}/{repo}/pull/123
================================================
```

## Workflow Steps Diagram

```mermaid
flowchart TD
    Start([Trigger: Schedule or Manual]) --> Checkout[1. Checkout Repository<br/>fetch-depth: 0]
    Checkout --> DotNet[2. Setup .NET 10<br/>Installs .NET 10.0.x SDK]
    DotNet --> CustomSources{3. Custom NuGet<br/>Sources Provided?}

    CustomSources -->|Yes| ConfigSources[Configure Custom Sources<br/>- Parse comma-separated URLs<br/>- Add each with dotnet nuget add source<br/>- List configured sources]
    CustomSources -->|No| GHCli[4. Install GitHub CLI<br/>choco install gh -y]
    ConfigSources --> GHCli

    GHCli --> UpdateReadme[5. Update README with Umbraco Versions<br/>- Run UpdateReadmeUmbracoVersion.ps1<br/>- Process each major version<br/>- Query NuGet.org for latest Umbraco.Cms<br/>- Handle per-version prerelease flags]

    UpdateReadme --> UpdatePackages[6. Run UpdateThirdPartyPackages.ps1<br/>- Scan for .csproj files<br/>- Query NuGet for latest versions<br/>- Update PackageReference elements<br/>- Clean and build all solutions]

    UpdatePackages --> BuildCheck{Build<br/>Success?}

    BuildCheck -->|No| BuildFailure[7. Build Failure Summary<br/>- Display build-summary.txt<br/>- Show errors and warnings<br/>- Exit workflow]
    BuildFailure --> End1([End: Build Failed])

    BuildCheck -->|Yes| CheckChanges[8. Check if Changes Were Made<br/>- Check README update status<br/>- Check package-summary.txt]

    CheckChanges --> HasChanges{Changes<br/>Detected?}

    HasChanges -->|No| NoChanges[Exit Gracefully<br/>Display 'No Changes Needed' message]
    NoChanges --> End2([End: No Changes])

    HasChanges -->|Yes| DryRun{Dry Run<br/>Mode?}

    DryRun -->|Yes| End3([End: Dry Run Complete])
    DryRun -->|No| Commit[9. Commit and Push Changes<br/>- Configure git user<br/>- Create branch: update-nuget-packages-timestamp<br/>- Stage all changes<br/>- Determine commit message<br/>- Push using PAT_TOKEN]

    Commit --> ReadSummary[10. Read Package Summary<br/>Load .artifacts/package-summary.txt]

    ReadSummary --> CheckDupes[11. Check for Existing Similar PRs<br/>- List open PRs matching pattern<br/>- Extract package tables from bodies<br/>- Normalize and compare summaries]

    CheckDupes --> DupeCheck{Duplicate PR<br/>Exists?}

    DupeCheck -->|Yes| SkipPR[Display PR Skipped Message<br/>Show existing PR link]
    SkipPR --> End4([End: PR Skipped])

    DupeCheck -->|No| CreatePR[12. Create Pull Request<br/>- Authenticate with GitHub CLI<br/>- Build dynamic PR body<br/>- Include README/package updates<br/>- Add custom sources if used<br/>- Create PR: main ← update-nuget-packages-timestamp]

    CreatePR --> Summary[13. Summary Output<br/>Display new PR link]
    Summary --> End5([End: PR Created])

    style BuildFailure fill:#ffcccc
    style NoChanges fill:#ccffcc
    style SkipPR fill:#ffffcc
    style CreatePR fill:#ccffcc
    style BuildCheck fill:#e6e6fa
    style HasChanges fill:#e6e6fa
    style DryRun fill:#e6e6fa
    style DupeCheck fill:#e6e6fa
    style CustomSources fill:#e6e6fa
```

## PowerShell Script Details

### UpdateThirdPartyPackages.ps1

**Location**: `.github/workflows/powershell/UpdateThirdPartyPackages.ps1`

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `RootPath` | string | Current directory | Repository root path to scan for projects |
| `DryRun` | switch | `false` | If set, simulates changes without modifying files or running builds |
| `IncludePrerelease` | switch | `false` | If set, includes prerelease versions (alpha, beta, rc) in update checks |
| `IgnorePackages` | string[] | `@()` | Exact package IDs to skip (case-insensitive) |
| `IgnorePatterns` | string[] | `@()` | Regex patterns for package IDs to skip (case-insensitive) |
| `InternalPackages` | string[] | `@()` | Exact internal package IDs to skip (case-insensitive) |
| `InternalPatterns` | string[] | `@()` | Regex patterns for internal packages to skip (case-insensitive) |
| `KillRunning` | switch | `false` | If set, stops any running processes from the repository before building |

### Key Functions

#### 1. `Get-LatestNuGetVersion`
**Purpose**: Query NuGet.org API for the latest package version

**Parameters**:
- `$packageId`: NuGet package identifier
- `$cache`: Hashtable for caching results
- `$IncludePrerelease`: Whether to include prerelease versions

**API Call**:
```powershell
$url = "https://api.nuget.org/v3-flatcontainer/{package-id}/index.json"
$resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 20
```

**Logic**:
```powershell
if ($IncludePrerelease) {
    $chosen = $versions[-1]  # Last version (latest)
} else {
    $stable = $versions | Where-Object { $_ -notmatch '-' }
    $chosen = if ($stable.Count -gt 0) { $stable[-1] } else { $versions[-1] }
}
```

**Caching**: Results stored in hashtable to avoid duplicate API calls

#### 2. `Update-Csproj-PackageReferences`
**Purpose**: Update package versions in a `.csproj` file

**Parameters**:
- `$csprojPath`: Path to `.csproj` file
- `$versionCache`: Shared version cache
- `$DryRunFlag`: Whether to simulate changes
- `$IncludePrerelease`: Include prerelease versions
- Package filtering parameters

**Process**:
1. Load `.csproj` as XML
2. Select all `//PackageReference` nodes
3. Filter out ignored and internal packages
4. Query NuGet for latest versions
5. Update `Version` attributes if changed
6. Save XML back to file (unless dry run)

**Returns**: Object with `Path`, `Updated`, `Changes`, `Errors`

#### 3. `Run-DotNet`
**Purpose**: Execute dotnet CLI commands with output capture

**Parameters**:
- `$Command`: Dotnet command and arguments
- `$Path`: Working directory
- `$DryRunFlag`: Skip execution if true
- `$StdOutFile`: Path to save stdout
- `$StdErrFile`: Path to save stderr

**Implementation**:
```powershell
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "dotnet"
$psi.Arguments = $Command
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
[void]$proc.Start()

$stdOut = $proc.StandardOutput.ReadToEnd()
$stdErr = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()
```

**Returns**: Object with `Command`, `Path`, `Success`, `ExitCode`, `StdOut`, `StdErr`

#### 4. `Write-AsciiTable`
**Purpose**: Render ASCII tables for console and file output

**Features**:
- Border drawing with `+`, `-`, `|` characters
- Column width auto-calculation
- Left/right alignment support
- Row grouping with separator lines
- Dual output (console + file)

**Example Output**:
```
+------------------+----------------------------------+--------------+--------------+
| File Name        | Package Name                     | Old Version  | New Version  |
+------------------+----------------------------------+--------------+--------------+
| Clean.csproj     | Umbraco.Cms.Web.Website         | 17.0.0       | 17.0.1       |
+------------------+----------------------------------+--------------+--------------+
```

#### 5. `Ensure-Directory`
**Purpose**: Create directory if it doesn't exist

**Safety Features**:
- Null/whitespace validation
- Container type checking
- Exception handling with detailed errors

#### 6. `Write-Log`
**Purpose**: Structured logging with timestamps and colors

**Format**:
```
[2025-01-22T14:30:45] [INFO] Querying NuGet for Microsoft.Extensions.Logging
```

**Parameters**:
- `$Prefix`: Text before colored value
- `$Value`: Text to display in color
- `$Suffix`: Text after colored value
- `$ValueColor`: Color for the value
- `$Level`: Log level (INFO, WARN, ERROR)

### Execution Flow

```powershell
# 1. Validation
if (-not (Test-Path $templatePath)) { Fail-Fast }

# 2. Setup
$artifactsRoot = Join-Path $RootPath ".artifacts"
$logsDir = Join-Path $artifactsRoot "logs"
Ensure-Directory $artifactsRoot
Ensure-Directory $logsDir

# 3. Package Updates
$csprojFiles = Get-ChildItem -Path $templatePath -Filter *.csproj -Recurse
$versionCache = @{}
$updateResults = @()

foreach ($csproj in $csprojFiles) {
    $updateResults += Update-Csproj-PackageReferences ...
}

# 4. Build Validation
$slnFiles = Get-ChildItem -Path $RootPath -Filter *.sln -Recurse
$buildResults = @()

foreach ($sln in $slnFiles) {
    $cleanResult = Run-DotNet -Command "clean ..."
    $buildResult = Run-DotNet -Command "build ..."
    $buildResults += [ordered]@{ ... }
}

# 5. Summary Generation
Write-AsciiTable -Rows $packageChanges -OutputFile "package-summary.txt"
Write-AsciiTable -Rows $buildSummaryRows -OutputFile "build-summary.txt"
```

### UpdateReadmeUmbracoVersion.ps1

**Location**: `.github/workflows/powershell/UpdateReadmeUmbracoVersion.ps1`

**Purpose**: Updates README.md with the latest Umbraco version(s) from NuGet.org

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `RootPath` | string | Current directory | Repository root where README.md is located |
| `ReadmePath` | string | `{RootPath}/README.md` | Path to README.md file |
| `UmbracoMajorVersion` | string/array | `"13"` | Umbraco major version(s) to update (e.g., "13" or "13,17") |
| `IncludePrerelease` | switch | `false` | If set, includes prerelease versions (alpha, beta, rc) |

#### Key Features

**1. Multiple Version Support**:
- Accepts comma-separated version strings: `"13,17"`
- Accepts string arrays: `@("13", "17")`
- Processes each version independently

**2. Per-Version Prerelease Flag**:
- Trailing `-` on version enables prerelease for that version
- Example: `"13,17-"` means stable for v13, prerelease for v17
- Overrides global `IncludePrerelease` switch for specific versions

**3. Smart Version Sorting**:
```powershell
# Prerelease priority (highest to lowest):
- RC (release candidate): Priority 70
- Beta: Priority 50
- Alpha: Priority 30
- Unknown prerelease: Priority 40
- Stable (no suffix): Priority 100
```

**4. Section-Targeted Updates**:
- Searches for `## Umbraco {version}` section headers
- Updates only within that specific section
- Multiple sections can be updated in a single run
- Preserves content between sections

**5. Pattern Matching**:
```regex
dotnet new install Umbraco\.Templates::(\d+\.\d+\.\d+(?:-[A-Za-z0-9]+)?) --force
```

Updates version in installation commands while preserving surrounding text.

#### Return Value

Returns a hashtable with:
- `Updated`: `$true` if README was modified, `$false` otherwise
- `Version`: Comma-separated list of updated versions (e.g., "13,17")
- `Error`: Error message if something went wrong, `$null` otherwise

#### Example Usage

```powershell
# Update single version (stable only)
.\UpdateReadmeUmbracoVersion.ps1 -UmbracoMajorVersion "13"

# Update single version (include prerelease)
.\UpdateReadmeUmbracoVersion.ps1 -UmbracoMajorVersion "17" -IncludePrerelease

# Update multiple versions (stable for both)
.\UpdateReadmeUmbracoVersion.ps1 -UmbracoMajorVersion "13,17"

# Update multiple versions (stable for 13, prerelease for 17)
.\UpdateReadmeUmbracoVersion.ps1 -UmbracoMajorVersion "13,17-"

# Update with array input
.\UpdateReadmeUmbracoVersion.ps1 -UmbracoMajorVersion @("13", "17-")
```

#### Integration with Workflow

The workflow calls this script before updating packages:

```yaml
- name: Update README with latest Umbraco versions
  id: update-readme
  shell: pwsh
  run: |
    # Determine version configuration
    $versionsString = "${{ env.UMBRACO_MAJOR_VERSIONS }}"

    # Process each version with per-version prerelease flags
    $result = ./.github/workflows/powershell/UpdateReadmeUmbracoVersion.ps1 `
      -RootPath "${{ github.workspace }}" `
      -UmbracoMajorVersion $version `
      -IncludePrerelease:$perVersionFlag

    # Output results for subsequent steps
    echo "readme_updated=$($result.Updated)" >> $env:GITHUB_OUTPUT
    echo "updated_versions=$($result.Version)" >> $env:GITHUB_OUTPUT
```

The outputs are used by later steps to:
1. Determine if any changes were made
2. Generate appropriate commit messages
3. Create informative PR descriptions

## Technical Details

### Environment

- **OS**: Windows (windows-latest)
- **.NET Version**: 10.0.x
- **PowerShell**: PowerShell Core (pwsh)
- **GitHub CLI**: Latest (via Chocolatey)

### Authentication

- **PAT_TOKEN**: Personal Access Token secret for pushing to repository and creating PRs
  - Required Permissions:
    - `repo` (full repository access)
    - `workflow` (workflow management)
- **GITHUB_TOKEN**: Automatic token for GitHub CLI authentication

### File Locations

```
.artifacts/
├── logs/
│   ├── {solution}__{timestamp}.clean.stdout.txt
│   ├── {solution}__{timestamp}.clean.stderr.txt
│   ├── {solution}__{timestamp}.build.stdout.txt
│   └── {solution}__{timestamp}.build.stderr.txt
├── package-summary.txt
└── build-summary.txt
```

### NuGet API Usage

**Endpoint**: `https://api.nuget.org/v3-flatcontainer/{package-id}/index.json`

**Response Format**:
```json
{
  "versions": [
    "1.0.0",
    "1.0.1",
    "1.1.0",
    "2.0.0-alpha.1",
    "2.0.0"
  ]
}
```

**Rate Limiting**:
- No explicit rate limits documented
- Script uses caching to minimize calls
- 20-second timeout per request

### Git Operations

**Configuration**:
```bash
git config user.name "github-actions"
git config user.email "github-actions@github.com"
```

**Branch Creation**:
```bash
git checkout -b update-nuget-packages-20250122143045
```

**Staging and Committing**:
```bash
git add .
git commit -m "Update NuGet packages"
```

**Push with Authentication**:
```bash
git push https://x-access-token:${PAT_TOKEN}@github.com/{owner}/{repo}.git {branch}
```

### GitHub CLI Operations

**Authentication**:
```bash
echo $env:GITHUB_TOKEN | gh auth login --with-token
```

**List PRs**:
```bash
gh pr list --state open --json number,headRefName,body --limit 100
```

**Create PR**:
```bash
gh pr create --title "..." --body-file pr-body.md --base main --head {branch}
```

## Manual Execution

### Using GitHub Actions UI

1. **Navigate to Actions**
   - Go to repository → Actions tab
   - Click "Update NuGet Packages" workflow

2. **Run Workflow**
   - Click "Run workflow" dropdown
   - Select branch (usually `main`)
   - Configure parameters:
     - **Run without making changes**: Check for dry run testing
     - **Include prerelease versions**: Uncheck for stable-only (default: unchecked)
     - **Comma-separated Umbraco major versions**: Enter versions like `13` or `13,17-` (default: `13`)
     - **Comma-separated custom NuGet source URLs**: Optional, for custom feeds
   - Click "Run workflow"

3. **Monitor Execution**
   - Workflow appears in the list
   - Click to view real-time logs
   - Check for README update results
   - Review package update summaries
   - Check for errors, warnings, or build failures

### Using GitHub CLI

```bash
# Trigger with default parameters (uses env variables: UMBRACO_MAJOR_VERSIONS, stable only)
gh workflow run update-packages.yml

# Dry run to preview changes (stable versions)
gh workflow run update-packages.yml \
  -f dryRun=true \
  -f includePrerelease=false

# Update to stable versions only (explicit)
gh workflow run update-packages.yml \
  -f dryRun=false \
  -f includePrerelease=false

# Update including prereleases
gh workflow run update-packages.yml \
  -f includePrerelease=true

# Update specific Umbraco versions (stable for both)
gh workflow run update-packages.yml \
  -f umbracoVersions="13,17" \
  -f includePrerelease=false

# Update with per-version prerelease flags (stable for 13, prerelease for 17)
gh workflow run update-packages.yml \
  -f umbracoVersions="13,17-" \
  -f includePrerelease=false

# Update with custom NuGet source (single source)
gh workflow run update-packages.yml \
  -f includePrerelease=true \
  -f nugetSources="https://www.myget.org/F/umbraco-dev/api/v3/index.json"

# Update with multiple custom NuGet sources
gh workflow run update-packages.yml \
  -f includePrerelease=true \
  -f nugetSources="https://www.myget.org/F/umbraco-dev/api/v3/index.json,https://pkgs.dev.azure.com/myorg/_packaging/myfeed/nuget/v3/index.json"

# Update specific Umbraco versions with custom source (17 prerelease only)
gh workflow run update-packages.yml \
  -f umbracoVersions="17-" \
  -f nugetSources="https://www.myget.org/F/umbraco-dev/api/v3/index.json"

# Watch workflow execution
gh run watch

# View latest run logs
gh run view --log
```

### Local Execution

For testing or manual updates:

#### Update README with Latest Umbraco Versions

```powershell
# Navigate to repository root
cd /path/to/Clean

# Update single version (stable only)
./.github/workflows/powershell/UpdateReadmeUmbracoVersion.ps1 `
  -RootPath "." `
  -UmbracoMajorVersion "13"

# Update single version (include prerelease)
./.github/workflows/powershell/UpdateReadmeUmbracoVersion.ps1 `
  -RootPath "." `
  -UmbracoMajorVersion "17" `
  -IncludePrerelease

# Update multiple versions (stable for 13, prerelease for 17)
./.github/workflows/powershell/UpdateReadmeUmbracoVersion.ps1 `
  -RootPath "." `
  -UmbracoMajorVersion "13,17-"
```

#### Update Third-Party Packages

```powershell
# Dry run to preview changes
./.github/workflows/powershell/UpdateThirdPartyPackages.ps1 `
  -RootPath "." `
  -DryRun `
  -IncludePrerelease

# Apply updates
./.github/workflows/powershell/UpdateThirdPartyPackages.ps1 `
  -RootPath "." `
  -IncludePrerelease

# Stable versions only
./.github/workflows/powershell/UpdateThirdPartyPackages.ps1 `
  -RootPath "." `
  -IncludePrerelease:$false

# Ignore specific packages
./.github/workflows/powershell/UpdateThirdPartyPackages.ps1 `
  -RootPath "." `
  -IncludePrerelease `
  -IgnorePackages "Newtonsoft.Json","Microsoft.NET.Test.Sdk"

# Ignore packages by pattern
./.github/workflows/powershell/UpdateThirdPartyPackages.ps1 `
  -RootPath "." `
  -IncludePrerelease `
  -IgnorePatterns "^Microsoft\.Extensions\.", "Analyzers$"
```

## Package Filtering

The script supports multiple filtering mechanisms to control which packages get updated:

### Ignore Packages (Exact Match)

**Use Case**: Exclude specific packages by exact name

**Example**:
```yaml
# In workflow file
-IgnorePackages "Umbraco.Cms.Web.Website","Newtonsoft.Json"
```

**PowerShell**:
```powershell
-IgnorePackages @("Umbraco.Cms.Web.Website", "Newtonsoft.Json")
```

**Matching**: Case-insensitive exact match of package ID

### Ignore Patterns (Regex)

**Use Case**: Exclude packages by naming pattern

**Example**:
```yaml
# Ignore all Microsoft.Extensions packages
-IgnorePatterns "^Microsoft\.Extensions\."

# Ignore all analyzer packages
-IgnorePatterns "Analyzers$"
```

**PowerShell**:
```powershell
-IgnorePatterns @("^Microsoft\.Extensions\.", "Analyzers$")
```

**Matching**: Case-insensitive regex match against package ID

### Internal Packages (Exact Match)

**Use Case**: Mark packages as internal/local to skip updates

**Example**:
```yaml
-InternalPackages "Clean.Core","Clean.Headless"
```

**PowerShell**:
```powershell
-InternalPackages @("Clean.Core", "Clean.Headless")
```

**Purpose**: Prevents attempting to update project-local packages

### Internal Patterns (Regex)

**Use Case**: Mark internal packages by naming convention

**Example**:
```yaml
# Treat all packages starting with "Clean." as internal
-InternalPatterns "^Clean\."
```

**PowerShell**:
```powershell
-InternalPatterns @("^Clean\.")
```

**Purpose**: Automatically identify internal packages by naming pattern

### Automatic Filtering

The script automatically skips:

1. **CPM-Managed Packages**: Packages without `Version` attribute
   ```xml
   <!-- This package is managed by CPM, won't be updated -->
   <PackageReference Include="Some.Package" />
   ```

2. **Child `<Version>` Elements**: Only `Version` attributes are updated
   ```xml
   <!-- Script only updates attribute-style versions -->
   <PackageReference Include="Package" Version="1.0.0" />

   <!-- This style is skipped (CPM pattern) -->
   <PackageReference Include="Package">
     <Version>1.0.0</Version>
   </PackageReference>
   ```

3. **Unchanged Versions**: Packages already at latest version are skipped

## Reviewing Pull Requests

When a package update PR is created, follow these review guidelines:

### 1. Check the PR Description

**What to Look For**:
- **IncludePrerelease setting**: Verify if prerelease versions were included
- **Triggered by**: Confirm if scheduled or manual trigger
- **Updated Packages table**: Review the list of changed packages

**Example**:
```
+------------------+----------------------------------+--------------+--------------+
| File Name        | Package Name                     | Old Version  | New Version  |
+------------------+----------------------------------+--------------+--------------+
| Clean.csproj     | Umbraco.Cms.Web.Website         | 17.0.0       | 17.0.1       |
| Clean.csproj     | Microsoft.Extensions.Logging    | 8.0.0        | 8.0.1        |
+------------------+----------------------------------+--------------+--------------+
```

### 2. Review Changed Files

**Files to Check**:
- All `.csproj` files with modified `<PackageReference>` elements
- Ensure only `Version` attributes changed
- Verify no unexpected file modifications

### 3. Assess Update Risk

**Version Changes to Scrutinize**:

| Change Type | Example | Risk Level | Action |
|-------------|---------|------------|--------|
| Patch update | `17.0.0` → `17.0.1` | Low | Usually safe, review release notes |
| Minor update | `17.0.0` → `17.1.0` | Medium | Check for new features, test thoroughly |
| Major update | `17.0.0` → `18.0.0` | High | Review breaking changes, migration guide |
| Prerelease | `17.0.0` → `17.1.0-rc.1` | High | Only for testing, not production |

**Release Notes**:
- Check package changelog for breaking changes
- Look for deprecation warnings
- Identify new features that might affect existing code

### 4. Build Status

The workflow doesn't run CI builds on the PR, so:

1. **Wait for CI**: Let the PR build workflow complete
2. **Check for Errors**: Review build logs for compilation issues
3. **Test Locally**: For significant updates, pull the branch and test

### 5. Testing Recommendations

**For Low-Risk Updates** (patch versions):
- Review automated test results
- Spot-check critical functionality

**For Medium-Risk Updates** (minor versions):
- Run full test suite locally
- Test key features affected by updated packages
- Check for deprecation warnings

**For High-Risk Updates** (major versions, prereleases):
- Full regression testing
- Review migration guides
- Test in staging environment
- Consider breaking into smaller PRs

### 6. Merge Guidelines

**Safe to Merge When**:
- ✅ All CI checks pass
- ✅ No unexpected file changes
- ✅ Only patch or minor version updates
- ✅ No breaking changes in release notes
- ✅ Tests pass locally (if tested)

**Requires Caution**:
- ⚠️ Major version updates
- ⚠️ Prerelease versions
- ⚠️ Large number of simultaneous updates
- ⚠️ Build errors or warnings introduced
- ⚠️ Known breaking changes in updated packages

**Should Reject**:
- ❌ Build failures
- ❌ Unexpected file modifications
- ❌ Prerelease versions in production branches
- ❌ Breaking changes without migration plan

## Troubleshooting

### Common Issues

#### 1. Workflow Fails at "Run UpdateThirdPartyPackages script"

**Possible Causes**:
- NuGet.org API unavailable or slow
- Invalid `.csproj` XML structure
- Network connectivity issues

**Solutions**:
```powershell
# Test NuGet API manually
Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/newtonsoft.json/index.json"

# Validate .csproj XML
[xml]$xml = Get-Content "path/to/project.csproj"

# Check for XML errors in script logs
# Look for "Failed to read XML" messages
```

#### 2. Build Failures After Update

**Possible Causes**:
- Breaking changes in updated packages
- Incompatible version combinations
- Missing dependencies

**Solutions**:
```powershell
# Clear NuGet caches
dotnet nuget locals all --clear

# Restore packages
dotnet restore

# Check for binding redirects or compatibility issues
dotnet list package --vulnerable
dotnet list package --deprecated
```

**Revert Specific Package**:
```powershell
# Edit .csproj to revert version
# Then restore and rebuild
dotnet restore
dotnet build
```

#### 3. PR Not Created (No Changes Detected)

**Cause**: All packages already up-to-date

**Expected Behavior**:
```
No changes detected. Skipping commit and PR.
```

**Verification**:
```powershell
# Manually check for updates
./.github/workflows/powershell/UpdateThirdPartyPackages.ps1 -DryRun
```

#### 4. Duplicate PR Skipped Message

**Cause**: Identical updates already exist in an open PR

**Message**:
```
An existing PR (#123) already has identical package updates.
No need to create a duplicate PR.
```

**Resolution**:
- Review existing PR: https://github.com/{owner}/{repo}/pull/123
- If PR is stale, close it to allow new PR creation
- If PR is valid, no action needed

#### 5. Authentication Failure

**Error**:
```
remote: Permission to {owner}/{repo}.git denied
fatal: unable to access: The requested URL returned error: 403
```

**Cause**: `PAT_TOKEN` missing or invalid

**Solution**:
1. Generate new Personal Access Token:
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token (classic)"
   - Scopes: `repo`, `workflow`
   - Generate and copy token

2. Update repository secret:
   - Repository → Settings → Secrets and variables → Actions
   - Update `PAT_TOKEN` secret

#### 6. GitHub CLI Not Found

**Error**:
```
choco : The term 'choco' is not recognized
```

**Cause**: Chocolatey installation failed or not in PATH

**Solution**:
```yaml
# In workflow file, add error handling
- name: Install GitHub CLI
  run: |
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
      Write-Error "Chocolatey not found"
      exit 1
    }
    choco install gh -y
```

#### 7. Large Number of Updates Causes Timeout

**Symptom**: Workflow times out during NuGet API queries

**Solutions**:

**Option 1**: Increase timeout in script
```powershell
# In UpdateThirdPartyPackages.ps1
$resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 60  # Increased from 20
```

**Option 2**: Process in batches
```powershell
# Use -IgnorePatterns to split updates
# First run: Update Microsoft packages
-IgnorePatterns "^(?!Microsoft\.)"

# Second run: Update non-Microsoft packages
-IgnorePatterns "^Microsoft\."
```

#### 8. Prerelease Versions Unexpectedly Included

**Cause**: `includePrerelease` defaults to `true` for scheduled runs

**Verification**:
Check PR body:
```markdown
**IncludePrerelease:** true
```

**Solution**:
```yaml
# In workflow file, change default
-IncludePrereleaseFlag = if ('${{ github.event.inputs.includePrerelease }}' -eq 'false') { $false } else { $true }
# Change to:
-IncludePrereleaseFlag = if ('${{ github.event.inputs.includePrerelease }}' -eq 'true') { $true } else { $false }
```

### Debugging Tips

#### Enable Verbose Logging

**PowerShell Script**:
```powershell
# Add at top of script
$VerbosePreference = 'Continue'
```

**Workflow File**:
```yaml
- name: Run UpdateThirdPartyPackages script
  shell: pwsh
  run: |
    $VerbosePreference = 'Continue'
    ./.github/workflows/powershell/UpdateThirdPartyPackages.ps1 ...
```

#### View Build Logs

**Locations**:
```
.artifacts/logs/{solution}__{timestamp}.build.stdout.txt
.artifacts/logs/{solution}__{timestamp}.build.stderr.txt
```

**Download from Workflow**:
1. Go to failed workflow run
2. Not uploaded as artifacts (only created locally)
3. View logs in workflow output under "Run UpdateThirdPartyPackages script"

#### Test Locally Before Committing

```powershell
# 1. Dry run to preview changes
./.github/workflows/powershell/UpdateThirdPartyPackages.ps1 -DryRun

# 2. Review proposed changes
Get-Content .artifacts/package-summary.txt

# 3. Apply updates
./.github/workflows/powershell/UpdateThirdPartyPackages.ps1

# 4. Test build locally
dotnet clean
dotnet build

# 5. If successful, commit manually
git add .
git commit -m "Update NuGet packages"
git push
```

## Best Practices

### For Maintainers

1. **Monitor Scheduled Runs**
   - Check Actions tab daily
   - Review PRs promptly to avoid accumulation
   - Close stale update PRs before merging newer ones

2. **Configure Filtering Wisely**
   - Add internal packages to `InternalPatterns`
   - Pin critical packages with `IgnorePackages` if needed
   - Use `IgnorePatterns` for package families you manage manually

3. **Set Appropriate Schedule**
   - Default: Daily at 10:30 AM UK time
   - Consider reducing frequency for stable projects
   - Increase frequency during active development

4. **Review Release Notes**
   - Before merging, check changelogs for major updates
   - Look for breaking changes or deprecations
   - Plan migrations for major version updates

5. **Test Critical Updates**
   - Pull PR branch locally for major version updates
   - Run full test suite
   - Deploy to staging environment if available

### For Contributors

1. **Don't Modify Update PRs**
   - Let the bot create clean PRs
   - If changes needed, close PR and modify filters

2. **Coordinate with Scheduled Runs**
   - Avoid manual package updates
   - Let automation handle routine updates
   - Only manual update for urgent security fixes

3. **Report Issues**
   - If builds fail, investigate before merging
   - Open issues for problematic package updates
   - Document any packages that need pinning

### For Reviewers

1. **Quick Review Checklist**
   - ✅ Only `.csproj` files modified
   - ✅ Only `Version` attributes changed
   - ✅ Reasonable version increments (not skipping major versions)
   - ✅ No prerelease versions in stable branches
   - ✅ Build succeeds (after PR CI runs)

2. **Deep Review Triggers**
   - Major version updates
   - Large number of simultaneous updates
   - Packages with known breaking changes
   - Security-critical dependencies

3. **Approval Guidelines**
   - Low-risk updates: Approve quickly
   - Medium-risk: Wait for CI, spot-check release notes
   - High-risk: Request local testing or staging deployment

## Configuration Examples

### Daily Stable Updates Only

```yaml
# .github/workflows/update-packages.yml
on:
  schedule:
    - cron: '30 10 * * *'
  workflow_dispatch:
    inputs:
      includePrerelease:
        default: 'false'  # Changed from 'true'
```

### Weekly Updates Including Prereleases

```yaml
on:
  schedule:
    - cron: '0 9 * * MON'  # Every Monday at 9 AM UTC
  workflow_dispatch:
    inputs:
      includePrerelease:
        default: 'true'
```

### Exclude Specific Packages

```yaml
# Add to script call
-IgnorePackages "Umbraco.Cms.Web.Website","Newtonsoft.Json"
```

### Exclude Package Families

```yaml
# Exclude all Microsoft.Extensions packages
-IgnorePatterns "^Microsoft\.Extensions\."

# Exclude all analyzer packages
-IgnorePatterns "Analyzers$"

# Multiple patterns
-IgnorePatterns "^Microsoft\.Extensions\.", "Analyzers$", "^StyleCop\."
```

### Mark Internal Packages

```yaml
-InternalPackages "Clean.Core","Clean.Headless"
# Or by pattern
-InternalPatterns "^Clean\."
```

## Related Documentation

- [workflow-pr.md](workflow-pr.md) - Pull request build and test automation
- [workflow-versioning-releases.md](workflow-versioning-releases.md) - Release process and versioning strategy
- [general-consuming-packages.md](general-consuming-packages.md) - Using development packages from GitHub Packages

## Summary

The Update NuGet Packages workflow provides:

- ✅ **Automated Dependency Management**: Daily checks keep packages current
- ✅ **README Version Updates**: Automatically updates installation instructions with latest Umbraco versions
- ✅ **Multi-Version Support**: Tracks multiple Umbraco major versions simultaneously (e.g., 13 and 17)
- ✅ **Per-Version Prerelease Control**: Configure stable/prerelease independently for each version (e.g., `13,17-`)
- ✅ **Build Validation**: Ensures updates don't break compilation, with detailed failure reporting
- ✅ **Intelligent Duplicate Detection**: Prevents redundant PRs
- ✅ **Comprehensive Reporting**: Clear summaries of all changes (README + packages)
- ✅ **Smart Commit Messages**: Adds `[skip ci]` for README-only changes to avoid unnecessary builds
- ✅ **Flexible Filtering**: Fine-grained control over which packages update
- ✅ **Prerelease Support**: Option to include or exclude beta/rc versions
- ✅ **Custom NuGet Sources**: Support for testing with pre-release packages from custom feeds
- ✅ **Dry Run Mode**: Test changes without modifying files
- ✅ **Detailed Logging**: Full build output saved for debugging
- ✅ **Local Execution**: Can run manually for testing or urgent updates
- ✅ **Dynamic PR Bodies**: Shows exactly what was updated (README, packages, or both)

This ensures the Clean starter kit stays up-to-date with the latest Umbraco versions and package dependencies while maintaining stability and code quality.
