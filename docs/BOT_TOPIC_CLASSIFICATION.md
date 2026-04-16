# Bot-to-Agent Topic Classification Strategy

This document explains how Einstein Bot dialogs and actions are grouped into NGA Agent topics during migration.

## Overview

**Challenge:** Einstein Bots organize logic into **dialogs** (sequential conversation flows), while NGA Agents organize into **topics** (intent-based subagents with specialized responsibilities).

**Solution:** Group related bot dialogs and actions into topics based on multiple criteria, balancing specialization with maintainability.

## Topic Classification Criteria

Topics are created by analyzing bot structure across 4 dimensions (in priority order):

### 1. Entity Focus (Highest Priority)

**Principle:** Actions that operate on the same underlying entity/object should be in the same topic.

**Examples:**
- All actions manipulating `Profile` (register, login, logout, update) → `Profile_Management` topic
- All actions manipulating `Booking` (create, modify, cancel, confirm) → `Booking_Management` topic
- All actions manipulating `Case` (create, update, close) → `Case_Management` topic

**How to Identify:**
- Examine action names for common entity references
- Analyze invocation targets (Apex class names, Flow names often contain entity)
- Review input/output parameters (recordId, objectType fields indicate entity)

### 2. Shared Variables (Second Priority)

**Principle:** Actions that read/write the same conversation variables likely work together in a workflow.

**Examples:**
- Actions reading `profile_id` variable → grouped together (they depend on profile context)
- Actions writing `booking_id` variable → grouped together (they produce booking context)
- Actions using `payment_confirmed` flag → grouped together (payment workflow)

**How to Identify:**
- From `preprocessed_bot.json`, check `variables_read` and `variables_written` for each action
- Actions with high variable overlap (>50% shared variables) should be grouped
- Critical workflow variables (IDs, status flags) are strong grouping signals

### 3. Dialog Groups (Third Priority)

**Principle:** Bot creators organized dialogs into dialog groups for a reason — respect that organization.

**Examples:**
- All dialogs in `Profile_Operations` group → `Profile_Management` topic
- All dialogs in `Booking_Flows` group → `Booking_Management` topic
- Dialogs without group (empty string) → `General` topic

**How to Identify:**
- From bot metadata, check `dialog.dialogGroup` field
- Group all dialogs with same non-empty dialog group
- Handle empty/null dialog group as "General" or "Miscellaneous"

### 4. Intent Alignment (Fourth Priority)

**Principle:** Actions serving similar user intents should be grouped together.

**Examples:**
- Actions related to "flight booking" intent → `Booking_Management` topic
- Actions related to "profile update" intent → `Profile_Management` topic
- Actions related to "payment processing" intent → `Payment_Processing` topic

**How to Identify:**
- From `intent_digest.json`, review intent descriptions and utterances
- Map intents to dialogs (intent → target dialog from navigation)
- Map dialogs to actions (invocations within dialogs)
- Group actions by common intent themes

## Topic Size Constraints

### Maximum Actions Per Topic: 7

**Reason:** Topics with too many actions become difficult to reason about and maintain.

**When a grouping exceeds 7 actions:**
1. **Option A — Split by Sub-Entity:**
   - `Booking_Management_Create` (create, search flights, select seats)
   - `Booking_Management_Modify` (reschedule, cancel, refund, update passengers)

2. **Option B — Split by Workflow Stage:**
   - `Booking_Management_Part_1` (search, create, select)
   - `Booking_Management_Part_2` (modify, cancel, confirm)

3. **Option C — Split by Complexity:**
   - `Booking_Management_Core` (most common actions)
   - `Booking_Management_Advanced` (less common/specialized actions)

### Minimum Actions Per Topic: 1

**Reason:** Some topics legitimately have only one action (e.g., knowledge base search).

**When a topic has 1 action:**
- Verify it's not better grouped with another topic
- Check if it's a utility action (knowledge search, escalation)
- If truly standalone, create single-action topic (acceptable)

## Special Topics (Always Create)

### 1. agent_entrypoint (start_agent)

**Purpose:** Entry point for the agent, handles welcome and initial routing.

**Source:** Bot's entry dialogs (first dialogs users encounter).

**Structure:**
- **Description:** "Entry point for [Bot Name] NGA Agent"
- **Reasoning:**
  - Welcome message (from entry dialog messages)
  - Identify initial user intent
  - Route to appropriate topic
- **Actions:** Transitions to all primary topics (using `@utils.transition to @topic.X`)

**Example:**
```agentscript
start_agent agent_entrypoint:
   description: "Entry point for Emirates Airlines agent"
   reasoning:
      instructions: |
         Welcome the user and identify their initial intent.
         Route to the appropriate topic based on their needs.
      actions:
         go_to_profile: @utils.transition to @topic.Profile_Management
            description: "Route to profile operations: registration, login, logout, update profile, manage account, ..."
         
         go_to_booking: @utils.transition to @topic.Booking_Management
            description: "Route to booking operations: create booking, modify reservation, cancel flight, reschedule, seat selection, ..."
```

### 2. topic_router (if bot has intents)

**Purpose:** Handle intent-based navigation (replaces bot's Intent_Redirect navigation type).

**Source:** Bot's ML intent configuration.

**Structure:**
- **Description:** "Routes user to appropriate topic based on stated intent"
- **Reasoning:** Simple routing logic with intent-rich transition descriptions
- **Actions:** Transitions to all topics reachable via intent
- **Guards:** `available when` clauses for topics requiring preconditions

**Example:**
```agentscript
topic topic_router:
   description: "Handles intent-based navigation for all intent redirect flows"
   reasoning:
      instructions: |
         Identify the user's intent from their message and route to the appropriate topic.
      actions:
         route_to_profile: @utils.transition to @topic.Profile_Management
            description: "Route to profile operations when user mentions: login, register, sign up, logout, account, profile settings, update password, ..."
         
         route_to_booking: @utils.transition to @topic.Booking_Management
            description: "Route to booking when user mentions: book flight, reservation, cancel booking, modify trip, change seats, reschedule, refund, ..."
            available when @variables.profile_id != ""  # Booking requires authenticated user
```

## Topic Classification Algorithm

### Step 1: Extract All Actions

From `preprocessed_bot.json`:
```python
actions = {
  "ActionName": {
    "type": "apex/flow/api/...",
    "target": "...",
    "variables_read": [...],
    "variables_written": [...],
    "invoked_by_dialogs": [...]
  }
}
```

### Step 2: Build Entity Groups

Group actions by entity keywords in action name:
- Actions with "Profile" in name → entity = "Profile"
- Actions with "Booking" in name → entity = "Booking"
- Actions with "Case" in name → entity = "Case"

If no clear entity keyword, infer from Apex/Flow target name.

### Step 3: Build Variable Overlap Graph

For each pair of actions, compute variable overlap:
```python
overlap = len(set(action1.variables_read + action1.variables_written) & 
              set(action2.variables_read + action2.variables_written))

if overlap >= threshold:
    # Group these actions together
```

### Step 4: Build Dialog Group Mapping

Map dialogs to groups:
```python
dialog_groups = {
  "Profile_Management": ["Login_Dialog", "Register_Dialog", "Logout_Dialog"],
  "Booking_Management": ["Create_Booking", "Cancel_Booking", "Modify_Booking"],
  "": ["Welcome", "Main_Menu"]  # No explicit group
}
```

Map actions to dialog groups via invocation:
```python
action_to_groups = {}
for action_name, action_data in actions.items():
    for dialog in action_data["invoked_by_dialogs"]:
        for group, group_dialogs in dialog_groups.items():
            if dialog in group_dialogs:
                action_to_groups[action_name].add(group or "General")
```

### Step 5: Build Intent Mapping

From `intent_digest.json` and dialog navigation:
```python
intent_to_dialogs = {
  "booking_intent": ["Create_Booking", "Modify_Booking"],
  "profile_intent": ["Login_Dialog", "Register_Dialog"]
}

# Map to actions
intent_to_actions = {}
for intent, dialogs in intent_to_dialogs.items():
    for dialog in dialogs:
        # Find actions invoked by this dialog
        for action, action_data in actions.items():
            if dialog in action_data["invoked_by_dialogs"]:
                intent_to_actions[intent].append(action)
```

### Step 6: Create Topics

Combine all criteria:

```python
topics = {}

# Start with entity-based groups (highest priority)
for entity in entities:
    entity_actions = [a for a in actions if a.entity == entity]
    
    # Refine by dialog groups
    for group in dialog_groups:
        group_actions = [a for a in entity_actions if group in action_to_groups[a]]
        
        if len(group_actions) <= 7:
            # Create single topic
            topics[f"{entity}_{group}"] = {
                "actions": group_actions,
                "entity_focus": entity,
                "dialog_group": group
            }
        else:
            # Split into multiple topics (max 7 actions each)
            for i in range(0, len(group_actions), 7):
                topics[f"{entity}_{group}_Part_{i//7 + 1}"] = {
                    "actions": group_actions[i:i+7],
                    "entity_focus": entity,
                    "dialog_group": group
                }
```

### Step 7: Assign Dialogs to Topics

For each topic's actions, find all source dialogs:

```python
for topic_name, topic_data in topics.items():
    associated_dialogs = set()
    for action in topic_data["actions"]:
        associated_dialogs.update(actions[action]["invoked_by_dialogs"])
    
    topic_data["associated_dialogs"] = list(associated_dialogs)
```

### Step 8: Extract Shared Variables

For each topic, find variables used across its actions:

```python
for topic_name, topic_data in topics.items():
    shared_vars = set()
    for action in topic_data["actions"]:
        shared_vars.update(actions[action]["variables_read"])
        shared_vars.update(actions[action]["variables_written"])
    
    topic_data["shared_variables"] = list(shared_vars)
```

## Output Format

The classification produces `data/topic_classification.json`:

```json
{
  "topics": {
    "Profile_Management": {
      "description": "Handles user profile operations including registration, login, logout, and profile updates",
      "entity_focus": "Profile",
      "associated_dialogs": ["Login_Dialog", "Register_Dialog", "Logout_Dialog", "Update_Profile"],
      "associated_actions": ["EmiratesLoginProfile", "EmiratesRegisterProfile", "EmiratesLogoutProfile"],
      "shared_variables": ["profile_id", "username", "email", "is_authenticated"],
      "action_dialog_mapping": {
        "EmiratesLoginProfile": ["Login_Dialog"],
        "EmiratesRegisterProfile": ["Register_Dialog"],
        "EmiratesLogoutProfile": ["Logout_Dialog"]
      }
    },
    "Booking_Management": {
      "description": "Handles flight booking operations including create, modify, cancel, and reschedule",
      "entity_focus": "Booking",
      "associated_dialogs": ["Create_Booking", "Modify_Booking", "Cancel_Booking", "Reschedule_Flight"],
      "associated_actions": ["EmiratesCreateBooking", "EmiratesFetchFlights", "EmiratesCancelBooking", "EmiratesRescheduleBooking", "EmiratesSelectSeats"],
      "shared_variables": ["booking_id", "flight_number", "passenger_count", "departure_date"],
      "action_dialog_mapping": {
        "EmiratesCreateBooking": ["Create_Booking"],
        "EmiratesFetchFlights": ["Create_Booking", "Reschedule_Flight"],
        "EmiratesCancelBooking": ["Cancel_Booking"],
        "EmiratesRescheduleBooking": ["Reschedule_Flight"],
        "EmiratesSelectSeats": ["Create_Booking", "Modify_Booking"]
      }
    }
  },
  "count": 2
}
```

## Validation Checklist

After classification, verify:

- [ ] Every bot action appears in at least one topic
- [ ] No topic has more than 7 actions (if so, split further)
- [ ] Topics with 1 action are justified (utility actions, knowledge search)
- [ ] Entity-focused topics are coherent (actions operate on same object)
- [ ] Dialog groups are respected (dialogs from same group stay together)
- [ ] `agent_entrypoint` and `topic_router` (if intents exist) are always created
- [ ] Action-dialog mapping is complete (every action knows its source dialogs)
- [ ] Shared variables make sense (variables used across topic's actions)

## Common Patterns

### Pattern 1: Authentication Workflow

**Actions:** Login, Register, Logout, ResetPassword, VerifyEmail
**Topic:** `Authentication` or `Profile_Management`
**Shared Variables:** `profile_id`, `is_authenticated`, `session_token`

### Pattern 2: CRUD Operations

**Actions:** Create, Read, Update, Delete (on same entity)
**Topic:** `[Entity]_Management`
**Shared Variables:** `[entity]_id`, `[entity]_status`

### Pattern 3: Multi-Step Workflows

**Actions:** Step1, Step2, Step3, Finalize (sequential workflow)
**Topic:** `[Workflow_Name]`
**Shared Variables:** `current_step`, `workflow_id`, intermediate data variables

### Pattern 4: Utility Actions

**Actions:** KnowledgeSearch, Escalate, TransferToAgent
**Topic:** Often single-action topics, or grouped into `Knowledge_Support` topic
**Shared Variables:** Minimal (query, result, escalation_reason)

## Bot-to-Agent Transition Planning

Once topics are classified, plan transitions:

### Entry Point Transitions
- From `agent_entrypoint` → route to primary topics based on user intent
- Use rich transition descriptions matching intent utterances

### Intent-Based Transitions
- From any topic → `topic_router` → target topic
- Replaces bot's `Intent_Redirect` navigation

### Direct Transitions
- Replaces bot's `Redirect` navigation
- From Topic A → Topic B (permanent handoff)
- Implemented as `transition to @topic.B` in `after_reasoning`

### Inline Actions (Call Pattern)
- Replaces bot's `Call` navigation
- Invoked dialog becomes inline action or `before_reasoning` block
- Implicit return to caller after execution

## Example: Emirates Airlines Bot

### Bot Structure
- 15 dialogs across 4 dialog groups
- 12 actions (Apex invocations)
- 5 intents

### Classified Topics
1. **agent_entrypoint** — Entry point, welcome, initial routing
2. **topic_router** — Intent-based navigation (5 intents)
3. **Profile_Management** — Login, Register, Logout (3 actions, 4 dialogs)
4. **Booking_Management** — CreateBooking, FetchFlights, SelectSeats, CancelBooking, RescheduleBooking (5 actions, 6 dialogs)
5. **Flight_Queries** — FlightStatus, BaggageInfo, CheckIn (3 actions, 3 dialogs)
6. **Knowledge_Support** — KnowledgeSearch (1 action, 2 dialogs)

### Topic Count: 6 (including agent_entrypoint and topic_router)

### Validation
- ✓ Max 7 actions per topic (Booking_Management has 5, all others ≤3)
- ✓ All 12 actions assigned
- ✓ Entity focus clear (Profile, Booking, Flight, Knowledge)
- ✓ Dialog groups respected
- ✓ Shared variables identified per topic

## References

- `skills/01-retrieve-bot-metadata/scripts/preprocess_bot.py` — Implementation
- `data/topic_classification.json` — Output format
- `migration-architecture.md` — Downstream consumer (uses classification for design)
