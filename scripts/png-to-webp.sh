#!/usr/bin/env bash
#
# Convert all .png files under the project (or a given directory) to .webp using cwebp.
#
# Requires: cwebp (macOS: brew install webp), git
#
# Usage:
#   ./scripts/png-to-webp.sh [options] [directory]
#
# Options:
#   -q, --quality N   WebP quality 0-100 (default: 85)
#   -k, --keep        Keep original .png files (not recommended under res/)
#   -n, --dry-run     Print actions only (skips git clean check)
#   -f, --force       Run even if git working tree is not clean
#   -h, --help        Show help
#
# Safety: By default the script refuses to run unless the git working tree is clean
# (commit or stash first). That gives you an easy rollback: git checkout -- . or
# git reset --hard HEAD~1 after reviewing the conversion.
#
# Note: In Android res/, drawable name is the basename without extension. PNG sources
# are always removed after a successful conversion under res/ to avoid duplicate resources.
#
# By default, directories named .git, build, .gradle, and .idea are skipped. Pass an explicit
# directory to convert only that tree (no pruning except what find applies).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

QUALITY=85
REPLACE=1
DRY_RUN=0
FORCE=0
SEARCH_ROOT="$PROJECT_ROOT"

usage() {
  sed -n '1,26p' "$0" | tail -n +2
  exit "${1:-0}"
}

should_remove_png() {
  local png="$1"
  if [[ "$png" == *"/res/"* ]]; then
    return 0
  fi
  [[ $REPLACE -eq 1 ]]
}

require_clean_git() {
  if [[ $DRY_RUN -eq 1 ]] || [[ $FORCE -eq 1 ]]; then
    return 0
  fi

  if ! git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: $PROJECT_ROOT is not a git repository." >&2
    echo "       Commit checkpoints are required for rollback. Use --force to override." >&2
    exit 1
  fi

  if [[ -n "$(git -C "$PROJECT_ROOT" status --porcelain)" ]]; then
    echo "Error: Git working tree is not clean." >&2
    echo "" >&2
    echo "This script deletes PNG files after conversion. Commit first so you can roll back:" >&2
    echo "  git add -A && git commit -m \"chore: checkpoint before png-to-webp\"" >&2
    echo "  ./scripts/png-to-webp.sh" >&2
    echo "" >&2
    echo "Rollback if needed:" >&2
    echo "  git checkout -- .          # undo uncommitted conversion" >&2
    echo "  git reset --hard HEAD~1    # restore pre-checkpoint state" >&2
    echo "" >&2
    echo "Use --dry-run to preview without changes, or --force to skip this check." >&2
    exit 1
  fi

  echo "Git working tree is clean — rollback checkpoint: $(git -C "$PROJECT_ROOT" rev-parse --short HEAD)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--quality)
      QUALITY="${2:?missing quality}"
      shift 2
      ;;
    -k|--keep)
      REPLACE=0
      shift
      ;;
    -r|--replace)
      REPLACE=1
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -f|--force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage 1
      ;;
    *)
      SEARCH_ROOT="$(cd "$1" && pwd)"
      shift
      break
      ;;
  esac
done

if ! command -v cwebp >/dev/null 2>&1; then
  echo "cwebp not found. Install WebP tools, e.g.: brew install webp" >&2
  exit 1
fi

res_in_scope=0
if [[ "$SEARCH_ROOT" == *"/res"* ]]; then
  res_in_scope=1
elif find "$SEARCH_ROOT" \
  \( -name .git -o -name build -o -name .gradle -o -name .idea \) -prune -o \
  -type f -path '*/res/*/*.png' -print -quit 2>/dev/null | grep -q .; then
  res_in_scope=1
fi

if [[ $res_in_scope -eq 1 ]] && [[ $REPLACE -eq 0 ]]; then
  echo "Warning: --keep under res/ leaves duplicate drawable names (png + webp)." >&2
  echo "         Android resource merge will fail. Omit --keep for res/ migrations." >&2
  echo ""
fi

require_clean_git

count=0
while IFS= read -r -d '' png; do
  webp="${png%.png}.webp"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "Would: cwebp -q $QUALITY \"$png\" -o \"$webp\""
    if should_remove_png "$png"; then
      echo "Would: rm \"$png\""
    fi
  else
    if cwebp -quiet -q "$QUALITY" "$png" -o "$webp" && [[ -s "$webp" ]]; then
      if should_remove_png "$png"; then
        rm -f "$png"
      fi
    else
      echo "Failed to convert: $png" >&2
      exit 1
    fi
  fi
  count=$((count + 1))
done < <(
  find "$SEARCH_ROOT" \
    \( -name .git -o -name build -o -name .gradle -o -name .idea \) -prune -o \
    -type f -name '*.png' -print0
)

echo "Done. Converted $count file(s) under: $SEARCH_ROOT"
if [[ $DRY_RUN -eq 0 ]] && [[ $FORCE -eq 0 ]]; then
  echo "Review changes, then commit or rollback with: git checkout -- ."
fi
