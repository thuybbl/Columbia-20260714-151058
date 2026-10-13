#!/bin/bash

# Script to trigger GitHub Actions workflow
# Usage: ./trigger-workflow.sh <tag_name> [branch]
# Example: ./trigger-workflow.sh v1.1.9-rc
# Example: ./trigger-workflow.sh v1.1.9-rc main

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

function info() {
    echo -e "${GREEN}$1${NC}" >&2
}

function warn() {
    echo -e "${YELLOW}$1${NC}" >&2
}

# Load .env file
function load_env_file() {
    local env_file="$SCRIPT_DIR/.env"
    if [ -f "$env_file" ]; then
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
    error "GITHUB_TOKEN not found. Set it in scripts/.env or environment variable"
fi

if [ -z "$1" ]; then
    error "Usage: $0 <tag_name> [branch] [build_type]\n" \
          "Example: $0 v1.1.9-rc\n" \
          "Example: $0 v1.1.9-rc main RC\n" \
          "Example: $0 v1.1.9-test bug/fix TEST"
fi

TAG_NAME=$1
BRANCH=${2:-$(git rev-parse --abbrev-ref HEAD)}
BUILD_TYPE=${3:-"RC"}

# Auto-detect build type from tag name if not provided
if [ -z "$3" ]; then
    if [[ "$TAG_NAME" == *"-test" ]]; then BUILD_TYPE="TEST"; fi
    if [[ "$TAG_NAME" == *"-qa" ]]; then BUILD_TYPE="QA"; fi
    if [[ "$TAG_NAME" == *"-qc" ]]; then BUILD_TYPE="QC"; fi
fi

WORKFLOW_FILE="release-rc.yml"

info "Triggering workflow dispatch..."
info "  Tag: $TAG_NAME"
info "  Branch: $BRANCH"
info "  Build Type: $BUILD_TYPE"
info "  Workflow: $WORKFLOW_FILE"

# Get repo name
REPO=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:/]([^/]+\/[^/]+)(\.git)?$/\1/' | sed 's/\.git$//')

if [ -z "$REPO" ]; then
    error "Could not determine repository name"
fi

info "Repository: $REPO"
echo ""

# Function to check if workflow exists on a branch
check_workflow_on_branch() {
    local check_branch=$1
    local check_response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO/contents/.github/workflows/$WORKFLOW_FILE?ref=$check_branch" 2>/dev/null)
    
    local check_code=$(echo "$check_response" | tail -1)
    [ "$check_code" = "200" ]
}

# Check default branch name
DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d':' -f2 | sed 's/^[[:space:]]*//')
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="main"

# Check if workflow exists on specified branch
info "Checking if workflow exists on branch '$BRANCH'..."
if check_workflow_on_branch "$BRANCH"; then
    info "✅ Workflow file found on branch '$BRANCH'"
    
    # Critical check: GitHub requires workflow to exist on default branch
    if [ "$BRANCH" != "$DEFAULT_BRANCH" ]; then
        info "Checking if workflow also exists on default branch '$DEFAULT_BRANCH'..."
        if ! check_workflow_on_branch "$DEFAULT_BRANCH"; then
            warn "⚠️  CRITICAL: Workflow file NOT found on default branch '$DEFAULT_BRANCH'"
            warn "GitHub Actions requires the workflow to exist on '$DEFAULT_BRANCH' before it can be triggered on any other branch."
            warn "Please merge '.github/workflows/$WORKFLOW_FILE' into '$DEFAULT_BRANCH' first."
        fi
    fi
    WORKFLOW_BRANCH="$BRANCH"
else
    warn "⚠️  Workflow file not found on branch '$BRANCH'"
    
    # Try to find workflow on other common branches
    info "Searching for workflow on other branches..."
    FOUND_BRANCH=""
    
    for test_branch in "bug/fix-infinity-ads" "main" "master" "develop" "dev"; do
        if check_workflow_on_branch "$test_branch"; then
            info "✅ Found workflow on branch '$test_branch'"
            FOUND_BRANCH="$test_branch"
            break
        fi
    done
    
    if [ -n "$FOUND_BRANCH" ]; then
        warn "Workflow exists on branch '$FOUND_BRANCH' but not on '$BRANCH'"
        info "Auto-switching to branch '$FOUND_BRANCH' for workflow dispatch"
        WORKFLOW_BRANCH="$FOUND_BRANCH"
    else
        WORKFLOW_BRANCH="$BRANCH"
        warn "Could not find workflow on any common branches"
        warn "Will attempt to trigger on '$BRANCH' anyway - may fail if workflow doesn't exist"
    fi
fi

echo ""

# Trigger workflow dispatch
info "Triggering workflow dispatch..."
info "  Using branch: ${WORKFLOW_BRANCH:-$BRANCH}"

WORKFLOW_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW_FILE/dispatches" \
    -d "{
        \"ref\": \"${WORKFLOW_BRANCH:-$BRANCH}\",
        \"inputs\": {
            \"tag_name\": \"$TAG_NAME\",
            \"build_type\": \"$BUILD_TYPE\"
        }
    }")

WORKFLOW_CODE=$(echo "$WORKFLOW_RESPONSE" | tail -1)
WORKFLOW_BODY=$(echo "$WORKFLOW_RESPONSE" | sed '$d')

if [ "$WORKFLOW_CODE" = "204" ]; then
    info "✅ Workflow dispatch triggered successfully!"
    info ""
    info "Workflow details:"
    info "  Tag: $TAG_NAME"
    info "  Branch: ${WORKFLOW_BRANCH:-$BRANCH}"
    info "  Workflow: $WORKFLOW_FILE"
    info ""
    info "You can view the workflow run at:"
    info "  https://github.com/$REPO/actions"
    exit 0
else
    if [ "$WORKFLOW_CODE" = "403" ]; then
        error "Workflow dispatch failed (HTTP 403 - Permission denied)\n" \
              "Your GITHUB_TOKEN doesn't have permission to trigger workflows.\n" \
              "To fix this:\n" \
              "  1. For classic tokens: Add 'workflow' scope\n" \
              "  2. For fine-grained tokens: Add 'Actions: Write' permission"
    elif [ "$WORKFLOW_CODE" = "404" ]; then
        error "Workflow dispatch failed (HTTP 404)\n" \
              "Workflow '$WORKFLOW_FILE' not found on branch '${WORKFLOW_BRANCH:-$BRANCH}'.\n" \
              "The workflow might exist on a different branch.\n" \
              "Try: $0 $TAG_NAME bug/fix-infinity-ads"
    else
        error "Workflow dispatch failed (HTTP $WORKFLOW_CODE)\n" \
              "$(echo "$WORKFLOW_BODY" | head -5)"
    fi
fi
