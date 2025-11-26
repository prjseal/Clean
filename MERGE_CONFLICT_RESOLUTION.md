# Merge Conflict Resolution for PR #169

## Overview
PR #169 (Move documentation) has a merge conflict in `README.md` that needs to be resolved before it can be merged into main.

## Conflict Analysis

### Conflict Location 1: Version Support Statement (lines 22-32)
**Main branch:**
```markdown
Clean targets **Umbraco 17 (LTS)**. For complete version mapping for previous versions, see the [Versioning and Releases](.github/VERSIONING-AND-RELEASES.md#version-mapping) documentation.

For detailed information about the package architecture and the different NuGet packages, see the [Package Architecture](.github/PACKAGES.md) documentation.
```

**PR branch:**
```markdown
Clean supports **Umbraco 13 (LTS)** and **Umbraco 17 (LTS)**. For complete version mapping and support information, see the [Versioning and Releases](.github/VERSIONING-AND-RELEASES.md#version-mapping) documentation.

## Documentation

For detailed documentation about this package and the repository, please see the [docs](.github/DOCUMENTATION.md).
```

### Conflict Location 2: Documentation Section Position (lines 159-167)
**Main branch:** Has a duplicate "## Documentation" section later in the file linking to `DOCUMENTATION.md`
**PR branch:** Removes this duplicate section (documentation already appears earlier)

## Resolution Applied

### Issue 1: Version Support Statement
**Resolution:** Use main branch version ✓
```markdown
Clean targets **Umbraco 17 (LTS)**. For complete version mapping for previous versions, see the [Versioning and Releases](.github/VERSIONING-AND-RELEASES.md#version-mapping) documentation.

For detailed information about the package architecture and the different NuGet packages, see the [Package Architecture](.github/PACKAGES.md) documentation.
```

### Issue 2: Documentation Section Position
**Resolution:** Use PR branch approach (early position) ✓
```markdown
## Documentation

For detailed documentation about this package and the repository, please see the [docs](.github/DOCUMENTATION.md).
```

### Final Result
The resolved README.md has:
1. Main branch's version text ("targets Umbraco 17") + package architecture reference
2. Documentation section positioned early (after version info, before Installation)
3. Documentation link correctly pointing to `.github/DOCUMENTATION.md`
4. No duplicate documentation section later in the file

## How to Apply This Resolution

### Option 1: Merge main into PR branch
```bash
git checkout claude/move-documentation-01TY1ZQ7GsG8gF6HsAi8Ywg9
git merge origin/main
# Resolve conflicts as described above
git add README.md
git commit -m "Merge main branch to resolve conflicts"
git push
```

### Option 2: Apply the resolved content manually
Replace lines 22-32 in the conflicted README.md with:
```markdown
Clean targets **Umbraco 17 (LTS)**. For complete version mapping for previous versions, see the [Versioning and Releases](.github/VERSIONING-AND-RELEASES.md#version-mapping) documentation.

For detailed information about the package architecture and the different NuGet packages, see the [Package Architecture](.github/PACKAGES.md) documentation.

## Documentation

For detailed documentation about this package and the repository, please see the [docs](.github/DOCUMENTATION.md).
```

And remove the duplicate documentation section later in the file (around lines 159-167).

## Status
✅ Conflict identified and analyzed
✅ Resolution determined and tested
✅ Documentation created
⚠️ Waiting for push permission to PR branch or manual application
