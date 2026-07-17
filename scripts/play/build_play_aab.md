# Play AAB üretim notu (WP-122)

## ⛔ Release blocker

**Mevcut `version: 1.0.29+29` — versionCode 29.**  
Play’e yeni AAB yüklemeden **önce** `+BUILD` artırılmalı (aynı versionCode reddedilir / güncelleme engeli).  
Ajan bu dosyada versionCode **artırmaz**.

Gereksinimler: `app/env.json` (dart-define), release keystore (`key.jks` / `key.properties` — **commit edilmez**), Android SDK, JDK.

## Version kuralı

1. `app/pubspec.yaml` → `version: X.Y.Z+BUILD`  
2. BUILD = versionCode; **yüklemeden önce artır** (şu an `1.0.29+29` = **blocker**).  
3. Tag ile hizala (`vN` / `beta-vN`).

## Komut (Windows)

```bat
cd app
flutter clean
flutter pub get
flutter build appbundle --flavor play --release --dart-define-from-file=env.json
```

Çıktı: `build/app/outputs/bundle/playRelease/app-play-release.aab`

## Doğrulama

```bat
jarsigner -verify -verbose -certs build\app\outputs\bundle\playRelease\app-play-release.aab
```

- applicationId: `com.manilmax.online_study_room` (play flavor suffix yok)  
- Installer permission: play flavor’da yok (WP-110/128)

## Ajan sınırı

Bu script/doc **upload etmez**. Sahip Play Console’a yükler.
