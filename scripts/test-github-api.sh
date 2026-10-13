#!/bin/bash

# Test GitHub API access with token from .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env file (same logic as release-rc.sh)
function load_env_file() {
    local env_file="$SCRIPT_DIR/.env"
    
    if [ -f "$env_file" ]; then
        echo "✅ Loading .env file..."
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                continue
            fi
            if [[ ! "$line" =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*= ]]; then
                continue
            fi
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local key=$(echo "$line" | cut -d'=' -f1)
            local value=$(echo "$line" | cut -d'=' -f2-)
            value=$(echo "$value" | sed -E "s/^['\"]|['\"]$//g")
            export "$key=$value"
        done < "$env_file"
    fi
}

load_env_file

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_TOKEN not found"
    exit 1
fi

echo "✅ GITHUB_TOKEN loaded (${#GITHUB_TOKEN} chars)"

# Get repo name from git
REPO=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:/]([^/]+\/[^/]+)(\.git)?$/\1/' | sed 's/\.git$//')
if [ -z "$REPO" ]; then
    echo "❌ Could not determine repository name"
    exit 1
fi

echo "📦 Repository: $REPO"
echo ""

# Test 1: Check repository access
echo "Test 1: Checking repository access..."
REPO_CHECK=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO")

HTTP_CODE=$(echo "$REPO_CHECK" | tail -1)
BODY=$(echo "$REPO_CHECK" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Repository access: OK"
    REPO_NAME=$(echo "$BODY" | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4)
    echo "   Full name: $REPO_NAME"
else
    echo "❌ Repository access failed (HTTP $HTTP_CODE)"
    echo "$BODY" | head -5
    exit 1
fi

echo ""

# Test 2: Check workflow access
echo "Test 2: Checking workflow access..."
WORKFLOW_CHECK=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/actions/workflows/release-rc.yml")

HTTP_CODE=$(echo "$WORKFLOW_CHECK" | tail -1)
BODY=$(echo "$WORKFLOW_CHECK" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Workflow access: OK"
    WORKFLOW_NAME=$(echo "$BODY" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    echo "   Workflow name: $WORKFLOW_NAME"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠️  Workflow not found (HTTP 404)"
    echo "   This is OK if workflow doesn't exist on current branch"
else
    echo "❌ Workflow access failed (HTTP $HTTP_CODE)"
    echo "$BODY" | head -5
fi

echo ""
echo "✅ All tests completed!"
