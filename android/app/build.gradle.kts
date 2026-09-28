// ANDROID: cấu hình đóng gói và ký app học viên để phát hành lên Google Play.
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// android/key.properties chứa storeFile, storePassword, keyAlias, keyPassword.
// File này bị loại khỏi Git. storeFile là đường dẫn tuyệt đối hoặc từ android/.
val releaseKeys = Properties()
val releaseKeysFile = rootProject.file("key.properties")
if (releaseKeysFile.isFile) {
    releaseKeysFile.inputStream().use { releaseKeys.load(it) }
}
val releaseStoreFile = releaseKeys.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }

// Chỉ kiểm tra khóa khi chạy task release; debug không cần khóa phát hành.
val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    group = "verification"
    description = "Checks release signing inputs without building the app."
    doLast {
        val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        val missingKeys = requiredKeys.filter { releaseKeys.getProperty(it).isNullOrBlank() }
        check(missingKeys.isEmpty()) {
            "Chua cau hinh khoa phat hanh. Dien android/key.properties: " +
                missingKeys.joinToString(", ") + ". Khong dung debug key de phat hanh."
        }
        check(releaseStoreFile?.isFile == true) {
            "Khong tim thay keystore. Kiem tra storeFile trong android/key.properties."
        }
        check(releaseKeys.getProperty("keyAlias") != "androiddebugkey") {
            "Khong duoc dung alias androiddebugkey cho ban phat hanh."
        }
    }
}

android {
    namespace = "com.example.e09_elearning"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Giữ mã chủ dự án đã chọn; đổi mã phải đồng bộ Firebase Android.
        applicationId = "com.example.e09_elearning"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = releaseStoreFile
            storePassword = releaseKeys.getProperty("storePassword")
            keyAlias = releaseKeys.getProperty("keyAlias")
            keyPassword = releaseKeys.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            // Không tự dùng debug key khi chưa cấu hình khóa chính thức.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" || it.name == "validateSigningRelease" }
    .configureEach { dependsOn(verifyReleaseSigning) }

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
