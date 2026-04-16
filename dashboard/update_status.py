#!/usr/bin/env python3
"""
Helper script to update the dashboard status from CLI skills.
Can be called from within each skill to update the UI in real-time.
"""

import json
import sys
from pathlib import Path

DASHBOARD_DIR = Path(__file__).parent
STATUS_FILE = DASHBOARD_DIR / "pipeline_status.json"


def load_status():
    """Load current pipeline status."""
    if STATUS_FILE.exists():
        with open(STATUS_FILE, 'r') as f:
            return json.load(f)
    return {}


def save_status(status):
    """Save pipeline status to file."""
    with open(STATUS_FILE, 'w') as f:
        json.dump(status, f, indent=2)


def update_step_status(step_id, new_status):
    """
    Update the status of a specific step.

    Args:
        step_id: Step number (1-6)
        new_status: One of 'pending', 'in-progress', 'completed', 'error'
    """
    status = load_status()
    status[str(step_id)] = new_status
    save_status(status)
    print(f"✓ Updated step {step_id} status to: {new_status}")


def add_artifact(filename):
    """
    Add an artifact to the list of generated files.

    Args:
        filename: Name of the artifact file
    """
    status = load_status()
    if 'artifacts' not in status:
        status['artifacts'] = []

    if filename not in status['artifacts']:
        status['artifacts'].append(filename)
        save_status(status)
        print(f"✓ Added artifact: {filename}")


def set_step_error(step_id, error_message):
    """
    Mark a step as errored with a message.

    Args:
        step_id: Step number (1-6)
        error_message: Description of the error
    """
    status = load_status()
    status[str(step_id)] = 'error'
    if 'errors' not in status:
        status['errors'] = {}
    status['errors'][str(step_id)] = error_message
    save_status(status)
    print(f"✗ Step {step_id} encountered an error: {error_message}")


def reset_pipeline():
    """Reset all pipeline status."""
    save_status({})
    print("✓ Pipeline status reset")


def main():
    """Command-line interface for the status updater."""
    if len(sys.argv) < 2:
        print("""
Usage:
    python3 dashboard/update_status.py <command> [args]

Commands:
    start <step_id>              Mark step as in-progress
    complete <step_id>           Mark step as completed
    error <step_id> <message>    Mark step as errored
    artifact <filename>          Add an artifact to the list
    reset                        Reset all status
    show                         Show current status

Examples:
    python3 dashboard/update_status.py start 1
    python3 dashboard/update_status.py complete 1
    python3 dashboard/update_status.py artifact bot.json
    python3 dashboard/update_status.py error 2 "Failed to parse metadata"
""")
        sys.exit(1)

    command = sys.argv[1]

    if command == "start":
        step_id = sys.argv[2]
        update_step_status(step_id, "in-progress")

    elif command == "complete":
        step_id = sys.argv[2]
        update_step_status(step_id, "completed")

    elif command == "error":
        step_id = sys.argv[2]
        error_msg = sys.argv[3] if len(sys.argv) > 3 else "Unknown error"
        set_step_error(step_id, error_msg)

    elif command == "artifact":
        filename = sys.argv[2]
        add_artifact(filename)

    elif command == "reset":
        reset_pipeline()

    elif command == "show":
        status = load_status()
        print(json.dumps(status, indent=2))

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
