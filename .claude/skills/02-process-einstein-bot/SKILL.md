---
name: process-einstein-bot
description: Pre-processes an einstein bot's structure to filter out noise, and retain relevant data necessary to convert the bot into an agentscript backing an AI agent (agentforce agent).
allowed-tools: Write, Edit, Read, Glob
---

# 0. Prerequisite

- If both `preprocessed_bot.json` and `intent_digest.json` files already exists in the data directory, ask the user explicitly if they want to skip this step.
    - If yes, then show a message to the user like 'Proceeding to the next step..'. And give back the control.
    - If not, proceed to the next step.

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

# 3. Show Bot Summary.

- Show a tabular summary of the processed bot to the user. Include bot name, bot version name, total number of dialogs, total number of actions, total number of intents and total number of context variables.
- Do not show the generated files or file paths to the user.

# 4. Wait for user response.

- Ask if they have any questions related to the bot metadata or if they want to proceed further to the next step.
    - Provide a few suggestions for questions. Like -
        - Summarize dialogs with actions/invocations.
        - Summarize dialogs with intents.
        - Show all actions/invocations.
        - Show details of any particular apex/flow action.
- If the user has any questions, look for the answers from the content in the generated files (`intent_digest.json` or `preprocessed_bot.json`) or the original `bot.json` file.
    - If the question is out of the scope of these files, then inform the user that the question is out of scope and inform them that you can answer questions related to the bot configuration and provide examples of questions about dialogs, actions, dialog to action mappings etc.
    - If the user asks questions about all the dialogs, and if there are too many dialogs in the bot (more than 20), nudge user towards a more specific question instead of displaying all the dialogs at once.
    - User CANNOT ask to modify/update any information about the bot. And hence, the generated files and the original bot json file cannot be modified via user interactions at this point.
- If the user wants to proceed to the next step, provide a message to the user like 'Proceeding to the next step..'. And stop here. And give back the control.

** IMPORTANT INSTRUCTION ** - Do not make any changes to `bot.json` or `preprocessed_bot.json` or `intent_digest.json` files while interacting with the user.
