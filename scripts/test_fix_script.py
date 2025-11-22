#!/usr/bin/env python3
"""Quick test to verify the label fixing logic works correctly."""

import json
import html
import re
from pathlib import Path

# Simulate the fix_package_xml logic
def test_label_addition():
    # This is the "before" XML from the user
    before_config = '{&quot;blocks&quot;:[{&quot;contentElementTypeKey&quot;:&quot;dd183f78-7d69-4eda-9b4c-a25970583a28&quot;,&quot;settingsElementTypeKey&quot;:&quot;da15dc43-43f6-45f6-bda8-1fd17a49d25c&quot;},{&quot;contentElementTypeKey&quot;:&quot;e0df4794-063a-4450-8f4f-c615a5d902e2&quot;,&quot;settingsElementTypeKey&quot;:&quot;fed88ec5-c150-42af-b444-1f9ac5a100ba&quot;}],&quot;validationLimit&quot;:{&quot;min&quot;:null,&quot;max&quot;:null},&quot;useSingleBlockMode&quot;:false}'

    # Sample label map (from uSync)
    label_map = {
        'dd183f78-7d69-4eda-9b4c-a25970583a28': 'Rich Text: ${ content.markup | stripHtml} ${$settings.hide == \'1\' ? \'[HIDDEN]\' : \'\'}',
        'e0df4794-063a-4450-8f4f-c615a5d902e2': 'Image: ${ caption } ${$settings.hide == \'1\' ? \'[HIDDEN]\' : \'\'}',
    }

    print("BEFORE:")
    print(before_config[:150] + "...")
    print()

    # Decode HTML entities
    config_json_str = html.unescape(before_config)
    print("Decoded JSON:")
    print(config_json_str[:150] + "...")
    print()

    # Parse the JSON
    config = json.loads(config_json_str)

    # Add labels to each block
    for block in config.get('blocks', []):
        content_key = block.get('contentElementTypeKey')
        if content_key in label_map:
            block['label'] = label_map[content_key]

    # Convert back to JSON string
    modified_json = json.dumps(config, separators=(',', ':'))

    # Unicode-escape single quotes to match Umbraco format
    modified_json = modified_json.replace("'", r'\u0027')

    # Encode back to HTML entities
    modified_encoded = modified_json.replace('"', '&quot;')

    print("AFTER:")
    print(modified_encoded[:200] + "...")
    print()

    # Verify labels were added
    config_check = json.loads(html.unescape(modified_encoded))
    labels_added = sum(1 for b in config_check['blocks'] if 'label' in b)
    print(f"✓ Successfully added {labels_added} labels")

    # Show one label example
    if config_check['blocks'][0].get('label'):
        print(f"✓ Example label: {config_check['blocks'][0]['label'][:60]}...")

if __name__ == '__main__':
    test_label_addition()
