package com.binarybridge.ai.columbia.features.result

import android.content.Intent
import android.widget.VideoView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.FileProvider
import androidx.navigation.NavHostController
import com.binarybridge.ai.columbia.core.file.FileManager
import com.binarybridge.ai.columbia.data.json.CreationRepo
import com.binarybridge.ai.columbia.ui.components.BackTopBar
import com.binarybridge.ai.columbia.ui.components.ChoiceChip
import com.binarybridge.ai.columbia.ui.components.ColumbiaBackground
import com.binarybridge.ai.columbia.ui.components.GhostButton
import com.binarybridge.ai.columbia.ui.components.GradientButton
import com.binarybridge.ai.columbia.ui.theme.*
import kotlinx.coroutines.launch
import java.io.File

@Composable
fun ResultScreen(nav: NavHostController, id: String) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val creation = remember(id) { CreationRepo.byId(id) }
    var toast by remember { mutableStateOf<String?>(null) }

    ColumbiaBackground {
        if (creation == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Video not found", color = ColumbiaTextSecondary)
            }
            return@ColumbiaBackground
        }

        Column(
            Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
        ) {
            Box(Modifier.padding(vertical = 8.dp)) {
                BackTopBar(onBack = { nav.popBackStack() }, center = {
                    Text("Your video", color = ColumbiaTextPrimary, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                })
            }

            AndroidView(
                factory = { c ->
                    VideoView(c).apply {
                        setVideoPath(creation.videoPath)
                        setOnPreparedListener { mp -> mp.isLooping = true; start() }
                    }
                },
                modifier = Modifier.fillMaxWidth().height(420.dp).clip(RoundedCornerShape(20.dp)).background(androidx.compose.ui.graphics.Color.Black)
            )

            Column(
                Modifier.padding(top = 16.dp).fillMaxWidth().clip(RoundedCornerShape(20.dp))
                    .background(ColumbiaSurface).border(1.dp, ColumbiaBorder, RoundedCornerShape(20.dp)).padding(16.dp)
            ) {
                Text("Prompt", color = ColumbiaTextSecondary, fontSize = 13.sp)
                Spacer(Modifier.height(6.dp))
                Text(creation.prompt, color = ColumbiaTextPrimary, fontSize = 15.sp)
                Row(Modifier.padding(top = 12.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    ChoiceChip(creation.resolution, false) {}
                    ChoiceChip(creation.ratio, false) {}
                    ChoiceChip("${creation.durationSec}s", false) {}
                }
            }

            Row(Modifier.padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                GhostButton("Save", Modifier.weight(1f), Icons.Rounded.Download) {
                    scope.launch {
                        val ok = FileManager.saveVideoToGallery(File(creation.videoPath), "Columbia_${creation.id.take(6)}")
                        toast = if (ok) "Saved to gallery" else "Save failed"
                    }
                }
                GhostButton("Share", Modifier.weight(1f), Icons.Rounded.Share) {
                    try {
                        val uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.fileprovider", File(creation.videoPath))
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "video/mp4"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        ctx.startActivity(Intent.createChooser(send, "Share video"))
                    } catch (e: Exception) { toast = "Share failed" }
                }
            }
            GradientButton("Create another", Modifier.padding(top = 12.dp).fillMaxWidth(), Icons.Rounded.AutoAwesome) {
                nav.navigate("home") { popUpTo("home") { inclusive = false } }
            }
            toast?.let { Text(it, color = ColumbiaSuccess, modifier = Modifier.padding(top = 12.dp)) }
            Spacer(Modifier.height(120.dp))
        }
    }
}
