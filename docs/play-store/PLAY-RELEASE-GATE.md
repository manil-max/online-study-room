# Play Release Gate

> **Durum tazelendi: 2026-08-08 (v60 sonrası).** Aşağıdaki tablo WP-124'ten
> beri boş şablon olarak duruyordu; bu tur her satır **kodda doğrulanarak**
> güncellendi. Tik atılan satırın yanında dayanağı yazılıdır. Tik atılmayan
> satır "yapılacak" demektir, "bilinmiyor" demez.

## Kod tarafı — bende olan işler

| Kapı | Durum | Dayanak / eksik olan |
|---|---|---|
| Play installer izolasyonu (uygulama içi APK güncellemesi Play sürümünde kapalı) | ✅ | `play` flavor var (`app/android/app/build.gradle.kts:159`) ve dağıtım kanalı `DISTRIBUTION_CHANNEL` ile ayrılıyor; define unutulursa kanal **play**'e düşer, yani güvenli taraf varsayılan (`distribution_channel.dart:12`) |
| Hesap silme (uygulama içi + 14 gün grace + purge) | ✅ | `account_settings_screen.dart:183`, migration `0113`/`0114`; staging'de aktive, health=configured |
| UGC bildir / engelle / engellenenler listesi | ✅ | `report_sheet.dart`, `block_user_action.dart`, `blocked_users_screen.dart`; mesajda uzun bas → bildir/engelle (`class_chat_card.dart:200`) |
| targetSdk seviyesi | ✅ | `targetSdk = flutter.targetSdkVersion` → Flutter varsayılanı (şu an 36); Play eşiğinin üstünde |
| Üretim migration zinciri | ✅ | head **0123**, staging+production ikisi de post-check 0123 |
| **AAB (app bundle) üretimi** | ❌ | `release.yml:122` yalnız `flutter build apk` koşuyor. Play yeni uygulamada **AAB** ister. `play` flavor'ı hiçbir workflow **hiç derlemiyor** — yani bugün Play'e yüklenecek bir artefakt yok ve o flavor'ın derlendiği bile ölçülmemiş. |
| **Canlı yasal site (HTTPS)** | ❌ | Metinler repoda var (`docs/legal/PRIVACY-POLICY.*`, `TERMS-OF-USE.*`, `COMMUNITY-GUIDELINES.*`) ama **yayınlanmış bir URL yok**: `LEGAL_BASE_URL` hiçbir env dosyasında ve hiçbir workflow'da tanımlı değil. Play formu gizlilik politikası URL'si **zorunlu** ister; veri silme URL'si de istenir. |
| Cihaz QA matrisi (P0=0) | 🟡 | Yalnız sahibin telefonu + bir API 33 emülatörü. Farklı Android sürümü/marka kapsanmadı. |
| Rollback / ileri düzeltme planı | 🟡 | Migration tarafı yazılı (her migration başlığında rollback), ama Play'de **staged rollout + halt** akışı hiç denenmedi. |

## Sahip tarafı — Console'da benim yapamayacaklarım

| İş | Not |
|---|---|
| Play Console geliştirici hesabı | Tek seferlik ücret + kimlik doğrulama. Hesap açılmadan aşağıdakilerin hiçbiri başlamaz. |
| **Kapalı test şartı** | Yeni **kişisel** geliştirici hesaplarında Google, üretime çıkmadan önce belirli sayıda test kullanıcısıyla belirli bir süre kapalı test koşulmasını şart koşuyor. Bu **Google'ın şartı**, bizim beta turumuz değil — "betayı atlıyoruz" kararı GitHub kanalımız içindi ve geçerli; bu ayrı bir kapı. Kesin sayı/süre hesap açılırken Console'da yazılı görünür, oradan okunmalı. |
| Data safety formu | Satır satır `docs/play-store/DATA-SAFETY.md` tablosundan doldurulur. |
| İçerik derecelendirme anketi | Sohbet + kullanıcı içeriği olduğu için UGC beyanı ile tutarlı doldurulmalı. |
| Store listing görselleri | Uygulama ikonu, öne çıkan grafik, telefon ekran görüntüleri. Repoda **hazır listing görseli yok** (`references/app icon` dışında). |
| İmzalama anahtarı yedeği | `key.jks` CI'da `KEYSTORE_BASE64` secret'ı olarak duruyor. **Çevrimdışı ikinci bir kopya sahipte olmalı** — anahtar kaybolursa aynı uygulama bir daha güncellenemez. |

## Sıra (önerilen)

1. **Sahip:** Play Console hesabını aç. Kapalı test şartının kesin sayısı ve
   süresi ancak orada okunur; plan ona göre kurulur.
2. **Ben:** AAB yolunu kur — `play` flavor'ı için `flutter build appbundle`,
   release workflow'una ayrı bir iş ve preflight kapısı. Bu iş bugün
   **hiç yok**, en büyük kod boşluğu bu.
3. **Ben:** Yasal metinleri canlı bir HTTPS adrese koy ve `LEGAL_BASE_URL`'i
   ortam dosyalarına bağla. Play formu bu URL olmadan kaydedilemez.
4. **Sahip + ben:** Data safety + içerik derecelendirme + listing.
5. **Ben:** Staged rollout (10% → 25% → 50% → 100%) ve halt runbook'u.

**GO şartı:** yukarıdaki ❌ ve 🟡 satırların hepsi kapanır **ve** sahip imzası.
