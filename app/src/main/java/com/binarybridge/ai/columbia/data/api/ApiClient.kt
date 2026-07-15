package com.binarybridge.ai.columbia.data.api

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

/**
 * Cấu hình API Qwen Cloud Wan 2.7.
 * CẢNH BÁO: key nhúng client-side → lộ trong APK. Chấp nhận cho MVP; production phải proxy qua backend.
 */
object ApiConfig {
    const val BASE_URL = "https://dashscope-intl.aliyuncs.com/api/v1"
    const val API_KEY = "sk-ws-H.YPIIIM.RIwn.MEUCIE2UwNogT7QBvBpHt_g2p-WmtN1iR1SAeUwaq4vu2wASAiEA6g_hNFO8IL0l1L2l-opuqWxlASTuEvJPTYvo4mt9so0"

    const val ENDPOINT_IMAGE = "/services/aigc/multimodal-generation/generation"
    const val ENDPOINT_VIDEO = "/services/aigc/video-generation/video-synthesis"
    const val TASKS = "/tasks"
}

/** HTTP thô bằng HttpURLConnection (không thêm lib mạng). Mọi hàm chạy trên IO, fail-open trả null. */
object ApiClient {
    private const val TAG = "ColumbiaApi"
    private const val CONNECT_TIMEOUT = 30_000
    private const val READ_TIMEOUT = 60_000

    /** POST JSON, trả body text hoặc null nếu lỗi. */
    suspend fun postJson(
        url: String,
        body: JsonObject,
        extraHeaders: Map<String, String> = emptyMap(),
    ): String? = withContext(Dispatchers.IO) {
        var conn: HttpURLConnection? = null
        try {
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = CONNECT_TIMEOUT
                readTimeout = READ_TIMEOUT
                doOutput = true
                setRequestProperty("Authorization", "Bearer ${ApiConfig.API_KEY}")
                setRequestProperty("Content-Type", "application/json")
                extraHeaders.forEach { (k, v) -> setRequestProperty(k, v) }
            }
            conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            readResponse(conn)
        } catch (e: Exception) {
            Log.e(TAG, "postJson error: ${e.message}")
            null
        } finally {
            conn?.disconnect()
        }
    }

    /** GET JSON, trả body text hoặc null. */
    suspend fun getJson(
        url: String,
        extraHeaders: Map<String, String> = emptyMap(),
    ): String? = withContext(Dispatchers.IO) {
        var conn: HttpURLConnection? = null
        try {
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = CONNECT_TIMEOUT
                readTimeout = READ_TIMEOUT
                setRequestProperty("Authorization", "Bearer ${ApiConfig.API_KEY}")
                extraHeaders.forEach { (k, v) -> setRequestProperty(k, v) }
            }
            readResponse(conn)
        } catch (e: Exception) {
            Log.e(TAG, "getJson error: ${e.message}")
            null
        } finally {
            conn?.disconnect()
        }
    }

    /** Tải file (mp4/ảnh) về [dest]. Trả true nếu thành công. */
    suspend fun downloadTo(url: String, dest: File): Boolean = withContext(Dispatchers.IO) {
        var conn: HttpURLConnection? = null
        try {
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = CONNECT_TIMEOUT
                readTimeout = READ_TIMEOUT
            }
            conn.inputStream.use { input ->
                FileOutputStream(dest).use { out -> input.copyTo(out) }
            }
            dest.exists() && dest.length() > 0
        } catch (e: Exception) {
            Log.e(TAG, "downloadTo error: ${e.message}")
            false
        } finally {
            conn?.disconnect()
        }
    }

    private fun readResponse(conn: HttpURLConnection): String {
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.let { BufferedReader(InputStreamReader(it, Charsets.UTF_8)).use { r -> r.readText() } } ?: ""
        if (code !in 200..299) Log.e(TAG, "HTTP $code: $text")
        return text
    }
}
