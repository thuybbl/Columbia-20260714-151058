#!/usr/bin/env bash
# Remove *all* GitHub Releases associated with a tag (including duplicate drafts) so
# softprops/action-gh-release can create/publish without "already_exists" / finalization errors.
#
# Env: GITHUB_TOKEN (required), REPO (owner/repo), TAG_NAME (e.g. v1.0.0)
set -euo pipefail

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${REPO:?REPO is required (owner/repo)}"
: "${TAG_NAME:?TAG_NAME is required}"

API="https://api.github.com/repos/$REPO"
ENC_TAG=$(printf '%s' "$TAG_NAME" | jq -sRr @uri)
TAG_URL="$API/releases/tags/$ENC_TAG"

lookup_release() {
  curl -sS -o /tmp/gh_release_lookup.json -w "%{http_code}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$TAG_URL"
}

delete_release() {
  local id="$1"
  curl -sS -o /dev/null -w "%{http_code}" -X DELETE \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API/releases/$id"
}

# Delete every release in paginated /releases with .tag_name == TAG_NAME
sweep_releases_by_tag_name() {
  local page=1 deleted=0
  while [ "$page" -le 30 ]; do
    local code
    code=$(curl -sS -o /tmp/gh_rel_page.json -w "%{http_code}" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$API/releases?per_page=100&page=$page")
    if [ "$code" != "200" ]; then
      break
    fi
    local n
    n=$(jq 'length' /tmp/gh_rel_page.json)
    if [ "$n" -eq 0 ]; then
      break
    fi
    while IFS= read -r id; do
      [ -z "$id" ] || [ "$id" = "null" ] && continue
      echo "Deleting release id=$id (tag_name=$TAG_NAME) ..." >&2
      local dc
      dc=$(delete_release "$id" || true)
      if [ "$dc" = "204" ]; then
        deleted=$((deleted + 1))
      else
        echo "Warning: DELETE release $id returned HTTP $dc" >&2
      fi
    done < <(jq -r --arg t "$TAG_NAME" '.[] | select(.tag_name == $t) | .id' /tmp/gh_rel_page.json)
    if [ "$n" -lt 100 ]; then
      break
    fi
    page=$((page + 1))
  done
  echo "$deleted"
}

# Orphan *draft* releases often lack tag_name but title includes the tag (e.g. "Test Build v1.0.17-test");
# softprops then errors with a duplicate draft vs published.
sweep_draft_releases_name_contains() {
  local page=1 deleted=0
  while [ "$page" -le 30 ]; do
    local code
    code=$(curl -sS -o /tmp/gh_rel_page.json -w "%{http_code}" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$API/releases?per_page=100&page=$page")
    if [ "$code" != "200" ]; then
      break
    fi
    local n
    n=$(jq 'length' /tmp/gh_rel_page.json)
    if [ "$n" -eq 0 ]; then
      break
    fi
    while IFS= read -r id; do
      [ -z "$id" ] || [ "$id" = "null" ] && continue
      echo "Deleting orphan draft release id=$id (title contains tag; workflow-style name) ..." >&2
      local dc
      dc=$(delete_release "$id" || true)
      if [ "$dc" = "204" ]; then
        deleted=$((deleted + 1))
      else
        echo "Warning: DELETE draft release $id returned HTTP $dc" >&2
      fi
    done < <(jq -r --arg t "$TAG_NAME" \
      '.[] | select(.draft == true) | select((.name // "") | contains($t)) | select((.name // "") | (contains("Test Build") or contains("RC Build"))) | .id' \
      /tmp/gh_rel_page.json)
    if [ "$n" -lt 100 ]; then
      break
    fi
    page=$((page + 1))
  done
  echo "$deleted"
}

echo "=== Cleaning GitHub releases for tag $TAG_NAME (repo $REPO) ==="

pass=1
while [ "$pass" -le 4 ]; do
  d1=$(sweep_releases_by_tag_name)
  echo "  pass $pass: deleted $d1 release(s) with exact tag_name match"
  d2=0
  if [ "$pass" -le 2 ]; then
    d2=$(sweep_draft_releases_name_contains)
    echo "  pass $pass: deleted $d2 draft(s) with title containing this tag (workflow pattern)"
  fi
  if [ "$d1" -eq 0 ] && [ "$d2" -eq 0 ]; then
    break
  fi
  sleep 2
  pass=$((pass + 1))
done

# Canonical lookup by tag (catches stragglers)
HTTP_CODE=$(lookup_release)
if [ "$HTTP_CODE" = "200" ]; then
  RID=$(jq -r '.id' /tmp/gh_release_lookup.json)
  if [ -n "$RID" ] && [ "$RID" != "null" ]; then
    echo "Deleting release id=$RID (GET /releases/tags/...)..."
    if [ "$(delete_release "$RID")" = "204" ]; then
      sleep 1
    fi
  fi
fi

# Verify: no release for this tag
for i in 1 2 3 4 5 6 7 8; do
  sleep 1
  VERIFY=$(lookup_release)
  if [ "$VERIFY" = "404" ]; then
    # quick scan: no tag_name match in first page
    curl -sS -o /tmp/gh_rel_p1.json \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$API/releases?per_page=100" >/dev/null
    LEFT=$(jq --arg t "$TAG_NAME" '[.[] | select(.tag_name == $t)] | length' /tmp/gh_rel_p1.json)
    if [ "${LEFT:-0}" -eq 0 ]; then
      echo "OK: no release remains for tag $TAG_NAME (list page 1 clean)."
      exit 0
    fi
    echo "Tag endpoint 404 but list still has tag_name=$TAG_NAME (count $LEFT); sweeping again ..." >&2
    sweep_releases_by_tag_name >/dev/null
    continue
  fi
  if [ "$VERIFY" = "200" ]; then
    RID=$(jq -r '.id' /tmp/gh_release_lookup.json)
    if [ -n "$RID" ] && [ "$RID" != "null" ]; then
      echo "Verify pass $i/8: deleting straggler release id=$RID (GET /releases/tags/...)" >&2
      delete_release "$RID" || true
    fi
    # Re-run list sweep in case API returned a different object than the paginated list
    sweep_releases_by_tag_name >/dev/null
    sleep 1
    continue
  fi
  echo "Unexpected HTTP $VERIFY when verifying release for tag $TAG_NAME" >&2
  exit 1
done

echo "Failed to remove all releases for tag $TAG_NAME. Check https://github.com/$REPO/releases" >&2
exit 1
