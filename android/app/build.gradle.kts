import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseProperties = Properties()
val releasePropertiesFile = rootProject.file("key.properties")
if (releasePropertiesFile.exists()) {
    releasePropertiesFile.inputStream().use { releaseProperties.load(it) }
}
val releaseApplicationId = providers.gradleProperty("resthouseApplicationId")
    .orNull ?: releaseProperties.getProperty("applicationId")
val allowLegacyId = providers.gradleProperty("resthouseAllowLegacyId").orNull == "true"
val unsignedRelease = providers.gradleProperty("resthouseUnsignedRelease").orNull == "true"
val signingFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseSigning = signingFields.all { !releaseProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.example.resthouse_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Keep the installed app identity for debug and legacy migrations.
        applicationId = releaseApplicationId ?: "com.example.resthouse_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning && !unsignedRelease) {
            create("release") {
                storeFile = rootProject.file(releaseProperties.getProperty("storeFile"))
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning && !unsignedRelease) signingConfigs.getByName("release") else null
        }
    }
}

val validateReleaseConfiguration = tasks.register("validateReleaseConfiguration") {
    doLast {
        if (releaseApplicationId.isNullOrBlank() ||
            (releaseApplicationId.startsWith("com.example.") && !allowLegacyId)) {
            throw GradleException("Set applicationId in android/key.properties, or -PresthouseApplicationId. Existing installs may explicitly use -PresthouseAllowLegacyId=true with their original signing key.")
        }
        if (!unsignedRelease && !hasReleaseSigning) {
            throw GradleException("Release signing is required. Copy android/key.properties.example to android/key.properties and configure your signing key. For build verification only, use -PresthouseUnsignedRelease=true.")
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseConfiguration)
}

flutter {
    source = "../.."
}
