package com.binarybridge.ai.columbia.features.paywall

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.binarybridge.ai.columbia.ui.components.AppDialog
import com.binarybridge.ai.columbia.ui.components.GradientButton
import com.binarybridge.ai.columbia.ui.components.RoundIconButton
import com.binarybridge.ai.columbia.ui.theme.*

@Composable
fun PaywallScreen(nav: NavHostController) {
    var selectedYearly by remember { mutableStateOf(true) }
    var info by remember { mutableStateOf(false) }

    Box(
        Modifier.fillMaxSize().background(
            Brush.radialGradient(listOf(ColumbiaPrimaryDeep, ColumbiaBackground), radius = 1400f)
        )
    ) {
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalArrangement = Arrangement.End) {
                RoundIconButton(Icons.Rounded.Close) { nav.popBackStack() }
            }
            Column(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.size(72.dp).clip(RoundedCornerShape(20.dp)).background(Brush.linearGradient(listOf(ColumbiaPrimary, ColumbiaMagenta))), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.WorkspacePremium, null, tint = Color.White, modifier = Modifier.size(36.dp))
                }
                Spacer(Modifier.height(12.dp))
                Text("Columbia Premium", color = ColumbiaTextPrimary, fontWeight = FontWeight.ExtraBold, fontSize = 26.sp)
                Text("Unlock the full spectrum", color = ColumbiaTextSecondary, fontSize = 14.sp)
            }

            Column(
                Modifier.padding(top = 24.dp).fillMaxWidth().clip(RoundedCornerShape(20.dp))
                    .background(ColumbiaGlass).border(1.dp, ColumbiaBorder, RoundedCornerShape(20.dp)).padding(18.dp)
            ) {
                listOf("1080P HD generation", "No ads", "Priority queue", "Bonus monthly credits").forEach {
                    Row(Modifier.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Check, null, tint = ColumbiaPrimaryBright, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(10.dp))
                        Text(it, color = ColumbiaTextPrimary, fontSize = 15.sp)
                    }
                }
            }

            Row(Modifier.padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                PlanBox("Weekly", "$4.99", !selectedYearly, Modifier.weight(1f)) { selectedYearly = false }
                PlanBox("Yearly", "$29.99", selectedYearly, Modifier.weight(1f)) { selectedYearly = true }
            }

            GradientButton("Continue", Modifier.padding(top = 16.dp).fillMaxWidth()) { info = true }

            Row(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalArrangement = Arrangement.Center) {
                listOf("Restore", "Terms", "Privacy").forEach {
                    Text(it, color = ColumbiaTextMuted, fontSize = 12.sp, modifier = Modifier.padding(horizontal = 10.dp).clickable { info = true })
                }
            }
            Spacer(Modifier.height(40.dp))
        }

        if (info) {
            AppDialog(
                title = "Preview build",
                message = "Subscriptions will be enabled soon. Purchase logic is handled separately.",
                confirmText = "OK", onConfirm = { info = false }, onDismiss = { info = false }
            )
        }
    }
}

@Composable
private fun PlanBox(name: String, price: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) Brush.linearGradient(listOf(ColumbiaPrimary, ColumbiaPrimaryBright)) else Brush.linearGradient(listOf(ColumbiaSurface, ColumbiaSurface)))
            .border(1.dp, if (selected) Color.Transparent else ColumbiaBorder, RoundedCornerShape(16.dp))
            .clickable { onClick() }
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(name, color = if (selected) Color.White else ColumbiaTextPrimary, fontWeight = FontWeight.Bold)
        Text(price, color = if (selected) Color.White else ColumbiaTextSecondary, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
    }
}
