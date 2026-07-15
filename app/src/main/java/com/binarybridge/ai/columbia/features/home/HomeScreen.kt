package com.binarybridge.ai.columbia.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowForward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Image
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.app.Activity
import androidx.activity.compose.LocalActivity
import androidx.navigation.NavHostController
import com.binarybridge.ai.columbia.ads.AdsPlacementHolder
import com.binarybridge.ai.columbia.ads.AdsPolicy
import com.binarybridge.ai.columbia.core.PendingMedia
import com.binarybridge.ai.columbia.core.SettingManager
import com.binarybridge.ai.columbia.data.domain.Catalog
import com.binarybridge.ai.columbia.data.domain.Effect
import com.binarybridge.ai.columbia.ui.components.ColumbiaBackground
import com.binarybridge.ai.columbia.ui.components.CreditPill
import com.binarybridge.ai.columbia.ui.components.HeroGradient
import com.binarybridge.ai.columbia.ui.components.RoundIconButton
import com.binarybridge.ai.columbia.ui.components.SectionLabel
import com.binarybridge.ai.columbia.ui.components.ads.NativeAdFrame
import com.binarybridge.ai.columbia.ui.theme.*

@Composable
fun HomeScreen(nav: NavHostController) {
    val credits by SettingManager.credits.collectAsState()
    val activity = LocalActivity.current as? Activity

    // Inter khi mở function từ Home (fail-open: ads tắt/null → đi thẳng)
    fun withInter(go: () -> Unit) {
        if (activity != null) AdsPolicy.showInterAd(activity, AdsPlacementHolder.INTER_HOME, onContinue = go)
        else go()
    }

    ColumbiaBackground {
        Column(
            Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
        ) {
            // TopBar
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                Box(
                    Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(HeroGradient),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Rounded.AutoAwesome, null, tint = Color.White, modifier = Modifier.size(22.dp)) }
                Spacer(Modifier.width(12.dp))
                Text("Columbia", color = ColumbiaTextPrimary, fontSize = 26.sp, fontWeight = FontWeight.ExtraBold)
                Spacer(Modifier.weight(1f))
                CreditPill(credits) { nav.navigate("topup") }
                Spacer(Modifier.width(8.dp))
                RoundIconButton(Icons.Rounded.Settings) { nav.navigate("settings") }
            }

            // Hero
            Column(
                Modifier
                    .padding(top = 16.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(
                        Brush.linearGradient(
                            listOf(ColumbiaPrimaryDeep.copy(alpha = 0.55f), ColumbiaMagenta.copy(alpha = 0.35f))
                        )
                    )
                    .border(1.dp, ColumbiaBorder, RoundedCornerShape(20.dp))
                    .padding(20.dp)
            ) {
                Text(
                    "Turn ideas & photos\ninto AI videos",
                    color = ColumbiaTextPrimary, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, lineHeight = 28.sp
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .padding(top = 14.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(50))
                        .background(Color.Black.copy(alpha = 0.35f))
                        .border(1.dp, ColumbiaBorder, RoundedCornerShape(50))
                        .clickable {
                            PendingMedia.pendingPrompt = ""
                            withInter { nav.navigate("generation?mode=text") }
                        }
                        .padding(start = 16.dp, end = 8.dp, top = 8.dp, bottom = 8.dp)
                ) {
                    Icon(Icons.Rounded.AutoAwesome, null, tint = ColumbiaPrimaryBright, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(10.dp))
                    Text("Describe it, we animate it", color = ColumbiaTextMuted, fontSize = 15.sp, modifier = Modifier.weight(1f))
                    Box(
                        Modifier.size(40.dp).clip(CircleShape).background(HeroGradient),
                        contentAlignment = Alignment.Center
                    ) { Icon(Icons.Rounded.ArrowForward, null, tint = Color.White, modifier = Modifier.size(20.dp)) }
                }
            }

            // 2 mode cards
            Row(Modifier.padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ModeCard(
                    Modifier.weight(1f), Icons.Rounded.TextFields, "Text to Video", "Describe it, we animate it"
                ) { PendingMedia.pendingPrompt = ""; withInter { nav.navigate("generation?mode=text") } }
                ModeCard(
                    Modifier.weight(1f), Icons.Rounded.Image, "Image to Video", "Bring your photo to life"
                ) { PendingMedia.pendingPrompt = ""; withInter { nav.navigate("imagepick") } }
            }

            // Trending effects
            Spacer(Modifier.height(24.dp))
            SectionLabel("Spectrum")
            Text("Trending effects", color = ColumbiaTextPrimary, fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
            Spacer(Modifier.height(12.dp))
            Catalog.effects.chunked(2).forEach { row ->
                Row(Modifier.fillMaxWidth().padding(bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    row.forEach { effect ->
                        EffectCard(Modifier.weight(1f), effect) {
                            PendingMedia.pendingPrompt = effect.promptTemplate
                            withInter { nav.navigate("imagepick") }
                        }
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
            }

            Spacer(Modifier.height(8.dp))
            NativeAdFrame(
                adPlacement = AdsPlacementHolder.NATIVE_HOME,
                modifier = Modifier.fillMaxWidth(),
                reloadIntervalMs = 20_000L,
            )

            Spacer(Modifier.height(200.dp))
        }
    }
}

@Composable
private fun ModeCard(
    modifier: Modifier,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Column(
        modifier
            .heightIn(min = 140.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(ColumbiaSurface)
            .border(1.dp, ColumbiaBorder, RoundedCornerShape(20.dp))
            .clickable { onClick() }
            .padding(16.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Box(
            Modifier.size(46.dp).clip(RoundedCornerShape(12.dp)).background(ColumbiaPrimary.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center
        ) { Icon(icon, null, tint = ColumbiaPrimaryBright, modifier = Modifier.size(22.dp)) }
        Column {
            Text(title, color = ColumbiaTextPrimary, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            Text(subtitle, color = ColumbiaTextSecondary, fontSize = 13.sp)
        }
    }
}

@Composable
private fun EffectCard(modifier: Modifier, effect: Effect, onClick: () -> Unit) {
    Box(
        modifier
            .aspectRatio(0.85f)
            .clip(RoundedCornerShape(16.dp))
            .background(
                Brush.linearGradient(
                    listOf(Color(effect.colorSeed), Color(effect.colorSeed).copy(alpha = 0.4f), Color.Black.copy(alpha = 0.7f))
                )
            )
            .clickable { onClick() }
    ) {
        Text(
            effect.name, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp,
            modifier = Modifier.align(Alignment.BottomStart).padding(12.dp)
        )
    }
}
