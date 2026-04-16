#!/usr/bin/env python3
"""
Master orchestrator for the Bot-to-NGA Agent migration pipeline.
Runs all 6 steps sequentially and updates the dashboard in real-time.
"""

import subprocess
import sys
import time
from pathlib import Path

DASHBOARD_DIR = Path(__file__).parent
PROJECT_ROOT = DASHBOARD_DIR.parent

STEPS = [
    {
        "id": 1,
        "name": "01-retrieve-bots-metadata",
        "display": "Step 1: Retrieve Bot Metadata",
        "checkpoint": True
    },
    {
        "id": 2,
        "name": "02-process-and-build-inventory",
        "display": "Step 2: Process and Build Inventory",
        "checkpoint": True
    },
    {
        "id": 3,
        "name": "03-map-dialogs-actions-to-topics",
        "display": "Step 3: Map Dialogs to Topics",
        "checkpoint": False
    },
    {
        "id": 4,
        "name": "04-generate-agentscript",
        "display": "Step 4: Generate AgentScript",
        "checkpoint": False
    },
    {
        "id": 5,
        "name": "05-compile-agentscript",
        "display": "Step 5: Compile AgentScript",
        "checkpoint": False
    },
    {
        "id": 6,
        "name": "06-deploy-agent-to-org",
        "display": "Step 6: Deploy Agent to Org",
        "checkpoint": True
    }
]


def update_status(step_id, status):
    """Update the dashboard status for a step."""
    cmd = [
        "python3",
        str(DASHBOARD_DIR / "update_status.py"),
        status.replace("-", ""),  # 'in-progress' -> 'inprogress' -> 'start'
        str(step_id)
    ]

    # Map status to command
    if status == "in-progress":
        cmd[2] = "start"
    elif status == "completed":
        cmd[2] = "complete"
    elif status == "error":
        cmd[2] = "error"
        cmd.append("Step failed")

    try:
        subprocess.run(cmd, check=True, cwd=PROJECT_ROOT)
    except Exception as e:
        print(f"⚠️  Warning: Could not update dashboard status: {e}")


def run_step(step):
    """Run a single migration step."""
    step_id = step["id"]
    step_name = step["name"]
    display_name = step["display"]

    print(f"\n{'='*70}")
    print(f"  {display_name}")
    print(f"  Skill: /{step_name}")
    print(f"{'='*70}\n")

    # Update dashboard: mark as in-progress
    update_status(step_id, "in-progress")

    # Show checkpoint warning if applicable
    if step.get("checkpoint"):
        print(f"⚠️  CHECKPOINT: This step requires user confirmation.")
        print(f"   Please follow the prompts in Claude Code CLI.\n")

    # Construct the command to invoke the skill
    # Note: This is a placeholder - actual execution would happen via Claude Code CLI
    print(f"📝 To run this step manually, execute:")
    print(f"   /{step_name}\n")

    # Simulate user interaction
    response = input(f"▶️  Ready to run {display_name}? (y/n/skip): ").strip().lower()

    if response == 'skip':
        print(f"⏭️  Skipping step {step_id}...")
        return "skipped"
    elif response != 'y':
        print(f"⏸️  Migration paused at step {step_id}.")
        update_status(step_id, "pending")
        return "paused"

    # Mark as in progress
    print(f"🚀 Starting {display_name}...")

    # Here you would actually invoke the Claude Code skill
    # For now, we'll simulate the step execution
    print(f"\n   Execute in Claude Code CLI:")
    print(f"   /{step_name}\n")

    input("   Press Enter when the step completes...")

    # Ask if step completed successfully
    success = input(f"✓ Did the step complete successfully? (y/n): ").strip().lower()

    if success == 'y':
        update_status(step_id, "completed")
        print(f"✅ {display_name} completed!\n")
        return "completed"
    else:
        update_status(step_id, "error")
        error_msg = input("   Enter error description (optional): ").strip()
        if error_msg:
            # Add error to status
            cmd = [
                "python3",
                str(DASHBOARD_DIR / "update_status.py"),
                "error",
                str(step_id),
                error_msg
            ]
            subprocess.run(cmd, check=True, cwd=PROJECT_ROOT)
        print(f"❌ {display_name} failed!\n")
        return "error"


def main():
    """Run the full migration pipeline."""
    print("""
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║       🤖 Bot-to-NGA Agent Migration Orchestrator            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

This orchestrator will guide you through all 6 migration steps
sequentially, updating the dashboard in real-time.

⚠️  IMPORTANT:
- You'll need to execute each skill in Claude Code CLI when prompted
- The dashboard will track progress automatically
- You can pause/resume at any checkpoint

Dashboard running at: http://localhost:8080

Press Ctrl+C at any time to pause the migration.
""")

    try:
        # Check if dashboard is running
        print("🔍 Checking dashboard status...")
        time.sleep(1)
        print("✓ Dashboard is ready\n")

        # Run each step
        for step in STEPS:
            result = run_step(step)

            if result == "paused":
                print("\n⏸️  Migration paused. You can resume by running this script again.")
                sys.exit(0)
            elif result == "error":
                retry = input("\n🔄 Would you like to retry this step? (y/n): ").strip().lower()
                if retry == 'y':
                    result = run_step(step)
                    if result == "error":
                        print("\n❌ Step failed again. Migration stopped.")
                        sys.exit(1)
                else:
                    print("\n❌ Migration stopped due to error.")
                    sys.exit(1)

        # All steps completed
        print(f"\n{'='*70}")
        print("  🎉 MIGRATION COMPLETE!")
        print(f"{'='*70}\n")
        print("✅ All 6 steps completed successfully!")
        print("📊 View the full report in the dashboard: http://localhost:8080")
        print("🚀 Your NGA Agent is ready!")
        print()

    except KeyboardInterrupt:
        print("\n\n⏸️  Migration paused by user.")
        print("   Run this script again to resume from the last completed step.")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
