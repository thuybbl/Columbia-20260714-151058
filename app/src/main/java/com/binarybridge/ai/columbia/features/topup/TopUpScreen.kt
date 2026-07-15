package com.binarybridge.ai.columbia.features.topup

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.PlayCircle
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
import com.binarybridge.ai.columbia.data.domain.Catalog
import com.binarybridge.ai.columbia.data.domain.CreditPack
import com.binarybridge.ai.columbia.ui.components.AppDialog
import com.binarybridge.ai.columbia.ui.components.BackTopBar
import com.binarybridge.ai.columbia.ui.components.ColumbiaBackground
import com.binarybridge.ai.columbia.ui.components.GradientButton
import com.binarybridge.ai.columbia.ui.components.SectionLabel
import com.binarybridge.ai.columbia.ui.theme.*

@Composable
fun TopUpScreen(nav: NavHostController) {
    val credits by SettingManager.credits.collectAsState()
    var pendingPack by remember { mutableStateOf<CreditPack?>(null) }
    var showAd by remember { mutableStateOf(false) }
    var info by remember { mutableStateOf<String?>(null) }

    ColumbiaBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            Box(Modifier.padding(vertical = 8.dp)) {
                BackTopBar(onBack = { nav.popBackStack() }, center = {
                    Column { SectionLabel("Top up"); Text("Credits", color = ColumbiaTextPrimary, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp) }
                })
            }

            // Balance banner
            Row(
                Modifier.padding(top = 8.dp).fillMaxWidth().clip(RoundedCornerShape(20.dp))
                    .background(Brush.linearGradient(listOf(Color(0xFF7C3AED), ColumbiaMagenta))).padding(22.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Rounded.Bolt, null, tint = Color.White, modifier = Modifier.size(30.dp))
                Spacer(Modifier.width(12.dp))
                Column {
                    Text("Your balance", color = Color.White.copy(alpha = 0.85f), fontSize = 13.sp)
                    Text("$credits credits", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 26.sp)
                }
            }

            // Watch ad row
            Row(
                Modifier.padding(top = 16.dp).fillMaxWidth().clip(RoundedCornerShape(20.dp))
                    .background(ColumbiaSurface).border(1.dp, ColumbiaBorder, RoundedCornerShape(20.dp))
                    .clickable { showAd = true }.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.size(46.dp).clip(RoundedCornerShape(12.dp)).background(ColumbiaCreditGold.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.PlayCircle, null, tint = ColumbiaCreditGold, modifier = Modifier.size(24.dp))
                }
                Spacer(Modifier.width(14.dp))
                Text("Watch an ad · +2 credits", color = ColumbiaTextPrimary, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                Icon(Icons.Rounded.ChevronRight, null, tint = ColumbiaTextMuted)
            }

            SectionLabel("Spectrum packs", Modifier.padding(top = 24.dp))
            Text("Get credits", color = ColumbiaTextPrimary, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)

            val packs = Catalog.packs
            if (packs.isNotEmpty()) {
                PackCard(packs.first(), Modifier.padding(top = 12.dp).fillMaxWidth()) { pendingPack = packs.first() }
                packs.drop(1).chunked(2).forEach { row ->
                    Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        row.forEach { p -> PackCard(p, Modifier.weight(1f)) { pendingPack = p } }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
            Spacer(Modifier.height(120.dp))
        }

        pendingPack?.let { p ->
            AppDialog(
                title = "Purchase ${p.credits} credits",
                message = "In-app purchase (${p.priceLabel}) will be enabled soon. This is a preview build.",
                confirmText = "OK",
                onConfirm = { pendingPack = null },
                onDismiss = { pendingPack = null }
            )
        }
        if (showAd) {
            AppDialog(
                title = "Earn credits", message = "Watch a short ad to earn +2 credits.", confirmText = "Watch",
                onConfirm = { SettingManager.addCredits(2); showAd = false; info = "+2 credits added!" },
                dismissText = "Cancel", onDismiss = { showAd = false }
            )
        }
        info?.let { AppDialog(title = "Columbia", message = it, confirmText = "OK", onConfirm = { info = null }, onDismiss = { info = null }) }
    }
}

@Composable
private fun PackCard(pack: CreditPack, modifier: Modifier, onClick: () -> Unit) {
    // modifier = Modifier.weight(1f) từ Row. Nội dung mọi thẻ đồng nhất -> bằng chiều cao + nút thẳng hàng.
    // Badge POPULAR là OVERLAY neo mép trên viền (không chiếm chiều cao nội dung) — theo spec "badge neo trên viền".
    Box(modifier) {
        Column(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(ColumbiaSurface)
                .border(1.dp, if (pack.popular) ColumbiaPrimary else ColumbiaBorder, RoundedCornerShape(20.dp))
                .padding(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(Icons.Rounded.Bolt, null, tint = ColumbiaCreditGold, modifier = Modifier.size(24.dp))
            Text("${pack.credits}", color = ColumbiaTextPrimary, fontWeight = FontWeight.ExtraBold, fontSize = 28.sp)
            Text("credits", color = ColumbiaTextMuted, fontSize = 13.sp)
            // luôn giữ 1 dòng (chống lệch nếu 2 thẻ cùng hàng khác nhau về extra)
            Text(
                if (pack.extraPercent > 0) "+${pack.extraPercent}% extra" else " ",
                color = ColumbiaPrimaryBright, fontSize = 13.sp
            )
            GradientButton(pack.priceLabel, Modifier.padding(top = 10.dp).fillMaxWidth(), onClick = onClick)
        }
        if (pack.popular) {
            Box(
                Modifier.align(Alignment.TopCenter).offset(y = (-10).dp)
                    .clip(RoundedCornerShape(50)).background(ColumbiaPrimary)
                    .padding(horizontal = 12.dp, vertical = 4.dp)
            ) { Text("POPULAR", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp) }
        }
    }
}
