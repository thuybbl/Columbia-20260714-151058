package com.binarybridge.ai.columbia.data.api

import android.util.Log
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.add
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject

/** Trạng thái poll video. */
sealed class VideoResult {
    data class Pending(val status: String) : VideoResult()
    data class Success(val videoUrl: String) : VideoResult()
    data class Failed(val code: String, val message: String) : VideoResult()
}

/**
 * Wrap ApiClient thành 2 thao tác nghiệp vụ (Qwen image + Wan i2v).
 * ✅ media[].url nhận base64 data URI (đã kiểm chứng) → ảnh local đưa thẳng, không cần host.
 */
object ApiRepo {
    private const val TAG = "ColumbiaApiRepo"
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private fun sizeForRatio(ratio: String): String = when (ratio) {
        "16:9" -> "2048*1152"
        "9:16" -> "1152*2048"
        "1:1" -> "2048*2048"
        "4:3" -> "1920*1440"
        "3:4" -> "1440*1920"
        else -> "1152*2048"
    }

    /** Part A: text → ảnh. Trả URL ảnh public (24h) hoặc null. */
    suspend fun textToImage(prompt: String, ratio: String): String? {
        val body = buildJsonObject {
            put("model", "qwen-image-2.0")
            putJsonObject("input") {
                putJsonArray("messages") {
                    addJsonObject {
                        put("role", "user")
                        putJsonArray("content") {
                            addJsonObject { put("text", prompt) }
                        }
                    }
                }
            }
            putJsonObject("parameters") {
                put("size", sizeForRatio(ratio))
                put("n", 1)
                put("prompt_extend", true)
                put("watermark", false)
            }
        }
        val resp = ApiClient.postJson(ApiConfig.BASE_URL + ApiConfig.ENDPOINT_IMAGE, body) ?: return null
        return try {
            val root = json.parseToJsonElement(resp).jsonObject
            root["output"]?.jsonObject
                ?.get("choices")?.jsonArray?.firstOrNull()?.jsonObject
                ?.get("message")?.jsonObject
                ?.get("content")?.jsonArray
                ?.firstOrNull { it.jsonObject["image"] != null }?.jsonObject
                ?.get("image")?.jsonPrimitive?.content
        } catch (e: Exception) {
            Log.e(TAG, "textToImage parse: ${e.message}"); null
        }
    }

    /**
     * Part B: tạo task ảnh→video. [imageRef] = data URI base64 (ảnh local) hoặc URL public.
     * Trả task_id hoặc null.
     */
    suspend fun createVideoTask(
        imageRef: String,
        prompt: String,
        resolutionApi: String,
        ratio: String,
        durationSec: Int,
    ): String? {
        val body = buildJsonObject {
            put("model", "wan2.7-i2v")
            putJsonObject("input") {
                put("prompt", prompt)
                putJsonArray("media") {
                    addJsonObject {
                        put("type", "first_frame")
                        put("url", imageRef)
                    }
                }
            }
            putJsonObject("parameters") {
                put("resolution", resolutionApi)
                put("ratio", ratio)
                put("duration", durationSec)
                put("prompt_extend", true)
                put("watermark", false)
            }
        }
        val resp = ApiClient.postJson(
            ApiConfig.BASE_URL + ApiConfig.ENDPOINT_VIDEO,
            body,
            extraHeaders = mapOf("X-DashScope-Async" to "enable"),
        ) ?: return null
        return try {
            json.parseToJsonElement(resp).jsonObject["output"]?.jsonObject
                ?.get("task_id")?.jsonPrimitive?.content
        } catch (e: Exception) {
            Log.e(TAG, "createVideoTask parse: ${e.message}"); null
        }
    }

    /** Poll 1 lần trạng thái task. */
    suspend fun pollVideo(taskId: String): VideoResult {
        val resp = ApiClient.getJson("${ApiConfig.BASE_URL}${ApiConfig.TASKS}/$taskId")
            ?: return VideoResult.Pending("UNKNOWN")
        return try {
            val out = json.parseToJsonElement(resp).jsonObject["output"]?.jsonObject
                ?: return VideoResult.Pending("UNKNOWN")
            when (val status = out["task_status"]?.jsonPrimitive?.content) {
                "SUCCEEDED" -> {
                    val url = out["video_url"]?.jsonPrimitive?.content
                    if (url.isNullOrBlank()) VideoResult.Failed("NoUrl", "Missing video_url")
                    else VideoResult.Success(url)
                }
                "FAILED" -> VideoResult.Failed(
                    out["code"]?.jsonPrimitive?.content ?: "Unknown",
                    out["message"]?.jsonPrimitive?.content ?: "Generation failed"
                )
                else -> VideoResult.Pending(status ?: "PENDING")
            }
        } catch (e: Exception) {
            Log.e(TAG, "pollVideo parse: ${e.message}")
            VideoResult.Pending("UNKNOWN")
        }
    }
}
