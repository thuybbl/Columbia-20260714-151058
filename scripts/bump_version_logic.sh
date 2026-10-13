#!/usr/bin/env bash
# Bump a semver version (same rules as scripts/release-rc.sh bump_version).
# Usage: bump_version_logic.sh <current_version> <major|minor|patch>
# Stdout: new version string (e.g. 1.2.4)
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <current_version> <major|minor|patch>" >&2
  exit 1
fi

current_version=$1
bump_type=$2

IFS='.' read -ra PARTS <<< "$current_version"
if [ "${#PARTS[@]}" -lt 3 ]; then
  echo "Error: version must be major.minor.patch (got: $current_version)" >&2
  exit 1
fi

major=${PARTS[0]}
minor=${PARTS[1]}
# Strip pre-release suffix from patch segment (e.g. 3-beta -> 3)
patch=${PARTS[2]%%-*}

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
    echo "Error: invalid bump type '$bump_type' (use major, minor, or patch)" >&2
    exit 1
    ;;
esac
