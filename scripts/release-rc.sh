#!/bin/bash

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_GRADLE="$ROOT_DIR/app/build.gradle.kts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

function load_env_file() {
    local env_file="$SCRIPT_DIR/.env"
    
    if [ -f "$env_file" ]; then
        info "Loading environment variables from $env_file..."
        
        # Read .env file line by line
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip empty lines and comments
            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                continue
            fi
            
            # Skip lines that don't look like KEY=VALUE
            if [[ ! "$line" =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*= ]]; then
                continue
            fi
            
            # Remove leading/trailing whitespace
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Extract key and value
            local key=$(echo "$line" | cut -d'=' -f1)
            local value=$(echo "$line" | cut -d'=' -f2-)
            
            # Remove quotes if present
            value=$(echo "$value" | sed -E "s/^['\"]|['\"]$//g")
            
            # .env file overrides environment variables
            export "$key=$value"
        done < "$env_file"
        
        info "✅ Environment variables loaded"
    else
        warn ".env file not found at $env_file (optional)"
    fi
}

function get_current_version() {
    # Only defaultConfig versionName — not versionNameSuffix / string templates
    local version_name
    version_name=$(grep -E '^[[:space:]]*versionName[[:space:]]*=' "$BUILD_GRADLE" | head -1 | sed -E 's/.*versionName[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/')
    local version_code
    version_code=$(grep -E '^[[:space:]]*versionCode[[:space:]]*=' "$BUILD_GRADLE" | head -1 | sed -E 's/.*versionCode[[:space:]]*=[[:space:]]*([0-9]+).*/\1/')
    echo "$version_name|$version_code"
}

function validate_version() {
    local version=$1
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
        error "Invalid version format: $version. Must be semver (e.g., 1.0.0, 1.0.0-beta.1)"
    fi
}

function bump_version() {
    local current_version=$1
    local bump_type=$2
    
    IFS='.' read -ra PARTS <<< "$current_version"
    local major=${PARTS[0]}
    local minor=${PARTS[1]}
    local patch=${PARTS[2]%%-*}  # Remove any pre-release suffix
    
    case "$bump_type" in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "$major.$((minor + 1)).0"
            ;;
        patch)
            echo "$major.$minor.$((patch + 1))"
            ;;
        *)
            error "Invalid bump type: $bump_type. Use major, minor, or patch"
            ;;
    esac
}

function set_version() {
    local new_version_name=$1
    local new_version_code=$2
    
    # Backup the file
    cp "$BUILD_GRADLE" "$BUILD_GRADLE.bak"
    
    # Kotlin DSL: versionName = "..." / versionCode = N
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "s/^([[:space:]]*versionName[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"$new_version_name\"/" "$BUILD_GRADLE"
        sed -i '' -E "s/^([[:space:]]*versionCode[[:space:]]*=[[:space:]]*)[0-9]+/\1$new_version_code/" "$BUILD_GRADLE"
    else
        sed -i -E "s/^([[:space:]]*versionName[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"$new_version_name\"/" "$BUILD_GRADLE"
        sed -i -E "s/^([[:space:]]*versionCode[[:space:]]*=[[:space:]]*)[0-9]+/\1$new_version_code/" "$BUILD_GRADLE"
    fi
    
    # Remove backup
    rm -f "$BUILD_GRADLE.bak"
}

# Store / RC flavor — must match app/build.gradle.kts productFlavors
# Local RC builds prod only; CI *-rc tags build organic/campaign/review (see test-rc-build.yml)
RELEASE_FLAVOR="prod"

function capitalize_flavor() {
    local f="$1"
    local c1 rest
    c1=$(echo "${f:0:1}" | tr '[:lower:]' '[:upper:]')
    rest="${f:1}"
    echo "${c1}${rest}"
}

function find_existing_builds() {
    local version_name=$1
    local version_code=$2
    local mode=${3:-rc} # rc | test

    cd "$ROOT_DIR"

    if [ -z "$version_name" ] || [ -z "$version_code" ]; then
        local version_info=$(get_current_version)
        version_name=$(echo "$version_info" | cut -d'|' -f1)
        version_code=$(echo "$version_info" | cut -d'|' -f2)
    fi

    info "Looking for build files matching version: $version_name (code: $version_code) [mode=$mode]"

    local version_pattern
    version_pattern=$(echo "$version_name" | sed 's/\./\\./g')
    # Prefer APKs that embed version in the filename; else fall back to newest in flavor dir
    local apk_pattern="${version_pattern}"

    local apk_file=""
    local aab_file=""

    if [ "$mode" = "test" ]; then
        local list=""
        for f in organic campaign review; do
            local p
            p=$(find "app/build/outputs/apk/${f}/debug" -name "*.apk" -type f 2>/dev/null | grep -E "${apk_pattern}" | head -1)
            [ -z "$p" ] && p=$(ls -t "app/build/outputs/apk/${f}/debug"/*.apk 2>/dev/null | head -1)
            if [ -z "$p" ]; then
                echo ""
                return
            fi
            [[ "$p" != /* ]] && p="$ROOT_DIR/$p"
            list="${list:+$list:}$p"
        done
        echo "${list}|"
        return
    else
        apk_file=$(find "app/build/outputs/apk/${RELEASE_FLAVOR}/release" -name "*.apk" -type f 2>/dev/null | grep -E "${apk_pattern}" | head -1)
        [ -z "$apk_file" ] && apk_file=$(ls -t "app/build/outputs/apk/${RELEASE_FLAVOR}/release"/*.apk 2>/dev/null | head -1)
        [ -n "$apk_file" ] && [[ "$apk_file" != /* ]] && apk_file="$ROOT_DIR/$apk_file"

        aab_file=$(find "app/build/outputs/bundle/${RELEASE_FLAVOR}Release" -name "*.aab" -type f 2>/dev/null | grep -E "${apk_pattern}" | head -1)
        [ -z "$aab_file" ] && aab_file=$(ls -t "app/build/outputs/bundle/${RELEASE_FLAVOR}Release"/*.aab 2>/dev/null | head -1)
        [ -n "$aab_file" ] && [[ "$aab_file" != /* ]] && aab_file="$ROOT_DIR/$aab_file"
    fi

    if [ -n "$apk_file" ] && [ -n "$aab_file" ]; then
        echo "$apk_file|$aab_file"
    else
        echo ""
    fi
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

function build_release() {
    local build_type=$1
    local version_suffix=$2

    info "\n🔨 Building release (productFlavors: app/build.gradle.kts)..."

    cd "$ROOT_DIR"

    if [ ! -f "./gradlew" ]; then
        error "gradlew not found. Make sure you're in the project root."
    fi

    chmod +x ./gradlew

    info "🧹 Cleaning the project..."
    ./gradlew clean >&2

    local gradle_cmd=""
    local is_test=false

    if [[ "$build_type" == "TEST" || "$build_type" == "QA" || "$build_type" == "QC" ]]; then
        is_test=true
        info "Test-style build: organic, campaign, review × Debug (matches CI *-test pattern)."
        gradle_cmd="./gradlew assembleOrganicDebug assembleCampaignDebug assembleReviewDebug"
    else
        local cap
        cap=$(capitalize_flavor "$RELEASE_FLAVOR")
        info "RC / store-style build: ${RELEASE_FLAVOR}Release APK + AAB (matches CI prod release)."
        gradle_cmd="./gradlew assemble${cap}Release bundle${cap}Release"
    fi

    if [ -n "$version_suffix" ]; then
        gradle_cmd="$gradle_cmd -PversionSuffix=\"$version_suffix\""
    fi

    info "Running: $gradle_cmd"
    eval "$gradle_cmd --no-daemon" >&2

    local apk_list=""
    local aab_file=""

    if [ "$is_test" = true ]; then
        local f p
        for f in organic campaign review; do
            p=$(find "app/build/outputs/apk/${f}/debug" -name "*.apk" -type f 2>/dev/null | head -1)
            if [ -z "$p" ]; then
                error "APK not found for flavor ${f} (debug). Expected app/build/outputs/apk/${f}/debug/"
            fi
            [[ "$p" != /* ]] && p="$ROOT_DIR/$p"
            apk_list="${apk_list:+$apk_list:}$p"
            info "✅ APK built: $p"
        done
    else
        local apk_file
        apk_file=$(ls -t "app/build/outputs/apk/${RELEASE_FLAVOR}/release"/*.apk 2>/dev/null | head -1)
        if [ -z "$apk_file" ]; then
            error "APK file not found after build (expected app/build/outputs/apk/${RELEASE_FLAVOR}/release/)"
        fi
        [[ "$apk_file" != /* ]] && apk_file="$ROOT_DIR/$apk_file"
        apk_list="$apk_file"
        info "✅ APK built: $apk_file"

        aab_file=$(ls -t "app/build/outputs/bundle/${RELEASE_FLAVOR}Release"/*.aab 2>/dev/null | head -1)
        if [ -z "$aab_file" ]; then
            error "AAB file not found after build (expected app/build/outputs/bundle/${RELEASE_FLAVOR}Release/)"
        fi
        [[ "$aab_file" != /* ]] && aab_file="$ROOT_DIR/$aab_file"
        info "✅ AAB built: $aab_file"
    fi

    echo "$apk_list|$aab_file"
}

function create_github_release() {
    local tag_name=$1
    local version_name=$2
    local github_token=$3
    local apk_list_csv=$4
    local aab_file=$5
    local build_type=$6

    cd "$ROOT_DIR"

    if [ -z "$apk_list_csv" ]; then
        error "APK path list is empty (colon-separated flavor APK paths)"
    fi

    if [ -n "$aab_file" ]; then
        if [[ "$aab_file" != /* ]]; then
            aab_file="$ROOT_DIR/$aab_file"
        fi
        if [ ! -f "$aab_file" ]; then
            warn "AAB file not found: $aab_file (skipping AAB upload)"
            aab_file=""
        fi
    fi

    local _apk
    local _first=1
    IFS=':' read -ra _APK_ARR <<< "$apk_list_csv"
    for _apk in "${_APK_ARR[@]}"; do
        [ -z "$_apk" ] && continue
        if [[ "$_apk" != /* ]]; then
            _apk="$ROOT_DIR/$_apk"
        fi
        if [ ! -f "$_apk" ]; then
            error "APK file not found: $_apk"
        fi
        if [ "$_first" = 1 ]; then
            info "APK(s) to upload:"
            _first=0
        fi
        info "  $_apk ($(ls -lh "$_apk" | awk '{print $5}'))"
    done
    if [ -n "$aab_file" ]; then
        info "AAB file: $aab_file ($(ls -lh "$aab_file" | awk '{print $5}'))"
    fi
    
    info "\n📦 Creating GitHub Release: $tag_name..."
    
    # Get repository info
    local remote_url=$(git config --get remote.origin.url)
    local repo=$(echo "$remote_url" | sed -E 's/.*github.com[:/]([^/]+\/[^/]+)(\.git)?$/\1/' | sed 's/\.git$//')
    
    if [ -z "$repo" ]; then
        error "Could not parse repository name from: $remote_url"
    fi
    
    info "Repository: $repo"
    
    # Test token and repository access
    info "Testing GitHub API access..."
    local test_response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$repo")
    
    local test_http_code=$(echo "$test_response" | tail -1)
    local test_body=$(echo "$test_response" | sed '$d')
    
    if [ "$test_http_code" != "200" ]; then
        error "Failed to access repository. HTTP $test_http_code\nResponse: $test_body"
    fi
    
    info "✅ Repository access confirmed"
    
    # Check if release already exists
    info "Checking if release exists for tag $tag_name..."
    local release_check=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$repo/releases/tags/$tag_name")
    
    local check_http_code=$(echo "$release_check" | tail -1)
    local check_body=$(echo "$release_check" | sed '$d')
    
    if [ "$check_http_code" = "200" ]; then
        local existing_release_id=$(echo "$check_body" | grep -oE '"id"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')
        warn "Release already exists (ID: $existing_release_id). Deleting it to recreate..."
        
        local delete_response=$(curl -s -w "\n%{http_code}" -X DELETE \
            -H "Authorization: Bearer $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/repos/$repo/releases/$existing_release_id")
        
        local delete_code=$(echo "$delete_response" | tail -1)
        if [ "$delete_code" != "204" ]; then
            error "Failed to delete existing release (HTTP $delete_code)"
        fi
        info "✅ Deleted existing release"
        sleep 2
    fi

    # Create release via GitHub API
    local release_title="Release Candidate $version_name"
    if [ "$build_type" != "RC" ]; then
        release_title="$build_type Build $version_name"
    fi

    info "Creating release..."
    local release_response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/$repo/releases" \
        -d "{
            \"tag_name\": \"$tag_name\",
            \"name\": \"$release_title\",
            \"body\": \"$build_type build for $version_name\\n\\nThis is an automated $build_type build.\",
            \"prerelease\": true,
            \"draft\": false
        }")
    
    local http_code=$(echo "$release_response" | tail -1)
    local release_body=$(echo "$release_response" | sed '$d')
    
    if [ "$http_code" != "201" ]; then
        error "Failed to create release. HTTP $http_code\nResponse: $release_body"
    fi
    
    # Parse release ID and upload URL
    local release_id=$(echo "$release_body" | grep -oE '"id"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')
    local upload_url=$(echo "$release_body" | grep -oE '"upload_url"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | cut -d'"' -f4 | sed 's/{?name,label}//')
    
    if [ -z "$release_id" ] || [ "$release_id" = "null" ]; then
        error "Could not extract release ID from response: $release_body"
    fi

    if [ -z "$upload_url" ]; then
        error "Could not extract upload URL from response: $release_body"
    fi
    
    info "✅ Release created with ID: $release_id"

    local apk_success=false
    local all_apk_ok=true
    info "\n📤 Uploading APK(s)..."
    for _apk in "${_APK_ARR[@]}"; do
        [ -z "$_apk" ] && continue
        if [[ "$_apk" != /* ]]; then
            _apk="$ROOT_DIR/$_apk"
        fi
        local apk_filename
        apk_filename=$(unique_apk_upload_name "$_apk")
        local upload_apk_response
        upload_apk_response=$(curl --max-time 600 --show-error -s -w "\n%{http_code}" -X POST \
            -H "Authorization: Bearer $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -H "Content-Type: application/vnd.android.package-archive" \
            --data-binary "@$_apk" \
            "${upload_url}?name=$apk_filename")
        local apk_http_code
        apk_http_code=$(echo "$upload_apk_response" | tail -1)
        if [ "$apk_http_code" != "201" ]; then
            warn "Failed to upload APK ($apk_filename). HTTP $apk_http_code"
            echo "$upload_apk_response" | sed '$d'
            all_apk_ok=false
        else
            info "✅ APK uploaded: $apk_filename"
        fi
    done
    if [ "$all_apk_ok" = true ]; then
        apk_success=true
    fi
    
    # Upload AAB
    local aab_success=false
    if [ -n "$aab_file" ]; then
        info "\n📤 Uploading AAB..."
        local aab_filename=$(basename "$aab_file")
        local upload_aab_response=$(curl --max-time 600 --show-error -s -w "\n%{http_code}" -X POST \
            -H "Authorization: Bearer $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -H "Content-Type: application/octet-stream" \
            --data-binary "@$aab_file" \
            "${upload_url}?name=$aab_filename")
        
        local aab_http_code=$(echo "$upload_aab_response" | tail -1)
        if [ "$aab_http_code" != "201" ]; then
            warn "Failed to upload AAB. HTTP $aab_http_code"
            echo "$upload_aab_response" | sed '$d'
        else
            info "✅ AAB uploaded: $aab_filename"
            aab_success=true
        fi
    else
        # AAB is optional for test builds
        aab_success=true
    fi
    
    # Return release_id and upload status
    echo "$release_id|$apk_success|$aab_success"
}

function trigger_workflow_dispatch() {
    local tag_name=$1
    local github_token=$2
    local build_type=$3
    
    info "\n🔔 Triggering workflow dispatch for notification..."
    
    # Get repository info
    local remote_url=$(git config --get remote.origin.url)
    local repo=$(echo "$remote_url" | sed -E 's/.*github.com[:/]([^/]+\/[^/]+)(\.git)?$/\1/' | sed 's/\.git$//')
    
    if [ -z "$repo" ]; then
        warn "Could not determine repository. Skipping workflow dispatch."
        return 1
    fi
    
    info "Repository: $repo"
    
    # Get workflow file name (should be release-rc.yml)
    local workflow_file="release-rc.yml"
    
    # Get current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ -z "$current_branch" ]; then
        error "Could not determine current branch."
        return 1
    fi
    
    info "Current branch: $current_branch"
    
    # Trigger workflow dispatch
    info "Triggering workflow dispatch..."
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$repo/actions/workflows/$workflow_file/dispatches" \
        -d "{
            \"ref\": \"$current_branch\",
            \"inputs\": {
                \"tag_name\": \"$tag_name\",
                \"build_type\": \"$build_type\"
            }
        }")
    
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "204" ]; then
        info "✅ Workflow dispatch triggered successfully"
        return 0
    else
        warn "Failed to trigger workflow dispatch. HTTP $http_code"
        if [ -n "$body" ]; then
            echo "$body" >&2
        fi
        return 1
    fi
}

function main() {
    local force_build=false
    local version_arg=""
    local build_type="RC"
    local version_suffix=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force_build=true
                shift
                ;;
            --test|--qa|--qc)
                # Convert --test to TEST, --qa to QA, etc.
                build_type=$(echo "${1#--}" | tr '[:lower:]' '[:upper:]')
                shift
                ;;
            -h|--help)
                error "Usage: ./scripts/release-rc.sh [options] [version|major|minor|patch]\n" \
                      "Options:\n" \
                      "  -f, --force    Force rebuild even if build files exist\n" \
                      "  --test         Build for TEST (only APK, adds -test suffix)\n" \
                      "  --qa           Build for QA (only APK, adds -qa suffix)\n" \
                      "  --qc           Build for QC (only APK, adds -qc suffix)\n\n" \
                      "Examples:\n" \
                      "  ./scripts/release-rc.sh patch           # 1.0.0 -> 1.0.1-rc (APK + AAB)\n" \
                      "  ./scripts/release-rc.sh --test patch    # 1.0.0 -> 1.0.1-test (Only APK)\n" \
                      "  ./scripts/release-rc.sh --qa minor      # 1.0.0 -> 1.1.0-qa (Only APK)\n" \
                      "  ./scripts/release-rc.sh 1.2.3           # Create v1.2.3-rc\n\n" \
                      "Environment variables:\n" \
                      "  GITHUB_TOKEN - GitHub personal access token\n"
                ;;
            *)
                if [ -z "$version_arg" ]; then
                    version_arg=$1
                else
                    error "Unexpected argument: $1\nUse -h or --help for usage information"
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$version_arg" ]; then
        error "Usage: ./scripts/release-rc.sh [options] [version|major|minor|patch]. Use -h for help."
    fi
    
    # Load environment variables from .env file
    load_env_file
    
    # Check for GitHub token
    if [ -z "$GITHUB_TOKEN" ]; then
        error "GITHUB_TOKEN environment variable is required."
    fi
    
    # Get current version
    local version_info=$(get_current_version)
    local current_version_name=$(echo "$version_info" | cut -d'|' -f1)
    local current_version_code=$(echo "$version_info" | cut -d'|' -f2)
    
    info "Current version: $current_version_name (code: $current_version_code)"
    
    # Determine new version
    local new_version_name
    local new_version_code
    
    if [[ "$version_arg" =~ ^(major|minor|patch)$ ]]; then
        new_version_name=$(bump_version "$current_version_name" "$version_arg")
        new_version_code=$((current_version_code + 1))
    else
        new_version_name="$version_arg"
        validate_version "$new_version_name"
        
        # Always increment versionCode (Android requirement)
        # versionCode must always increase for Play Store and device updates
        new_version_code=$((current_version_code + 1))
        if [[ "$build_type" != "RC" && "$new_version_name" == "$current_version_name" ]]; then
            info "Test build with existing version name $new_version_name. Incrementing versionCode: $current_version_code -> $new_version_code"
        fi
    fi
    
    # Set tag name and version suffix based on build type
    local tag_name
    if [ "$build_type" = "RC" ]; then
        tag_name="v${new_version_name}-rc"
        version_suffix="" # RC uses standard versionName
    else
        version_suffix="-$(echo "$build_type" | tr '[:upper:]' '[:lower:]')" # e.g., -test, -qa
        tag_name="v${new_version_name}${version_suffix}"
    fi
    
    info "Build type: $build_type"
    info "New version base: $new_version_name (code: $new_version_code)"
    if [ -n "$version_suffix" ]; then
        info "Version suffix: $version_suffix"
    fi
    info "Tag name: $tag_name"
    
    # Check if there are uncommitted changes (except build outputs)
    if [ -n "$(git status --porcelain | grep -v 'app/build/')" ]; then
        error "You have uncommitted changes. Please commit or stash them first."
    fi
    
    # Check if tag exists on remote
    info "Checking if tag exists on remote..."
    git fetch --tags --quiet 2>/dev/null || true
    
    # Allow rebuilding tags - delete existing tag if it exists (release will be recreated)
    if git ls-remote --tags origin "$tag_name" | grep -q "$tag_name"; then
        warn "Tag $tag_name already exists on remote. Will delete and recreate it for rebuild..."
        git push origin --delete "$tag_name" 2>/dev/null || warn "Failed to delete remote tag (may not exist)"
    fi
    
    # If tag exists locally, remove it
    if git rev-parse -q --verify "refs/tags/$tag_name" >/dev/null 2>&1; then
        warn "Tag $tag_name exists locally. Removing local tag..."
        git tag -d "$tag_name" || warn "Failed to delete local tag"
    fi
    
    # Update build.gradle.kts (versionName and versionCode)
    # Note: versionSuffix is passed via Gradle property during build
    info "\n📝 Updating app/build.gradle.kts..."
    set_version "$new_version_name" "$new_version_code"
    
    # Build release
    # Capture output and get only the last line (which contains the file paths)
    local build_output=$(build_release "$build_type" "$version_suffix")
    local last_line
    last_line=$(echo "$build_output" | tail -1)
    local apk_list_csv
    apk_list_csv=$(echo "$last_line" | cut -d'|' -f1)
    local aab_file
    aab_file=$(echo "$last_line" | cut -d'|' -f2)

    if [ -z "$apk_list_csv" ]; then
        error "Failed to build APK(s)."
    fi
    
    # Commit the version change (only if there are changes)
    info "\n📦 Committing version change..."
    git add app/build.gradle.kts
    HAS_COMMIT=false
    if ! git diff --cached --quiet app/build.gradle.kts; then
        git commit -m "chore: bump version to $new_version_name (code: $new_version_code) [$build_type]"
        HAS_COMMIT=true
    else
        warn "No version changes detected in build.gradle.kts. Skipping commit."
        info "Version name: $new_version_name (code: $new_version_code) is already set."
    fi
    
    # Create git tag
    info "\n🏷️  Creating git tag $tag_name..."
    git tag -a "$tag_name" -m "$build_type build $new_version_name"
    
    # Push commit and tag
    info "\n🚀 Pushing commit and tag to GitHub..."
    if [ "$HAS_COMMIT" = true ]; then
        git push origin HEAD
    fi
    git push origin "$tag_name"
    
    # Wait for GitHub
    sleep 2
    
    # Create GitHub release and upload files
    local release_result
    release_result=$(create_github_release "$tag_name" "$new_version_name$version_suffix" "$GITHUB_TOKEN" "$apk_list_csv" "$aab_file" "$build_type")
    local apk_success=$(echo "$release_result" | cut -d'|' -f2)
    
    # Trigger workflow dispatch
    if [ "$apk_success" = "true" ]; then
        trigger_workflow_dispatch "$tag_name" "$GITHUB_TOKEN" "$build_type"
    else
        warn "Skipping workflow dispatch because APK failed to upload"
    fi
    
    info "\n✅ Successfully created $build_type release $tag_name!"
}

main "$@"

