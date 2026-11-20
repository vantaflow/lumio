import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signature release : `key.properties` (local, ignoré par git) ou variables
// d'environnement LUMIO_KEYSTORE_FILE / LUMIO_KEYSTORE_PASSWORD /
// LUMIO_KEY_PASSWORD / LUMIO_KEY_ALIAS (CI). Sans rien de tout cela, repli sur
// la clé de debug pour que les builds locaux et la CI des PR fonctionnent.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(prop: String, env: String): String? =
    keyProps.getProperty(prop)?.takeIf { it.isNotBlank() }
        ?: System.getenv(env)?.takeIf { it.isNotBlank() }
val releaseStoreFile = signingValue("storeFile", "LUMIO_KEYSTORE_FILE")
val releaseStorePassword = signingValue("storePassword", "LUMIO_KEYSTORE_PASSWORD")
val releaseKeyPassword = signingValue("keyPassword", "LUMIO_KEY_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "LUMIO_KEY_ALIAS")
val hasReleaseKey = releaseStoreFile != null && releaseStorePassword != null &&
    releaseKeyPassword != null && releaseKeyAlias != null

android {
    namespace = "dev.lumio.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requis par flutter_local_notifications (notifications locales).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.lumio.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // TorrServer est exécuté depuis nativeLibraryDir : les .so doivent
            // être extraits à l'installation, et son binaire Go ne doit pas
            // passer par `strip`.
            useLegacyPackaging = true
            keepDebugSymbols += "**/libtorrserver.so"
            // Build d'une seule architecture (`--target-platform`) : on
            // n'embarque pas le binaire TorrServer de l'autre (~60 Mo).
            val target = project.findProperty("target-platform")?.toString() ?: ""
            if (target == "android-arm") excludes += "**/arm64-v8a/libtorrserver.so"
            if (target == "android-arm64") excludes += "**/armeabi-v7a/libtorrserver.so"
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyPassword = releaseKeyPassword
                keyAlias = releaseKeyAlias
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release")
            else signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
