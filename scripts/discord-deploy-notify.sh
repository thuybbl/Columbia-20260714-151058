#!/usr/bin/env bash
# Post deploy status to Discord #deploy channel.
# Usage: discord-deploy-notify.sh <status> [extra_env...]
# status: started | validate_failed | commit_failed | submitted | action_required | cancelled
set -euo pipefail

STATUS="${1:?status required}"
shift || true

if [ -z "${DISCORD_DEPLOY_WEBHOOK_URL:-}" ]; then
  echo "DISCORD_DEPLOY_WEBHOOK_URL not set. Skipping."
  exit 0
fi

TAG_NAME="${TAG_NAME:-unknown}"
REPO_NAME="${REPO_NAME:-unknown}"
PACKAGE_NAME="${PLAY_PACKAGE_NAME:-}"
VERSION_CODE="${VERSION_CODE:-}"
MODE="${MODE:-}"
ACTOR="${ACTOR:-github-actions}"
RUN_URL="${RUN_URL:-}"
ERROR_MSG="${ERROR_MSG:-}"
ROLLOUT="${ROLLOUT:-}"
RELEASE_STATUS="${RELEASE_STATUS:-}"

USER_TAGS=""
if [ -n "${DISCORD_RELEASE_MANAGER_IDS:-}" ]; then
  USER_TAGS=$(echo "$DISCORD_RELEASE_MANAGER_IDS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^/<@/' | sed 's/$/>/' | tr '\n' ' ')
fi

case "$STATUS" in
  started)
    TITLE="Deploy started"
    EMOJI="⏳"
    COLOR=9807270
  ;;
  validate_failed|upload_failed)
    TITLE="Deploy failed (validate/upload)"
    EMOJI="❌"
    COLOR=15158332
  ;;
  commit_failed)
    TITLE="Deploy failed (commit)"
    EMOJI="❌"
    COLOR=15158332
  ;;
  submitted)
    TITLE="Submitted — waiting for Google review"
    EMOJI="✅"
    COLOR=3066993
  ;;
  action_required)
    TITLE="Action required — Send for review manually"
    EMOJI="⚠️"
    COLOR=15105570
  ;;
  cancelled)
    TITLE="Deploy cancelled"
    EMOJI="🚫"
    COLOR=9807270
  ;;
  *)
    TITLE="Deploy status: $STATUS"
    EMOJI="ℹ️"
    COLOR=9807270
  ;;
esac

MODE_LABEL="$MODE"
case "$MODE" in
  upload_open) MODE_LABEL="Upload → Open testing (beta)" ;;
  upload_production) MODE_LABEL="Upload → Production" ;;
  promote_to_production) MODE_LABEL="Promote open testing → Production" ;;
esac

DETAILS=""
if [ -n "$PACKAGE_NAME" ]; then
  DETAILS="${DETAILS}**Package:** \`${PACKAGE_NAME}\`\n"
fi
if [ -n "$VERSION_CODE" ]; then
  DETAILS="${DETAILS}**Version code:** \`${VERSION_CODE}\`\n"
fi
if [ -n "$MODE_LABEL" ]; then
  DETAILS="${DETAILS}**Mode:** ${MODE_LABEL}\n"
fi
if [ -n "$ROLLOUT" ]; then
  DETAILS="${DETAILS}**Rollout:** ${ROLLOUT}\n"
fi
if [ -n "$RELEASE_STATUS" ]; then
  DETAILS="${DETAILS}**Release status:** ${RELEASE_STATUS}\n"
fi
if [ -n "$ACTOR" ]; then
  DETAILS="${DETAILS}**Triggered by:** ${ACTOR}\n"
fi

case "$STATUS" in
  submitted)
    DETAILS="${DETAILS}\nSubmitted to Google Play. Review may take a few hours up to 7 days.\nCheck email and Play Console → Publishing overview."
  ;;
  action_required)
    DETAILS="${DETAILS}\nPrevious submission was rejected. Changes committed with \`changesNotSentForReview\`.\nGo to Play Console → Publishing overview → **Send for review**.\nhttps://play.google.com/console"
  ;;
esac

if [ -n "$ERROR_MSG" ]; then
  ERR_ESC=$(printf '%s' "$ERROR_MSG" | head -c 900 | jq -Rs .)
else
  ERR_ESC='""'
fi

CONTENT="$USER_TAGS"
if [ "$STATUS" = "action_required" ] && [ -n "$USER_TAGS" ]; then
  CONTENT="$USER_TAGS"
fi

PAYLOAD=$(jq -n \
  --arg content "$CONTENT" \
  --arg title "${EMOJI} ${TITLE}: ${TAG_NAME}" \
  --argjson color "$COLOR" \
  --arg details "$DETAILS" \
  --argjson error "$ERR_ESC" \
  --arg run_url "$RUN_URL" \
  --arg repo "$REPO_NAME" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    content: (if $content == "" then null else $content end),
    embeds: [{
      title: $title,
      url: (if $run_url == "" then null else $run_url end),
      color: $color,
      description: $details,
      fields: (if ($error | length) > 2 then [{name: "Error", value: ("```\n" + $error + "\n```"), inline: false}] else [] end),
      footer: { text: ("Play Deploy • " + $repo) },
      timestamp: $timestamp
    }]
  }')

curl -fsS -X POST "$DISCORD_DEPLOY_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
