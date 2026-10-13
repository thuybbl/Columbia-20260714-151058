#!/bin/bash
# Sync GitHub Actions secrets/variables from scripts/.env
#   # secret  → gh secret set
#   # var     → gh variable set
#
# Skips empty / placeholder values so they cannot OVERRIDE org secrets on
# af-products (repo secret empty would hide NEXUS_*, Discord, GH Packages).
# Org-shared keys are never pushed unless --include-org.
#
#   ./scripts/push-secret.sh
#   ./scripts/push-secret.sh --include-org   # also push Nexus/Discord/GH Packages
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
INCLUDE_ORG=false

for a in "$@"; do
  case "$a" in
    --include-org) INCLUDE_ORG=true ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "tham số lạ: $a" >&2; exit 2 ;;
  esac
done

if [ ! -f "$ENV_FILE" ]; then
  echo "Lỗi: Không tìm thấy file .env tại $ENV_FILE"
  exit 1
fi

if ! CURRENT_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || [ -z "$CURRENT_REPO" ]; then
  echo "Lỗi: Không xác định được repo GitHub. Chạy script trong thư mục clone và đăng nhập: gh auth login"
  exit 1
fi

echo "🚀 Đồng bộ Secret + Variable lên GitHub ($CURRENT_REPO)..."
echo "   # secret → secrets · # var → variables · bỏ qua value rỗng (không đè org secret)"

mode=""
pushed=0
skipped=0

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Keys that live on GitHub org af-products — pushing empty/local copies
# would OVERRIDE org inheritance.
is_org_key() {
  case "$1" in
    GITHUB_TOKEN|GITHUB_ACTOR|GH_PACKAGES_TOKEN|NV_ACTOR|NV_TOKEN|\
    NEXUS_URL|NEXUS_USER|NEXUS_PASS|NEXUS_RAW_REPO|NEXUS_USERNAME|NEXUS_PASSWORD|\
    NEXUS_USERNAME_PROD|NEXUS_PASSWORD_PROD|\
    DISCORD_WEBHOOK_URL|DISCORD_USER_IDS|DISCORD_RELEASE_MANAGER_IDS|\
    PLAY_DEPLOY_BOT_URL|PLAY_DEPLOY_NOTIFY_TOKEN|DISCORD_DEPLOY_WEBHOOK_URL)
      return 0 ;;
    *) return 1 ;;
  esac
}

is_placeholder() {
  local v="$1"
  case "$v" in
    ''|ghp_your_token_here|your_token_here|changeme|TODO|xxx|XXX) return 0 ;;
    *) return 1 ;;
  esac
}

set_kv() {
  local kind="$1"
  local key="$2"
  local value="$3"

  if [[ "$value" =~ ^\".*\"$ ]]; then
    value="${value#\"}"
    value="${value%\"}"
  elif [[ "$value" =~ ^\'.*\'$ ]]; then
    value="${value#\'}"
    value="${value%\'}"
  fi

  if is_placeholder "$value"; then
    echo "⏭️  Bỏ qua $key (rỗng/placeholder — không đè org)"
    skipped=$((skipped + 1))
    return 0
  fi
  if [ "$INCLUDE_ORG" != true ] && is_org_key "$key"; then
    echo "⏭️  Bỏ qua $key (org secret af-products — dùng --include-org nếu cố ý)"
    skipped=$((skipped + 1))
    return 0
  fi

  if [[ "$kind" == "secret" ]]; then
    echo "🔐 Secret: $key"
    printf '%s' "$value" | gh secret set "$key" --repo "$CURRENT_REPO"
  else
    echo "📊 Variable: $key"
    gh variable set "$key" --body "$value" --repo "$CURRENT_REPO"
  fi
  pushed=$((pushed + 1))
}

while IFS= read -r line || [ -n "$line" ]; do
  stripped="$(trim "$line")"
  [[ -z "${stripped//[[:space:]]/}" ]] && continue

  if [[ "$stripped" =~ ^# ]]; then
    rest="$(trim "${stripped#\#}")"
    lc="$(printf '%s' "$rest" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lc" == "secret" ]]; then
      mode="secret"
      continue
    fi
    if [[ "$lc" == "var" || "$lc" == "variable" ]]; then
      mode="var"
      continue
    fi
    continue
  fi

  [[ "$stripped" != *"="* ]] && continue

  if [[ -z "$mode" ]]; then
    echo "⚠️  Bỏ qua (đặt dòng này sau # secret hoặc # var): $stripped"
    continue
  fi

  key="${stripped%%=*}"
  value="${stripped#*=}"
  key=$(printf '%s' "$key" | xargs)
  [[ -z "$key" ]] && continue

  set_kv "$mode" "$key" "$value"
done < "$ENV_FILE"

echo "✅ Xong: đẩy $pushed, bỏ qua $skipped. Kiểm tra Settings → Secrets and variables."
