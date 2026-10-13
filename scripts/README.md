# Release & DevOps Scripts

Tài liệu đầy đủ cho các script release, build và deployment của dự án Android. Hỗ trợ **macOS/Linux** (Bash) và **Windows** (PowerShell).

---

## 📋 Mục lục

- [Tổng quan](#tổng-quan)
- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Cấu hình](#cấu-hình)
- [Danh sách Scripts](#danh-sách-scripts)
- [Hướng dẫn chi tiết từng Script](#hướng-dẫn-chi-tiết-từng-script)
- [Workflow Release điển hình](#workflow-release-điển-hình)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Tổng quan

Các script tự động hóa:

- **Build APK/AAB** với version quản lý tự động
- **Tạo Git tags** và **GitHub Releases**
- **Upload artifacts** lên GitHub Releases
- **Trigger GitHub Actions workflows**
- **Quản lý keystore** (tạo, xuất secrets cho CI)
- **Tối ưu assets** (video, hình ảnh)
- **Test GitHub API** và cấu hình token

### Version Management

| Thuộc tính | Mô tả | Ví dụ |
|------------|--------|--------|
| **versionName** | Hiển thị cho người dùng | `1.0.3`, `2.0.0-beta.1` |
| **versionCode** | Số nguyên luôn tăng (bắt buộc) | `6`, `7`, `200` |

> **Quan trọng**: `versionCode` phải tăng mỗi lần build (yêu cầu của Play Store và Android).

---

## Yêu cầu hệ thống

### macOS / Linux

| Công cụ | Phiên bản |
|---------|-----------|
| Bash | 3.x+ |
| Git | Đã cấu hình remote GitHub |
| Gradle | Qua `gradlew` |
| curl | Để gọi GitHub API |
| keytool | JDK (để gen-key) |
| ffmpeg | Chỉ cho `compress-videos` |

### Windows

| Công cụ | Phiên bản |
|---------|-----------|
| PowerShell | 5.1+ (Windows) hoặc PowerShell Core 7+ |
| Git | Đã cấu hình remote GitHub |
| Gradle | Qua `gradlew` / `gradlew.bat` |
| JDK | `keytool` trong PATH |
| ffmpeg | Chỉ cho `compress-videos` |

### GitHub Token

Token cần các quyền:

- `repo` (full control)
- `workflow` (để trigger workflows)

---

## Cấu hình

### 1. Tạo GitHub Personal Access Token

1. GitHub → **Settings** → **Developer settings** → **Personal access tokens**
2. Tạo token mới (classic) với scopes: `repo`, `workflow`
3. Copy token (chỉ hiển thị một lần)

### 2. Tạo file `.env`

Tạo file `scripts/.env` (hoặc `./scripts/bootstrap-ci.sh` tự scaffold):

```
GITHUB_TOKEN=ghp_your_token_here
```

Generate/bootstrap điền `KEY_*` / `KEYSTORE_*` / `PLAY_PACKAGE_NAME`. Org secrets (Nexus/Discord/GH Packages) **không** copy vào đây.

> File `.env` nằm trong `.gitignore`, **không commit** lên Git.

### 3. Kiểm tra cấu hình

**macOS/Linux:**
```bash
./scripts/test-github-api.sh
```

**Windows:**
```powershell
.\scripts\test-github-api.ps1
# hoặc double-click: run-test-github-api.bat
```

Nếu thành công, script sẽ in ra thông tin repository và workflow.

---

## Danh sách Scripts

| Script | Mô tả | Unix | Windows |
|--------|--------|------|---------|
| **bootstrap-ci** | Gen keystore (`key0` / password = package) + `.env`; `--push` → GitHub | `bootstrap-ci.sh` | — |
| **gen-env-base64** | Encode jks + google-services.json vào `.env` | `gen-env-base64.sh` | `gen-env-base64.ps1` |
| **gen-key** | Tạo Android release keystore (JKS) | `gen-key.sh` | `gen-key.ps1` |
| **gen-github-secrets** | Xuất secrets cho GitHub Actions | `gen-github-secrets.sh` | `gen-github-secrets.ps1` |
| **release-rc** | Build + RC/Test/QA/QC release | `release-rc.sh` | `release-rc.ps1` |
| **recreate-release** | Tạo lại GitHub release | `recreate-release.sh` | `recreate-release.ps1` |
| **release** | Production release | `release.sh` | `release.ps1` |
| **bump_version_logic** | Semver bump (used by `release.sh`) | `bump_version_logic.sh` | — |
| **trigger-workflow** | Trigger GitHub Actions workflow | `trigger-workflow.sh` | `trigger-workflow.ps1` |
| **test-github-api** | Kiểm tra GitHub API token | `test-github-api.sh` | `test-github-api.ps1` |
| **compress-videos** | Nén video trong assets | `compress-videos.sh` | `compress-videos.ps1` |
| **optimize-assets** | Phân tích và gợi ý tối ưu assets | `optimize-assets.sh` | `optimize-assets.ps1` |

### Windows: Cách chạy

**PowerShell trực tiếp:**
```powershell
cd scripts
.\gen-key.ps1 -Help
.\release-rc.ps1 -Help
```

**Batch launcher (double-click hoặc cmd):**
```
run-gen-key.bat
run-release-rc.bat patch
run-test-github-api.bat
```

---

## Hướng dẫn chi tiết từng Script

### bootstrap-ci

Gen upload keystore + điền `scripts/.env`. Alias `key0`, hai password = `applicationId`, DN theo tên app.

```bash
./scripts/bootstrap-ci.sh          # chưa cần remote
./scripts/bootstrap-ci.sh --push   # sau gh repo create
```

Firebase PRODUCTION vẫn thủ công: `gen-env-base64.sh` rồi `push-secret.sh`.

### gen-key

Tạo Android release keystore (JKS) để ký APK/AAB.

| Option | Mô tả |
|--------|--------|
| `-o, --output PATH` | Đường dẫn keystore (default: `app/keystore.jks`) |
| `-a, --alias NAME` | Key alias (default: `key0`) |
| `-v, --validity N` | Số ngày hiệu lực (default: 10000) |
| `-n, --no-prompt` | Non-interactive, dùng env `KEYSTORE_PASSWORD`, `KEY_PASSWORD` |

**Ví dụ:**
```bash
# Unix
./scripts/gen-key.sh
./scripts/gen-key.sh -o app/my_release.jks -a mykey

# Windows
.\scripts\gen-key.ps1
.\scripts\gen-key.ps1 -Output app/my_release.jks -Alias mykey
```

**Env (cho CI / non-interactive):**
- `KEYSTORE_PASSWORD` — bắt buộc nếu `-n`
- `KEY_PASSWORD` — tùy chọn (mặc định = KEYSTORE_PASSWORD)
- `KEYSTORE_CN`, `KEYSTORE_OU`, `KEYSTORE_O`, `KEYSTORE_L`, `KEYSTORE_ST`, `KEYSTORE_C` — thông tin certificate
- `KEYSTORE_DNAME` — chuỗi `-dname` đầy đủ (ghi đè các biến trên)

---

### gen-github-secrets

In ra các secret cần cấu hình cho GitHub Actions (keystore base64, passwords).

**Ví dụ:**
```bash
# Unix
./scripts/gen-github-secrets.sh
./scripts/gen-github-secrets.sh app/release.jks

# Windows
.\scripts\gen-github-secrets.ps1
.\scripts\gen-github-secrets.ps1 app/release.jks
```

> Copy từng giá trị vào **Settings → Secrets and variables → Actions**. Xóa terminal sau khi copy.

---

### release-rc

Build và tạo RC, Test, QA hoặc QC release.

| Option | Mô tả |
|--------|--------|
| `-f, --force` | Force rebuild |
| `--test` | Build TEST (chỉ APK, tag: `v1.1.9-test`) |
| `--qa` | Build QA |
| `--qc` | Build QC |

**Version args:** `major`, `minor`, `patch` hoặc `1.2.3` (version cụ thể)

**Ví dụ:**
```bash
# Unix
./scripts/release-rc.sh patch              # 1.0.0 → 1.0.1-rc (APK + AAB)
./scripts/release-rc.sh --test patch       # 1.0.0 → 1.0.1-test (chỉ APK)
./scripts/release-rc.sh --qa minor
./scripts/release-rc.sh 1.2.3

# Windows
.\scripts\release-rc.ps1 patch
.\scripts\release-rc.ps1 -Test patch
.\scripts\release-rc.ps1 1.2.3
```

**Quy trình:**
1. Kiểm tra uncommitted changes
2. Xác định version mới
3. Xóa tag cũ nếu có (cho phép rebuild)
4. Cập nhật `app/build.gradle.kts`
5. Build APK (và AAB cho RC)
6. Commit version changes
7. Tạo và push tag
8. Tạo GitHub Release
9. Upload APK/AAB
10. Trigger workflow dispatch

---

### recreate-release

Tạo lại GitHub release từ build files có sẵn hoặc rebuild với `-Force`.

| Option | Mô tả |
|--------|--------|
| `-f, --force` | Rebuild APK/AAB trước khi tạo release |
| `--test`, `--qa`, `--qc` | Build type |
| `--trigger-workflow` | Trigger workflow sau khi tạo release |

**Ví dụ:**
```bash
# Unix
./scripts/recreate-release.sh --test 1.1.9
./scripts/recreate-release.sh -f --test 1.1.9
./scripts/recreate-release.sh 1.1.9 --trigger-workflow

# Windows
.\scripts\recreate-release.ps1 -Test 1.1.9
.\scripts\recreate-release.ps1 -Force -Test 1.1.9
.\scripts\recreate-release.ps1 1.1.9 -TriggerWorkflow
```

---

### release

Tạo production release (final, không phải RC).

**Ví dụ:**
```bash
# Unix
./scripts/release.sh patch
./scripts/release.sh 2.0.0
./scripts/release.sh 1.0.0 -f    # Force nếu tag đã tồn tại

# Windows
.\scripts\release.ps1 patch
.\scripts\release.ps1 2.0.0
```

---

### trigger-workflow

Trigger GitHub Actions workflow dispatch độc lập.

**Ví dụ:**
```bash
# Unix
./scripts/trigger-workflow.sh v1.1.9-rc
./scripts/trigger-workflow.sh v1.1.9-rc main
./scripts/trigger-workflow.sh v1.1.9-test bug/fix TEST

# Windows
.\scripts\trigger-workflow.ps1 v1.1.9-rc
.\scripts\trigger-workflow.ps1 v1.1.9-rc main RC
```

Build type được auto-detect từ tag (`-rc` → RC, `-test` → TEST, …).

---

### compress-videos

Nén video trong `app/src/main/assets/videos/`.

**Quality:**
- `high` (default): CRF 23, 1.5Mbps
- `medium`: CRF 28, 1Mbps

**Ví dụ:**
```bash
# Unix
./scripts/compress-videos.sh
./scripts/compress-videos.sh medium

# Windows
.\scripts\compress-videos.ps1
.\scripts\compress-videos.ps1 medium
```

**Yêu cầu:** `ffmpeg` phải có trong PATH.

---

### optimize-assets

Phân tích kích thước assets và in gợi ý tối ưu (video, PNG, GIF, MP3).

**Ví dụ:**
```bash
./scripts/optimize-assets.sh
.\scripts\optimize-assets.ps1
```

---

## Workflow Release điển hình

### 1. Test Build

```bash
./scripts/release-rc.sh --test patch
```

### 2. QA Build

```bash
./scripts/release-rc.sh --qa 1.1.9
```

### 3. RC (Release Candidate)

```bash
./scripts/release-rc.sh patch
```

### 4. Production Release

```bash
./scripts/release.sh patch
```

### 5. Tạo lại Release (nếu cần)

```bash
./scripts/recreate-release.sh --test 1.1.9
./scripts/recreate-release.sh -f --test 1.1.9
```

---

## Troubleshooting

### GITHUB_TOKEN not found

- Tạo `scripts/.env` với `GITHUB_TOKEN=...`
- Chạy `test-github-api` để kiểm tra

### Tag already exists

- `release-rc` tự động xóa tag cũ và tạo lại
- Xóa thủ công: `git push origin --delete v1.1.9-test`

### APK file not found

- Kiểm tra `app/build/outputs/apk/release/`
- Rebuild với `-f`: `recreate-release -f --test 1.1.9`

### Workflow dispatch 403

- Token cần scope `workflow` (classic) hoặc quyền **Actions: Write** (fine-grained)

### Workflow dispatch 404

- Workflow phải tồn tại trên default branch (main/master)
- Kiểm tra `.github/workflows/release-rc.yml`

### Windows: ExecutionPolicy

Nếu PowerShell báo lỗi execution policy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Best Practices

1. Luôn tăng `versionCode` khi rebuild
2. Test với `test-github-api` trước khi release
3. Backup keystore và lưu password an toàn
4. Sử dụng semantic versioning (major.minor.patch)

---

## Cấu trúc thư mục

```
scripts/
├── README.md                 # Tài liệu này
├── .env                      # GitHub token (không commit)
├── .env.example
├── gen-key.sh / .ps1
├── gen-github-secrets.sh / .ps1
├── release-rc.sh / .ps1
├── recreate-release.sh / .ps1
├── bump_version_logic.sh     # major/minor/patch bump (used by release.sh)
├── release.sh / .ps1
├── trigger-workflow.sh / .ps1
├── test-github-api.sh / .ps1
├── compress-videos.sh / .ps1
├── optimize-assets.sh / .ps1
├── run-*.bat                 # Windows batch launcher
└── .gitignore
```

---

**Cập nhật lần cuối:** 2025-03-12
