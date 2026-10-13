# CI / CD — shipped with code_base (App-Factory)

Workflows and `scripts/` land in every app via `git archive` of this tag.

**Org secrets** (Nexus, Discord webhook, GH Packages, Play-deploy bot) sống trên GitHub org
`af-products` — repo app **inherit**, không copy vào `scripts/.env`.

**Per-repo secrets** (generate tự tạo + `push-secret`):
- `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS` (`key0`)
- `GOOGLE_SERVICES_JSON_BASE64` — **thủ công** (Firebase PRODUCTION), CI release fail nếu trống
- Variable `PLAY_PACKAGE_NAME`

## Day-1 (no product flavors)

`code_base` builds with plain `assembleDebug` / `assembleRelease`.
`build-release.yml` auto-detects: uses `assembleProdRelease` when `create("prod")` exists, else `assembleRelease`.

## After flavors (organic / campaign / review / prod)

Typical AF shipping apps add these flavors during build. Then:
- `build-release.yml` → `assembleProdRelease` / `bundleProdRelease`
- `test-rc-build.yml` / `release-rc.yml` → organic/campaign/review tasks (require those flavors)

## Bootstrap secrets

1. `./scripts/bootstrap-ci.sh` — gen `app/keystore.jks` (alias `key0`, 2 password = `applicationId`, DN theo app name) + điền `scripts/.env`
2. Sau khi repo `af-products/<slug>` đã có: `./scripts/bootstrap-ci.sh --push` (hoặc `./scripts/push-secret.sh`)
3. Khi có Firebase **PRODUCTION**: `./scripts/gen-env-base64.sh` rồi `./scripts/push-secret.sh` lần 2
4. `app/google-services.json` DEV/test (project chung) **được commit** để debug local; CI release **ghi đè** bằng secret rồi xóa.

Keystore gitignore (`*.jks`). Không rotate trừ khi xóa file rồi chạy lại bootstrap.

See `scripts/README.md` for the full release flow.
