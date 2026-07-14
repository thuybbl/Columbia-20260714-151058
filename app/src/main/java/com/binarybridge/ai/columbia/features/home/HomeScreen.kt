package com.binarybridge.ai.columbia.features.home

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.binarybridge.ai.columbia.R
import com.binarybridge.ai.columbia.ads.AdsPlacementHolder
import com.binarybridge.ai.columbia.ads.AdsPolicy
import com.binarybridge.ai.columbia.core.SettingManager
import com.binarybridge.ai.columbia.ui.components.ads.AdBanner
import com.binarybridge.ai.columbia.ui.components.ads.NativeAdDialog
import com.binarybridge.ai.columbia.ui.components.ads.NativeAdFrame
import com.binarybridge.ai.columbia.ui.components.ads.NativeAdOverlay
import com.google.android.gms.ads.MobileAds
import androidx.compose.runtime.collectAsState

@Composable
fun HomeScreen() {
    val activity = LocalActivity.current as Activity

    var showNativeFull by remember { mutableStateOf(false) }

    fun showInter(action: () -> Unit = {}) {
        AdsPolicy.showInterAd(
            activity,
            AdsPlacementHolder.INTER_HOME,
            action
        )
    }

    BackHandler(enabled = showNativeFull) {
        showNativeFull = false
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "isFirstTime: ${SettingManager.isFirstTime.collectAsState().value}",
                fontSize = 16.sp,
                color = Color.Black,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = """
                    AdsPolicy là nơi viết logic ads theo kịch bản (mode từ Remote Config, nhịp show inter, preload ad tiếp theo…).
                    Với inter_home, khi bấm "Show Inter Ad" với force = false thì sẽ áp dụng kịch bản gần đây nhất được thiết kế:
                    • Lần đầu mở app (isFirstTime = true): chỉ show nếu đã qua 30 giây kể từ inter trước (ví dụ sau inter splash). Nếu chưa đủ 30s thì bỏ qua.
                    • Từ lần mở app thứ 2 trở đi (isFirstTime = false): lần bấm lẻ (1, 3, 5…) bỏ qua; lần bấm chẵn (2, 4, 6…) mới show inter.
                    
                    Liên hệ Nguyễn Văn Trường nếu cần hướng dẫn sử dụng.
                """.trimIndent(),
                fontSize = 14.sp,
                color = Color(0xFF424242),
                textAlign = TextAlign.Start,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(16.dp))
            Button(onClick = { showInter() }) {
                Text("Show Inter Ad")
            }
            Spacer(Modifier.height(12.dp))
            Button(onClick = { showNativeFull = true }) {
                Text("Show Native Full")
            }
            Spacer(Modifier.height(16.dp))

            NativeAdFrame(
                modifier = Modifier.fillMaxWidth(),
                adPlacement = AdsPlacementHolder.NATIVE_HOME,
                reloadIntervalMs = 15_000L,
            )

            Spacer(Modifier.height(24.dp))
        }

        AdBanner(
            modifier = Modifier.align(Alignment.BottomCenter),
            placement = AdsPlacementHolder.BANNER_HOME,
            showDelayMs = 400L,
        )
        NativeAdDialog(modifier = Modifier.align(Alignment.BottomCenter))

        if (showNativeFull) {
            NativeAdOverlay(
                layoutResId = R.layout.frame_ad_full,
                closeDelaySeconds = 0,
                onClose = { showNativeFull = false },
            ) { container, shimmer ->
                AdsPolicy.bindNativeAd(
                    activity = activity,
                    adPlacement = AdsPlacementHolder.NATIVE_ALL,
                    container = container,
                    shimmer = shimmer,
                    onAdFailed = { showNativeFull = false },
                    templateAdLayoutRes = R.layout.template_ad_full,
                )
            }
        }
    }

    LaunchedEffect(showNativeFull) {
        AdsPolicy.allowShowWelcomeBack = !showNativeFull
    }
    DisposableEffect(Unit) {
        onDispose {
            AdsPolicy.allowShowWelcomeBack = true
        }
    }

//    DisableWelcomeOverlayTemporarily()
}

@Composable
fun DisableWelcomeOverlayTemporarily() {
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                AdsPolicy.allowShowWelcomeBack = false
            }
            if (event == Lifecycle.Event.ON_PAUSE || event == Lifecycle.Event.ON_STOP) {
                AdsPolicy.allowShowWelcomeBack = true
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            AdsPolicy.allowShowWelcomeBack = true
        }
    }
}
