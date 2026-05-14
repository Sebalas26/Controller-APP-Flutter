import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val apikeyPropertiesFile = rootProject.file("../../apikey.properties")
val apikeyProperties = Properties()
if (apikeyPropertiesFile.exists()) {
    apikeyProperties.load(apikeyPropertiesFile.inputStream())
}

android {
    namespace = "interrapidisimo.controller_app_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "interrapidisimo.controllerapp"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField(
            "String",
            "ENCRYPT_AES256_PASSWORD_SECRET",
            (apikeyProperties["ENCRYPT_AES256_PASSWORD_SECRET"] as String?) ?: "\"\""
        )
        buildConfigField(
            "String",
            "ENCRYPT_AES256_SALT_SECRET",
            (apikeyProperties["ENCRYPT_AES256_SALT_SECRET"] as String?) ?: "\"\""
        )
        buildConfigField(
            "String",
            "ENCRYPT_AES256_KEY_SECRET",
            (apikeyProperties["ENCRYPT_AES256_KEY_SECRET"] as String?) ?: "\"\""
        )
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
