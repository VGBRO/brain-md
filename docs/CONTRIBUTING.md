# Contributing

Salesforce employees are welcome to contribute improvements to this project. The modular architecture makes it easy to update individual skills without touching the rest of the pipeline.

## Which File to Update

| Change Type | File(s) to Update |
|---|---|
| Environment checks, CLI prerequisites | `00-start-migration/SKILL.md` |
| AgentScript syntax rules and guide | `00-start-migration/assets/AGENT_SCRIPT_RULES.md` |
| Legacy type mapping table | `00-start-migration/assets/LEGACY_TYPE_MAPPINGS.md` |
| Metadata retrieval, inventory generation | `01-retrieve-legacy-agent/SKILL.md` |
| Architecture design, recipe assessment | `02-design-agent-architecture/SKILL.md` |
| Architecture template structure | `02-design-agent-architecture/assets/ARCHITECTURE_TEMPLATE.md` |
| Content preservation guardrails | `02-design-agent-architecture/assets/QUALITY_GUARDRAILS.md` |
| Scaffold generation, file structure | `03-scaffold-agentscript/SKILL.md` |
| Topic migration, action conversion | `04-migrate-agent-topics/SKILL.md` |
| Instruction classification rules | `04-migrate-agent-topics/assets/INSTRUCTION_CLASSIFICATION_GUIDE.md` |
| Compilation loop, error diagnosis | `05-compile-agentscript/SKILL.md` |
| Deployment, publish loop, verification | `06-deploy-agentscript/SKILL.md` |
| Compiler script | `00-start-migration/scripts/compile_agentscript.py` |

## Contribution Process

This project follows a standard GitHub pull request workflow:

1. **Fork the Repository**
   - Create a personal fork of the repository on GitHub

2. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Edit the appropriate skill or reference file (see table above)
   - Follow the [agentskills.io specification](https://agentskills.io/specification) for any SKILL.md changes
   - Ensure `name` field matches the directory name, descriptions are under 1024 chars, and SKILL.md bodies stay under 500 lines

4. **Test Your Changes**
   - Run through the affected pipeline step(s) with your changes
   - Verify intermediate artifacts are correctly produced and consumed by downstream skills

5. **Commit with a Descriptive Message**
   ```bash
   git commit -m "Add error handling for missing default_agent_user field"
   ```

6. **Push and Open a Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```
   - Open a PR against the `main` branch
   - Include a clear description of what changed and why
   - Reference any related issues

7. **Address Review Feedback**
   - Respond to comments and make requested changes
   - Keep commits clean and focused

## Guidelines

- Keep changes focused and atomic (one logical change per PR)
- Inter-skill communication goes through intermediate markdown artifacts (`migration-inventory.md`, `migration-architecture.md`)
- Test the affected pipeline step(s) end-to-end when modifying any SKILL.md
- Use consistent formatting with the existing documentation
- Include before/after examples when documenting anti-patterns
