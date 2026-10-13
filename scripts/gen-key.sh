#!/bin/bash

# Generate Android release keystore (JKS) for app signing.
# Use for new apps or when rotating signing keys. Backup the keystore and
# store passwords securely; losing them prevents publishing updates.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_OUTPUT="$ROOT_DIR/app/keystore.jks"
DEFAULT_ALIAS="key0"
DEFAULT_VALIDITY=10000

# Distinguished name (DN) for the key — used in the certificate.
# Set via env to avoid editing the script (e.g. for CI or your company).
#   CN = Common Name (e.g. your name or app name)
#   OU = Organizational Unit (e.g. Release, Mobile)
#   O  = Organization (company name)
#   L  = Locality (city)
#   ST = State / Province
#   C  = Country (2-letter code, e.g. US, VN)
KEYSTORE_CN="${KEYSTORE_CN:-Android}"
KEYSTORE_OU="${KEYSTORE_OU:-Android}"
KEYSTORE_O="${KEYSTORE_O:-App}"
KEYSTORE_L="${KEYSTORE_L:-HCM}"
KEYSTORE_ST="${KEYSTORE_ST:-HCM}"
KEYSTORE_C="${KEYSTORE_C:-VN}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Generate an Android release keystore (JKS) for app signing.

Options:
  -o, --output PATH   Output keystore path (default: app/keystore.jks)
  -a, --alias NAME   Key alias (default: key0)
  -v, --validity N   Validity in days (default: $DEFAULT_VALIDITY)
  -n, --no-prompt    Non-interactive: use env KEYSTORE_PASSWORD, KEY_PASSWORD
  -h, --help         Show this help

Environment (for -n):
  KEYSTORE_PASSWORD   Keystore password (required if -n)
  KEY_PASSWORD        Key password (defaults to KEYSTORE_PASSWORD if -n)

Certificate / company info (optional; used in -dname):
  KEYSTORE_CN         Common Name (default: Android)
  KEYSTORE_OU         Organizational Unit (default: Release)
  KEYSTORE_O          Organization / company name (default: App)
  KEYSTORE_L          Locality / city (default: City)
  KEYSTORE_ST         State / province (default: State)
  KEYSTORE_C          Country 2-letter code (default: US)
  KEYSTORE_DNAME      Full -dname string (overrides CN/OU/O/L/ST/C if set)

Examples:
  ./scripts/gen-key.sh
  ./scripts/gen-key.sh -o app/my_release.jks -a mykey
  KEYSTORE_PASSWORD=secret KEY_PASSWORD=secret ./scripts/gen-key.sh -n
EOF
}

OUTPUT="$DEFAULT_OUTPUT"
ALIAS="$DEFAULT_ALIAS"
VALIDITY=$DEFAULT_VALIDITY
NO_PROMPT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -a|--alias)
            ALIAS="$2"
            shift 2
            ;;
        -v|--validity)
            VALIDITY="$2"
            shift 2
            ;;
        -n|--no-prompt)
            NO_PROMPT=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Resolve path relative to repo root if needed
if [[ "$OUTPUT" != /* ]]; then
    OUTPUT="$ROOT_DIR/$OUTPUT"
fi

if [[ -f "$OUTPUT" ]]; then
    if [[ "$NO_PROMPT" == true ]]; then
        echo -e "${YELLOW}Already exists: $OUTPUT — skip (xóa file rồi chạy lại để rotate)${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Warning: $OUTPUT already exists. Overwrite? [y/N]${NC}"
    read -r ans
    case "$(echo "$ans" | tr '[:upper:]' '[:lower:]')" in
        y|yes) ;;
        *) echo "Aborted."
           exit 0 ;;
    esac
fi

STORE_PASS=""
KEY_PASS=""

if [[ "$NO_PROMPT" == true ]]; then
    STORE_PASS="${KEYSTORE_PASSWORD:?Set KEYSTORE_PASSWORD for non-interactive run}"
    KEY_PASS="${KEY_PASSWORD:-$STORE_PASS}"
else
    echo -e "${GREEN}Generate Android release keystore${NC}"
    echo "Output: $OUTPUT"
    echo "Alias:  $ALIAS"
    echo "Validity: $VALIDITY days"
    echo ""
    read -rsp "Keystore password: " STORE_PASS
    echo ""
    read -rsp "Key password (same as keystore if empty): " KEY_PASS
    echo ""
    if [[ -z "$KEY_PASS" ]]; then
        KEY_PASS="$STORE_PASS"
    fi
fi

mkdir -p "$(dirname "$OUTPUT")"
if [[ -n "${KEYSTORE_DNAME:-}" ]]; then
    DNAME="$KEYSTORE_DNAME"
else
    DNAME="CN=$KEYSTORE_CN, OU=$KEYSTORE_OU, O=$KEYSTORE_O, L=$KEYSTORE_L, ST=$KEYSTORE_ST, C=$KEYSTORE_C"
fi
keytool -genkey -v \
    -keystore "$OUTPUT" \
    -alias "$ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity "$VALIDITY" \
    -storepass "$STORE_PASS" \
    -keypass "$KEY_PASS" \
    -dname "$DNAME"

echo ""
echo -e "${GREEN}Keystore created: $OUTPUT${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Back up the keystore file and store it securely."
echo "  2. Keep keystore and key passwords in a password manager."
echo "  3. Ensure the keystore path is in .gitignore (e.g. *.jks, *.keystore)."
echo "  4. For CI: base64-encode the keystore and set KEYSTORE_BASE64; set KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD secrets."
echo "  5. In app/build.gradle.kts, point signingConfig release to this keystore (or use RELEASE_STORE_FILE etc.)."
