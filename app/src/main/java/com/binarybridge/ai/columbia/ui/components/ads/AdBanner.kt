package com.binarybridge.ai.columbia.ui.components.ads

import android.view.LayoutInflater
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.binarybridge.ai.columbia.ads.AdsLoader
import com.binarybridge.ai.columbia.ads.AdsPolicy
import com.binarybridge.ai.columbia.R
import kotlinx.coroutines.delay

@Composable
fun AdBanner(
    modifier: Modifier = Modifier,
    placement: String,
    showDelayMs: Long = 0L,
) {
    val activity = LocalActivity.current ?: return

    var visible by rememberSaveable { mutableStateOf(true) }
    var isReadyToShow by rememberSaveable(showDelayMs) { mutableStateOf(showDelayMs <= 0L) }
    var boundPlacement by remember { mutableStateOf<String?>(null) }
    var shouldReloadOnResume by remember { mutableStateOf(false) }

    val isActive by AdsLoader.isActive.collectAsState()
    val placementState by rememberUpdatedState(placement)
    val visibleState by rememberUpdatedState(visible)
    val isActiveState by rememberUpdatedState(isActive)
    val isReadyToShowState by rememberUpdatedState(isReadyToShow)

    LaunchedEffect(showDelayMs) {
        if (showDelayMs <= 0L) {
            isReadyToShow = true
            return@LaunchedEffect
        }
        isReadyToShow = false
        delay(showDelayMs)
        isReadyToShow = true
    }

    fun bindBanner() {
        boundPlacement = placementState
        AdsPolicy.bindBannerAd(
            activity = activity,
            adPlacement = placementState,
            onAdFailed = {
                visible = false
            }
        )
    }

    if (visible && isActive && isReadyToShow) AndroidView(
        modifier = modifier.fillMaxWidth(),
        factory = { context ->
            LayoutInflater.from(context).inflate(R.layout.banner_ad, null)
        },
        update = {
            if (boundPlacement != placementState) bindBanner()
        }
    )

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_PAUSE -> shouldReloadOnResume = true
                Lifecycle.Event.ON_RESUME -> {
                    if (shouldReloadOnResume && visibleState && isActiveState && isReadyToShowState) {
                        shouldReloadOnResume = false
                        bindBanner()
                    }
                }
                else -> Unit
            }
        }

        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }
}
