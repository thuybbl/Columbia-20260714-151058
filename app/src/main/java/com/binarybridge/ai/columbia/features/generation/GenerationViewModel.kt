package com.binarybridge.ai.columbia.features.generation

import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.binarybridge.ai.columbia.core.SettingManager
import com.binarybridge.ai.columbia.core.file.FileManager
import com.binarybridge.ai.columbia.corefeatures.videogen.GenOutcome
import com.binarybridge.ai.columbia.corefeatures.videogen.VideoGenerator
import com.binarybridge.ai.columbia.data.domain.GenMode
import com.binarybridge.ai.columbia.data.domain.Resolution
import kotlinx.coroutines.launch

class GenerationViewModel : ViewModel() {

    var mode by mutableStateOf(GenMode.TEXT); private set
    var prompt by mutableStateOf("")
    var resolution by mutableStateOf(Resolution.R720); private set
    var ratio by mutableStateOf("9:16"); private set
    var durationSec by mutableStateOf(8); private set
    var imageUri by mutableStateOf<Uri?>(null); private set

    var generating by mutableStateOf(false); private set
    var stage by mutableStateOf(""); private set
    var error by mutableStateOf<String?>(null)
    var notEnoughCredits by mutableStateOf(false)
    var resultId by mutableStateOf<String?>(null)

    fun initMode(m: GenMode, initialPrompt: String, image: Uri?) {
        mode = m
        if (prompt.isEmpty()) prompt = initialPrompt
        if (image != null) imageUri = image
    }

    fun updateMode(m: GenMode) { mode = m }
    fun updateResolution(r: Resolution) { resolution = r }
    fun updateRatio(r: String) { ratio = r }
    fun updateDuration(d: Int) { durationSec = d.coerceIn(2, 15) }
    fun updateImage(uri: Uri?) { imageUri = uri }

    fun cost(): Int = resolution.baseCost + maxOf(0, durationSec - 5) * 2

    fun generate() {
        if (generating) return
        if (mode == GenMode.IMAGE && imageUri == null) {
            error = "Please choose an image first."
            return
        }
        val price = cost()
        if (!SettingManager.spendCredits(price)) {
            notEnoughCredits = true
            return
        }
        generating = true
        stage = "Preparing…"
        viewModelScope.launch {
            val dataUri = if (mode == GenMode.IMAGE) FileManager.uriToBase64DataUri(imageUri!!) else null
            if (mode == GenMode.IMAGE && dataUri == null) {
                SettingManager.refundCredits(price)
                generating = false
                error = "Couldn't read that image. Try another."
                return@launch
            }
            val outcome = VideoGenerator.generate(
                mode = mode,
                prompt = prompt,
                imageDataUri = dataUri,
                resolution = resolution,
                ratio = ratio,
                durationSec = durationSec,
                onStage = { stage = it },
            )
            generating = false
            when (outcome) {
                is GenOutcome.Done -> resultId = outcome.creation.id
                is GenOutcome.Error -> {
                    SettingManager.refundCredits(price)
                    error = outcome.message
                }
            }
        }
    }
}
