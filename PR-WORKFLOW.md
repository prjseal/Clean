# Pull Request Workflow Documentation

This document describes the automated PR workflow for the Clean Umbraco starter kit, including build, testing, and package publication processes.

## Overview

The PR workflow automatically builds, tests, and publishes development packages to GitHub Packages whenever a pull request is opened or updated against the `main` branch. This ensures that all changes are validated before merging and provides immediate access to pre-release packages for testing.

## Workflow File

Location: `.github/workflows/pr-build-packages.yml`

## When Does It Run?

The workflow triggers automatically on:
- **Pull Request opened** to the `main` branch
- **Pull Request updated** (new commits pushed)
- **Pull Request synchronized** (rebased or updated)

## What It Does

The PR workflow performs the following operations:

### 1. **Automatic Version Management**

The workflow queries NuGet.org to determine the next appropriate version number:

```
Latest stable version: 7.0.0
Next PR build version: 7.0.1-ci.{build-number}

Latest prerelease version: 7.1.0-rc.1
Next PR build version: 7.1.0-ci.{build-number}
```

**Version Format**: `{base-version}-ci.{build-number}`

**Examples**:
- If latest is `7.0.0` (stable), PR build #42 creates `7.0.1-ci.42`
- If latest is `7.1.0-rc.1` (prerelease), PR build #42 creates `7.1.0-ci.42`

This ensures PR builds always have unique, sortable version numbers that won't conflict with official releases.

### 2. **Package Building**

The workflow builds **four NuGet packages**:

| Package | Description |
|---------|-------------|
| `Clean` | Main package with Umbraco starter content, views, and assets |
| `Clean.Core` | Core library with models and services |
| `Clean.Headless` | API controllers for headless CMS functionality |
| `Umbraco.Community.Templates.Clean` | dotnet CLI template for `dotnet new` |

**Build Command**:
```powershell
./CreateNuGetPackages.ps1 -Version "7.0.1-ci.42"
```

### 3. **Publishing to GitHub Packages**

All packages are automatically published to **GitHub Packages** (not NuGet.org), making them available for:
- Testing before official release
- Installing in test environments
- Validating changes in real projects

**Package Feed URL**: `https://nuget.pkg.github.com/{owner}/index.json`

See [CONSUMING-GITHUB-PACKAGES.md](CONSUMING-GITHUB-PACKAGES.md) for installation instructions.

### 4. **Comprehensive Automated Testing**

The workflow performs **two complete end-to-end tests**:

#### Test 1: Package Installation Testing

1. Creates a fresh Umbraco project using official templates
2. Installs the Clean package from GitHub Packages
3. Starts the Umbraco site
4. Uses Playwright to:
   - Navigate the home page
   - Discover and visit up to 10 internal links
   - Test the Umbraco login page
   - Capture full-page screenshots of each page

**Location**: `test-installation/` directory
**Screenshots**: Uploaded as workflow artifacts

#### Test 2: Template Installation Testing

1. Installs the Clean dotnet template from GitHub Packages
2. Creates a project using `dotnet new umbraco-starter-clean`
3. Starts the site created from the template
4. Uses Playwright to:
   - Navigate the home page
   - Discover and visit up to 10 internal links
   - Test the Umbraco login page
   - Capture full-page screenshots of each page

**Location**: `test-template/` directory
**Screenshots**: Uploaded as workflow artifacts

### 5. **Artifacts**

The workflow uploads the following artifacts for every PR:

| Artifact | Description | Naming Pattern |
|----------|-------------|----------------|
| NuGet Packages | All four `.nupkg` files | `nuget-packages-{version}` |
| Package Test Screenshots | Screenshots from package installation test | `package-test-screenshots-{version}` |
| Template Test Screenshots | Screenshots from template installation test | `template-screenshots-{version}` |

**Access**: Available in the "Actions" tab of the PR for download and review.

## Workflow Steps

Here's the complete sequence:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Checkout Repository                                       │
│    - Fetches full git history for versioning                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Setup .NET 10                                             │
│    - Installs .NET 10 SDK for building                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Get Latest NuGet Version & Create Build Version          │
│    - Queries NuGet.org API for latest "Clean" version       │
│    - Parses semantic versioning                              │
│    - Creates CI version: {base}-ci.{build-number}           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Display Version Info                                      │
│    - Shows base version, build number, and full version     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Run CreateNuGetPackages Script                           │
│    - Builds all 4 packages with CI version number            │
│    - Outputs to .artifacts/nuget/ directory                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Upload NuGet Packages as Artifacts                        │
│    - Makes packages downloadable from Actions tab           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. Publish to GitHub Packages                                │
│    - Adds GitHub Packages as NuGet source                    │
│    - Pushes each package to feed                             │
│    - Uses GITHUB_TOKEN for authentication                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. Test Package Installation                                 │
│    - Configures GitHub Packages source                       │
│    - Creates fresh Umbraco project                           │
│    - Installs Clean package from GitHub Packages            │
│    - Starts site and waits for ready (max 180s)             │
│    - Installs Playwright and Chromium                        │
│    - Runs automated browser tests                            │
│    - Takes screenshots of 10+ pages                          │
│    - Stops site and cleans up                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 9. Upload Package Test Screenshots                           │
│    - Uploads all screenshots as workflow artifact           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 10. Test Template Installation                               │
│     - Configures GitHub Packages source                      │
│     - Installs Clean template from GitHub Packages          │
│     - Creates project: dotnet new umbraco-starter-clean     │
│     - Starts site and waits for ready (max 180s)            │
│     - Installs Playwright and Chromium                       │
│     - Runs automated browser tests                           │
│     - Takes screenshots of 10+ pages                         │
│     - Stops site and cleans up                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 11. Upload Template Test Screenshots                         │
│     - Uploads all screenshots as workflow artifact          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 12. Build Summary                                            │
│     - Displays version, PR number, branch, and packages     │
│     - Shows link to GitHub Packages                          │
└─────────────────────────────────────────────────────────────┘
```

## Technical Details

### Environment

- **OS**: Windows (windows-latest)
- **.NET Version**: 10.0.x
- **Node.js**: Latest LTS (for Playwright)
- **Browser**: Chromium (via Playwright)

### Timeouts

- **Site Startup**: 180 seconds maximum
- **Page Navigation**: 30 seconds per page
- **Full Workflow**: ~10-15 minutes typical

### Authentication

- **GitHub Packages**: Uses `GITHUB_TOKEN` secret (automatically provided by GitHub Actions)
- **NuGet.org**: Not used in PR workflow (only release workflow)

### Version Sorting Logic

The workflow uses sophisticated version parsing to handle both stable and prerelease versions:

1. Fetches all versions from NuGet.org
2. Parses each version into `{base-version}` + `{prerelease-suffix}`
3. Sorts by version number (descending), then by prerelease status
4. If latest is **stable**: increments patch version for CI builds
5. If latest is **prerelease**: uses base version without suffix for CI builds

**Example 1 - Latest is Stable**:
```
Latest: 7.0.0
CI Build: 7.0.1-ci.42
```

**Example 2 - Latest is Prerelease**:
```
Latest: 7.1.0-rc.1
CI Build: 7.1.0-ci.42
```

This ensures CI builds always sort correctly between stable releases and official prereleases.

## Using PR Build Packages

To install packages from a PR build:

1. **Configure GitHub Packages source**:
   ```bash
   dotnet nuget add source https://nuget.pkg.github.com/OWNER/index.json \
     --name GitHubPackages \
     --username YOUR_GITHUB_USERNAME \
     --password YOUR_GITHUB_PAT \
     --store-password-in-clear-text
   ```

2. **Install the package**:
   ```bash
   dotnet add package Clean --version 7.0.1-ci.42 --source GitHubPackages
   ```

3. **Or install the template**:
   ```bash
   dotnet new install Umbraco.Community.Templates.Clean::7.0.1-ci.42 \
     --nuget-source https://nuget.pkg.github.com/OWNER/index.json
   ```

See [CONSUMING-GITHUB-PACKAGES.md](CONSUMING-GITHUB-PACKAGES.md) for detailed instructions.

## Reviewing PR Builds

When reviewing a PR, check:

1. **Build Status**: Green checkmark means all tests passed
2. **Version Number**: Should follow expected pattern
3. **Artifacts**: Download and inspect screenshots to verify rendering
4. **Packages**: Available at `https://github.com/{owner}/{repo}/packages`

### Accessing Artifacts

1. Go to the PR in GitHub
2. Click the "Checks" tab
3. Click on the workflow run
4. Scroll to "Artifacts" section
5. Download:
   - `nuget-packages-{version}` - The actual .nupkg files
   - `package-test-screenshots-{version}` - Package test screenshots
   - `template-screenshots-{version}` - Template test screenshots

## Troubleshooting

### Common Issues

**Version API Failure**:
- If NuGet.org API is unavailable, workflow defaults to `1.0.0-ci.{build}`
- Check workflow logs for "Error fetching version from NuGet"

**Site Startup Timeout**:
- Site has 180 seconds to start
- Check `site.log` and `site.err` files in test directories
- May indicate database migration or configuration issues

**Playwright Test Failures**:
- Check uploaded screenshots for rendering issues
- Look for 404s or broken pages
- Verify navigation structure hasn't broken

**GitHub Packages Push Failures**:
- Usually authentication issues
- Requires `GITHUB_TOKEN` with package write permissions
- May occur if duplicate version already exists (uses `--skip-duplicate`)

### Logs and Debugging

The workflow provides detailed colored output:
- **Cyan**: Section headers
- **Yellow**: In-progress operations
- **Green**: Success messages
- **Red**: Error messages

Each major step displays:
- Version information
- Package names and counts
- Site URLs
- Test progress
- Screenshot saves

## Related Documentation

- [VERSIONING-AND-RELEASES.md](VERSIONING-AND-RELEASES.md) - Release process and version strategy
- [CONSUMING-GITHUB-PACKAGES.md](CONSUMING-GITHUB-PACKAGES.md) - How to consume development packages
- [README.md](README.md) - Project overview and installation

## Differences from Release Workflow

| Feature | PR Workflow | Release Workflow |
|---------|-------------|------------------|
| **Trigger** | Pull requests to main | GitHub Release published |
| **Version Format** | `{version}-ci.{build}` | `{version}` (from git tag) |
| **Publish Target** | GitHub Packages | NuGet.org |
| **Testing** | Full E2E with screenshots | None (pre-tested in PR) |
| **Documentation Updates** | None | Updates README files |
| **Commit Back** | No | Yes (version updates) |

## Best Practices

### For Contributors

1. **Wait for Green**: Ensure workflow passes before requesting review
2. **Check Screenshots**: Review artifacts to verify visual rendering
3. **Test Locally**: Install PR packages to validate in real scenarios
4. **Breaking Changes**: Document any breaking changes that affect package consumers

### For Reviewers

1. **Review Artifacts**: Download and inspect screenshots
2. **Check Version**: Verify version number is appropriate
3. **Test Package**: Consider installing the PR package to test functionality
4. **Validate Tests**: Ensure new features are covered by the automated tests

### For Maintainers

1. **Monitor Workflow**: Keep an eye on build times and success rates
2. **Update Dependencies**: Regularly update Playwright and .NET SDK versions
3. **Expand Tests**: Add more page coverage as the site grows
4. **Clean Up Packages**: Periodically clean old CI packages from GitHub Packages

## Summary

The PR workflow provides:
- ✅ Automatic versioning for every PR build
- ✅ Immediate access to test packages via GitHub Packages
- ✅ Comprehensive end-to-end testing with browser automation
- ✅ Visual validation through automated screenshots
- ✅ Both package and template installation testing
- ✅ Clear, colored logging for easy debugging
- ✅ Artifact preservation for reviewer inspection

This ensures high quality and prevents regressions before code reaches production.
