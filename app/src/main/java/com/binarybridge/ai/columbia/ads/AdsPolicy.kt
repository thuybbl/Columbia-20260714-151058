package com.binarybridge.ai.columbia.ads

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.bbl.ads.modules.AdsManager
import com.bbl.ads.modules.configs.RemoteConfigManager
import com.bbl.ads.modules.function.AdCallback
import com.binarybridge.ai.columbia.core.SettingManager
import com.facebook.shimmer.ShimmerFrameLayout
import com.binarybridge.ai.columbia.R
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

object AdModeManager {

    private val modeMap = ConcurrentHashMap<String, Int>()

    init {
        initDefaultModes()
    }

    private fun initDefaultModes() {
        AdsPlacementHolder::class.java.fields
            .filter { field ->
                field.type == String::class.java
            }
            .forEach { field ->
                val placement = field.get(null) as? String ?: return@forEach
                modeMap[placement] = 1
            }
    }

    fun syncFromRemoteConfig(context: Context) {
        val remote = RemoteConfigManager.getInstance(context)

        AdsPlacementHolder::class.java.fields
            .filter { field ->
                field.type == String::class.java
            }
            .forEach { field ->
                val placement = field.get(null) as? String ?: return@forEach

                val mode = try {
                    remote.getString(placement, "1")
                        .toIntOrNull() ?: 1
                } catch (_: Exception) {
                    1
                }

                modeMap[placement] = mode
            }
    }

    fun getMode(placement: String): Int {
        return modeMap[placement] ?: 1
    }

    fun isEnabled(placement: String): Boolean {
        return getMode(placement) != 0
    }
}

object AdsPolicy {
    private const val INTERVAL = 30_000L

    @Volatile
    private var lastTimeShowedAt: Long = 0L

    @Volatile
    private var runtimeInterCount = 0

    @Volatile
    var allowShowWelcomeBack = true

    @Volatile
    var isShowingInterAd = false
        private set

    private val _isWaitingInterAd = MutableStateFlow(false)
    val isWaitingInterAd: StateFlow<Boolean> = _isWaitingInterAd.asStateFlow()

    private fun setShowingInter(showing: Boolean) {
        isShowingInterAd = showing
    }

    private fun setWaitingInterAd(waiting: Boolean) {
        _isWaitingInterAd.value = waiting
    }

    fun canShowInterAd(): Boolean = System.currentTimeMillis() - lastTimeShowedAt >= INTERVAL

    private fun resolvePlacement(placement: String): String {
        if (SettingManager.isFirstTime.value) return placement
        return when (placement) {
            AdsPlacementHolder.INTER_SPLASH -> AdsPlacementHolder.INTER_SPLASH_2ND
            else -> placement
        }
    }

    private inline fun skipIfAdsInactive(onSkip: () -> Unit): Boolean {
        if (!AdsLoader.isAdsEnabled()) {
            onSkip()
            return true
        }
        return false
    }

    private inline fun skipIfDisabled(
        placement: String,
        onDisabled: () -> Unit
    ): Boolean {
        if (!AdModeManager.isEnabled(placement)) {
            onDisabled()
            return true
        }
        return false
    }

    fun showInterAd(
        activity: Activity,
        adPlacement: String,
        onContinue: () -> Unit,
        delayTime: Long = 0,
        force: Boolean = false // Show ngay lập tức, không áp dụng luật bên dưới
    ) {
        val hasContinued = AtomicBoolean(false)
        val continueOnce = {
            if (hasContinued.compareAndSet(false, true)) {
                onContinue()
            }
        }

        if (skipIfAdsInactive { continueOnce() }) return

        val placement = resolvePlacement(adPlacement)
        loadNextAd(placement)

        val mode = AdModeManager.getMode(placement)
        if (mode == 0) {
            continueOnce()
            return
        }

        if (!force) {
            runtimeInterCount++
            val isOdd = runtimeInterCount % 2 == 1
            val isEven = !isOdd
            val isFirstTime = SettingManager.isFirstTime.value

            when (mode) {
                1 -> {
                    val shouldShow = if (isFirstTime) {
                        canShowInterAd()
                    } else {
                        isEven
                    }
                    if (!shouldShow) {
                        continueOnce()
                        return
                    }
                }
                2 -> {
                    val shouldShow = if (isFirstTime) {
                        isOdd
                    } else {
                        isEven
                    }
                    if (!shouldShow) {
                        continueOnce()
                        return
                    }
                }
            }
        }

        setShowingInter(true)
        setWaitingInterAd(true)
        AdsManager.getInstance()
            .loadandShowWithTimeDalay(
                activity,
                placement,
                25000,
                delayTime,
                object : AdCallback {
                    override fun onAdLoaded(p0: String?) {
                        super.onAdLoaded(p0)
                        setWaitingInterAd(false)
                    }

                    override fun onAdFailed(name: String?, error: String?) {
                        setWaitingInterAd(false)
                        setShowingInter(false)
                        Log.e("AdsLib", "$placement: $error")
                        continueOnce()
                    }
                    override fun onAdClosed(name: String?) {
                        setShowingInter(false)
                        continueOnce()
                    }
                }
            )

        if (
            !force &&
            mode == 1 &&
            SettingManager.isFirstTime.value
        ) {
            lastTimeShowedAt = System.currentTimeMillis()
        }
    }

    fun bindBannerAd(
        activity: Activity,
        adPlacement: String,
        onAdFailed: (() -> Unit)? = null
    ) {
        val placement = resolvePlacement(adPlacement)
        loadNextAd(placement)
        val bannerContainer = activity.findViewById<FrameLayout>(R.id.fr_banner)

        if (skipIfAdsInactive {
                bannerContainer?.visibility = View.GONE
                onAdFailed?.invoke()
            }) return

        if (skipIfDisabled(placement) {
                bannerContainer?.visibility = View.GONE
            }) return

        AdsManager.getInstance().show(activity, placement, object : AdCallback {
            override fun onAdFailed(p0: String?, p1: String?) {
                super.onAdFailed(p0, p1)
                bannerContainer?.visibility = View.GONE
                onAdFailed?.invoke()
                Log.e("AdsLib", "$p0: $p1")
            }
        })
    }

    fun bindNativeAd(
        activity: Activity,
        adPlacement: String,
        container: FrameLayout? = null,
        shimmer: ShimmerFrameLayout? = null,
        parentContainer: ViewGroup? = null,
        templateAdLayoutRes: Int = R.layout.template_ad_paid,
        onAdFailed: (() -> Unit)? = null,
        onAdLoaded: (() -> Unit)? = null,
    ) {
        val placement = resolvePlacement(adPlacement)
        loadNextAd(placement)

        val adContainer: FrameLayout? = container ?: activity.findViewById(R.id.frAds)
        val shimmerView: ShimmerFrameLayout? = shimmer ?: activity.findViewById(R.id.shimmerNative)

        if (adContainer == null || shimmerView == null) return

        if (skipIfAdsInactive {
                shimmerView.stopShimmer()
                shimmerView.visibility = View.GONE
                adContainer.visibility = View.GONE
                parentContainer?.visibility = View.GONE
                onAdFailed?.invoke()
            }) return

        if (skipIfDisabled(placement) {
                shimmerView.stopShimmer()
                shimmerView.visibility = View.GONE
                adContainer.visibility = View.GONE
                parentContainer?.visibility = View.GONE
            }) return

        adContainer.visibility = View.VISIBLE
        adContainer.removeAllViews()

        shimmerView.visibility = View.VISIBLE
        shimmerView.startShimmer()

        if (shimmerView.parent != adContainer) {
            (shimmerView.parent as? ViewGroup)?.removeView(shimmerView)
            adContainer.addView(shimmerView)
        }

        AdsManager.getInstance().loadAndPopulateNativeAd(
            activity,
            placement,
            templateAdLayoutRes,
            adContainer,
            shimmerView,
            object : AdCallback {

                override fun onAdLoaded(name: String?) {
                    shimmerView.stopShimmer()
                    shimmerView.visibility = View.GONE
                    onAdLoaded?.invoke()
                    Log.i("AdsLib", "$placement loaded")
                }

                override fun onAdFailed(name: String?, error: String?) {
                    shimmerView.stopShimmer()
                    shimmerView.visibility = View.GONE
                    adContainer.visibility = View.GONE

                    parentContainer?.visibility = View.GONE

                    onAdFailed?.invoke()

                    Log.e("AdsLib", "$placement: $error")
                }
            }
        )
    }

    fun loadAd(adPlacement: String) {
        if (!AdsLoader.isAdsEnabled()) return
        val placement = resolvePlacement(adPlacement)
        AdsManager.getInstance().load(placement, null)
    }

    fun loadNextAd(adPlacement: String) {
        if (!AdsLoader.isAdsEnabled()) return
        if (adPlacement == AdsPlacementHolder.BANNER_SPLASH) loadAd(AdsPlacementHolder.NATIVE_LFO1)
        if (adPlacement == AdsPlacementHolder.NATIVE_LFO1) loadAd(AdsPlacementHolder.NATIVE_LFO2)

        if (adPlacement == AdsPlacementHolder.NATIVE_LFO2) loadAd(AdsPlacementHolder.NATIVE_ONB1)
        if (adPlacement == AdsPlacementHolder.NATIVE_ONB1) loadAd(AdsPlacementHolder.NATIVE_ONB1_CLICK)
        if (adPlacement == AdsPlacementHolder.NATIVE_ONB1) {
            loadAd(AdsPlacementHolder.NATIVE_FULL1)
            loadAd(AdsPlacementHolder.NATIVE_FULL2)
        }
        if (adPlacement == AdsPlacementHolder.NATIVE_FULL2) {
            loadAd(AdsPlacementHolder.NATIVE_WELCOME)
            loadAd(AdsPlacementHolder.NATIVE_HOME)
            loadAd(AdsPlacementHolder.BANNER_HOME)
        }
        if (adPlacement == AdsPlacementHolder.INTER_SPLASH_2ND) {
            loadAd(AdsPlacementHolder.NATIVE_HOME)
            loadAd(AdsPlacementHolder.BANNER_HOME)
        }
        if (adPlacement == AdsPlacementHolder.INTER_HOME) loadAd(AdsPlacementHolder.INTER_HOME)

        if (adPlacement == AdsPlacementHolder.BANNER_HOME) loadAd(AdsPlacementHolder.NATIVE_RESUME)
    }
}
