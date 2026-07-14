# CLAUDE.md — Columbia

App Android (Jetpack Compose, single-Activity). Đây là source để phát triển & bảo trì.

## Hiểu app
- Yêu cầu & thiết kế: `blueprint/implementation_spec.md` (UI + Core logic) và `blueprint/task.md` (mô tả tính năng).
- Tài nguyên thiết kế: `blueprint/design_previews/` (mockup + icon), `blueprint/image_refs/`.

## Kiến trúc
- Jetpack Compose, feature-first: `features/` · `ui/` · `core/` · `data/`.

## Build & chạy
- `./gradlew assembleDebug`.
- `google-services.json` phải khớp `applicationId`.
- `local.properties` (sdk.dir) tự tạo lần build đầu; chạy trên thiết bị/emulator **ARM**.
