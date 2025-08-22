// In android/app/build.gradle.kts

import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.campuspay"

    // ✅ Updated as required by your plugins (path_provider, firebase, etc.)
    compileSdk = (localProperties.getProperty("flutter.compileSdkVersion") ?: "36").toInt()

    // ✅ Match Firebase & Razorpay requirement
    ndkVersion = localProperties.getProperty("flutter.ndkVersion") ?: "27.0.12077973"

    compileOptions {
        // ✅ Bumped to Java 11 (Java 8 is deprecated and was giving warnings)
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.campuspay"

        // ✅ Flutter minimum supported is 23, but warning says 24 is safer
        minSdk = localProperties.getProperty("flutter.minSdkVersion")?.toInt() ?: 24

        // ✅ Align with compileSdk
        targetSdk = localProperties.getProperty("flutter.targetSdkVersion")?.toInt() ?: 36

        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Flutter manages dependencies automatically
}
