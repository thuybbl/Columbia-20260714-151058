#!/usr/bin/env bash
# Encode release.jks + google-services.json → scripts/.env
# (KEYSTORE_BASE64, GOOGLE_SERVICES_JSON_BASE64) for push-secret / CI.
#
#   ./scripts/gen-env-base64.sh
#   ./scripts/gen-env-base64.sh -k app/release.jks -g app/google-services.json
#   ./scripts/gen-env-base64.sh --print   # print only, do not write .env
#
# Default keystore: app/release.jks (fallback app/keystore.jks if missing).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

KEYSTORE=""
GS_JSON=""
PRINT_ONLY=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Encode keystore + google-services.json as base64 into scripts/.env.

Options:
  -k, --keystore PATH   Keystore .jks (default: app/release.jks, else app/keystore.jks)
  -g, --google-services PATH
                        google-services.json (default: app/google-services.json)
  -e, --env PATH        Target .env (default: scripts/.env)
  -n, --print           Print values only; do not write .env
  -h, --help            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--keystore) KEYSTORE="$2"; shift 2 ;;
    -g|--google-services) GS_JSON="$2"; shift 2 ;;
    -e|--env) ENV_FILE="$2"; shift 2 ;;
    -n|--print) PRINT_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo -e "${RED}Unknown option: $1${NC}" >&2
      usage >&2
      exit 1
      ;;
    *)
      echo -e "${RED}Unexpected argument: $1${NC}" >&2
      usage >&2
      exit 1
      ;;
  esac
done

resolve_path() {
  local p="$1"
  if [[ "$p" != /* ]]; then
    p="$ROOT_DIR/$p"
  fi
  printf '%s' "$p"
}

if [[ -z "$KEYSTORE" ]]; then
  if [[ -f "$ROOT_DIR/app/release.jks" ]]; then
    KEYSTORE="$ROOT_DIR/app/release.jks"
  elif [[ -f "$ROOT_DIR/app/keystore.jks" ]]; then
    KEYSTORE="$ROOT_DIR/app/keystore.jks"
  else
    KEYSTORE="$ROOT_DIR/app/release.jks"
  fi
else
  KEYSTORE="$(resolve_path "$KEYSTORE")"
fi

if [[ -z "$GS_JSON" ]]; then
  GS_JSON="$ROOT_DIR/app/google-services.json"
else
  GS_JSON="$(resolve_path "$GS_JSON")"
fi

if [[ "$ENV_FILE" != /* ]]; then
  ENV_FILE="$(resolve_path "$ENV_FILE")"
fi

b64_file() {
  # Portable single-line base64 (macOS base64 has no -w0)
  base64 < "$1" | tr -d '\n'
}

upsert_env_key() {
  local file="$1" key="$2" value="$3"
  local tmp
  tmp="$(mktemp)"
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    awk -v k="$key" -v v="$value" '
      BEGIN { done = 0 }
      index($0, k "=") == 1 {
        print k "=" v
        done = 1
        next
      }
      { print }
      END { if (!done) print k "=" v }
    ' "$file" > "$tmp"
  else
    # Insert before "# var" section if present; else append
    if grep -qE '^#[[:space:]]*[Vv][Aa][Rr]' "$file" 2>/dev/null; then
      awk -v k="$key" -v v="$value" '
        BEGIN { inserted = 0 }
        /^#[[:space:]]*[Vv][Aa][Rr]/ && !inserted {
          print k "=" v
          print ""
          inserted = 1
        }
        { print }
        END {
          if (!inserted) print k "=" v
        }
      ' "$file" > "$tmp"
    else
      cat "$file" > "$tmp"
      printf '\n%s=%s\n' "$key" "$value" >> "$tmp"
    fi
  fi
  mv "$tmp" "$file"
}

KEYSTORE_B64=""
GS_B64=""
if [[ -f "$KEYSTORE" ]]; then
  KEYSTORE_B64="$(b64_file "$KEYSTORE")"
  echo -e "${CYAN}Keystore:${NC}  $KEYSTORE ($(wc -c < "$KEYSTORE" | tr -d ' ') bytes → ${#KEYSTORE_B64} chars b64)"
else
  echo -e "${YELLOW}Keystore not found: $KEYSTORE — skip KEYSTORE_BASE64${NC}" >&2
  echo "  Create one: ./scripts/gen-key.sh -o app/release.jks" >&2
fi
if [[ -f "$GS_JSON" ]]; then
  GS_B64="$(b64_file "$GS_JSON")"
  echo -e "${CYAN}Firebase:${NC}  $GS_JSON ($(wc -c < "$GS_JSON" | tr -d ' ') bytes → ${#GS_B64} chars b64)"
else
  echo -e "${YELLOW}google-services.json not found: $GS_JSON — skip GOOGLE_SERVICES_JSON_BASE64${NC}" >&2
fi
if [[ -z "$KEYSTORE_B64" && -z "$GS_B64" ]]; then
  echo -e "${RED}Nothing to encode — need app/release.jks and/or app/google-services.json${NC}" >&2
  exit 1
fi

if [[ "$PRINT_ONLY" -eq 1 ]]; then
  echo ""
  if [[ -n "$KEYSTORE_B64" ]]; then
    echo "KEYSTORE_BASE64=$KEYSTORE_B64"
  fi
  if [[ -n "$GS_B64" ]]; then
    echo "GOOGLE_SERVICES_JSON_BASE64=$GS_B64"
  fi
  echo ""
  echo -e "${YELLOW}Printed only — .env not modified. Clear terminal after copying.${NC}"
  exit 0
fi

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$ENV_EXAMPLE" ]]; then
    cp -f "$ENV_EXAMPLE" "$ENV_FILE"
    echo -e "${YELLOW}Created $ENV_FILE from .env.example${NC}"
  else
    {
      echo "# local env for release scripts"
      echo ""
      echo "# secret"
      echo ""
      echo "KEYSTORE_BASE64="
      echo "GOOGLE_SERVICES_JSON_BASE64="
      echo ""
      echo "# var"
    } > "$ENV_FILE"
    echo -e "${YELLOW}Created minimal $ENV_FILE${NC}"
  fi
fi

if [[ -n "$KEYSTORE_B64" ]]; then
  upsert_env_key "$ENV_FILE" "KEYSTORE_BASE64" "$KEYSTORE_B64"
fi
if [[ -n "$GS_B64" ]]; then
  upsert_env_key "$ENV_FILE" "GOOGLE_SERVICES_JSON_BASE64" "$GS_B64"
fi

echo ""
echo -e "${GREEN}Updated:${NC} $ENV_FILE"
if [[ -n "$KEYSTORE_B64" ]]; then
  echo "  KEYSTORE_BASE64=… (${#KEYSTORE_B64} chars)"
fi
if [[ -n "$GS_B64" ]]; then
  echo "  GOOGLE_SERVICES_JSON_BASE64=… (${#GS_B64} chars)"
fi
echo ""
echo "Next: ./scripts/push-secret.sh"
echo -e "${YELLOW}Do not commit scripts/.env${NC}"
