#!/usr/bin/env python3
"""
Helper script to read pipeline state across migration steps.

Usage:
    python3 scripts/get_pipeline_state.py              # Print full state as JSON
    python3 scripts/get_pipeline_state.py path         # Print bot JSON path only
    python3 scripts/get_pipeline_state.py bot          # Print bot name only
    python3 scripts/get_pipeline_state.py version      # Print bot version only
    python3 scripts/get_pipeline_state.py org          # Print org alias only
"""

import json
import sys
from pathlib import Path

STATE_FILE = Path(".claude/pipeline-state.json")


def get_state():
    """Load pipeline state. Returns None if state doesn't exist."""
    if not STATE_FILE.exists():
        return None

    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except Exception:
        return None


def get_field(field_name):
    """Get specific field from state. Returns empty string if not found."""
    state = get_state()
    if not state:
        return ""
    return state.get(field_name, "")


def main():
    if len(sys.argv) < 2:
        # Print full state
        state = get_state()
        if state:
            print(json.dumps(state, indent=2))
        else:
            print("{}")
        return

    command = sys.argv[1].lower()

    if command == "path":
        print(get_field("botJsonPath"))
    elif command == "bot":
        print(get_field("botName"))
    elif command == "version":
        print(get_field("botVersion"))
    elif command == "org":
        print(get_field("orgAlias"))
    elif command == "step":
        print(get_field("currentStep"))
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        print("Valid commands: path, bot, version, org, step", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
