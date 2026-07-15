# Columbia — Implementation Spec

App AI Video Generator (text→video & image→video) dựa trên Qwen Cloud Wan 2.7 API.
Design: dark theme, tím/magenta glassmorphism, motif "Spectrum", biểu tượng sparkle 4 cánh + tia sét (credit).
> Ảnh mẫu trong `image_refs/` gắn nhãn "Lumio"; tên app thật là **Columbia** (giữ nguyên ngôn ngữ thiết kế, đổi brand text).

---

# UI

## Theme

### Phong cách
- **Tông:** "AI/khoa học viễn tưởng nhẹ" — nền gần đen ám tím, các vầng sáng radial tím/magenta ở góc, thẻ kính mờ (glassmorphism) viền mảnh, phát sáng nhẹ (glow) quanh phần tử nhấn.
- **Điểm nhấn:** tím vibrant là màu hành động chủ đạo; magenta dùng cho gradient hero/CTA lớn; **vàng-hổ phách** RIÊNG cho credit (tia sét) — không dùng vàng cho việc khác.
- **Bề mặt:** thẻ bo góc lớn, nền thẻ tối hơi trong, viền `rgba(255,255,255,0.06–0.10)`. CTA chính = pill tím đặc hoặc gradient tím→magenta, có glow (`dropShadow`, KHÔNG `.shadow()` trên nền trong).
- **Nhãn section:** CHỮ HOA nhỏ, giãn chữ, màu tím sáng (vd `SPECTRUM`, `ACCOUNT`, `TOP UP`) đứng trên tiêu đề màn đậm trắng.
- **Chữ:** sans đậm, hình học (Poppins/Montserrat-like). Tiêu đề rất đậm; body xám tím nhạt.

### Palette (khai báo trong `ui/theme/Color.kt`, prefix `Columbia*`)
| Token | Hex | Vai trò |
|---|---|---|
| ColumbiaBackground | `#0A0712` | Nền chính (gần đen ám tím) |
| ColumbiaBackgroundElevated | `#120C1F` | Nền vùng nâng nhẹ |
| ColumbiaGlowViolet | `#3A2270` | Vầng sáng radial góc (tím) |
| ColumbiaGlowMagenta | `#5A1B57` | Vầng sáng radial góc (magenta) |
| ColumbiaSurface | `#16111F` | Nền thẻ đặc |
| ColumbiaSurfaceGlass | `#FFFFFF` @ 6% | Nền thẻ kính (overlay trắng mờ) |
| ColumbiaBorder | `#FFFFFF` @ 8% | Viền thẻ/kính |
| ColumbiaPrimary | `#8B5CF6` | Tím hành động chủ đạo |
| ColumbiaPrimaryBright | `#A87CFF` | Tím sáng (glow, active) |
| ColumbiaPrimaryDeep | `#6D28D9` | Tím đậm (gradient stop) |
| ColumbiaMagenta | `#C026D3` | Magenta (gradient stop, accent) |
| ColumbiaCreditGold | `#F5A623` | Tia sét credit (chỉ dùng cho credit) |
| ColumbiaTextPrimary | `#F6F3FC` | Chữ chính |
| ColumbiaTextSecondary | `#A79FB8` | Chữ phụ |
| ColumbiaTextMuted | `#6C6480` | Chữ mờ/placeholder |
| ColumbiaSuccess | `#3DD68C` | Trạng thái xong |
| ColumbiaDanger | `#F0556B` | Lỗi/thiếu credit |

- **Gradient hero/CTA:** `linear(135°, ColumbiaPrimaryDeep → ColumbiaMagenta)`.
- **Gradient balance card:** `linear(120°, #7C3AED → #C026D3)`.

### Design tokens (theo thang cố định ANDROID_APP_DESIGN)
- Spacing: 4/8/12/16/24/32. Padding ngang nội dung: 16dp.
- Corner: card chủ đạo **20dp**; pill/CTA **50%**; ô nhỏ/chip 12dp.
- Icon: nav/topbar 24dp; icon phụ 18–20dp.
- Type scale (sp): display 30 / screenTitle 26 / sectionTitle 20 / body 15 / caption 12; label-caps 12 (letterSpacing 1.5).
- Touch target ≥ 40dp. Cuối màn scroll thêm spacer 240dp (có banner/nav) hoặc 120dp.

## Layout (theo màn — cây indentation)

Ký hiệu: `[]` thành phần, `()` chú thích. Mọi màn: nền phủ màu + glow radial → statusBarsPadding → topbar cố định → nội dung (padding ngang 16dp).

### 1. HomeScreen  (route: `home`)  — có bottom nav
```
Home (nền + glow góc trên)
  TopBar (cố định)
    [Row]
      [AppLogo] (ô vuông 40dp bo 12dp, gradient tím, sparkle trắng)
      [Text "Columbia"] (display, đậm)
      [Spacer weight]
      [CreditPill] (pill nền tối: ⚡gold + "35" + nút "+" tròn tím)  → mở TopUp
      [IconButton settings] (gear, tròn viền mờ)  → Settings
  Content (scroll dọc)
    [HeroCard] (thẻ kính gradient tím, bo 20dp, glow)
      [Text "Turn ideas & photos into AI videos"] (sectionTitle đậm)
      [PromptInputBar] (pill nền tối trong)
        [Icon sparkle tím] + [TextField "Describe it, we animate it"] + [SendButton →] (tròn gradient)
        (Entry #1 → Generation mode=TEXT, prefill text người dùng gõ)
    [Row 2 mode cards] (gap 12)
      [ModeCard "Text to Video"] (icon "T", tiêu đề + "Describe it, we animate it")
        (Entry #2a → Generation mode=TEXT)
      [ModeCard "Image to Video"] (icon ảnh, tiêu đề + "Bring your photo to life")
        (Entry #2b → ImagePick sub-screen → Generation mode=IMAGE với ảnh đã chọn)
    [SectionLabel "SPECTRUM"] + [Title "Trending effects"]
    [EffectsGrid] (2 cột, thẻ ảnh bo 16dp, nhãn overlay dưới: AI Hug, AI Kiss, Muscle, Baby, Aging, Polaroid, …)
      (Tap effect → Generation mode=IMAGE, prefill prompt của effect + yêu cầu chọn ảnh)
    [Spacer 240dp]
  [FAB] (góc phải dưới, tròn gradient + sparkle, glow)  (Entry #3 → Generation mode=TEXT)
  [BottomNavBar] (thanh nổi bo tròn: Home•Gallery•Profile)
```
(task.md yêu cầu Home có đủ 3 entry: input bar, FAB, hàng 2 nút — "hơi lặp nhưng cứ tuân theo".)

### 2. GenerationScreen  (route: `generation?mode={mode}&effect={effect}`)  — KHÔNG bottom nav
```
Generation (nền + glow)
  TopBar
    [BackButton tròn] + [Spacer] + [CreditPill]
  [PreviewArea] (thẻ lớn gradient tím, bo 20dp, cao ~ nửa màn)
    - mode=TEXT: [sparkle lớn] + [Text "Text to Video"] (giữa)
    - mode=IMAGE: [Ảnh đã import lấp đầy] hoặc (nếu chưa có) [khung "Tap to import" + icon ảnh]
        (tap → mở Photo Picker → CropScreen → set ảnh)
    [ModeToggle] (segmented pill 2 mục: "Text to Video" | "Image to Video", mục active nền tím)
  [ConfigPanel] (sheet bo góc trên, nền tối nâng)
    [Handle] (thanh kéo mảnh)
    [PromptField] (thẻ nền trong, multiline, "Time-lapse of a flower blooming, macro, vivid colors")
        (mode=IMAGE: prompt mô tả chuyển động; vẫn cho nhập)
    [Row] [Label "Try an idea"] [Spacer] [Button "⇄ Surprise me"] (tím)
    [IdeaChips] (cuộn ngang: Neon city, Space cat, Cherry blossom, …) (tap → điền prompt)
    [SectionLabel "RESOLUTION"]
    [ResolutionSelector] (2 ô: "720P" | "1080P HD") (ô phải có khoá nếu chưa premium — hiển thị 🔒)
    [SectionLabel "ASPECT RATIO"]
    [RatioSelector] (chips: 16:9 · 9:16 · 1:1 · 4:3 · 3:4)
    [SectionLabel "DURATION"]
    [DurationSlider] (2–15s, hiện giá trị hiện tại "8s")
    [WatchAdsBanner] (viền tím: "▷ Watch 10 ads to create free")  (mode kiếm credit qua ad)
    [Row]
      [Text "Generate ⚡{cost}"] (chi phí credit theo resolution×duration)
      [GenerateButton] (pill gradient lớn "✦ Generate")  → kiểm credit → gọi API → GeneratingScreen/overlay
  (Loading state khi generate: overlay lottie + tiến trình polling; xong → ResultScreen)
```

### 3. ImagePickScreen  (route: `imagepick`)  — màn phụ chỉ để import ảnh (task.md yêu cầu)
```
ImagePick (nền + glow)
  TopBar [BackButton]
  Content (giữa màn)
    [Illustration] (khung tròn glow + icon ảnh)
    [Title "Choose a photo"] + [Sub "Pick an image to bring to life"]
    [Button "Import from gallery"] (pill gradient)  → Photo Picker → CropScreen
  (Sau khi crop xong → điều hướng Generation mode=IMAGE kèm ảnh)
```

### 4. CropScreen  (route: `crop`)  — crop ảnh đầu vào (task.md yêu cầu)
```
Crop (nền đen)
  TopBar [BackButton] + [Title "Crop"] + [Action "Done"] (tím)
  [CropView] (AndroidView bọc thư viện crop, khung theo ratio đang chọn)
  [BottomBar] (chọn nhanh ratio: 9:16 · 1:1 · 16:9 · free; nút Rotate)
  (Done → xuất ảnh đã crop → base64 → về Generation)
```

### 5. ResultScreen  (route: `result/{creationId}`)  — xem video kết quả
```
Result (nền + glow)
  TopBar [BackButton] + [Title "Your video"]
  [VideoPlayer] (AndroidView VideoView, bo 20dp, tap để play/pause, loop)
  [PromptCaption] (thẻ nền trong: prompt gốc + meta: resolution/ratio/duration)
  [Row actions] [Button "Save"] (tải về máy/Gallery) [Button "Share"] (chia sẻ)
  [Button "Create another"] (pill gradient)
```

### 6. GalleryScreen  (route: `gallery`)  — có bottom nav ; "My creations"
```
Gallery (nền + glow)
  TopBar [SectionLabel "YOUR SPECTRUM"] + [Title "My creations"]
  Content
    - Empty: giữa màn [FilmIcon glow] + [Title "No videos yet"] + [Sub "Your generated videos will appear here."] + [Button "✦ Create a video"]
    - List: [Grid 2 cột] thẻ video (thumbnail + ▷ + thời lượng) (tap → Result)
  [FAB]  → Generation
  [BottomNavBar]
```

### 7. ProfileScreen  (route: `profile`)  — có bottom nav ; "Account"
```
Profile (nền + glow)
  TopBar [SectionLabel "ACCOUNT"] + [Title "Profile"]
  Content
    [BalanceCard] (thẻ kính gradient: ⚡ tròn + "35 credits" + [Button "Get credits"])  → TopUp
    [OptionsGrid] (2 cột, thẻ 20dp, icon ô bo + nhãn)
      [Premium] (vương miện)  → Paywall
      [Get credits] (dấu +)  → TopUp
      [Watch an ad · +2 credits] (▷)  → xem reward ad → +2 credit
      [Restore purchase] (↺)  → stub IAP
      [Settings] (gear)  → Settings
  [FAB]  → Generation
  [BottomNavBar]
```

### 8. SettingsScreen  (route: `settings`)  — KHÔNG bottom nav
```
Settings (nền + glow)
  TopBar [BackButton]
  [SectionTitle "Settings"] (tím) + [Sub "Tailor the app to your needs"]
  [AppInfoCard] (thẻ kính: icon ô + "Columbia AI" + "Turn ideas & photos into AI videos")
  [OptionsGrid] (2 cột)
    [Language] (globe)  → LanguageScreen (tái dùng của base)
    [Rate Us] (👍)  → in-app review/Play
    [Share] (paper plane)  → share intent
    [Privacy Policy] (shield)  → webview/link
    [Terms of Use] (shield-check)  → webview/link
```

### 9. TopUpScreen  (route: `topup`)  — KHÔNG bottom nav ; "Credits"
```
TopUp (nền + glow)
  TopBar [BackButton] + [SectionLabel "TOP UP"] + [Title "Credits"]
  Content (scroll)
    [BalanceBanner] (thẻ gradient tím→magenta lớn: ⚡ + "35 credits")
    [WatchAdRow] (thẻ nền tối: ▷gold + "Watch an ad · +2 credits" + ">")  → reward ad
    [SectionLabel "SPECTRUM PACKS"] + [Title "Get credits"]
    [PacksList] (thẻ pack: ⚡ + "{n} credits" + ["+X% extra"] + [PriceButton "$x.xx"]; 1 thẻ badge "POPULAR")
      (Bấm mua = stub: chỉ Button + Screen, logic purchase xử lý sau — theo hub CLAUDE.md)
    [Spacer 120dp]
```

### 10. PaywallScreen  (route: `paywall`)  — Premium (stub IAP: chỉ Button + Screen)
```
Paywall (nền gradient tím đậm)
  TopBar [CloseButton]
  [Crown/Hero] + [Title "Columbia Premium"] + [FeatureList] (1080P, no ads, unlimited-ish, priority)
  [PlanOptions] (Weekly / Yearly — pill chọn)
  [CTA "Continue"] (gradient)  (stub)
  [Row links] Restore · Terms · Privacy
```

### Trạng thái phụ cần thiết kế (suy ra ngoài ảnh mẫu)
- **Generating/loading:** overlay lottie sparkle + text tiến trình ("Creating your video…", đếm bước polling). Không cho thoát giữa chừng ngoài nút Cancel.
- **Lỗi generate / thiếu credit:** popup nền kính: thông báo + CTA ("Get credits" / "Retry").
- **Empty gallery:** như mục 6.
- **ContentModerated / InvalidMedia:** popup thân thiện, gợi ý đổi prompt/ảnh.

### Flow chuẩn (base) — giữ nguyên
`SplashScreen → LanguageScreen → OnboardingScreen → MainScreen(bottom nav: Home/Gallery/Profile)`. Feature bắt đầu từ Home.

---

# Core Logic

## Kiến trúc (feature-first, theo APP_STRUCTURE)
```
app/
  core/
    datastore/SettingManager.kt      (đã có ở base — mở rộng: credits, isPremium, adFreeUntil)
    file/FileManager.kt              (lưu/đọc mp4 & thumbnail vào filesDir)
    json/JsonLoader.kt               (đọc asset json: effects, idea prompts)
  data/
    domain/                          (@Serializable models)
      Creation.kt        (id, prompt, mode, videoLocalPath, thumbPath, resolution, ratio, durationSec, createdAt)
      Effect.kt          (id, name, promptTemplate, previewAsset)
      CreditPack.kt      (id, credits, extraPercent, priceLabel, popular)
    json/
      CreationRepo.kt    (singleton: StateFlow<List<Creation>> lưu JSON qua DataStore/FileManager)
    api/
      ApiClient.kt       (HTTP nền tảng: POST/GET JSON, header auth, timeout, retry nhẹ)
      ApiRepo.kt         (wrap ApiClient, expose kết quả qua StateFlow/suspend; giấu chi tiết Qwen/Wan)
  corefeatures/
    videogen/VideoGenerator.kt       (điều phối: text→image→video / image→video + polling)
  features/
    home/        HomeScreen, HomeComponents, HomeViewModel
    generation/  GenerationScreen, GenerationComponents, GenerationViewModel, models/
    imagepick/   ImagePickScreen
    crop/        CropScreen (+ AndroidView crop)
    result/      ResultScreen, ResultViewModel
    gallery/     GalleryScreen, GalleryViewModel
    profile/     ProfileScreen, ProfileViewModel
    settings/    SettingsScreen
    topup/       TopUpScreen, TopUpViewModel
    paywall/     PaywallScreen
    language/    (tái dùng LanguageScreen của base)
  ui/
    theme/       Color.kt, Theme.kt, Type.kt
    components/  ColumbiaTopBar, SectionLabel, CreditPill, GradientButton, GlassCard, OptionCard,
                 BottomNavBar, ColumbiaFab, ChoiceChip, LoadingOverlay, AppDialog
  App.kt (flow + NavHost), MainActivity.kt
```
- **DI:** không dùng framework — singleton `object` + ViewModel (viewmodel-compose có sẵn).
- **Persistence:** DataStore (`datastore-preferences` có sẵn) + JSON (`kotlinx-serialization-json` có sẵn) cho Creation/credits. KHÔNG Room.
- **IO:** mọi network/file trên `Dispatchers.IO` trong scope của repo/VM; UI đọc `StateFlow`. Fail-open: bắt exception, trả null/an toàn, `Log.e`, không crash Compose.
- **Ảnh:** `coil-compose` (có sẵn) load thumbnail/ảnh remote. Video: `VideoView` qua `AndroidView` (không thêm ExoPlayer).

## API integration (Qwen Cloud Wan 2.7 — xem `api_specs/gen_api_specs.md`)
- Base: `https://dashscope-intl.aliyuncs.com/api/v1`. Header `Authorization: Bearer {KEY}`, `Content-Type: application/json`.
- Key: đặt trong `BuildConfig`/hằng số (MVP nhúng client — **rủi ro đã biết**, production nên proxy).
- **Part A — `qwen-image-2.0`** (đồng bộ): text→ảnh. Endpoint `/services/aigc/multimodal-generation/generation`. Lấy `output.choices[0].message.content[0].image` (URL public 24h).
- **Part B — `wan2.7-i2v`** (bất đồng bộ): ảnh→video. Header thêm `X-DashScope-Async: enable`. POST `/services/aigc/video-generation/video-synthesis` → `task_id`. GET `/tasks/{task_id}` cho tới `SUCCEEDED` (lấy `video_url`) / `FAILED`.
- ✅ **base64 data URI HỢP LỆ cho cả A và B** (đã kiểm chứng bằng call thật — spec ghi "chỉ URL" là SAI). → Ảnh local crop nhét thẳng `data:image/jpeg;base64,{...}` vào `media[].url`; **không cần upload/Firebase/backend**.

### Hai luồng generate (VideoGenerator điều phối)
- **mode=IMAGE:** ảnh crop → base64 → Part B (first_frame) → poll → video_url → tải về local.
- **mode=TEXT:** prompt → Part A (text→ảnh) → nhận image URL → Part B (image→video) → poll → video_url → tải về local. (Không có model text→video trực tiếp; ghép chuỗi.)
- **Polling:** 3s/lần trong 30s đầu, sau tăng dần (5s→8s), timeout ~5 phút. Chạy trong `viewModelScope`; hiển thị LoadingOverlay; có Cancel.
- **Sau SUCCEEDED:** download mp4 (URL hết hạn 24h) về `filesDir` qua FileManager, sinh thumbnail (frame đầu), tạo `Creation`, lưu `CreationRepo` → hiện ở Gallery + mở ResultScreen.
- **FAILED/exception:** hoàn lại credit đã trừ, hiện popup lỗi thân thiện (map `ContentModerated`/`InvalidMedia`/`Throttling`).

## Credit (local, theo task.md)
- Lưu `credits: Int` trong SettingManager (DataStore), mặc định 35.
- **Chi phí generate** = f(resolution, duration): vd `720P`: 20 + (duration-2); `1080P`: nhân đôi. Hiển thị "Generate ⚡{cost}" động.
- Trừ credit khi bắt đầu generate; **hoàn** nếu FAILED.
- **Cộng credit:** reward ad (+2), "Watch 10 ads to create free" (đủ N ad → 1 lần free), credit packs (IAP stub → cộng số credit tương ứng khi purchase — logic purchase để sau).
- Không đủ credit → chặn Generate, mở popup → TopUp/Paywall/Watch ad. (Lưu ý: local dễ bypass — chấp nhận cho MVP.)

## Navigation
- Base flow qua `App.kt` (Splash→Language→Onboarding→Main). `Main` chứa NavHost với bottom nav (home/gallery/profile) + các route ngoài nav (generation, imagepick, crop, result, settings, topup, paywall).
- Routes (chữ thường, danh từ số ít): `home`, `gallery`, `profile`, `generation`, `imagepick`, `crop`, `result/{id}`, `settings`, `topup`, `paywall`, `language`.
- Ảnh crop truyền giữa các màn qua ViewModel/state holder chung (tránh nhét bytes vào route args).

## Assets chuẩn bị
- `assets/effects.json`: danh sách Trending effects (id, name, promptTemplate, previewAsset/URL).
- `assets/ideas.json`: prompt gợi ý ("Neon city", "Space cat", "Cherry blossom", …) cho "Try an idea/Surprise me".
- `assets/credit_packs.json`: các pack (50/$1, 190/+27%, 300/+20%, …, POPULAR).
- Preview effect: dùng ảnh public ổn định hoặc drawable gradient placeholder (theo ANDROID_APP_DESIGN) nếu chưa có asset.

## Ads (chỉ tích hợp ở phase05 — bỏ qua lúc build UI/logic)
Reward ad (+credit), inter (splash/chuyển màn), native (home/gallery), banner. Áp theo ADS_LOGIC ở phase05; hiện chỉ chừa chỗ (nút "Watch an ad", "Watch 10 ads").

---

# Phase 02 — Refinements (rà UI/UX + logic trước khi code)

## UI/UX nhất quán (chốt để tránh lệch khi build)
- **Home 2 mode-card:** cùng `weight(1f)` + `heightIn(min=140.dp)` + `Arrangement.spacedBy(12.dp)` → hai thẻ luôn bằng chiều cao dù text khác dòng. Icon ô 46dp, tiêu đề body, mô tả caption — thống nhất cả hai.
- **Generation — resolution:** 2 ô `weight(1f)` bằng nhau (grid 1fr/1fr), KHÔNG trộn ô natural-width. Ratio & idea = `ChoiceChip` cùng 1 style (chip cao 40dp, padding ngang 16), khác selector resolution để phân biệt vai trò.
- **Generate row:** dùng `Row(verticalAlignment=CenterVertically)`; cụm "Generate ⚡{cost}" natural-width, nút Generate `weight(1f)` cao 52dp. Không để text và nút lệch baseline.
- **OptionCard (Profile/Settings):** cùng `heightIn(min=120.dp)`, grid 2 cột `spacedBy(12)`. Item lẻ (thứ 5) đứng một mình cột trái — khớp ảnh mẫu (không stretch full-width).
- **CreditPill / ColumbiaTopBar / SectionLabel / GradientButton / GlassCard / OptionCard / BottomNavBar / ColumbiaFab:** dùng CHUNG component ở `ui/components` cho mọi màn (đảm bảo credit pill ở Home = Generation = TopUp; nav item active style đồng nhất).
- **TopUp packs:** pack đầu (50) full-width; các pack sau grid 2 cột cùng chiều cao (`IntrinsicSize.Min`), badge "POPULAR" neo trên viền — thẻ có badge và không badge vẫn bằng cao.
- **Corner radius:** card chủ đạo 20dp toàn app; chip/CTA pill 50%; ô icon 12dp. Không phát sinh mức khác.
- **Glow/shadow:** chỉ `dropShadow()` cho glow trên thẻ kính/nút (nền trong) — KHÔNG `.shadow()` (artifact). Nền mọi màn: màu phủ + 2 vầng radial (tím góc trên-trái, magenta góc trên-phải) như style.css.

## Logic — chốt lựa chọn kỹ thuật (giảm mơ hồ cho phase03)
- **HTTP:** tự viết `ApiClient` bằng `HttpURLConnection` (JSON POST/GET + tải file), **không thêm lib mạng** (tránh phụ thuộc transitive OkHttp). Body base64 ~vài trăm KB: OK.
- **JSON:** `kotlinx-serialization` với data class `@Serializable` cho request/response cả Part A và Part B (đã có plugin + lib ở base).
- **Crop:** dùng `com.vanniktech:android-image-cropper` (mavenCentral, có `CropImageContract`) thay vì tự viết crop — nhanh, ổn định, hỗ trợ chọn ratio/rotate. `CropScreen` trong spec = màn của thư viện (theme tối). **Đánh đổi:** ít kiểm soát pixel giao diện crop; chấp nhận cho MVP.
- **Photo picker:** `ActivityResultContracts.PickVisualMedia` (Android Photo Picker) — KHÔNG cần quyền `READ_MEDIA_IMAGES`.
- **Truyền ảnh giữa màn:** singleton `PendingMedia` (object giữ `Uri`/`ByteArray` ảnh đã crop + prompt effect đang chờ) thay vì nhét bytes vào route args.
- **Effect tap:** Home → (đặt prompt effect vào PendingMedia) → `imagepick` → PhotoPicker → crop → `generation?mode=image` (prompt prefilled). Vì effect cần ảnh nguồn.
- **Video:** phát bằng `VideoView` qua `AndroidView`. Tải mp4 (URL hết hạn 24h) về `filesDir` ngay khi SUCCEEDED (HttpURLConnection stream). Thumbnail = `MediaMetadataRetriever.getFrameAtTime(0)`. Chia sẻ/lưu qua `FileProvider` (khai báo trong Manifest) + `MediaStore` (lưu về máy).
- **Chi phí credit (chốt số):** `cost = resBase + max(0, durationSec-5) * 2`, với `resBase(720P)=20`, `resBase(1080P)=40`. Trừ khi bắt đầu generate; hoàn khi FAILED/timeout.
- **1080P & premium:** 1080P khoá sau Premium (Paywall). Chưa premium → chọn 1080P mở Paywall.
- **Manifest bổ sung (phase03):** `INTERNET` (đã có), `FileProvider` (share/save), khai báo Photo Picker không cần quyền.

## Không có xung đột chặn
task.md + 2 model API + base64 → toàn bộ flow khả thi. KHÔNG cần `discussion.md`.

---

# Addendum (thay đổi khi code — phase03)

- **Crop:** lib `com.vanniktech:android-image-cropper` (`CropImageContract`) tự lo **cả chọn ảnh từ gallery LẪN crop** trong 1 flow → **bỏ** màn PhotoPicker và CropScreen riêng. `ImagePickScreen` chỉ còn nút "Import from gallery" gọi contract.
- **Danh mục tĩnh:** effects/ideas/credit packs để trong Kotlin (`data/domain/Catalog`) thay cho `assets/*.json` — gọn, tránh parse; dễ chuyển JSON sau nếu cần động.
- **API key:** hằng số trong `data/api/ApiConfig` (không dùng BuildConfig) cho gọn. (Rủi ro lộ key giữ nguyên như đã ghi.)
- **Icons:** thêm `androidx.compose.material:material-icons-extended` để dùng icon vector chuẩn (thay vì emoji/tự vẽ).
- **Resolution:** UI chỉ 720P (free) & 1080P (premium-gated) — bỏ nhãn 480p của ảnh mẫu (không phải giá trị API hợp lệ).
- **Reward ad & mua credit là STUB ở phase03:** "Watch an ad · +2" hiện cộng +2 trực tiếp qua dialog (placeholder); "Watch 10 ads to create free" báo "coming soon"; mua credit pack & Premium hiện dialog "preview build". **Reward ad thật làm ở phase05**; purchase do team xử lý sau (theo hub CLAUDE.md).
- **Base flow:** giữ `Splash→Language→Onboarding→` rồi vào `MainScreen` (NavHost + bottom nav Home/Gallery/Profile). LanguageScreen của base được tái dùng cho route `language` trong Settings.
- **FileProvider:** thêm provider + `res/xml/file_paths.xml` để Share video.
