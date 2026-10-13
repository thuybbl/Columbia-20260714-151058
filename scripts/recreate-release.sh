#!/bin/bash

# Script to recreate a GitHub release
# Usage: ./recreate-release.sh [options] <version> [--trigger-workflow]
# Use -f/--force to rebuild APK/AAB before creating release

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

RELEASE_FLAVOR="prod"

function capitalize_flavor() {
    local f="$1"
    echo "$(echo "${f:0:1}" | tr '[:lower:]' '[:upper:]')${f:1}"
}

function unique_apk_upload_name() {
    local apk_path=$1
    local base
    base=$(basename "$apk_path")
    if [[ "$apk_path" =~ /outputs/apk/([^/]+)/([^/]+)/ ]]; then
        echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${base}"
    else
        echo "$base"
    fi
}

# Build release APK/AAB (matches app/build.gradle.kts productFlavors)
function build_release() {
    local build_type=$1
    local version_suffix=$2

    info "\n🔨 Building release..."

    cd "$ROOT_DIR"

    if [ ! -f "./gradlew" ]; then
        error "gradlew not found. Make sure you're in the project root."
    fi

    chmod +x ./gradlew

    local gradle_cmd=""
    local is_test=false

    if [[ "$build_type" == "TEST" || "$build_type" == "QA" || "$build_type" == "QC" ]]; then
        is_test=true
        info "Test-style: organic, campaign, review × Debug."
        gradle_cmd="./gradlew assembleOrganicDebug assembleCampaignDebug assembleReviewDebug"
    else
        local cap
        cap=$(capitalize_flavor "$RELEASE_FLAVOR")
        info "RC: ${RELEASE_FLAVOR}Release APK + AAB."
        gradle_cmd="./gradlew assemble${cap}Release bundle${cap}Release"
    fi

    if [ -n "$version_suffix" ]; then
        gradle_cmd="$gradle_cmd -PversionSuffix=\"$version_suffix\""
    fi

    info "Running: $gradle_cmd"
    eval "$gradle_cmd --no-daemon"

    local apk_list=""
    local aab_file=""

    if [ "$is_test" = true ]; then
        local f p
        for f in organic campaign review; do
            p=$(find "app/build/outputs/apk/${f}/debug" -name "*.apk" -type f 2>/dev/null | head -1)
            if [ -z "$p" ]; then
                error "APK not found for flavor ${f} (debug)"
            fi
            [[ "$p" != /* ]] && p="$ROOT_DIR/$p"
            apk_list="${apk_list:+$apk_list:}$p"
            info "✅ APK built: $p"
        done
    else
        local apk_file
        apk_file=$(ls -t "app/build/outputs/apk/${RELEASE_FLAVOR}/release"/*.apk 2>/dev/null | head -1)
        if [ -z "$apk_file" ]; then
            error "APK file not found after build!"
        fi
        [[ "$apk_file" != /* ]] && apk_file="$ROOT_DIR/$apk_file"
        apk_list="$apk_file"
        info "✅ APK built: $apk_file"

        aab_file=$(ls -t "app/build/outputs/bundle/${RELEASE_FLAVOR}Release"/*.aab 2>/dev/null | head -1)
        if [ -z "$aab_file" ]; then
            error "AAB file not found after build!"
        fi
        [[ "$aab_file" != /* ]] && aab_file="$ROOT_DIR/$aab_file"
        info "✅ AAB built: $aab_file"
    fi

    echo "$apk_list|$aab_file"
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
    error "Usage: $0 [options] <version> [--trigger-workflow]\nOptions:\n  -f, --force          Force rebuild APK/AAB before creating release\n  --test, --qa, --qc   Build type\n  --trigger-workflow   Trigger workflow dispatch after release\nExample: $0 --test 1.1.9\nExample: $0 -f --test 1.1.9"
fi

VERSION=""
TRIGGER_WORKFLOW=false
BUILD_TYPE="RC"
TAG_SUFFIX="-rc"
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        --test|--qa|--qc)
            BUILD_TYPE=$(echo "${1#--}" | tr '[:lower:]' '[:upper:]')
            TAG_SUFFIX="-${1#--}"
            shift
            ;;
        --trigger-workflow)
            TRIGGER_WORKFLOW=true
            shift
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION=$1
            else
                error "Unexpected argument: $1"
            fi
            shift
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    error "Version not provided. Usage: $0 [options] <version>"
fi

TAG_NAME="v${VERSION}${TAG_SUFFIX}"

if [ "$FORCE" = true ]; then
    info "Force rebuild enabled. Will rebuild APK/AAB before creating release."
fi

info "Recreating $BUILD_TYPE release for version: $VERSION"
info "Tag: $TAG_NAME"

# Check if tag exists
if ! git rev-parse -q --verify "refs/tags/$TAG_NAME" >/dev/null 2>&1; then
    warn "Tag $TAG_NAME does not exist locally. Fetching from remote..."
    git fetch origin --tags --quiet
    if ! git rev-parse -q --verify "refs/tags/$TAG_NAME" >/dev/null 2>&1; then
        warn "Tag $TAG_NAME does not exist on remote either. Creating it at current HEAD..."
        git tag "$TAG_NAME"
    fi
fi

# Check if tag exists on remote
git fetch --tags --quiet 2>/dev/null || true
if ! git ls-remote --tags origin "$TAG_NAME" | grep -q "$TAG_NAME"; then
    warn "Tag $TAG_NAME does not exist on remote. Pushing tag..."
    git push origin "$TAG_NAME"
    sleep 2
fi

# Build or find build files
if [ "$FORCE" = true ]; then
    # Determine version suffix for build
    VERSION_SUFFIX=""
    if [[ "$BUILD_TYPE" != "RC" ]]; then
        VERSION_SUFFIX="$TAG_SUFFIX"  # e.g., "-test", "-qa", "-qc"
    fi
    
    # Build release
    BUILD_OUTPUT=$(build_release "$BUILD_TYPE" "$VERSION_SUFFIX")
    APK_LIST_CSV=$(echo "$BUILD_OUTPUT" | cut -d'|' -f1)
    AAB_FILE=$(echo "$BUILD_OUTPUT" | cut -d'|' -f2)

    info "Using newly built file(s):"
    IFS=':' read -ra _BL <<< "$APK_LIST_CSV"
    for _f in "${_BL[@]}"; do
        info "  APK: $(basename "$_f")"
    done
    [ -n "$AAB_FILE" ] && info "  AAB: $(basename "$AAB_FILE")"
else
    info "Looking for existing build files..."
    APK_LIST_CSV=""
    AAB_FILE=""

    if [[ "$BUILD_TYPE" == "TEST" || "$BUILD_TYPE" == "QA" || "$BUILD_TYPE" == "QC" ]]; then
        for f in organic campaign review; do
            p=$(find "$ROOT_DIR/app/build/outputs/apk/${f}/debug" -name "*${VERSION}*.apk" -type f 2>/dev/null | head -1)
            [ -z "$p" ] && p=$(ls -t "$ROOT_DIR/app/build/outputs/apk/${f}/debug"/*.apk 2>/dev/null | head -1)
            [ -z "$p" ] && error "APK not found for $f debug. Build with -f or run Gradle."
            APK_LIST_CSV="${APK_LIST_CSV:+$APK_LIST_CSV:}$p"
        done
    else
        APK_FILE=$(find "$ROOT_DIR/app/build/outputs/apk/${RELEASE_FLAVOR}/release" -name "*${VERSION}*.apk" -type f 2>/dev/null | head -1)
        [ -z "$APK_FILE" ] && APK_FILE=$(ls -t "$ROOT_DIR/app/build/outputs/apk/${RELEASE_FLAVOR}/release"/*.apk 2>/dev/null | head -1)
        [ -z "$APK_FILE" ] && error "APK not found under app/build/outputs/apk/${RELEASE_FLAVOR}/release"
        APK_LIST_CSV="$APK_FILE"

        AAB_FILE=$(find "$ROOT_DIR/app/build/outputs/bundle/${RELEASE_FLAVOR}Release" -name "*${VERSION}*.aab" -type f 2>/dev/null | head -1)
        [ -z "$AAB_FILE" ] && AAB_FILE=$(ls -t "$ROOT_DIR/app/build/outputs/bundle/${RELEASE_FLAVOR}Release"/*.aab 2>/dev/null | head -1)
        [ -z "$AAB_FILE" ] && warn "AAB not found for RC. Only APK(s) will be uploaded."
    fi

    info "Found build files:"
    IFS=':' read -ra _BL <<< "$APK_LIST_CSV"
    for _f in "${_BL[@]}"; do
        info "  APK: $(basename "$_f")"
    done
    [ -n "$AAB_FILE" ] && info "  AAB: $(basename "$AAB_FILE")"
fi

# Get repo name
REPO=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:/]([^/]+\/[^/]+)(\.git)?$/\1/' | sed 's/\.git$//')

if [ -z "$REPO" ]; then
    error "Could not determine repository name"
fi

info "Repository: $REPO"

# Check if release already exists
info "Checking if release exists..."
RELEASE_CHECK=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/releases/tags/$TAG_NAME")

HTTP_CODE=$(echo "$RELEASE_CHECK" | tail -1)
RELEASE_BODY=$(echo "$RELEASE_CHECK" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    RELEASE_ID=$(echo "$RELEASE_BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    warn "Release already exists (ID: $RELEASE_ID). Deleting it..."
    
    DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO/releases/$RELEASE_ID")
    
    DELETE_CODE=$(echo "$DELETE_RESPONSE" | tail -1)
    if [ "$DELETE_CODE" != "204" ]; then
        error "Failed to delete existing release (HTTP $DELETE_CODE)"
    fi
    info "✅ Deleted existing release"
    sleep 2
fi

# Create new release
info "Creating new release..."
release_title="Release Candidate $VERSION"
if [ "$BUILD_TYPE" != "RC" ]; then
    release_title="$BUILD_TYPE Build $VERSION"
fi

RELEASE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    "https://api.github.com/repos/$REPO/releases" \
    -d "{
        \"tag_name\": \"$TAG_NAME\",
        \"name\": \"$release_title\",
        \"body\": \"$BUILD_TYPE Build $VERSION\\n\\nRecreated release\",
        \"prerelease\": true
    }")

HTTP_CODE=$(echo "$RELEASE_RESPONSE" | tail -1)
RELEASE_BODY=$(echo "$RELEASE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "201" ]; then
    error "Failed to create release (HTTP $HTTP_CODE)\n$RELEASE_BODY"
fi

# Parse release ID - try multiple methods
RELEASE_ID=$(echo "$RELEASE_BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
if [ -z "$RELEASE_ID" ]; then
    # Try alternative parsing
    RELEASE_ID=$(echo "$RELEASE_BODY" | sed -n 's/.*"id": *\([0-9]*\).*/\1/p' | head -1)
fi

# Parse upload URL
UPLOAD_URL=$(echo "$RELEASE_BODY" | grep -o '"upload_url":"[^"]*' | cut -d'"' -f4 | sed 's/{?name,label}//')
if [ -z "$UPLOAD_URL" ]; then
    # Try alternative parsing
    UPLOAD_URL=$(echo "$RELEASE_BODY" | sed -n 's/.*"upload_url": *"\([^"]*\)".*/\1/p' | head -1 | sed 's/{?name,label}//')
fi

if [ -z "$RELEASE_ID" ]; then
    warn "Failed to parse release ID. Response preview:"
    echo "$RELEASE_BODY" | head -10
    error "Failed to parse release ID from response"
fi

if [ -z "$UPLOAD_URL" ]; then
    warn "Failed to parse upload URL. Response preview:"
    echo "$RELEASE_BODY" | head -10
    error "Failed to parse upload URL from response"
fi

info "✅ Release created (ID: $RELEASE_ID)"

# Upload APK
info "Uploading APK..."
APK_NAME=$(basename "$APK_FILE")
APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
info "  File: $APK_NAME ($APK_SIZE)"
info "  This may take a few minutes for large files..."

UPLOAD_APK=$(curl --max-time 600 --show-error -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/vnd.android.package-archive" \
    --data-binary "@$APK_FILE" \
    "${UPLOAD_URL}?name=$APK_NAME" 2>&1)

APK_CODE=$(echo "$UPLOAD_APK" | tail -1)
APK_RESPONSE=$(echo "$UPLOAD_APK" | sed '$d')

if [ "$APK_CODE" = "201" ]; then
    info "✅ APK uploaded successfully"
else
    warn "⚠️  APK upload failed (HTTP $APK_CODE)"
    if [ -n "$APK_RESPONSE" ]; then
        warn "Response: $(echo "$APK_RESPONSE" | head -3)"
    fi
fi

# Upload AAB
if [ -n "$AAB_FILE" ]; then
    info "Uploading AAB..."
    AAB_NAME=$(basename "$AAB_FILE")
    AAB_SIZE=$(du -h "$AAB_FILE" | cut -f1)
    info "  File: $AAB_NAME ($AAB_SIZE)"
    info "  This may take a few minutes for large files..."

    UPLOAD_AAB=$(curl --max-time 600 --show-error -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$AAB_FILE" \
        "${UPLOAD_URL}?name=$AAB_NAME" 2>&1)

    AAB_CODE=$(echo "$UPLOAD_AAB" | tail -1)
    AAB_RESPONSE=$(echo "$UPLOAD_AAB" | sed '$d')

    if [ "$AAB_CODE" = "201" ]; then
        info "✅ AAB uploaded successfully"
    else
        warn "⚠️  AAB upload failed (HTTP $AAB_CODE)"
        if [ -n "$AAB_RESPONSE" ]; then
            warn "Response: $(echo "$AAB_RESPONSE" | head -3)"
        fi
    fi
fi

# Trigger workflow if requested
if [ "$TRIGGER_WORKFLOW" = true ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    WORKFLOW_FILE="release-rc.yml"
    
    # Check if workflow exists first
    info "Checking workflow access..."
    WORKFLOW_CHECK=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW_FILE")
    
    CHECK_CODE=$(echo "$WORKFLOW_CHECK" | tail -1)
    if [ "$CHECK_CODE" != "200" ]; then
        if [ "$CHECK_CODE" = "404" ]; then
            warn "Workflow file not found: $WORKFLOW_FILE (HTTP 404)"
            warn "The workflow might not exist on the current branch ($CURRENT_BRANCH)."
            warn "Will attempt to trigger workflow anyway - it may fail if workflow doesn't exist."
        elif [ "$CHECK_CODE" = "403" ]; then
            warn "Cannot access workflow file: $WORKFLOW_FILE (HTTP 403)"
            warn "This usually means your token doesn't have Actions permission."
        else
            warn "Unexpected HTTP code when checking workflow: $CHECK_CODE"
        fi
    else
        info "✅ Workflow file found and accessible"
    fi
    
    info "Triggering workflow dispatch..."
    WORKFLOW_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW_FILE/dispatches" \
        -d "{
            \"ref\": \"$CURRENT_BRANCH\",
            \"inputs\": {
                \"tag_name\": \"$TAG_NAME\",
                \"build_type\": \"$BUILD_TYPE\"
            }
        }")
    
    WORKFLOW_CODE=$(echo "$WORKFLOW_RESPONSE" | tail -1)
    WORKFLOW_BODY=$(echo "$WORKFLOW_RESPONSE" | sed '$d')
    
    if [ "$WORKFLOW_CODE" = "204" ]; then
        info "✅ Workflow dispatch triggered successfully"
    else
        if [ "$WORKFLOW_CODE" = "403" ]; then
            warn "⚠️  Workflow dispatch failed (HTTP 403 - Permission denied)"
            warn "Your GITHUB_TOKEN doesn't have permission to trigger workflows."
            warn "To fix this:"
            warn "  1. For classic tokens: Add 'workflow' scope"
            warn "  2. For fine-grained tokens: Add 'Actions: Write' permission"
        elif [ "$WORKFLOW_CODE" = "404" ]; then
            warn "⚠️  Workflow dispatch failed (HTTP 404)"
            warn "Workflow '$WORKFLOW_FILE' not found on branch '$CURRENT_BRANCH'."
            warn "The workflow might only exist on the default branch (main/master)."
            warn "You can manually trigger the workflow from GitHub Actions UI if needed."
        else
            warn "⚠️  Workflow dispatch failed (HTTP $WORKFLOW_CODE)"
            if [ -n "$WORKFLOW_BODY" ]; then
                warn "Response: $(echo "$WORKFLOW_BODY" | head -3)"
            fi
        fi
    fi
fi

info ""
info "✅ Release recreated successfully!"
info "   Tag: $TAG_NAME"
info "   Release ID: $RELEASE_ID"
info "   URL: https://github.com/$REPO/releases/tag/$TAG_NAME"
