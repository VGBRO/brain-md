---
name: verify-bot-to-agent-migration-prerequisites
description: >
   Entry point for migrating an Einstein Bot to a Salesforce NGA (Next Generation AI) Agent
   using AgentScript format. Verifies prerequisites, explains the 6-step migration pipeline,
   and launches the first step. Start here when the user wants to migrate an Einstein Bot
   to NGA Agent.
metadata:
   author: salesforce-migration
   version: "2.0-bot"
   pipeline-order: "0"
compatibility: Requires Node.js, Python 3.11+, Salesforce CLI (sf), uv package manager, and network access to the Salesforce Nexus PyPI proxy.
---

# Start Bot-to-NGA Agent Migration

## Purpose

This is the entry point for the Einstein Bot to NGA Agent migration pipeline. It orients the user,
verifies that all required tools are installed, provides authoritative reference materials, and
hands off to the first migration step.

## When to Use This Skill

Activate this skill when:
- The user wants to migrate an Einstein Bot to NGA Agent
- The user mentions Einstein Bot, bot migration, or bot-to-agent conversion
- The user says "start migration", "migrate bot", or "convert bot to agent"
- The user asks about the bot-to-NGA migration process or pipeline steps

## Instructions

### Step 1: Launch Interactive Dashboard

Before explaining the pipeline, launch the visual dashboard:

```bash
python3 dashboard/server.py &
open http://localhost:8080
```

This opens an interactive web dashboard showing all 6 pipeline steps with real-time progress tracking.

### Step 2: Explain the Pipeline

Present the migration overview to the user:

```
Bot-to-NGA Agent Migration Pipeline
====================================

This pipeline migrates an Einstein Bot to a Salesforce NGA (Next Generation AI)
Agent using AgentScript format in 6 steps:

  Step 1  Retrieve Bot Metadata
          Process Einstein Bot metadata JSON, extract dialog structure,
          intents, invocations, and generate comprehensive inventory.

  Step 2  Design Agent Architecture
          Map bot constructs (dialogs, intents, navigation) to AgentScript
          patterns (topics, reasoning, transitions) using AgentScript Rules
          guide and recipe patterns. Handle bot-specific transformations:
          - Dialogs → Topics (grouped by entity, variables, intents)
          - Bot Steps → Reasoning (deterministic → AI-guided)
          - Invocations → Actions (preserve targets exactly)
          - Intents → Topic Router (dedicated intent routing)
          - Navigation → Transitions (Redirect/Call/Intent_Redirect)

  Step 3  Scaffold AgentScript
          Create the .agent file with config, variables (bot conversation
          variables → mutable, context variables → linked), system block
          (welcome from entry dialogs), and entry-point routing.

  Step 4  Migrate Agent Topics
          Transform bot dialog steps into AgentScript topics:
          - Message steps → reasoning instructions (pipe text)
          - Invocation steps → action calls with slot filling
          - Variable operations → assignments or action parameters
          - Navigation steps → topic transitions
          - Conditional logic → if/else or available when guards
          Process one topic at a time, strictly following AgentScript Rules.

  Step 5  Compile AgentScript
          Validate the .agent file locally in a self-healing loop that
          auto-diagnoses and fixes errors.

  Step 6  Deploy AgentScript
          Deploy and publish to your Salesforce org (with your explicit
          confirmation before any deployment).

You will be asked for confirmation at three checkpoints:
  - Step 1: Which org and which bot to migrate
  - Step 2: The architecture design and new agent name
  - Step 6: The deployment target org (shown with full details)
```

### Step 3: Verify Prerequisites

**IMPORTANT: You MUST wait for up to 5 minutes for ALL `sf` CLI commands to complete.** Do
not cancel, retry, or re-run the same `sf` command without first giving it adequate time to
finish. Salesforce CLI operations (especially org-related commands) can be slow depending on
network conditions and org size.

Run ALL of the following checks. Report the result of each.

#### 2a: Python 3.11+

```bash
python3 --version
```

Check that the version is 3.11 or higher. If Python is not installed or the version is older than 3.11, check for `python3.11` as a fallback:

```bash
python3.11 --version 2>/dev/null || echo "not found"
```

If `python3.11` exists and is 3.11+, suggest creating an alias or updating the PATH. Otherwise:
> "Python 3.11+ is required for the AgentScript compiler but not installed or version is too old.
> Current version: [version or 'not found']"

#### 2b: Node.js

```bash
node --version
```

If this fails:
> "Node.js is required (for the Salesforce CLI) but not installed.
> Install it from: https://nodejs.org/"

#### 2c: Salesforce CLI

```bash
sf --version
```

If this fails:
> "The Salesforce CLI (`sf`) is required but not installed.
> Install it from: https://developer.salesforce.com/tools/salesforcecli"

#### 2d: uv Package Manager

```bash
uv --version
```

If this fails:
> "The `uv` package manager is required but not installed.
> Install from: https://docs.astral.sh/uv/getting-started/installation/"

#### 2e: Authenticated Salesforce Org

```bash
sf org list
```

Verify at least one org is listed. If none:
> "No authenticated Salesforce orgs found. Authenticate with:
> 
>   `sf org login web --instance-url <ORG_LOGIN_URL> --alias <CUSTOM_NAME>`
> 
> Example:
>   `sf org login web --instance-url https://orgfarm-7532d67587.test1.my.pc-rnd.salesforce.com/ --alias orgfarm-epic`"

#### 2f: Compiler Dependencies (Network Access)

```bash
python3 skills/00-start-migration/scripts/compile_agentscript_nexus_ts.py 2>&1 || true
```

If the output shows a network error reaching the Nexus PyPI proxy:
> "Cannot reach the Salesforce Nexus PyPI proxy at nexus-proxy.repo.local.sfdc.net.
> Ensure you are on a network with access (VPN may be required)."

If the output shows `Usage:` or a missing-argument error, the compiler is accessible — this
is a successful check.

### Step 4: Report Readiness

After all checks, display a summary:

```
Prerequisites Check
====================
  Python 3.11+:       [PASS version / FAIL]
  Node.js:            [PASS version / FAIL]
  Salesforce CLI:     [PASS version / FAIL]
  uv:                 [PASS version / FAIL]
  Authenticated Orgs: [PASS count found / FAIL none]
  Compiler Access:    [PASS / FAIL]
```

If **all checks pass**:
> "Your environment is ready. Starting Step 1: Retrieve Legacy Agent."

Then invoke the **01-retrieve-legacy-agent** skill.

If **any of checks 2a, 2b, 2c, or 2d fail** (Python 3.11+, Node.js, sf CLI, or uv missing), suggest the user
run the appropriate one-line installer command:

> "Some prerequisites are missing: [list missing tools].
> You can install them automatically using the provided installation scripts:
>
> **macOS/Linux:**
> ```bash
> bash scripts/install-prerequisites.sh
> ```
>
> **Windows (PowerShell):**
> ```powershell
> powershell -ExecutionPolicy Bypass -File scripts/install-prerequisites.ps1
> ```
>
> After installing, please restart your terminal and re-run this skill."

Do NOT proceed to Step 1 until all prerequisites pass.

## Key Reference Assets

Three reference files in `00-start-migration/assets/` are used throughout the pipeline:

1. **`AGENT_SCRIPT_RULES.md`** — The **authoritative** rules and guide for building valid
   AgentScript. This file is sourced from an external repository and may be updated at any time.
   Every skill that generates or modifies AgentScript code MUST read and internalize this file
   before producing any output.

2. **`AGENT_SCRIPT_RECIPES.xml`** — A collection of working AgentScript recipe examples
   demonstrating various patterns. Use these as implementation references, but always defer to
   `AGENT_SCRIPT_RULES.md` for authoritative syntax and structural rules.

3. **`LEGACY_TYPE_MAPPINGS.md`** — The **authoritative** type mapping table for converting legacy
   `lightning:type` values to AgentScript types and `complex_data_type_name`. **This file takes
   precedence over the type mapping section in `AGENT_SCRIPT_RULES.md`** because it covers the
   complete set of types encountered in legacy bundles (including types not listed in the external
   rules file). Every skill that maps parameter types MUST consult this file.

## Pipeline Recovery

If the migration is interrupted at any point, the user can resume from the last successful
step without starting over. Each step produces an artifact that the next step consumes:

| Resume From | Required Artifact | Skill to Invoke |
|-------------|------------------|-----------------|
| Step 1 | _(none — starts fresh)_ | `01-retrieve-legacy-agent` |
| Step 2 | `migration-inventory.md` at project root | `02-design-agent-architecture` |
| Step 3 | `migration-architecture.md` at project root | `03-scaffold-agentscript` |
| Step 4 | Scaffolded `.agent` file + architecture doc | `04-migrate-agent-topics` |
| Step 5 | Complete `.agent` file with all topics | `05-compile-agentscript` |
| Step 6 | Compiled `.agent` file | `06-deploy-agentscript` |

To resume: verify the required artifact exists and is not corrupted, then invoke the
corresponding skill directly. If an artifact is missing or incorrect, re-run the skill that
produces it.

## Output

- Environment readiness report
- Pipeline overview for the user
- Handoff to `01-retrieve-legacy-agent` (on success)
