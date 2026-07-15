package com.binarybridge.ai.columbia.features.generation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Image
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PlayCircle
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.binarybridge.ai.columbia.core.PendingMedia
import com.binarybridge.ai.columbia.core.rememberCropFlow
import com.binarybridge.ai.columbia.core.SettingManager
import com.binarybridge.ai.columbia.data.domain.Catalog
import com.binarybridge.ai.columbia.data.domain.GenMode
import com.binarybridge.ai.columbia.data.domain.Resolution
import com.binarybridge.ai.columbia.ui.components.AppDialog
import com.binarybridge.ai.columbia.ui.components.BackTopBar
import com.binarybridge.ai.columbia.ui.components.ColumbiaBackground
import com.binarybridge.ai.columbia.ui.components.CreditPill
import com.binarybridge.ai.columbia.ui.components.GhostButton
import com.binarybridge.ai.columbia.ui.components.GradientButton
import com.binarybridge.ai.columbia.ui.components.HeroGradient
import com.binarybridge.ai.columbia.ui.components.LoadingOverlay
import com.binarybridge.ai.columbia.ui.components.SectionLabel
import com.binarybridge.ai.columbia.ui.theme.*

@Composable
fun GenerationScreen(nav: NavHostController, modeArg: String) {
    val vm: GenerationViewModel = viewModel()
    val credits by SettingManager.credits.collectAsState()
    val isPremium by SettingManager.isPremium.collectAsState()

    LaunchedEffect(Unit) {
        val m = if (modeArg == "image") GenMode.IMAGE else GenMode.TEXT
        vm.initMode(m, PendingMedia.pendingPrompt, PendingMedia.croppedImageUri)
    }

    val launchCrop = rememberCropFlow { uri ->
        PendingMedia.croppedImageUri = uri
        vm.updateImage(uri)
    }

    // Điều hướng khi có kết quả
    LaunchedEffect(vm.resultId) {
        vm.resultId?.let { id ->
            PendingMedia.clear()
            nav.navigate("result/$id") { popUpTo("generation?mode={mode}") { inclusive = true } }
        }
    }

    ColumbiaBackground {
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
        ) {
            Box(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                BackTopBar(onBack = { nav.popBackStack() }, trailing = { CreditPill(credits) { nav.navigate("topup") } })
            }

            // Preview
            Box(
                Modifier
                    .padding(horizontal = 16.dp)
                    .fillMaxWidth()
                    .height(320.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(HeroGradient)
                    .clickable(enabled = vm.mode == GenMode.IMAGE) { launchCrop() },
                contentAlignment = Alignment.Center
            ) {
                if (vm.mode == GenMode.IMAGE && vm.imageUri != null) {
                    AsyncImage(model = vm.imageUri, contentDescription = null, modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(20.dp)))
                } else if (vm.mode == GenMode.IMAGE) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Rounded.Image, null, tint = Color.White, modifier = Modifier.size(56.dp))
                        Spacer(Modifier.height(8.dp))
                        Text("Tap to import a photo", color = Color.White, fontWeight = FontWeight.Bold)
                    }
                } else {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Rounded.AutoAwesome, null, tint = Color.White, modifier = Modifier.size(56.dp))
                        Spacer(Modifier.height(8.dp))
                        Text("Text to Video", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    }
                }
                // Toggle
                Row(
                    Modifier
                        .align(Alignment.BottomCenter)
                        .padding(16.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(50))
                        .background(Color.Black.copy(alpha = 0.4f))
                        .padding(5.dp)
                ) {
                    ToggleSeg("Text to Video", vm.mode == GenMode.TEXT, Modifier.weight(1f)) { vm.updateMode(GenMode.TEXT) }
                    ToggleSeg("Image to Video", vm.mode == GenMode.IMAGE, Modifier.weight(1f)) {
                        vm.updateMode(GenMode.IMAGE); if (vm.imageUri == null) launchCrop()
                    }
                }
            }

            // Config sheet
            Column(
                Modifier
                    .padding(top = 8.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
                    .background(ColumbiaBackgroundElevated)
                    .padding(18.dp)
            ) {
                // Prompt
                Box(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 72.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color.Black.copy(alpha = 0.35f))
                        .border(1.dp, ColumbiaBorder, RoundedCornerShape(16.dp))
                        .padding(14.dp)
                ) {
                    if (vm.prompt.isEmpty()) {
                        Text(
                            if (vm.mode == GenMode.IMAGE) "Describe the motion (optional)…" else "Describe your video…",
                            color = ColumbiaTextMuted, fontSize = 15.sp
                        )
                    }
                    BasicTextField(
                        value = vm.prompt,
                        onValueChange = { vm.prompt = it },
                        textStyle = TextStyle(color = ColumbiaTextPrimary, fontSize = 15.sp),
                        cursorBrush = SolidColor(ColumbiaPrimaryBright),
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Idea chips
                Row(Modifier.padding(top = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("Try an idea", color = ColumbiaTextSecondary, fontSize = 14.sp)
                    Spacer(Modifier.weight(1f))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.clip(RoundedCornerShape(50)).clickable { vm.prompt = Catalog.ideas.random() }.padding(4.dp)
                    ) {
                        Icon(Icons.Rounded.Shuffle, null, tint = ColumbiaPrimaryBright, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Surprise me", color = ColumbiaPrimaryBright, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                }
                Row(
                    Modifier.padding(top = 12.dp).horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Catalog.ideas.take(5).forEach { idea ->
                        Box(
                            Modifier.clip(RoundedCornerShape(50)).border(1.dp, ColumbiaBorder, RoundedCornerShape(50))
                                .clickable { vm.prompt = idea }.padding(horizontal = 16.dp, vertical = 10.dp)
                        ) { Text(idea.take(18), color = ColumbiaTextPrimary, fontSize = 13.sp) }
                    }
                }

                // Resolution
                SectionLabel("Resolution", Modifier.padding(top = 24.dp))
                Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    ResBox(Resolution.R720, vm.resolution == Resolution.R720, false, Modifier.weight(1f)) { vm.updateResolution(Resolution.R720) }
                    ResBox(Resolution.R1080, vm.resolution == Resolution.R1080, !isPremium, Modifier.weight(1f)) {
                        if (isPremium) vm.updateResolution(Resolution.R1080) else nav.navigate("paywall")
                    }
                }

                // Ratio
                SectionLabel("Aspect ratio", Modifier.padding(top = 24.dp))
                Row(
                    Modifier.padding(top = 12.dp).horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    listOf("9:16", "16:9", "1:1", "4:3", "3:4").forEach { r ->
                        com.binarybridge.ai.columbia.ui.components.ChoiceChip(r, vm.ratio == r) { vm.updateRatio(r) }
                    }
                }

                // Duration
                SectionLabel("Duration", Modifier.padding(top = 24.dp))
                Slider(
                    value = vm.durationSec.toFloat(),
                    onValueChange = { vm.updateDuration(it.toInt()) },
                    valueRange = 2f..15f,
                    colors = SliderDefaults.colors(
                        thumbColor = ColumbiaPrimaryBright,
                        activeTrackColor = ColumbiaPrimary,
                        inactiveTrackColor = Color.White.copy(alpha = 0.12f)
                    )
                )
                Text("${vm.durationSec}s", color = ColumbiaPrimaryBright, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.CenterHorizontally))

                // Watch ads (placeholder cho phase05)
                GhostButton("Watch 10 ads to create free", Modifier.padding(top = 16.dp).fillMaxWidth(), Icons.Rounded.PlayCircle) {
                    vm.error = "Rewarded ads will be available soon."
                }

                // Generate
                Row(Modifier.padding(top = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column {
                        Text("Generate", color = ColumbiaTextMuted, fontSize = 12.sp)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Rounded.AutoAwesome, null, tint = ColumbiaCreditGold, modifier = Modifier.size(18.dp))
                            Text(" ${vm.cost()}", color = ColumbiaCreditGold, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
                        }
                    }
                    Spacer(Modifier.width(16.dp))
                    GradientButton("Generate", Modifier.weight(1f), Icons.Rounded.AutoAwesome) { vm.generate() }
                }

                Spacer(Modifier.height(120.dp))
            }
        }

        if (vm.generating) LoadingOverlay(vm.stage)

        vm.error?.let { msg ->
            AppDialog(
                title = "Heads up", message = msg, confirmText = "OK",
                onConfirm = { vm.error = null }, onDismiss = { vm.error = null }
            )
        }
        if (vm.notEnoughCredits) {
            AppDialog(
                title = "Not enough credits",
                message = "You need ${vm.cost()} credits for this video. Get more to continue.",
                confirmText = "Get credits",
                onConfirm = { vm.notEnoughCredits = false; nav.navigate("topup") },
                dismissText = "Later",
                onDismiss = { vm.notEnoughCredits = false }
            )
        }
    }
}

@Composable
private fun ToggleSeg(text: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(50)).background(if (on) ColumbiaPrimary else Color.Transparent).clickable { onClick() }.padding(vertical = 12.dp),
        contentAlignment = Alignment.Center
    ) { Text(text, color = if (on) Color.White else ColumbiaTextSecondary, fontWeight = FontWeight.Bold, fontSize = 14.sp) }
}

@Composable
private fun ResBox(res: Resolution, selected: Boolean, locked: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) Brush.linearGradient(listOf(ColumbiaPrimary, ColumbiaPrimaryBright)) else Brush.linearGradient(listOf(ColumbiaSurface, ColumbiaSurface)))
            .border(1.dp, if (selected) Color.Transparent else ColumbiaBorder, RoundedCornerShape(16.dp))
            .clickable { onClick() }
            .padding(vertical = 16.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(res.label, color = if (selected) Color.White else ColumbiaTextPrimary, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            if (locked) { Spacer(Modifier.width(6.dp)); Icon(Icons.Rounded.Lock, null, tint = if (selected) Color.White else ColumbiaTextSecondary, modifier = Modifier.size(16.dp)) }
        }
    }
}
