# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an automated migration pipeline for converting Salesforce **Einstein Bots** (rule-based chatbots) to **NGA Agents** (Next Generation AI Agents) using the AgentScript format. The pipeline transforms legacy bot metadata—dialogs, intents, actions, and navigation flows—into modern AI-guided agents that leverage LLM reasoning.

## Pipeline Architecture

The migration follows a **6-step sequential pipeline** implemented as Claude Code skills:

```
Step 0: Start Migration (prerequisite checks)
   ↓
Step 1: Retrieve Bot Metadata (parse bot.json, generate inventory)
   ↓
Step 2: Process & Build Inventory (design architecture, map bot → agent patterns)
   ↓
Step 3: Map Dialogs/Actions to Topics (scaffold .agent file structure)
   ↓
Step 4: Generate AgentScript (core transformation engine)
   ↓
Step 5: Compile AgentScript (self-healing validation loop)
   ↓
Step 6: Deploy Agent to Org (publish with human confirmation)
```

Each step is implemented as a **skill** in `.claude/skills/<NN>-<step-name>/` and produces intermediate artifacts that the next step consumes.

## Key Components

### Skills (`.claude/skills/`)
- **00-start-migration** — Entry point, verifies prerequisites (Node.js, `sf` CLI, `uv`, org auth)
- **01-retrieve-bots-metadata** — Parses `data/bot.json`, extracts dialogs/intents/actions, outputs `migration-inventory.md`
- **02-process-and-build-inventory** — Designs agent architecture, maps bot constructs to AgentScript patterns, outputs `migration-architecture.md`
- **03-map-dialogs-actions-to-topics** — Groups actions into topics (max 7 actions per topic), outputs `data/topic_classification.json`
- **04-generate-agentscript** — Core engine that transforms bot steps into AgentScript topics (reasoning, actions, transitions), outputs `.agent` file
- **05-compile-agentscript** — Runs local compiler in self-healing loop (max 30 iterations), auto-fixes errors
- **06-deploy-agent-to-org** — Deploys via `sf agent publish authoring-bundle` with mandatory human confirmation (max 15 retries)
- **07-generate-agent-tests** — Generates test scenarios from bot utterances
- **08-execute-agent-tests** — Runs tests against deployed agent
- **09-generate-roi-report** — Produces migration summary report

### Reference Assets (`.claude/skills/00-start-migration/assets/`)
These files are **authoritative** for all AgentScript generation and compilation:
- **`AGENT_SCRIPT_RULES.md`** — Official AgentScript syntax and structural rules (MUST be consulted by all generation skills)
- **`AGENT_SCRIPT_RECIPES.xml`** — Working AgentScript examples demonstrating patterns
- **`LEGACY_TYPE_MAPPINGS.md`** — Bot-to-AgentScript type mappings (takes precedence over rules file for legacy types)

### Compiler
- **`scripts/compile_agentscript_nexus_ts.py`** — Python wrapper around TypeScript-based `@agentscript/cli` compiler from Nexus npm registry
- Requires Node.js 18+, `tree-sitter-cli`, and network access to Salesforce Nexus PyPI/npm proxies

### Intermediate Artifacts
| File | Produced By | Consumed By | Purpose |
|------|------------|-------------|---------|
| `data/bot.json` | User (manual export) | Step 1 | Source Einstein Bot metadata |
| `migration-inventory.md` | Step 1 | Steps 2-4 | Complete bot structure analysis |
| `data/preprocessed_bot.json` | Step 1 | Steps 2-4 | Structured bot data |
| `data/intent_digest.json` | Step 1 | Steps 2, 4 | Intent summaries |
| `migration-architecture.md` | Step 2 | Steps 3-6 | Target architecture plan |
| `data/topic_classification.json` | Step 3 | Step 4 | Final topic structure with action-to-dialog mappings |
| `force-app/.../aiAuthoringBundles/<AgentName>/<AgentName>.agent` | Steps 4-5 | Step 6 | The AgentScript source file |
| `force-app/.../<AgentName>.bundle-meta.xml` | Step 6 | Step 6 | Salesforce metadata |

## Core Transformations (Bot → Agent)

### Variables
- **Conversation variables** → `mutable` (runtime state)
- **Context variables** → `linked` (with `source:` field)
- **Action outputs used downstream** → `mutable`

### Navigation
- **Redirect** → `after_reasoning` transition (permanent handoff)
- **Call** → `before_reasoning` or inline action (execute and return)
- **Intent_Redirect** → Transition to `topic_router` topic

### Dialog Steps
- **Message** → Reasoning instructions (`| text`)
- **Invocation** → Action call with slot filling (`call @actions.action_name`)
- **Variable Operation (Set)** → Assignment (`set @variables.name = value`)
- **Variable Operation (Collect)** → Reasoning + action (ask for input)
- **Conditional** → `if/else` blocks or `available when` guards
- **Wait** → Implicit in reasoning loop (LLM handles naturally)
- **SystemMessage (Transfer/EndChat)** → System actions

### Actions
Preserve exact target names from bot metadata:
- Apex → `"apex://ClassName"`
- Flow → `"flow://FlowName"`
- Standard Invocable Action → `"standardInvocableAction://ActionName"`
- External Service → `"externalService://ServiceName"`

## How to Run the Migration

1. **Place bot metadata** in `data/bot.json` (exported Einstein Bot JSON)
2. **Start migration**:
   ```
   Ask Claude: "Start the bot migration"
   ```
   or invoke skill directly: `/00-start-migration`
3. **Follow checkpoints**:
   - Step 1: Confirm bot identity and inventory
   - Step 2: Provide agent name/label, approve architecture
   - Step 6: Confirm deployment target org

## Compilation

### Local Testing
Test any `.agent` file locally before deployment:
```bash
uv run --refresh --native-tls .claude/skills/00-start-migration/scripts/compile_agentscript_nexus_ts.py path/to/Agent.agent
```

### Compiler Outcomes
| Output | Meaning |
|--------|---------|
| `Successfully compiled Agent Script.` | No errors |
| `Successfully compiled Agent Script (library warnings present...)` | Warnings are informational (known library bugs with `developer_name=None`) |
| `Parse errors in ...` / `Compile errors in ...` | Real errors requiring fixes |

**Note:** `sf agent publish` is the authoritative validator; local compiler catches most but not all issues.

## Pipeline Recovery

If interrupted, resume from any step:

| Resume From | Required Artifact | Invoke |
|-------------|------------------|--------|
| Step 0 | _(none)_ | `/00-start-migration` |
| Step 1 | _(none)_ | `/01-retrieve-bots-metadata` |
| Step 2 | `migration-inventory.md` | `/02-process-and-build-inventory` |
| Step 3 | `migration-architecture.md` | `/03-map-dialogs-actions-to-topics` |
| Step 4 | `data/topic_classification.json` + architecture | `/04-generate-agentscript` |
| Step 5 | Complete `.agent` file | `/05-compile-agentscript` |
| Step 6 | Compiled `.agent` file | `/06-deploy-agent-to-org` |

## Important Constraints

### Self-Healing Loops
- **Step 5 (compilation)**: Max **30 iterations** to auto-fix errors
- **Step 6 (publish)**: Max **15 retries** to fix publish failures

### Salesforce CLI Timeouts
**CRITICAL:** Always wait **up to 5 minutes** for `sf` CLI commands to complete. Never cancel or retry without adequate time (network latency and org size affect speed).

### Error Diagnosis Authority
When diagnosing AgentScript errors in Steps 4-6:
1. **Primary**: `.claude/skills/00-start-migration/assets/AGENT_SCRIPT_RULES.md`
2. **Secondary**: `.claude/skills/00-start-migration/assets/AGENT_SCRIPT_RECIPES.xml`
3. **Type mappings**: `.claude/skills/00-start-migration/assets/LEGACY_TYPE_MAPPINGS.md`

**Never use web search** for AgentScript syntax—all rules are in local files.

### Deployment Safety
- **Always require explicit YES/NO confirmation** before deploying (Step 6)
- Display full org details (ID, username, instance URL, type)
- Never skip confirmation or deploy without user approval

## Topic Design Rules

When grouping actions into topics (Step 3):

**Grouping Priority** (highest to lowest):
1. Actions working on same **entity** → **SHOULD** group
2. Actions updating/writing same **variable** → **MOST LIKELY** group
3. Actions consuming/reading same **variable** → **MOST LIKELY** group
4. Actions from same **dialog group** → **LIKELY** group
5. Actions with similar **intentions** → **CAN** group

**Constraints**:
- Max **7 actions per topic** (split if needed)
- An action **can belong to multiple topics** if criteria demand it

## Common Issues

### Network Access
- Compiler dependencies require access to **Salesforce Nexus PyPI/npm proxies** (`nexus-proxy.repo.local.sfdc.net`)
- VPN may be required

### Missing Prerequisites
Run automated installer:
- **macOS/Linux**: `bash scripts/install-prerequisites.sh`
- **Windows**: `powershell -ExecutionPolicy Bypass -File scripts/install-prerequisites.ps1`

### Publish Failures (After Successful Compilation)
Common causes:
- **Missing Flow/Apex components** in target org → Deploy them first
- **Schema mismatches** → Check action parameter types against legacy schema
- **Invalid `complex_data_type_name`** → Consult `LEGACY_TYPE_MAPPINGS.md`
- **Permissions** → Ensure user has Agentforce admin permissions

### Pipeline Stalls
Each skill produces an artifact for the next step. If a skill fails partway:
1. Check for partial output files
2. Fix manually if needed
3. Re-run downstream skill

## Directory Structure

```
bot-to-agent-migration-dev/
├── .claude/skills/          # Pipeline step implementations (00-09)
├── customers/               # Customer-specific bot metadata
├── data/                    # Intermediate artifacts
│   ├── generated/          # Generated AgentScript files
│   ├── resources/          # Reference data for skills
│   └── sf-cli/             # Salesforce CLI package directory
├── dashboard/              # Interactive web dashboard for progress tracking
├── docs/                   # Documentation (PIPELINE.md, TROUBLESHOOTING.md)
├── scripts/                # Installation and utility scripts
├── force-app/              # Generated Salesforce metadata
│   └── main/default/
│       └── aiAuthoringBundles/
└── sfdx-project.json       # Salesforce project config
```

## Related Skills

When user mentions bot migration, use:
- **chatbots-domain-expert** — Salesforce Chatbots platform expert (Einstein Bots + Agentforce)
- For architecture questions about Salesforce Chatbots platform, always prefer this skill

## Data Directory
data/ - Use this relative location as the data directory. This will store all required intermediate data files.

## Resources Directory
resources/ - Use this relative location as the resources directory to lookup any resources referenced in the skills/agents.

## Documentation

- **README.md** — Quick start and pipeline overview
- **docs/PIPELINE.md** — Detailed step-by-step reference
- **docs/TROUBLESHOOTING.md** — Common issues and solutions
- **DASHBOARD_SETUP.md** — Interactive dashboard setup guide
