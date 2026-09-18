import java.util.Properties

plugins {
    id("com.android.application")
    // Kotlin is provided by the Flutter Gradle Plugin (Built-in Kotlin), so the
    // app no longer applies the Kotlin Gradle Plugin itself.
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.flet.saludnow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // serious_python loads Python extension modules memory-mapped directly from the
    // APK (no extraction) and ships pure Python in stored asset zips, so
    // `useLegacyPackaging` / `keepDebugSymbols` from earlier Flet templates are no
    // longer needed at minSdk 23+. The `pickFirsts` and `excludes` blocks below
    // address two unrelated multi-source jniLibs issues that AGP can't resolve on
    // its own.
    packaging {
        jniLibs {
            // serious_python_android ships libc++_shared.so as part of the Python runtime payload
            // (the cross-compiled wheels on pypi.flet.dev depend on it at link time). Many third-party
            // Flutter plugins (ultralytics_yolo, sentry_flutter, several ML / CV / audio plugins) also
            // bundle their own copy. When an app pulls in both, Gradle's mergeNativeLibs task aborts
            // with "N files found with path 'lib/<abi>/libc++_shared.so'" because AGP refuses to silently
            // choose between duplicate native libraries (the right default for most .so files).
            //
            // libc++_shared.so is a documented exception: the NDK has held strict ABI compatibility on it
            // since r17, so whichever copy wins input ordering, every consumer that linked against libc++_shared
            // will work against it. pickFirsts is the narrowly-scoped escape hatch for exactly this case -- it
            // only opens a hole for the matching glob; any other future duplicate-native-lib conflict still fails loudly.
            pickFirsts += listOf("**/libc++_shared.so")

// flet: legacy_packaging 

// flet: excluded_abis 
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets["main"].java.srcDir("src/main/kotlin")

    
    

    defaultConfig {
        applicationId = "com.flet.saludnow"
        val resolvedMinSdk = flutter.minSdkVersion
        minSdk = resolvedMinSdk
        val resolvedTargetSdk = flutter.targetSdkVersion
        targetSdk = resolvedTargetSdk
        versionCode = flutterVersionCode
        versionName = flutterVersionName

        println("Gradle build config:")
        println("  minSdkVersion: $resolvedMinSdk")
        println("  targetSdkVersion: $resolvedTargetSdk")
        println("  versionCode: $flutterVersionCode")
        println("  versionName: $flutterVersionName")

// flet: split_per_abi 
        ndk {
            
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
            
        }
// flet: end of split_per_abi 
    }

// flet: android_signing 

    buildTypes {
        release {
// flet: android_signing 
            signingConfig = signingConfigs.getByName("debug")
// flet: end of android_signing 
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {}
