package com.binarybridge.ai.columbia.features.language

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.core.tween
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.binarybridge.ai.columbia.R
import com.binarybridge.ai.columbia.core.SettingManager
import com.binarybridge.ai.columbia.FadeSlideHorizontal
import com.binarybridge.ai.columbia.ads.AdsPlacementHolder
import com.binarybridge.ai.columbia.ui.components.ads.NativeAdFrame
import kotlinx.coroutines.delay

enum class LanguageStep {
    Language,
    Region,
}

@Composable
fun LanguageScreen(
    selectRegion: Boolean = true,
    onNext: () -> Unit = {},
) {
    var currentStep by rememberSaveable {
        mutableStateOf(LanguageStep.Language)
    }

    var selectedLanguageLocaleId by rememberSaveable {
        mutableStateOf<String?>(null)
    }

    var selectedRegionIndex by rememberSaveable {
        mutableIntStateOf(-1)
    }

    val selectedLanguage = remember(selectedLanguageLocaleId) {
        supportedLanguages.find { it.localeId == selectedLanguageLocaleId }
    }

    BackHandler(currentStep == LanguageStep.Region,) {
        selectedRegionIndex = -1
        currentStep = LanguageStep.Language
    }

    AnimatedContent(
        targetState = currentStep,
        modifier = Modifier.fillMaxSize(),
        transitionSpec = {
            when {
                initialState == LanguageStep.Language && targetState == LanguageStep.Region ->
                    FadeSlideHorizontal.first togetherWith ExitTransition.KeepUntilTransitionsFinished
                else -> EnterTransition.None togetherWith ExitTransition.None
            }
        },
        label = "LanguageStepAnimation",
    ) { step ->

        when (step) {
            LanguageStep.Language -> {
                LanguageSelectionContent(
                    selectedLocaleId = selectedLanguageLocaleId,
                    onLanguageSelected = { localeId ->
                        selectedLanguageLocaleId = localeId
                        SettingManager.setAppLocale(localeId)
                    },
                    onNext = {
                        val language = selectedLanguage

                        if (
                            selectRegion &&
                            language != null &&
                            language.regions.isNotEmpty()
                        ) {
                            currentStep = LanguageStep.Region
                        } else {
                            onNext()
                        }
                    },
                )
            }

            LanguageStep.Region -> {
                val language = selectedLanguage
                    ?: return@AnimatedContent

                RegionSelectionContent(
                    regions = language.regions,
                    selectedRegionIndex = selectedRegionIndex,
                    onRegionSelected = {
                        selectedRegionIndex = it
                    },
                    onNext = {
                        val region =
                            language.regions.getOrNull(selectedRegionIndex)

                        SettingManager.setAppLocale(
                            region?.localeId ?: language.localeId
                        )

                        onNext()
                    },
                )
            }
        }
    }
}

@Composable
private fun LanguageSelectionContent(
    selectedLocaleId: String?,
    onLanguageSelected: (String) -> Unit,
    onNext: () -> Unit,
) {
    var showNextButton by remember { mutableStateOf(false) }

    LaunchedEffect(selectedLocaleId) {
        if (selectedLocaleId != null) {
            showNextButton = false
            delay(500)
            showNextButton = true
        } else {
            showNextButton = false
        }
    }

    Column(modifier = Modifier.fillMaxSize().navigationBarsPadding()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .height(64.dp)
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.language),
                    modifier = Modifier.weight(1f),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF212121),
                )

                AnimatedVisibility(
                    visible = showNextButton,
                    enter = fadeIn(),
                    exit = fadeOut(),
                ) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .clickable(onClick = onNext)
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = stringResource(R.string.next),
                            color = Color(0xFF64B5F6),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            }
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .background(Color(0xFFF2F2F2)),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(supportedLanguages, key = { it.localeId }) { language ->
                LanguageItemCard(
                    language = language,
                    isSelected = selectedLocaleId == language.localeId,
                    onClick = { onLanguageSelected(language.localeId) },
                )
            }
            item {
                Spacer(modifier = Modifier.height(240.dp))
            }
        }
        NativeAdFrame(
            modifier = Modifier.fillMaxWidth(),
            adPlacement = AdsPlacementHolder.NATIVE_LFO1,
            reloadIntervalMs = 15_000L,
        )
    }
}

@Composable
private fun RegionSelectionContent(
    regions: List<Region>,
    selectedRegionIndex: Int,
    onRegionSelected: (Int) -> Unit,
    onNext: () -> Unit,
) {
    var showNextButton by remember { mutableStateOf(false) }

    LaunchedEffect(selectedRegionIndex) {
        if (selectedRegionIndex >= 0) {
            showNextButton = false
            delay(500)
            showNextButton = true
        } else {
            showNextButton = false
        }
    }

    Column(modifier = Modifier.fillMaxSize().navigationBarsPadding()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .height(64.dp)
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.select_region),
                    modifier = Modifier.weight(1f),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF212121),
                )

                AnimatedVisibility(
                    visible = showNextButton,
                    enter = fadeIn(),
                    exit = fadeOut(),
                ) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .clickable(onClick = onNext)
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = stringResource(R.string.next),
                            color = Color(0xFF64B5F6),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            }
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .background(Color(0xFFF2F2F2)),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            itemsIndexed(regions, key = { index, region -> index }) { index, region ->
                RegionItemCard(
                    region = region,
                    isSelected = selectedRegionIndex == index,
                    onClick = { onRegionSelected(index) },
                )
            }
            item {
                Spacer(modifier = Modifier.height(240.dp))
            }
        }
        NativeAdFrame(
            modifier = Modifier.fillMaxWidth(),
            adPlacement = AdsPlacementHolder.NATIVE_LFO2,
            reloadIntervalMs = 15_000L,
        )
    }
}

@Composable
private fun LanguageItemCard(
    language: Language,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(language.resId),
            contentDescription = language.text,
            modifier = Modifier
                .size(22.dp)
                .clip(CircleShape),
            contentScale = ContentScale.Crop,
        )

        Text(
            text = language.text,
            modifier = Modifier
                .weight(1f)
                .padding(start = 10.dp),
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = Color(0xFF212121),
        )

        DonutRadioButton(selected = isSelected)
    }
}

@Composable
private fun RegionItemCard(
    region: Region,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(region.resId),
            contentDescription = region.text,
            modifier = Modifier
                .size(22.dp)
                .clip(CircleShape),
            contentScale = ContentScale.Crop,
        )

        Text(
            text = region.text,
            modifier = Modifier
                .weight(1f)
                .padding(start = 10.dp),
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = Color(0xFF212121),
        )

        DonutRadioButton(selected = isSelected)
    }
}

@Composable
private fun DonutRadioButton(
    selected: Boolean,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .size(20.dp)
            .clip(CircleShape)
            .background(if (selected) Color(0xFF2196F3) else Color(0xFFE1E1E1)),
        contentAlignment = Alignment.Center,
    ) {
        if (selected) {
            Box(
                modifier = Modifier
                    .size(11.dp)
                    .clip(CircleShape)
                    .background(Color.White),
            )
        }
    }
}
