#!/bin/bash

# Output key/value pairs for GitHub Actions secrets (release signing).
# Run locally and copy each value into Settings → Secrets and variables → Actions.
# Do not commit or share the console output.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_KEYSTORE="$ROOT_DIR/app/keystore.jks"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [KEYSTORE_PATH]

Generate GitHub Actions secret names and values for release build (keystore).
Prints to console so you can copy each value into GitHub → Settings → Secrets.

Arguments:
  KEYSTORE_PATH   Path to .jks keystore (default: app/keystore.jks)

Options:
  -n, --no-prompt   Use env only: KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD
  -h, --help        Show this help

Env (optional if not -n):
  KEYSTORE_PASSWORD   Keystore password
  KEY_ALIAS           Key alias (default: first alias from keystore)
  KEY_PASSWORD        Key password (default: KEYSTORE_PASSWORD)
EOF
}

NO_PROMPT=false
KEYSTORE="$DEFAULT_KEYSTORE"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--no-prompt)
            NO_PROMPT=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            usage >&2
            exit 1
            ;;
        *)
            KEYSTORE="$1"
            shift
            ;;
    esac
done

if [[ "$KEYSTORE" != /* ]]; then
    KEYSTORE="$ROOT_DIR/$KEYSTORE"
fi

if [[ ! -f "$KEYSTORE" ]]; then
    echo -e "${RED}Keystore not found: $KEYSTORE${NC}" >&2
    echo "Create one first: ./scripts/gen-key.sh -o app/keystore.jks" >&2
    exit 1
fi

STORE_PASS=""
KEY_ALIAS=""
KEY_PASS=""

if [[ "$NO_PROMPT" == true ]]; then
    STORE_PASS="${KEYSTORE_PASSWORD:?Set KEYSTORE_PASSWORD for non-interactive run}"
    KEY_ALIAS="${KEY_ALIAS:-}"
    KEY_PASS="${KEY_PASSWORD:-$STORE_PASS}"
fi

if [[ -z "$STORE_PASS" ]]; then
    echo -e "${CYAN}Keystore: $KEYSTORE${NC}"
    read -rsp "Keystore password: " STORE_PASS
    echo ""
fi

# Get first alias from keystore if not set
if [[ -z "$KEY_ALIAS" ]]; then
    KEY_ALIAS=$(keytool -list -keystore "$KEYSTORE" -storepass "$STORE_PASS" 2>/dev/null | grep -E "^\s+\w" | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk '{print $1}')
    if [[ -z "$KEY_ALIAS" ]]; then
        if [[ "$NO_PROMPT" == true ]]; then
            echo -e "${RED}Set KEY_ALIAS env or ensure keystore has an alias.${NC}" >&2
            exit 1
        fi
        echo -e "${RED}Could not read alias from keystore.${NC}" >&2
        read -rp "Key alias: " KEY_ALIAS
    fi
fi

if [[ -z "$KEY_PASS" ]] && [[ "$NO_PROMPT" != true ]]; then
    read -rsp "Key password (same as keystore if empty): " KEY_PASS
    echo ""
fi
KEY_PASS="${KEY_PASS:-$STORE_PASS}"

# Base64 encode keystore (single line for GitHub secret)
KEYSTORE_B64=$(base64 < "$KEYSTORE" | tr -d '\n')

echo ""
echo -e "${GREEN}=== Add these as GitHub Actions secrets ===${NC}"
echo -e "Repo → Settings → Secrets and variables → Actions → New repository secret"
echo ""
echo -e "${YELLOW}Do not commit or share this output. Clear terminal after copying.${NC}"
echo ""

print_secret() {
    local name="$1"
    local value="$2"
    local mask="${3:-}"
    echo -e "${CYAN}Secret name:${NC}  $name"
    if [[ -n "$mask" ]]; then
        echo -e "${CYAN}Value:${NC}       (paste the value below)"
        echo "$value"
    else
        echo -e "${CYAN}Value:${NC}       $value"
    fi
    echo ""
}

print_secret "KEYSTORE_BASE64"   "$KEYSTORE_B64" "mask"
print_secret "KEYSTORE_PASSWORD" "$STORE_PASS"  "mask"
print_secret "KEY_ALIAS"         "$KEY_ALIAS"   "mask"
print_secret "KEY_PASSWORD"     "$KEY_PASS"    "mask"

echo -e "${GREEN}Optional (used by this workflow):${NC}"
echo "  GITHUB_ACTOR, GH_PACKAGES_TOKEN (or legacy NV_ACTOR/NV_TOKEN) — GitHub Packages if needed"
echo "  DISCORD_WEBHOOK_URL    — for Discord notifications"
echo "  GITHUB_TOKEN           — usually set automatically for Actions"
echo ""
