package com.binarybridge.ai.columbia.features.onboarding

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.binarybridge.ai.columbia.R
import com.binarybridge.ai.columbia.ads.AdsLoader
import com.binarybridge.ai.columbia.ads.AdsPlacementHolder
import com.binarybridge.ai.columbia.ads.AdsPolicy
import com.binarybridge.ai.columbia.ui.components.ads.NativeAdFrame
import com.binarybridge.ai.columbia.ui.components.ads.NativeAdOverlay
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Pages that trigger a native-full overlay when the user taps "Next"
private val PAGES_WITH_NATIVE_FULL = setOf(0, 1)

@Composable
fun OnboardingScreen(onNext: () -> Unit = {}) {
    val pageCount = 3
    val pagerState = rememberPagerState(initialPage = 0, pageCount = { pageCount })
    val scope = rememberCoroutineScope()
    val activity = LocalActivity.current ?: return
    var showNativeFull by remember { mutableStateOf(false) }
    val isAdActive by AdsLoader.isActive.collectAsState()

    LaunchedEffect(showNativeFull, pagerState.settledPage) {
        val blockWelcome = showNativeFull || pagerState.settledPage in setOf(0, 1)
        AdsPolicy.allowShowWelcomeBack = !blockWelcome
    }
    DisposableEffect(Unit) {
        onDispose { AdsPolicy.allowShowWelcomeBack = true }
    }

    fun navigateToNextReal() {
        showNativeFull = false
        scope.launch {
            delay(200)
            val nextPage = pagerState.currentPage + 1
            if (nextPage < pagerState.pageCount) {
                pagerState.animateScrollToPage(nextPage)
            } else {
                onNext()
            }
        }
    }

    fun navigateToNext() {
        if (isAdActive && pagerState.currentPage in PAGES_WITH_NATIVE_FULL) {
            showNativeFull = true
        } else {
            navigateToNextReal()
        }
    }

    BackHandler {
        if (showNativeFull) {
            showNativeFull = false
        } else {
            scope.launch {
                pagerState.animateScrollToPage(
                    (pagerState.currentPage - 1).coerceIn(0, pagerState.pageCount - 1)
                )
            }
        }
    }

    Box(Modifier.fillMaxSize()) {
        HorizontalPager(
            state = pagerState,
            userScrollEnabled = false,
            beyondViewportPageCount = 1,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            val isInViewport = pagerState.settledPage == page
            when (page) {
                0 -> OnboardingPage(
                    adPlacement = AdsPlacementHolder.NATIVE_ONB1,
                    isInViewport = isInViewport,
                    onNext = { navigateToNext() }
                )
                1 -> OnboardingPage(
                    adPlacement = AdsPlacementHolder.NATIVE_ONB1,
                    isInViewport = isInViewport,
                    onNext = { navigateToNext() }
                )
                2 -> OnboardingPage(
                    adPlacement = null,
                    isInViewport = isInViewport,
                    onNext = { navigateToNextReal() }
                )
            }
        }

        if (showNativeFull) {
            val placement = when (pagerState.currentPage) {
                0 -> AdsPlacementHolder.NATIVE_FULL1
                else -> AdsPlacementHolder.NATIVE_FULL2
            }
            NativeAdOverlay(
                layoutResId = R.layout.frame_ad_full,
                closeDelaySeconds = 0,
                onClose = { navigateToNextReal() }
            ) { container, shimmer ->
                AdsPolicy.bindNativeAd(
                    activity = activity as Activity,
                    adPlacement = placement,
                    container = container,
                    shimmer = shimmer,
                    templateAdLayoutRes = R.layout.template_ad_full,
                    onAdFailed = { navigateToNextReal() }
                )
            }
        }
    }
}

/**
 * Sample onboarding page template.
 *
 * Swap [R.drawable.placeholder_background] for the actual artwork and add title /
 * body copy above the button as needed for each page.
 *
 * @param adPlacement  Native-ad placement rendered at the very bottom, or
 *                     `null` to hide the ad slot on this page.
 * @param isInViewport Pass `pagerState.settledPage == page` so the native ad
 *                     only binds while this page is fully settled in view.
 * @param onNext       Called when the user taps the "Next" button.
 */
@Composable
fun OnboardingPage(
    adPlacement: String? = null,
    isInViewport: Boolean = true,
    onNext: () -> Unit = {}
) {
    Box(modifier = Modifier.fillMaxSize()) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(R.drawable.placeholder_background)
                .size(coil.size.Size.ORIGINAL)
                .build(),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
        ) {
            Spacer(Modifier.weight(1f))

            Column(
                modifier = Modifier.padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                OnboardingNextButton(onClick = onNext)
                Spacer(Modifier.height(16.dp))
            }

            if (adPlacement != null && isInViewport) {
                NativeAdFrame(
                    adPlacement = adPlacement,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

@Composable
private fun OnboardingNextButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val buttonShape = remember { RoundedCornerShape(50) }
    val gradient = Brush.horizontalGradient(
        colors = listOf(Color(0xFF1565C0), Color(0xFF1E88E5))
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(buttonShape)
            .background(gradient)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = stringResource(R.string.next),
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.5.sp
        )
    }
}
