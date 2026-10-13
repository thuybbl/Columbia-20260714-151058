# Nexus Setup Runbook — cho một project Android mới

> Checklist + hướng dẫn để setup **Nexus Repository** làm nơi lưu artifact (APK/AAB/IPA) cho project mới, có CI/CD trên GitHub Actions, thông báo qua Discord/Slack.

**Phạm vi:** Nexus 3 Community Edition, raw (hosted) repositories.
**Giả định:** đã có 1 Nexus instance đang chạy, quyền `admin`, 1 GitHub repo project.

---

## Mục lục

- [0. Thông tin cần gom trước khi bắt đầu](#0-thông-tin-cần-gom-trước-khi-bắt-đầu)
- [1. Đặt convention (folder & filename)](#1-đặt-convention-folder--filename)
- [2. Tạo Blob Stores](#2-tạo-blob-stores)
- [3. Tạo 2 Repositories (prod + nonprod)](#3-tạo-2-repositories-prod--nonprod)
- [4. Cleanup Policy cho nonprod](#4-cleanup-policy-cho-nonprod)
- [5. Tạo Roles](#5-tạo-roles)
- [6. Tạo Users CI](#6-tạo-users-ci)
- [7. (Tuỳ chọn) Bật Anonymous download](#7-tuỳ-chọn-bật-anonymous-download)
- [8. Smoke test credentials](#8-smoke-test-credentials)
- [9. Cấu hình GitHub Secrets & Variables](#9-cấu-hình-github-secrets--variables)
- [10. Tích hợp vào GitHub Actions workflow](#10-tích-hợp-vào-github-actions-workflow)
- [11. Test end-to-end](#11-test-end-to-end)
- [12. Migration dữ liệu cũ](#12-migration-dữ-liệu-cũ)
- [13. Lockdown & hardening](#13-lockdown--hardening)
- [14. Troubleshooting](#14-troubleshooting)
- [15. Daily operations](#15-daily-operations)

---

## 0. Thông tin cần gom trước khi bắt đầu

Điền trước, dùng xuyên suốt các phase.

| Mục | Giá trị | Ví dụ |
|---|---|---|
| `APP_SLUG` | _______ | `shimeji` (chữ thường, gạch-ngang) |
| `NEXUS_URL` | _______ | `https://nexus.stemlabs.site` |
| Tên prod repo | _______ | `raw-releases-prod` |
| Tên nonprod repo | _______ | `raw-releases-nonprod` |
| Platform | _______ | `android` / `ios` / both |
| Store(s) | _______ | `playstore`, `huawei`, `direct`, `appstore`, `testflight` |
| Track(s) | _______ | `production`, `beta`, `internal` |
| Flavor(s) build | _______ | `prod`, `organic`, `campaign`, `review` |
| Retention nonprod | `60 ngày` | đề xuất |
| Người cần READ | _______ | dev, QA, ASO, release-manager |
| Discord webhook | _______ | đã có chưa? |

---

## 1. Đặt convention (folder & filename)

> **Làm phase này trên giấy/Confluence TRƯỚC khi động vào Nexus.** Đổi convention sau khi đã có file rất phiền.

### 1.1. Folder tree bên trong mỗi repo raw

```text
<APP_SLUG>/
└── <platform>/                     # android | ios
    └── <store>/                    # playstore | huawei | direct | appstore | testflight
        └── <track>/                # production | beta | internal
            └── <versionName>+<versionCode>/   # IMMUTABLE — 1 thư mục = 1 lần build
                ├── <filename>.apk | .aab | .ipa
                ├── <filename>.<ext>.sha256
                ├── mapping.txt                   # Android prod only
                ├── native-debug-symbols.zip      # nếu có NDK
                └── metadata.json                 # build provenance
```

### 1.2. Filename convention (BẮT BUỘC, enforce ở CI)

```text
<APP_SLUG>-<platform>-<store>-<flavor>-<track>-<versionName>-<versionCode>-<YYYY-MM-DD>-<gitShortSha>.<ext>
```

Ví dụ:

- `shimeji-android-playstore-prod-production-1.2.1-125-2026-04-20-a1b2c3d.aab`
- `shimeji-android-playstore-organic-beta-1.2.2-126-2026-04-21-deadbee.apk`
- `shimeji-ios-appstore-prod-production-1.2.1-125-2026-04-20-a1b2c3d.ipa`

### 1.3. Nguyên tắc KHÔNG THỎA HIỆP

- Tên file chỉ dùng `[a-z0-9.-]`, không khoảng trắng, không ký tự đặc biệt.
- Date format **ISO** `YYYY-MM-DD` (không `MM.DD.YYYY` — gây nhầm locale).
- `versionCode` luôn có mặt trong tên & path. Tag prod phải match `versionName`.
- Không bao giờ dùng tên generic: `app-release.apk`, `output.apk`, `build.apk`.

---

## 2. Tạo Blob Stores

> Mục đích: tách storage backend của prod và nonprod để backup/quota riêng.

- [ ] Login Nexus → **Settings (⚙) → Repository → Blob Stores**
- [ ] **Create Blob Store:**
  - Type: `File`
  - Name: `releases-prod`
  - Path: *(default)*
- [ ] **Create Blob Store:**
  - Type: `File`
  - Name: `releases-nonprod`
  - Path: *(default)*

> **Ghi chú:** nếu Nexus dùng chung cho nhiều project, đặt tên kèm prefix: `<project>-releases-prod`, `<project>-releases-nonprod`.

---

## 3. Tạo 2 Repositories (prod + nonprod)

### 3.1. `raw-releases-prod`

- [ ] **Settings → Repository → Repositories → Create repository**
- [ ] Recipe: **raw (hosted)**
- [ ] Name: `raw-releases-prod`
- [ ] Online: ✅
- [ ] Blob store: `releases-prod`
- [ ] Strict Content Type Validation: **TẮT** *(raw repo phải tắt để upload `.aab`)*
- [ ] **Deployment policy: `Disable redeploy`** ← ĐỪNG QUÊN
- [ ] Create

### 3.2. `raw-releases-nonprod`

- [ ] Recipe: **raw (hosted)**
- [ ] Name: `raw-releases-nonprod`
- [ ] Blob store: `releases-nonprod`
- [ ] Strict Content Type Validation: **TẮT**
- [ ] **Deployment policy: `Allow redeploy`**
- [ ] Create

### Lý do phân tách

| Repo | Mục đích | Policy | Cleanup |
|---|---|---|---|
| `raw-releases-prod` | Bản đã phát hành thật | Disable redeploy | Giữ vĩnh viễn |
| `raw-releases-nonprod` | Build RC/test/QA | Allow redeploy | Auto xoá 60 ngày |

---

## 4. Cleanup Policy cho nonprod

- [ ] **Settings → Repository → Cleanup Policies → Create**
  - Name: `nonprod-60d`
  - Format: `raw`
  - Criteria → Component Age: **60 days**
- [ ] **Repositories → `raw-releases-nonprod` → Edit**
  - Cleanup policies: chọn `nonprod-60d`
  - Save

Nexus tự chạy cleanup hàng ngày (~1h sáng). Repo prod **không** gắn cleanup policy.

---

## 5. Tạo Roles

### 5.1. Role `ci-prod-writer`

- [ ] **Security → Roles → Create role → Nexus role**
- [ ] Role ID: `ci-prod-writer`
- [ ] Name: `CI prod writer`
- [ ] Privileges (đủ **4** cái, phải có cả `-edit`):
  ```text
  nx-repository-view-raw-raw-releases-prod-add
  nx-repository-view-raw-raw-releases-prod-edit
  nx-repository-view-raw-raw-releases-prod-read
  nx-repository-view-raw-raw-releases-prod-browse
  ```
- [ ] **KHÔNG** thêm `-delete` (để token không xoá được gì)
- [ ] Save

> **Quirk Nexus 3:** raw repo cần **cả** `-add` và `-edit` để `PUT` một asset mới. Thiếu `-edit` sẽ bị **HTTP 403** khi upload file mới. Policy `Disable redeploy` ở repo vẫn chặn ghi đè bất kể privilege, nên thêm `-edit` vẫn an toàn.

### 5.2. Role `ci-nonprod-writer`

- [ ] Role ID: `ci-nonprod-writer`
- [ ] Privileges:
  ```text
  nx-repository-view-raw-raw-releases-nonprod-add
  nx-repository-view-raw-raw-releases-nonprod-edit
  nx-repository-view-raw-raw-releases-nonprod-read
  nx-repository-view-raw-raw-releases-nonprod-browse
  ```

### 5.3. Role `releases-reader` (cho ASO, QA, dev)

- [ ] Role ID: `releases-reader`
- [ ] Privileges:
  ```text
  nx-repository-view-raw-raw-releases-prod-read
  nx-repository-view-raw-raw-releases-prod-browse
  nx-repository-view-raw-raw-releases-nonprod-read
  nx-repository-view-raw-raw-releases-nonprod-browse
  ```

---

## 6. Tạo Users CI

### 6.1. User `ci-prod`

- [ ] **Security → Users → Create local user**
  - User ID: `ci-prod`
  - First/Last: `CI` / `Prod`
  - Email: `devops@your-domain`
  - Password: sinh bằng password manager, ≥ 20 ký tự, lưu vào vault
  - Status: **Active**
  - Roles: `ci-prod-writer`
- [ ] Save — xác nhận "Granted roles" có `ci-prod-writer`

### 6.2. User `ci-nonprod`

- [ ] Giống 6.1, role `ci-nonprod-writer`

### 6.3. (Tuỳ chọn) User `aso` / `qa-readonly`

- [ ] Role `releases-reader`

> **Ghi chú:** Nếu có Nexus Pro → ưu tiên tạo **User Token** thay vì password cho CI.

---

## 7. (Tuỳ chọn) Bật Anonymous download

Khi muốn link tải trên Discord/Slack không cần login.

> **Nguyên tắc an toàn:** chỉ mở anonymous cho **nonprod**. Prod vẫn bắt auth.

- [ ] **Security → Anonymous Access**
  - Allow anonymous users to access the server: ✅
  - Save
- [ ] **Security → Roles → `nx-anonymous` → Edit**
  - Privileges (chỉ giữ):
    ```text
    nx-repository-view-raw-raw-releases-nonprod-read
    ```
  - Gỡ mọi privilege khác, đặc biệt là `-browse` và bất kỳ privilege nào của `raw-releases-prod`.
- [ ] Save

### Kết quả

| Hành động | Chưa login | Đã login |
|---|---|---|
| `GET` URL file nonprod | ✅ 200 | ✅ 200 |
| `GET` URL file prod | ❌ 401 | ✅ 200 |
| Browse UI | Trống | Đầy đủ |
| `PUT` upload | ❌ 403 | ✅ *(nếu có role)* |

### Rủi ro cần truyền đạt cho team

- Ai có URL nonprod đều tải được. Link **không có expiry**.
- Discord channel phải là **private**.
- Nếu cần signed URL / expiry → cần reverse proxy (nginx `secure_link`, R2 pre-signed, Cloudflare Access).

---

## 8. Smoke test credentials

Chạy **6 test** sau trước khi đụng GitHub Actions. Phải pass đủ 6.

### Chuẩn bị

```bash
echo "smoke" > /tmp/x.txt
export NEXUS=https://nexus.stemlabs.site
export P_PW='<password-ci-prod>'
export N_PW='<password-ci-nonprod>'
```

### Các test

| # | Mô tả | Command | Expect |
|---|---|---|---|
| 1 | `ci-prod` upload file mới lên prod | `curl -i -u ci-prod:"$P_PW" --upload-file /tmp/x.txt "$NEXUS/repository/raw-releases-prod/_smoke/hello.txt"` | `201 Created` |
| 2 | Upload trùng path | lặp lại lệnh 1 | `400 Bad Request` *("Repository does not allow updating")* |
| 3 | `ci-prod` xoá file | `curl -i -u ci-prod:"$P_PW" -X DELETE "$NEXUS/repository/raw-releases-prod/_smoke/hello.txt"` | `403 Forbidden` |
| 4 | `ci-prod` upload sang nonprod | `curl -i -u ci-prod:"$P_PW" --upload-file /tmp/x.txt "$NEXUS/repository/raw-releases-nonprod/_smoke/hello.txt"` | `403 Forbidden` |
| 5 | `ci-nonprod` upload nonprod lần 1 | `curl -i -u ci-nonprod:"$N_PW" --upload-file /tmp/x.txt "$NEXUS/repository/raw-releases-nonprod/_smoke/hello.txt"` | `201` |
| 6 | `ci-nonprod` upload nonprod lần 2 | lặp lại lệnh 5 | `200` hoặc `204` |

> **Dọn dẹp sau test:** login `admin`, xoá thư mục `_smoke` ở cả 2 repo.

---

## 9. Cấu hình GitHub Secrets & Variables

**GitHub repo → Settings → Secrets and variables → Actions**

### Tab Variables (public, không phải bí mật)

| Variable | Giá trị |
|---|---|
| `APP_SLUG` | `shimeji` |
| `NEXUS_PROD_REPO` | `raw-releases-prod` |
| `NEXUS_NONPROD_REPO` | `raw-releases-nonprod` |
| `DISCORD_USER_IDS` | `id1,id2,id3` *(optional, để tag)* |

### Tab Secrets

| Secret | Giá trị | Ghi chú |
|---|---|---|
| `NEXUS_URL` | `https://nexus.stemlabs.site` | |
| `NEXUS_USERNAME` | `ci-nonprod` | Workflow nonprod |
| `NEXUS_PASSWORD` | *pw ci-nonprod* | |
| `NEXUS_USERNAME_PROD` | `ci-prod` | Workflow prod *(tách riêng là best practice)* |
| `NEXUS_PASSWORD_PROD` | *pw ci-prod* | |
| `KEYSTORE_BASE64` | base64 của `keystore.jks` | |
| `KEYSTORE_PASSWORD` | | per-app; generate: = applicationId |
| `KEY_ALIAS` | `key0` | per-app |
| `KEY_PASSWORD` | | per-app; = applicationId |
| `GOOGLE_SERVICES_JSON_BASE64` | base64 của `app/google-services.json` **PRODUCTION** | Bắt buộc trên **repo** (không phải org). Thủ công. |
| `DISCORD_WEBHOOK_URL` | | **org** af-products |
| `GITHUB_ACTOR`, `GH_PACKAGES_TOKEN` | | **org** af-products. Legacy: `NV_ACTOR` / `NV_TOKEN` |

> **Khuyến nghị:** Nexus / Discord / GH Packages để **org secret** `af-products`. Chỉ đẩy per-repo: keystore + Firebase PRODUCTION. `push-secret.sh` bỏ qua org keys + value rỗng (tránh đè org bằng chuỗi trống).

### Tạo base64 keystore / google-services

```bash
# macOS / Linux — hoặc dùng scripts/gen-env-base64.sh / bootstrap-ci.sh
base64 -w 0 app/keystore.jks | pbcopy
base64 -w 0 app/google-services.json | pbcopy
```

```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("keystore.jks")) | clip
```

---

## 10. Tích hợp vào GitHub Actions workflow

Workflow cần có **3 nhóm step** theo đúng thứ tự:

### (A) Compute artifact metadata

- Đọc `versionName` / `versionCode` từ `app/build.gradle.kts`
- Git short SHA: `git rev-parse --short HEAD`
- Build date: `date -u +%Y-%m-%d`
- **Gate tag vs versionName:** `TAG_VER="${TAG#v}"; [ "$TAG_VER" = "$VERSION_NAME" ] || exit 1`
- Compose `DEST_DIR = <APP>/<platform>/<store>/<track>/<ver>+<code>`
- Compose `BASE_NAME` theo convention §1.2
- Export ra `$GITHUB_OUTPUT`

### (B) Stage artifacts

- `cp` file build gốc sang `stage/` với tên `BASE_NAME.<ext>`
- `cp` `mapping.txt`, `native-debug-symbols.zip` (nếu prod)
- Sinh `metadata.json` bằng `jq`:

  ```json
  {
    "app": "shimeji",
    "platform": "android",
    "store": "playstore",
    "track": "production",
    "flavor": "prod",
    "tag": "v1.2.1",
    "versionName": "1.2.1",
    "versionCode": "125",
    "gitSha": "a1b2c3d...",
    "gitShortSha": "a1b2c3d",
    "buildDate": "2026-04-20",
    "builtBy": "github_actor",
    "ciJobUrl": "https://github.com/.../actions/runs/...",
    "signerSha256": "AA:BB:..."
  }
  ```

- Với mỗi file trong `stage/`, sinh sidecar `.sha256`:

  ```bash
  sha256sum "$f" | awk '{print $1"  "basename}' > "${f}.sha256"
  ```

### (C) Upload to Nexus

- `REPO_BASE = $NEXUS_URL/repository/$NEXUS_REPO/$DEST_DIR`
- Với mỗi file trong `stage/`: `PUT` lên `$REPO_BASE/<filename>`
- Check HTTP code, fail nếu không `200/201/204`
- Map lỗi đọc hiểu:

  | Code | Nghĩa |
  |---|---|
  | `400` | Redeploy disabled + path đã tồn tại |
  | `401` | Sai credentials |
  | `403` | Thiếu privilege hoặc sai repo |
  | `404` | Repo không tồn tại |

- Export URL để step Discord dùng

### Quyết định thêm

- Tag nào → track nào? (thường: `vX.Y.Z` → `production`, `*-rc` → `beta`, `*-test` → `internal`)
- Khi fail upload, có cleanup partial không? *(nên có)*
- Có upload artifact lên GitHub Actions artifacts luôn không để fallback?

> **Reference:** các file đã viết sẵn — `build-release.yml`, `test-rc-build.yml`, `release-rc.yml` trong cùng thư mục này.

---

## 11. Test end-to-end

Thứ tự từ dễ/an toàn → khó/rủi ro cao.

- [ ] **Bước 1: tag test**
  ```bash
  git tag v0.0.1-test && git push origin v0.0.1-test
  ```
  Kỳ vọng: file ở `raw-releases-nonprod/<app>/android/playstore/internal/0.0.1+<code>/`. Discord nhận link đủ.

- [ ] **Bước 2: tag RC**
  ```bash
  git tag v0.0.1-rc && git push origin v0.0.1-rc
  ```
  Kỳ vọng: file ở track `beta`.

- [ ] **Bước 3: tag prod** *(bump `versionCode` trong gradle trước)*
  ```bash
  git tag v0.0.1 && git push origin v0.0.1
  ```
  Kỳ vọng: file ở `raw-releases-prod/...`.

- [ ] **Bước 4: test chống ghi đè**
  Re-run workflow prod với cùng `versionCode`.
  Kỳ vọng: **FAIL** ở step upload với **HTTP 400**. Đây là hành vi **mong muốn**.

- [ ] **Bước 5: test notification workflow manual**
  Actions → *Release Candidate Notification* → Run workflow:
  - `tag_name`: `v0.0.1-rc`
  - `build_type`: `RC`

  Kỳ vọng: tìm được đúng 3 APK và gửi Discord.

- [ ] **Bước 6: test anonymous download** *(nếu đã bật §7)*
  Mở URL Discord bằng incognito → tải được không cần login.

---

## 12. Migration dữ liệu cũ

Nếu đã có repo cũ kiểu `raw-releases/release/vX.Y.Z/app-release.apk`:

- [ ] Liệt kê bản cần giữ (thường là N bản prod gần nhất + bản đang phát hành)
- [ ] Với mỗi bản:
  - Tải file cũ về
  - Đổi tên theo convention §1.2 (tra `versionCode` + `gitSha` trong git log)
  - Tính sha256
  - Upload lên `raw-releases-prod` bằng `ci-prod`
- [ ] Repo cũ → chuyển thành read-only, đánh dấu `ARCHIVED - do not upload`
- [ ] Sau 3-6 tháng không dùng → xoá

### Script mẫu

```bash
OLD=https://nexus.stemlabs.site/repository/raw-releases
NEW=https://nexus.stemlabs.site/repository/raw-releases-prod
VER=1.2.0; CODE=120; SHA=abcdef0; DATE=2026-01-15
APP=shimeji

for EXT in apk aab; do
  curl -u admin:... -O "$OLD/release/v$VER/app-release.$EXT"
  NEW_NAME="$APP-android-playstore-prod-production-$VER-$CODE-$DATE-$SHA.$EXT"
  mv "app-release.$EXT" "$NEW_NAME"
  sha256sum "$NEW_NAME" > "$NEW_NAME.sha256"

  DEST="$NEW/$APP/android/playstore/production/$VER+$CODE"
  curl -u ci-prod:... --upload-file "$NEW_NAME"        "$DEST/$NEW_NAME"
  curl -u ci-prod:... --upload-file "$NEW_NAME.sha256" "$DEST/$NEW_NAME.sha256"
done
```

---

## 13. Lockdown & hardening

*(Làm sau khi chạy ổn 1-2 tuần.)*

- [ ] Tách credentials prod/nonprod nếu chưa: `NEXUS_USERNAME_PROD` ≠ `NEXUS_USERNAME`
- [ ] Gỡ quyền write của mọi user người khỏi `raw-releases-prod`. Chỉ `ci-prod` có `ci-prod-writer`.
- [ ] **Security → Anonymous Access:** tắt nếu không cần; nếu cần, đảm bảo `nx-anonymous` chỉ có read nonprod.
- [ ] **Security → Realms:** chỉ giữ Local Authenticating + (nếu có) LDAP/SAML. Gỡ realm không dùng (Docker Bearer Token Realm, …).
- [ ] Rotate password `ci-prod` / `ci-nonprod` định kỳ **90 ngày** → cập nhật GitHub secret.
- [ ] **Audit log** (Nexus Pro): Logging → Audit → enabled; forward sang SIEM.
- [ ] **Backup:**

  | Thư mục | Bắt buộc |
  |---|---|
  | `sonatype-work/nexus3/db/` | ✅ (metadata) |
  | `sonatype-work/nexus3/blobs/releases-prod/` | ✅ |
  | `sonatype-work/nexus3/blobs/releases-nonprod/` | ❌ (60 ngày tự rotate) |

  Lịch backup hàng đêm, giữ 30 bản. Test restore ít nhất 1 lần/quý.

- [ ] **HTTPS bắt buộc.** Không cho basic auth qua HTTP plain.
- [ ] **Reverse proxy** (nginx/Caddy) để terminate TLS, thêm rate limit, security headers.
- [ ] **Monitoring:** alert khi disk blob store > 80%, upload fail liên tục, anonymous traffic bất thường.

---

## 14. Troubleshooting

### `HTTP 401 Unauthorized`

- Sai username/password. Check secret GitHub có khoảng trắng thừa không.
- Password có ký tự đặc biệt: luôn quote single-quote `'...'` trong shell.

### `HTTP 403 Forbidden` khi upload

- Role thiếu privilege `-add` **hoặc** `-edit`. Thêm đủ 4 (`add`/`edit`/`read`/`browse`).
- User chưa được gắn role (*Users → Edit → Granted roles*).
- User đang Disabled.
- Dùng `ci-prod` upload nonprod (hoặc ngược lại) — behavior đúng, check lại secret.

### `HTTP 400 Bad Request` khi upload

- Repo đang `Disable redeploy` và path đã tồn tại. **Đây là behavior đúng cho prod.**
- Cần bump `versionCode` (prod) hoặc chuyển sang nonprod.

### `HTTP 404 Not Found`

- Tên repo trong URL sai (check dash/underscore).
- Repo chưa online: *Repositories → Edit → Online ✅*.

### `HTTP 500 Internal Server Error`

- Disk blob store đầy: `df -h` trên máy Nexus.
- Nexus đang read-only: *Settings → System → Read-only → release*.

### Upload OK nhưng Browse UI không thấy file

- Bình thường nếu chưa login hoặc user không có `-browse`.
- Refresh browser. UI browse có cache nhẹ.

### Cleanup không xoá file nonprod cũ

- *Settings → Tasks* → kiểm task `Admin - Cleanup repositories using their associated policies` đang enabled.
- Cleanup xoá component có age > N ngày tính từ lần **cuối download**, không phải upload. File vẫn được tải thì không xoá.

### Link Discord mở bị hỏi login dù đã bật anonymous

- Check `nx-anonymous` role có đúng `-read` privilege cho repo đó.
- Check *Security → Anonymous Access* đang Enabled.
- Clear browser cache.

### Workflow notification tìm không ra artifact

- Path prefix trong step *Resolve artifacts* phải khớp chính xác convention §1. 1 ký tự lệch là không tìm ra.
- Thử REST API thủ công:

  ```bash
  curl -u ci-nonprod:... \
    "$NEXUS/service/rest/v1/search/assets?repository=raw-releases-nonprod&q=<APP>/android/playstore"
  ```

---

## 15. Daily operations

### Release mới

1. Bump `versionCode` & `versionName` trong `app/build.gradle.kts` (commit).
2. `git tag v<X.Y.Z> && git push origin v<X.Y.Z>`
3. Theo dõi Actions, đợi Discord notification.
4. Download AAB từ link, verify sha256:
   ```bash
   sha256sum -c <file>.sha256
   ```
5. Upload AAB lên Play Console.
6. **KHÔNG BAO GIỜ** gỡ tag & push lại cùng version. Muốn sửa → bump code mới.

### RC / QA build

1. `git tag v<X.Y.Z>-rc && git push`
2. Build lại bao nhiêu lần cũng được *(nonprod cho phép redeploy)*.
3. Sau 60 ngày file tự biến mất — đừng đưa link cũ cho ai.

### Hotfix

1. Branch từ tag prod cũ:
   ```bash
   git checkout -b hotfix/1.2.1.1 v1.2.1
   ```
2. Fix, bump `versionCode` (`1.2.1.1` hoặc tăng build number).
3. Tag `v1.2.1.1`, push → workflow build prod.
4. File hotfix nằm trong thư mục `1.2.1.1+<code>/` riêng, **không** đụng `1.2.1+<code>/` cũ.

### Ai đó hỏi: "Cho tôi bản prod cũ"

- Nexus UI → Browse → `raw-releases-prod` → `<app>/android/playstore/production/`
- Hoặc REST:
  ```bash
  curl "$NEXUS/service/rest/v1/search/assets?repository=raw-releases-prod&q=<version>"
  ```

### Bị crash ở Play Console

- Cần `mapping.txt` của đúng `versionCode` crash. Vào thư mục version đó trên Nexus, tải `mapping.txt`, upload Play Console hoặc Crashlytics.

### Health check hàng tuần

- [ ] Disk blob: `df -h` < 80%
- [ ] Số artifact tích luỹ: UI → Browse → xem kích thước repo
- [ ] Cleanup task chạy OK: *Settings → Tasks → last result*
- [ ] Backup job gần nhất thành công
- [ ] Audit log không có upload prod từ user lạ

---

## Kết

Checklist này copy sang mỗi project mới → chỉ cần sửa `APP_SLUG` và tên repo. Convention folder/filename giữ nguyên để sau nhiều project cùng dùng 1 Nexus vẫn không đụng nhau.

| | |
|---|---|
| **Cập nhật** | 2026-04-23 |
| **Maintainer** | _______________ |
