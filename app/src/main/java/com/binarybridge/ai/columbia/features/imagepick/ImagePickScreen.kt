package com.binarybridge.ai.columbia.features.imagepick

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Image
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import com.binarybridge.ai.columbia.core.PendingMedia
import com.binarybridge.ai.columbia.core.rememberCropFlow
import com.binarybridge.ai.columbia.ui.components.BackTopBar
import com.binarybridge.ai.columbia.ui.components.ColumbiaBackground
import com.binarybridge.ai.columbia.ui.components.GradientButton
import com.binarybridge.ai.columbia.ui.theme.*

@Composable
fun ImagePickScreen(nav: NavHostController) {
    val launchCrop = rememberCropFlow { uri ->
        PendingMedia.croppedImageUri = uri
        nav.navigate("generation?mode=image") { popUpTo("imagepick") { inclusive = true } }
    }

    ColumbiaBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 16.dp)) {
            Box(Modifier.padding(vertical = 8.dp)) { BackTopBar(onBack = { nav.popBackStack() }) }
            Spacer(Modifier.weight(1f))
            Column(Modifier.fillMaxSize().weight(4f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Box(
                    Modifier.size(110.dp).clip(CircleShape).background(
                        Brush.radialGradient(listOf(ColumbiaPrimary.copy(alpha = 0.35f), Color.Transparent))
                    ),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Rounded.Image, null, tint = ColumbiaPrimaryBright, modifier = Modifier.size(48.dp)) }
                Spacer(Modifier.height(16.dp))
                Text("Choose a photo", color = ColumbiaTextPrimary, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
                Spacer(Modifier.height(6.dp))
                Text("Pick an image to bring to life", color = ColumbiaTextSecondary, fontSize = 14.sp, textAlign = TextAlign.Center)
                Spacer(Modifier.height(24.dp))
                GradientButton("Import from gallery", icon = Icons.Rounded.Add) { launchCrop() }
            }
            Spacer(Modifier.weight(1f))
        }
    }
}
