package com.binarybridge.ai.columbia.features.settings

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Apps
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.PrivacyTip
import androidx.compose.material.icons.rounded.Send
import androidx.compose.material.icons.rounded.ThumbUp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.binarybridge.ai.columbia.ads.AdsPlacementHolder
import com.binarybridge.ai.columbia.ui.components.BackTopBar
import com.binarybridge.ai.columbia.ui.components.ColumbiaBackground
import com.binarybridge.ai.columbia.ui.components.OptionCard
import com.binarybridge.ai.columbia.ui.components.ads.NativeAdFrame
import com.binarybridge.ai.columbia.ui.theme.*

@Composable
fun SettingsScreen(nav: NavHostController) {
    val ctx = LocalContext.current
    fun openUrl(url: String) = try { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } catch (_: Exception) {}

    ColumbiaBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            Box(Modifier.padding(vertical = 8.dp)) { BackTopBar(onBack = { nav.popBackStack() }) }
            Text("Settings", color = ColumbiaPrimaryBright, fontWeight = FontWeight.ExtraBold, fontSize = 30.sp, modifier = Modifier.padding(top = 8.dp))
            Text("Tailor the app to your needs", color = ColumbiaTextSecondary, fontSize = 14.sp)

            // App info
            Row(
                Modifier.padding(top = 16.dp).fillMaxWidth().clip(RoundedCornerShape(20.dp))
                    .background(ColumbiaGlass).border(1.dp, ColumbiaBorder, RoundedCornerShape(20.dp)).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.size(52.dp).clip(RoundedCornerShape(14.dp)).background(ColumbiaPrimary.copy(alpha = 0.18f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Apps, null, tint = ColumbiaPrimaryBright, modifier = Modifier.size(26.dp))
                }
                Spacer(Modifier.width(14.dp))
                Column {
                    Text("Columbia AI", color = ColumbiaTextPrimary, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Text("Turn ideas & photos into AI videos", color = ColumbiaTextSecondary, fontSize = 13.sp)
                }
            }

            Row(Modifier.padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OptionCard(Icons.Rounded.Language, "Language", Modifier.weight(1f)) { nav.navigate("language") }
                OptionCard(Icons.Rounded.ThumbUp, "Rate Us", Modifier.weight(1f)) {
                    openUrl("https://play.google.com/store/apps/details?id=${ctx.packageName}")
                }
            }
            Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OptionCard(Icons.Rounded.Send, "Share", Modifier.weight(1f)) {
                    try {
                        ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, "Create AI videos with Columbia: https://play.google.com/store/apps/details?id=${ctx.packageName}")
                        }, "Share"))
                    } catch (_: Exception) {}
                }
                OptionCard(Icons.Rounded.PrivacyTip, "Privacy Policy", Modifier.weight(1f)) { openUrl("https://binarybridge.dev/privacy") }
            }
            Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OptionCard(Icons.Rounded.Description, "Terms of Use", Modifier.weight(1f)) { openUrl("https://binarybridge.dev/terms") }
                Spacer(Modifier.weight(1f))
            }
            Spacer(Modifier.height(24.dp))
            NativeAdFrame(
                adPlacement = AdsPlacementHolder.NATIVE_HOME,
                modifier = Modifier.fillMaxWidth(),
                reloadIntervalMs = 20_000L,
            )
            Spacer(Modifier.height(40.dp))
        }
    }
}
