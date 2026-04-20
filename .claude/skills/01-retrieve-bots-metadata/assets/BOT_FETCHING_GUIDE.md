# Bot Fetching Guide

## Overview

This guide explains two ways to fetch Einstein Bot metadata from Salesforce orgs for use in the migration pipeline:
1. **Interactive Claude Skill** (Recommended) - Conversational guided experience
2. **Direct Script** - Command-line automation

---

## Quick Start

### Method 1: Interactive Claude Skill (Recommended)

Use the conversational interface with Claude Code:

```
/01-retrieve-bots-metadata
```

**What happens:**
1. ✅ Automatic org connection check
2. ✅ Interactive bot list with descriptions
3. ✅ Version selection with recommendations
4. ✅ Confirmation before download
5. ✅ Progress tracking through all steps
6. ✅ Natural language understanding

**Example conversation:**
```
User: /01-retrieve-bots-metadata

Claude: 
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Einstein Bots → Agentscript Converter  |  Step 1 of 6
  Retrieve Bot Metadata
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Connecting to Salesforce org...
✅  Connected to: orgfarm-cult  (epic.out...@orgfarm.salesforce.com)

Fetching available bots...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AVAILABLE BOTS  (Org: orgfarm-cult)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  #   Bot Name                  Description
  ─   ─────────────────────     ──────────────────────────────────────────
  1   Agent1                    New agent description
  2   B2A_Intent_Enabled        A bot from scratch.
  3   emirates                  A bot from scratch.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Which bot would you like to convert?

User: 2

Claude: ✅  Selected: B2A_Intent_Enabled

Fetching versions...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VERSIONS  —  B2A_Intent_Enabled
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  #   Version     Status      Last Modified
  ─   ─────────   ─────────   ──────────────────
  1   v1          Inactive    12 Mar 2026, 06:46

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Which version would you like to use?

User: v1

Claude: ✅  Selected: v1 (Inactive)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CONFIRM SELECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Bot      : B2A_Intent_Enabled
  Version  : v1  (Inactive)
  Org      : orgfarm-cult

Ready to proceed?

User: yes

Claude: ✅ Confirmed. Downloading metadata for B2A_Intent_Enabled v1...

[Downloads and processes all metadata]

✅  Metadata saved successfully!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Step 1 complete.
  B2A_Intent_Enabled v1  —  metadata downloaded

  Ready to proceed to Step 2: Bot Inventory.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Would you like to proceed to Step 2?
```

**Natural language support:**
- "select bot 2" or "2" or "B2A_Intent_Enabled"
- "select the active version" or "v1" or "1"
- "yes" or "confirm" or "proceed"
- "back" or "quit" at any stage

---

### Method 2: Direct Script

Use the command-line script for automation:

```bash
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh <BOT_NAME> [ORG_ALIAS] [ML_DOMAIN]
```

**Examples:**
```bash
# Interactive mode (shows bot list)
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh interactive orgfarm-cult

# Direct fetch from default org
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh B2A_Intent_Enabled

# Fetch from specific org
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh B2A_Intent_Enabled my-org

# Fetch with custom ML domain
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh B2A_Intent_Enabled my-org CustomIntents
```

---

### Method 3: Use Existing bot.json

If you already have `bot.json` exported from a Salesforce org, simply place it in:
```
data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/jsons/<BOTNAME>.json
```
And skip to Step 2 of the migration pipeline.

---

## Prerequisites

### Required Software

| Tool | Purpose | Check Installation |
|------|---------|-------------------|
| **Salesforce CLI (`sf`)** | Retrieve metadata from orgs | `sf --version` |
| **Python 3.7+** | Run extraction scripts | `python3 --version` |

### Org Authentication

Before fetching, authenticate to your Salesforce org:

```bash
# Production or Developer org
sf org login web --alias my-org

# Sandbox org
sf org login web --alias my-sandbox --instance-url https://test.salesforce.com

# Orgfarm org (Salesforce internal)
sf org login web --alias orgfarm-epic --instance-url https://orgfarm-xxxx.test1.my.pc-rnd.salesforce.com/
```

**Verify authentication:**
```bash
sf org list
```

You should see your org with "Connected" status.

---

## What Gets Fetched

The fetch script retrieves and extracts:

### 1. Bot Structure
- Bot metadata (`Bot:<BotName>`)
- Bot dialogs and dialog groups
- Bot steps (Message, Invocation, Navigation, etc.)
- Conversation variables
- Context variables

### 2. Invocations
- Apex invocations
- Flow invocations
- Standard Invocable Actions
- External Service calls
- Input/output parameters with types

### 3. ML Training Data

#### From Bot's Internal ML Domain
- Intents defined in bot metadata
- Utterances per intent
- Intent descriptions

#### From External ML Domain (if exists)
- Intent Set (e.g., `IntentSets`)
- Additional training utterances
- Shared intents across bots

---

## Step-by-Step Process

### Step 1: Find Your Bot Name

List all bots in your org:

```bash
sf data query --query "SELECT Id, DeveloperName, MasterLabel FROM Bot" --target-org my-org
```

**Use the `DeveloperName`** (not `MasterLabel`) for fetching.

Example output:
```
Id                  DeveloperName        MasterLabel
00DB0000000XXXX     FIT_Bot             FIT Bot
00DB0000000YYYY     Customer_Support    Customer Support Bot
```

Use: `FIT_Bot` (not "FIT Bot")

### Step 2: Check ML Domain (Optional)

If your bot uses an external ML domain, find its name using SF CLI:

```bash
# List all ML domains in org
sf data query --query "SELECT DeveloperName FROM MlDomain" --target-org my-org

# Or check bot metadata after retrieval (Step 3 first)
cat data/sf-cli/main/default/bots/<BOT_NAME>/<BOT_NAME>.bot-meta.json | grep -A5 "relatedMlIntents"
```

**Common ML Domain Names:**
- `IntentSets` (most common - use this as default)
- `Intents`
- `<BotName>Intents`

See `SF_CLI_COMMANDS.md` for more discovery methods.

### Step 3: Run Fetch Script

```bash
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh <BOT_NAME> <ORG_ALIAS> <ML_DOMAIN>
```

**What happens:**
1. ✅ Retrieves bot metadata from org
2. ✅ Retrieves ML domain metadata (if available)
3. ✅ Extracts bot structure to JSON
4. ✅ Converts ML domain XML to JSON
5. ✅ Merges ML training data into bot JSON
6. ✅ Copies result to `data/bot.json`

### Step 4: Verify Output

Check that `data/bot.json` exists and contains expected data:

```bash
ls -lh data/bot.json

# Quick inspection
python3 -c "import json; d=json.load(open('data/bot.json')); print(f\"Bot: {d['Bot']['label']}\"); print(f\"Dialogs: {len(d['Bot']['botVersions'][0]['botDialogs'])}\"); print(f\"Intents: {len(d['Bot']['botMlDomain']['mlIntents'])}\")"
```

---

## Output Files

### Generated Files (New Structure)

After fetching, files are organized in a custom folder:

| File | Location | Purpose |
|------|----------|---------|
| Bot XML | `data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/bots/` | Raw bot metadata from Salesforce |
| ML Domain XML | `data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/mlDomains/` | Raw ML metadata from Salesforce |
| **Bot JSON** | `data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/jsons/<BOTNAME>.json` | **⭐ FINAL OUTPUT - complete bot + ML data** |
| ML Domain JSON | `data/sf-cli/custom/<ORGID_BOTNAME_VERSION>/jsons/<DOMAIN>.json` | Converted ML domain |

### File Relationships

```
data/sf-cli/
  ├─ main/default/                          (SF CLI default structure - untouched)
  │   ├─ bots/<BOT_NAME>/                   (raw retrieved metadata)
  │   └─ mlDomains/                         (raw retrieved ML domains)
  │
  └─ custom/<ORGID_BOTNAME_VERSION>/        (organized output)
      ├─ bots/
      │   ├─ <BOTNAME>.bot-meta.xml         (copied from main/default)
      │   └─ v1.botVersion-meta.xml         (copied from main/default)
      ├─ mlDomains/
      │   └─ IntentSets.mlDomain-meta.xml   (copied from main/default)
      └─ jsons/
          ├─ <BOTNAME>.json  ⭐              (complete: bot + ML merged)
          ├─ IntentSets.json                 (converted ML domain)
          ├─ <BOTNAME>.bot-meta.json        (converted bot metadata)
          └─ v1.botVersion-meta.json        (converted version metadata)
```

**Example folder name:** `00DVW0000075wIf2AI_B2A_Intent_Enabled_v1`
- Org ID: `00DVW0000075wIf2AI`
- Bot name: `B2A_Intent_Enabled`
- Version: `v1`

---

## Common Issues

### Issue: "Bot metadata not found"

**Cause:** Bot doesn't exist or wrong name.

**Fix:**
```bash
# List bots in org
sf data query --query "SELECT DeveloperName FROM Bot" --target-org my-org

# Use exact DeveloperName
```

### Issue: "ML domain metadata not found"

**Cause:** ML domain doesn't exist or wrong name.

**Fix:**
```bash
# Find correct ML domain name
python3 .claude/skills/01-retrieve-bots-metadata/scripts/find_ml_domain.py <BOT_NAME>

# Use recommended domain name
```

**Note:** This is a WARNING, not an error. The script will continue with the bot's internal ML domain.

### Issue: "No authenticated orgs found"

**Cause:** Not logged into Salesforce org.

**Fix:**
```bash
sf org login web --alias my-org
sf org list
```

### Issue: Missing invocations in output

**Cause:** Invocations are in bot XML but not extracted.

**Fix:** Ensure you're using `fetch_bot_from_org.sh` (which calls `extract_bot_metadata.py`), not the simple XML converter.

### Issue: Missing utterances in output

**Cause:** Bot uses external ML domain that wasn't retrieved.

**Fix:**
```bash
# Find ML domain name
python3 .claude/skills/01-retrieve-bots-metadata/scripts/find_ml_domain.py <BOT_NAME>

# Re-run fetch with correct ML domain
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh <BOT_NAME> <ORG> <DISCOVERED_DOMAIN>
```

---

## Advanced Usage

### Manual Step-by-Step Extraction

If you need more control:

```bash
# 1. Retrieve bot metadata
BOT_NAME="FIT_Bot"
ORG="my-org"
sf project retrieve start --metadata Bot:${BOT_NAME} --target-org ${ORG}

# 2. Retrieve ML domain (optional)
sf project retrieve start --metadata MlDomain:IntentSets --target-org ${ORG}

# 3. Convert bot XML to JSON
python3 .claude/skills/01-retrieve-bots-metadata/scripts/convert_bot_xml_to_json.py ${BOT_NAME}

# 4. Extract bot structure (includes ML intent extraction from relatedMlIntents)
python3 .claude/skills/01-retrieve-bots-metadata/scripts/extract_bot_metadata.py ${BOT_NAME}

# 5. Convert ML domain XML (if retrieved)
python3 .claude/skills/01-retrieve-bots-metadata/scripts/convert_ml_domain.py \
  data/sf-cli/main/default/mlDomains/IntentSets.mlDomain-meta.xml

# Note: extract_bot_metadata.py automatically extracts only the referenced intents
# from Intent Sets based on relatedMlIntents field. No separate merge step needed.
```

### Find ML Domain Name

Discover which ML domain a bot references using SF CLI:

```bash
# Method 1: List all ML domains in org
sf data query --query "SELECT DeveloperName FROM MlDomain" --target-org my-org

# Method 2: Check bot metadata after retrieval
cat data/sf-cli/main/default/bots/<BOT_NAME>/<BOT_NAME>.bot-meta.json | grep -A5 "relatedMlIntents"

# Method 3: Try common names
# IntentSets, Intents, <BotName>Intents
```

See `SF_CLI_COMMANDS.md` for comprehensive discovery methods.

### Custom Output Location

```bash
python3 .claude/skills/01-retrieve-bots-metadata/scripts/extract_bot_metadata.py ${BOT_NAME} \
  --output /custom/path/bot.json
```

---

## Integration with Migration Pipeline

### Workflow

```
1. Fetch Bot
   ↓
2. Verify data/bot.json
   ↓
3. Start Migration
   ↓
4. Follow pipeline steps
```

### After Fetching

Once `data/bot.json` is ready:

```bash
# Start the migration pipeline
# Ask Claude: "Start the bot migration"
# Or invoke directly: /00-start-migration
```

The migration pipeline will:
1. Read `data/bot.json`
2. Process bot structure
3. Design agent architecture
4. Generate AgentScript
5. Compile and deploy

---

## Best Practices

### 1. Always Fetch with ML Domain

For complete migration, always include the ML domain:

```bash
bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh <BOT_NAME> <ORG> IntentSets
```

### 2. Verify Bot Name First

Always list bots before fetching:

```bash
sf data query --query "SELECT DeveloperName FROM Bot LIMIT 20" --target-org my-org
```

### 3. Check ML Domain

Try `IntentSets` first (most common), or query ML domains with SF CLI (see `SF_CLI_COMMANDS.md`).

### 4. Verify Output

After fetching, inspect `data/bot.json` to ensure:
- ✅ Bot structure is complete
- ✅ Dialogs are present
- ✅ Invocations are extracted
- ✅ ML intents have utterances

### 5. Keep Intermediate Files

Don't delete files in `force-app/main/default/bots/` - they're useful for debugging and comparison.

---

## Troubleshooting

### Enable Verbose Output

For debugging, run scripts with verbose output:

```bash
# Salesforce CLI verbose mode
export SF_LOG_LEVEL=debug
sf project retrieve start --metadata Bot:${BOT_NAME} --target-org ${ORG}
```

### Check Retrieved Files

After retrieval, verify files exist:

```bash
ls -la data/sf-cli/main/default/bots/<BOT_NAME>/
ls -la data/sf-cli/main/default/mlDomains/
```

### Compare with Reference

If you have a reference bot.json, compare:

```bash
python3 .claude/skills/01-retrieve-bots-metadata/scripts/extract_bot_metadata.py ${BOT_NAME} --compare
```

---

## Next Steps

After successfully fetching bot data:

1. ✅ Verify `data/bot.json` exists
2. ✅ Inspect bot structure (dialogs, intents, invocations)
3. ✅ Start migration pipeline: `/00-start-migration`
4. ✅ Follow pipeline checkpoints (Step 1, Step 2, Step 6)
5. ✅ Deploy migrated agent to org

---

## Reference

### Script Locations

| Script | Purpose |
|--------|---------|
| `fetch_bot_from_org.sh` | Main wrapper (orchestrates all steps) |
| `list_bots_interactive.py` | Interactive bot selector with formatted display |
| `convert_bot_xml_to_json.py` | Bot XML → JSON converter (handles arrays/booleans) |
| `extract_bot_metadata.py` | Core extraction engine (extracts only referenced ML intents) |
| `convert_ml_domain.py` | ML domain XML → JSON converter |
| `compare_bot_jsons.py` | Validation tool for comparing bot JSONs |

### File Formats

**Input:** Einstein Bot metadata (XML)
- `<BotName>.bot-meta.xml`
- `*.botVersion-meta.xml`
- `<MlDomain>.mlDomain-meta.xml`

**Output:** Bot JSON (cult.json format)
- Complete bot structure
- All invocations with parameters
- ML intents with utterances
- Ready for migration pipeline

---

## Support

For issues or questions:
- Check this guide first
- Review [TROUBLESHOOTING.md](../../../docs/TROUBLESHOOTING.md)
- Inspect intermediate files in `data/sf-cli`
- Use SF CLI to query ML domains (see `SF_CLI_COMMANDS.md`)
