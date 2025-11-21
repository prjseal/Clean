# Versioning Strategy and Release Process

This document describes the versioning strategy for Clean NuGet packages and how to perform releases.

## Table of Contents

- [Overview](#overview)
- [Versioning Strategy](#versioning-strategy)
- [Package Feeds](#package-feeds)
- [Creating Releases](#creating-releases)
- [Version Mapping](#version-mapping)
- [Workflows](#workflows)
- [Troubleshooting](#troubleshooting)

## Overview

The Clean project uses **Semantic Versioning 2.0** with different version formats for development builds and official releases:

- **Development/CI Builds**: Automatically published to **GitHub Packages** with `-ci` suffix
- **Official Releases**: Manually published to **NuGet.org** via GitHub Releases

## Versioning Strategy

### Version Format

We follow [Semantic Versioning 2.0](https://semver.org/):

```
MAJOR.MINOR.PATCH[-PRERELEASE]
```

- **MAJOR**: Incompatible API changes
- **MINOR**: Backward-compatible functionality additions
- **PATCH**: Backward-compatible bug fixes
- **PRERELEASE**: Optional pre-release identifier (e.g., `alpha`, `beta`, `rc`, `ci`)

### Version Types

| Type | Format | Example | When to Use |
|------|--------|---------|-------------|
| **CI Build** | `X.Y.Z-ci.N` | `7.0.0-ci.123` | Automatic on every PR |
| **Stable Release** | `X.Y.Z` | `7.0.0` | Production-ready release |
| **Release Candidate** | `X.Y.Z-rc.N` | `7.0.0-rc.1` | Near-final testing |
| **Beta** | `X.Y.Z-beta.N` | `7.0.0-beta.1` | Feature-complete testing |
| **Alpha** | `X.Y.Z-alpha.N` | `7.0.0-alpha.1` | Early testing |

### Version Precedence

NuGet follows SemVer 2.0 precedence rules:

```
1.0.0-alpha.1 < 1.0.0-beta.1 < 1.0.0-rc.1 < 1.0.0 < 1.0.1-ci.1
```

**Important**: CI builds (`-ci.N`) sort **after** stable releases, ensuring they don't interfere with production package resolution.

## Package Feeds

### GitHub Packages (Development)

**URL**: `https://nuget.pkg.github.com/prjseal/index.json`

**Purpose**:
- PR/CI builds
- Internal testing
- Development workflows

**Authentication**: Requires GitHub PAT with `read:packages` scope

**Automatic Publishing**:
- Every PR to `main` branch
- Version format: `{latest-stable}-ci.{build-number}`
- Example: `7.0.0-ci.123`

See [CONSUMING-GITHUB-PACKAGES.md](CONSUMING-GITHUB-PACKAGES.md) for consumption details.

### NuGet.org (Production)

**URL**: `https://api.nuget.org/v3/index.json`

**Purpose**:
- Official releases
- Public distribution
- Production use

**Authentication**: Requires NuGet API key

**Manual Publishing**:
- Triggered by creating a GitHub Release
- Version from release tag
- Example: `v7.0.0` → `7.0.0`

## Creating Releases

### Prerequisites

1. **NuGet API Key Setup** (One-time)

   a. Create API key:
   - Visit https://www.nuget.org/account/apikeys
   - Click "Create"
   - Key name: `Clean-GitHub-Actions`
   - Glob pattern: `Clean.*` and `Umbraco.Community.Templates.Clean`
   - Select "Push" and "Push new packages and package versions"
   - Click "Create"
   - Copy the API key (shown once only)

   b. Add to GitHub Secrets:
   - Go to repository **Settings**
   - Navigate to **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `NUGET_API_KEY`
   - Value: Paste your NuGet API key
   - Click **Add secret**

2. **Version Decision**

   Determine the next version based on changes:
   - Breaking changes → Increment MAJOR (e.g., `7.0.0` → `8.0.0`)
   - New features → Increment MINOR (e.g., `7.0.0` → `7.1.0`)
   - Bug fixes → Increment PATCH (e.g., `7.0.0` → `7.0.1`)

### Release Process

#### Option 1: Using GitHub UI

1. **Navigate to Releases**
   - Go to https://github.com/prjseal/Clean/releases
   - Click **Draft a new release**

2. **Create Tag and Release**
   - Click **Choose a tag**
   - Type new tag: `v7.0.0` (include `v` prefix)
   - Click **Create new tag on publish**
   - Target: `main` branch

3. **Fill Release Details**
   - Release title: `Version 7.0.0`
   - Description: Add release notes with changes, fixes, features
   - Check **Set as a pre-release** if applicable (for `-rc`, `-beta`, `-alpha` versions)

4. **Publish**
   - Click **Publish release**
   - Workflow automatically starts

5. **Monitor Workflow**
   - Go to **Actions** tab
   - Watch "Release - Publish to NuGet.org" workflow
   - Verify all steps complete successfully

#### Option 2: Using GitHub CLI

1. **Install GitHub CLI** (if not already installed)
   ```bash
   # Windows
   winget install --id GitHub.cli

   # Or download from https://cli.github.com/
   ```

2. **Authenticate**
   ```bash
   gh auth login
   ```

3. **Create Stable Release**
   ```bash
   gh release create v7.0.0 \
     --title "Version 7.0.0" \
     --notes "## Changes

   - Added new feature X
   - Fixed bug Y
   - Updated dependencies

   ## Breaking Changes
   - Changed API Z

   ## Migration Guide
   - Update code from X to Y"
   ```

4. **Create Pre-release**
   ```bash
   gh release create v7.1.0-rc.1 \
     --title "Version 7.1.0 RC1" \
     --notes "Release candidate for 7.1.0" \
     --prerelease
   ```

5. **Verify Publishing**
   ```bash
   # Check workflow status
   gh run list --workflow=release-nuget.yml

   # View workflow logs
   gh run view --log
   ```

### What Happens During Release

When you publish a release, the `release-nuget.yml` workflow:

1. **Validates** the version tag format
2. **Checks out** the code
3. **Extracts** version from tag (removes `v` prefix)
4. **Updates** all `.csproj` files with the version
5. **Builds** all packages in dependency order:
   - Clean.Core
   - Clean.Headless
   - Clean (depends on Core and Headless)
   - Umbraco.Community.Templates.Clean
6. **Publishes** to NuGet.org
7. **Uploads** `.nupkg` files to GitHub Release assets
8. **Commits** version updates to `main` branch (automatically, without triggering other workflows)
9. **Reports** success or failure

> **Note**: The version updates are automatically committed back to the `main` branch after a successful release. This ensures that anyone cloning the repository will see the latest released versions in the `.csproj` files. This commit does not trigger any workflows, preventing circular pipeline runs.

### Post-Release Verification

1. **Check NuGet.org**
   - Visit https://www.nuget.org/packages/Clean
   - Verify new version appears (may take 5-10 minutes to index)

2. **Check Package Details**
   ```bash
   # Using .NET CLI
   dotnet nuget list source
   dotnet tool install --global dotnet-search
   dotnet search Clean --exact-match
   ```

3. **Test Installation**
   ```bash
   # Create test project
   dotnet new umbraco -n TestProject

   # Install your package
   dotnet add package Clean --version 7.0.0

   # Verify installation
   dotnet list package
   ```

## Version Mapping

The Clean packages maintain version alignment with Umbraco CMS:

| Clean Version | Umbraco Version | Support Type | .NET Version |
|---------------|-----------------|--------------|--------------|
| 4.x.x | 13.x | LTS | .NET 8 |
| 5.x.x | 15.x | STS | .NET 9 |
| 6.x.x | 16.x | STS | .NET 9 |
| 7.x.x | 17.x | LTS | .NET 10 |

**Versioning Guidelines**:
- Major version changes when targeting new Umbraco major version
- Minor/Patch versions for features and fixes within the same Umbraco version
- Pre-release versions during Umbraco preview/RC periods

## Workflows

### PR Build Workflow (`.github/workflows/pr-build-packages.yml`)

**Trigger**: Pull request to `main` branch

**Process**:
1. Query NuGet.org for latest stable version
2. Append `-ci.{build-number}` to create build version
3. Run `CreateNuGetPackages.ps1` with version
4. Publish to GitHub Packages
5. Upload artifacts

**Example Versions**:
- Latest on NuGet.org: `7.0.0`
- PR #45, Build #123: `7.0.0-ci.123`
- PR #46, Build #124: `7.0.0-ci.124`

**When to Use**:
- Testing changes before merging
- Validating package build process
- Sharing pre-merge packages with team

### Release Workflow (`.github/workflows/release-nuget.yml`)

**Trigger**: GitHub Release published

**Process**:
1. Extract version from release tag
2. Validate version format
3. Build packages with release version
4. Publish to NuGet.org (requires `NUGET_API_KEY`)
5. Upload to release assets
6. Commit version updates to `main` branch (with `[skip ci]` to prevent triggering workflows)
7. Generate summary

**Example**:
- Release tag: `v7.0.0`
- Package version: `7.0.0`
- Feed: NuGet.org

**When to Use**:
- Official releases
- Public distribution
- Production deployments

**Important Notes**:
- Version changes are automatically committed directly to `main` after successful release
- The commit message includes `[skip ci]` to prevent triggering other workflows
- Uses `github-actions[bot]` as the commit author
- This ensures developers cloning the repo see the latest released versions

## Troubleshooting

### Release Workflow Fails with "NUGET_API_KEY secret is not set"

**Problem**: The NuGet API key is missing from GitHub secrets.

**Solution**:
1. Create API key at https://www.nuget.org/account/apikeys
2. Add to GitHub: Settings → Secrets → Actions → New secret
3. Name: `NUGET_API_KEY`
4. Re-run the failed workflow

### Package Already Exists on NuGet.org

**Problem**: Trying to publish a version that already exists.

**Solution**:
- NuGet.org doesn't allow overwriting versions
- Delete the GitHub Release
- Create a new release with the next patch version
- Example: If `7.0.0` exists, use `7.0.1`

### Version Tag Format Invalid

**Problem**: Workflow fails with "Invalid version format" error.

**Error Example**:
```
Invalid version format: 7.0.0.1. Expected format: X.Y.Z or X.Y.Z-prerelease
```

**Solution**:
Use semantic versioning format:
- ✅ `v7.0.0`
- ✅ `v7.0.0-rc.1`
- ❌ `v7.0.0.1` (4 segments not allowed)
- ❌ `7.0.0_rc1` (use hyphen, not underscore)

### Packages Not Appearing on NuGet.org

**Problem**: Workflow succeeded but packages don't show on NuGet.org.

**Possible Causes**:
1. **Indexing Delay**: Wait 5-10 minutes for NuGet to index
2. **Package ID Ownership**: Ensure you own the package ID on NuGet.org
3. **API Key Permissions**: Verify API key has push permissions for the package ID pattern

**Solution**:
```bash
# Check package status
curl https://api.nuget.org/v3-flatcontainer/clean/index.json

# If not listed after 15 minutes, check workflow logs
gh run view --log
```

### CI Build Version Conflicts

**Problem**: Multiple PRs create packages with same version.

**Example**:
- PR #45 and PR #46 both use `7.0.0-ci.123`

**Why This Happens**:
- Both PRs triggered at similar times
- Both query NuGet.org and get same base version
- Build numbers might overlap if re-run

**Solution**:
- This is expected behavior
- `--skip-duplicate` flag prevents errors
- GitHub Packages shows latest
- Use specific artifact from Actions tab if needed

### Dependency Version Mismatches

**Problem**: `Clean` package can't find correct version of `Clean.Core`.

**Cause**: Packages built separately with different versions.

**Solution**:
The `CreateNuGetPackages.ps1` script handles this by:
1. Building packages in dependency order
2. Updating all internal package references to match version
3. Using local NuGet source during build

If issues persist:
```powershell
# Clear NuGet caches
dotnet nuget locals all --clear

# Re-run package creation
./CreateNuGetPackages.ps1 -Version "7.0.0"
```

### Pre-release Not Showing in NuGet Package Manager

**Problem**: Published `7.0.0-rc.1` but can't find it in Visual Studio.

**Solution**:
Pre-release packages require "Include prerelease" checkbox:
- Visual Studio: Check "Include prerelease"
- CLI: Use `--prerelease` flag
  ```bash
  dotnet add package Clean --version 7.0.0-rc.1
  # Or
  dotnet add package Clean --prerelease
  ```

## Best Practices

### Versioning

1. **Use Git Tags Consistently**
   - Always prefix with `v` (e.g., `v7.0.0`)
   - Tag the correct commit (usually main branch HEAD)

2. **Write Meaningful Release Notes**
   - List all changes, features, and fixes
   - Include breaking changes section
   - Provide migration guidance if needed

3. **Test Before Releasing**
   - Review PR build packages from GitHub Packages
   - Validate in test environment
   - Ensure all tests pass

4. **Version Alignment**
   - Keep Clean version aligned with Umbraco major version
   - Example: Clean 7.x for Umbraco 17.x

### Release Timing

1. **Stable Releases**
   - After thorough testing
   - When Umbraco stable version is released
   - When breaking changes are finalized

2. **Pre-releases**
   - During Umbraco RC/preview periods
   - For beta testing new features
   - When gathering community feedback

3. **Patch Releases**
   - For critical bug fixes
   - For security updates
   - For dependency updates

### Communication

1. **Announce Releases**
   - Update README.md with latest version
   - Post to community forums/Discord
   - Update documentation

2. **Document Breaking Changes**
   - Create migration guides
   - Provide code examples
   - List deprecated features

## Quick Reference

### Common Commands

```bash
# Create stable release
gh release create v7.0.0 --title "Version 7.0.0" --notes "Release notes..."

# Create pre-release
gh release create v7.1.0-rc.1 --title "7.1.0 RC1" --notes "..." --prerelease

# List releases
gh release list

# Delete release (if needed)
gh release delete v7.0.0 --yes

# View workflow runs
gh run list --workflow=release-nuget.yml

# Watch workflow execution
gh run watch

# Test package locally
./CreateNuGetPackages.ps1 -Version "7.0.0-test.1"
```

### Version Examples

```
# Stable releases
v7.0.0
v7.1.0
v7.0.1

# Pre-releases
v7.0.0-alpha.1
v7.0.0-beta.1
v7.0.0-rc.1
v7.1.0-rc.2

# CI builds (automatic)
7.0.0-ci.123
7.0.0-ci.124
```

## Additional Resources

- [Semantic Versioning 2.0](https://semver.org/)
- [NuGet Package Versioning](https://docs.microsoft.com/en-us/nuget/concepts/package-versioning)
- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Consuming GitHub Packages](CONSUMING-GITHUB-PACKAGES.md)
- [Umbraco Version Support](https://umbraco.com/products/knowledge-center/long-term-support-and-end-of-life/)
