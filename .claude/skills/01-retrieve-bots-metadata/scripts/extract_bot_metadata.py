#!/usr/bin/env python3
"""
Generic script to extract bot metadata from Salesforce metadata files.
Works with ANY bot - no hardcoded values.
"""

import json
import sys
import argparse
from pathlib import Path
from typing import Any, Dict, List, Set, Optional, Tuple


def load_json_file(file_path: Path) -> Dict[str, Any]:
    """Load JSON file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def build_variable_type_map(conversation_vars: List[Dict]) -> Dict[str, Dict]:
    """
    Build a map of variable name to its complete type information.
    Returns: {variableName: {dataType, collectionType, etc}}
    """
    var_map = {}
    for var in conversation_vars:
        var_name = var.get("developerName")
        if var_name:
            var_map[var_name] = {
                "dataType": var.get("dataType", "Text"),
                "collectionType": var.get("collectionType"),
                "label": var.get("label", "")
            }
    return var_map


def infer_sobject_type_from_label(label: str) -> Optional[str]:
    """
    Try to infer SObject API name from label.
    E.g., "Current User" -> might be a User-related object
    Returns None if can't infer.
    """
    if not label:
        return None

    # Convert label to potential API name format
    # Remove special chars, title case each word
    words = label.replace("_", " ").split()

    # If it looks like it could be a custom object (multiple words, specific patterns)
    if len(words) >= 2:
        # Try to construct API name
        api_name = "".join(word.capitalize() for word in words)

        # Add __c suffix if it looks like a custom object
        # (Not standard objects like Account, Contact, Case, etc.)
        if api_name not in ["Account", "Contact", "Case", "User", "Lead", "Opportunity"]:
            return f"{api_name}__c"
        return api_name

    return None


def map_salesforce_data_type(sf_type: str, param_name: str = "") -> str:
    """
    Map Salesforce data types to API parameter types.
    Uses standard Salesforce type mappings.
    For Number type, infers INTEGER vs NUMBER based on parameter name.
    """
    type_mapping = {
        "Text": "STRING",
        "LongText": "STRING",
        "Number": "NUMBER",  # May be overridden below
        "Boolean": "BOOLEAN",
        "Date": "DATE",
        "DateTime": "DATETIME",
        "Currency": "NUMBER",
        "Percent": "NUMBER",
        "Id": "STRING",
        "Email": "STRING",
        "Phone": "STRING",
        "Url": "STRING",
        "Picklist": "STRING",
        "MultiPicklist": "STRING",
        "Object": "SOBJECT",  # Generic object
    }

    result = type_mapping.get(sf_type, "STRING")

    # For Number type, check if it should be INTEGER
    if sf_type == "Number" and param_name:
        param_lower = param_name.lower()
        # These patterns suggest integers
        integer_patterns = ["days", "count", "quantity", "index", "page", "limit"]
        if any(pattern in param_lower for pattern in integer_patterns):
            result = "INTEGER"

    return result


def infer_parameter_type_generic(
    param_name: str,
    variable_name: str,
    var_type_map: Dict[str, Dict]
) -> Dict[str, Any]:
    """
    Infer parameter type generically using ONLY metadata information.
    No hardcoded patterns or specific object names.
    """
    # If we have the variable mapping, use it
    if variable_name and variable_name in var_type_map:
        var_info = var_type_map[variable_name]
        data_type = var_info["dataType"]

        # Map to API type (pass param_name for Number type inference)
        api_type = map_salesforce_data_type(data_type, param_name)

        result = {"type": api_type}

        # For Object types, try to infer the specific SObject
        if data_type == "Object":
            # Try to infer from variable label
            sobject_type = infer_sobject_type_from_label(var_info.get("label", ""))
            if sobject_type:
                result["sObjectType"] = sobject_type
            # Otherwise leave as generic SOBJECT

        # Handle collections
        if var_info.get("collectionType") == "List":
            result["collectionType"] = "List"

        return result

    # Fallback: Generic type inference based on common Salesforce patterns
    # Use parameter name to make educated guess
    param_lower = param_name.lower()

    # Boolean patterns
    if param_lower.startswith("is") or param_lower.startswith("has") or "success" in param_lower:
        return {"type": "BOOLEAN"}

    # Date patterns
    if "date" in param_lower and "update" not in param_lower:
        return {"type": "DATE"}

    if "datetime" in param_lower or "timestamp" in param_lower:
        return {"type": "DATETIME"}

    # Number patterns
    if any(word in param_lower for word in ["count", "number", "amount", "quantity", "duration", "id"]):
        if "id" in param_lower and not param_lower.endswith("id"):
            return {"type": "STRING"}
        elif param_lower.endswith("id") or param_lower.endswith("ids"):
            return {"type": "STRING"}
        return {"type": "NUMBER"}

    # Default to STRING
    return {"type": "STRING"}


def extract_required_fields_from_steps(bot_dialogs: List[Dict]) -> Set[str]:
    """
    Extract which fields are marked as required in dialog steps.
    Returns set of variable names that are required.
    """
    required_vars = set()

    def process_step(step: Any):
        if not isinstance(step, dict):
            return

        # Check for collection steps with optionalCollect flag
        optional_collect = step.get("optionalCollect", "false")
        if optional_collect == "false":
            # This is a required collection
            bot_var_op = step.get("botVariableOperation", {})
            if isinstance(bot_var_op, dict):
                operands = bot_var_op.get("botVariableOperands", {})
                if isinstance(operands, dict):
                    target_name = operands.get("targetName")
                    if target_name:
                        required_vars.add(target_name)

        # Recurse into nested steps
        nested_steps = step.get("botSteps", [])
        if isinstance(nested_steps, list):
            for nested_step in nested_steps:
                process_step(nested_step)

    # Process all dialogs
    for dialog in bot_dialogs:
        steps = dialog.get("botSteps", [])
        for step in steps:
            process_step(step)

    return required_vars


def extract_invocations_from_bot_version_generic(
    bot_version_data: Dict,
    var_type_map: Dict[str, Dict],
    required_vars: Set[str]
) -> Dict[str, Dict]:
    """
    Extract all invocations generically from botVersion.
    Uses only metadata, no hardcoded values.
    """
    print("    Extracting invocations from bot dialogs...")

    invocations = {}

    def process_step(step: Any, depth: int = 0):
        """Recursively process a bot step."""
        if not isinstance(step, dict):
            return

        # Check for botInvocation in botVariableOperation
        bot_var_op = step.get("botVariableOperation", {})
        if isinstance(bot_var_op, dict) and "botInvocation" in bot_var_op:
            bot_invocation = bot_var_op.get("botInvocation", {})
            invocation_name = bot_invocation.get("invocationActionName", "")

            if invocation_name:
                if invocation_name not in invocations:
                    invocations[invocation_name] = {
                        "inputParameters": {},
                        "outputParameters": {}
                    }

                # Extract parameter mappings
                mappings = bot_invocation.get("invocationMappings", [])
                for mapping in mappings:
                    if not isinstance(mapping, dict):
                        continue

                    param_name = mapping.get("parameterName", "")
                    mapping_type = mapping.get("type", "")  # "Input" or "Output"
                    variable_name = mapping.get("variableName", "")

                    if not param_name:
                        continue

                    # Infer parameter type generically
                    param_info = infer_parameter_type_generic(
                        param_name,
                        variable_name,
                        var_type_map
                    )

                    # Check if required (for input parameters only)
                    if mapping_type == "Input" and variable_name in required_vars:
                        param_info["required"] = True

                    # Add to appropriate parameters dict
                    if mapping_type == "Input":
                        invocations[invocation_name]["inputParameters"][param_name] = param_info
                    elif mapping_type == "Output":
                        invocations[invocation_name]["outputParameters"][param_name] = param_info

        # Also check for direct botInvocation (alternative format)
        if "botInvocation" in step:
            bot_invocation = step.get("botInvocation", {})
            invocation_name = (
                bot_invocation.get("invocationName", "") or
                bot_invocation.get("invocationActionName", "")
            )

            if invocation_name:
                if invocation_name not in invocations:
                    invocations[invocation_name] = {
                        "inputParameters": {},
                        "outputParameters": {}
                    }

                mappings = bot_invocation.get("invocationMappings", [])
                for mapping in mappings:
                    if not isinstance(mapping, dict):
                        continue

                    param_name = mapping.get("parameterName", "")
                    mapping_type = mapping.get("type", "")
                    variable_name = mapping.get("variableName", "")

                    if not param_name:
                        continue

                    param_info = infer_parameter_type_generic(
                        param_name,
                        variable_name,
                        var_type_map
                    )

                    if mapping_type == "Input" and variable_name in required_vars:
                        param_info["required"] = True

                    if mapping_type == "Input":
                        invocations[invocation_name]["inputParameters"][param_name] = param_info
                    elif mapping_type == "Output":
                        invocations[invocation_name]["outputParameters"][param_name] = param_info

        # Recurse into nested botSteps
        nested_steps = step.get("botSteps", [])
        if isinstance(nested_steps, list):
            for nested_step in nested_steps:
                process_step(nested_step, depth + 1)

    # Get conversation variables
    conversation_vars = bot_version_data.get("conversationVariables", [])

    # Build required vars set
    bot_dialogs = bot_version_data.get("botDialogs", [])

    # Process all bot dialogs
    for dialog in bot_dialogs:
        bot_steps = dialog.get("botSteps", [])
        for step in bot_steps:
            process_step(step)

    print(f"      Found {len(invocations)} unique invocations")
    return invocations


def parse_related_ml_intents(bot_meta: Dict) -> Dict[str, List[str]]:
    """
    Parse relatedMlIntents from bot metadata.

    Each bot dialog with mlIntentTrainingEnabled can reference an external Intent Set.
    Format: "relatedMlIntents": {"relatedMlIntent": "IntentSetName.IntentName"}

    Returns: {
        "IntentSetName": ["IntentName1", "IntentName2", ...],
        ...
    }

    Example:
        "relatedMlIntents": {"relatedMlIntent": "MyMLDomain.MyIntent"}

    Returns:
        {"MyMLDomain": ["MyIntent"]}
    """
    from collections import defaultdict

    intent_set_map = defaultdict(list)

    bot_ml_domain = bot_meta.get("Bot", {}).get("botMlDomain", {})
    ml_intents = bot_ml_domain.get("mlIntents", [])

    for intent in ml_intents:
        if not isinstance(intent, dict):
            continue

        related_ml = intent.get("relatedMlIntents")

        # Handle both array and dict formats
        if isinstance(related_ml, list):
            # Array format: [{"relatedMlIntent": "IntentSetName.IntentName"}]
            for item in related_ml:
                if isinstance(item, dict):
                    related_intent = item.get("relatedMlIntent", "")
                    if related_intent and '.' in related_intent:
                        intent_set_name, intent_name = related_intent.split('.', 1)
                        intent_set_map[intent_set_name].append(intent_name)
        elif isinstance(related_ml, dict):
            # Dict format: {"relatedMlIntent": "IntentSetName.IntentName"}
            related_intent = related_ml.get("relatedMlIntent", "")
            if related_intent and '.' in related_intent:
                intent_set_name, intent_name = related_intent.split('.', 1)
                intent_set_map[intent_set_name].append(intent_name)

    return dict(intent_set_map)


def load_intent_set_json(intent_set_name: str, bot_dir: Path = None) -> Optional[Dict]:
    """Load Intent Set JSON file. Returns None if not found."""
    # Try custom folder first if bot_dir provided
    if bot_dir:
        # Check jsons folder first
        ml_domain_file = bot_dir / "jsons" / f"{intent_set_name}.json"
        if ml_domain_file.exists():
            try:
                with open(ml_domain_file) as f:
                    return json.load(f)
            except Exception:
                pass

        # Then check mlDomains folder
        ml_domain_file = bot_dir / "mlDomains" / f"{intent_set_name}.json"
        if ml_domain_file.exists():
            try:
                with open(ml_domain_file) as f:
                    return json.load(f)
            except Exception:
                pass

    # Fallback to default location
    ml_domain_file = Path(f"data/sf-cli/main/default/mlDomains/{intent_set_name}.json")

    if not ml_domain_file.exists():
        return None

    try:
        with open(ml_domain_file) as f:
            return json.load(f)
    except Exception:
        return None


def extract_specific_intents_from_set(intent_set_data: Dict, intent_names: List[str]) -> List[Dict]:
    """
    Extract ONLY specific intents from an Intent Set.
    Does not extract all intents - only the ones referenced by the bot.
    """
    all_intents = intent_set_data.get("mlIntents", [])

    # Create map for quick lookup
    intent_map = {
        intent["developerName"]: intent
        for intent in all_intents
    }

    # Extract only requested intents
    extracted_intents = []
    for intent_name in intent_names:
        if intent_name in intent_map:
            extracted_intents.append(intent_map[intent_name])

    return extracted_intents


def extract_ml_data_from_bot_meta_generic(bot_meta: Dict) -> Dict[str, Any]:
    """Extract ML domain and intent data generically from bot metadata."""
    print("    Extracting ML data from bot metadata...")

    bot_ml_domain = bot_meta.get("Bot", {}).get("botMlDomain", {})

    if not bot_ml_domain:
        return {"c": {}}

    domain_label = bot_ml_domain.get("label", "MlDomain")
    domain_name = bot_ml_domain.get("name", domain_label.replace(" ", ""))
    ml_intents_raw = bot_ml_domain.get("mlIntents", [])

    # Convert to standard bot JSON format
    ml_intents = []
    for intent in ml_intents_raw:
        if not isinstance(intent, dict):
            continue

        ml_intent_utterances = []
        utterances = intent.get("mlIntentUtterances", [])

        for utterance in utterances:
            if isinstance(utterance, dict):
                ml_intent_utterances.append({
                    "utterance": utterance.get("utterance", "")
                })

        ml_intents.append({
            "developerName": intent.get("developerName", ""),
            "label": intent.get("label", ""),
            "mlIntentUtterances": ml_intent_utterances
        })

    print(f"      Found {len(ml_intents)} intents")

    # Use domain name as key
    return {
        "c": {
            domain_name: {
                "MlDomain": {
                    "fullName": domain_name,
                    "label": domain_label,
                    "mlIntents": ml_intents
                }
            }
        }
    }


def get_empty_agent_actions() -> Dict[str, Any]:
    """
    Return empty agent actions structure.
    """
    return {
        "customActions": [],
        "standardActions": []
    }


def simplify_context_variables_generic(context_vars: List[Dict]) -> List[Dict]:
    """Simplify context variables to bot JSON format (only core fields)."""
    simplified = []
    for var in context_vars:
        if not isinstance(var, dict):
            continue

        simplified.append({
            "dataType": var.get("dataType"),
            "developerName": var.get("developerName"),
            "label": var.get("label")
        })
    return simplified


def rebuild_bot_json_generic(
    bot_meta: Dict,
    bot_version: Dict,
    bot_name: str
) -> Dict[str, Any]:
    """Rebuild bot JSON format from metadata files generically."""
    print("\n  Rebuilding bot JSON format from metadata...\n")

    bot_data = bot_meta.get("Bot", {})
    bot_version_data = bot_version.get("BotVersion", {})

    # Use bot_name as fullName (not botVersion.fullName which is just "v1")
    full_name = bot_name

    # Build variable type map
    conversation_vars = bot_version_data.get("conversationVariables", [])
    var_type_map = build_variable_type_map(conversation_vars)

    # Build required fields set
    bot_dialogs = bot_version_data.get("botDialogs", [])
    required_vars = extract_required_fields_from_steps(bot_dialogs)

    # Extract Bot structure
    bot_data = {
        "fullName": full_name,
        "botMlDomain": bot_data.get("botMlDomain", {}),
        "contextVariables": simplify_context_variables_generic(
            bot_data.get("contextVariables", [])
        ),
        "description": bot_data.get("description", ""),
        "label": bot_data.get("label", ""),
        "botVersions": [bot_version_data]
    }

    # Extract invocations generically
    invocations = extract_invocations_from_bot_version_generic(
        bot_version_data,
        var_type_map,
        required_vars
    )

    # Extract ML data generically
    ml_data = extract_ml_data_from_bot_meta_generic(bot_meta)

    # Get agent actions (from existing bot JSON if available)
    agent_actions = get_empty_agent_actions()

    # Combine
    result = {
        "Bot": bot_data,
        "availableAgentActions": agent_actions,
        "botInvocationsDescribeInfo": {
            "apex": invocations,
            "flow": {}
        },
        "mlRelatedData": ml_data
    }

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Extract bot JSON from metadata files (generic, works with any bot)"
    )
    parser.add_argument("bot_name", help="Bot developer name")
    parser.add_argument("--output", "-o", help="Output file path")
    parser.add_argument("--bot-dir", help="Bot directory path (default: data/sf-cli/main/default/bots/{bot_name})")

    args = parser.parse_args()

    bot_name = args.bot_name

    if args.bot_dir:
        base_dir = Path(args.bot_dir)
    else:
        base_dir = Path(f"data/sf-cli/main/default/bots/{bot_name}")

    print("="*80)
    print(f"Extracting Bot JSON from Metadata (Generic): {bot_name}")
    print("="*80)

    # Load metadata files from jsons directory
    print("\nStep 1: Loading metadata files...")
    jsons_dir = base_dir / "jsons"
    bot_meta_file = jsons_dir / f"{bot_name}.bot-meta.json"

    if not bot_meta_file.exists():
        print(f"Error: {bot_meta_file} not found", file=sys.stderr)
        sys.exit(1)

    bot_meta = load_json_file(bot_meta_file)

    # Find botVersion file in jsons directory
    version_files = list(jsons_dir.glob("*.botVersion-meta.json"))
    if not version_files:
        print(f"Error: No botVersion-meta.json found in {jsons_dir}", file=sys.stderr)
        sys.exit(1)

    bot_version = load_json_file(version_files[0])
    print(f"  ✓ Loaded {bot_meta_file.name}")
    print(f"  ✓ Loaded {version_files[0].name}")

    # Rebuild
    print("\nStep 2: Extracting and combining data...")
    rebuilt = rebuild_bot_json_generic(bot_meta, bot_version, bot_name)

    # Create jsons subdirectory
    jsons_dir = base_dir / "jsons"
    jsons_dir.mkdir(exist_ok=True)

    # Save initial version (temporary)
    temp_file = base_dir / "generated_temp.json"
    with open(temp_file, 'w', encoding='utf-8') as f:
        json.dump(rebuilt, f, indent=2, ensure_ascii=False)

    print(f"\n  ✓ Saved temporary file to {temp_file}")

    # Step 3: Extract and merge related ML intents from Intent Sets
    print("\nStep 3: Extracting related ML intents from Intent Sets...")
    intent_set_map = parse_related_ml_intents(bot_meta)

    if intent_set_map:
        print(f"  ✓ Found references to {len(intent_set_map)} Intent Set(s):")
        for intent_set_name, intent_names in intent_set_map.items():
            print(f"      - {intent_set_name}: {len(intent_names)} intent(s) - {', '.join(intent_names)}")

        # Build mlRelatedData with only the referenced intents
        ml_related_data = {"c": {}}
        total_intents = 0
        total_utterances = 0
        missing_sets = []

        for intent_set_name, intent_names in intent_set_map.items():
            intent_set_data = load_intent_set_json(intent_set_name, base_dir)

            if intent_set_data:
                # Extract ONLY the referenced intents
                extracted_intents = extract_specific_intents_from_set(intent_set_data, intent_names)

                if extracted_intents:
                    utterance_count = sum(
                        len(intent.get("mlIntentUtterances", []))
                        for intent in extracted_intents
                    )

                    ml_related_data["c"][intent_set_name] = {
                        "MlDomain": {
                            "fullName": intent_set_data.get("fullName", intent_set_name),
                            "label": intent_set_data.get("label", intent_set_name),
                            "mlIntents": extracted_intents
                        }
                    }

                    total_intents += len(extracted_intents)
                    total_utterances += utterance_count
                    print(f"      ✓ Extracted {len(extracted_intents)} intent(s) with {utterance_count} utterances from {intent_set_name}")
            else:
                missing_sets.append(intent_set_name)

        if ml_related_data["c"]:
            # Replace mlRelatedData with the extracted intents
            rebuilt["mlRelatedData"] = ml_related_data

            # Save final version to jsons directory with bot name
            output_file = jsons_dir / f"{bot_name}.json"
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(rebuilt, f, indent=2, ensure_ascii=False)

            print(f"\n  ✓ Final version saved to: {output_file}")
            print(f"  🎉 Extracted {total_intents} intent(s) with {total_utterances} utterances")

            # Clean up temporary file
            if temp_file.exists():
                temp_file.unlink()
                print(f"  ✓ Cleaned up temporary file: {temp_file}")
        else:
            # No ML related data, save to jsons directory with bot name
            output_file = jsons_dir / f"{bot_name}.json"
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(rebuilt, f, indent=2, ensure_ascii=False)

            print(f"\n  ✓ Saved to: {output_file}")

            # Clean up temporary file
            if temp_file.exists():
                temp_file.unlink()
                print(f"  ✓ Cleaned up temporary file: {temp_file}")

        if missing_sets:
            print(f"\n  ⚠  Missing Intent Set(s): {', '.join(missing_sets)}")
            for missing_set in missing_sets:
                print(f"  💡 Run: sf project retrieve start --metadata MlDomain:{missing_set}")
                print(f"  💡 Then: python3 scripts/custom/convert_intentsets_xml.py")
    else:
        print(f"  ℹ  No relatedMlIntents found - using bot's internal ML domain only")

        # Save to jsons directory with bot name
        output_file = jsons_dir / f"{bot_name}.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(rebuilt, f, indent=2, ensure_ascii=False)

        print(f"\n  ✓ Saved to: {output_file}")

        # Clean up temporary file
        if temp_file.exists():
            temp_file.unlink()
            print(f"  ✓ Cleaned up temporary file: {temp_file}")

    print("\n" + "="*80 + "\n")


if __name__ == "__main__":
    main()
