#!/bin/bash
# Fetch Einstein Bot metadata from Salesforce org and convert to JSON
# This script retrieves bot structure, invocations, and ML training data

set -e

BOT_NAME="${1}"
ORG="${2:-}"
ML_DOMAIN="${3:-}"  # Optional - will auto-discover if not provided

# Check if first argument is "interactive"
if [ "$BOT_NAME" = "interactive" ]; then
    INTERACTIVE="true"
    BOT_NAME=""  # Clear bot name so it will be selected interactively

    if [ -z "$ORG" ]; then
        echo "Error: Org alias required for interactive mode"
        echo ""
        echo "Usage: $0 interactive <ORG_ALIAS>"
        echo ""
        echo "Example:"
        echo "  $0 interactive my-org"
        exit 1
    fi
else
    INTERACTIVE="false"

    if [ -z "$BOT_NAME" ]; then
        echo "Usage: $0 <BOT_NAME> [ORG_ALIAS] [ML_DOMAIN]"
        echo "   or: $0 interactive <ORG_ALIAS>"
        echo ""
        echo "Examples:"
        echo "  $0 MyBot my-org"
        echo "  $0 MyBot my-org MyMLDomain"
        echo "  $0 interactive my-org            # Interactive bot selection"
        echo ""
        echo "This will:"
        echo "  1. Retrieve bot metadata from Salesforce org"
        echo "  2. Retrieve ML training data (intents + utterances)"
        echo "  3. Extract complete bot structure"
        echo "  4. Save as data/bot.json (ready for migration pipeline)"
        echo ""
        exit 1
    fi
fi

# Determine project root (4 levels up from this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "================================================================================"
echo "Fetch Einstein Bot from Salesforce Org"
echo "================================================================================"
echo ""
if [ "$INTERACTIVE" = "true" ]; then
    echo "Mode:       Interactive Selection"
    echo "Org:        ${ORG}"
else
    echo "Bot Name:   $BOT_NAME"
    echo "Org:        ${ORG:-<default>}"
    echo "ML Domain:  ${ML_DOMAIN:-<auto-discover>}"
fi
echo "Project:    $PROJECT_ROOT"
echo ""
echo "================================================================================"
echo ""

# Step 1.0: Ensure SF project exists
echo "Step 1.0: Checking Salesforce DX project setup..."
echo ""

if [ ! -f "$PROJECT_ROOT/sfdx-project.json" ]; then
    echo "⚠️  No sfdx-project.json found. Creating Salesforce DX project..."
    echo ""

    cd "$PROJECT_ROOT"
    sf project generate \
        --name "bot-to-agent-migration" \
        --template "empty" \
        --output-dir "."

    if [ $? -ne 0 ]; then
        echo ""
        echo "Error: Failed to create Salesforce DX project"
        exit 1
    fi

    # Update sfdx-project.json to use data/sf-cli as package directory
    cat > "$PROJECT_ROOT/sfdx-project.json" <<'EOF'
{
  "packageDirectories": [
    {
      "path": "data/sf-cli",
      "default": true
    }
  ],
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "62.0"
}
EOF

    echo "  ✓ Created sfdx-project.json with package directory: data/sf-cli"
else
    echo "  ✓ sfdx-project.json exists"
fi

# Ensure package directory structure exists
mkdir -p "$PROJECT_ROOT/data/sf-cli/main/default"
mkdir -p "$PROJECT_ROOT/data/resources"

# Remove force-app directory if it exists (SF CLI will use it instead of data/sf-cli)
if [ -d "$PROJECT_ROOT/force-app" ]; then
    echo "  ⚠️  Removing conflicting force-app directory"
    rm -rf "$PROJECT_ROOT/force-app"
fi

# Remove any empty metadata directories that cause SF CLI scandir errors
# Let SF CLI create these directories during retrieve
rmdir "$PROJECT_ROOT/data/sf-cli/main/default/bots" 2>/dev/null || true
rmdir "$PROJECT_ROOT/data/sf-cli/main/default/mlDomains" 2>/dev/null || true
rmdir "$PROJECT_ROOT/data/sf-cli/main/default/aiAuthoringBundles" 2>/dev/null || true

echo "  ✓ Package directory structure ready"
echo ""
echo "================================================================================"
echo ""

# Step 1.1: Interactive bot selection (if enabled)
if [ "$INTERACTIVE" = "true" ]; then
    echo "Step 1.1: Interactive bot selection..."
    echo ""

    # Run interactive bot selector - redirect only the SELECTED_BOT line to capture it
    TEMP_OUTPUT=$(mktemp)

    # Run the script with full terminal access, capture only the output
    python3 "$SCRIPT_DIR/list_bots_interactive.py" "$ORG" 2>&1 | tee "$TEMP_OUTPUT"
    EXIT_CODE=${PIPESTATUS[0]}

    if [ $EXIT_CODE -ne 0 ]; then
        rm -f "$TEMP_OUTPUT"
        echo ""
        echo "Bot selection cancelled or failed."
        exit 0
    fi

    # Extract selected bot name from captured output
    SELECTED_BOT=$(grep "SELECTED_BOT=" "$TEMP_OUTPUT" | cut -d'=' -f2)
    rm -f "$TEMP_OUTPUT"

    if [ -z "$SELECTED_BOT" ]; then
        echo ""
        echo "No bot selected. Exiting."
        exit 0
    fi

    # Set BOT_NAME to selected bot
    BOT_NAME="$SELECTED_BOT"

    echo ""
    echo "  ✓ Selected bot: $BOT_NAME"
    echo ""
    echo "================================================================================"
    echo ""
fi

# Step 1.2: Get org ID and bot version to create folder name
echo "Step 1.2: Getting org details and bot version..."
echo ""

# Get org ID
if [ -z "$ORG" ]; then
    ORG_INFO=$(sf org display --json 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error: No default org set. Please specify org with --target-org or set a default org."
        echo "Run: sf org display to check available orgs"
        exit 1
    fi
else
    ORG_INFO=$(sf org display --target-org "$ORG" --json 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to get org details for: $ORG"
        echo "Check that the org alias is correct and you're authenticated."
        exit 1
    fi
fi

ORG_ID=$(echo "$ORG_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('result', {}).get('id', ''))" 2>/dev/null)

if [ -z "$ORG_ID" ]; then
    echo "Error: Failed to retrieve org ID from org info"
    exit 1
fi

echo "  ✓ Org ID: $ORG_ID"

# Query bot version
if [ -z "$ORG" ]; then
    BOT_VERSION_QUERY=$(sf data query --query "SELECT VersionNumber FROM BotVersion WHERE BotDefinition.DeveloperName='${BOT_NAME}' ORDER BY VersionNumber DESC LIMIT 1" --json)
else
    BOT_VERSION_QUERY=$(sf data query --query "SELECT VersionNumber FROM BotVersion WHERE BotDefinition.DeveloperName='${BOT_NAME}' ORDER BY VersionNumber DESC LIMIT 1" --target-org "$ORG" --json)
fi

BOT_VERSION=$(echo "$BOT_VERSION_QUERY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['result']['records'][0]['VersionNumber'] if data['result']['records'] else '1')")

if [ -z "$BOT_VERSION" ]; then
    echo "  ⚠️  Could not determine bot version, defaulting to 1"
    BOT_VERSION="1"
fi

echo "  ✓ Bot Version: $BOT_VERSION"

# Define custom folder path (separate from SF CLI's default structure)
FOLDER_NAME="${ORG_ID}_${BOT_NAME}_v${BOT_VERSION}"
BOT_DIR="$PROJECT_ROOT/data/sf-cli/custom/${FOLDER_NAME}"

echo "  ℹ️  Will organize files into: custom/${FOLDER_NAME}"

echo ""
echo "================================================================================"
echo ""

# Step 1.3: Retrieve bot metadata
echo "Step 1.3: Retrieving bot metadata from Salesforce org..."
echo ""

# Change to project root for SF CLI commands
cd "$PROJECT_ROOT"

if [ -z "$ORG" ]; then
    sf project retrieve start \
        --metadata "Bot:${BOT_NAME}"
else
    sf project retrieve start \
        --metadata "Bot:${BOT_NAME}" \
        --target-org "${ORG}"
fi

if [ $? -ne 0 ]; then
    echo ""
    echo "Error: Failed to retrieve bot metadata"
    echo "Check that:"
    echo "  - Bot name is correct (DeveloperName, not Label)"
    echo "  - You're authenticated to the org"
    echo "  - The bot exists in the org"
    exit 1
fi

echo ""

# Step 1.4: Auto-discover ML domains from bot metadata (if not provided)
if [ -z "$ML_DOMAIN" ]; then
    echo "Step 1.4: Auto-discovering ML domains from bot metadata..."
    echo ""

    # Parse bot metadata to find relatedMlIntents (from default location)
    DEFAULT_BOT_DIR="$PROJECT_ROOT/data/sf-cli/main/default/bots/${BOT_NAME}"
    BOT_META_FILE="${DEFAULT_BOT_DIR}/${BOT_NAME}.bot-meta.xml"

    if [ -f "$BOT_META_FILE" ]; then
        # Extract ML domain names from relatedMlIntent tags (format: "DomainName.IntentName")
        DISCOVERED_DOMAINS=$(grep -o '<relatedMlIntent>[^<]*</relatedMlIntent>' "$BOT_META_FILE" | \
                            sed 's/<[^>]*>//g' | \
                            cut -d'.' -f1 | \
                            sort -u | \
                            tr '\n' ' ')

        if [ -n "$DISCOVERED_DOMAINS" ]; then
            echo "  ✓ Discovered ML domain(s): $DISCOVERED_DOMAINS"
            ML_DOMAINS_TO_FETCH="$DISCOVERED_DOMAINS"
        else
            echo "  ℹ  No external ML domains referenced - will use bot's internal mlDomain only"
            ML_DOMAINS_TO_FETCH=""
        fi
    else
        echo "  ⚠️  Bot metadata file not found, skipping auto-discovery"
        ML_DOMAINS_TO_FETCH=""
    fi
else
    echo "Step 1.4: Using provided ML domain: $ML_DOMAIN"
    ML_DOMAINS_TO_FETCH="$ML_DOMAIN"
fi

echo ""

# Step 1.5: Retrieve ML training data
if [ -n "$ML_DOMAINS_TO_FETCH" ]; then
    echo "Step 1.5: Retrieving ML training data from Salesforce org..."
    echo ""

    # Ensure we're in project root for SF CLI commands
    cd "$PROJECT_ROOT"

    ML_DOMAIN_RETRIEVED=false

    for DOMAIN in $ML_DOMAINS_TO_FETCH; do
        echo "  Fetching ML domain: $DOMAIN"

        # Capture stderr to temp file to avoid flooding console with progress spinner
        TEMP_ERR=$(mktemp)

        if [ -z "$ORG" ]; then
            sf project retrieve start \
                --metadata "MlDomain:${DOMAIN}" 2>"$TEMP_ERR"
            EXIT_CODE=$?
        else
            sf project retrieve start \
                --metadata "MlDomain:${DOMAIN}" \
                --target-org "${ORG}" 2>"$TEMP_ERR"
            EXIT_CODE=$?
        fi

        # Only show errors if command failed (ignore ENOENT scandir warnings)
        if [ $EXIT_CODE -ne 0 ]; then
            grep -v -E "(ENOENT.*scandir|Error \(ENOENT\):)" "$TEMP_ERR" || true
        fi
        rm -f "$TEMP_ERR"

        # Check if files were actually retrieved
        if [ -f "$PROJECT_ROOT/data/sf-cli/main/default/mlDomains/${DOMAIN}.mlDomain-meta.xml" ]; then
            echo "    ✓ Retrieved $DOMAIN"
            ML_DOMAIN_RETRIEVED=true
        else
            echo "    ⚠️  Failed to retrieve $DOMAIN (may not exist in org)"
        fi
    done

    if [ "$ML_DOMAIN_RETRIEVED" = false ]; then
        echo ""
        echo "  ⚠️  No ML domains retrieved successfully"
        echo "  Continuing with bot's internal mlDomain only..."
    fi
else
    echo "Step 1.5: Skipping ML domain retrieval (none specified or discovered)"
    ML_DOMAIN_RETRIEVED=false
fi

echo ""

# Step 1.6: Copy all retrieved files to custom organized folder
echo "Step 1.6: Copying files to custom/${FOLDER_NAME}..."
echo ""

# Create custom folder structure with subfolders
mkdir -p "$BOT_DIR/bots"
mkdir -p "$BOT_DIR/jsons"

# Copy bot XML files to bots subfolder
DEFAULT_BOT_DIR="$PROJECT_ROOT/data/sf-cli/main/default/bots/${BOT_NAME}"
if [ -d "$DEFAULT_BOT_DIR" ]; then
    cp -r "$DEFAULT_BOT_DIR"/*.bot-meta.xml "$BOT_DIR/bots/" 2>/dev/null || true
    cp -r "$DEFAULT_BOT_DIR"/*.botVersion-meta.xml "$BOT_DIR/bots/" 2>/dev/null || true
    echo "  ✓ Bot XML files copied to bots/"
fi

# Copy ML domain XML files to mlDomains subfolder
DEFAULT_ML_DIR="$PROJECT_ROOT/data/sf-cli/main/default/mlDomains"
if [ -d "$DEFAULT_ML_DIR" ] && [ "$(ls -A $DEFAULT_ML_DIR 2>/dev/null)" ]; then
    mkdir -p "$BOT_DIR/mlDomains"
    cp -r "$DEFAULT_ML_DIR"/*.mlDomain-meta.xml "$BOT_DIR/mlDomains/" 2>/dev/null || true
    echo "  ✓ ML domain XML files copied to mlDomains/"
fi

echo ""

# Step 1.7: Convert bot XML to JSON
echo "Step 1.7: Converting bot XML metadata to JSON..."
echo ""
python3 "$SCRIPT_DIR/convert_bot_xml_to_json.py" "${BOT_NAME}" "${FOLDER_NAME}"

if [ $? -ne 0 ]; then
    echo ""
    echo "Error: Failed to convert bot XML to JSON"
    exit 1
fi

echo ""

# Step 1.8: Convert ML domain XML to JSON FIRST (before extraction needs it)
if [ "$ML_DOMAIN_RETRIEVED" = true ]; then
    echo "Step 1.8: Converting ML domain XML to JSON..."
    echo ""

    ML_DOMAIN_CONVERTED=false

    # Convert all retrieved ML domain XML files in custom folder
    for ML_XML_FILE in "$BOT_DIR/mlDomains"/*.mlDomain-meta.xml; do
        if [ -f "$ML_XML_FILE" ]; then
            echo "  Converting: $(basename "$ML_XML_FILE")"
            python3 "$SCRIPT_DIR/convert_ml_domain.py" "$ML_XML_FILE"

            if [ $? -eq 0 ]; then
                echo "    ✓ Converted successfully"
                # Move JSON from mlDomains to jsons folder
                JSON_FILE="${ML_XML_FILE%.mlDomain-meta.xml}.json"
                if [ -f "$JSON_FILE" ]; then
                    mv "$JSON_FILE" "$BOT_DIR/jsons/"
                    echo "    ✓ Moved to jsons/"
                fi
                ML_DOMAIN_CONVERTED=true
            else
                echo "    ⚠️  Conversion failed"
            fi
        fi
    done

    if [ "$ML_DOMAIN_CONVERTED" = false ]; then
        echo ""
        echo "  ⚠️  No ML domain XML files found or all conversions failed"
    fi
else
    echo "Step 1.8: Skipped (ML domain not retrieved)"
    ML_DOMAIN_CONVERTED=false
fi

echo ""

# Step 1.9: Extract bot data (now IntentSets.json is available if needed)
echo "Step 1.9: Extracting bot metadata to JSON..."
echo ""
python3 "$SCRIPT_DIR/extract_bot_metadata.py" "${BOT_NAME}" --bot-dir "${BOT_DIR}"

if [ $? -ne 0 ]; then
    echo ""
    echo "Error: Failed to extract bot metadata"
    exit 1
fi

echo ""

# Step 1.10: Removed (merge_ml_data.py is obsolete)
# extract_bot_metadata.py now handles ML intent extraction correctly by parsing
# relatedMlIntents and extracting ONLY the referenced intents from Intent Sets.

# Final file is always in jsons directory with bot name
FINAL_FILE="${BOT_DIR}/jsons/${BOT_NAME}.json"

if [ ! -f "$FINAL_FILE" ]; then
    echo "Error: Final bot JSON not found at $FINAL_FILE"
    exit 1
fi

echo ""
echo "================================================================================"
echo "✅ Complete!"
echo "================================================================================"
echo ""

echo "Folder: custom/${FOLDER_NAME}"
echo ""
if [ "$ML_DOMAIN_CONVERTED" = true ]; then
    echo "🎉 Successfully fetched bot with COMPLETE ML training data!"
    echo ""
    echo "Output file:"
    echo "  data/sf-cli/custom/${FOLDER_NAME}/jsons/${BOT_NAME}.json ⭐"
    echo "  (COMPLETE: bot + invocations + ML training data)"
    echo ""
    echo "Additional resources:"
    echo "  - SF CLI raw: data/sf-cli/main/default/bots/ and mlDomains/"
    echo "  - Organized XML: data/sf-cli/custom/${FOLDER_NAME}/"
    echo "  - Organized JSON: data/sf-cli/custom/${FOLDER_NAME}/jsons/"
    echo "  - ML domains: data/sf-cli/custom/${FOLDER_NAME}/mlDomains/"
else
    echo "⚠️  Fetched bot structure and invocations"
    echo "   ML training data is from bot's internal mlDomain"
    echo ""
    echo "Output file:"
    echo "  data/sf-cli/custom/${FOLDER_NAME}/jsons/${BOT_NAME}.json ⭐"
    echo "  (bot structure + invocations + internal ML)"
    echo ""
    echo "Additional resources:"
    echo "  - SF CLI raw: data/sf-cli/main/default/bots/"
    echo "  - Organized XML: data/sf-cli/custom/${FOLDER_NAME}/"
    echo "  - Organized JSON: data/sf-cli/custom/${FOLDER_NAME}/jsons/"
fi

echo ""
echo "================================================================================"
echo ""
echo "Next step: Start the migration pipeline"
echo "  Ask Claude: 'Start the bot migration for ${BOT_NAME}'"
echo "  Or run: /00-start-migration"
echo ""
echo "  Bot JSON location: data/sf-cli/custom/${FOLDER_NAME}/jsons/${BOT_NAME}.json"
echo ""
echo "================================================================================"
echo ""
