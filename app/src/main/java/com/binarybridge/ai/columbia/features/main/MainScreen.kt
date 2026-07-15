package com.binarybridge.ai.columbia.features.main

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.binarybridge.ai.columbia.features.gallery.GalleryScreen
import com.binarybridge.ai.columbia.features.generation.GenerationScreen
import com.binarybridge.ai.columbia.features.home.HomeScreen
import com.binarybridge.ai.columbia.features.imagepick.ImagePickScreen
import com.binarybridge.ai.columbia.features.language.LanguageScreen
import com.binarybridge.ai.columbia.features.paywall.PaywallScreen
import com.binarybridge.ai.columbia.features.profile.ProfileScreen
import com.binarybridge.ai.columbia.features.result.ResultScreen
import com.binarybridge.ai.columbia.features.settings.SettingsScreen
import com.binarybridge.ai.columbia.features.topup.TopUpScreen
import com.binarybridge.ai.columbia.ui.components.BottomNavBar
import com.binarybridge.ai.columbia.ui.components.ColumbiaFab
import com.binarybridge.ai.columbia.ui.components.MainTab

@Composable
fun MainScreen() {
    val nav = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val route = backStack?.destination?.route
    val onTab = route == "home" || route == "gallery" || route == "profile"

    fun openGeneration(mode: String) = nav.navigate("generation?mode=$mode")

    Box(Modifier.fillMaxSize()) {
        NavHost(
            navController = nav,
            startDestination = "home",
            enterTransition = { EnterTransition.None },
            exitTransition = { ExitTransition.None },
        ) {
            composable("home") { HomeScreen(nav) }
            composable("gallery") { GalleryScreen(nav) }
            composable("profile") { ProfileScreen(nav) }
            composable(
                "generation?mode={mode}",
                arguments = listOf(navArgument("mode") { type = NavType.StringType; defaultValue = "text" })
            ) { entry ->
                GenerationScreen(nav, entry.arguments?.getString("mode") ?: "text")
            }
            composable("imagepick") { ImagePickScreen(nav) }
            composable(
                "result/{id}",
                arguments = listOf(navArgument("id") { type = NavType.StringType })
            ) { entry -> ResultScreen(nav, entry.arguments?.getString("id") ?: "") }
            composable("settings") { SettingsScreen(nav) }
            composable("topup") { TopUpScreen(nav) }
            composable("paywall") { PaywallScreen(nav) }
            composable("language") { LanguageScreen(selectRegion = false, onNext = { nav.popBackStack() }) }
        }

        if (onTab) {
            val current = when (route) {
                "gallery" -> MainTab.GALLERY
                "profile" -> MainTab.PROFILE
                else -> MainTab.HOME
            }
            ColumbiaFab(
                onClick = { openGeneration("text") },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .navigationBarsPadding()
                    .padding(end = 18.dp, bottom = 104.dp)
            )
            BottomNavBar(
                current = current,
                onSelect = { tab ->
                    val dest = when (tab) {
                        MainTab.HOME -> "home"; MainTab.GALLERY -> "gallery"; MainTab.PROFILE -> "profile"
                    }
                    if (dest != route) nav.navigate(dest) {
                        popUpTo("home") { saveState = true }
                        launchSingleTop = true
                        restoreState = true
                    }
                },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
                    .padding(start = 16.dp, end = 16.dp, bottom = 16.dp)
            )
        }
    }
}
