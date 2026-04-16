---
name: preprocess-einstein-bot
description: Pre-processes an einstein bot's structure to filter out noise, and retain relevant data necessary to convert the bot into an agentscript backing an AI agent (agentforce agent).
allowed-tools: Write, Edit, Read, Glob
---

# 1. Reformat and refine the bot structure.

```python
from scripts import preprocess_bot
preprocess_bot.run()
```

# 2. Generate Intent Digest.

- First, read the json content at the path `Bot.botMlDomain.mlIntents` from `bot.json` file located in the data directory.
- This data represents a set of intents. Every intent will have the following information:
  - `description`: The description of the intent.
  - `developerName`: The developer name of the intent.
  - `label`: The name of the intent.
  - `mlIntentUtterances`: An array of objects used to train a predictive AI model to understand the particular intent and later classify the user's input into the intent.
    - `utterance`: The natural language utterance used to train the intent.
- Create an intent digest (a json dictionary) in the following structure:
    - key: The developer name of the intent.
    - value: A 2-3 sentence description/summary of the user's intent. This description would later be used by a generative AI agent as a subagent's context to match against the user's intent.
- Save the intent digest to `intent_digest.json` file in the data directory.
