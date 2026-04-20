#!/usr/bin/env python3
"""
Merge ML Domain training data into generated bot JSON
Replaces the mlRelatedData section with correct training intents
"""

import json
import sys
from pathlib import Path


def merge_ml_domains(bot_name: str, folder_name: str = None):
    """Merge ML Domain data into bot's extracted metadata JSON"""

    # Paths
    if folder_name is None:
        folder_name = bot_name

    # Use custom folder structure
    bot_dir = Path(f"data/sf-cli/custom/{folder_name}")
    jsons_dir = bot_dir / "jsons"
    generated_file = jsons_dir / f"{bot_name}.json"

    # Check if bot JSON exists
    if not generated_file.exists():
        print(f"Error: Bot JSON not found at {generated_file}")
        print("Run extract_bot_metadata.py first")
        return False

    # Find ML domain JSON files in jsons folder (they're all together now)
    ml_domain_files = list(jsons_dir.glob("*.json"))
    # Filter out the bot JSON itself and bot-meta JSONs
    ml_domain_files = [f for f in ml_domain_files if f.stem != bot_name and not f.stem.endswith('.bot-meta') and not f.stem.endswith('.botVersion-meta')]

    if not ml_domain_files:
        print("Error: No ML domain JSON files found")
        print("Run: sf project retrieve start --metadata MlDomain:<YourMLDomainName>")
        print("Then: python3 scripts/convert_ml_domain.py <path-to-xml>")
        return False

    # Use the first ML domain file found
    ml_domain_file = ml_domain_files[0]
    ml_domain_name = ml_domain_file.stem
    print(f"Using ML domain: {ml_domain_name}")

    # Load files
    print(f"Loading {generated_file}...")
    bot_data = json.load(open(generated_file))

    print(f"Loading {ml_domain_file}...")
    ml_domain_data = json.load(open(ml_domain_file))

    # Current mlRelatedData (from bot's internal ML domain)
    old_domain = bot_data.get("mlRelatedData", {}).get("c", {})
    old_domain_name = list(old_domain.keys())[0] if old_domain else None

    if old_domain_name:
        old_intents = old_domain[old_domain_name]["MlDomain"]["mlIntents"]
        print(f"\nCurrent ML Domain: {old_domain_name}")
        print(f"  Intents: {len(old_intents)}")

        # Count utterances
        old_utterances = sum(len(i["mlIntentUtterances"]) for i in old_intents)
        print(f"  Utterances: {old_utterances}")

    # New mlRelatedData (from ML Domain)
    new_intents = ml_domain_data["mlIntents"]
    new_utterances = sum(len(i["mlIntentUtterances"]) for i in new_intents)

    print(f"\nNew ML Domain: {ml_domain_name} (external training data)")
    print(f"  Intents: {len(new_intents)}")
    print(f"  Utterances: {new_utterances}")

    # Replace mlRelatedData
    bot_data["mlRelatedData"] = {
        "c": {
            ml_domain_name: {
                "MlDomain": {
                    "fullName": ml_domain_name,
                    "label": ml_domain_data.get("label", ml_domain_name),
                    "mlIntents": new_intents
                }
            }
        }
    }

    # Create jsons directory if it doesn't exist
    jsons_dir.mkdir(exist_ok=True)

    # Save updated file to jsons directory with bot name
    output_file = jsons_dir / f"{bot_name}.json"
    with open(output_file, 'w') as f:
        json.dump(bot_data, f, indent=2)

    # Clean up temporary file
    if generated_file.exists() and generated_file.name == "generated_temp.json":
        generated_file.unlink()
        print(f"  ✓ Cleaned up temporary file: {generated_file}")

    print(f"\n{'='*80}")
    print(f"✅ Successfully merged {ml_domain_name} into bot data!")
    print(f"{'='*80}")
    print(f"\nOutput: {output_file}")
    print("\nChanges:")
    print(f"  ✓ Replaced mlRelatedData section")
    print(f"  ✓ ML Domain: {old_domain_name} → {ml_domain_name}")
    print(f"  ✓ Intents: {len(old_intents) if old_domain_name else 0} → {len(new_intents)}")
    print(f"  ✓ Utterances: {old_utterances if old_domain_name else 0} → {new_utterances}")

    # Show sample intents
    if new_intents:
        print(f"\n✓ Sample intents from {ml_domain_name}:")
        for i, intent in enumerate(new_intents[:3], 1):
            utt_count = len(intent.get('mlIntentUtterances', []))
            print(f"    {i}. {intent['developerName']} ({utt_count} utterances)")

    print(f"\n{'='*80}")

    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 merge_ml_data.py <BOT_NAME> [FOLDER_NAME]")
        print("\nExample:")
        print("  python3 merge_ml_data.py MyBot")
        print("  python3 merge_ml_data.py MyBot 00Dxx000000xxxx_MyBot_v1")
        sys.exit(1)

    bot_name = sys.argv[1]
    folder_name = sys.argv[2] if len(sys.argv) > 2 else None

    print("="*80)
    print("Merging ML Domain Training Data into Bot")
    print("="*80)
    print(f"\nBot: {bot_name}")
    if folder_name:
        print(f"Folder: {folder_name}")

    success = merge_ml_domains(bot_name, folder_name)

    if success:
        print("\n🎉 Done! Your bot now has the external ML training data merged")
    else:
        print("\n❌ Failed to merge. Check errors above.")
        sys.exit(1)


if __name__ == "__main__":
    main()
