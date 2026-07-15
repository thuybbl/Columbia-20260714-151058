package com.binarybridge.ai.columbia.features.gallery

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.VideoLibrary
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.binarybridge.ai.columbia.ads.AdsPlacementHolder
import com.binarybridge.ai.columbia.core.PendingMedia
import com.binarybridge.ai.columbia.data.domain.Creation
import com.binarybridge.ai.columbia.data.json.CreationRepo
import com.binarybridge.ai.columbia.ui.components.ColumbiaBackground
import com.binarybridge.ai.columbia.ui.components.GradientButton
import com.binarybridge.ai.columbia.ui.components.ScreenHeader
import com.binarybridge.ai.columbia.ui.components.ads.NativeAdFrame
import com.binarybridge.ai.columbia.ui.theme.*
import java.io.File

@Composable
fun GalleryScreen(nav: NavHostController) {
    val creations by CreationRepo.creations.collectAsState()

    ColumbiaBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            Spacer(Modifier.height(8.dp))
            ScreenHeader("Your Spectrum", "My creations")

            if (creations.isEmpty()) {
                Column(
                    Modifier.fillMaxWidth().padding(top = 140.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Box(
                        Modifier.size(90.dp).clip(CircleShape).background(
                            Brush.radialGradient(listOf(ColumbiaPrimary.copy(alpha = 0.25f), Color.Transparent))
                        ),
                        contentAlignment = Alignment.Center
                    ) { Icon(Icons.Rounded.VideoLibrary, null, tint = ColumbiaPrimaryBright, modifier = Modifier.size(38.dp)) }
                    Spacer(Modifier.height(14.dp))
                    Text("No videos yet", color = ColumbiaTextPrimary, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
                    Spacer(Modifier.height(6.dp))
                    Text("Your generated videos will appear here.", color = ColumbiaTextSecondary, fontSize = 14.sp, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(16.dp))
                    GradientButton("Create a video", icon = Icons.Rounded.AutoAwesome) {
                        PendingMedia.pendingPrompt = ""; nav.navigate("generation?mode=text")
                    }
                }
            } else {
                Spacer(Modifier.height(16.dp))
                creations.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth().padding(bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        row.forEach { item ->
                            CreationCard(Modifier.weight(1f), item) { nav.navigate("result/${item.id}") }
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
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
private fun CreationCard(modifier: Modifier, item: Creation, onClick: () -> Unit) {
    Box(
        modifier.aspectRatio(0.7f).clip(RoundedCornerShape(16.dp)).background(ColumbiaSurface).clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        if (item.thumbPath.isNotBlank() && File(item.thumbPath).exists()) {
            AsyncImage(model = File(item.thumbPath), contentDescription = null, modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(16.dp)))
        } else {
            Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(ColumbiaPrimaryDeep, ColumbiaMagenta))))
        }
        Box(Modifier.size(48.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.4f)), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.PlayArrow, null, tint = Color.White, modifier = Modifier.size(28.dp))
        }
        Text(
            "${item.durationSec}s", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp)
        )
    }
}
