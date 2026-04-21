---
name: 05-compile-agentscript
description: >
  Runs the AgentScript compiler (TypeScript/Nexus implementation) in a self-healing loop, automatically
  diagnosing and fixing syntax, structural, and semantic errors until compilation succeeds or
  the maximum retry count is reached. Pipeline step 5 of 6.
metadata:
  author: salesforce-migration
  version: "2.0-nexus-ts"
  pipeline-order: "5"
compatibility: Requires Python 3.11+, Node.js v18+, npm, tree-sitter-cli (global), @agentscript/cli from Nexus npm registry, and 00-start-migration/assets/AGENT_SCRIPT_RULES.md for error diagnosis reference.
---

# Compile AgentScript

## Purpose

Run the local AgentScript compiler against the generated `.agent` file and enter a self-healing
loop to diagnose and fix errors. The compiler validates syntax (via ANTLR parser), structure
(via the DSL model), and semantic correctness (via the compiler backend).

## Prerequisites

- The `.agent` file exists at the path from `migration-architecture.md`.
- Python 3.11+ installed
- Node.js v18+ installed
- npm installed (comes with Node.js)
- tree-sitter-cli installed globally: `npm install -g tree-sitter-cli`
- @agentscript/cli from Nexus: `npm install --legacy-peer-deps --ignore-scripts`
- Network access to Nexus npm registry (for verification)
- The compiler script: `skills/00-verify-prerequisites/scripts/compile_agentscript_nexus_ts.py`

**Note:** The compiler automatically checks all prerequisites and provides installation instructions if anything is missing.

## Authoritative Rules Reference

**Before diagnosing or fixing ANY compilation error, you MUST read and internalize
`rules/AGENT_SCRIPT_RULES.md` from resources directory.** This is the authoritative source of truth
for all AgentScript syntax, structure, naming, types, block ordering, and validation rules. It
is dynamic and may change between runs — always read its current contents.

When fixing errors, consult the rules file for the correct syntax, then check
`recipes/AGENT_SCRIPT_RECIPES.xml` from resources directory for working examples if needed.
**Precedence order** (highest to lowest): `AGENT_SCRIPT_RULES.md` > `AGENT_SCRIPT_RECIPES.xml`. The migration
skill files contain overrides and refinements that take precedence over the general-purpose
rules file.

Pay special attention to the **Error Prevention** section in the rules file — it documents
the most common mistakes and their correct alternatives.

## Instructions

### Step 1: Copy AgentScript to Target Location

Before compilation, copy the generated `agentscript.agent` from the data directory to the proper Salesforce CLI structure:

1. **Read `migration-architecture.md`** to extract the agent name (stored as `AGENT_NAME`).

2. **Define paths**:
   ```
   SOURCE_FILE = data/agentscript.txt
   TARGET_DIR = data/sf-cli/generated/aiAuthoringBundles/AGENT_NAME
   TARGET_FILE = data/sf-cli/generated/aiAuthoringBundles/AGENT_NAME/AGENT_NAME.agent
   ```

3. **Create directory structure if it doesn't exist**:
   ```bash
   mkdir -p data/sf-cli/generated/aiAuthoringBundles/AGENT_NAME
   ```

4. **Copy and rename the file**:
   ```bash
   cp data/agentscript.txt data/sf-cli/generated/aiAuthoringBundles/AGENT_NAME/AGENT_NAME.agent
   ```

5. **Verify the copy**:
   ```bash
   ls -lh data/sf-cli/generated/aiAuthoringBundles/AGENT_NAME/AGENT_NAME.agent
   ```

If the source file `data/agentscript.txt` doesn't exist, STOP and report to the user that Step 4 (Generate AgentScript) must be completed first.

Store `TARGET_FILE` as `AGENT_FILE_PATH` for use in subsequent steps.

### Step 2: Verify Prerequisites

The compiler script automatically checks all prerequisites. However, you can verify them manually if needed:

```bash
# Check Python version
python3 --version  # Should be 3.11+

# Check Node.js version
node --version  # Should be v18+

# Check npm
npm --version

# Check tree-sitter CLI
tree-sitter --version

# Check @agentscript/cli installation
python3 skills/00-start-migration/scripts/compile_agentscript_nexus_ts.py --help
```

**The compiler will automatically display a Prerequisites Check:**

```
Prerequisites Check
============================================================
  Node.js (v18+)      ✓ PASS  v24.14.1
  npm                 ✓ PASS  11.11.0
  tree-sitter CLI     ✓ PASS  tree-sitter 0.26.8
  @agentscript/cli    ✓ PASS  2.2.25 (node_modules/@agentscript/cli)
  Nexus npm registry  ✓ PASS  @agentscript/cli@2.2.25

✓ All prerequisites satisfied
```

**If any prerequisite is missing**, the compiler will display installation instructions.

**One-Time Setup (if prerequisites are missing):**

```bash
# Install tree-sitter CLI globally
npm install -g tree-sitter-cli

# Install @agentscript/cli from Nexus
cd <project-root>
npm install --legacy-peer-deps --ignore-scripts
```

### Step 3: Initialize Loop Counter

Set `ITERATION = 0` and `MAX_ITERATIONS = 30`.

### Step 4: Run Compilation

**Note:** Use the `AGENT_FILE_PATH` from Step 1 (the `.agent` file in the `data/sf-cli/generated/aiAuthoringBundles/AGENT_NAME/` directory).

Execute the compiler using the TypeScript/Nexus implementation:

```bash
python3 skills/00-start-migration/scripts/compile_agentscript_nexus_ts.py AGENT_FILE_PATH
```

**Important Notes:**
- This uses the **@agentscript/cli** TypeScript implementation from **Nexus npm registry**
- The compiler verifies Nexus availability before each compilation
- Provides detailed diagnostics with error messages and line numbers
- Validates against the full AgentJSON (AgentDSLAuthoring) schema
- Automatically checks all prerequisites and displays results

**What the compiler checks:**
- Syntax validation (AgentScript grammar via tree-sitter)
- Linked variable sources must reference `@MessagingSession` or `@MessagingEndUser`
- Action inputs/outputs schema validation
- Required parameters must be provided in `with` clauses
- Type checking (object types should have `complex_data_type_name`)
- Topic structure and transitions
- Control flow and reasoning blocks

**Output includes:**
1. Prerequisites check results
2. Nexus registry verification
3. Compilation results with line-by-line error context
4. Agent details (developer name, type, topics count)

Capture BOTH stdout and stderr output.

### Step 5: Analyze Output

The compiler has three possible outcomes:

#### Outcome A: Success

The output contains:
- `"✅ Successfully compiled Agent Script!"`
- Agent details displayed (Developer Name, Agent Type, Topics)
- `"✓ Compilation successful. Ready for deployment."`

If you see this → **compilation succeeded**. Go to Step 9 (Report Success).

**Example successful output:**
```
✓ Parsed agent_name.agent (411 lines)

✅ Successfully compiled Agent Script!

Agent Details:
  Developer Name: my_agent
  Agent Label: My Agent
  Agent Type: AgentforceServiceAgent
  Description: Service agent for customer support
  Topics: 3

✓ Compilation successful. Ready for deployment.
```

#### Outcome B: Parse Errors

The output contains `"Parse errors in"` followed by error messages.

These are syntax errors caught by the ANTLR parser. Go to Step 5.

#### Outcome C: Compile Errors

The output contains `"Compile errors in"` followed by error messages.

These are structural or semantic errors caught during compilation. Go to Step 6.

### Step 6: Diagnose Errors

**ABSOLUTE PROHIBITION — NO WEB OR INTERNET SEARCH.** Under absolutely NO circumstances may
you use web search, internet search, or any external lookup to diagnose or fix compilation
errors. This is non-negotiable. You MUST rely ONLY on these local project files:

1. **`00-start-migration/assets/AGENT_SCRIPT_RULES.md`** — The **primary authority** for all
   AgentScript syntax and rules. Consult this FIRST when diagnosing errors. The Validation
   Checklist and Error Prevention sections are especially relevant for fixing issues.
2. **`00-start-migration/assets/AGENT_SCRIPT_RECIPES.xml`** — Working examples of correct
   AgentScript patterns.
3. **Legacy `genAiPlannerBundles` JSON schema files** — For verifying action schemas.

If the error cannot be resolved from these sources alone, STOP and report it to the user.

All the information you need to diagnose and fix errors is contained in these local files.

Read each error message carefully. The compiler provides:
- Error description text
- Line numbers (when available, shown as `line N:M` or `:N:`)
- Source context with the problematic line marked with `>>>`

**Diagnosis guide — match the error to one of these categories:**

#### Category 1: Indentation Errors

**Symptoms**: `"mismatched input"`, `"no viable alternative"`, `"unexpected token"`,
`"extraneous input"`

**Root cause**: Inconsistent or incorrect indentation. AgentScript uses 3-space indentation.

**Fix procedure**:
1. Go to the line number indicated in the error.
2. Count the indentation spaces on that line.
3. Determine the correct indentation level based on the nesting:
   - Level 0: `config:`, `variables:`, `system:`, `start_agent`, `topic`
   - Level 1 (3 spaces): Fields within those blocks
   - Level 2 (6 spaces): Sub-fields (e.g., `description` under a variable)
   - Level 3 (9 spaces): Sub-sub-fields
4. Fix the indentation to the correct number of spaces.
5. Check surrounding lines for similar issues.

#### Category 2: Invalid Identifiers

**Symptoms**: `"invalid identifier"`, `"name must match"`, `"invalid character"`

**Root cause**: Name contains invalid characters (spaces, hyphens, special chars) or starts
with a number.

**Fix procedure**:
1. Find the identifier on the indicated line.
2. Replace invalid characters with underscores.
3. Ensure it starts with a letter.
4. Ensure it's max 80 characters.

#### Category 3: Duplicate Names

**Symptoms**: `"duplicate"`, `"already defined"`, `"name conflict"`

**Root cause**: Two elements have the same name within the same scope.

**Fix procedure**:
1. Find both declarations with the same name.
2. Rename one to be unique (e.g., append `_2` or use a more descriptive name).
3. Update all references to the renamed element.

#### Category 4: Undefined References

**Symptoms**: `"undefined variable"`, `"unknown action"`, `"unknown topic"`,
`"not defined"`, `"cannot resolve"`

**Root cause**: A `@variables.name`, `@actions.name`, or `@topic.name` reference points
to something that doesn't exist.

**Fix procedure**:
1. Identify the reference on the indicated line.
2. Check if the target is declared:
   - For `@variables.name` → check the `variables:` block
   - For `@actions.name` → check the `actions:` block within the SAME topic
   - For `@topic.name` → check that a `topic name:` block exists
3. Either fix the typo in the reference or add the missing declaration.

#### Category 5: Type Errors

**Symptoms**: `"type error"`, `"expected type"`, `"incompatible type"`,
`"input_value="`

**Root cause**: A value doesn't match the expected type.

**Fix procedure**:
1. Check the type declaration of the variable or parameter.
2. Ensure the default value matches:
   - `string` → `""` (not `0` or `False`)
   - `number` → `0` (not `""` or `False`)
   - `boolean` → `True` or `False` (not `"true"` or `1`)
   - `object` → `{}`
   - `list[...]` → `[]`

#### Category 6: Missing Required Fields

**Symptoms**: `"required field"`, `"missing field"`, `"expected X"`

**Root cause**: A required element is missing from a block.

**Fix procedure**:
1. Identify which block is missing the field.
2. Consult `00-start-migration/assets/AGENT_SCRIPT_RULES.md` for the required elements and
   correct structure of that block type (see the Block Reference and Required Elements sections).
3. If needed, search `00-start-migration/assets/AGENT_SCRIPT_RECIPES.xml` for a working example.
4. Add the missing field with the appropriate value.

#### Category 7: Invalid Target Format

**Symptoms**: Errors mentioning `target`, `invocation`, `flow://`, `apex://`

**Root cause**: Action target string is malformed.

**Fix procedure**:
1. Verify the target follows the format `"type://Name"` where `type` is one of the
   supported AgentScript target types:
   - `"flow://FlowName"` — Salesforce Flows
   - `"apex://ClassName"` — Apex classes
   - `"generatePromptResponse://TemplateName"` — Prompt Templates
   - `"standardInvocableAction://ActionName"` — Platform standard actions
     (e.g., `identifyRecordByName`, `queryRecords`, `getDataForGrounding`).
     Do NOT use `flow://` for standard invocable actions.
   - `"externalService://ServiceName"` — External services
   - `"quickAction://ActionName"` — Quick Actions
   - `"api://EndpointName"` — REST API
   - `"apexRest://EndpointName"` — Apex REST
   - Other types: `serviceCatalog`, `integrationProcedureAction`, `expressionSet`,
     `cdpMlPrediction`, `externalConnector`, `slack`, `namedQuery`, `auraEnabled`,
     `mcpTool`, `retriever` (all follow the same `"type://name"` pattern)
2. Ensure the target string is wrapped in double quotes.
3. Ensure there are no spaces in the target string.
4. Ensure the target name after `://` matches the legacy `invocationTarget` exactly —
   do not rename, re-case, or reformat.

#### Category 8: Reasoning Syntax Errors

**Symptoms**: Errors pointing to lines within `reasoning:` or `instructions:` blocks

**Root cause**: Malformed pipe syntax, if/else blocks, or variable interpolation.

**Fix procedure**:
1. Check `|` pipe lines — each must start with `|` followed by a space.
2. Check `if/else` blocks:
   - `if` must be followed by a condition and then `:`
   - `else:` must be on its own line at the same indentation as `if`
   - Content under `if`/`else` must be indented 3 more spaces
3. Check variable interpolation:
   - Must use `{!expression}` syntax
   - `@variables.name` inside expressions (not `$variables` or `%variables`)
4. Check `set` statements:
   - Must use `=` not `:=` or `==`
   - Left side must be `@variables.name`
   - Right side must be `@outputs.name` or a value

### Step 7: Apply Fixes

For each diagnosed error:

1. Read the section of the `.agent` file around the error line.
2. Identify the root cause using the diagnosis guide above.
3. Consult `00-start-migration/assets/AGENT_SCRIPT_RULES.md` for the correct syntax of the
   affected construct. Pay attention to the Error Prevention section for common mistakes.
4. Apply the MINIMUM fix needed — do not rewrite large sections.
5. If you need a working example of the construct, search
   `00-start-migration/assets/AGENT_SCRIPT_RECIPES.xml` for one — but verify the example
   conforms to the current rules in `AGENT_SCRIPT_RULES.md`.

**Important**: Fix ALL errors from the current compilation run before re-compiling.
Do not fix one error and immediately re-run.

### Step 8: Re-run Compilation

Increment `ITERATION`.

If `ITERATION >= MAX_ITERATIONS`:
- **STOP the loop.**
- Report all remaining errors to the user.
- Ask for guidance.
- Go to Step 9.

Otherwise, return to Step 4.

### Step 9: Fix Linter Errors

After compilation succeeds, you MUST check for and fix any linter errors in the `.agent`
file and any related project files before proceeding to deployment. Open the `.agent` file
in the IDE and review for:

- Syntax warnings or errors flagged by the IDE's linter
- Formatting inconsistencies
- Any remaining issues that the IDE highlights

**Do NOT proceed to the deploy step until ALL linter errors are resolved.** Deploying code
with linter errors can result in deployment failures or unexpected behavior in the org.

### Step 10: Report Success

```
Compilation Successful
======================
File: AGENT_FILE_PATH
Iterations: ITERATION
Library warnings: [count or "none"]
Linter errors: [PASS — all resolved]

The AgentScript file has been validated by the local compiler.
Note: The authoritative validator is `sf agent publish`. Library warnings
(if any) about developer_name=None are known issues and do not indicate
problems with your AgentScript.
```

### Step 11: Report Failure (if max iterations reached)

```
Compilation Failed After MAX_ITERATIONS Attempts
=================================================
File: AGENT_FILE_PATH

Remaining errors:
  1. [error description] (line [N])
  2. [error description] (line [N])

These errors could not be automatically resolved. Please review the
errors above and the .agent file manually, or provide guidance on
how to fix them.
```

## Output

- Successfully compiled `.agent` file (or detailed error report)
- Compilation status for the `06-deploy-agentscript` skill

## Next Step

After successful compilation, ask user if user wants to go ahead with deploy agent step strictly in yes/no answer.
if answer is yes, invoke the **06-deploy-agentscript** skill.

After unsuccessful compilation ,ask user if user wants to go ahead with deploy agent step strictly in yes/no answer.
if answer is yes, invoke the **06-deploy-agentscript** skill.


