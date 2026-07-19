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
| Başarım & Sosyal Profil 3.0 (WP-56/57) | ✅ Tamamlandı → **iyileştirme WP-208–211 + WP-216–220** (güvenli claim rollout + verified oturum + ölü başarı fix) |
| Windows masaüstü (WP-27/52/53/28/70/71) | ✅ Tamamlandı (cihaz smoke → debug) |
| Global açık/özel gruplar (WP-92/93) | ✅ Tamamlandı |
| **Google Play production (WP-110–124)** | 🔴 **Açık — NO-GO** (bkz. §8.8) |
| Başarım+Görev+Grup PP (WP-208–220) | 🟡 **Planlandı v3.1** (`docs/features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md`); WP-220 saha kanıtı sonrası WP-219 reward/verified-XP aktivasyon kapısıdır |

> Tamamlanmış programların ayrıntılı kapsamı: `archive/KALITE-PROGRAMI-tarihsel.md §8.1–8.7`. AI katmanı (gelecek): aynı arşiv §6.

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
8. **Windows dağıtım kanalı:** Microsoft Store MSIX (önerilen) mi, doğrudan imzalı MSIX + App Installer mi.
9. **Kusursuz Ay eşiği:** sözlük açıklamasındaki 30 gün mü, mevcut server+Dart evaluator davranışı ve her ay erişilebilir “dört kusursuz hafta” anlamındaki 28 gün mü? **Öneri: 28 gün.** Karar evaluator, sözlük ve tüm dil metinlerine birlikte uygulanır; WP-210'u bloke eder, WP-209/208'i etkilemez.

---

## 13. Kaynaklar

- Android bildirimleri — https://developer.android.com/develop/ui/compose/notifications
- Android foreground services — https://developer.android.com/develop/background-work/services/fgs
- Widget güncelleme kuralları — https://developer.android.com/develop/ui/views/appwidgets/advanced
- Android widget quality — https://developer.android.com/docs/quality-guidelines/widget-quality
- Android Dynamic Color — https://developer.android.com/develop/ui/views/theming/dynamic-colors
- flutter_foreground_task — https://pub.dev/packages/flutter_foreground_task
- flutter_local_notifications (chronometer) — https://pub.dev/packages/flutter_local_notifications
- Flutter Windows deployment — https://docs.flutter.dev/deployment/windows
- MSIX signing — https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide
