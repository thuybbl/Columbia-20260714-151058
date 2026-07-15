package com.binarybridge.ai.columbia

import androidx.activity.compose.LocalActivity
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.bbl.ads.modules.AdsManager
import com.bbl.ads.modules.consent.ConsentCallback
import com.binarybridge.ai.columbia.core.SettingManager
import com.binarybridge.ai.columbia.features.onboarding.SplashScreen

import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import com.binarybridge.ai.columbia.features.main.MainScreen
import com.binarybridge.ai.columbia.features.language.LanguageScreen
import com.binarybridge.ai.columbia.features.onboarding.OnboardingScreen

private const val ENTER_TIME = 400
private const val EXIT_TIME = 300

// [code_base v2] Các transition tái sử dụng cho flow / màn chức năng.
// Giữ lại như building block; màn demo AppSample của v1 đã được gỡ bỏ.
internal val ZoomTransition = Pair(
    fadeIn(animationSpec = tween(ENTER_TIME)) + scaleIn(initialScale = 1.3f, animationSpec = tween(ENTER_TIME)),
    fadeOut(animationSpec = tween(EXIT_TIME)) + scaleOut(targetScale = 1.3f, animationSpec = tween(EXIT_TIME)),
)

internal val SlideHorizontalTransition = Pair(
    slideInHorizontally(initialOffsetX = { it }),
    slideOutHorizontally(targetOffsetX = { it }),
)

internal val FadeSlideHorizontal = Pair(
    fadeIn(animationSpec = tween(ENTER_TIME / 2)) + slideInHorizontally(initialOffsetX = { it / 3 }),
    fadeOut(animationSpec = tween(EXIT_TIME / 2)),
)

internal val FadeSlideUp = Pair(
    fadeIn(animationSpec = tween(ENTER_TIME / 2)) + slideInVertically(initialOffsetY = { it / 4 }),
    fadeOut(animationSpec = tween(EXIT_TIME / 2)),
)

internal val FlowTransition = Pair(
    fadeIn(animationSpec = tween(ENTER_TIME / 2)) + slideInHorizontally(
        initialOffsetX = { it / 3 },
        animationSpec = tween(ENTER_TIME)
    ),
    slideOutHorizontally(
        targetOffsetX = { -it / 3 },
        animationSpec = tween(ENTER_TIME * 2)
    ),
)

@Composable
fun CheckForConsent() {
    val activity = LocalActivity.current

    LaunchedEffect(Unit) {
        if (SettingManager.checkConsentDone.value) return@LaunchedEffect

        AdsManager.getInstance().runConsentFlow(activity, object : ConsentCallback {
            override fun onConsentComplete(canPersonalized: Boolean) {
                AdsManager.getInstance().logCustomEvent("consent_success", mapOf("result" to canPersonalized))
                AdsManager.getInstance().reloadConsent()
                SettingManager.setCheckConsentDone()
            }

            override fun onConsentError(message: String?) {
                AdsManager.getInstance().logCustomEvent("consent_error", mapOf("message" to (message ?: "")))
                AdsManager.getInstance().reloadConsent()
                SettingManager.setCheckConsentDone()
            }
        })
    }
}

private enum class AppScreen { Splash, Language, Onboarding, Home }

@Composable
fun App() {
    var screenOrdinal by rememberSaveable { mutableStateOf(AppScreen.Splash.ordinal) }
    val screen = AppScreen.entries[screenOrdinal]
    fun goTo(s: AppScreen) { screenOrdinal = s.ordinal }

    AnimatedContent(
        targetState = screen,
        transitionSpec = { FlowTransition.first togetherWith FlowTransition.second },
        label = "app_flow"
    ) { target ->
        when (target) {
            AppScreen.Splash -> SplashScreen(
                onNext = { goTo(AppScreen.Language) }
            )
            AppScreen.Language -> LanguageScreen(
                onNext = { goTo(AppScreen.Onboarding) }
            )
            AppScreen.Onboarding -> OnboardingScreen(
                onNext = {
                    goTo(AppScreen.Home)
                }
            )
            AppScreen.Home -> {
                MainScreen()
                CheckForConsent()
            }
        }
    }
}
