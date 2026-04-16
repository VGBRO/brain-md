# Bot-to-NGA Agent Migration Pipeline — Detailed Reference

This document covers each pipeline step for **Einstein Bot to NGA Agent** migration, including intermediate artifacts, bot-specific transformations, and recovery instructions.

## Pipeline Overview

The migration pipeline consists of 6 core steps that transform Einstein Bot metadata into Salesforce NGA (Next Generation AI) AgentScript format:

```
Step 0 → Step 1 → Step 2 → Step 3 → Step 4 → Step 5 → Step 6
  ↓        ↓        ↓        ↓        ↓        ↓        ↓
Start   Retrieve Process   Map     Generate Compile Deploy
Migration  Bot   & Build  Dialogs  Agent-   Agent-   to
         Metadata Inventory to      script   script   Org
                           Topics
```

---

## Step-by-Step Usage

### Step 0: Start Migration

**Skill**: `00-start-migration`

The entry point to the pipeline. Explains the full migration process, runs prerequisite checks, and launches Step 1 when everything is ready.

**What it does:**
- Presents the 6-step pipeline overview
- Verifies all tools are installed (Node.js, Python 3.8+, uv, Salesforce CLI)
- If any tools are missing, suggests installation commands for your OS
- Checks for authenticated Salesforce orgs (if needed for deployment)
- Tests compiler dependency access (Salesforce Nexus PyPI proxy)
- Reports readiness and hands off to Step 1

**User interaction required:**
- Install missing prerequisites if prompted
- Place `bot.json` in `data/` directory
- Resolve any remaining issues before the pipeline begins

**Output:** Environment readiness report

**Command to invoke:**
```
Ask Claude: "Start the bot migration"
```
or directly: `/00-start-migration`

---

### Step 1: Retrieve Bot Metadata

**Skill**: `01-retrieve-bots-metadata`

Processes Einstein Bot metadata JSON, preprocesses dialog structures, extracts intents and invocations, and generates comprehensive inventory.

**What it does:**
- Reads `data/bot.json` (exported Einstein Bot metadata)
- Parses dialog structure (dialogs, dialog groups, bot steps)
- Extracts actions/invocations (Apex, Flow, API, Standard Invocable Actions)
- Processes ML intents and utterances
- Maps dialog navigation flows (Redirect, Call, Intent_Redirect)
- Classifies preliminary topics (groups related dialogs/actions)
- Writes `migration-inventory.md` with complete bot structure
- Generates preprocessed artifacts for downstream steps

**User interaction required:**
- Confirm `bot.json` is the correct bot to migrate
- Confirm the inventory looks correct (dialog counts, action counts, intents)

**Output:** 
- `migration-inventory.md` at project root — Complete bot structure analysis
- `data/preprocessed_bot.json` — Structured bot data with dialogs and actions
- `data/intent_digest.json` — Intent summaries from ML intents
- `data/topic_classification.json` — Preliminary topic groupings

**Bot-Specific Parsing:**
- Dialog steps: message, variable_operation, invocation, navigation, wait
- Navigation types: 
  - **Redirect** — Permanent handoff to target dialog
  - **Call** — Execute target, return to caller
  - **Intent_Redirect** — Route by user intent
- Variable types: 
  - Conversation variables → `mutable` in AgentScript
  - Context variables → `linked` in AgentScript

---

### Step 2: Process and Build Inventory

**Skill**: `02-process-and-build-inventory`

Analyzes bot structure and designs an optimal NGA Agent architecture by mapping Einstein Bot constructs to AgentScript patterns.

**What it does:**
- Maps Einstein Bot constructs to AgentScript patterns:
  - **Dialogs → Topics**: Groups related dialogs by entity, shared variables, dialog groups, and intents
  - **Bot Steps → Reasoning**: Transforms deterministic bot steps into AI-guided reasoning instructions
  - **Invocations → Actions**: Preserves action names and targets exactly
  - **Intents → Topic Router**: Creates dedicated intent routing topic
  - **Navigation → Transitions**: Maps Redirect/Call/Intent_Redirect to AgentScript transitions
- Maps bot data types to AgentScript types (using type mappings reference)
- Identifies all variables and their scope:
  - Conversation variables → `mutable`
  - Context variables → `linked` (with source:)
  - Action outputs feeding downstream steps → `mutable`
- Designs topic structure (max 7 actions per topic, split if needed)
- Creates `agent_entrypoint` (entry point + welcome) and `topic_router` (intent routing)
- Maps conditional logic to `available when` guards or `if/else` blocks
- Selects best recipe patterns for each topic

**Grouping Criteria** (highest priority first):
1. Actions working on the same underlying entity **should** be grouped
2. Actions updating/writing the same variable **most likely** should be grouped
3. Actions consuming/reading the same variable **most likely** should be grouped
4. Actions from same dialog group **likely** should be grouped
5. Actions with similar intentions **can** be grouped

**User interaction required:**
- Provide the new agent name (e.g., `agent_customer_support`)
- Provide agent label (e.g., "Customer Support NGA Agent")
- Review and approve the architecture plan

**Output:** `migration-architecture.md` at the project root — Complete architecture design

**Bot-Specific Architecture Decisions:**
- Dialog-to-topic mapping strategy (entity focus, shared variables, dialog groups)
- Navigation type conversion:
  - Redirect → `after_reasoning` transition
  - Call → inline or `before_reasoning`
  - Intent_Redirect → transition to `topic_router`
- Intent routing design (keyword-rich transition descriptions matching utterances)
- Variable lifecycle mapping (conversation → `mutable`, context → `linked`)

---

### Step 3: Map Dialogs and Actions to Topics

**Skill**: `03-map-dialogs-actions-to-topics`

Generates topic classifications by analyzing action groupings, dialog associations, and intent patterns.

**What it does:**
- Reads preprocessed bot data and architecture plan
- Groups actions/tools into topics based on:
  - Underlying entity
  - Shared variables (read/write)
  - Dialog group membership
  - Similar intentions
- Maintains max 7 actions per topic (splits if necessary)
- Traces back dialogs associated with each action
- Builds action-to-dialog mapping for each topic
- Generates 2-3 sentence natural language description for each topic
- **Important**: An action can belong to multiple topics if criteria demand it

**Output:** 
- `data/topic_classification.json` — Final topic structure with:
  - Topic descriptions
  - Associated dialogs
  - Associated actions
  - Action-to-dialog mappings

**Topic Classification Format:**
```json
{
    "topics": {
        "<topic_name>": {
            "description": "Natural language description of topic purpose",
            "associated_dialogs": ["Dialog_1", "Dialog_2"],
            "associated_actions": ["Action_1", "Action_2"],
            "action_dialog_mapping": {
                "<action_name>": ["Dialog_List"]
            }
        }
    }
}
```

---

### Step 4: Generate AgentScript

**Skill**: `04-generate-agentscript`

The core migration engine for bot-to-NGA conversion. Generates the complete AgentScript file from topics, bot metadata, and architecture plan.

**What it does:**

#### 4.1 Generate Config Section
- Creates `agent_name` from hash of bot ID and version
- Sets up agent metadata (type, label, description)

#### 4.2 Generate Variables Section
- Retains context variables from bot as `linked` variables
- Creates `mutable` variables for conversation state
- Maps bot variable types to AgentScript types

#### 4.3 Generate Knowledge Section
- Checks for Knowledge Feedback dialog
- Configures RAG feature if knowledge base exists
- Adds placeholders for org-specific configuration

#### 4.4 Generate Topics
- **Creates topics from pre-selected classifications:**
  - Generates `actions:` section for each tool/invocation
  - Maps targets: `apex://`, `flow://`, `standardInvocableAction://`, etc.
  - Populates inputs/outputs with correct types and `complex_data_type_name`
  - Generates `reasoning:` section with:
    - Instructions (1-2 line summary of when to use each action)
    - Action calls with input/output variable mappings
    - Conditions (`available when`) based on variable state
  
- **Creates routing topics:**
  - `agent_entrypoint` (marked as `start_agent`) — Entry point with welcome
  - `topic_router` — Intent-based routing to appropriate topics
  
- **Traverses bot metadata in DFS manner** starting from Welcome dialog:
  - Follows transitions (call/redirect/intent_redirect)
  - Stops at dialogs already in pre-selected topics
  - Groups similar paths
  - Creates topics for meaningful groups with transitions
  
- **Generates before_reasoning and after_reasoning sections:**
  - Actions executed before decision-making → `before_reasoning`
  - Actions executed after decision-making → `after_reasoning`
  
- **Topic consolidation:**
  - Merges topics without actions or with similar descriptions
  - Prioritizes entity and intention similarity

#### 4.5 Generate System Section
- Creates generic system instruction reflecting:
  - AI-powered orchestrator role
  - Summary of all topic functionalities

#### 4.6 Validations
- Ensures AgentScript adheres to syntax rules
- Verifies transitions point to existing topics
- Consolidates comments at start
- Validates action input/output mappings
- Ensures all topics are reachable from `start_agent`

**Bot-to-AgentScript Transformations:**

| Bot Step Type | AgentScript Pattern |
|--------------|-------------------|
| Message | Reasoning instructions (pipe text: `\| message content`) |
| Invocation | Action calls with slot filling and output capture |
| Variable Operation | Inline assignments (`set @variables.name = value`) or action parameters |
| Navigation (Redirect) | `after_reasoning` transition to target topic |
| Navigation (Call) | `before_reasoning` or inline action execution |
| Navigation (Intent_Redirect) | Transition to `topic_router` topic |
| Wait | Implicit in reasoning loop (LLM handles naturally) |
| Conditional | `if/else` blocks or `available when` guards |

**Output:** Complete `.agent` file at `force-app/main/default/aiAuthoringBundles/<AgentName>/<AgentName>.agent`

---

### Step 5: Compile AgentScript

**Skill**: `05-compile-agentscript`

Runs the local compiler in a self-healing loop, automatically diagnosing and fixing errors.

**What it does:**
- Runs `compile_agentscript_nexus_ts.py <path>` (TypeScript-based Nexus compiler)
- If errors occur, diagnoses them by category (indentation, invalid names, duplicates, undefined references, type mismatches, etc.)
- Applies targeted fixes and re-compiles
- Loops up to 30 times or until compilation succeeds
- Distinguishes real errors from known library bugs (`developer_name=None`)

**Output:** Validated `.agent` file ready for deployment
- If errors occur, diagnoses them by category:
  - Indentation errors
  - Invalid identifiers
  - Duplicate names
  - Undefined references
  - Type errors
  - Missing required fields
  - Invalid target format
  - Reasoning syntax errors
- Applies targeted fixes and re-compiles
- Loops up to 30 times or until compilation succeeds
- Distinguishes real errors from known library bugs (`developer_name=None`)
- Fixes all linter errors before proceeding

**Error Diagnosis Authority:**
- **Primary**: `.claude/skills/00-start-migration/assets/AGENT_SCRIPT_RULES.md` — Authoritative AgentScript syntax and rules
- **Secondary**: `.claude/skills/00-start-migration/assets/AGENT_SCRIPT_RECIPES.xml` — Working examples
- **NO WEB SEARCH ALLOWED** — All diagnosis must use local files only

**Compiler Outcomes:**

| Output | Meaning |
|--------|---------|
| `Successfully compiled Agent Script.` | No errors |
| `Successfully compiled Agent Script (library warnings present...)` | No errors in your code (library warnings are informational) |
| `Parse errors in ...` / `Compile errors in ...` | Real errors requiring fixes |

**Output:** Validated `.agent` file ready for deployment

**Note:** The local compiler catches most issues, but `sf agent publish` is the authoritative validator.

---

### Step 6: Deploy Agent to Org

**Skill**: `06-deploy-agent-to-org`

Deploys the compiled agent to your Salesforce org with mandatory human confirmation.

**What it does:**
- Verifies no linter errors remain in `.agent` file
- Displays full org details:
  - Org ID, username, instance URL, org type
  - Agent name and source path
- **Requires explicit YES/NO confirmation before any deployment**
- Verifies `.bundle-meta.xml` exists (creates if missing):
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <AiAuthoringBundle xmlns="http://soap.sforce.com/2006/04/metadata">
      <bundleType>AGENT</bundleType>
  </AiAuthoringBundle>
  ```
- Publishes the agent via `sf agent publish authoring-bundle` (deploys + publishes in one step)
- If publish fails, enters a self-healing loop (max 15 retries):
  - Diagnoses publish error
  - Fixes `.agent` file
  - Re-compiles locally
  - Retries publish
- Verifies the agent appears in the org after successful publish

**Common Publish Errors:**

| Error | Fix |
|-------|-----|
| Invalid `complex_data_type_name` | Read legacy schema, set correct type from `LEGACY_TYPE_MAPPINGS.md` |
| Invalid data type for parameter | Change base type to `object`, add `complex_data_type_name` |
| Missing output/input parameters | Add missing parameter from legacy schema |
| Invalid (phantom) parameters | Remove parameter that doesn't exist on source action |
| "A source action is required" | Add `source:` field for standard actions |
| Invalid action target | Deploy missing Flow/Apex component to org first |
| Schema validation failure | Fix parameters to match legacy schema |
| Invalid variable reference | Add variable or fix reference |

**User interaction required:**
- Explicit deployment confirmation after reviewing org details (YES/NO)

**Safety Rules:**
- NEVER deploy without explicit user confirmation
- NEVER skip confirmation step
- NEVER force-deploy over existing bundles without warning
- Wait up to 5 minutes for `sf` CLI commands to complete

**Output:** Live `aiAuthoringBundle` agent in your Salesforce org

**Migration Complete Summary:**
- Source: Einstein Bot (botVersions metadata)
- Target: NGA Agent (aiAuthoringBundle / AgentScript)
- Topics migrated
- Actions migrated
- Variables defined
- Publish iterations

---

## Intermediate Artifacts

The pipeline produces these intermediate files during migration:

| File | Location | Produced By | Consumed By | Purpose |
|------|----------|------------|-------------|---------|
| `bot.json` | `data/` | User (manual) | Step 1 | Exported Einstein Bot metadata |
| `preprocessed_bot.json` | `data/` | Step 1 | Steps 2, 3, 4 | Structured bot data (dialogs, actions) |
| `intent_digest.json` | `data/` | Step 1 | Steps 2, 4 | Intent summaries from ML intents |
| `topic_classification.json` | `data/` | Step 3 | Step 4 | Final topic structure with mappings |
| `migration-inventory.md` | Project root | Step 1 | Steps 2, 3, 4 | Complete structural inventory |
| `migration-architecture.md` | Project root | Step 2 | Steps 3, 4, 5, 6 | Target architecture plan |
| `<AgentName>.agent` | `force-app/.../aiAuthoringBundles/` | Steps 4-5 | Step 6 | The AgentScript source file |
| `<AgentName>.bundle-meta.xml` | `force-app/.../aiAuthoringBundles/` | Step 6 | Step 6 | Salesforce metadata file |

These files serve as the communication layer between skills, allowing each step to operate independently with clear inputs and outputs.

---

## Pipeline Recovery

If the migration is interrupted at any point, you can resume from the last successful step without starting over:

| Resume From | Required Artifact | Skill to Invoke |
|-------------|------------------|-----------------|
| Step 0 | _(none)_ | `00-start-migration` |
| Step 1 | `data/bot.json` | `01-retrieve-bots-metadata` |
| Step 2 | `migration-inventory.md`, `data/preprocessed_bot.json` | `02-process-and-build-inventory` |
| Step 3 | `migration-architecture.md` | `03-map-dialogs-actions-to-topics` |
| Step 4 | `data/topic_classification.json`, architecture doc | `04-generate-agentscript` |
| Step 5 | Complete `.agent` file with all topics | `05-compile-agentscript` |
| Step 6 | Compiled `.agent` file (no errors) | `06-deploy-agent-to-org` |

**To resume:** Verify the required artifact exists and is not corrupted, then invoke the corresponding skill directly. If an artifact is missing or incorrect, re-run the skill that produces it.

---

## Compiling AgentScript Locally

using the Python wrapper:

```bash
python3 compile_agentscript_nexus_ts.py path/to/YourAgent.agent
```

**Requirements:**
- `python3` package manager installed
- Network access to Salesforce Nexus PyPI proxy


The compiler has three possible outcomes:

| Output | Meaning |
|--------|---------|
| `Successfully compiled Agent Script.` | No errors. Ready for deployment. |
| `Successfully compiled Agent Script (library warnings present...)` | No errors in your code. Known library bugs in dependencies are informational only. |
| `Parse errors in ...` / `Compile errors in ...` | Real errors that need fixing. Line numbers and context are shown. |

**Note:** The authoritative validator is always `sf agent publish` — the local compiler catches most issues but the server-side compiler is definitive.

---

## Einstein Bot to AgentScript Mapping Reference

### Variable Mappings

| Bot Variable Type | AgentScript Type | Notes |
|------------------|-----------------|-------|
| Conversation Variable | `mutable` | Runtime state that can be modified |
| Context Variable | `linked` | Sourced from external systems (with `source:`) |
| Action Output (used downstream) | `mutable` | Captured and used in subsequent steps |

### Navigation Mappings

| Bot Navigation Type | AgentScript Pattern | Behavior |
|--------------------|-------------------|----------|
| Redirect | `after_reasoning` transition | Permanent handoff to target topic |
| Call | `before_reasoning` or inline | Execute target, return to caller |
| Intent_Redirect | Transition to `topic_router` | Route based on user intent |

### Dialog Step Mappings

| Bot Step Type | AgentScript Pattern | Example |
|--------------|-------------------|---------|
| Message | Reasoning instructions (pipe text) | `\| Greet the user and ask how you can help` |
| Invocation | Action call with slot filling | `call @actions.lookup_user` |
| Variable Operation (Set) | Assignment statement | `set @variables.user_id = @outputs.user.id` |
| Variable Operation (Collect) | Reasoning + action | `\| Ask for booking ID` + `call @actions.get_input` |
| Navigation (Redirect) | `after_reasoning` transition | `transition to: @topic.process_order` |
| Navigation (Call) | `before_reasoning` action | `call @actions.validate_user` |
| Navigation (Intent_Redirect) | Transition to router | `transition to: @topic.topic_router` |
| Wait | Implicit in reasoning loop | LLM handles naturally |
| Conditional | `if/else` or `available when` | `if @variables.is_authenticated:` |
| System Message (Transfer) | System action | `call @actions.transfer_to_agent` |
| System Message (EndChat) | System action | `call @actions.end_conversation` |
| Record Lookup | Action with query | `call @actions.query_records` |

### Action Target Mappings

| Bot Invocation Type | AgentScript Target Format |
|--------------------|--------------------------|
| Apex | `"apex://ClassName"` |
| Flow | `"flow://FlowName"` |
| Standard Invocable Action | `"standardInvocableAction://ActionName"` |
| External Service | `"externalService://ServiceName"` |
| Quick Action | `"quickAction://ActionName"` |
| API | `"api://EndpointName"` |
| Apex REST | `"apexRest://EndpointName"` |

**Note:** Always preserve the exact target name from bot metadata — do not rename, re-case, or reformat.

---

## Best Practices

### During Migration

1. **Always start with Step 0** to verify prerequisites
2. **Review inventory carefully** at Step 1 to ensure bot structure is correct
3. **Provide meaningful agent names** at Step 2 (e.g., `agent_customer_support`)
4. **Test locally** with compiler before deploying
5. **Confirm org details** at Step 6 before deployment

### After Migration

1. **Open Agentforce Builder** and verify the agent's configuration
2. **Test with sample conversations** from the original bot
3. **Compare behavior** against the legacy bot
4. **Activate the agent** when satisfied with testing
5. **Monitor performance** and iterate as needed

### Troubleshooting

- **Compilation errors**: Check `.claude/skills/00-start-migration/assets/AGENT_SCRIPT_RULES.md` for syntax
- **Publish errors**: Read error message carefully — most are schema mismatches
- **Missing actions**: Ensure Flows/Apex classes are deployed to org
- **Variable errors**: Verify variable types match expected formats
- **Linter errors**: Fix all IDE warnings before deployment

---

## Additional Resources

- **AGENT_SCRIPT_RULES.md** — Authoritative AgentScript syntax reference (in `.claude/skills/00-start-migration/assets/`)
- **AGENT_SCRIPT_RECIPES.xml** — Working AgentScript examples (in `.claude/skills/00-start-migration/assets/`)
- **LEGACY_TYPE_MAPPINGS.md** — Bot-to-AgentScript type mappings (in `.claude/skills/00-start-migration/assets/`)
- **TROUBLESHOOTING.md** — Common issues and solutions (in `docs/`)
- **CONTRIBUTING.md** — Contribution guidelines (in `docs/`)

---

**Version:** 2.0-bot  
**Last Updated:** 2026-04-17  
**Pipeline Steps:** 6 core steps (0-6)
