---
name: einstein-bot-to-agentscript-converter
description: Generates the complete agentscript backing an AI agent (agentforce agent) from the full einstein bot metadata/configuration. The complete bot metadata json would be provided as input to this skill.
allowed-tools: Write, Edit, Read, Glob
---

# 1. Ask the bot metadata json file path and copy the file to data directory named `bot.json`.

# 2. Use the skill `preprocess-einstein-bot` to preprocess the bot metadata.

# 3. Use the skill `generate-agentscript-topics` to pick the topics.

# 4. Use the skill `generate-agentscript-from-topics-and-bot` to generate the agentscript.

# 5. Use the skill `deploy-agentscript` to deploy the agentscript to the target org.

# 6. Use the skill `deploy-agentscript` to  deploy the agentscript to the target org.

