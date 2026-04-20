#!/usr/bin/env python3
"""
Interactive bot selector - lists all bots with versions and prompts user to select one
"""

import json
import subprocess
import sys
from typing import List, Dict, Optional, Tuple


def run_sf_command(query: str, org: Optional[str] = None) -> List[Dict]:
    """Run sf data query and return results as list of dicts"""
    cmd = [
        "sf", "data", "query",
        "--query", query,
        "--result-format", "json"
    ]

    if org:
        cmd.extend(["--target-org", org])

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(result.stdout)
        return data.get("result", {}).get("records", [])
    except subprocess.CalledProcessError as e:
        print(f"Error querying Salesforce: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON response: {e}", file=sys.stderr)
        sys.exit(1)


def list_bots(org: Optional[str] = None) -> List[Dict]:
    """Query all bot versions from org"""
    query = """
    SELECT
        BotDefinition.DeveloperName,
        BotDefinition.Description,
        VersionNumber,
        LastModifiedDate
    FROM BotVersion
    ORDER BY BotDefinition.DeveloperName, VersionNumber DESC
    """

    return run_sf_command(query, org)


def group_by_bot(versions: List[Dict]) -> Dict[str, List[Dict]]:
    """Group versions by bot developer name"""
    grouped = {}
    for version in versions:
        bot_name = version["BotDefinition"]["DeveloperName"]
        if bot_name not in grouped:
            grouped[bot_name] = []
        grouped[bot_name].append(version)
    return grouped


def display_bot_list(bot_list: List[str], grouped_bots: Dict[str, List[Dict]]) -> None:
    """Display numbered list of bots in table format"""
    print("\n" + "="*120)
    print("Available Bots")
    print("="*120)

    # Table header
    print(f"\n{'#':<5} {'Bot Name':<30} {'Version':<10} {'Description':<45} {'Last Modified':<20}")
    print("-" * 120)

    for i, bot_name in enumerate(bot_list, 1):
        versions = grouped_bots[bot_name]
        version_nums = [str(v["VersionNumber"]) for v in versions]
        version_str = f"v{', v'.join(version_nums)}"

        # Get bot description
        bot_desc = versions[0]["BotDefinition"].get("Description", "N/A")
        if len(bot_desc) > 45:
            bot_desc = bot_desc[:42] + "..."

        # Get last modified date
        last_modified = versions[0].get("LastModifiedDate", "N/A")
        if last_modified and len(last_modified) > 10:
            last_modified = last_modified[:10]  # Just the date part

        print(f"[{i}]{' ':<3} {bot_name:<30} {version_str:<10} {bot_desc:<45} {last_modified:<20}")

    print("-" * 120)
    print(f"[0]    Cancel / Exit")
    print("=" * 120)


def display_bot_details(bot_name: str, versions: List[Dict]) -> None:
    """Display detailed version information for a selected bot"""
    print("\n" + "="*80)
    print(f"Bot Details: {bot_name}")
    print("="*80)

    # Bot description
    bot_desc = versions[0]["BotDefinition"].get("Description", "N/A")
    print(f"\nDescription: {bot_desc}")

    # Version details
    print(f"\n{'Version':<10} {'Last Modified':<20}")
    print("-" * 35)

    for version in versions:
        ver_num = version["VersionNumber"]
        last_modified = version["LastModifiedDate"][:10] if version.get("LastModifiedDate") else "N/A"
        print(f"v{ver_num:<9} {last_modified:<20}")


def get_user_choice(prompt: str, max_choice: int) -> int:
    """Get numeric choice from user"""
    while True:
        try:
            choice_str = input(prompt).strip()
            choice = int(choice_str)
            if 0 <= choice <= max_choice:
                return choice
            else:
                print(f"Please enter a number between 0 and {max_choice}")
        except ValueError:
            print("Please enter a valid number")
        except (KeyboardInterrupt, EOFError):
            print("\n")
            return 0


def confirm_selection(bot_name: str) -> bool:
    """Confirm bot selection"""
    print()
    while True:
        response = input(f"Fetch {bot_name}? [y/n]: ").strip().lower()
        if response in ['y', 'yes']:
            return True
        elif response in ['n', 'no']:
            return False
        elif response == '':
            continue
        else:
            print("Please enter 'y' or 'n'")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 list_bots_interactive.py <ORG_ALIAS>", file=sys.stderr)
        print("\nExample:", file=sys.stderr)
        print("  python3 list_bots_interactive.py my-org", file=sys.stderr)
        sys.exit(1)

    org = sys.argv[1]

    print(f"\nQuerying bots from org: {org}...")

    # Fetch bot versions
    versions = list_bots(org)

    if not versions:
        print("\nNo bots found in org.", file=sys.stderr)
        sys.exit(1)

    # Group by bot
    grouped_bots = group_by_bot(versions)

    # Interactive selection
    bot_list = sorted(grouped_bots.keys())

    print(f"\nFound {len(bot_list)} bot(s) with {sum(len(v) for v in grouped_bots.values())} version(s)")

    while True:
        # Display bot list
        display_bot_list(bot_list, grouped_bots)

        # Get user selection
        choice = get_user_choice("\nEnter bot number (0 to cancel): ", len(bot_list))

        if choice == 0:
            print("\n✗ Selection cancelled")
            sys.exit(0)

        # Get selected bot
        selected_bot = bot_list[choice - 1]

        # Display bot details
        display_bot_details(selected_bot, grouped_bots[selected_bot])

        # Confirm selection
        if confirm_selection(selected_bot):
            # Output selected bot name to stdout for shell script to capture
            print(f"\n✓ Bot selected: {selected_bot}")
            print(f"SELECTED_BOT={selected_bot}")
            sys.exit(0)
        else:
            # Go back to bot list
            print("\n↩ Going back to bot list...")


if __name__ == "__main__":
    main()
