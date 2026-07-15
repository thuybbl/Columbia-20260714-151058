package com.binarybridge.ai.columbia.core

import android.app.Activity
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.yalantis.ucrop.UCrop
import java.io.File

/** Tuỳ chọn uCrop theo ngôn ngữ thiết kế Columbia (tối + tím). */
private fun columbiaUCropOptions(): UCrop.Options = UCrop.Options().apply {
    setToolbarTitle("Crop")
    setStatusBarColor(0xFF0A0712.toInt())
    setToolbarColor(0xFF16111F.toInt())
    setRootViewBackgroundColor(0xFF0A0712.toInt())
    setToolbarWidgetColor(0xFFF6F3FC.toInt())        // tiêu đề + nút back + nút Done (✓)
    setActiveControlsWidgetColor(0xFF8B5CF6.toInt()) // tab/điều khiển đang chọn
    setLogoColor(0xFF8B5CF6.toInt())
    setCropFrameColor(0xFFA87CFF.toInt())
    setCropGridColor(0x33FFFFFF)
    setFreeStyleCropEnabled(true)
    setShowCropGrid(true)
}

/**
 * Trả về hàm `launch()` mở luồng crop: Photo Picker (không cần quyền) → uCrop (themed) → [onCropped] với Uri ảnh đã crop.
 * Dùng chung cho ImagePickScreen & GenerationScreen (một nguồn duy nhất, tránh lệch cấu hình).
 */
@Composable
fun rememberCropFlow(onCropped: (Uri) -> Unit): () -> Unit {
    val context = LocalContext.current

    val ucropLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            result.data?.let { UCrop.getOutput(it) }?.let(onCropped)
        }
    }

    val pickLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            val dest = Uri.fromFile(File(context.cacheDir, "crop_${System.currentTimeMillis()}.jpg"))
            val intent = UCrop.of(uri, dest)
                .withOptions(columbiaUCropOptions())
                .getIntent(context)
            ucropLauncher.launch(intent)
        }
    }

    return remember {
        { pickLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
    }
}
