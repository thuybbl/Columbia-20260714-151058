import java.text.SimpleDateFormat
import java.util.Date

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.google.services)
    alias(libs.plugins.firebase.crashlytics)
}

android {
    namespace = "com.binarybridge.ai.columbia"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.binarybridge.ai.columbia"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // [code_base v2] Ads native lib chỉ có bản ARM → giới hạn ABI để tránh crash
        // khởi động trên emulator x86_64 (bài học từ session Calcify, xem HANDOFF mục 4).
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }

        val dateText = SimpleDateFormat("MM.dd.yyyy").format(Date())
        val taskNames = gradle.startParameter.taskNames.joinToString(" ").lowercase()

        val variant = when {
            "release" in taskNames -> "release"
            "debug" in taskNames -> "debug"
            else -> "unknown"
        }

        val formattedName = "${rootProject.name}_${variant}_v${versionName}_v${versionCode}_$dateText"

        project.setProperty("archivesBaseName", formattedName)
    }

    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            manifestPlaceholders["app_id"] = "ca-app-pub-3940256099942544~3347511713"
        }
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            manifestPlaceholders["app_id"] = "ca-app-pub-3850749456614322~8864378632"
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)

    implementation(libs.google.material)
    implementation(libs.androidx.navigation.compose.android)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)

    implementation(libs.androidx.compose.animation)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.kotlinx.serialization.json)
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.0")
    implementation("io.coil-kt:coil-compose:2.6.0")
    implementation("com.airbnb.android:lottie-compose:6.6.2")



    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.android.gms:play-services-ads:25.1.0")
    implementation("com.bbl:module-ads:1.8.9")
    implementation("com.adjust.sdk:adjust-android:5.5.1")
    implementation("com.applovin:applovin-sdk:13.6.0")
    implementation("com.pangle.global:pag-sdk:7.9.1.1") { exclude(group = "com.pangle.global", module = "tiktok-business-android-sdk-comp") }
    implementation("com.google.ads.mediation:pangle:7.9.1.1.0") { exclude(group = "com.pangle.global", module = "tiktok-business-android-sdk-comp") }
    implementation("com.google.ads.mediation:vungle:7.7.1.0")
    implementation("com.google.ads.mediation:applovin:13.6.0.0")
    implementation("com.google.ads.mediation:ironsource:9.3.0.1")
    implementation("com.google.ads.mediation:facebook:6.21.0.1")
    implementation("com.facebook.android:facebook-android-sdk:18.1.3")
    implementation("com.google.ads.mediation:mintegral:17.0.91.0")
    implementation("com.unity3d.ads:unity-ads:4.17.0")
    implementation("com.google.ads.mediation:unity:4.17.0.0")
    implementation("com.github.tiktok:tiktok-business-android-sdk:1.5.0")
    implementation("com.appsflyer:af-android-sdk:6.17.6")
    implementation("com.appsflyer:adrevenue:6.9.1")
    implementation("com.facebook.shimmer:shimmer:0.5.0")

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.analytics)
    implementation(libs.firebase.crashlytics)
    implementation(libs.firebase.config)
}
