# Play Store Hazırlık Taraması — Odak Kampı

**Tarih:** 2026-07-17  
**Kapsam:** Kod tabanı + şema + edge + izinler + politika + ops + açık WP’ler  
**Yöntem:** Statik analiz (cihaz/Play Console erişimi yok). Runtime kanıtı olmayan maddeler **olası / doğrula** etiketlidir.  
**Kural:** Bu belge yalnız rapordur. **Kod, commit, build, push yapılmadı.**

**Sürüm anlık görüntüsü (kod):**
| Alan | Değer |
|---|---|
| `version` | `1.0.29+29` (`app/pubspec.yaml`) |
| `applicationId` (stable) | `com.manilmax.online_study_room` |
| Beta flavor | `…online_study_room.beta` + `-beta` |
| Son güvenlik/ops commit’leri | WP-103…109 (FGS, presence, XP tetik, migration 0034–0036, edge auth) |
| Son migration dosyası | `0036_security_hardening.sql` |

---

## 1) Yönetici özeti

### Genel yargı

Uygulama **ürün olarak olgun** (sayaç, grup, istatistik, widget, alarm, l10n, RLS, XP ledger).  
**Play Store “GO” için henüz hazır sayılmaz.** Engelleyici maddeler çoğunlukla **politika + yasal + cihaz kanıtı + backend deploy**, yalnızca “eksik özellik” değil.

### Risk skoru (özet)

| Alan | Skor | Not |
|---|---|---|
| Play politikası (izinler / güncelleme / hesap silme) | 🔴 Yüksek | Birden fazla ret riski |
| Gizlilik / KVKK / Data safety | 🔴 Yüksek | Politika URL’si + silme + form |
| Kararlılık (cihaz) | 🟠 Orta–Yüksek | WP-103 kodda; **cihaz QA yok** |
| Güvenlik (sunucu) | 🟡 Orta | 0035–0036 **kodda**; prod’a uygulanmış mı bilinmiyor |
| İçerik / UGC | 🟡 Orta | Sınıf sohbeti + açık grup |
| Teknik kalite / test | 🟢 Orta–İyi | Geniş test paketi; tam CI/soak belirsiz |
| Mağaza listesi / varlıklar | ⚪ Bilinmiyor | Repo dışında |

### Top 10 engel (önce bunlar)

1. **Hesap silme yolu yok** (Play: hesap oluşturan uygulamalarda uygulama içi silme zorunlu) — WP-66 yalnız karar taslağı.  
2. **GitHub APK in-app updater + `REQUEST_INSTALL_PACKAGES`** — Play dışından APK kurdurma politikaya aykırı; Play sürümünde kapatılmalı / Play In-App Updates’e geçilmeli.  
3. **Gizlilik politikası URL’si** (web + uygulama içi link) eksik görünüyor.  
4. **Data safety formu** doldurulmamış (repo’da form yok; Console işi).  
5. **Kısıtlı izin beyanları:** `USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `FOREGROUND_SERVICE_SPECIAL_USE`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — Console form + gerekçe şart; aksi ret.  
6. **WP-103 Android ≤13 FGS çökmesi** — kod merge edildi; **cihazda 0 çökme kanıtı yok** → aile/review cihazlarında P0.  
7. **Migration 0034–0036 + Edge CRON_SECRET** prod’da uygulanmadıysa güvenlik/ops açık kalır.  
8. **UGC (sınıf sohbeti):** raporlama / engelleme / moderasyon politikası net değil (Play UGC).  
9. **Güncel sürüm release gate’i yok.** V8 kapısı tarihsel kanıttır; production kararı bu taramadaki güncel bloklayıcılar ve yeni sürüm kanıtlarıyla verilmelidir.  
10. **Soak / çok cihaz QA** (Samsung + Pixel, cold start, reboot, OEM pil) eksik.

### “Play’e basarsak en kötü senaryo”

- **Politika ret:** installer / exact alarm / FSI / specialUse / battery / hesap silme.  
- **Kullanıcı P0:** Android 13 ve altı sayaç çökmesi (eğer WP-103 APK’si test edilmeden basılırsa).  
- **Güven / yasal:** silme yok + e-posta/oturum verisi + Sentry → KVKK/şikâyet.  
- **Backend:** eski RLS/migration → enumerasyon veya rapor spam (0036/edge deploy öncesi).

---

## 2) Ürün ve paket kimliği

| Madde | Durum | Risk |
|---|---|---|
| Package ID kalıcı | `com.manilmax.online_study_room` | ID değişmez; yanlış ID = yeni uygulama |
| Stable vs beta | Flavor: stable “Odak Kampı”, beta ayrı package + isim | Play’de **stable** flavor AAB; beta Internal/Closed track ayrı package olabilir veya tek package track |
| İmza | `key.properties` + release imza zorunlu; debug release engeli var | Keystore kaybı = güncelleme imkânsız — yedek **kritik** |
| Sürüm | `1.0.29+29` | Her yüklemede `versionCode` artmalı |
| `pubspec` description | “A new Flutter project.” | Mağaza metni değil; listing ayrı — polish |

**Öneri:** Play’e **yalnız `stable` flavor AAB** yükle; beta’yı Internal testing veya ayrı app. Keystore offline + Cloud backup.

---

## 3) Play politikası — kritik izinler ve özellikler

Kaynak: `AndroidManifest.xml` (`Kodda doğrulandı`).

### 3.1 İzin matrisi

| İzin | Amaç (ürün) | Play riski | Aksiyon |
|---|---|---|---|
| `INTERNET` | Supabase, güncelleme | Düşük | Data safety’de ağ |
| `POST_NOTIFICATIONS` | Sayaç, alarm, dürtme | Orta | Runtime istek + gerekçe metni |
| **`REQUEST_INSTALL_PACKAGES`** | GitHub APK kur | **🔴 Bloklayıcı** | Play build’de **kaldır**; updater’ı Play In-App Updates veya “Mağazada güncelle” linki yap |
| `FOREGROUND_SERVICE` + `DATA_SYNC` + **`SPECIAL_USE`** | Uzun sayaç bildirimi | **🔴 Form zorunlu** | Console: FGS declaration; specialUse gerekçesi (kullanıcı başlatmalı çalışma sayacı) |
| `WAKE_LOCK` | FGS | Düşük–orta | Gerekçe FGS ile |
| `RECEIVE_BOOT_COMPLETED` | Alarm/timer restore | Orta | Boot receiver dar tut (mevcut `exported=false` iyi) |
| **`SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM`** | Saat alarm | **🔴** | USE_EXACT_ALARM yalnız alarm saati / takvim sınıfı; gerekçe + form. Aksi yalnız SCHEDULE + kullanıcı ayarı |
| `VIBRATE` | Alarm | Düşük | — |
| **`USE_FULL_SCREEN_INTENT`** | Kilit ekranı alarm | **🔴** | Android 14+ kısıt; alarm uygulamaları için beyan; aksi FSI kullanma |
| **`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`** | OEM kill | **🟠** | Otomatik “izin ver” diyaloğu politikaya takılabilir; ayarlara yönlendir tercih et |

### 3.2 Foreground service `specialUse`

- Manifest property mevcut: `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` (çalışma sayacı metni).  
- WP-103: `dataSync|specialUse` + API dalları hizalı (`Kodda doğrulandı`).  
- **Play Console:** “Foreground service types” + specialUse açıklaması **İngilizce** net yazılmalı.  
- Yanlış tip (sadece dataSync ile 8 saat iddiası) Android 15 cap’e takılır; kod 34+ SPECIAL_USE kullanıyor — form ile tutarlı anlat.

### 3.3 In-app güncelleme (sideload)

`UpdaterService` → GitHub Releases APK + `open_filex` + `REQUEST_INSTALL_PACKAGES`.

| Senaryo | Sonuç |
|---|---|
| Play’den yüklü + GitHub APK zorla | Politika ihlali / ret / kaldırma riski |
| Play In-App Updates | Uyumlu yol |
| “Mağaza sayfasını aç” | Uyumlu, basit |

**Play track için:** installer izni ve GitHub APK indirme **kapalı** olmalı (flavor/`dart-define` ile). Sideload/beta kanalı ayrı kalabilir.

### 3.4 Hesap oluşturma → silme zorunluluğu

- Auth: e-posta/şifre (Supabase).  
- Ayarlar: hesap yönetimi / çıkış var; **“Hesabımı sil” implementasyonu yok** (`docs/HESAP-SILME-RETENTION-KARARI.md` = taslak, migration yok).  
- Admin soft-delete edge tarafında kısmi (anonimleştirme zayıf).

**Play:** [Account deletion](https://support.google.com/googleplay/android-developer/answer/13327111) — uygulama içi + web yol.  
**Durum:** 🔴 **Bloklayıcı** (hesaplı app).

### 3.5 UGC (kullanıcı üretimi içerik)

| Yüzey | Var mı? | Play beklentisi |
|---|---|---|
| Sınıf sohbeti | Evet (`class_messages`, max 500 char) | Rapor / engel / engellenen içerik politikası |
| Açık grup keşfi | Evet (0032) | Spam / uygunsuz isim |
| Profil adı / avatar | Evet | Rapor; avatar public bucket |
| Dürtme | Evet | Taciz / rate limit (nudge cooldown SQL’de var) |

**Eksik (kodda net değil):** kullanıcıdan kullanıcıya “şikâyet et”, global block listesi, sohbet moderasyonu.  
Feedback ticket admin’e gider — **UGC flagging** yerine destek kanalı; Play “UGC apps” için yetersiz kalabilir.

### 3.6 Çocuklar / Families

Ürün “çalışma sınıfı / genç-yetişkin” odaklı; Families programı hedeflenmiyorsa **hedef kitle 13+ / 16+** net seçilmeli. Chat + sosyal → Children-directed **değil** beyanı.  
Content rating anketinde social networking / user communication işaretlenir.

### 3.7 Reklam / IAP / abonelik

Kodda reklam/IAP paketi görülmedi → Data safety “Advertising” hayır; Payments yok.  
Basitleştirir.

---

## 4) Gizlilik, KVKK ve Data safety

### 4.1 Toplanan / işlenen veri (envanter özeti)

| Veri | Nerede | Not |
|---|---|---|
| E-posta, auth | Supabase Auth | Zorunlu kimlik |
| Display name, avatar, animal | `profiles`, Storage avatars | Sosyal vitrin |
| Çalışma oturumları | `study_sessions` | Süre, ders, zaman |
| Presence / “çalışıyor” | `presence` | Canlı durum |
| Sohbet | `class_messages` | UGC |
| XP / başarı | ledger | Server-authoritative |
| Cihaz tercihleri | SharedPreferences | Yerel |
| Offline kuyruk | prefs | Oturum mutasyonları |
| Crash / performans | Sentry (opt-in build flag) | `SENTRY_ENABLED` + DSN |
| Aylık e-posta | opt-in, job queue | 0030+ |

### 4.2 Zorunlu mağaza parçaları

| Parça | Durum | Risk |
|---|---|---|
| Gizlilik politikası (HTTPS URL) | Repoda hazır URL yok | 🔴 |
| Uygulama içi politika linki | Görülmedi | 🔴 |
| Kullanım koşulları | Görülmedi | 🟠 |
| Data safety formu | Console | 🔴 (elle) |
| Hesap silme + web silme | Yok / taslak | 🔴 |
| Veri export | Taslak (WP-66) | 🟠 KVKK talebi |
| Sentry opt-out | Build flag; in-app opt-out net değil | 🟠 |

### 4.3 Data safety — beyan önerisi (taslak)

- **Personal info:** e-posta, isim  
- **Photos:** avatar (kullanıcı seçer)  
- **App activity:** çalışma süreleri, app etkileşimi  
- **Messages:** in-app chat (varsa “other in-app messages”)  
- **App info and performance:** crash logs (Sentry açıksa)  
- **Collected / shared:** Supabase (işleyici); Sentry (varsa)  
- **Encryption in transit:** HTTPS evet  
- **Deletion:** şu an “hayır / kısmi” → silme eklenene kadar form yalan olmamalı  

### 4.4 Avatar storage

Avatars bucket public read (migration 0002) → profil foto URL’leri tahmin edilebilir path ile erişilebilir olabilir.  
Data safety + gizlilik metninde “profil fotoğrafı herkese açık / grup üyelerine” net yazılmalı.  
Mümkünse private + signed URL (ileri iş).

---

## 5) Güvenlik (uygulama + backend)

### 5.1 Son dönemde kapatılanlar (kodda)

| Konu | WP | Not |
|---|---|---|
| FGS tip uyumsuzluğu ≤13 | 103 | Cihaz QA bekliyor |
| Presence null updatedAt | 104 | — |
| XP profil-only tetik | 105 | — |
| members map + index | 106 | 0034 deploy |
| Manuel TZ | 107 | — |
| Rapor retry + cron URL | 108 | Edge + 0035 + secrets |
| Edge cron auth, IDOR stats, profiles RLS, sessiz update | 109 | 0036 + group repo |

### 5.2 Hâlâ riskli / ops’a bağlı

| Risk | Seviye | Durum |
|---|---|---|
| 0034–0036 prod’a **uygulanmamış** | 🔴 | Dosya var ≠ canlı |
| Edge `CRON_SECRET` / GUC set edilmemiş | 🔴 | Mail + yetkisiz invoke |
| Client `study_sessions` yazımı (süre enflasyonu / XP) | 🟠 | S1; ürün max-süre kararı yok |
| `TimerActionReceiver` exported=true | 🟡 | Dış intent ile toggle riski; permission koruması kontrol et |
| Widget provider’lar exported | 🟢 | Normal |
| Deep link recovery scheme | 🟡 | Supabase URL config + App Links doğrula |
| service_role istemcide yok | 🟢 | Kurallara uygun |
| `env.json` / keystore gitignore | 🟢 | Track edilmiyor (önceki kontrol) |
| Admin soft-delete zayıf PII temizliği | 🟠 | Hesap silme WP ile birleşmeli |

### 5.3 RLS özeti (yüksek seviye)

- Grup join RPC ile sertleştirilmiş (0012+).  
- Oturum görünürlüğü `can_see_user_sessions`.  
- XP ledger istemci yazamaz.  
- 0036 sonrası profiles global select kapalı (deploy şart).  
- Chat: üyelik + body length check.

---

## 6) Kararlılık, çökme ve cihaz QA

### 6.1 Bilinen / düzeltilmiş P0 adayları

| Konu | Kod | Cihaz |
|---|---|---|
| Android 10–13 FGS crash | WP-103 fix | **Doğrulanmadı** |
| Presence “hâlâ çalışıyor” | WP-104 | Cihaz |
| Durdur oturum kaybı | WP-104 | Cihaz |
| XP gelmiyor (profil açmadan) | WP-105 | Cihaz + ledger |

### 6.2 OEM / arka plan

- Samsung / Xiaomi / Oppo: FGS + exact alarm + pil kısıtı.  
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` politikası vs güvenilirlik tradeoff.  
- Boot sonrası alarm/timer: `TimerBootReceiver`, `AlarmReceiver`.

### 6.3 Test / kapı belgeleri

| Belge | Durum |
|---|---|
| Bu tarama | Güncel Play production NO-GO değerlendirmesi |
| `archive/v8/V8-RELEASE-GATE.md` | Tarihsel V8 kapısı; güncel sürüm kararı için kullanılmaz |
| `archive/v8/QA-V8-ANDROID.md` | Tarihsel V8 cihaz QA şablonu |
| `archive/v8/V8-ROLLBACK.md` | Tarihsel V8 rollback planı |
| Otomatik test | Geniş suite; tam `flutter test` bu turda koşturulmadı |

### 6.4 Minimum cihaz matrisi (Play öncesi)

| Cihaz / API | Senaryo |
|---|---|
| API 33 (Android 13) | Sayaç start/stop/FGS (WP-103) |
| API 34–35 | SPECIAL_USE + exact alarm + FSI |
| Samsung One UI | Bildirim, widget, pil |
| Pixel | Referans AOSP |
| Cold start + reboot + app kill | Timer/alarm/outbox |
| Offline 10 dk + online | Outbox flush |

---

## 7) Backend / ops (Play’den bağımsız ama prod için zorunlu)

| Madde | Risk | Aksiyon |
|---|---|---|
| Migration 0001–0033 canlı mı? | 🟠 | Envanter / `BACKEND-DURUM` |
| **0034 index** | Performans | SQL Editor |
| **0035 cron** | Rapor ölü / yanlış URL | GUC + unschedule/reschedule |
| **0036 güvenlik** | IDOR/profiles | SQL Editor |
| Edge deploy send/collect | Spam / 401 | `CRON_SECRET` deploy |
| Resend / DNS (WP-69) | E-posta | Ürün kararı |
| Supabase Free limit | Kota | Kullanıcı artınca plan |
| Realtime bağlantı sayısı | Ölçek | Küçük grup OK; açık grup büyürse izle |

---

## 8) Ürün / UX / erişilebilirlik (mağaza yorumları)

| Konu | Not |
|---|---|
| İzin yorgunluğu | Bildirim + alarm + FSI + pil → ilk açılışta hepsini isteme; kademeli |
| EN/TR | l10n altyapısı var; listing de iki dil |
| Boş durumlar | Genel olarak düşünülmüş (offline-first) |
| Hata mesajları | Türkçe odaklı |
| TalkBack | Sistematik a11y audit belgesi yok |
| Tablet / fold | Adaptif layout var; Play tablet screenshot |
| Windows | Play dışı; karıştırma |

---

## 9) Performans ve maliyet (kullanıcı algısı)

| Konu | Not |
|---|---|
| Mobil IndexedStack 5 sekme | Arka planda ticker/campfire — jank / pil **olası** |
| Group daily stats tablo-geneli realtime | Küçük grup OK; büyürse DB |
| Offline prefs JSON | Uzun kullanımda jank **olası** |
| Sentry | Kota / PII |
| fl_chart | Stats sekmesi bellek |

Play review doğrudan “yavaş” diye reddetmez; 1★ yorum üretir.

---

## 10) Store listing ve Console kontrol listesi

### 10.1 Listing varlıkları

- [ ] Uygulama adı ≤ 30 karakter (Odak Kampı)  
- [ ] Kısa / uzun açıklama TR (+ EN opsiyonel)  
- [ ] İkon 512×512  
- [ ] Feature graphic 1024×500  
- [ ] Telefon ekran görüntüleri (en az 2; öneri 4–8)  
- [ ] Tablet ekran görüntüleri (hedefleniyorsa)  
- [ ] Kategori (Education / Productivity)  
- [ ] İletişim e-postası  
- [ ] Gizlilik politikası URL  
- [ ] Content rating anketi  
- [ ] Hedef kitle / News apps vb. formlar  

### 10.2 App content formları

- [ ] Privacy policy  
- [ ] Ads (hayır)  
- [ ] App access (giriş gerekiyorsa demo hesap)  
- [ ] Content ratings  
- [ ] Target audience  
- [ ] News / COVID / Data safety / Government  
- [ ] **Financial features** hayır  
- [ ] **Health** hayır  
- [ ] **Foreground service** beyanı  
- [ ] **Exact alarm** beyanı  
- [ ] **Photo/video permissions** (picker)  
- [ ] Account deletion URL + in-app  

### 10.3 Teknik Console

- [ ] AAB (APK değil tercih)  
- [ ] 64-bit  
- [ ] targetSdk güncel (Flutter default — build log’da doğrula; genelde 34/35)  
- [ ] Play App Signing (Google managed) — keystore stratejisi  
- [ ] Internal → Closed → Production basamak  
- [ ] Pre-launch report (Firebase Test Lab)  

---

## 11) Mimari ve “bilinçli borç” (Play ret değil ama ürün riski)

| Borç | Etki |
|---|---|
| Client-authoritative session insert | Liderlik / XP abuse |
| Hesap silme yok | Politika + yasal |
| Soft admin delete zayıf | Destek / KVKK |
| Aylık rapor ops yarım | Sessiz özellik |
| OPTIMIZATIONS derin perf | Ölçek sonrası |
| Release gate NO-GO | Süreç disiplini |
| pubspec “new Flutter project” | Kozmetik |

---

## 12) Öncelikli yol haritası (Play’e giden)

### Faz A — Politika bloklayıcıları (yayın yok)

1. Hesap silme (in-app + web) — WP-66 implement  
2. Gizlilik politikası + uygulama içi link  
3. Play build: **GitHub APK updater OFF** + `REQUEST_INSTALL_PACKAGES` kaldır  
4. Data safety formu (dürüst)  
5. FGS specialUse + exact alarm + FSI Console beyanları  
6. Battery optimization: agresif prompt’u yumuşat  

### Faz B — Prod güvenlik/ops

1. 0034, 0035, 0036 SQL  
2. Edge deploy + `CRON_SECRET` + GUC  
3. RLS smoke (profiles, monthly stats, group admin)  

### Faz C — Kararlılık kanıtı

1. API 33 + Samsung + Pixel: sayaç / widget / alarm / offline  
2. WP-103/104/105 cihaz tik  
3. Pre-launch report 0 crash  

### Faz D — Soft launch

1. Internal testing (güvenilir 5–20 hesap)  
2. Closed testing 14+ gün (isteğe bağlı ama yorum kalitesi)  
3. Production staged rollout %20  

### Faz E — Sonra

1. UGC raporlama  
2. Session duration server cap (S1)  
3. Avatar private  
4. Play In-App Updates  

---

## 13) GO / NO-GO matrisi

| Kapı | GO için | Şu an |
|---|---|---|
| Hesap silme | In-app + web canlı | ❌ |
| Gizlilik URL | Canlı sayfa | ❌ / bilinmiyor |
| Installer izni | Play AAB’de yok | ❌ (manifest’te var) |
| FGS/alarm beyanları | Console dolu | ⚪ Console |
| Data safety | Dolu + tutarlı | ⚪ Console |
| WP-103 cihaz | 0 çökme video | ❌ |
| Migration 0036 | Prod | ❓ |
| Edge cron auth | Deploy + secret | ❓ |
| Content rating | Bitmiş | ⚪ |
| Keystore yedek | 2+ kopya | ❓ |
| Demo hesap (reviewer) | Çalışır | ❓ |

**Özet karar önerisi:** **NO-GO Play production** — Internal testing, A fazı bitmeden açılmamalı.  
Kapalı beta (sideload / beta package) politikası Play’den farklıdır; karıştırma.

---

## 14) Reviewer notu (demo hesabı)

Play review için:

- Test e-postası + şifre  
- Önceden dolu grup + örnek oturum  
- “Sayaç başlat → bildirim → durdur” 60 sn akış  
- Alarm kur (exact alarm ayarı gerekebilir — not yaz)  
- Chat ve keşif adımları  
- Türkçe cihaz varsayılanı  

Eksik hesap silme review’ı da engelleyebilir.

---

## 15) Bu taramanın sınırları

- Play Console mevcut form durumuna bakılmadı.  
- Canlı Supabase şema dump’ı yok (migration dosyası ≠ deploy).  
- `flutter test` / release AAB bu turda üretilmedi.  
- Hukuki metin (KVKK avukatı) bu belge yerine geçmez.  
- Google politika metinleri güncellenir; submit öncesi resmi sayfaları yeniden oku.

---

## 16) Hızlı referans — dosyalar

| Konu | Dosya |
|---|---|
| İzinler / FGS | `app/android/app/src/main/AndroidManifest.xml` |
| Flavor / imza | `app/android/app/build.gradle.kts` |
| Updater | `app/lib/features/updater/updater_service.dart` |
| Sentry | `app/lib/core/observability/*` |
| Hesap silme kararı | `docs/HESAP-SILME-RETENTION-KARARI.md` |
| Güncel Play hazırlığı | `docs/PLAY-STORE-HAZIRLIK-TARAMASI.md` |
| Güvenlik migration | `supabase/migrations/0036_security_hardening.sql` |
| Rapor edge | `supabase/functions/{collect,send}-report/` |
| Son optimizasyon/bug | `OPTIMIZATIONS.md` (opsiyonel; tarihli) |

---

*Rapor sonu. Kod / commit / build yok. Play submit öncesi Faz A + C zorunlu kabul edilmeli.*
