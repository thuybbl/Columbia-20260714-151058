#!/usr/bin/env bash
# Upload keystore theo format AF: alias key0, 2 password = applicationId, DN theo app.
# Idempotent: đã có app/keystore.jks thì không đụng.
#
#   ./scripts/generate_release_keystore.sh
#   APPLICATION_ID=com.foo.app APP_NAME="Foo" ./scripts/generate_release_keystore.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/bootstrap-ci.sh"
