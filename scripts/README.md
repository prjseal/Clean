# Package Fix Scripts

This directory contains scripts to automate workarounds for known Umbraco issues.

## fix-package-blocklist-labels.py

Automates the workaround for the Umbraco BlockList label export bug tracked at [umbraco/Umbraco-CMS#20801](https://github.com/umbraco/Umbraco-CMS/issues/20801).

### Problem

When creating and downloading packages from the Umbraco backoffice, the `package.xml` file doesn't include label configurations for BlockList data types, even though these labels are present in the original system.

### Solution

This script automatically:
1. Extracts the downloaded package.zip
2. Reads the correct label data from the uSync configuration file
3. Adds the missing labels to the package.xml
4. Repacks the package.zip
5. Copies it to the migrations folder for deployment

### Usage

1. Download the package.zip from Umbraco backoffice
2. Place it in the repository root directory
3. Run the script:

```bash
python3 scripts/fix-package-blocklist-labels.py
```

Or specify a custom path:

```bash
python3 scripts/fix-package-blocklist-labels.py /path/to/package.zip
```

### What It Does

The script reads label templates from:
- `template/Clean.Blog/uSync/v17/DataTypes/BlockListMainContent.config`

And updates the `[BlockList] Main Content` DataType in package.xml to include labels for:
- Rich Text blocks
- Image blocks
- Video blocks
- Code Snippet blocks
- Image Carousel blocks
- Article List blocks

### Output

The script will:
- Modify the package.zip in place with the corrected labels
- Copy the fixed package.zip to `template/Clean/Migrations/package.zip`
- The migrations package is then ready for the dotnet pack process

### Example

```bash
$ python3 scripts/fix-package-blocklist-labels.py
Extracting /home/user/Clean/package.zip...
Reading labels from template/Clean.Blog/uSync/v17/DataTypes/BlockListMainContent.config...
Found 6 block labels
Modifying package.xml...
✓ Added 6 labels to [BlockList] Main Content
Repacking package.zip...
Replacing original package.zip...
Copying to template/Clean/Migrations/package.zip...

✓ Package processing complete!
  - Modified package.zip with labels
  - Copied to template/Clean/Migrations/package.zip
```

### Requirements

- Python 3.6 or higher (uses standard library only)
