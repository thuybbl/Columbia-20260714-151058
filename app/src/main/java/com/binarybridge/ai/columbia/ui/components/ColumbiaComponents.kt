package com.binarybridge.ai.columbia.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.VideoLibrary
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.binarybridge.ai.columbia.ui.theme.*

/** Nền chung: màu phủ + 2 vầng radial glow (tím trên-trái, magenta trên-phải). */
@Composable
fun ColumbiaBackground(content: @Composable androidx.compose.foundation.layout.BoxScope.() -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(ColumbiaBackground)
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(ColumbiaGlowViolet.copy(alpha = 0.55f), Color.Transparent),
                        center = Offset(120f, 60f), radius = 900f
                    )
                )
        )
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(ColumbiaGlowMagenta.copy(alpha = 0.5f), Color.Transparent),
                        center = Offset(1200f, 220f), radius = 900f
                    )
                )
        )
        content()
    }
}

val CtaGradient = Brush.linearGradient(listOf(ColumbiaPrimary, ColumbiaPrimaryBright))
val HeroGradient = Brush.linearGradient(listOf(ColumbiaPrimaryDeep, ColumbiaMagenta))

@Composable
fun SectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(), color = ColumbiaPrimaryBright, fontSize = 12.sp,
        fontWeight = FontWeight.Bold, letterSpacing = 2.sp, modifier = modifier
    )
}

@Composable
fun ScreenHeader(label: String, title: String) {
    Column {
        SectionLabel(label)
        Text(title, color = ColumbiaTextPrimary, fontSize = 26.sp, fontWeight = FontWeight.ExtraBold)
    }
}

@Composable
fun CreditPill(credits: Int, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(Color.Black.copy(alpha = 0.4f))
            .border(1.dp, ColumbiaBorder, RoundedCornerShape(50))
            .clickable { onClick() }
            .padding(start = 12.dp, end = 6.dp, top = 6.dp, bottom = 6.dp)
    ) {
        Icon(Icons.Rounded.Bolt, null, tint = ColumbiaCreditGold, modifier = Modifier.size(18.dp))
        Text("$credits", color = ColumbiaTextPrimary, fontWeight = FontWeight.Bold)
        Box(
            Modifier.size(26.dp).clip(CircleShape).background(ColumbiaPrimary),
            contentAlignment = Alignment.Center
        ) { Icon(Icons.Rounded.Add, null, tint = Color.White, modifier = Modifier.size(16.dp)) }
    }
}

@Composable
fun RoundIconButton(icon: ImageVector, onClick: () -> Unit) {
    Box(
        Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(ColumbiaGlass)
            .border(1.dp, ColumbiaBorder, CircleShape)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) { Icon(icon, null, tint = ColumbiaTextPrimary, modifier = Modifier.size(20.dp)) }
}

@Composable
fun BackTopBar(onBack: () -> Unit, trailing: @Composable (() -> Unit)? = null, center: @Composable (() -> Unit)? = null) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        RoundIconButton(Icons.Rounded.ArrowBack, onBack)
        Spacer(Modifier.width(12.dp))
        Box(Modifier.weight(1f)) { center?.invoke() }
        trailing?.invoke()
    }
}

@Composable
fun GradientButton(
    text: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(if (enabled) CtaGradient else Brush.linearGradient(listOf(ColumbiaSurface, ColumbiaSurface)))
            .clickable(enabled = enabled) { onClick() }
            .padding(vertical = 15.dp, horizontal = 20.dp)
    ) {
        if (icon != null) {
            Icon(icon, null, tint = if (enabled) Color.White else ColumbiaTextMuted, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(10.dp))
        }
        Text(text, color = if (enabled) Color.White else ColumbiaTextMuted, fontWeight = FontWeight.Bold, fontSize = 15.sp)
    }
}

@Composable
fun GhostButton(text: String, modifier: Modifier = Modifier, icon: ImageVector? = null, onClick: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .border(1.dp, ColumbiaPrimary, RoundedCornerShape(50))
            .clickable { onClick() }
            .padding(vertical = 14.dp, horizontal = 18.dp)
    ) {
        if (icon != null) {
            Icon(icon, null, tint = ColumbiaPrimaryBright, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp))
        }
        Text(text, color = ColumbiaPrimaryBright, fontWeight = FontWeight.Bold, fontSize = 14.sp)
    }
}

@Composable
fun ColumbiaCard(modifier: Modifier = Modifier, padding: Dp = 16.dp, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier
            .clip(RoundedCornerShape(20.dp))
            .background(ColumbiaSurface)
            .border(1.dp, ColumbiaBorder, RoundedCornerShape(20.dp))
            .padding(padding),
        content = content
    )
}

@Composable
fun OptionCard(icon: ImageVector, label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(
        modifier
            .heightIn(min = 120.dp)
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
        Text(label, color = ColumbiaTextPrimary, fontWeight = FontWeight.Bold, fontSize = 16.sp)
    }
}

@Composable
fun ChoiceChip(text: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(if (selected) ColumbiaPrimary else Color.Transparent)
            .border(1.dp, if (selected) ColumbiaPrimary else ColumbiaBorder, RoundedCornerShape(50))
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) { Text(text, color = if (selected) Color.White else ColumbiaTextPrimary, fontSize = 14.sp, fontWeight = FontWeight.Medium) }
}

@Composable
fun ColumbiaFab(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier
            .size(64.dp)
            .clip(CircleShape)
            .background(CtaGradient)
            .border(3.dp, ColumbiaPrimaryBright.copy(alpha = 0.5f), CircleShape)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) { Icon(Icons.Rounded.AutoAwesome, null, tint = Color.White, modifier = Modifier.size(28.dp)) }
}

enum class MainTab { HOME, GALLERY, PROFILE }

@Composable
fun BottomNavBar(current: MainTab, onSelect: (MainTab) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .fillMaxWidth()
            .height(74.dp)
            .clip(RoundedCornerShape(26.dp))
            .background(ColumbiaBackgroundElevated.copy(alpha = 0.95f))
            .border(1.dp, ColumbiaBorder, RoundedCornerShape(26.dp)),
        horizontalArrangement = Arrangement.SpaceAround,
        verticalAlignment = Alignment.CenterVertically
    ) {
        NavItem(Icons.Rounded.Home, "Home", current == MainTab.HOME) { onSelect(MainTab.HOME) }
        NavItem(Icons.Rounded.VideoLibrary, "Gallery", current == MainTab.GALLERY) { onSelect(MainTab.GALLERY) }
        NavItem(Icons.Rounded.Person, "Profile", current == MainTab.PROFILE) { onSelect(MainTab.PROFILE) }
    }
}

@Composable
private fun NavItem(icon: ImageVector, label: String, selected: Boolean, onClick: () -> Unit) {
    val c = if (selected) ColumbiaPrimaryBright else ColumbiaTextSecondary
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.clip(RoundedCornerShape(12.dp)).clickable { onClick() }.padding(8.dp)
    ) {
        Icon(icon, null, tint = c, modifier = Modifier.size(22.dp))
        Text(label, color = c, fontSize = 12.sp)
    }
}

@Composable
fun LoadingOverlay(stage: String) {
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.75f)),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(color = ColumbiaPrimaryBright)
            Spacer(Modifier.height(20.dp))
            Text(stage, color = ColumbiaTextPrimary, fontWeight = FontWeight.Bold, fontSize = 16.sp, textAlign = TextAlign.Center)
            Spacer(Modifier.height(6.dp))
            Text("This can take up to a minute", color = ColumbiaTextSecondary, fontSize = 13.sp)
        }
    }
}

@Composable
fun AppDialog(
    title: String,
    message: String,
    confirmText: String,
    onConfirm: () -> Unit,
    dismissText: String? = null,
    onDismiss: () -> Unit,
) {
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.6f)).clickable(enabled = false) {},
        contentAlignment = Alignment.Center
    ) {
        ColumbiaCard(Modifier.fillMaxWidth().padding(32.dp), padding = 20.dp) {
            Text(title, color = ColumbiaTextPrimary, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            Spacer(Modifier.height(10.dp))
            Text(message, color = ColumbiaTextSecondary, fontSize = 14.sp)
            Spacer(Modifier.height(18.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                if (dismissText != null) {
                    GhostButton(dismissText, Modifier.weight(1f), onClick = onDismiss)
                }
                GradientButton(confirmText, Modifier.weight(1f), onClick = onConfirm)
            }
        }
    }
}
