package com.binarybridge.ai.columbia.core

import android.content.Context
import android.util.Log
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

private val Context.localDataStore by preferencesDataStore(name = "local_data")

object SettingManager {

    private lateinit var dataStore: DataStore<Preferences>

    private val scope = CoroutineScope(
        SupervisorJob() + Dispatchers.IO
    )

    // For app
    private val IS_FIRST_TIME = booleanPreferencesKey("isFirstTime")
    private val APP_LOCALE = stringPreferencesKey("appLocale")

    // For business
    private val IS_PURCHASED = booleanPreferencesKey("isPurchased")
    private val ONBOARDING_FLOW_DONE = booleanPreferencesKey("onBoardingFlowDone")
    private val CHECK_CONSENT_DONE = booleanPreferencesKey("checkConsentDone")

    // [Columbia] credit local + premium
    private val CREDITS = intPreferencesKey("credits")
    private val IS_PREMIUM = booleanPreferencesKey("isPremium")
    private val FREE_AD_PROGRESS = intPreferencesKey("freeAdProgress")
    private const val DEFAULT_CREDITS = 35
    const val FREE_ADS_TARGET = 10   // xem đủ 10 ad để tạo 1 lần free

    private val _isFirstTime = MutableStateFlow(true)
    val isFirstTime: StateFlow<Boolean> = _isFirstTime.asStateFlow()

    private val _appLocale = MutableStateFlow("")
    val appLocale = _appLocale.asStateFlow()


    private val _isPurchased = MutableStateFlow(false)
    val isPurchased: StateFlow<Boolean> = _isPurchased.asStateFlow()

    private val _onBoardingFlowDone = MutableStateFlow(false)
    val onBoardingFlowDone: StateFlow<Boolean> = _onBoardingFlowDone.asStateFlow()

    private val _checkConsentDone = MutableStateFlow(false)
    val checkConsentDone: StateFlow<Boolean> = _checkConsentDone.asStateFlow()

    private val _credits = MutableStateFlow(DEFAULT_CREDITS)
    val credits: StateFlow<Int> = _credits.asStateFlow()

    private val _isPremium = MutableStateFlow(false)
    val isPremium: StateFlow<Boolean> = _isPremium.asStateFlow()

    private val _freeAdProgress = MutableStateFlow(0)
    val freeAdProgress: StateFlow<Int> = _freeAdProgress.asStateFlow()

    fun init(context: Context) {
        val appContext = context.applicationContext
        dataStore = appContext.localDataStore

        scope.launch {
            val prefs = dataStore.data.first()

            _isFirstTime.value = prefs[IS_FIRST_TIME] ?: true
            val savedLocale = prefs[APP_LOCALE] ?: Locale.getDefault().language
            _appLocale.value = savedLocale

            _isPurchased.value = prefs[IS_PURCHASED] ?: false
            _onBoardingFlowDone.value = prefs[ONBOARDING_FLOW_DONE] ?: false
            _checkConsentDone.value = prefs[CHECK_CONSENT_DONE] ?: false
            _credits.value = prefs[CREDITS] ?: DEFAULT_CREDITS
            _isPremium.value = prefs[IS_PREMIUM] ?: false
            _freeAdProgress.value = prefs[FREE_AD_PROGRESS] ?: 0

            if (_isFirstTime.value) dataStore.edit { it[IS_FIRST_TIME] = false }

            withContext(Dispatchers.Main) {
                applyLocale(savedLocale)
            }

            Log.i("SettingManager", "isFirstTime=${_isFirstTime.value}, locale=$savedLocale")
        }
    }

    private fun applyLocale(localeId: String) {
        AppCompatDelegate.setApplicationLocales(
            LocaleListCompat.forLanguageTags(localeId)
        )
    }
    fun setAppLocale(localeId: String) {
        val changed = _appLocale.value != localeId
        _appLocale.value = localeId
        applyLocale(localeId)

        if (changed) {
            scope.launch {
                dataStore.edit {
                    it[APP_LOCALE] = localeId
                }
            }
        }
    }

    fun setPurchased(purchased: Boolean) {
        if (!purchased || _isPurchased.value) return

        _isPurchased.value = true

        scope.launch {
            dataStore.edit {
                it[IS_PURCHASED] = true
            }
        }
    }

    fun setOnBoardingFlowDone() {
        if (_onBoardingFlowDone.value) return

        _onBoardingFlowDone.value = true

        scope.launch {
            dataStore.edit {
                it[ONBOARDING_FLOW_DONE] = true
            }
        }
    }

    fun setCheckConsentDone() {
        if (_checkConsentDone.value) return

        _checkConsentDone.value = true

        scope.launch {
            dataStore.edit {
                it[CHECK_CONSENT_DONE] = true
            }
        }
    }

    // === [Columbia] credit / premium ===
    private fun persistCredits(value: Int) {
        _credits.value = value
        scope.launch { dataStore.edit { it[CREDITS] = value } }
    }

    fun addCredits(amount: Int) {
        if (amount <= 0) return
        persistCredits(_credits.value + amount)
    }

    /** Trừ credit nếu đủ; trả true nếu đã trừ. */
    fun spendCredits(amount: Int): Boolean {
        if (amount <= 0) return true
        if (_credits.value < amount) return false
        persistCredits(_credits.value - amount)
        return true
    }

    fun refundCredits(amount: Int) = addCredits(amount)

    fun setPremium(premium: Boolean) {
        if (_isPremium.value == premium) return
        _isPremium.value = premium
        scope.launch { dataStore.edit { it[IS_PREMIUM] = premium } }
    }

    /** Xem 1 reward-ad cho tiến trình "watch N ads to create free". Trả true khi đủ target (đã reset). */
    fun incFreeAdProgress(): Boolean {
        val next = _freeAdProgress.value + 1
        return if (next >= FREE_ADS_TARGET) {
            _freeAdProgress.value = 0
            scope.launch { dataStore.edit { it[FREE_AD_PROGRESS] = 0 } }
            true
        } else {
            _freeAdProgress.value = next
            scope.launch { dataStore.edit { it[FREE_AD_PROGRESS] = next } }
            false
        }
    }
}