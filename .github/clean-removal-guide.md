# How to Remove the BlockList Label Workaround

When Umbraco fixes issue [#20801](https://github.com/umbraco/Umbraco-CMS/issues/20801), follow these steps to remove the workaround:

## Quick Disable (for testing)

To quickly test without the fix:

1. Open `.github/workflows/powershell/CreateNuGetPackages.ps1`
2. Change line 13 from:
   ```powershell
   $FixBlockListLabels = $true
   ```
   to:
   ```powershell
   $FixBlockListLabels = $false
   ```

## Complete Removal

### Step 1: Remove from PowerShell Script

**File:** `.github/workflows/powershell/CreateNuGetPackages.ps1`

**Delete lines 6-97** (feature flag and function):
```powershell
# ============================================================================
# TEMPORARY WORKAROUND - Remove when Umbraco fixes issue #20801
# https://github.com/umbraco/Umbraco-CMS/issues/20801
#
# Set to $false to disable the BlockList label fix
# Delete this entire section when Umbraco releases a fix
# ============================================================================
$FixBlockListLabels = $true

function Fix-BlockListLabels {
    # ... [entire function] ...
}
# ============================================================================
```

**Delete the workaround block** (search for "BEGIN TEMPORARY WORKAROUND"):
```powershell
# ========================================================================
# BEGIN TEMPORARY WORKAROUND - Umbraco issue #20801
# Remove this entire block when Umbraco fixes BlockList label export
# ========================================================================
if ($FixBlockListLabels) {
    # ... [entire block] ...
}
# ========================================================================
# END TEMPORARY WORKAROUND
# ========================================================================
```

### Step 2: Optional - Remove Scripts Directory

If you want to completely clean up:

```bash
# Remove the entire scripts directory (optional)
rm -rf scripts/
```

Or keep the directory for future use and just remove the workaround files:
```bash
rm scripts/fix-package-blocklist-labels.py
rm scripts/test_fix_script.py
rm scripts/REMOVAL-GUIDE.md
rm scripts/README.md
```

## Verification

After removal, test that packages still build correctly:

1. Run the package build:
   ```powershell
   ./.github/workflows/powershell/CreateNuGetPackages.ps1 -Version "7.0.0-test.1"
   ```

2. Verify the package downloads successfully
3. Check that Umbraco now includes labels in the exported package.xml

## Tracking the Umbraco Fix

Monitor the Umbraco CMS repository for fixes:
- Issue: https://github.com/umbraco/Umbraco-CMS/issues/20801
- Watch for releases that mention BlockList label fixes
- Check release notes for Umbraco CMS updates

## Need Help?

If you're unsure whether Umbraco has fixed the issue:

1. Download a fresh package from Umbraco backoffice
2. Extract and inspect `package.xml`
3. Look for the `[BlockList] Main Content` DataType
4. Check if the `blocks` array contains `"label"` properties

If labels are present, the bug is fixed and you can safely remove this workaround!
