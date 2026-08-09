import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
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
            // WP-529: ad artik SABIT DEGIL, dile gore cozulen bir kaynak.
            // Telefonu Ingilizce olan kullanici magazada "Focus Camp" gorup
            // indiriyordu ama uygulama adi "Odak Kampi" kaliyordu.
            manifestPlaceholders["appName"] = "@string/app_name_stable"
            manifestPlaceholders["authCallbackScheme"] = "com.manilmax.onlinestudyroom"
        }
        create("beta") {
            dimension = "channel"
            applicationIdSuffix = ".beta"
            // Kanalın semver ön-sürüm kimliği release manifestinden gelir
            // (örn. 1.0.42-beta.1); ikinci bir "-beta" suffix eklenmez.
            // Dart: --dart-define=DISTRIBUTION_CHANNEL=githubBeta
            manifestPlaceholders["appName"] = "@string/app_name_beta"
            manifestPlaceholders["authCallbackScheme"] = "com.manilmax.onlinestudyroom.beta"
        }
        create("play") {
            dimension = "channel"
            // applicationIdSuffix yok → com.manilmax.online_study_room (stable ile aynı kimlik)
            // WP-128: Flutter derlemesi FLUTTER_APP_FLAVOR=play enjekte eder; Dart
            // DistributionConfig flavor==play iken define unutulsa bile sideload updater kapalı.
            // --dart-define=DISTRIBUTION_CHANNEL=play hâlâ önerilir (açık niyet / CI).
            manifestPlaceholders["appName"] = "@string/app_name_stable"
            manifestPlaceholders["authCallbackScheme"] = "com.manilmax.onlinestudyroom"
            manifestPlaceholders["distributionChannel"] = "play"
        }
        create("local") {
            dimension = "channel"
            applicationIdSuffix = ".local"
            versionNameSuffix = "-local"
            manifestPlaceholders["appName"] = "@string/app_name_local"
            manifestPlaceholders["authCallbackScheme"] = "com.manilmax.onlinestudyroom.local"
        }

    }

    // Local yalnız geliştirici kimliğidir; beta görsel işaretini tekrar kullanır,
    // gerçek beta ile application id/ad/auth/cache/widget alanı yine ayrıdır.
    sourceSets.getByName("local").res.srcDir("src/beta/res")

    // WP-533: play, stable ile AYNI applicationId'yi tasir
    // (com.manilmax.online_study_room) - ayni marka, ayni ikon. Launcher
    // ikonu @mipmap/ic_launcher (src/main/AndroidManifest.xml:26) yalniz
    // flavor res dizinlerinde duruyor ve src/play/res hic yoktu; play
    // derlemesi kaynak baglamada duserdi.
    // Firebase yapilandirmasi bu yolla VERILEMEZ: google-services eklentisi
    // sourceSets'e degil sabit src/<flavor>/ yollarina bakar (v61 kosumunun
    // hata metni bu listeyi yazar). Bu yuzden src/play/google-services.json
    // ayri bir dosya olarak durur; stable ile birebir ayni kalmasi
    // `scripts/test_all.py --internal-play-firebase` kapisiyla korunur.
    sourceSets.getByName("play").res.srcDir("src/stable/res")

    // Local is intentionally not a registered FCM application. Disable the
    // Google Services processing task only for that developer-only flavor.
    applicationVariants.all {
        if (flavorName == "local") {
            tasks.matching { task ->
                task.name.startsWith("processLocal") &&
                    task.name.endsWith("GoogleServices")
            }.configureEach {
                enabled = false
            }
        }
    }

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
            // key.properties yoksa debug imzasına düşmek yerine release derlemesi
            // durdurulur — ama bu kontrol artık AŞAĞIDA, ÇALIŞMA zamanında yapılır.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// 🔴 WP-580: imza kapısı KONFIGÜRASYON zamanından ÇALIŞMA zamanına alındı.
//
// Eskiden `throw GradleException(...)` doğrudan `buildTypes { release { … } }`
// bloğunun içindeydi. O blok, hangi task çalıştırılırsa çalıştırılsın Gradle
// projeyi yapılandırırken DEĞERLENDİRİLİR. Sonucu: `key.properties` olmayan bir
// makinede `assembleLocalDebug` bile — hatta `--dry-run` bile — "Release imzası
// için android/key.properties gerekli" diyerek düşüyordu.
//
// Bedeli somut ve ölçüldü: CI'daki "Android emülatör smoke (sayaç)" işi,
// WP-572'nin satır-satır kabuk tuzağı düzeltildikten sonra ilk kez gerçekten
// koştu, emülatörü buldu ("Cihaz: emulator-5554") ve tam APK derlemesinde bu
// kapıya çarptı (koşum 31285409925, job 93173161286,
// `Gradle task assembleLocalDebug failed`). Yani sayacı gerçek bir Android
// sürecinde çalıştıran TEK kapı, imzalama sırrı gerektirmeyen bir DEBUG
// derlemesi yüzünden bloklanıyordu. CI'da release anahtarı YOK ve OLMAMALI:
// `local` flavor geliştirici/test derlemesidir.
//
// Yeni kural aynı sertlikte ama doğru yerde: release ARTEFAKTI üreten task
// çalışmadan hemen önce kontrol edilir. Debug derlemeleri etkilenmez, imzasız
// release hâlâ imkânsızdır.
val requireReleaseKeystore = tasks.register("requireReleaseKeystore") {
    group = "verification"
    doLast {
        if (!keystorePropertiesFile.exists()) {
            throw GradleException(
                "Release imzası için android/key.properties gerekli. " +
                    "Debug imzalı release APK/AAB üretimi engellendi."
            )
        }
    }
}

// `package…Release` gerçek paketleme task'ıdır; `assemble`/`bundle` yaşam
// döngüsü task'larıdır. Üçü de bağlanır: hangisi çağrılırsa çağrılsın kapı önce
// koşar. Debug varyantları bilerek EŞLEŞMEZ.
tasks.configureEach {
    if (name.matches(Regex("^(package|assemble|bundle)[A-Za-z]*Release[A-Za-z]*$"))) {
        dependsOn(requireReleaseKeystore)
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
    implementation("androidx.core:core-ktx:1.18.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    testImplementation("junit:junit:4.13.2")
}
