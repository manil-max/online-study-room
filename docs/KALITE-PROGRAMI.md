# Odak Kampı — Kalite Programı ve Ürün Yol Haritası (Master Plan)

> **Başlangıç:** 2026-07-12 · **Bu dosya tek kanonik yönetişim kaynağıdır.**
> **Sadeleştirme (2026-07-19):** Tamamlanmış program dilimlerinin tarihsel kapsam/tanı detayı (§0/1/3/5.1/6/8.1–8.7/10/12) `archive/KALITE-PROGRAMI-tarihsel.md`'ye taşındı. Burada **canlı yönetişim** kaldı: çalışma sistemi, kalite kapıları, eşzamanlılık kuralı, platform/güvenlik ilkeleri, açık Play programı, cihaz QA, açık kararlar.

## Kanıt etiketleri (her iddiada kullanılır)

| Etiket | Anlamı |
|---|---|
| `Kodda doğrulandı` | İlgili dosya/satır okunarak teyit edildi. |
| `Cihazda doğrulanmalı` | Gerçek Android cihazda kanıt gerektirir. |
| `Ürün kararı gerekiyor` | Ürün sahibinin kararı olmadan ilerlenmez. |

---

## 2. Temel İlke: İki "Tamamlandı" Tanımı

1. **Kod/ekran oluşturuldu.**
2. **Özellik kullanıcı beklentisini karşılıyor ve cihazda güvenilir çalışıyor.**

**Artık yalnızca (2) "tamamlandı" sayılır.** Kalite programının özü budur.

---

## 4. Çalışma Sistemi (yönetişim — CANLI)

### 4.1 WP durum merdiveni (8 aşama)

1. `Planlandı` · 2. `Geliştiriliyor` · 3. `Kod tamamlandı` · 4. `Otomatik test geçti` · 5. `Gerçek cihaz QA geçti` · 6. `Ürün kabulü geçti` · 7. `Yayınlandı` · 8. `Yayın sonrası doğrulandı`

Bir ajan yalnız ilk 3–4 aşamayı kapatabilir. **"Tamamlanan"a geçiş için gerçek cihaz (5) ve ürün kabulü (6) zorunludur.**

### 4.2 Her WP için zorunlu teslim paketi

Problem tanımı · kullanıcı senaryoları · kapsam dışı · tasarım/prototip · teknik tasarım · veri/migration etkisi · RLS/güvenlik · edge-case listesi · otomatik testler · gerçek cihaz test matrisi · performans/batarya · erişilebilirlik · geri alma planı · kanıtlar (ekran/video/test çıktısı) · ürün sahibi kabulü.

### 4.3 Release kalite kapısı

Aşağıdakilerden biri sağlanmıyorsa **stable release çıkmaz:** kritik/ağır bug 0 · migration dry-run başarılı · Supabase staging başarılı · tüm otomatik testler başarılı · Android release build başarılı · gerçek Samsung cihaz testi başarılı · temel kullanıcı yolculukları başarılı · widget/bildirim cold-start başarılı · recovery/admin/RLS testleri başarılı · beta soak ≥ 3 gün · rollback planı hazır.

### 4.4 Ölçülebilir kabul kriterleri (örnekler)

"Apple seviyesinde" tek başına kriter değildir; ölçülebilir karşılığı:
- Sayaç uygulama kapalıyken 8 saatte ≤ ±1 sn sapar.
- Widget aksiyonu ≤ 500 ms görsel geri bildirim verir.
- Oturum kaydı sonrası uygulama içi istatistik ≤ 1 sn'de değişir.
- Ana ekran stats widget'ı oturum bitiminden ≤ 5 sn sonra yenilenir.
- Hiçbir başarı aynı kademe için iki kez XP vermez.
- Tema değişince ana UI yüzeylerinin ≥ %95'i yeni token setinden beslenir.
- Kritik metinlerde WCAG AA kontrastı sağlanır.
- Samsung ve Pixel test matrisinde bildirim/widget davranışı kanıtlanır.

---

## 5. Altyapı İlkeleri (CANLI)

> Yığın denetimi (tut/ekle/değiştir) tarihsel karar tablosu → `archive/KALITE-PROGRAMI-tarihsel.md §5.1`. Çekirdek: Flutter + Riverpod 3 + Supabase + çift repository + RLS + offline-first; felsefe "yıkma, güçlendir".

### 5.2 Android native platform sınırları (`Cihazda doğrulanmalı`)

- Bildirimin son **görünümünü sistem/OEM belirler**; Samsung/Pixel/sürümlerde piksel-aynı görünüm garanti edilemez. Hedef `HH:MM:SS` + butonlar ulaşılabilir, layout OEM'e bağlı.
- Bildirim aksiyonları app açmadan native receiver/service ile çalışır; uzun görünür işler foreground service + kalıcı bildirim; **servis başlangıç kısıtları ve sürüm farkları** dikkate alınır.
- Widget'ı **saniyede Flutter'dan yeniden çizmek yanlıştır.** Periyodik güncelleme <30 dk garanti değil, WorkManager <15 dk'ya uygun değil. Canlı süre için native `Chronometer`; state değişimi için receiver/service; stats widget'ları **olay bazlı**.
- Gerekli izinler: `FOREGROUND_SERVICE`(+tip), `WAKE_LOCK`, `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `RECEIVE_BOOT_COMPLETED`.

### 5.3 Güvenlik ve veri bütünlüğü (kalite kadar kritik)

- **Sosyal profil görünürlüğü:** yalnız ortak aktif grup üyesi görebilmeli; e-posta görünmemeli; adminlik erişimi otomatik genişletmemeli.
- **Server-authoritative ilerleme:** XP ve achievement progress istemcide hesaplanmaz. Akış: server-side RPC/Edge Function + **idempotent achievement event** + **append-only XP ledger** + denetim/test.

### 5.4 Ortam ve migration yönetişimi (CANLI)

- Üç ortam vardır: local Supabase (geliştirme), ayrı staging Supabase (beta), production Supabase (stable).
- **Beta yalnız staging'e, stable yalnız production'a bağlanır.** Ortam/kanal uyuşmazlığı fail-closed olur.
- `supabase/migrations/` tek kanonik zincirdir; local → staging → production terfisi yapılır. Ortama özel SQL çatalları yasaktır.
- Remote'a uygulanmış migration immutable'dır; düzeltme yeni ileri migration ile gelir.
- Production mutasyonu için staging kanıtı, cihaz QA, ≥3 gün soak, backup, dry-run, post-check ve o somut deploy'a açık ürün sahibi GO zorunludur.
- `supabase db reset --linked` remote ortamda yasaktır. Normal migration deploy'u SQL Editor değil Supabase CLI üzerinden izlenebilir geçmişle yapılır.
- Ayrıntılı operasyon sözleşmesi: `docs/ORTAM-MIGRATION-YONETISIMI.md`.

---

## 7. Program Sırası ve Eşzamanlılık (CANLI)

**Eşzamanlılık kuralı:** Aynı anda **en fazla iki çalışma hattı**. **Saat, Tema ve Başarım aynı anda açılamaz** — üçü de ortak theme/navigation/profile/provider yüzeylerine dokunur, büyük çakışma yaratır.

### Program durumu

| Program | Durum |
|---|---|
| Faz 0A/0B (gerçeklik + test/gözlemlenebilirlik) | ✅ Kapandı |
| V8 Güven Sürümü (A sayaç-tek-doğruluk / B senkron / C IA) | ✅ Yayımlandı (soak ürün kararıyla atlandı) |
| Saat ürünü (WP-58/59/60) | ✅ Tamamlandı |
| Tema Stüdyosu (WP-54/55) | ✅ Tamamlandı |
| Başarım & Sosyal Profil 3.0 (WP-56/57) | ✅ Tamamlandı → **iyileştirme WP-208–211 + WP-216–220** (güvenli claim rollout + tüm süre kaynakları eşit + ölü başarı fix) |
| Windows masaüstü (WP-27/52/53/28/70/71) | ✅ Masaüstü ürün temeli tamamlandı; **Store ürünleştirmesi WP-259–262 açık** |
| Global açık/özel gruplar (WP-92/93) | ✅ Tamamlandı |
| **Google Play production (WP-110–124)** | 🔴 **Açık — NO-GO** (bkz. §8.8) |
| Başarım+Görev+Grup PP (WP-208–220) | 🟡 **v3.2 geçişi sürüyor** (`docs/features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md`); manuel/sayaç/native süre eşitliği ürün kanonu, mevcut `0063` kabul edilmedi |
| **Kurtarma ve ortam izolasyonu (WP-225–232)** | 🔴 **En yüksek öncelik / production freeze**; canlı DB baseline, CLI, staging ayrımı, eşit-süre ve ekonomi onarımı, beta soak, kontrollü production terfisi |

> Tamamlanmış programların ayrıntılı kapsamı: `archive/KALITE-PROGRAMI-tarihsel.md §8.1–8.7`. AI katmanı (gelecek): aynı arşiv §6.

---

## 8.7 Proje Kurtarma ve Güvenli Teslim Programı (WP-225–232 · AÇIK)

Amaç production verisini koruyarak mevcut istemci/DB/migration drift'ini kaldırmak ve aynı sınıf hatanın tekrarını sistemsel olarak engellemektir.

| Faz | WP | Çıktı | Sert kapı |
|---|---|---|---|
| 0 — Freeze/kanıt | WP-225 | Canlı salt-okunur envanter, backup/recovery durumu, oturum/XP baseline | Production yazımı yok |
| 1 — CLI/baseline | WP-226 | Pinli CLI + local replay + manuel 0001–0062 geçmiş uzlaşması | Şema kanıtı olmadan `migration repair` yok |
| 2 — İzolasyon | WP-227 | Beta→staging, stable→production; ayrı kimlik/env; fail-closed | Beta production'a bağlanamaz |
| 3 — Otomasyon | WP-228 | Local/staging otomasyonu + production manual gate | Remote reset yok; secret sızıntısı yok |
| 4A — Sunucu onarımı | WP-229 | Güvenli ileri migration; tüm süre kaynakları eşit; reward zinciri canlı | Session/ledger/reward invariant kaybı 0 |
| 4B — İstemci onarımı | WP-230 | 6 kademe/20k ekonomi, tutarlı XP barı, verified metin temizliği, benzersiz build | Client/server tuple farkı 0 |
| 5 — İstatistik güveni | WP-231 | Açık takvim haftası + ayrı Son 7 Gün; toplam refresh ≤1 sn | Kişisel/grup aynı dönem sözleşmesi |
| 6 — Terfi | WP-232 | Staging migration+cihaz QA+≥3 gün soak; kontrollü production recovery release | Açık ürün sahibi GO |

Kilit ürün kararları:

- Manuel giriş, uygulama kronometresi, geri sayım, Pomodoro ve native/widget sayaç geçerli `study_sessions` olarak aynı istatistik/XP/başarım/grup akışına girer.
- Taç eşikleri `[0, 20k, 75k, 200k, 500k, 1M]`; istemci ve server tek fixture/sözleşmeyle doğrulanır.
- “Bu hafta” Pazartesi 00:00–şimdi takvim haftasıdır ve UI bunu açık yazar; kullanıcı beklentisi için ayrıca “Son 7 Gün” filtresi eklenir.
- Mevcut `0063` production'a uygulanmaz. WP-225 hiçbir remote'a uygulanmadığını kanıtlarsa yayımlanmamış dosya güvenle yeniden yazılabilir; herhangi bir remote'da uygulanmışsa dosya immutable kalır ve yeni ileri migration yazılır. Remote'a uygulanmış `0051–0062` dosyaları değiştirilmez.

---

## 8.8 Google Play Production Hazırlığı (WP-110–124 · AÇIK)

Amaç yalnız AAB üretmek değil; Play politikası, veri yaşam döngüsü, UGC güvenliği, Android platform uygunluğu, backend operasyonu ve gerçek cihaz kanıtlarıyla savunulabilir bir production GO kararı. Tekil WP kartları `progress.md`/arşivde; burada kanonik faz sırası:

| Dalga | WP | Çıktı | Kapı |
|---|---|---|---|
| 1 — Kanal/yasal | WP-110, WP-111 | Play/sideload izolasyonu; gizlilik/koşullar/topluluk kuralları + canlı URL | Play manifestinde installer/self-update yok; URL erişilebilir |
| 2 — Hesap yaşam döngüsü | WP-112 → 113 → 114 | Veri/retention sözleşmesi; idempotent hard-delete; app içi + web silme | WP-66 kararları; staging silme kanıtı |
| 3 — UGC güvenliği | WP-115 → 116; 117 | Raporla/engelle/koşul kabulü; moderasyon kuyruğu + audit | RLS/abuse testleri; uçtan uca kanıt |
| 4 — Android politikası | WP-118 | FGS, exact alarm, FSI, battery opt., exported component uygunluğu | API 33–36 davranış/fallback kanıtı |
| 5 — Beyan/store | WP-119 → 120 | Data Safety envanteri; listing/App Content/reviewer erişimi | Kod–beyan tutarlılığı; eksiksiz Console paketi |
| 6 — Production ops/build | WP-121, WP-122 | Migration/Edge/RLS deploy kapısı; API 36 imzalı AAB | Onaysız canlı mutasyon yok; versionCode > mevcut |
| 7 — Kalite/yayın | WP-123 → 124 | Gerçek cihaz, erişilebilirlik, pre-launch, internal/closed test, soak, staged rollout | Açık GO olmadan submission/rollout yok |

Zorunlu politika ilkeleri: uygulama içi **ve** web'den hesap silme (yalnız "devre dışı" değil) · Play artefaktı GitHub APK kurmaz, `REQUEST_INSTALL_PACKAGES` istemez · UGC yüzeyleri koşul kabulü + raporlama + engelleme + moderasyon olmadan çıkmaz · kısıtlı izinler gerçek cihazda fallback ile kanıtlanır · effective target API 36 (31 Ağustos 2026 takvimi; submit anında yeniden kontrol) · yeni kişisel hesapta closed-test (≥12 tester, 14 gün kesintisiz) kanıtlanır.

Bulgu kanıtı: `docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`; sahip aksiyonları: `docs/play/OWNER-ACTION-CHECKLIST.md`.

---

## 8.9 Bildirim Güveni ve Android Canlı Sayaç (WP-265–267 · AÇIK)

- **WP-265:** Dürtme/güncelleme/duyuru, local notification, alarm ve FGS yüzeylerini adli olarak ayrıştır; resmî Android/Samsung/Firebase/Supabase sözleşmesiyle kök neden ve kabul matrisi çıkar.
- **WP-266:** Android remote push'ı FCM + Supabase transactional outbox/per-device delivery/Edge dispatcher ile kur; token/preference/retry/logout/iki-cihaz yaşam döngüsünü RLS ve idempotency ile kilitle; local test ile gerçek remote self-test'i ayır ve p95 ≤10 sn sağlık yüzeyi sağla.
- **WP-267:** Native sayaç state/FGS/action omurgasını koruyarak custom `RemoteViews` varsayılanından standard/promoted ongoing notification'a geç; Samsung Now Bar'ı garanti değil OEM best-effort kabul et.
- **Seri sıra:** WP-265 → WP-266 → WP-267. Migration/Edge ve native timer aynı anda yazılmaz.
- **Release kapısı:** Terminated uygulamada gerçek dürtme, duplicate=0, invalid-token/retry, Samsung+Pixel/API matrisi ve beta soak kanıtı olmadan stable çıkmaz. Production migration/Edge/release ayrıca açık kullanıcı GO ister.
- **Kanonik rapor:** [`NOTIFICATION-SYSTEM-AUDIT-2026-07.md`](NOTIFICATION-SYSTEM-AUDIT-2026-07.md)

## 9. Cihaz QA Matrisi ve Test Senaryoları (CANLI)

Zorunlu senaryolar (her kalite kapısında koşulur): cold start · force stop · telefon kilidi · yeniden başlatma · internet kaybı · aynı hesap iki cihazda · saat dilimi/gün değişimi · uygulama güncellemesi · batarya optimizasyonu · Samsung One UI + Pixel davranışı · 23:59–00:01 gün sınırı · reboot sonrası alarm/timer recovery · widget/bildirim cold-start. Tek sayfa matris: `docs/qa/DEVICE-QA-MATRIX.md`.

---

## 11. Açık Kararlar (`Ürün kararı gerekiyor`)

> Tamamlanan büyük programlara ait eski kararlar (sürüm çerçevesi, Faz 0 başlangıç, native onayı, istatistik sırası, tema derinliği, Saat kapsamı, sosyal profil gizliliği) **çözüldü ve uygulandı** → tarihsel detay arşivde. Kalan açık kararlar:

1. **Hesap silme/retention:** geri alma süresi, kullanıcı export'u, mesaj silme/anonimleşme, admin audit saklama (WP-113 canlı ops önkoşulu).
2. **Play yasal kimliği:** Privacy/Terms domaini, destek e-postası, veri sorumlusu/işletme adı.
3. **Hedef kitle:** 13+/16+ ve çocuklara yönelik mi (rating/reklam/veri beyanını değiştirir).
4. **Alarm politikası:** exact alarm temel işlev mi, yoksa güvenli inexact fallback mi.
5. **Play geliştirici hesabı:** kişisel/organizasyon türü + açılış tarihi (12 tester/14 gün kapısı).
6. **Aylık rapor (WP-69):** DNS + Resend API key ile canlıya alınacak mı.
7. **Yeni grafik türleri (WP-67):** brief hazır; implementasyon onayı.
8. **Windows dağıtım kanalı (çözüldü):** Stable = Microsoft Store MSIX; GitHub Releases = beta/QA. Public Store yayını, Private Audience pilotu ve açık kullanıcı GO sonrası yapılır.

---

## 13. Kaynaklar

- Android bildirimleri — https://developer.android.com/develop/ui/compose/notifications
- Android Live Updates — https://developer.android.com/develop/ui/views/notifications/live-update
- Android foreground services — https://developer.android.com/develop/background-work/services/fgs
- Firebase Cloud Messaging (Flutter) — https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- Firebase FCM HTTP v1 — https://firebase.google.com/docs/cloud-messaging/send/v1-api
- Supabase Database Webhooks — https://supabase.com/docs/guides/database/webhooks
- Widget güncelleme kuralları — https://developer.android.com/develop/ui/views/appwidgets/advanced
- Android widget quality — https://developer.android.com/docs/quality-guidelines/widget-quality
- Android Dynamic Color — https://developer.android.com/develop/ui/views/theming/dynamic-colors
- flutter_foreground_task — https://pub.dev/packages/flutter_foreground_task
- flutter_local_notifications (chronometer) — https://pub.dev/packages/flutter_local_notifications
- Flutter Windows deployment — https://docs.flutter.dev/deployment/windows
- MSIX signing — https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide
