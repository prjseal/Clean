#!/usr/bin/env python3
"""
Automate the workaround for Umbraco BlockList label export bug.
https://github.com/umbraco/Umbraco-CMS/issues/20801

This script:
1. Extracts package.zip
2. Reads label data from uSync config file
3. Adds missing labels to package.xml DataType configuration
4. Rezips the package
5. Moves it to the migrations folder
"""

import json
import xml.etree.ElementTree as ET
import zipfile
import os
import shutil
import sys
import re
from pathlib import Path
import html


def strip_markdown_bold(text):
    """Remove markdown bold markers (**) from text."""
    return text.replace('**', '')


def extract_labels_from_usync(usync_file_path):
    """Extract label mappings from uSync config file."""
    tree = ET.parse(usync_file_path)
    root = tree.getroot()

    # Find the Config element containing the CDATA
    config_elem = root.find('.//Config')
    if config_elem is None:
        raise ValueError("Could not find Config element in uSync file")

    # Parse the JSON from CDATA
    config_json = json.loads(config_elem.text.strip())

    # Create a mapping of contentElementTypeKey -> label
    label_map = {}
    for block in config_json.get('blocks', []):
        content_key = block.get('contentElementTypeKey')
        label = block.get('label', '')
        if content_key and label:
            # Strip markdown formatting from labels
            label = strip_markdown_bold(label)
            label_map[content_key] = label

    return label_map


def fix_package_xml(package_xml_path, label_map):
    """Add missing labels to the [BlockList] Main Content DataType."""
    # Read the XML file
    with open(package_xml_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the DataType with Name="[BlockList] Main Content"
    # We need to extract and modify the Configuration attribute
    pattern = r'(<DataType Name="\[BlockList\] Main Content"[^>]*Configuration=")([^"]+)(")'

    def replace_config(match):
        prefix = match.group(1)
        config_encoded = match.group(2)
        suffix = match.group(3)

        # Decode HTML entities
        config_json_str = html.unescape(config_encoded)

        # Parse the JSON
        config = json.loads(config_json_str)

        # Add labels to each block
        for block in config.get('blocks', []):
            content_key = block.get('contentElementTypeKey')
            if content_key in label_map:
                # Add the label property
                block['label'] = label_map[content_key]

        # Convert back to JSON string
        modified_json = json.dumps(config, separators=(',', ':'))

        # Unicode-escape single quotes to match Umbraco format
        modified_json = modified_json.replace("'", r'\u0027')

        # Encode back to HTML entities (matching the original encoding style)
        modified_encoded = modified_json.replace('"', '&quot;')

        return prefix + modified_encoded + suffix

    # Replace the configuration
    modified_content, count = re.subn(pattern, replace_config, content, count=1)

    if count == 0:
        print("Warning: Could not find [BlockList] Main Content DataType in package.xml")
        return False

    # Write the modified content back
    with open(package_xml_path, 'w', encoding='utf-8') as f:
        f.write(modified_content)

    print(f"✓ Added {len(label_map)} labels to [BlockList] Main Content")
    return True


def process_package(package_zip_path, usync_config_path, migrations_dir):
    """Main processing function."""
    # Create a temporary directory for extraction
    temp_dir = Path(package_zip_path).parent / 'temp_package_extract'

    try:
        # Extract package.zip
        print(f"Extracting {package_zip_path}...")
        if temp_dir.exists():
            shutil.rmtree(temp_dir)
        temp_dir.mkdir()

        with zipfile.ZipFile(package_zip_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)

        # Read labels from uSync config
        print(f"Reading labels from {usync_config_path}...")
        label_map = extract_labels_from_usync(usync_config_path)
        print(f"Found {len(label_map)} block labels")

        # Fix package.xml
        package_xml_path = temp_dir / 'package.xml'
        if not package_xml_path.exists():
            raise FileNotFoundError(f"package.xml not found in {temp_dir}")

        print("Modifying package.xml...")
        if not fix_package_xml(package_xml_path, label_map):
            return False

        # Create a new package.zip
        print("Repacking package.zip...")
        new_package_path = Path(package_zip_path).parent / 'package_new.zip'
        if new_package_path.exists():
            new_package_path.unlink()

        with zipfile.ZipFile(new_package_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for item in temp_dir.rglob('*'):
                if item.is_file():
                    arcname = item.relative_to(temp_dir)
                    zipf.write(item, arcname)

        # Replace the original package.zip
        print("Replacing original package.zip...")
        os.replace(new_package_path, package_zip_path)

        # Copy to migrations folder
        migrations_package = Path(migrations_dir) / 'package.zip'
        print(f"Copying to {migrations_package}...")
        shutil.copy2(package_zip_path, migrations_package)

        print("\n✓ Package processing complete!")
        print(f"  - Modified package.zip with labels")
        print(f"  - Copied to {migrations_package}")
        return True

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False
    finally:
        # Clean up temp directory
        if temp_dir.exists():
            shutil.rmtree(temp_dir)


def main():
    """Main entry point."""
    # Determine paths based on script location
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent

    # Default paths
    package_zip = repo_root / 'package.zip'  # User downloads here
    usync_config = repo_root / 'template' / 'Clean.Blog' / 'uSync' / 'v17' / 'DataTypes' / 'BlockListMainContent.config'
    migrations_dir = repo_root / 'template' / 'Clean' / 'Migrations'

    # Allow command-line override
    if len(sys.argv) > 1:
        package_zip = Path(sys.argv[1])

    # Validate paths
    if not package_zip.exists():
        print(f"Error: package.zip not found at {package_zip}", file=sys.stderr)
        print("\nUsage:")
        print(f"  {sys.argv[0]} [path/to/package.zip]")
        print(f"\nDefault package.zip location: {package_zip}")
        print("Please download the package.zip from Umbraco and place it there,")
        print("or provide the path as an argument.")
        sys.exit(1)

    if not usync_config.exists():
        print(f"Error: uSync config not found at {usync_config}", file=sys.stderr)
        sys.exit(1)

    if not migrations_dir.exists():
        print(f"Error: Migrations directory not found at {migrations_dir}", file=sys.stderr)
        sys.exit(1)

    # Process the package
    success = process_package(package_zip, usync_config, migrations_dir)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
