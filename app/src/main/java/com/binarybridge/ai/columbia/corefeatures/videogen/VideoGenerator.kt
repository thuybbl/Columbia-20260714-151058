package com.binarybridge.ai.columbia.corefeatures.videogen

import com.binarybridge.ai.columbia.core.file.FileManager
import com.binarybridge.ai.columbia.data.api.ApiRepo
import com.binarybridge.ai.columbia.data.api.VideoResult
import com.binarybridge.ai.columbia.data.domain.Creation
import com.binarybridge.ai.columbia.data.domain.GenMode
import com.binarybridge.ai.columbia.data.domain.Resolution
import com.binarybridge.ai.columbia.data.json.CreationRepo
import kotlinx.coroutines.delay
import java.util.UUID

sealed class GenOutcome {
    data class Done(val creation: Creation) : GenOutcome()
    data class Error(val message: String) : GenOutcome()
}

/**
 * Điều phối sinh video:
 *  - IMAGE: ảnh base64 → i2v
 *  - TEXT : text → Part A (ảnh) → i2v  (không có model text→video trực tiếp)
 * Rồi poll tới SUCCEEDED, tải mp4 + thumbnail về local, tạo Creation.
 */
object VideoGenerator {
    private const val POLL_TIMEOUT_MS = 5 * 60 * 1000L

    suspend fun generate(
        mode: GenMode,
        prompt: String,
        imageDataUri: String?,
        resolution: Resolution,
        ratio: String,
        durationSec: Int,
        onStage: (String) -> Unit,
    ): GenOutcome {
        val effectivePrompt = prompt.ifBlank { "Bring this to life with natural, cinematic motion" }

        // 1) Xác định first-frame
        val firstFrame: String = when (mode) {
            GenMode.IMAGE -> imageDataUri
                ?: return GenOutcome.Error("No image selected.")
            GenMode.TEXT -> {
                onStage("Painting the first frame…")
                ApiRepo.textToImage(effectivePrompt, ratio)
                    ?: return GenOutcome.Error("Couldn't create the image. Please try again.")
            }
        }

        // 2) Tạo task video
        onStage("Submitting your video…")
        val taskId = ApiRepo.createVideoTask(firstFrame, effectivePrompt, resolution.api, ratio, durationSec)
            ?: return GenOutcome.Error("Couldn't start generation. Please try again.")

        // 3) Poll
        onStage("Creating your video…")
        val start = System.currentTimeMillis()
        var attempt = 0
        while (System.currentTimeMillis() - start < POLL_TIMEOUT_MS) {
            delay(if (attempt < 10) 3_000L else 5_000L)
            attempt++
            when (val r = ApiRepo.pollVideo(taskId)) {
                is VideoResult.Success -> return finalize(r.videoUrl, effectivePrompt, mode, resolution, ratio, durationSec, onStage)
                is VideoResult.Failed -> return GenOutcome.Error(mapError(r.code, r.message))
                is VideoResult.Pending -> { /* keep polling */ }
            }
        }
        return GenOutcome.Error("Generation timed out. Please try again.")
    }

    private suspend fun finalize(
        videoUrl: String,
        prompt: String,
        mode: GenMode,
        resolution: Resolution,
        ratio: String,
        durationSec: Int,
        onStage: (String) -> Unit,
    ): GenOutcome {
        onStage("Downloading…")
        val id = UUID.randomUUID().toString()
        val file = FileManager.videoFile(id)
        val ok = com.binarybridge.ai.columbia.data.api.ApiClient.downloadTo(videoUrl, file)
        if (!ok) return GenOutcome.Error("Downloaded video failed. The link may have expired.")
        val thumb = FileManager.extractThumbnail(file, id)
        val creation = Creation(
            id = id,
            prompt = prompt,
            mode = mode.name,
            videoPath = file.absolutePath,
            thumbPath = thumb,
            resolution = resolution.api,
            ratio = ratio,
            durationSec = durationSec,
            createdAt = System.currentTimeMillis(),
        )
        CreationRepo.add(creation)
        return GenOutcome.Done(creation)
    }

    private fun mapError(code: String, message: String): String = when {
        code.contains("ContentModerated", true) || code.contains("DataInspection", true) ->
            "Your prompt or image didn't pass content rules. Try adjusting it."
        code.contains("InvalidMedia", true) ->
            "That image couldn't be used. Try another photo."
        code.contains("Throttling", true) ->
            "Servers are busy. Please try again in a moment."
        else -> message.ifBlank { "Generation failed. Please try again." }
    }
}
