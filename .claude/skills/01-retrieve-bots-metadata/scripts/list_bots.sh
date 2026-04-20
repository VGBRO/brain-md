#!/bin/bash
# List all bots with all versions in org for user selection

ORG="${1:-}"

if [ -z "$ORG" ]; then
    echo "Usage: $0 <ORG_ALIAS>"
    echo ""
    echo "Example:"
    echo "  bash .claude/skills/01-retrieve-bots-metadata/scripts/list_bots.sh my-org"
    exit 1
fi

echo "================================================================================"
echo "Available Bots in Org: $ORG"
echo "================================================================================"
echo ""

# Query all bot versions
sf data query \
    --query "SELECT BotDefinition.DeveloperName, BotDefinition.Description, VersionNumber, LastModifiedDate FROM BotVersion ORDER BY BotDefinition.DeveloperName, VersionNumber DESC" \
    --target-org "$ORG"

echo ""
echo "================================================================================"
echo ""
echo "To fetch a bot (latest version), run:"
echo "  bash .claude/skills/01-retrieve-bots-metadata/scripts/fetch_bot_from_org.sh <DeveloperName> $ORG"
echo ""
echo "Note: The fetch script retrieves the bot with all its versions and metadata."
echo ""
