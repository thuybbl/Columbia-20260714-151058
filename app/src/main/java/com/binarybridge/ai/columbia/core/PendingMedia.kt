package com.binarybridge.ai.columbia.core

import android.net.Uri

/**
 * Giữ tạm ảnh đã crop + prompt chờ (vd từ effect) để truyền giữa các màn,
 * thay vì nhét binary vào nav route args.
 */
object PendingMedia {
    var croppedImageUri: Uri? = null
    var pendingPrompt: String = ""

    fun clear() {
        croppedImageUri = null
        pendingPrompt = ""
    }
}
