package com.binarybridge.ai.columbia.features.onboarding

import android.app.Activity
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.binarybridge.ai.columbia.ads.AdsLoader
import com.binarybridge.ai.columbia.ads.AdsPlacementHolder
import com.binarybridge.ai.columbia.ads.AdsPolicy
import com.binarybridge.ai.columbia.ui.components.ads.AdBanner
import com.binarybridge.ai.columbia.R
import kotlinx.coroutines.delay

private const val LOADING_PROGRESS_ANIMATION_MS = 1200L

@Composable
fun SplashScreen(onNext: () -> Unit = {}) {
    val activity = LocalActivity.current as Activity

    val ready by AdsLoader.finished.collectAsState()
    var progressComplete by remember { mutableStateOf(false) }

    LaunchedEffect(ready) {
        if (!ready) return@LaunchedEffect

        progressComplete = true
        delay(LOADING_PROGRESS_ANIMATION_MS + 1500)

        AdsPolicy.showInterAd(
            activity = activity,
            adPlacement = AdsPlacementHolder.INTER_SPLASH,
            force = true,
            onContinue = onNext
        )
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .navigationBarsPadding()
    ) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(R.drawable.placeholder_background)
                .size(coil.size.Size.ORIGINAL)
                .build(),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )

        Box(Modifier.fillMaxSize().statusBarsPadding()) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 128.dp)
                    .padding(horizontal = 32.dp)
            ) {
                AppLoadingProgressBar(progressComplete)
            }

            if (ready) {
                AdBanner(
                    modifier = Modifier.align(Alignment.BottomCenter),
                    placement = AdsPlacementHolder.BANNER_SPLASH
                )
            }
        }
    }
}

@Composable
fun CustomLoadingProgressBar(
    value: Int,
    modifier: Modifier = Modifier,
    height: Dp = 12.dp,
) {
    val shape = remember { RoundedCornerShape(percent = 50) }
    val progress = (value.coerceIn(0, 100)) / 100f

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .clip(shape)
            .background(Color(0xFFE0E0E0))
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth(progress)
                .clip(shape)
                .background(
                    brush = Brush.horizontalGradient(
                        colors = listOf(Color(0xFF1E88E5), Color(0xFF00BCD4))
                    )
                )
        )
    }
}

@Composable
fun AppLoadingProgressBar(
    isDone: Boolean,
    modifier: Modifier = Modifier
) {
    val target = remember { (60..85).random() }

    var current by remember { mutableFloatStateOf(0f) }

    LaunchedEffect(isDone) {
        val start = current
        val end = if (isDone) 100f else target.toFloat()

        val steps = 60
        val stepDelay = LOADING_PROGRESS_ANIMATION_MS / steps

        for (i in 1..steps) {
            val t = i / steps.toFloat()
            current = start + (end - start) * t
            delay(stepDelay)
        }

        current = end
    }

    CustomLoadingProgressBar(
        value = current.toInt(),
        modifier = modifier
    )
}
