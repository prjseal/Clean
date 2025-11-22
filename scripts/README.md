# Package Fix Scripts

This directory contains documentation for the Umbraco BlockList label workaround.

## BlockList Label Fix (PowerShell)

**The fix is now implemented directly in PowerShell** within `.github/workflows/powershell/CreateNuGetPackages.ps1`. No external dependencies or manual steps required!

Automates the workaround for the Umbraco BlockList label export bug tracked at [umbraco/Umbraco-CMS#20801](https://github.com/umbraco/Umbraco-CMS/issues/20801).

### Problem

When creating and downloading packages from the Umbraco backoffice, the `package.xml` file doesn't include label configurations for BlockList data types, even though these labels are present in the original system.

### Solution

The PowerShell build script (`CreateNuGetPackages.ps1`) automatically:
1. Downloads package.zip from Umbraco API
2. Extracts the package
3. Reads label data from `template/Clean.Blog/uSync/v17/DataTypes/BlockListMainContent.config`
4. Adds missing labels to the `[BlockList] Main Content` DataType in package.xml
5. Repacks the package.zip
6. Continues with the normal build process

### How It Works

The fix runs automatically during:
- ✅ **PR builds** (before publishing to GitHub Packages)
- ✅ **Release builds** (before publishing to NuGet.org)

No manual intervention needed - just run the build script as normal!

### What Gets Fixed

Adds labels to the `[BlockList] Main Content` DataType for:
- Rich Text blocks
- Image blocks
- Video blocks
- Code Snippet blocks
- Image Carousel blocks
- Article List blocks

### Implementation Details

The fix is implemented as a PowerShell function `Fix-BlockListLabels` in `CreateNuGetPackages.ps1`:
- Parses XML and JSON natively in PowerShell
- Strips markdown formatting from labels
- Unicode-escapes single quotes to match Umbraco format
- HTML-encodes for XML attributes
- No external dependencies required

## Disabling or Removing the Fix

### Quick Disable

To temporarily disable the fix without removing code:

1. Open `.github/workflows/powershell/CreateNuGetPackages.ps1`
2. Change line 13 to: `$FixBlockListLabels = $false`

### Complete Removal

When Umbraco fixes the bug, see [REMOVAL-GUIDE.md](REMOVAL-GUIDE.md) for complete removal instructions.

## Why This is Temporary

This is a workaround for a known Umbraco bug: [umbraco/Umbraco-CMS#20801](https://github.com/umbraco/Umbraco-CMS/issues/20801)

Once Umbraco releases a fix, this entire workaround can be removed. All code sections are clearly marked with comments:
- `TEMPORARY WORKAROUND - Remove when Umbraco fixes issue #20801`

## Legacy Python Scripts

The `fix-package-blocklist-labels.py` and `test_fix_script.py` files are kept for reference but are no longer used. The fix is now fully implemented in PowerShell for better integration with the existing build process.
