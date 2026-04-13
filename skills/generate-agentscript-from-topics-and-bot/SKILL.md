---
name: generate-agentscript-from-topics-and-bot
description: Generates the complete agentscript backing an AI agent (agentforce agent) from the pre-generated topics and the full einstein bot metadata/configuration. The topics and the bot data would be provided as input to this skill.
allowed-tools: Write, Edit, Read, Glob
---

# 1. Understand the agentscript/agentforce syntax.

## Definition of Agentforce agent (configured in Agentscript language).

An agentforce agent is an orchestrator AI agent working on top of a group of subagents. Each subagent has their own instruction set and a list of allowed tools/actions. The orchestrator agent works in harmony with the subagents by delegating tasks and following the global instructions provided to it.

## Agentforce agent Configuration schema (Agentscript language structure/syntax).

- First, lookup and understand `AgentScriptLexer.g4` and `AgentScriptParser.g4` files in the available resources. These are antlr files that define the structure and grammar of the agentscript language.
- `system` section captures system consumed values.
- `config` section provides configuration values and settings.
- `variables` section captures the configuration runtime variables used to store the session state.
- `knowledge` section captures the details of a knowledge base configured to provide the necessary information to answer queries.
- `topic/start_agent` in the language represents the subagent.
    - `actions` within a topic capture the tools that the topic/subagent has access to.
    - `reasoning` section with the topic captures the logic that should be followed by the subagent to execute the task.
        - `actions` within the reasoning section are equivalent to `tools` that can be used by LLM. They are references to actions within the scope of the topic, or references to some standard actions provided by the framework.
        - `instructions` within the reasoning section are natural language instructions followed by subagent to figure out the next steps to execute. Usually, reasoning happens in a loop (taking into consideration, the previous iterations' outputs).
    - `before_reasoning` section contains the logic that should be executed by the subagent before the reasoning loop starts. This is similar to hooks in subagent framework. This is only executed once before the reasoning starts (independent of the number of iterations in the reasoning loop).
    - `after_reasoning` section contains the logic that should be executed by the subagent after the reasoning loop ends. This is similar to hooks in subagent framework. This is only executed once after the reasoning ends (independent of the number of iterations in the reasoning loop).

# 2. Understand the einstein bot metadata's structure.

## Definition of Einstein Bot

An Einstein bot is an autonomous software which is equipped to execute certain steps based on the configured workflows and user inputs. Simply put, bot is an automation software which deterministically follows a certain workflow to execute pre-configured steps (in order) based on the Einstein Bot Configuration.


## Einstein Bot Configuration Schema

Einstein Bot metadata configuration has the following attributes:
- Bot: Object that stores all the metadata information about the configuration. A bot will only have one botVersion. A Bot is composed of the following attributes:

    - botVersions: Object that contains the conversation flow configuration for a given Bot. The main elements in a bot version include:
        - botDialogs: These are groups of botSteps which are executed in order. Steps are executed sequentially. A dialog can optionally have an associated "mlIntent" and in turn the sample "mlIntentUtterances" that come with it. Simply put, this dialog should be invoked if the corresponding intent is inferred from the user input. A botDialog has the following attributes:
            - developerName: Unique identifier of the dialog.
            - mlIntent: Name of the mlIntent entity attached to this dialog.
            - botSteps: These define the specific conversational actions followed within a dialog. Supported step types include:
                - Message: Outputs a message
                    - Navigation: Controls conversation flow by redirecting or calling another dialog via bot navigation links. Types of navigation include:
                        - Redirect: Stop executing the current stack of steps and move on to the target dialog. This is a transfer of control to the target dialog.
                            - An entity is used to capture the details of target bot dialog via field targetBotDialog.
                        - Call: Start executing the steps in the target dialog. After their execution is complete, resume the execution of the current dialog. This is similar to a function call, where the control returns after completion of execution of the function.
                            - An entity is used to capture the details of target bot dialog via field targetBotDialog.
                    - VariableOperation: Used to manipulate conversational variables, the supported types of variable operations include:
                        - Set: Explicitly assign a value to a variable from another variable or an explicit value. If the variable has to be assigned an explicit value based on output of invocable actions, this step will have a reference to an invocation step and the corresponding parameter to variable mappings.
                        - Unset: Clear a variable value.
                        - Collect : Asking a question to populate a value into a variable. For collect operations, we support providing static or dynamic options.
                            - An entity is used to define the applicable target variable data types and collection behavior. If a collect option has dynamic options it will have an internal invocation step with an output parameter mapping to populate the list of options.
                            - Normally, variable collection is only enforced if the target variable hasn’t been set. To override this, askCollectIfSet can be set to TRUE in order to always force a variable collection regardless of the variable state.
                        - SetConversationLanguage: Set a system-level variable that controls the user language.
                        - CollectAttachment: Used to collect a file from the user.
                    - Invocation: Represents and external invocation action which is triggered to achieve relevant intent. These actions specify mapping input/output parameters to conversationVariables. Each invocation has an associated botInvocation entity capturing the details of the invocation action name and invocation action type. Invocations can be backed by any of the following action types:
                        - apex
                        - flow
                        - standardInvocableAction
                        - externalService
                        - quickAction
                        - api
                        - logFeedback: Not relevant for Agents
                        - logGoalAchieved: Not relevant for Agents
                        - logDisambiguation: Not relevant for Agents
                    - Wait: Used to pause the conversation flow and switch control to the user to trigger an intent.
                    - Group: Used to create a composite step that wraps.
                    - SystemMessage: Used to trigger system level actions, examples of system messages include:
                        - Transfer: Initiate an action to transfer the conversation to a human.
                        - EndChat: Initiate an action to end the current conversation session.
                    - RecordLookup: Used to perform a query action against a defined SObject type and results are populated back into a list object variable.
                    - RichMessage: Used to send a rich message definition on supported channels. Examples of rich messages include:
                        - Authentication
                        - Forms
                        - Payments
                        - Time Selector
                        - Enhanced Links
                        - etc...
                    - GoalStep: Not relevant for Agents
                - conversationVariables:  List of custom variables used throughout the dialog flows. Supported variable data types include:
                    - Text
                    - Number
                    - Boolean
                    - Date
                    - DateTime
                    - Currency
                    - Id
                    - Object: This data type was used to capture complex data structures, like SObjects, Apex Types or Maps.
                - conversationSystemDialogs: These entries represent an assignment of a dialog to common system state behaviors. Supported behaviors include:
                    - TransferFailed
                    - ErrorHandling
                    - KnowledgeFallback
                    - Disambiguation
                    - DisambiguationFailed
                    - KnowledgeAction
                    - entryDialog (via a botVersion property)
                    - mainMenuDialog (via a botVersion property)

    - botMlDomain: This contains the details of all the intents associated with dialogs. A botMlDomain will have the following attributes:
        - mlIntents: List of all the intents. An mlIntent will have the following attributes:
            - developerName: Unique identifier for this intent.
            - description: A simple description of this intent.
            - mlIntentUtterances: List of sample sentences used to train an LLM for intent detection. These utterances can be in multiple languages like English, German, Spanish, French etc...

- botInvocationsDescribeInfo: This is a map containing the configuration of all apex and flow actions. Details of each action along with input/output parameter mappings would be captured against its name within the invocation action type entry in the map.

- availableAgentActions: A list of custom and standard agent actions that already exist in the customer's org for invocable actions used by the bot. We should not create new Agent actions for those invocationTargets that are exposed as availableAgentActions.

- mlRelatedData: Contains intent and entity data for related MlIntents and mlSlotClasses that are not present in the bot metadata.

# 3. Read the provided Einstein bot metadata's structure

Read the file `bot.json` from the data directory and parse the structure to map to the einstein bot metadata structure.

# 4. Parse the preprocessed bot data.

- Read the json content from `preprocessed_bot.json` file located in the data directory.
- This file contains the preprocessed bot data. This data is in the following structure:
  - `dialogs`: A dictionary of dialogs.
    - key: The developer name of the dialog. This is the unique identifier for the dialog.
    - value: A dictionary of dialog information.
      - `dialog_group`: The group of the dialog.
      - `developer_name`: The developer name of the dialog.
      - `description`: The description of the dialog.
      - `label`: The label of the dialog.
      - `tools`: A list of tools/actions used in the dialog.
      - `outbound_transitions`: A list of outbound transitions from the dialog.
        - `target`: The target dialog of the transition. This stores the developer name of the target dialog.
        - `type`: The type of the transition.
  - `actions`: A dictionary of actions.
    - key: unique identifier (developer name) of the action.
    = value: A dictionary of Action information.

# 5. Read the pre-selected topics and the topic-dialog mappings.

Read the file `topic_classification.json` from the data directory. This file has the below structure:
```
{
    "topics": {
        <topic_name>: {
            description: "",
            associated_dialogs: [],
            associated_actions: [],
            action_dialog_mapping: {
                <action_name>: [<dialog_list>]
            }
        }
    }
}
```

Below is the interpretation of this structure:
1. Each topic in the topics dictionary has been selected by carefully reviewing the einstein bot metadata. These are the topics/subagents that would be included in the agentforce agent to mimic/replicate the einstein bot functionality as best as possible.
2. Each topic has an associated list of actions/tools. These are the ones that the final topic/subagent will have access to.
3. Each topic has an associated list of bot dialogs. These are the dialogs from whose functionality the topic has been selected.
4. Each topic also has a mapping of action/tool name to a dialog list. This signifies that this topic/subagent should represent the execution behavior of the action in this set of dialogs (among the dialogs that are associated with the topic). Instructions for this topic should be generated based on the execution logic of these actions.

# 6. Understand the intent digest.

Read the file `intent_digest.json` from the data directory. This file contains the below structure:
```
{
    <dialog_name>: <dialog_intent_description>
}
```

In the einstein bot metadata, intents can be configured corresponding to each dialog, indicating the purpose of the dialog via natural language utterances that can be used to train AI predictive models. When a user asks something, intent classification is done using this model to decide the next steps of execution.

Intent digest contains a summary/overview of the intent of every dialog for which an intent has been configured.


# 7. Generate the agentscript for the agentforce agent.

Follow the below steps to generate the final agentscript:

## 1. Retain context variables.

Context variables are present in bot metadata at the json path `Bot.contextVariables`. Translate them as-is into `linked` variables in agentscript. Refer agentscript syntax to do this.

**IMPORTANT - Make sure to align with the agentscript syntax**

## 2. Generate config section in agentscript.

Sample structure:
```
config:
    agent_name: "ServiceBot"
    agent_id: "1"
    agent_type: "AgentforceServiceAgent"
    default_agent_user: "xyz@company.com"
```

- Generate the `agent_name` from a hash of a combination of botId (bot metadata json path `Bot.fullName`), botVersionId (bot metadata json path `Bot.botVersions[0].fullName`). Format of agent_name: `agent_<bot_name>_<hash>`.
- Leave the `default_agent_user` field as-is, to capture the placeholder value. Add a comment in the agentscript (as per the agentscript syntax) to inform the user that this field should be populated before using the agent.

## 3. Generate knowledge section in agentscript.

Knowledge base in bot is used to lookup a user text, in case none of the intents configured in the bot match the query. This is more like a backup to serve the user better and acts like a catch-all cushion.

1. Find the dialog corresponding to knowledge feedback in bot. This would be a conversation system dialog (bot metadata json path `Bot.botVersions[0].conversationSystemDialogs`) of type `KnowledgeFeedback`.
2. If the dialog does not exist, knowledge is not configured in bot, and this knowledge block can be ignored in agentscript.
3. If the dialog exists, then add the knowledge block (leave the placeholders as-is), and add a comment to inform the user to update these values before using the agent.
4. Knowledge block format in agentscript :
```
knowledge:
   rag_feature_config_id: "<placeholder_id>"
   citations_enabled: True
   citations_url: "https://help.example.com"
```

## 4. Generate topics.

### 4.1 Create topics from pre-selected topics.

Follow the below steps for each topic in the selected topics:
1. Generate `actions` section. Create an action corresponding to every action/tool in `associated_actions` attached to the topic.
    - `target` in the action should be of the format "apex://<action_name>" or "flow://<action_name>".
        - If the action is not an apex or flow action, `target` should just contain the name of the action. Also, add a comment to indicate that this should be fixed before using the agent.
    - populate `inputs` and `outputs` for every action. Retrieve this information from `botInvocationsDescribeInfo` in bot metadata.
        - if inputs or outputs are of type object, also include the `complex_data_type_name`. This can be obtained from the `sObjectType` in inputParameters in `botInvocationsDescribeInfo`.
    - Try to populate all the fields (including optional fields) in the action definitions.
2. Generate `reasoning` section.
    - Generate instructions and tools for each topic. To do this:
        - For every action in topic's `action_dialog_mapping`, go through the list of dialogs mapped to each action to find the logical flow in which the action would be executed. For example,
            - An action can be executed conditionally (variable condition)
            - An action can be executed based on user selection (from the menu options provided)
            - An action can be executed based on a user intent
            - An action can be executed in a conversational path based on redirections from one dialog to another
        - While understanding the logical flow of conversation, figure out the intent of the flow. Use the below things to figure out the intent:
            - The option selected by the user among a menu of options
                - for example, user selects an option to "Return item" (from the menu of options) -- intent is to return the product
            - The natural language input provided by the user matching an intent from the `intent_digest`
                - for example, user enters "I want to return a product", which matches with the intent digest of a dialog "Process_Return". So, the intent of redirection to this dialog was to "return a product/item"
        - Based on this logical flow of conversation:
            - Prepare an instruction containing 1-2 line summary of what the action does, when to use this action/tool and add it in the `instructions` section within reasoning block.
                - This instruction should capture the intent behind the logical conversational flow and the conditions for this flow to happen.
            - Generate an action corresponding to this particular action/tool, and add it in the `actions` section within reasoning block.
                - Map input and output variables to these actions. Two possibilities here:
                    - if the value of the variable is required to be stored in conversational state, add an explicit variable for this (in the `variables` section in agentscript), and pass it as an input to the action. for example,
                        - if a variable value stores something retrieved from a previously executed action in the bot conversational flow, then retain the same behavior in the agentscript by adding a variable explicitly.
                        - a clear example of this would be: the user credentials or the logged-in user object, which would be accessed during the entire lifecycle of the conversation.
                    - if the value of the variable is not necessary for further conversation processing, then the subagent (via LLM) would automatically handle passing this variable value via user input. for example, 
                        - if the action input only requires something entered by the user for this particular step, then do not create a variable for this in the agentscript (as the agent can handle this on its own).
                        - a clear example of this would be: the booking id to be selected for cancellation (this would not be accessed across the conversation, and is only necessary until the cancellation is complete).
                - Generate conditions for the tool to be available (`available when` in agentscript syntax). Two possibilities here:
                    - if the tool accepts a complex input that cannot be entered directly by the user, then this tool should only be available if the corresponding conversational variable holding this value in agentscript is populated.
                        - for example, a tool named `list_user_bookings`, which accepts logged-in user info, should only be populated if the variable corresponding to the logged-in user is populated.
                    - in all the possible logical conversational flows in the bot, if the tool/action is invoked only after a certain variable is set, then this tool should only be available if the corresponding conversational variable holding this value in agentscript is populated.

### 4.2 Create topics routing to pre-selected topics.

The einstein bot may also contain some logic/functionality outside the dialogs attached to the pre-defined topics. So, in order to stitch everything together, follow the below steps:
1. Create a topic (mark it as `start_agent` in agentscript) to indicate the start of conversation. Name of the topic should be `agent_entrypoint`. Generate an appropriate description for this topic.
2. Parse through the `intent_digest`. If the bot has intent enabled dialogs, create a topic with the name `topic_router`, corresponding to the intent routing. Generate an appropriate description for the topic indicating that this topic routes the conversation according to the user's intention.
3. Start traversing the bot metadata (in a DFS manner) starting from the `Welcome` dialog in the bot. Follow the below steps:
    - DFS graph structure:
        - Nodes are Bot Dialogs
        - Edges (uni-directional) are bot transitions (call/redirect) from source dialog to target dialog. These can be found in preprocessed_bot (`outbound_transitions`).
            - type=`call`: this transition type executes the target and brings the control back to the source. So, backtrack and resume the source execution to find the full conversational path.
            - type=`redirect`: this transition type executes the target and does not brings the control back to the source. So, continue with the next transitions.
            - type=`intent_redirect`: this transition type means a possible transition to any of the intent enabled dialogs (depending on the user input). Stop here.
    - **Important Instruction** - Stop DFS when a dialog which was already a part of the pre-selected topics is seen. This means that the control should move to the already generated topic via a transition in agentscript.
    - **Important Instruction** - If `intent_redirect` type transition is seen in the conversational path flow, add a transition to the topic `topic_router`, and generate appropriate description.
    - Summarize each path (the steps in the path before another dialog which is already a part of the pre-selected topics is seen in the path). After covering all the paths, try to group these paths based on similarities. for example,
        - below are similar paths:
            - a path where user selects an option "modify profile", and enters "I want to update my password" in the next step
            - a path where user selects an option "modify profile", and enters "I want to update my phone" in the next step
    - For every meaningful group, create a topic in agentscript, with appropriate transitions (as `reasoning.actions`) and the instructions on when to use these transitions.
    - **Important Instruction** - Follow the agentscript syntax according to the grammar files.

### 4.3 Create before_reasoning and after_reasoning sections.

`before_reasoning` and `after_reasoning` sections in agentscript would be executed by the subagent only once (either before or after reasoning). So, for every topic generated, 
    - if there are actions/tools to be executed before any decision making (via LLM) is involved, move them to `before_reasoning`
    - if there are actions/tools to be executed after all decision making (via LLM) is complete, move them to `after_reasoning`

### 4.4 Topic consolidation.

Among the generated topics, try to merge the topics if (highest criteria first):
- the topic is not a pre-generated topic.
- the topics don't have any actions.
- the topic descriptions are similar. similarity priority
    - underlying entity on which the topics/subagents are supposed to work on
    - underlying intention

## 5. Generate system section.

Format:
```
system:
    instructions: "You are a helpful customer service representative"
```

Generate a generic system instruction that reflects the following:
- The agent is an AI powered orchestrator
- The agent will help with a summary of all the topic descriptions combined

# 8. Validations.

1. **Important Instruction** - Ensure that the final agentforce configuration (agentscript) adheres to the syntax of the agentscript as per the provided antlr files.
2. Ensure that the transitions in the agentscript do not point to non-existent topics. If so, either modify the transition to point to the right topic or delete the transition and corresponding instructions.
3. Consolidate all the comments at the start of the agentscript. Comment starts with '#'.
4. Ensure that comments are added to explain every placeholder entry in the agentscript.
5. Ensure that all actions have correct input and output mappings in the right expected variable formats. If not, fix the problem by matching the format with `botInvocationsDescribeInfo` in bot metadata.
6. The agent execution starts from the topic labelled `start_agent`. Make sure that every other topic is reachable in any path via transitions. If a topic is not reachable, delete that topic.

# 9. Output the agentscript

Write the generated agentscript to `agentscript.txt` in the data directory.
