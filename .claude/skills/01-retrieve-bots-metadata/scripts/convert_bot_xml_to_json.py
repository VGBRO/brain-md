#!/usr/bin/env python3
"""
Convert Bot XML metadata files to JSON format
"""

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def xml_to_dict(element):
    """Recursively convert XML element to dictionary"""
    result = {}

    # Add text content if present
    if element.text and element.text.strip():
        return element.text.strip()

    # Process child elements
    for child in element:
        child_data = xml_to_dict(child)
        tag = child.tag.split('}')[-1]  # Remove namespace

        if tag in result:
            # Convert to list if multiple elements with same tag
            if not isinstance(result[tag], list):
                result[tag] = [result[tag]]
            result[tag].append(child_data)
        else:
            result[tag] = child_data

    return result


def convert_bot_xml(xml_file: Path) -> dict:
    """Convert bot XML file to JSON structure"""
    tree = ET.parse(xml_file)
    root = tree.getroot()

    # Convert to dict
    bot_data = xml_to_dict(root)

    # Wrap in appropriate key based on file type
    if xml_file.name.endswith('.bot-meta.xml'):
        return {"Bot": bot_data}
    elif xml_file.name.endswith('.botVersion-meta.xml'):
        return {"BotVersion": bot_data}
    else:
        return bot_data


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 convert_bot_xml_to_json.py <bot_name> [folder_name]")
        print("\nExample:")
        print("  python3 convert_bot_xml_to_json.py MyBot")
        print("  python3 convert_bot_xml_to_json.py MyBot 00Dxx000000xxxx_MyBot_v1")
        sys.exit(1)

    bot_name = sys.argv[1]
    folder_name = sys.argv[2] if len(sys.argv) > 2 else bot_name

    # Custom folder structure: data/sf-cli/custom/{folder_name}
    bot_dir = Path(f"data/sf-cli/custom/{folder_name}")
    bots_dir = bot_dir / "bots"
    jsons_dir = bot_dir / "jsons"

    # Create jsons subdirectory
    jsons_dir.mkdir(exist_ok=True)

    # Convert bot-meta.xml (look in bots subfolder)
    bot_xml = bots_dir / f"{bot_name}.bot-meta.xml"
    if bot_xml.exists():
        print(f"Converting {bot_xml}...")
        bot_data = convert_bot_xml(bot_xml)

        # Save to jsons directory
        jsons_output = jsons_dir / f"{bot_name}.bot-meta.json"
        with open(jsons_output, 'w') as f:
            json.dump(bot_data, f, indent=2)
        print(f"  ✓ Created {jsons_output}")
    else:
        print(f"Error: {bot_xml} not found")
        sys.exit(1)

    # Convert botVersion XML files (look in bots subfolder)
    for version_xml in bots_dir.glob("*.botVersion-meta.xml"):
        print(f"Converting {version_xml}...")
        version_data = convert_bot_xml(version_xml)

        # Save to jsons directory
        jsons_output = jsons_dir / version_xml.with_suffix('.json').name
        with open(jsons_output, 'w') as f:
            json.dump(version_data, f, indent=2)
        print(f"  ✓ Created {jsons_output}")

    print("\n✅ XML to JSON conversion complete!")


if __name__ == "__main__":
    main()
