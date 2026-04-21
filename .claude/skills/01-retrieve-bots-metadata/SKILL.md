---
name: retrieve-bots-metadata
description: >
   Step 1 of 6: Retrieve Bot Metadata. Interactive conversational interface for fetching Einstein Bot 
   metadata from Salesforce orgs. Guides users through org connection, bot selection, version selection, 
   and metadata download with complete ML training data.
metadata:
   author: salesforce-migration
   version: "3.0-ux-step1"
   pipeline-order: "1"
   ux-spec: "Einstein Bots → Agentscript Converter - Step 1"
compatibility: Requires Salesforce CLI (sf), Python 3.7+, authenticated org access

# Step 1 — Retrieve Bot Metadata from SF Org

## Purpose

This is **Step 1 of the 6-step Einstein Bots → Agentforce Converter pipeline**. It provides an interactive conversational interface for retrieving bot metadata from Salesforce orgs, including complete ML training data.

## Pipeline Context

```
┌──────────────────────────────────────────────────────────────┐
│  Einstein Bots → Agentforce Converter Pipeline               │
│                                                               │
│  Step 1: Retrieve Metadata        ◀── YOU ARE HERE           │
│  Step 2: Bot Inventory                                        │
│  Step 3: Mapping Plan                                         │
│  Step 4: Generate Script                                      │
│  Step 5: Compile & Validate                                   │
│  Step 6: Create Agent                                         │
└──────────────────────────────────────────────────────────────┘
```

---

## Activation

This skill activates when the user:
- Says "proceed" from the pipeline welcome screen (Step 0)
- Says "start bot migration" or similar
- Invokes `/01-retrieve-bots-metadata` directly
- Wants to fetch a bot from a Salesforce org

---

## Conversational Flow

### Phase 1.1: Org Connection

**Automatic Entry**

When this skill activates, immediately display the Step 1 header and attempt org connection:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Einstein Bots → Agentscript Converter  |  Step 1 of 6
  Retrieve Bot Metadata
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Connecting to Salesforce org...
```

**Check org authentication:**
```bash
sf org list --json
```

**Success Path:**
```
✅  Connected to: <OrgName>  (<username@example.com>)

Fetching available bots...
```

Proceed to Phase 1.2.

**Failure Path:**
```
❌  Could not connect to Salesforce org.

    Reason : <error detail, e.g. "Auth token expired" or "Org not found">
    Fix    : Re-authenticate using:  sf org login web --alias <alias>
             Then re-run:            /01-retrieve-bots-metadata
```

Do not proceed. Wait for user to fix authentication and re-invoke skill.

---

### Phase 1.2: Bot List Display

**Run interactive bot query:**

Execute:
```bash
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh interactive <ORG_ALIAS>
```

This invokes the existing `list_bots_interactive.py` script which queries:
```sql
SELECT BotDefinition.DeveloperName, BotDefinition.Description, 
       VersionNumber, LastModifiedDate
FROM BotVersion
ORDER BY BotDefinition.DeveloperName, VersionNumber DESC
```

**Expected output from script:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AVAILABLE BOTS  (Org: <OrgName>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  #   Bot Name                  Description
  ─   ─────────────────────     ──────────────────────────────────────────
  1   CustomerServiceBot              Customer service bot for airline services.
                                Handles reservations, baggage, rewards.
  2   FitnessAssistantBot               Fitness assistant. Manages class
                                bookings, memberships, and support queries.
  3   SupportBot        General support bot with intent routing

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Type the number of the bot you want to convert.

  [1–N]   Select a bot
  [quit]  Exit
```

**Handle edge cases:**

- **No bots found:**
  ```
  ❌ No Einstein Bots found in this org.
  ```
  
- **More than 20 bots:**
  List first 20 and add pagination:
  ```
  [more]  Show next 20 bots
  ```

**Natural Language Understanding:**

Accept these variations:
- "select bot 1" / "1" / "bot 1" / "first one"
- "select CustomerServiceBot" / "Emirates Bot"
- "show me the Emirates bot"
- "quit" / "exit" / "cancel"

Map these to the appropriate bot selection or exit.

**Conversation Examples:**

```
User: select 2
Claude: ✅  Selected: FitnessAssistantBot
        Fetching versions...
        [Proceeds to Phase 1.3]

User: I want the Emirates bot
Claude: ✅  Selected: CustomerServiceBot
        Fetching versions...
        [Proceeds to Phase 1.3]

User: quit
Claude: Exiting bot selection. You can restart with /01-retrieve-bots-metadata
```

---

### Phase 1.3: Version List Display

**Once bot is selected, show versions:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VERSIONS  —  CustomerServiceBot
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  #   Version     Status      Last Modified
  ─   ─────────   ─────────   ──────────────────
  1   v4          Active      12 Apr 2026, 14:32
  2   v3          Inactive    01 Mar 2026, 09:15
  3   v2          Inactive    10 Jan 2026, 11:40

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  The Active version is recommended for production migrations.

  [1–N]   Select a version
  [back]  Go back to the bot list
  [quit]  Exit
```

**Natural Language Understanding:**

Accept these variations:
- "select version 4" / "v4" / "4" / "version 4"
- "select the active version" / "active one"
- "select 1st item" / "first" / "1"
- "back" / "go back"
- "quit" / "exit"

**Conversation Examples:**

```
User: select the active version
Claude: ✅  Selected: v4 (Active)
        [Proceeds to Phase 1.4]

User: back
Claude: ↩ Going back to bot list...
        [Returns to Phase 1.2]

User: what does active mean?
Claude: The "Active" version is the currently deployed version in your org.
        For production migrations, you should use the Active version to ensure
        you're migrating the live bot configuration.
        
        Would you like to select a version?
```

**Off-topic handling:**

```
User: how do I create a new bot?
Claude: We are currently in the bot selection phase (Step 1). I can help you:
        - Select a version to migrate
        - Go back to the bot list
        - Exit this process
        
        To create a new bot, you would do that in Salesforce Setup after
        completing the migration. Shall we continue selecting a version?
```

---

### Phase 1.4: Confirm Selection

**Before downloading, show confirmation:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CONFIRM SELECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Bot      : CustomerServiceBot
  Version  : v4  (Active)
  Org      : <OrgName>

  I will download the metadata for this bot and save it
  locally before proceeding to the inventory step.

  [yes]   Confirm and download
  [back]  Go back to the version list
  [quit]  Exit
```

**Natural Language Understanding:**

Accept:
- "yes" / "y" / "confirm" / "proceed" / "download"
- "no" / "n" / "back" / "cancel"
- "quit" / "exit"

**Conversation Examples:**

```
User: yes
Claude: ✅ Confirmed. Downloading metadata...
        [Proceeds to Phase 1.5]

User: wait, go back
Claude: ↩ Going back to version list...
        [Returns to Phase 1.3]

User: what metadata will be downloaded?
Claude: I will download:
        - Bot structure (dialogs, steps, navigation rules)
        - All actions and invocations (Apex, Flows)
        - ML intents and utterances
        - External ML domain training data (if available)
        
        This gives us everything needed for the migration.
        Ready to proceed?
```

---

### Phase 1.5: Download & Save

**Execute download:**

Run the existing infrastructure:
```bash
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh <BOT_NAME> <ORG_ALIAS>
```

**Show simplified progress (hide intermediate steps unless errors occur):**
```
Downloading metadata for CustomerServiceBot v4...

✅  Metadata saved to: 
    data/sf-cli/custom/00DVW...CustomerServiceBot_v4/jsons/CustomerServiceBot.json
```

**Internal steps (Steps 1.1-1.7) run silently:**
- 1.1: Checking Salesforce DX project setup
- 1.2: Getting org details and bot version
- 1.3: Retrieving bot metadata from org
- 1.4: Auto-discovering ML domains
- 1.5: Retrieving ML training data (if available)
- 1.6: Copying files to custom folder
- 1.7: Converting and extracting metadata (includes two-phase Apex parsing)

**Only show step details if an error occurs at any step.**

**Example error output:**
```
Downloading metadata for CustomerServiceBot v4...
  Step 1.3: Retrieving bot metadata...
  ❌ Error in Step 1.3: Failed to retrieve bot metadata
     Reason: Bot not found in org
```

**Success outcome:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Step 1 complete.
  Ready to proceed to Step 2: Parse Bot Metadata & Inventory.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [yes]   Proceed to Step 2
  [quit]  Exit  (resume later: /02-process-and-build-inventory)
```

**Failure outcome:**
```
❌  Metadata download failed.

    Bot     : CustomerServiceBot  v4
    Reason  : <error detail from script>

  [retry]  Try downloading again
  [back]   Go back to the version list
  [quit]   Exit
```

**Natural Language Understanding:**

Accept:
- "yes" / "proceed" / "continue" / "next"
- "retry" / "try again"
- "back" / "go back"
- "quit" / "exit"

---

## Conversation Patterns

### Free-Form Questions During Selection

The user can ask questions at any point. Handle contextually:

**During bot selection (Phase 1.2):**
```
User: what does this bot do?
Claude: I can see that CustomerServiceBot is described as: "Customer service bot 
        for airline services. Handles reservations, baggage, rewards."
        
        Would you like to select this bot?

User: show me more details about bot 2
Claude: Bot 2 is FitnessAssistantBot:
        - Description: Fitness assistant
        - Available versions: v1, v2, v3
        - Latest modified: [date]
        
        Would you like to select this bot?
```

**Off-topic redirects:**
```
User: how does AgentScript work?
Claude: That's a great question! I'll explain how AgentScript works when we 
        get to Step 4 (Generate Script). Right now, we're in Step 1 where we 
        need to select and download a bot's metadata.
        
        Which bot would you like to convert?

User: can I change the org?
Claude: We are currently connected to: <OrgName>
        
        To switch orgs, you'll need to:
        1. Say "quit" to exit
        2. Authenticate to a different org: sf org login web --alias <new-alias>
        3. Re-run: /01-retrieve-bots-metadata
        
        Would you like to continue with the current org, or quit and switch?
```

### Conversation Memory

Maintain context throughout the flow:
- Remember which bot was selected when asking about versions
- Remember version when asking for confirmation
- Refer back to previous choices naturally

**Example:**
```
[User selected CustomerServiceBot in Phase 1.2]

Claude (in Phase 1.3): Here are the versions for CustomerServiceBot...

[User selected v4 in Phase 1.3]

Claude (in Phase 1.4): Confirm: CustomerServiceBot v4 from <OrgName>
```

---

## Technical Implementation

### Script Invocations

**Phase 1.1 - Check org:**
```bash
sf org list --json
```

**Phase 1.2 - Interactive bot selection:**
```bash
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh interactive <ORG_ALIAS>
```

This script internally calls `list_bots_interactive.py` which:
1. Queries all bots and versions
2. Displays formatted table
3. Captures user selection
4. Returns `SELECTED_BOT=<name>` for shell to parse

**Phase 1.5 - Download metadata:**
```bash
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh <BOT_NAME> <ORG_ALIAS>
```

This executes the full retrieval pipeline (Steps 1.3-1.10 in the script).

### Output Files

After successful completion:

| File | Location | Purpose |
|------|----------|---------|
| Complete bot JSON | `data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/jsons/<BOTNAME>.json` | Main output for Step 2 |
| Bot XML | `data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/bots/` | Raw bot metadata |
| ML Domain XML | `data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/mlDomains/` | Raw ML metadata |
| All JSONs | `data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/jsons/` | Converted metadata |

### Error Handling

**Org authentication failure:**
- Show exact error from `sf org list`
- Provide fix command
- Do not proceed

**Bot query failure:**
- Show error from query
- Suggest fixes (check permissions, network)
- Allow retry or quit

**Download failure:**
- Show which step failed (1.3-1.10)
- Show error detail from script
- Offer retry, go back, or quit

---

## Hand-off to Step 2

Once Step 1 completes successfully, hand off to Step 2:

**File to pass:**
```
data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/jsons/<BOTNAME>.json
```

**Transition message:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Step 1 complete.
  CustomerServiceBot v4  —  metadata downloaded

  Moving to Step 2: Bot Inventory.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then invoke:
```
/02-process-and-build-inventory
```

Or wait for user to say "yes" / "proceed".

---

## Design Principles

### Visual Consistency

Use these formatting patterns consistently:

**Headers:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Title
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Status indicators:**
- ✅ Success
- ❌ Error
- ⚠️  Warning
- ℹ️  Info
- ↩ Going back
- ✓ Checkmark for completed items

**Options:**
```
[option]  Description
```

**Table borders:**
```
─   Separator
```

### Conversational Tone

- Be concise and direct
- Use active voice: "I will download..." not "The system will..."
- Acknowledge user input: "✅ Selected: CustomerServiceBot"
- Provide context: "The Active version is recommended for production migrations"
- Guide next steps: "Would you like to select a version?"

### Natural Language Processing

- Accept multiple phrasings for same intent
- Handle typos gracefully
- Understand context from previous messages
- Redirect off-topic questions contextually
- Never say "I don't understand" - always suggest valid options

---

## Testing Scenarios

### Happy Path
1. User invokes skill
2. Org connects successfully
3. User selects bot by number
4. User selects active version
5. User confirms
6. Download succeeds
7. User proceeds to Step 2

### Edge Cases

**No bots in org:**
- Show clear message
- Don't proceed

**Authentication expired mid-flow:**
- Catch error
- Show re-auth command
- Allow retry

**User changes mind:**
- Allow "back" at every stage
- Maintain context when going back

**Download interrupted:**
- Show which step failed
- Offer retry with same selections

**Off-topic questions:**
- Answer briefly
- Redirect to current phase
- Maintain flow context

---

## Quick Reference

### Commands Available

| Phase | User Can Say | Action |
|-------|-------------|--------|
| 1.2 | "select 1" / "bot 1" | Select bot |
| 1.2 | "quit" / "exit" | Exit skill |
| 1.3 | "select v4" / "active" | Select version |
| 1.3 | "back" | Return to bot list |
| 1.4 | "yes" / "confirm" | Start download |
| 1.4 | "back" | Return to versions |
| 1.5 | "retry" | Retry download |
| 1.5 | "yes" / "proceed" | Go to Step 2 |

### File Paths

```
.claude/skills/01-retrieve-bots-metadata/
├── SKILL.md                                  # This file
├── APEX_INVOCATION_PARSING.md                # Technical doc for two-phase Apex parsing
├── assets/
│   ├── SF_CLI_COMMANDS.md                    # SF CLI reference
│   └── BOT_FETCHING_GUIDE.md                 # Comprehensive fetching guide
└── scripts/
    ├── fetch_bot_from_org.sh                 # Main orchestrator (Steps 1.1-1.7)
    ├── list_bots_interactive.py              # Bot selector
    ├── convert_bot_xml_to_json.py            # Bot XML converter
    ├── extract_bot_metadata.py               # Extraction engine (handles ML intents, normalizes retryMessages)
    ├── convert_ml_domain.py                  # ML domain XML converter
    ├── fetch_and_parse_invocations.sh        # Apex parsing orchestrator (two-phase approach)
    ├── extract_invocations_from_bot.py       # Phase 1: Extract parameter names from bot metadata
    ├── parse_apex_invocable_methods.py       # Phase 2a: Parse Apex @InvocableMethod signatures
    ├── merge_invocation_types.py             # Phase 2b: Merge bot params with Apex types
    └── compare_bot_jsons.py                  # Validation tool

Output:
data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/
├── bots/                                     # Raw bot XML
├── mlDomains/                                # Raw ML XML
├── apex-invocations/                         # Apex parsing artifacts
│   ├── classes/                              # Retrieved Apex .cls files
│   ├── bot-invocations.json                  # Phase 1 output (parameter names)
│   ├── parsed-apex-types.json                # Phase 2a output (types from Apex)
│   └── merged-invocations.json               # Phase 2b output (complete data)
└── jsons/                                    # Converted JSON (main output)
    └── <BOTNAME>.json                        # ⭐ Pass this to Step 2 (includes real Apex types)
```

---

## Technical Implementation Details

### Two-Phase Apex Parsing (Step 1.7)

**Problem Solved:**
The original implementation inferred Apex invocable method parameter types from bot conversation variable labels, leading to incorrect type information. For example, a variable labeled "Response User" was incorrectly inferred as `ResponseUser__c` when the actual type was `CultUser__c`.

**Solution:**
Replaced inference with real Apex class parsing from Salesforce org using a two-phase approach:

**Phase 1: Extract Parameter Names from Bot Metadata**
- Script: `extract_invocations_from_bot.py`
- Parses `invocationMappings` from botVersion metadata
- Returns parameter names (without types yet)
- Output: `bot-invocations.json`

**Phase 2: Fetch and Parse Apex Classes**
- **Phase 2a: Parse Apex Source** (`parse_apex_invocable_methods.py`)
  - Retrieves .cls files from org using SF CLI
  - Parses `@InvocableMethod` signatures
  - Handles Request/Response inner classes
  - Handles simple method signatures (List<String> input, List<Response> output)
  - Handles mixed patterns (simple input + Response class output)
  - Maps Apex types to API types (`String` → `STRING`, `CustomObject__c` → `SOBJECT`)
  - Uses `sobjectType` field name (lowercase 's')
  - Output: `parsed-apex-types.json`
  
- **Phase 2b: Merge** (`merge_invocation_types.py`)
  - Merges bot metadata parameters with Apex type information
  - Uses Apex as authoritative source (includes all defined parameters)
  - Sorts all data alphabetically
  - Output: `merged-invocations.json`

**Phase 3: Update Bot JSON**
- Replaces `botInvocationsDescribeInfo.apex` with complete, accurate data
- Output: `<BOTNAME>_with_parsed_invocations.json` → `<BOTNAME>.json`

**Batching Strategy:**
- ≤ 50 Apex classes: Single `sf project retrieve start` call with `package.xml`
- \> 50 Apex classes: Batches of 50 (efficient parallel retrieval)

**Key Features:**
- ✅ No inference - all data from real Apex source code
- ✅ Accurate SObject types (e.g., `CultUser__c` not fabricated `ResponseUser__c`)
- ✅ Proper field name: `sobjectType` (lowercase 's')
- ✅ Includes `required` flags from `@InvocableVariable(required=true)`
- ✅ Handles complex method patterns (Request/Response, simple, mixed)
- ✅ Alphabetically sorted (classes, input params, output params)
- ✅ Generic - works with any Einstein Bot

**See Also:**
- `.claude/skills/01-retrieve-bots-metadata/APEX_INVOCATION_PARSING.md` for complete technical documentation
- `.claude/skills/01-retrieve-bots-metadata/assets/BOT_FETCHING_GUIDE.md` for usage guide

### retryMessages Normalization (Step 2.5 in extract_bot_metadata.py)

**Problem Solved:**
Einstein Bot metadata has inconsistent `retryMessages` structure:
- Sometimes: `{"message": "...", "messageIdentifier": "..."}` (single object)
- Sometimes: `[{"message": "...", "messageIdentifier": "..."}, ...]` (array)

**Solution:**
Added `normalize_retry_messages()` function that ensures all `retryMessages` fields are arrays of objects for consistency.

---

## Next Steps

After successful completion:
- **File ready:** `data/sf-cli/custom/.../jsons/<BOTNAME>.json`
- **Contains:** Complete bot structure + ML training data + accurate Apex invocation types
- **Next skill:** `/02-process-and-build-inventory`
- **User prompt:** "Would you like to proceed to Step 2: Bot Inventory?"
