package com.binarybridge.ai.columbia.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.PlayCircle
import androidx.compose.material.icons.rounded.Restore
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.binarybridge.ai.columbia.core.SettingManager
import com.binarybridge.ai.columbia.ui.components.AppDialog
import com.binarybridge.ai.columbia.ui.components.ColumbiaBackground
import com.binarybridge.ai.columbia.ui.components.GradientButton
import com.binarybridge.ai.columbia.ui.components.OptionCard
import com.binarybridge.ai.columbia.ui.components.ScreenHeader
import com.binarybridge.ai.columbia.ui.theme.*

@Composable
fun ProfileScreen(nav: NavHostController) {
    val credits by SettingManager.credits.collectAsState()
    var showWatchAd by remember { mutableStateOf(false) }
    var info by remember { mutableStateOf<String?>(null) }

    ColumbiaBackground {
        Column(Modifier.fillMaxWidth().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            Spacer(Modifier.height(8.dp))
            ScreenHeader("Account", "Profile")

            // Balance card
            Row(
                Modifier.padding(top = 16.dp).fillMaxWidth().clip(RoundedCornerShape(20.dp))
                    .background(Brush.linearGradient(listOf(ColumbiaPrimaryDeep.copy(alpha = 0.45f), ColumbiaMagenta.copy(alpha = 0.3f))))
                    .border(1.dp, ColumbiaBorder, RoundedCornerShape(20.dp)).padding(18.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.size(46.dp).clip(CircleShape).background(ColumbiaPrimary), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Bolt, null, tint = Color.White, modifier = Modifier.size(24.dp))
                }
                Spacer(Modifier.width(14.dp))
                Column {
                    Text("Your balance", color = ColumbiaTextSecondary, fontSize = 13.sp)
                    Text("$credits credits", color = ColumbiaTextPrimary, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
                }
                Spacer(Modifier.weight(1f))
                GradientButton("Get credits", Modifier, onClick = { nav.navigate("topup") })
            }

            // Options grid
            Row(Modifier.padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OptionCard(Icons.Rounded.WorkspacePremium, "Premium", Modifier.weight(1f)) { nav.navigate("paywall") }
                OptionCard(Icons.Rounded.Add, "Get credits", Modifier.weight(1f)) { nav.navigate("topup") }
            }
            Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OptionCard(Icons.Rounded.PlayCircle, "Watch an ad · +2 credits", Modifier.weight(1f)) { showWatchAd = true }
                OptionCard(Icons.Rounded.Restore, "Restore purchase", Modifier.weight(1f)) { info = "Nothing to restore yet." }
            }
            Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OptionCard(Icons.Rounded.Settings, "Settings", Modifier.weight(1f)) { nav.navigate("settings") }
                Spacer(Modifier.weight(1f))
            }

            Spacer(Modifier.height(200.dp))
        }

        if (showWatchAd) {
            AppDialog(
                title = "Earn credits",
                message = "Watch a short ad to earn +2 credits.",
                confirmText = "Watch",
                onConfirm = { SettingManager.addCredits(2); showWatchAd = false; info = "+2 credits added!" },
                dismissText = "Cancel",
                onDismiss = { showWatchAd = false }
            )
        }
        info?.let {
            AppDialog(title = "Columbia", message = it, confirmText = "OK", onConfirm = { info = null }, onDismiss = { info = null })
        }
    }
}
