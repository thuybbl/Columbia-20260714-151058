#!/bin/bash

set -e

# --- Cấu hình đường dẫn ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_GRADLE="$ROOT_DIR/app/build.gradle.kts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function error() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }
function info() { echo -e "${GREEN}$1${NC}"; }
function warn() { echo -e "${YELLOW}$1${NC}"; }

function have_origin_remote() {
    git remote get-url origin >/dev/null 2>&1
}

# Returns 0 if origin has refs/tags/<name> (lightweight or annotated).
function remote_tag_exists() {
    local t=$1
    have_origin_remote || return 1
    local out
    out=$(git ls-remote -q origin "refs/tags/$t" 2>/dev/null || true)
    [ -n "$out" ]
}

function local_tag_exists() {
    git rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1
}

function delete_local_tag_if_exists() {
    local t=$1
    if local_tag_exists "$t"; then
        git tag -d "$t"
        info "Removed local tag $t"
    fi
}

function delete_remote_tag_if_exists() {
    local t=$1
    have_origin_remote || return 0
    if remote_tag_exists "$t"; then
        if git push origin --delete "$t"; then
            info "Removed remote tag $t on origin"
        else
            error "Failed to delete remote tag $t on origin. Run: git push origin --delete $t"
        fi
    fi
}

function get_current_version() {
    # Only defaultConfig assignment lines — not versionNameSuffix / templates
    local version_name
    version_name=$(grep -E '^[[:space:]]*versionName[[:space:]]*=' "$BUILD_GRADLE" | head -1 | sed -E 's/.*versionName[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/')
    local version_code
    version_code=$(grep -E '^[[:space:]]*versionCode[[:space:]]*=' "$BUILD_GRADLE" | head -1 | sed -E 's/.*versionCode[[:space:]]*=[[:space:]]*([0-9]+).*/\1/')
    if [ -z "$version_name" ]; then
        error "versionName is empty in app/build.gradle.kts defaultConfig. Set a semver (e.g. 1.0.0) before running release."
    fi
    echo "$version_name|$version_code"
}

function set_version() {
    local new_version_name=$1
    local new_version_code=$2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "s/^([[:space:]]*versionName[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"$new_version_name\"/" "$BUILD_GRADLE"
        sed -i '' -E "s/^([[:space:]]*versionCode[[:space:]]*=[[:space:]]*)[0-9]+/\1$new_version_code/" "$BUILD_GRADLE"
    else
        sed -i -E "s/^([[:space:]]*versionName[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"$new_version_name\"/" "$BUILD_GRADLE"
        sed -i -E "s/^([[:space:]]*versionCode[[:space:]]*=[[:space:]]*)[0-9]+/\1$new_version_code/" "$BUILD_GRADLE"
    fi
}

function main() {
    if [ $# -eq 0 ]; then
        error "Usage: ./scripts/release.sh [test|rc|patch|minor|major|version] [-f]"
    fi

    local force=false
    local args=()
    for arg in "$@"; do
        [[ "$arg" == "-f" || "$arg" == "--force" ]] && force=true || args+=("$arg")
    done

    local action=${args[0]}
    local version_info=$(get_current_version)
    local current_v_name=$(echo "$version_info" | cut -d'|' -f1)
    local current_v_code=$(echo "$version_info" | cut -d'|' -f2)

    local tag_name=""
    local should_commit=false

    case "$action" in
        test|rc)
            # Test/RC: tag is *-test or *-rc → GitHub runs test-rc-build.yml only (not build-release.yml).
            # Chế độ Test/RC: Giữ nguyên file, chỉ tạo Tag
            tag_name="v${current_v_name}-${action}"
            info "🛠  Mode: $(echo "$action" | tr '[:lower:]' '[:upper:]'). Using current version: $current_v_name"
            should_commit=false
            ;;
        patch|minor|major)
            # Chế độ Release: Tăng version, tạo Commit và Tag
            local new_v_name
            new_v_name=$("${SCRIPT_DIR}/bump_version_logic.sh" "$current_v_name" "$action")
            tag_name="v$new_v_name"
            new_v_code=$((current_v_code + 1))
            should_commit=true
            info "🚀 Mode: RELEASE ($action). New version: $new_v_name (code: $new_v_code)"
            ;;
        *)
            # Fix version cụ thể (action = semver string, e.g. 1.0.7)
            local new_v_name="$action"
            tag_name="v$new_v_name"
            new_v_code=$((current_v_code + 1))
            should_commit=true
            info "🎯 Mode: MANUAL. New version: $new_v_name"
            ;;
    esac

    # Tag trùng: kiểm tra cả local và origin (tránh push tag bị reject khi chỉ có tag trên remote)
    local has_local=false
    local has_remote=false
    local_tag_exists "$tag_name" && has_local=true
    remote_tag_exists "$tag_name" && has_remote=true

    if [ "$has_local" = true ] || [ "$has_remote" = true ]; then
        if [ "$force" != true ]; then
            error "Tag $tag_name already exists (local=$has_local, remote=$has_remote). Remove: git tag -d $tag_name and/or git push origin --delete $tag_name. Or use -f to replace local and remote tags."
        fi
        warn "Tag $tag_name already exists (local=$has_local remote=$has_remote). Replacing (-f)..."
        delete_local_tag_if_exists "$tag_name"
        delete_remote_tag_if_exists "$tag_name"
    fi

    if [ "$should_commit" = true ]; then
        # Thực hiện tăng version và commit
        if [ -n "$(git status --porcelain)" ]; then
            error "Uncommitted changes found. Please commit or stash first."
        fi
        set_version "$new_v_name" "$new_v_code"
        git add app/build.gradle.kts
        git commit -m "chore: bump version to $new_v_name"
        git push origin HEAD
    fi

    # Luôn tạo và push tag
    info "🏷  Creating and pushing tag: $tag_name"
    git tag -a "$tag_name" -m "Build for $action: $tag_name"
    git push origin "$tag_name"

    info "\n✅ Done! Triggered workflow for $tag_name"
}

main "$@"