import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing config. Two supported sources, checked in this order:
//
// 1. Local dev: android/key.properties (gitignored — never commit it).
//    storeFile path in that file may be relative to the android/app/
//    module dir or absolute; both are supported below.
//
//      storePassword=...
//      keyPassword=...
//      keyAlias=sprout-upload
//      storeFile=/absolute/path/to/sprout-upload-key.jks
//
// 2. CI (GitHub Actions): env vars, populated from repo secrets. The
//    workflow decodes the base64-encoded keystore secret to a temp file
//    and points ANDROID_KEYSTORE_PATH at it — see build-apk.yml.
//
//      ANDROID_KEYSTORE_PATH
//      ANDROID_KEYSTORE_PASSWORD
//      ANDROID_KEY_ALIAS
//      ANDROID_KEY_PASSWORD
//
// If neither source is present (e.g. a plain `flutter run --release` on a
// machine with no local key.properties and no CI env vars), release builds
// fall back to the debug keystore so local dev workflows keep working —
// but such a build must never be uploaded to Play.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasLocalKeyProperties = keystorePropertiesFile.exists()
if (hasLocalKeyProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val hasCiSigningEnv = System.getenv("ANDROID_KEYSTORE_PATH") != null &&
    System.getenv("ANDROID_KEYSTORE_PASSWORD") != null &&
    System.getenv("ANDROID_KEY_ALIAS") != null &&
    System.getenv("ANDROID_KEY_PASSWORD") != null

val hasReleaseSigning = hasLocalKeyProperties || hasCiSigningEnv

android {
    namespace = "com.sprout.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sprout.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                if (hasLocalKeyProperties) {
                    val storeFilePath = keystoreProperties.getProperty("storeFile")
                    storeFile = file(storeFilePath)
                    storePassword = keystoreProperties.getProperty("storePassword")
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                } else {
                    storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH")!!)
                    storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                    keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                    keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
                }
            }
        }
    }

    buildTypes {
        release {
            // Real upload-key signing when key.properties (local) or the
            // ANDROID_KEYSTORE_* env vars (CI) are present; otherwise falls
            // back to the debug key so `flutter run --release` still works
            // on a machine with no signing config. A debug-signed build
            // must never be uploaded to Play — see build-apk.yml, which
            // only runs the appbundle step when CI signing is configured.
            signingConfig = if (hasReleaseSigning) {
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.android.material:material:1.13.0")
    implementation("androidx.concurrent:concurrent-futures:1.3.0")
}
