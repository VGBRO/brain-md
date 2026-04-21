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

# Purpose

This verifies that all required tools are installed and prerequisites are met, provides authoritative reference materials, and hands off to the first migration step.

# Instructions

## 1. Verify Prerequisites

**IMPORTANT: You MUST wait for up to 5 minutes for ALL `sf` CLI commands to complete.** Do
not cancel, retry, or re-run the same `sf` command without first giving it adequate time to
finish. Salesforce CLI operations (especially org-related commands) can be slow depending on
network conditions and org size.

Run ALL of the following checks. Report the result of each.

### 1a: Python 3.11+

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

### 1b: Node.js

```bash
node --version
```

If this fails:
> "Node.js is required (for the Salesforce CLI) but not installed.
> Install it from: https://nodejs.org/"


### 1c: Salesforce CLI

```bash
sf --version
```

If this fails:
> "The Salesforce CLI (`sf`) is required but not installed.
> Install it from: https://developer.salesforce.com/tools/salesforcecli"


### 1d: uv Package Manager

```bash
uv --version
```

If this fails:
> "The `uv` package manager is required but not installed.
> Install from: https://docs.astral.sh/uv/getting-started/installation/"


### 1e: Authenticated Salesforce Org

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


### 1f: Compiler Dependencies (Network Access)

```bash
python3 skills/00-start-migration/scripts/compile_agentscript_nexus_ts.py 2>&1 || true
```

If the output shows a network error reaching the Nexus PyPI proxy:
> "Cannot reach the Salesforce Nexus PyPI proxy at nexus-proxy.repo.local.sfdc.net.
> Ensure you are on a network with access (VPN may be required)."

If the output shows `Usage:` or a missing-argument error, the compiler is accessible — this
is a successful check.

## 2. Report Readiness

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

**Do NOT proceed to the next step until all prerequisites pass.**

## 3. Output

- Environment readiness report
- Pipeline overview for the user
