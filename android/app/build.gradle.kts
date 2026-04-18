plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dazeddingo.trail"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.dazeddingo.trail"
        // workmanager + flutter_local_notifications + flutter_secure_storage
        // all need at least API 23 in practice.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Debug signing for now — CI restores a pinned debug keystore
            // from DEBUG_KEYSTORE_B64 so the signing SHA is stable across
            // releases (matches the watchnext pattern).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // flutter_local_notifications uses java.time APIs — core library
    // desugaring lets them work on minSdk 23.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")

    // androidx.work is no longer exported transitively by workmanager 0.9.x
    // (was an `api` dep in 0.5.x, now `implementation`). BootReceiver.kt
    // references WorkManager / OneTimeWorkRequestBuilder / ExistingWorkPolicy
    // directly, so we need to declare it ourselves. Version pinned to match
    // workmanager_android-0.9.0+2's transitive dep to avoid double-classpath
    // surprises.
    implementation("androidx.work:work-runtime-ktx:2.10.2")
}

flutter {
    source = "../.."
}
