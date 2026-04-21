# Pipeline State Management

## Overview

The migration pipeline maintains state in `.claude/pipeline-state.json` to enable:
- ✅ Session resumption across steps
- ✅ Automatic bot JSON discovery in downstream steps
- ✅ Context awareness (org, bot, version)
- ✅ Progress tracking

## State File Format

**Location:** `.claude/pipeline-state.json`

**Structure:**
```json
{
  "currentStep": 1,
  "botName": "B2A_Intent_Enabled",
  "botVersion": "v1",
  "orgId": "00dvw0000075wif2ai",
  "orgAlias": "orgfarm-cult",
  "botJsonPath": "data/bots/00dvw0000075wif2ai/b2a_intent_enabled/v1/B2A_Intent_Enabled.json",
  "lastUpdated": "2026-04-21T21:13:00Z"
}
```

## When State is Created/Updated

| Step | Action | State Update |
|------|--------|--------------|
| Step 1 | Bot metadata retrieved | Create/overwrite entire state |
| Step 2 | Inventory generated | Update `currentStep: 2` |
| Step 3 | Topics mapped | Update `currentStep: 3` |
| Step 4 | AgentScript generated | Update `currentStep: 4` |
| Step 5 | Compilation complete | Update `currentStep: 5` |
| Step 6 | Agent deployed | Update `currentStep: 6` |

## Reading State

### From Bash Scripts

```bash
# Get bot JSON path
BOT_JSON=$(python3 scripts/get_pipeline_state.py path)

# Get bot name
BOT_NAME=$(python3 scripts/get_pipeline_state.py bot)

# Get bot version
BOT_VERSION=$(python3 scripts/get_pipeline_state.py version)

# Get org alias
ORG_ALIAS=$(python3 scripts/get_pipeline_state.py org)

# Get current step
CURRENT_STEP=$(python3 scripts/get_pipeline_state.py step)

# Get full state as JSON
STATE=$(python3 scripts/get_pipeline_state.py)
```

### From Python Scripts

```python
#!/usr/bin/env python3
import json
from pathlib import Path

def get_pipeline_state():
    state_file = Path(".claude/pipeline-state.json")
    if not state_file.exists():
        return None
    with open(state_file) as f:
        return json.load(f)

# Usage
state = get_pipeline_state()
if state:
    bot_json_path = state["botJsonPath"]
    bot_name = state["botName"]
    bot_version = state["botVersion"]
```

## Updating State

### From Bash Scripts

```bash
# Update current step
python3 -c "
import json
from pathlib import Path

state_file = Path('.claude/pipeline-state.json')
state = json.loads(state_file.read_text())
state['currentStep'] = 2
state_file.write_text(json.dumps(state, indent=2))
"
```

### From Python Scripts

```python
import json
from pathlib import Path
from datetime import datetime

def update_pipeline_step(step_number):
    state_file = Path(".claude/pipeline-state.json")
    
    if not state_file.exists():
        print("❌ Pipeline state not found. Run Step 1 first.")
        return False
    
    state = json.loads(state_file.read_text())
    state["currentStep"] = step_number
    state["lastUpdated"] = datetime.utcnow().isoformat() + "Z"
    
    state_file.write_text(json.dumps(state, indent=2))
    return True

# Usage
update_pipeline_step(2)
```

## Error Handling

### Missing State File

If state file doesn't exist, downstream steps should:

1. Show clear error message
2. Point to Step 1
3. Exit gracefully

**Example:**
```bash
BOT_JSON=$(python3 scripts/get_pipeline_state.py path)

if [ -z "$BOT_JSON" ]; then
    echo "❌ No pipeline state found."
    echo ""
    echo "Run Step 1 first to fetch bot metadata:"
    echo "  /01-retrieve-bots-metadata"
    echo ""
    exit 1
fi

if [ ! -f "$BOT_JSON" ]; then
    echo "❌ Bot JSON not found at: $BOT_JSON"
    echo ""
    echo "The file may have been deleted. Re-run Step 1:"
    echo "  /01-retrieve-bots-metadata"
    echo ""
    exit 1
fi
```

### Invalid JSON

The helper script `get_pipeline_state.py` handles parse errors gracefully:
- Returns empty string for individual fields
- Returns `{}` for full state
- Never crashes

## Session Resumption

Users can resume the pipeline at any step if state exists:

```
User: What step am I on?
Claude: [reads .claude/pipeline-state.json]
        You're on Step 3 (Map Dialogs to Topics)
        Bot: B2A_Intent_Enabled v1
        
        Would you like to continue?
```

## Best Practices

1. ✅ **Always read state** at the start of Steps 2-6
2. ✅ **Update step number** after each step completes
3. ✅ **Validate bot JSON exists** before processing
4. ✅ **Show context** to user (bot name, version, org)
5. ✅ **Handle missing state** with clear Step 1 instructions

## Example: Step 2 Integration

```bash
#!/bin/bash
# Step 2: Process and Build Inventory

# Load pipeline state
BOT_JSON=$(python3 scripts/get_pipeline_state.py path)
BOT_NAME=$(python3 scripts/get_pipeline_state.py bot)
BOT_VERSION=$(python3 scripts/get_pipeline_state.py version)

if [ -z "$BOT_JSON" ]; then
    echo "❌ No pipeline state. Run Step 1: /01-retrieve-bots-metadata"
    exit 1
fi

if [ ! -f "$BOT_JSON" ]; then
    echo "❌ Bot JSON missing: $BOT_JSON"
    exit 1
fi

echo "Processing: $BOT_NAME $BOT_VERSION"
echo ""

# ... process bot JSON ...

# Update state after completion
python3 -c "
import json
from pathlib import Path
state = json.loads(Path('.claude/pipeline-state.json').read_text())
state['currentStep'] = 2
Path('.claude/pipeline-state.json').write_text(json.dumps(state, indent=2))
"

echo "✅ Step 2 complete"
```

## Cleanup

To reset pipeline state (start fresh):

```bash
rm .claude/pipeline-state.json
```

Or via Python:
```python
from pathlib import Path
Path(".claude/pipeline-state.json").unlink(missing_ok=True)
```
