import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// İmzalama bilgileri android/key.properties dosyasından okunur (repoya commit edilmez).
// CI ortamında bu dosya GitHub Secrets'tan üretilir.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun decodeDartDefines(raw: String?): Map<String, String> {
    if (raw.isNullOrBlank()) return emptyMap()
    return raw.split(',').associate { encoded ->
        val decoded = try {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        } catch (_: IllegalArgumentException) {
            throw GradleException("Dart define manifesti çözümlenemedi.")
        }
        val separator = decoded.indexOf('=')
        if (separator <= 0) {
            throw GradleException("Dart define manifestinde geçersiz kayıt var.")
        }
        decoded.substring(0, separator) to decoded.substring(separator + 1)
    }
}

fun validateEnvironmentIdentity(flavor: String, defines: Map<String, String>) {
    fun required(name: String): String = defines[name]?.trim().orEmpty().ifEmpty {
        throw GradleException("$flavor artefaktı için $name zorunlu.")
    }

    val expectedChannel = when (flavor) {
        "local" -> "local"
        "beta" -> "beta"
        "stable", "play" -> "stable"
        else -> throw GradleException("Bilinmeyen Android flavor: $flavor")
    }
    val expectedEnvironment = when (flavor) {
        "local" -> "local"
        "beta" -> "staging"
        else -> "production"
    }
    if (required("CHANNEL").lowercase() != expectedChannel ||
        required("APP_ENVIRONMENT").lowercase() != expectedEnvironment
    ) {
        throw GradleException("$flavor kanal/backend eşleşmesi güvenli değil.")
    }

    val commit = required("GIT_COMMIT_SHA").lowercase()
    val validCommit = if (flavor == "local") {
        commit == "local-dev" || Regex("^[0-9a-f]{7,40}$").matches(commit)
    } else {
        Regex("^[0-9a-f]{7,40}$").matches(commit)
    }
    if (!validCommit || !Regex("^\\d{4}$").matches(required("MIGRATION_HEAD"))) {
        throw GradleException("Build commit/migration kimliği geçersiz.")
    }

    val url = defines["SUPABASE_URL"]?.trim().orEmpty()
    val anonKey = defines["SUPABASE_ANON_KEY"]?.trim().orEmpty()
    if (flavor == "local" &&
        defines["ALLOW_IN_MEMORY"]?.lowercase() == "true" &&
        url.isEmpty() &&
        anonKey.isEmpty()
    ) {
        return
    }
    if (url.isEmpty() || anonKey.isEmpty()) {
        throw GradleException("$flavor artefaktı için Supabase client ayarları zorunlu.")
    }
    val selectedRef = required("SUPABASE_PROJECT_REF").lowercase()
    if (anonKey.lowercase().startsWith("sb_secret_") ||
        anonKey.lowercase().contains("service_role")
    ) {
        throw GradleException("İstemci build'inde service-role/secret key kullanılamaz.")
    }

    if (flavor == "local") {
        if (selectedRef != "local" ||
            !(url.startsWith("http://127.0.0.1:54321") ||
                url.startsWith("http://localhost:54321"))
        ) {
            throw GradleException("Local flavor yalnız local Supabase'e bağlanabilir.")
        }
        return
    }

    val stagingRef = required("STAGING_SUPABASE_PROJECT_REF").lowercase()
    val productionRef = required("PRODUCTION_SUPABASE_PROJECT_REF").lowercase()
    val refPattern = Regex("^[a-z0-9]{20}$")
    if (!refPattern.matches(stagingRef) ||
        !refPattern.matches(productionRef) ||
        stagingRef == productionRef
    ) {
        throw GradleException("Staging/production project-ref matrisi geçersiz.")
    }
    val expectedRef = if (flavor == "beta") stagingRef else productionRef
    val forbiddenRef = if (flavor == "beta") productionRef else stagingRef
    if (selectedRef != expectedRef ||
        selectedRef == forbiddenRef ||
        url != "https://$selectedRef.supabase.co"
    ) {
        throw GradleException("$flavor yanlış Supabase projesine yönlendiriliyor.")
    }
}

android {
    namespace = "com.manilmax.online_study_room"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.manilmax.online_study_room"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Yayın kanalları:
    // - stable / beta: GitHub sideload (APK + REQUEST_INSTALL_PACKAGES)
    // - play: Play Store AAB (installer izni yok; aynı applicationId = stable)
    // WP-110: play ve stable aynı paket kimliği → yan yana kurulamaz (bilinçli).
    flavorDimensions += "channel"
    productFlavors {
        create("stable") {
            dimension = "channel"
            // Dart tarafı: --dart-define=DISTRIBUTION_CHANNEL=githubStable (CI release.yml)
            manifestPlaceholders["appName"] = "Odak Kampı"
            manifestPlaceholders["authCallbackScheme"] = "com.manilmax.onlinestudyroom"
        }
        create("beta") {
            dimension = "channel"
            applicationIdSuffix = ".beta"
            versionNameSuffix = "-beta"
            // Dart: --dart-define=DISTRIBUTION_CHANNEL=githubBeta
            manifestPlaceholders["appName"] = "Odak Kampı BETA TEST"
            manifestPlaceholders["authCallbackScheme"] = "com.manilmax.onlinestudyroom.beta"
        }
        create("play") {
            dimension = "channel"
            // applicationIdSuffix yok → com.manilmax.online_study_room (stable ile aynı kimlik)
            // WP-128: Flutter derlemesi FLUTTER_APP_FLAVOR=play enjekte eder; Dart
            // DistributionConfig flavor==play iken define unutulsa bile sideload updater kapalı.
            // --dart-define=DISTRIBUTION_CHANNEL=play hâlâ önerilir (açık niyet / CI).
            manifestPlaceholders["appName"] = "Odak Kampı"
            manifestPlaceholders["authCallbackScheme"] = "com.manilmax.onlinestudyroom"
            manifestPlaceholders["distributionChannel"] = "play"
        }
        create("local") {
            dimension = "channel"
            applicationIdSuffix = ".local"
            versionNameSuffix = "-local"
            manifestPlaceholders["appName"] = "Odak Kampı LOCAL"
            manifestPlaceholders["authCallbackScheme"] = "com.manilmax.onlinestudyroom.local"
        }

    }

    // Local yalnız geliştirici kimliğidir; beta görsel işaretini tekrar kullanır,
    // gerçek beta ile application id/ad/auth/cache/widget alanı yine ayrıdır.
    sourceSets.getByName("local").res.srcDir("src/beta/res")

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // storeFile, android/ klasörüne (rootProject) göre çözülür.
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Yayınlanan TÜM APK'lar aynı kalıcı release anahtarıyla imzalanmalı.
            // key.properties yoksa debug imzasına düşmek yerine release derlemesini durdur.
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "Release imzası için android/key.properties gerekli. " +
                        "Debug imzalı release APK üretimi engellendi."
                )
            }
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Flutter artefaktı üreten task'tan önce kanal/backend manifestini doğrula.
// compileStableDebugKotlin gibi yalnız native derleme task'ları bu kapıya bağlı
// değildir; APK/AAB üreten compileFlutterBuild* zinciri bağlıdır.
listOf("local", "beta", "stable", "play").forEach { flavor ->
    val capitalizedFlavor = flavor.replaceFirstChar { it.uppercase() }
    val validationTask = tasks.register("validate${capitalizedFlavor}Environment") {
        group = "verification"
        doLast {
            val defines = decodeDartDefines(project.findProperty("dart-defines")?.toString())
            validateEnvironmentIdentity(flavor, defines)
        }
    }
    tasks.configureEach {
        if (name.startsWith("compileFlutterBuild$capitalizedFlavor")) {
            dependsOn(validationTask)
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
