# Troubleshooting

## Compiler fails with network errors

The compiler dependencies are hosted on the Salesforce internal Nexus PyPI proxy. Ensure you are on a network that can reach `nexus-proxy.repo.local.sfdc.net`. VPN may be required.

## `sf org list` shows no orgs

Authenticate first:

```bash
sf org login web --instance-url <ORG_LOGIN_URL> --alias <CUSTOM_NAME>
```

**Example:**
```bash
sf org login web --instance-url https://orgfarm-7532d67587.test1.my.pc-rnd.salesforce.com/ --alias orgfarm-epic
```

## Compilation succeeds but publish fails

The local compiler and the server-side compiler may differ. Common causes:
- **Missing Flows or Apex classes** in the target org — the `.agent` file references targets that don't exist yet. Deploy those components first.
- **Schema mismatches** — the action's input/output types don't match what the Flow/Apex expects. Check the error message for specifics.
- **Permissions** — ensure your user has the Agentforce admin permissions in the target org.

## `developer_name=None` warnings

These are known bugs in the compiler's Python dependencies, not in your AgentScript code. They are safe to ignore. The `skills/00-start-migration/scripts/compile_agentscript.py` script filters these automatically.

## Pipeline stalls at a skill boundary

Each skill produces an intermediate file that the next skill consumes. If a skill fails partway through, check for partial output files (`migration-inventory.md`, `migration-architecture.md`, or the `.agent` file). You can fix these manually and re-run the downstream skill.
