#!/usr/bin/env bash
# bootstrap-ci.sh — gen upload keystore + điền scripts/.env (per-app).
#
# Format key (chuẩn AF / Play upload):
#   alias            = key0
#   store password   = applicationId (package name)
#   key password     = applicationId (cùng giá trị)
#   DN               = CN/O = app name, OU=Android, L=HCM, ST=HCM, C=VN
#
# KHÔNG đẩy Nexus/Discord/GH Packages — chúng sống ở org secret af-products.
# google-services.json PRODUCTION: thủ công → gen-env-base64.sh → push-secret.sh
#
#   ./scripts/bootstrap-ci.sh           # gen key + .env (chưa cần remote)
#   ./scripts/bootstrap-ci.sh --push    # sau khi có origin: push-secret
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
KEYSTORE="$ROOT_DIR/app/keystore.jks"
DO_PUSH=false

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

for a in "$@"; do
  case "$a" in
    --push) DO_PUSH=true ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "tham số lạ: $a" >&2; exit 2 ;;
  esac
done

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
    if grep -qE '^#[[:space:]]*[Vv][Aa][Rr]' "$file" 2>/dev/null; then
      awk -v k="$key" -v v="$value" '
        BEGIN { inserted = 0 }
        /^#[[:space:]]*[Vv][Aa][Rr]/ && !inserted {
          print k "=" v
          print ""
          inserted = 1
        }
        { print }
        END { if (!inserted) print k "=" v }
      ' "$file" > "$tmp"
    else
      cat "$file" > "$tmp"
      printf '\n%s=%s\n' "$key" "$value" >> "$tmp"
    fi
  fi
  mv "$tmp" "$file"
}

GRADLE="$ROOT_DIR/app/build.gradle.kts"
[ -f "$GRADLE" ] || { echo "${RED}thiếu $GRADLE${NC}" >&2; exit 1; }

APP_ID="${APPLICATION_ID:-}"
if [ -z "$APP_ID" ]; then
  APP_ID="$(perl -0777 -ne 'print $1 if /applicationId\s*=\s*"([^"]+)"/' "$GRADLE")"
fi
[ -n "$APP_ID" ] || { echo "${RED}không đọc được applicationId — truyền APPLICATION_ID=…${NC}" >&2; exit 1; }

APP_LABEL="${APP_NAME:-}"
if [ -z "$APP_LABEL" ]; then
  STRINGS="$ROOT_DIR/app/src/main/res/values/strings.xml"
  if [ -f "$STRINGS" ]; then
    APP_LABEL="$(perl -ne 'print $1 if /name="app_name">([^<]+)/' "$STRINGS")"
  fi
fi
[ -n "$APP_LABEL" ] || APP_LABEL="$APP_ID"

# keytool storepass tối thiểu 6 ký tự — package name luôn đủ
if [ "${#APP_ID}" -lt 6 ]; then
  echo "${RED}applicationId quá ngắn cho keystore password: $APP_ID${NC}" >&2
  exit 1
fi

echo "${CYAN}bootstrap-ci${NC}"
echo "  package : $APP_ID"
echo "  app     : $APP_LABEL"
echo "  alias   : key0"
echo "  keystore: $KEYSTORE"

if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE" ]; then
  cp -f "$ENV_EXAMPLE" "$ENV_FILE"
  echo "  created scripts/.env from .env.example"
fi
[ -f "$ENV_FILE" ] || {
  printf '%s\n' '# secret' '' 'KEY_ALIAS=key0' 'KEYSTORE_PASSWORD=' 'KEY_PASSWORD=' 'KEYSTORE_BASE64=' 'GOOGLE_SERVICES_JSON_BASE64=' '' '# var' "PLAY_PACKAGE_NAME=$APP_ID" > "$ENV_FILE"
}

if [ -f "$KEYSTORE" ]; then
  echo "${YELLOW}  keystore đã có — giữ nguyên (không xoá/rotate)${NC}"
else
  export KEYSTORE_PASSWORD="$APP_ID"
  export KEY_PASSWORD="$APP_ID"
  export KEYSTORE_CN="$APP_LABEL"
  export KEYSTORE_OU="${KEYSTORE_OU:-Android}"
  export KEYSTORE_O="$APP_LABEL"
  export KEYSTORE_L="${KEYSTORE_L:-HCM}"
  export KEYSTORE_ST="${KEYSTORE_ST:-HCM}"
  export KEYSTORE_C="${KEYSTORE_C:-VN}"
  "$SCRIPT_DIR/gen-key.sh" -n -a key0 -o app/keystore.jks
fi

# [v2.8] VERIFY password TRƯỚC khi ghi .env — keystore đã có có thể sinh với applicationId CŨ (ASO đổi package sau khi
# sinh key): ghi mù KEYSTORE_PASSWORD=$APP_ID ⇒ .env + GH secret sai ⇒ CI release fail (AF rà kho: 13 app dính).
KT="${JAVA_HOME:+$JAVA_HOME/bin/keytool}"
[ -x "$KT" ] || KT="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
[ -x "$KT" ] || KT="keytool"
ENV_PW="$(grep -E '^KEYSTORE_PASSWORD=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true)"
ENV_KPW="$(grep -E '^KEY_PASSWORD=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true)"
if "$KT" -list -keystore "$KEYSTORE" -storepass "$APP_ID" >/dev/null 2>&1; then
  STOREPASS="$APP_ID"; KEYPASS="$APP_ID"
elif [ -n "$ENV_PW" ] && "$KT" -list -keystore "$KEYSTORE" -storepass "$ENV_PW" >/dev/null 2>&1; then
  STOREPASS="$ENV_PW"; KEYPASS="${ENV_KPW:-$ENV_PW}"
  echo "${YELLOW}  keystore sinh với password cũ (package đã đổi) — giữ password trong .env${NC}"
else
  echo "${RED}  app/keystore.jks KHÔNG mở được bằng applicationId lẫn .env KEYSTORE_PASSWORD — password không biết.${NC}" >&2
  echo "${RED}  KHÔNG ghi .env / KHÔNG push secret. Người giữ key cấp password, hoặc app chưa lên Play thì xoá keystore rồi chạy lại.${NC}" >&2
  exit 1
fi

# Điền .env per-app (không đụng org keys)
upsert_env_key "$ENV_FILE" "KEY_ALIAS" "key0"
upsert_env_key "$ENV_FILE" "KEYSTORE_PASSWORD" "$STOREPASS"
upsert_env_key "$ENV_FILE" "KEY_PASSWORD" "$KEYPASS"
upsert_env_key "$ENV_FILE" "PLAY_PACKAGE_NAME" "$APP_ID"

"$SCRIPT_DIR/gen-env-base64.sh" -k "$KEYSTORE" || true

echo "${GREEN}  .env sẵn sàng (GOOGLE_SERVICES_JSON_BASE64 để trống cho tới khi có Firebase PRODUCTION)${NC}"

if [ "$DO_PUSH" = true ]; then
  "$SCRIPT_DIR/push-secret.sh"
else
  echo "  Remote chưa cần. Sau gh repo create: ./scripts/bootstrap-ci.sh --push"
fi
