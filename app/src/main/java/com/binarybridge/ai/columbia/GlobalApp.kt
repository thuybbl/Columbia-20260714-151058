package com.binarybridge.ai.columbia

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.bbl.ads.modules.AdsManager
import com.bbl.ads.modules.application.AdsMultiDexApplication
import com.bbl.ads.modules.billing.AppPurchase
import com.bbl.ads.modules.configs.GlobalConfig
import com.binarybridge.ai.columbia.ads.AdsLoader
import com.binarybridge.ai.columbia.ads.AdsPolicy
import com.binarybridge.ai.columbia.core.SettingManager
import com.binarybridge.ai.columbia.features.iap.Iap
import com.vungle.ads.internal.ui.AdActivity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class GlobalApp : AdsMultiDexApplication() {

    private val _shouldShowWelcomeBack = MutableStateFlow(false)
    val shouldShowWelcomeBack = _shouldShowWelcomeBack.asStateFlow()

    override fun createDefaultGlobalConfig(): GlobalConfig {
        val config = super.createDefaultGlobalConfig()

        config.isConsentRequiredBeforeInit = false
        config.isEnableRemoteConfig = true
        config.adLoggingType = "realtime_database"
        config.isVariantDev = BuildConfig.DEBUG
//        config.isVariantDev = false
        config.loadStrategy = GlobalConfig.LOAD_STRATEGY_WATERFALL
        config.adjustToken = "t4goaggekidc"
        config.appsflyerToken = "X6Kiaov2ZqhCk3fc7dGnCd"
        config.facebookClientToken = "53d399e89e70e4d494e929d3d680e4fb"
        config.testDevices = arrayOf("727854F084C6F0CDC793A5A192B72FCC", "8D9B9371B8704790A1C041FAF7C14071", "B7DE3A60025A6EBCAC171F608A5EB87B", "EB52EFE4C726897953885CB827CA2EFC")

        return config
    }

    override fun onCreate() {
        super.onCreate()

        SettingManager.init(this)

        AdsManager.getInstance().apply {
            disableAppResumeWithActivity(AdActivity::class.java)
            disableAppResumeWithActivity(com.google.android.gms.ads.AdActivity::class.java)
            disableAppResumeWithActivity(MainActivity::class.java)
        }

        AdsLoader.initEarly(this)

        observeAppBackground()
        initBilling()
    }

    private fun observeAppBackground() {
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStop(owner: LifecycleOwner) {
                if (!AdsPolicy.isShowingInterAd && AdsLoader.isAdsEnabled()) {
                    _shouldShowWelcomeBack.value = true
                }
            }
        })
    }

    fun consumeWelcomeBack() {
        _shouldShowWelcomeBack.value = false
    }

    private fun initBilling() {
        val listIAPId: ArrayList<String> = ArrayList()
        val listSubsId: ArrayList<String> = ArrayList()
        listSubsId.add(Iap.weeklyId)
        listSubsId.add(Iap.monthlyId)
        listIAPId.add(Iap.lifetimeId)
        AppPurchase.getInstance().initBilling(this, listIAPId, listSubsId, this.globalConfig)
        AppPurchase.getInstance().setUpdatePurchaseListener {

        }
    }
}
