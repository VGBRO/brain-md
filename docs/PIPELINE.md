# Bot-to-NGA Agent Migration Pipeline — Detailed Reference

This document covers each pipeline step for **Einstein Bot to NGA Agent** migration, including intermediate artifacts and recovery instructions.

## Step-by-Step Usage

### Step 0: Start Migration

**Skill**: `00-start-migration`

The entry point to the pipeline. Explains the full migration process, runs prerequisite checks, and launches Step 1 when everything is ready.

**What it does:**
- Presents the 6-step pipeline overview
- Verifies all tools are installed (Node.js, Python 3.8+, uv, Salesforce CLI)
- If any tools are missing, suggests installation commands for your OS
- Checks for authenticated Salesforce orgs (if needed for deployment)
- Tests compiler dependency access
- Reports readiness and hands off to Step 1

**User interaction required:**
- Install missing prerequisites if prompted
- Place bot.json in data/ directory
- Resolve any remaining issues before the pipeline begins

**Output:** Environment readiness report

---

### Step 1: Retrieve Bot Metadata

**Skill**: `01-retrieve-bot-metadata`

Processes Einstein Bot metadata JSON, preprocesses dialog structures, extracts intents and invocations, and generates comprehensive inventory.

**What it does:**
- Reads `data/bot.json` (exported Einstein Bot metadata)
- Parses dialog structure (dialogs, dialog groups, bot steps)
- Extracts actions/invocations (Apex, Flow, API, Standard Invocable Actions)
- Processes ML intents and utterances
- Maps dialog navigation flows (Redirect, Call, Intent_Redirect)
- Classifies preliminary topics (groups related dialogs/actions)
- Writes `migration-inventory.md` with complete bot structure
- Generates `preprocessed_bot.json`, `intent_digest.json`, `topic_classification.json`

**User interaction required:**
- Confirm bot.json is the correct bot to migrate
- Confirm the inventory looks correct (dialog counts, action counts, intents)

**Output:** 
- `migration-inventory.md` at project root
- `data/preprocessed_bot.json` — Structured bot data
- `data/intent_digest.json` — Intent summaries
- `data/topic_classification.json` — Preliminary topic groupings

**Bot-Specific Parsing:**
- Dialog steps: message, variable_operation, invocation, navigation, wait
- Navigation types: Redirect (permanent handoff), Call (return to caller), Intent_Redirect (route by intent)
- Variable types: conversation variables (→ mutable), context variables (→ linked)

---

### Step 2: Design Agent Architecture

**Skill**: `02-design-agent-architecture`

Analyzes bot structure and consults `AGENT_SCRIPT_RULES.md` + `AGENT_SCRIPT_RECIPES.xml` to design an optimal NGA Agent architecture.

**What it does:**
- Maps Einstein Bot constructs to AgentScript patterns:
  - **Dialogs → Topics**: Groups related dialogs by entity, variables, dialog groups, intents
  - **Bot Steps → Reasoning**: Deterministic steps become AI-guided reasoning instructions
  - **Invocations → Actions**: Preserve action names and targets exactly
  - **Intents → Topic Router**: Creates dedicated intent routing topic
  - **Navigation → Transitions**: Redirect/Call/Intent_Redirect map to topic transitions
- Maps bot data types to AgentScript types (using `LEGACY_TYPE_MAPPINGS.md`)
- Identifies all variables:
  - Conversation variables → mutable
  - Context variables → linked (with source:)
  - Action outputs feeding downstream → mutable
- Designs topic structure (max 7 actions per topic, split if needed)
- Creates `agent_entrypoint` (entry point + welcome) and `topic_router` (intent routing)
- Maps conditional logic to `available when` guards or `if/else` blocks
- Preserves action targets exactly (no renaming)
- Selects best recipe patterns for each topic

**User interaction required:**
- Provide the new agent name (e.g., `agent_emirates`)
- Provide agent label (e.g., "Emirates Airlines NGA Agent")
- Review and approve the architecture plan

**Output:** `migration-architecture.md` at the project root

**Bot-Specific Architecture Decisions:**
- Dialog-to-topic mapping strategy (entity focus, shared variables, dialog groups)
- Navigation type conversion (Redirect → transition, Call → inline, Intent_Redirect → topic_router)
- Intent routing design (keyword-rich transition descriptions matching utterances)
- Variable lifecycle mapping (conversation → mutable, context → linked)

---

### Step 3: Scaffold AgentScript

**Skill**: `03-scaffold-agentscript`

Creates the directory structure and initial `.agent` file with the foundational blocks.

**What it does:**
- Creates `force-app/main/default/aiAuthoringBundles/<AgentName>/`
- Generates `<AgentName>.bundle-meta.xml` (required metadata file)
- Generates the `<AgentName>.agent` file with:
  - **config:** block — agent name, label, type, description
  - **variables:** block — all mutable and linked variables (from bot conversation/context vars)
  - **system:** block — welcome message (from entry dialogs), error message, global instructions
  - **start_agent:** block — `agent_entrypoint` topic with transitions to other topics

**Output:** `<AgentName>.agent` file with scaffold blocks, ready for topic migration

**Bot-Specific Scaffolding:**
- Agent name derived from bot developer name
- Variables mapped from bot conversation variables (mutable) and context variables (linked)
- Welcome message extracted from bot entry dialog messages
- Entry point routing based on bot dialog graph and intents

---

### Step 4: Migrate Agent Topics

**Skill**: `04-migrate-agent-topics`

The core migration engine for bot-to-NGA conversion. Generates complete AgentScript topic blocks one at a time.

**What it does:**
- For each planned topic:
  - **Converts bot dialog steps to reasoning:**
    - Message steps → pipe text instructions
    - Invocation steps → action calls with slot filling and output capture
    - Variable operation steps → inline assignments or action parameters
    - Navigation steps → topic transitions (Redirect → transition, Call → inline, Intent_Redirect → topic_router)
    - Wait steps → implicit in reasoning loop (LLM handles naturally)
    - Conditional steps → if/else blocks or available when guards
  - **Converts bot actions to AgentScript action definitions:**
    - Preserves action names exactly (strip ID suffixes only)
    - Maps invocation targets to target: format (apex://, flow://, standardInvocableAction://, etc.)
    - Maps input/output parameters with types and complex_data_type_name
    - Preserves confirmation requirements
  - **Implements navigation flows:**
    - Redirect → after_reasoning transitions
    - Call → before_reasoning or inline actions
    - Intent_Redirect → transition to topic_router
  - **Applies recipe patterns:**
    - Consults AGENT_SCRIPT_RECIPES.xml for optimal implementations
    - Uses idiomatic AgentScript (not naive 1:1 copy)
- Processes topics ONE AT A TIME to manage context limits
- Verifies content preservation (all dialog steps, actions, transitions implemented)

**Bot-Specific Topic Migration:**
- Dialog step classification (message/invocation/navigation/variable/wait/conditional)
- Deterministic bot logic → AI-guided reasoning instructions
- Sequential bot steps → structured reasoning with control flow
- Bot variables → mutable/linked agent variables with proper scoping
  - Preserves confirmation-required action logic
  - Handles shared and planner-level actions
- Verifies zero functional loss via a completeness checklist

**Output:** Complete `.agent` file with all topic blocks appended

---

### Step 5: Compile AgentScript

**Skill**: `05-compile-agentscript`

Runs the local compiler in a self-healing loop, automatically diagnosing and fixing errors.

**What it does:**
- Runs `uv run --refresh --native-tls skills/00-start-migration/scripts/compile_agentscript.py <path>`
- If errors occur, diagnoses them by category (indentation, invalid names, duplicates, undefined references, type mismatches, etc.)
- Applies targeted fixes and re-compiles
- Loops up to 30 times or until compilation succeeds
- Distinguishes real errors from known library bugs (`developer_name=None`)

**Output:** Validated `.agent` file ready for deployment

---

### Step 6: Deploy AgentScript

**Skill**: `06-deploy-agentscript`

Deploys the compiled agent to your Salesforce org with mandatory human confirmation.

**What it does:**
- Displays full org details (Org ID, username, instance URL, org type)
- Requires explicit YES/NO confirmation before any deployment
- Publishes the agent via `sf agent publish authoring-bundle`
- If publish fails, enters a self-healing loop (max 15 retries): fix, re-compile, re-publish
- Verifies the agent appears in the org after successful publish

**User interaction required:**
- Explicit deployment confirmation after reviewing org details

**Output:** Live `aiAuthoringBundle` agent in your Salesforce org

## Intermediate Artifacts

The pipeline produces these intermediate files at the project root during migration:

| File | Produced By | Consumed By | Purpose |
|------|------------|------------|---------|
| `migration-inventory.md` | Step 1 | Steps 2, 4 | Complete structural inventory of the legacy agent |
| `migration-architecture.md` | Step 2 | Steps 3, 4, 5, 6 | Target architecture plan with variable/topic/routing design |
| `force-app/.../AgentName.agent` | Steps 3-5 | Step 6 | The AgentScript source file |

These files serve as the communication layer between skills, allowing each step to operate independently with clear inputs and outputs.

## Pipeline Recovery

If the migration is interrupted at any point, you can resume from the last successful step without starting over:

| Resume From | Required Artifact | Skill to Invoke |
|-------------|------------------|-----------------|
| Step 0 | _(none)_ | `00-start-migration` |
| Step 1 | _(none)_ | `01-retrieve-legacy-agent` |
| Step 2 | `migration-inventory.md` | `02-design-agent-architecture` |
| Step 3 | `migration-architecture.md` | `03-scaffold-agentscript` |
| Step 4 | Scaffolded `.agent` file + architecture doc | `04-migrate-agent-topics` |
| Step 5 | Complete `.agent` file with all topics | `05-compile-agentscript` |
| Step 6 | Compiled `.agent` file | `06-deploy-agentscript` |

To resume, verify the required artifact exists, then invoke the corresponding skill directly.

## Compiling AgentScript Locally

You can run the compiler manually at any time:

```bash
uv run --refresh --native-tls skills/00-start-migration/scripts/compile_agentscript.py path/to/YourAgent.agent
```

The compiler has three possible outcomes:

| Output | Meaning |
|--------|---------|
| `Successfully compiled Agent Script.` | No errors. |
| `Successfully compiled Agent Script (library warnings present...)` | No errors in your code. Known library bugs in dependencies are informational only. |
| `Parse errors in ...` / `Compile errors in ...` | Real errors that need fixing. Line numbers and context are shown. |

The authoritative validator is always `sf agent publish` — the local compiler catches most issues but the server-side compiler is definitive.
