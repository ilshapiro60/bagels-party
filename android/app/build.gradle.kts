plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: Codemagic sets CI=true and CM_* (see
// https://docs.codemagic.io/code-signing-yaml/signing-android/ ).
// Locally, use android/key.properties (gitignored) per
// https://docs.flutter.dev/deployment/android#signing-the-app
//
// Do not use java.util.Properties.load() for this file: on Windows, paths like
// C:\Users\... are parsed as unicode escapes and fail with "Malformed \uxxxx encoding".
fun loadLocalKeyProperties(file: java.io.File): Map<String, String> {
    if (!file.exists()) return emptyMap()
    return file.bufferedReader().useLines { lines ->
        lines.mapNotNull { line ->
            val t = line.trim()
            if (t.isEmpty() || t.startsWith("#")) return@mapNotNull null
            val eq = t.indexOf('=')
            if (eq <= 0) return@mapNotNull null
            val key = t.substring(0, eq).trim()
            val value = t.substring(eq + 1).trim().trim('"')
            key to value
        }.toMap()
    }
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = loadLocalKeyProperties(keystorePropertiesFile)

android {
    namespace = "com.pawparty.paw_party"
    buildFeatures {
        buildConfig = true
    }
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
        applicationId = "com.pawparty.paw_party"
        // Places SDK 5.x requires API 24 (Android 7.0); covers 99%+ of active devices.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (System.getenv("CI") == "true") {
                storeFile = file(System.getenv("CM_KEYSTORE_PATH")!!)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")!!
                keyAlias = System.getenv("CM_KEY_ALIAS")!!
                keyPassword = System.getenv("CM_KEY_PASSWORD")!!
            } else if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"]!!
                keyPassword = keystoreProperties["keyPassword"]!!
                storeFile = rootProject.file(keystoreProperties["storeFile"]!!)
                storePassword = keystoreProperties["storePassword"]!!
            }
        }
    }

    buildTypes {
        release {
            val useReleaseKeystore =
                System.getenv("CI") == "true" || keystorePropertiesFile.exists()
            signingConfig =
                if (useReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Debug-only: release must not bundle firebase-appcheck-debug (startup crashes if the
    // ContentProvider references stripped/missing debug classes). Release uses Play Integrity from Dart.
    implementation(platform("com.google.firebase:firebase-bom:33.14.0"))
    debugImplementation("com.google.firebase:firebase-appcheck-debug")
    // Native Places SDK (New) — Nearby Search for vet clinic picker.
    implementation("com.google.android.libraries.places:places:5.1.1")
}
