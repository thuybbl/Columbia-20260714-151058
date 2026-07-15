# Qwen Cloud Wan 2.7 — API Reference

> **Base URL:** `https://dashscope-intl.aliyuncs.com/api/v1`

> ✅ **ĐÍNH CHÍNH ĐÃ KIỂM CHỨNG (App-Factory):** Tài liệu bên dưới ghi `wan2.7-i2v` `media[].url`
> "chỉ nhận public HTTP/HTTPS URL" — **SAI**. Đã test call thật (task SUCCEEDED): trường `url` **CHẤP NHẬN
> base64 data URI** dạng `data:image/jpeg;base64,{...}`. → Ảnh user import/crop (local) đưa **thẳng base64**
> vào Part B, **KHÔNG cần** upload/host/Firebase Storage/backend. Áp dụng cho cả Part A và Part B.
> "Text→video" ghép chuỗi: `text → Part A (ra ảnh) → Part B (ảnh→video)`.

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Part A — Image Generation & Editing (`qwen-image-2.0`)](#part-a--image-generation--editing-qwen-image-20)
   - [A1. Endpoint & Flow](#a1-endpoint--flow)
   - [A2. Request Payload](#a2-request-payload)
   - [A3. Response Payload](#a3-response-payload)
   - [A4. Use Cases & Examples](#a4-use-cases--examples)
3. [Part B — Image to Video (`wan2.7-i2v`)](#part-b--image-to-video-wan27-i2v)
   - [B1. Endpoint & Flow](#b1-endpoint--flow)
   - [B2. Request Payload](#b2-request-payload)
   - [B3. Response Payload](#b3-response-payload)
   - [B4. Use Cases & Examples](#b4-use-cases--examples)
4. [Error Handling](#4-error-handling)

---

## 1. Authentication

Tất cả requests đều yêu cầu header:

```
Authorization: Bearer {DASHSCOPE_API_KEY}
Content-Type: application/json
```

**API Key:**

```
sk-ws-H.YPIIIM.RIwn.MEUCIE2UwNogT7QBvBpHt_g2p-WmtN1iR1SAeUwaq4vu2wASAiEA6g_hNFO8IL0l1L2l-opuqWxlASTuEvJPTYvo4mt9so0
```

> URL hết hạn sau **24 giờ** — download ảnh/video ngay sau khi nhận kết quả.

---

## Part A — Image Generation & Editing (`qwen-image-2.0`)

### A1. Endpoint & Flow

`qwen-image-2.0` dùng **synchronous** call — không cần polling task.

```
POST https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation
  → 200 OK { "output": { "choices": [ { "message": { "content": [ { "image": "..." } ] } } ] } }
```

---

### A2. Request Payload

#### Cấu trúc đầy đủ

```json
{
  "model": "qwen-image-2.0",
  "input": {
    "messages": [
      {
        "role": "user",
        "content": [
          { "image": "string (public URL hoặc Base64, tùy chọn)" },
          { "text": "string (bắt buộc, prompt)" }
        ]
      }
    ]
  },
  "parameters": {
    "size": "2048*2048",
    "n": 1,
    "prompt_extend": true,
    "negative_prompt": "string",
    "watermark": false
  }
}
```

#### `input.messages`

Chỉ hỗ trợ **single-turn**: đúng **1** message với `"role": "user"`.

#### `content` items

| Field | Type | Bắt buộc | Mô tả |
|---|---|---|---|
| `text` | string | Có (đúng 1) | Prompt mô tả ảnh cần tạo hoặc chỉnh sửa. Hỗ trợ tiếng Anh và tiếng Trung. |
| `image` | string | Không (1–3 ảnh) | URL công khai (HTTP/HTTPS) hoặc Base64 (`data:{mime};base64,{data}`) |

> Để **chỉnh sửa ảnh**, truyền ảnh đầu vào qua các `image` items. Thứ tự trong `content` xác định "image 1", "image 2",... trong prompt.

**Ràng buộc ảnh đầu vào:**

| Thuộc tính | Giới hạn |
|---|---|
| Định dạng | JPEG, JPG, PNG, BMP, WEBP |
| Số lượng | 1–3 ảnh / request |

#### `parameters`

| Field | Type | Default | Mô tả |
|---|---|---|---|
| `size` | string | `"2048*2048"` | Kích thước ảnh đầu ra theo `"width*height"`. Phạm vi: 512×512 – 2048×2048. |
| `n` | integer | `1` | Số ảnh cần tạo. Phạm vi: 1–6. |
| `prompt_extend` | boolean | `true` | AI tự mở rộng prompt ngắn để tăng chất lượng. |
| `negative_prompt` | string | — | Những gì cần loại trừ khỏi ảnh (ví dụ: "blurry, extra fingers"). |
| `watermark` | boolean | `false` | Thêm watermark vào ảnh đầu ra. |

**`size` — Kích thước phổ biến theo tỷ lệ:**

| Tỷ lệ | Kích thước |
|---|---|
| 1:1 | `2048*2048` |
| 16:9 | `2048*1152` |
| 9:16 | `1152*2048` |
| 4:3 | `1920*1440` |
| 3:4 | `1440*1920` |

---

### A3. Response Payload

#### Thành công → `200 OK`

```json
{
  "status_code": 200,
  "request_id": "d2d1a8c0-325f-9b9d-8b90-xxxxxx",
  "code": "",
  "message": "",
  "output": {
    "choices": [
      {
        "finish_reason": "stop",
        "message": {
          "role": "assistant",
          "content": [
            {
              "image": "https://dashscope-result-intl.oss-cn-shanghai.aliyuncs.com/xxx.png?Expires=xxx"
            }
          ]
        }
      }
    ]
  },
  "usage": {
    "image_count": 1,
    "width": 2048,
    "height": 2048
  }
}
```

| Field | Type | Mô tả |
|---|---|---|
| `output.choices[].message.content[].image` | string | URL tải ảnh. **Hết hạn sau 24h.** |
| `usage.image_count` | integer | Số ảnh đã tạo |
| `usage.width` | integer | Chiều rộng ảnh đầu ra (px) |
| `usage.height` | integer | Chiều cao ảnh đầu ra (px) |

> Nếu `n > 1`, mỗi ảnh là một object riêng trong `output.choices[0].message.content[]`.

#### Lỗi

```json
{
  "status_code": 400,
  "request_id": "...",
  "code": "InvalidParameter",
  "message": "..."
}
```

---

### A4. Use Cases & Examples

#### A4.1 Text-to-Image

```bash
curl --location 'https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-ws-H.YPIIIM.RIwn.MEUCIE2UwNogT7QBvBpHt_g2p-WmtN1iR1SAeUwaq4vu2wASAiEA6g_hNFO8IL0l1L2l-opuqWxlASTuEvJPTYvo4mt9so0' \
  -d '{
    "model": "qwen-image-2.0",
    "input": {
      "messages": [
        {
          "role": "user",
          "content": [
            { "text": "A flower shop with exquisite windows, a beautiful wooden door, and flowers on display" }
          ]
        }
      ]
    },
    "parameters": {
      "size": "2048*2048",
      "n": 1,
      "prompt_extend": true,
      "negative_prompt": "low quality, blurry, distorted",
      "watermark": false
    }
  }'
```

---

#### A4.2 Image Editing (Multi-Image Reference)

Truyền 1–3 ảnh vào `content` cùng với prompt mô tả cách chỉnh sửa:

```bash
curl --location 'https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-ws-H.YPIIIM.RIwn.MEUCIE2UwNogT7QBvBpHt_g2p-WmtN1iR1SAeUwaq4vu2wASAiEA6g_hNFO8IL0l1L2l-opuqWxlASTuEvJPTYvo4mt9so0' \
  -d '{
    "model": "qwen-image-2.0",
    "input": {
      "messages": [
        {
          "role": "user",
          "content": [
            { "image": "https://example.com/person.png" },
            { "image": "https://example.com/dress.png" },
            { "text": "Make the girl from image 1 wear the black dress from image 2" }
          ]
        }
      ]
    },
    "parameters": {
      "size": "1024*1536",
      "n": 2,
      "prompt_extend": true,
      "watermark": false
    }
  }'
```

---

## Part B — Image to Video (`wan2.7-i2v`)

### B1. Endpoint & Flow

`wan2.7-i2v` dùng **asynchronous** call — cần polling task.

```
POST https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/video-generation/video-synthesis
  → 200 OK { "output": { "task_id": "...", "task_status": "PENDING" } }

GET https://dashscope-intl.aliyuncs.com/api/v1/tasks/{task_id}
  → 200 OK { "output": { "task_status": "SUCCEEDED", "video_url": "..." } }
```

Header bổ sung bắt buộc cho async:

```
X-DashScope-Async: enable
```

**Task statuses:**

| Status | Meaning |
|---|---|
| `PENDING` | Đang xếp hàng, chưa bắt đầu |
| `RUNNING` | Đang tạo |
| `SUCCEEDED` | Hoàn thành — `video_url` có hạn 24h |
| `FAILED` | Thất bại — không tính phí |

> **Polling:** Cứ 3 giây poll một lần trong 30 giây đầu, sau đó tăng dần interval.

---

### B2. Request Payload

#### Cấu trúc đầy đủ

```json
{
  "model": "wan2.7-i2v",
  "input": {
    "prompt": "string (bắt buộc)",
    "media": [
      {
        "type": "first_frame | last_frame",
        "url": "string (public HTTP/HTTPS URL)"
      }
    ],
    "audio_url": "string (tùy chọn, public HTTP/HTTPS URL)"
  },
  "parameters": {
    "resolution": "720P | 1080P",
    "ratio": "16:9 | 9:16 | 1:1 | 4:3 | 3:4",
    "duration": 10,
    "prompt_extend": true,
    "watermark": false,
    "negative_prompt": "string",
    "seed": 12345
  }
}
```

#### `input` fields

| Field | Type | Bắt buộc | Mô tả |
|---|---|---|---|
| `prompt` | string | Có | Mô tả chuyển động và camera. |
| `media` | array | Có | 1 hoặc 2 object ảnh (xem bên dưới). |
| `audio_url` | string | Không | URL công khai của file âm thanh để sync với video. |

#### `media` items

| Field | Type | Giá trị hợp lệ | Mô tả |
|---|---|---|---|
| `type` | string | `"first_frame"`, `"last_frame"` | Vai trò của ảnh trong video |
| `url` | string | HTTP/HTTPS public URL | URL ảnh đầu vào (JPEG, PNG, WebP) |

**Quy tắc:**
- **1 item** `"first_frame"` → animate từ 1 ảnh tĩnh.
- **2 items** (`"first_frame"` + `"last_frame"`) → tạo video nối giữa 2 keyframe.
- Thứ tự trong array không quan trọng — `type` xác định vai trò.

#### `parameters`

| Field | Type | Default | Giá trị hợp lệ | Mô tả |
|---|---|---|---|---|
| `resolution` | string | — | `"720P"`, `"1080P"` | Độ phân giải đầu ra (**bắt buộc**) |
| `ratio` | string | `"16:9"` | `"16:9"`, `"9:16"`, `"1:1"`, `"4:3"`, `"3:4"` | Tỷ lệ khung hình |
| `duration` | integer | `5` | `2` – `15` (nguyên) | Thời lượng video (giây) |
| `prompt_extend` | boolean | `false` | `true`, `false` | AI tự mở rộng và tối ưu prompt |
| `watermark` | boolean | `false` | `true`, `false` | Thêm watermark Wan vào video |
| `negative_prompt` | string | `""` | Văn bản bất kỳ | Những gì cần tránh trong video |
| `seed` | integer | random | Số nguyên bất kỳ | Đặt để tái tạo kết quả |

**`resolution` × `ratio` → Kích thước đầu ra:**

| `resolution` | `ratio` | Kích thước |
|---|---|---|
| `1080P` | `16:9` | 1920 × 1080 |
| `1080P` | `9:16` | 1080 × 1920 |
| `1080P` | `1:1` | 1080 × 1080 |
| `720P` | `16:9` | 1280 × 720 |
| `720P` | `9:16` | 720 × 1280 |
| `720P` | `1:1` | 720 × 720 |

---

### B3. Response Payload

#### Tạo task thành công → `200 OK`

```json
{
  "request_id": "abc123-...",
  "output": {
    "task_id": "966cebcd-dedc-4962-af88-xxxxxx",
    "task_status": "PENDING"
  }
}
```

#### Query task — SUCCEEDED

```json
{
  "request_id": "abc123-...",
  "output": {
    "task_id": "966cebcd-dedc-4962-af88-xxxxxx",
    "task_status": "SUCCEEDED",
    "video_url": "https://dashscope-result-sh.oss-accelerate.aliyuncs.com/xxx.mp4?Expires=xxx",
    "orig_prompt": "Prompt gốc bạn gửi lên",
    "prompt": "Prompt đã được AI mở rộng (khi prompt_extend=true)"
  },
  "usage": {
    "video_duration": 10,
    "video_count": 1
  }
}
```

| Field | Type | Mô tả |
|---|---|---|
| `output.video_url` | string | URL tải file MP4. **Hết hạn sau 24h.** |
| `output.orig_prompt` | string | Prompt gốc bạn gửi |
| `output.prompt` | string | Prompt đã được AI mở rộng (chỉ khi `prompt_extend=true`) |
| `usage.video_duration` | integer | Thời lượng video đã tạo (giây) |
| `usage.video_count` | integer | Số video đã tạo (luôn là `1`) |

#### Query task — FAILED

```json
{
  "request_id": "abc123-...",
  "output": {
    "task_id": "966cebcd-dedc-4962-af88-xxxxxx",
    "task_status": "FAILED",
    "code": "InternalError.Algo",
    "message": "The model failed to generate a video. Please retry."
  }
}
```

---

### B4. Use Cases & Examples

#### B4.1 Animate từ 1 ảnh (First Frame)

```bash
# Step 1: Tạo task
curl --location 'https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/video-generation/video-synthesis' \
  -H 'X-DashScope-Async: enable' \
  -H 'Authorization: Bearer sk-ws-H.YPIIIM.RIwn.MEUCIE2UwNogT7QBvBpHt_g2p-WmtN1iR1SAeUwaq4vu2wASAiEA6g_hNFO8IL0l1L2l-opuqWxlASTuEvJPTYvo4mt9so0' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "wan2.7-i2v",
    "input": {
      "prompt": "The camera slowly moves up from below the sea turtle. The turtle swims leisurely.",
      "media": [
        { "type": "first_frame", "url": "https://example.com/turtle.webp" }
      ]
    },
    "parameters": {
      "resolution": "1080P",
      "ratio": "16:9",
      "duration": 10,
      "prompt_extend": true
    }
  }'

# Step 2: Poll kết quả
curl -X GET 'https://dashscope-intl.aliyuncs.com/api/v1/tasks/{task_id}' \
  -H 'Authorization: Bearer sk-ws-H.YPIIIM.RIwn.MEUCIE2UwNogT7QBvBpHt_g2p-WmtN1iR1SAeUwaq4vu2wASAiEA6g_hNFO8IL0l1L2l-opuqWxlASTuEvJPTYvo4mt9so0'
```

---

#### B4.2 Animate giữa 2 ảnh (First + Last Frame)

```bash
curl --location 'https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/video-generation/video-synthesis' \
  -H 'X-DashScope-Async: enable' \
  -H 'Authorization: Bearer sk-ws-H.YPIIIM.RIwn.MEUCIE2UwNogT7QBvBpHt_g2p-WmtN1iR1SAeUwaq4vu2wASAiEA6g_hNFO8IL0l1L2l-opuqWxlASTuEvJPTYvo4mt9so0' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "wan2.7-i2v",
    "input": {
      "prompt": "A dancer gracefully moves across the stage from left to right.",
      "media": [
        { "type": "first_frame", "url": "https://example.com/pose-start.jpg" },
        { "type": "last_frame",  "url": "https://example.com/pose-end.jpg" }
      ]
    },
    "parameters": {
      "resolution": "1080P",
      "ratio": "16:9",
      "duration": 8,
      "prompt_extend": true
    }
  }'
```

---

#### B4.3 Với Custom Audio

```bash
curl --location 'https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/video-generation/video-synthesis' \
  -H 'X-DashScope-Async: enable' \
  -H 'Authorization: Bearer sk-ws-H.YPIIIM.RIwn.MEUCIE2UwNogT7QBvBpHt_g2p-WmtN1iR1SAeUwaq4vu2wASAiEA6g_hNFO8IL0l1L2l-opuqWxlASTuEvJPTYvo4mt9so0' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "wan2.7-i2v",
    "input": {
      "prompt": "A news anchor looks at the camera and speaks clearly.",
      "media": [
        { "type": "first_frame", "url": "https://example.com/anchor.jpg" }
      ],
      "audio_url": "https://example.com/narration.mp3"
    },
    "parameters": {
      "resolution": "1080P",
      "ratio": "16:9",
      "duration": 15,
      "prompt_extend": false
    }
  }'
```

> Bỏ `audio_url` để model tự tạo nhạc nền và hiệu ứng âm thanh.  
> Một file audio duy nhất / request. Phải là URL HTTP/HTTPS công khai.

---

## 4. Error Handling

| HTTP Status | Meaning |
|---|---|
| `200` | Request thành công |
| `400` | Request không hợp lệ — kiểm tra lại payload và tham số |
| `401` | Unauthorized — API key không hợp lệ hoặc thiếu |
| `429` | Rate limit — giảm tốc độ gửi request |
| `500` | Server error — retry với exponential backoff |

**`task_status: "FAILED"` codes (Part B - Video):**

| Code | Nguyên nhân | Cách xử lý |
|---|---|---|
| `InternalError.Algo` | Model thất bại | Retry request |
| `InvalidParameter` | Giá trị tham số sai | Kiểm tra `resolution`, `ratio`, `duration` |
| `InvalidMedia` | URL ảnh không truy cập được hoặc sai định dạng | Dùng URL HTTP/HTTPS công khai; định dạng: JPEG, PNG, WEBP |
| `ContentModerated` | Prompt hoặc ảnh vi phạm chính sách nội dung | Chỉnh sửa prompt hoặc ảnh đầu vào |
| `Throttling` | Rate limit | Back off và retry |

**Error codes (Part A - Image):**

| Code | Nguyên nhân | Cách xử lý |
|---|---|---|
| `InvalidParameter` | Giá trị tham số sai | Kiểm tra `size`, `n` |
| `DataInspectionFailed` | Prompt hoặc ảnh vi phạm chính sách | Chỉnh sửa prompt hoặc ảnh |
| `Throttling` | Rate limit | Back off và retry |

Full error reference: https://docs.qwencloud.com/api-reference/preparation/error-messages.md