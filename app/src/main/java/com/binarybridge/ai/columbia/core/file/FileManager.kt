package com.binarybridge.ai.columbia.core.file

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/** Quản lý file mp4 / thumbnail trong filesDir + lưu về gallery + base64 hoá ảnh input. */
object FileManager {
    private const val TAG = "ColumbiaFile"
    private lateinit var appContext: Context

    fun init(context: Context) { appContext = context.applicationContext }

    private fun videosDir(): File =
        File(appContext.filesDir, "creations").apply { if (!exists()) mkdirs() }

    fun videoFile(id: String) = File(videosDir(), "$id.mp4")
    fun thumbFile(id: String) = File(videosDir(), "$id.jpg")

    /** Đọc ảnh từ [uri] → data URI base64 (cho API). Trả null nếu lỗi. */
    suspend fun uriToBase64DataUri(uri: Uri): String? = withContext(Dispatchers.IO) {
        try {
            val bytes = appContext.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: return@withContext null
            val mime = appContext.contentResolver.getType(uri) ?: "image/jpeg"
            val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
            "data:$mime;base64,$b64"
        } catch (e: Exception) {
            Log.e(TAG, "uriToBase64DataUri: ${e.message}"); null
        }
    }

    /** Sinh thumbnail (frame đầu) từ file video, lưu jpg. Trả path hoặc "". */
    suspend fun extractThumbnail(videoFile: File, id: String): String = withContext(Dispatchers.IO) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(videoFile.absolutePath)
            val bmp: Bitmap = retriever.getFrameAtTime(0) ?: return@withContext ""
            val out = thumbFile(id)
            FileOutputStream(out).use { bmp.compress(Bitmap.CompressFormat.JPEG, 85, it) }
            bmp.recycle()
            out.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "extractThumbnail: ${e.message}"); ""
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }
    }

    /** Lưu 1 file mp4 (đã tải về filesDir) ra thư viện Movies. Trả true nếu OK. */
    suspend fun saveVideoToGallery(videoFile: File, displayName: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val resolver = appContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, "$displayName.mp4")
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/Columbia")
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
            }
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            else MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            val item = resolver.insert(collection, values) ?: return@withContext false
            resolver.openOutputStream(item)?.use { out -> videoFile.inputStream().use { it.copyTo(out) } }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear(); values.put(MediaStore.Video.Media.IS_PENDING, 0)
                resolver.update(item, values, null, null)
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "saveVideoToGallery: ${e.message}"); false
        }
    }
}
