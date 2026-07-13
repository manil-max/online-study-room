# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-13
> Sistem: İş Paketi (WP) tabanlı, **Kalite Programı**. Kanonik program: `docs/KALITE-PROGRAMI.md`.
> Planlama: `.agents/skills/planner/SKILL.md` · Uygulama: `.agents/skills/worker/SKILL.md` · Kurallar: `.agents/AGENTS.md`.
> **"Tamamlandı" = kod DEĞİL; kullanıcı beklentisini karşılayan + cihazda güvenilir çalışan iş.** İş durum merdiveni (8 aşama) ve kanıt etiketleri (`Kodda doğrulandı` / `Cihazda doğrulanmalı` / `Ürün kararı gerekiyor`) için bkz. AGENTS.md §0.

---

## Proje Gerçekleri (ajan referansı)

- **Framework:** Flutter ^3.12 · Riverpod 3.3 · Supabase 2.15 · fl_chart
- **Uygulama kökü:** `app/` — Flutter komutları yalnız burada çalışır.
- **Repo katmanı çift:** Her arayüz `supabase/` ve `in_memory/` repository'leriyle desteklenir.
- **Migration'lar:** `supabase/migrations/` — yerelde `0001–0023` vardır. Canlı şemada `0001–0019` etkileri doğrulandı; `0020–0023` SQL Editor'da sırasıyla uygulanır. `0022` ve `0023` tekrar-çalıştırılabilir (idempotent).
- **Gün sınırı:** `Europe/Istanbul`
- **RLS helper'ları:** `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`, `is_super_admin()`
- **Dashboard:** 6 sütunlu 2D matris, 19 kart türü, `grid_reflow.dart` motoru.
- **Tema:** Hazır paletler + özel palet slotları; görünür tüm yüzeyler palette bağlanmalıdır, sabit gri renk eklenmez.
- **Navigasyon hedefi:** Ana Sayfa / Saat / Gruplar / İstatistikler / Profil. Ana Sayfa günlük kullanım alanıdır; diğer alanların verisi kendi sekmelerinde eksiksiz bulunur.
- **Release:** Stable/Beta kanalı GitHub Releases ile çalışır. **v7 yayında (özellik sürümü).** İlk kalite-kapılı stable önerisi: **v8 "Güven Sürümü"** (`Ürün kararı gerekiyor`).
- **Kalite kapıları:** Her WP DoD'siz kapanmaz; stable release kalite kapısından geçer (AGENTS.md §3). Server-authoritative XP, RLS/sosyal profil, platform sınırları → `docs/KALITE-PROGRAMI.md`.
- **Son WP numarası:** 53
- **Geliştirme ortamı:**
  - Proje: `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room`
  - Flutter: `C:\src\flutter` · Android SDK: `C:\Android\Sdk`
  - JDK: `C:\Program Files\Android\Android Studio\jbr`
  - Web test: `flutter run -d chrome --web-port=5005 --dart-define-from-file=env.json`
  - GitHub: `manil-max/online-study-room` (public)

---

## ⚡ Aktif Çalışma Kaydı (çakışma koordinasyon yüzeyi)
- **Geliştirme ortamı:**
  - Proje: `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room`
  - Flutter: `C:\src\flutter` · Android SDK: `C:\Android\Sdk`
  - JDK: `C:\Program Files\Android\Android Studio\jbr`
  - Web test: `flutter run -d chrome --web-port=5005 --dart-define-from-file=env.json`
  - GitHub: `manil-max/online-study-room` (public)

---

## ⚡ Aktif Çalışma Kaydı (çakışma koordinasyon yüzeyi)

> **Bu bölüm paralel ajanların TEK paylaşılan gerçeğidir.** Her ajan görevi alır almaz (kod yazmadan önce) kendi lane'ini doldurur; başlamadan önce tüm lane'leri okuyup çakışma ön-kontrolü yapar (AGENTS.md §1). Çakışma varsa başlamaz, kullanıcıyı gerekçeyle uyarır.
> Bir WP tamamlanınca (cihaz QA + kabul) kartı buradan/plandan kaldırılır, **Tamamlanan İş Paketleri**ne tek kez eklenir.

**Lane şablonu** (doldurulacak alanlar): Durum · Faz/WP · Aşama (8-merdiven) · SAHİP yollar · Ortak/riskli yüzey · Başlangıç · Son güncelleme · Not. *(Branch yok — herkes `main`'de; AGENTS.md §1.5.)*

### Gemini Lane
- **Durum:** [x] Tamamlandı (Boşta)
- **Faz/WP:** Faz 0 · Başarım 3.0 & XP Ledger Mimarisi
- **Aşama:** Mimari tasarım tamamlandı
- **SAHİP yollar:** `docs/BASARIM-MIMARISI.md`
- **Ortak/riskli yüzey:** Yok (yalnızca planlama)
- **Dal:** — (ana dal `main`)
- **Başlangıç:** 2026-07-13 12:12 (Europe/Istanbul)
- **Son güncelleme:** 2026-07-13 (Europe/Istanbul)
- **Not:** Server-authoritative başarı sistemi, XP ledger yapısı ve Supabase RPC tasarımları `docs/BASARIM-MIMARISI.md` dosyasına başarıyla işlendi. Başarım eşik değerleri ve gizli sürpriz rozetler kullanıcı onayıyla kodlanmaya hazır hale getirildi.

### Claude Lane
- **Durum:** [x] Boşta — WP-41 + WP-42/51 ürün kabulü (kullanıcı 2026-07-13)
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (main)
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-13
- **Not:** V8-A native sayaç/bildirim/widget (beta-v11…v15) + Grok in-app start hotfix (`94945ac`) ile kod hattı kapatıldı. Kalan: sonraki beta cihaz smoke; OEM Live Panel ince ayar ayrı polish (kapsam dışı).

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (ana dal `main`)
- **Başlangıç:** 2026-07-13 (Europe/Istanbul)
- **Son güncelleme:** 2026-07-13 (WP-53 R1 kod kapıları geçti)
- **Not:** Ayarlar tek katmana indirildi; ExpansionTile yok, Gruplar sayacı kaldırıldı, bildirim/sürüm doğrudan açılıyor, grid Auto seçeneği kaldırılıp eski değer 6'ya göçüyor. Analyze + 283 test + Windows release build PASS; görsel cihaz QA bekliyor. Push yok.

### Grok Lane
- **Durum:** [x] Boşta — WP-58/59/60 kod+otomatik test geçti (cihaz QA / ürün kabulü bekliyor)
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** main
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-13
- **Not:** Saat Merkezi R1–R3 kodlandı: epoch motor, exact alarm, Alarm 2.0, çoklu timer, dünya saati, lap kronometre, StandBy burn-in. `flutter analyze` (clock paths) 0; time_engine+clock+alarms testleri 20/20 PASS. `Cihazda doğrulanmalı`.

---

## Kalite Programı — Faz/Program Sırası

> Kaynak: `docs/KALITE-PROGRAMI.md`. Bunlar program dilimleridir; planner tetiklenince WP'lere bölünür. Aynı anda en fazla **iki çalışma hattı**; Saat/Tema/Başarım aynı anda AÇILMAZ.

| Sıra | Program/Faz | Kapsam | Durum | Not |
|---|---|---|---|---|
| 1 | **Faz 0A** | Tek kaynak & tamamlanma denetimi (envanter, P0/P1/P2 bug, migration/Edge Function canlı durum) | Planlandı | Yeni özellik üretmez |
| 2 | **Faz 0B** | Test & gözlemlenebilirlik temeli (integration test, native test planı, Sentry) | Planlandı | — |
| 3 | **V8-A** | Sayaç–bildirim–widget tek doğruluk kaynağı (foreground service, canlı `Chronometer`) | Kod+ürün kabulü (WP-40–42/51) | Sonraki beta smoke; WP-48 paket |
| 4 | **V8-B** | Genel senkronizasyon denetimi (canonical projection, idempotency) | Planlandı | — |
| 5 | **V8-C** | Küçük IA: İstatistik sırası + Gruplar sırası/kamp ateşi + animasyon | Planlandı | düşük risk, golden test |
| 6 | **V8 beta → soak → stable** | Kalite kapısı | Planlandı | `Ürün kararı`: sürüm no |
| 7 | **Saat programı** | Saat 1–5 (motor → IA → alarm → kronometre/timer → StandBy/widget) | Kod tamamlandı · cihaz QA bekliyor | WP-58/59/60 |
| 8 | **Tema Stüdyosu** | Token motoru + 12+ tema ailesi + katmanlı editör | WP-54/55 tamamlandı | PRO hex stüdyo sonraki |
| 9 | **Başarım & Sosyal Profil 3.0** | Tek motor, server-authoritative XP ledger, herkese açık profil RLS | WP-56/57 tamamlandı | 0025–0027 SQL canlı; 0028 genel yayın; B7 RLS ayrı |
| 10 | **Windows masaüstü** | WP-27 base → WP-52 adaptif grid → WP-53 desktop IA → WP-28 MSIX/release | Araştırıldı · planlandı | `docs/WINDOWS-URUN-PLANI.md` |

## Planlanan İş Paketleri

> Burada yalnız başlanmamış, WP'ye bölünmüş işler bulunur. Sıra, bağımlılık ve ürün önceliğine göre korunur.

| WP | Durum | Kısa kapsam | Bağımlılık |
|---|---|---|---|
| WP-38 | Bekliyor | Faz 0A · Canlı backend durum matrisi (kod yok) | — |
| WP-52 | Kod tamamlandı · cihaz QA bekliyor | Adaptif dashboard · cihaz başına 6/8/12/16 sütun + güvenli layout profilleri | WP-27 base shell |
| WP-53 | R1 Ayarlar kodlandı · diğer ekranlar planlandı | Windows Desktop Design 2.0 · ekran-içi gerçek masaüstü IA | WP-52 + WP-27 base shell |
| WP-45 | Bekliyor | V8-C · Gruplar sırası + kamp ateşi + animasyon (bağımsız) | — |
| WP-46 | Kabul bekliyor | Faz 0B · V8 integration test + Android QA matrisi | WP-40–45 kod aşaması |
| WP-47 | Kabul bekliyor | Faz 0B · Sentry + senkron gözlemlenebilirliği | WP-46 kod aşaması (yönetici istisnası: cihaz QA ertelendi) |
| WP-48 | Bekliyor | V8 beta paketi + cihaz QA kanıtı | WP-40–47 |
| WP-49 | Bekliyor | V8 beta soak + hata kapısı | WP-48 |
| WP-50 | Hazırlık tamamlandı | V8 stable karar + rollback paketi | WP-49 kanıtları + ürün GO/NO-GO |
| WP-27 | Base cihaz QA geçti | Windows desktop shell + klavye/fare + Compact Focus | Ürün kabulü WP-52/53 sonrası |
| WP-28 | Bekliyor | Windows MSIX + imza + update + release QA | WP-53 cihaz/ürün kabulü |
| WP-58 | Otomatik test geçti · cihaz QA bekliyor | Saat Merkezi R1 · Epoch motor + Exact Alarm | — |
| WP-59 | Otomatik test geçti · cihaz QA bekliyor | Saat Merkezi R2 · Alarm 2.0 + Çoklu Timer Studio | WP-58 |
| WP-60 | Otomatik test geçti · cihaz QA bekliyor | Saat Merkezi R3 · Dünya / Kronometre / StandBy | WP-58 |

> **Dağıtım notu:** WP-39 iptal edildi. **WP-40** V8-A'nın temelidir; WP-41/42 ondan sonra, ikisi `study_providers` timer-sync'i paylaştığı için birbirleriyle paralel değildir. WP-43, V8-A'dan sonra başlar. WP-44 ve WP-45 ayrık dosyalarda bağımsız yürütülebilir.

> ✅ **Windows çakışma kontrolü:** WP-52 dashboard/settings presentation dosyalarında; Claude WP-41/42/51 notification/widget/native dosyalarında, SAHİP kesişimi yok. WP-53 `features/home/**` yüzeyini WP-52 ile paylaştığı için onun kabulünden sonra; WP-28 paketleme de WP-53 ürün kabulünden sonra serileştirilir.

> ✅ Çakışma kontrolü: WP-37 ve WP-38 yalnız kendi yeni doc dosyalarına yazar (`docs/DENETIM-FAZ0A.md` vs `docs/BACKEND-DURUM.md`), `app/**` ve `supabase/**`'a dokunmaz → **paralel güvenli**, aktif lane yok.


### WP-41: V8-A · Canlı Chronometer Bildirim (Başlat/Durdur) 🔔
- **Program/Faz:** V8-A · **Bağımlılık: WP-40 (tamamlandı)**
- **Ajan:** Claude (Codex'ten devir — Codex WP-47'de; kullanıcı talimatı)
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · kod+beta hattı (v11–v15) + in-app start hotfix
- **Problem:** Bildirimde canlı `HH:MM:SS` + Başlat/Durdur, app açmadan yönetim (istek 1).
- **Kapsam dışı:** Widget (→WP-42), state store (WP-40).
- **SAHİP dosyalar (yaz):** `app/lib/core/notifications/timer_notification_service.dart`, ilgili notification receiver Kotlin.
- **DOKUNMA:** `study_providers.dart` (WP-40 sahibi — yalnız oku), widget (WP-42).
- **Adımlar:** [x] dar görünüm (HH:MM:SS + tek durum + Başlat/Durdur); [x] native `Chronometer` (usesChronometer); [x] butonlar Flutter açmadan sıralı native komut kaydına yazar. Geniş görünümdeki Sıfırla / +1 dk, timer state eylemi olarak ayrı UI kapsamıdır.
- **Kabul (ölçülebilir):** Kod/test/Android build geçti. 20 ardışık Başlat/Durdur (app kapalı), canlı akan saat ve bildirim/uygulama paritesi için cihaz videosu bekleniyor (`Cihazda doğrulanmalı`).
- **Tuzaklar:** Bildirim son görünümü OEM'e bağlı — hedef ulaşılabilir ama piksel garanti değil. `study_providers` timer-sync WP-40 kapsamında; buraya taşırsan WP-42 ile çakışır.
- **Model önerisi:** 🔴 Opus
- **Kök neden (Claude, beta-v8 QA):** İki ayrı bildirim var — (a) FGS'in zorunlu statik bildirimi (`timer_foreground_service`, kronometre/buton yok), (b) WP-41 zengin bildirimi (`study_timer_ongoing`, importance LOW). LOW olan altta/silik kaldığı için kullanıcı statik olanı görüp "değişmemiş" diyor. Ayrıca kullanıcının cihazında **hem stable hem beta kurulu** → 2 bildirim gözlemi bundan (teşhis kirli). Temiz teşhis için stable durdurulmalı. **Asıl mimari boşluk WP-42 ile ortak (aşağıda).**

- **Cihaz QA turu 2 (beta-v10, 2026-07-13):** ÇEKİRDEK ÇALIŞIYOR ✅ — tek bildirim, saniye saniye akan `HH:MM:SS`, app tamamen kapalıyken Durdur işleniyor ve süre doğru kaydediliyor. Kullanıcı **2 revizyon** istedi (ekran görüntüsü: HyperOS "Live notifications" panelinde native Kronometre uygulaması `00:05.32` Lap/Stop ile üstte, bizimki `00:00:10` + "Odak Kampı çalışıyor" alt satırıyla altta):
  - **R1 — Gövde yazısı kaldır:** Bildirimde hâlâ görünen "Odak Kampı çalışıyor" alt satırı kalksın; saat uygulaması gibi yalnız akan süre + buton kalsın. **Plan:** `timer_foreground_service.dart` içindeki 3 `notificationText: 'Odak Kampı çalışıyor'` (start→updateService, start→startService, `_TimerTask._refreshNotification`) boş string `''` yapılır. Bazı OEM boş text'i yok saymazsa tek boşluk `' '` denenir. Kanıt: cihazda alt satır görünmez.
  - **R2 — Durdur kalıcı toggle (Durdur↔Başlat):** Durdur'a basınca bildirim **kaybolmasın**; süre kaydedilsin (işlev doğru) ama buton **Başlat**'a dönsün, kullanıcı app açmadan tekrar başlatabilsin. **Plan:** (1) Harici komut modeline `'start'` eklenir (`timer_external_command_store.dart`; `command` alanı `start`/`stop`, `at` ikisi için var). (2) FGS mod bayrağı prefs `timer_fg_mode` = `running`/`idle`. (3) Durdur handler: stop komutu yaz (`at=now`) + `sendDataToMain` → **`stopService` YOK**; bunun yerine `updateService(title: '00:00:00', notificationButtons: [Başlat id=timer_start])`, mode=`idle`; `onRepeatEvent` idle iken tazelemeyi durdurur (süre donar). (4) Başlat handler (`id=timer_start`): start komutu yaz (`at=now`), `timer_active_started_at=now`, mode=`running`, buton→Durdur; `onRepeatEvent` yeniden akıtır + `sendDataToMain`. (5) Ana isolate `study_providers._processPendingExternalCommand` artık `'start'`i de işler → `startedAt=at` ile yeni oturum başlatır (server-authoritative session insert; `sequence` ile idempotent); `'stop'` zaten var. **Ürün kararı (R2-a):** Sayaç idle iken FGS canlı kalır → bildirim sürekli görünür (pil/politika bedeli). Öneri: idle iken bildirim `ongoing`/sticky olmasın (kullanıcı kaydırıp atabilsin); tam durdurma app içinde zaten var. Alternatif = idle'da FGS'i durdurup normal (ongoing olmayan) `flutter_local_notifications` bildirimi + native `BroadcastReceiver` (app-kapalı Başlat) — ama çift-sistem karmaşasını geri getirir; bu geçiş asıl olarak WP-51 native yeniden yazımında yapılır. **Önerilen: Option A (FGS canlı toggle).**
  - **Not (yan gözlem):** Kullanıcı "ana uygulamanın bildirim iznini kapattım ama hâlâ çıkıyor" dedi — bu beklenen: `dataSync` foreground service'in zorunlu bildirimi POST_NOTIFICATIONS iznine bağlı değildir (servis çalıştıkça görünür). Ayrı bug değil; R2 idle davranışıyla birlikte kullanıcıya kapatma yolu (ongoing kaldırma) sunulur.
  - **Tasarım isteği (native saat/dinamik panel görünümü) → yeni WP-51'e ayrıldı** (native `Chronometer`/`ProgressStyle`/Live Updates gerektirir; flutter_foreground_task text-update ile yaklaşık; gerçek native kronometre için Kotlin bildirim). R1/R2 önce, WP-51 sonra.
  - **Kabul (R1/R2, ölçülebilir):** Cihazda (a) bildirimde gövde yazısı yok, yalnız süre+buton; (b) Durdur→süre kaydedilir + bildirim `00:00:00` + **Başlat** olur; (c) Başlat→app açmadan yeni oturum başlar, süre akar; (d) 10 ardışık Durdur/Başlat (app kapalı) oturum sayımını bozmaz. `Cihazda doğrulanmalı`.

- **Uygulama (beta-v11, 2026-07-13, Claude):** R1+R2 kodlandı. **Plandan sapma (daha sağlam):** Tek-atımlık komut store yerine, app-kapalı Durdur her tamamlanan çalışma aralığını `timer_pending_intervals` **kuyruğuna** yazar (last-write-wins komut modeli arka arkaya Durdur→Başlat'ta ilk oturumu kaybederdi — kabul (d) bunu men eder). Değişen dosyalar: `timer_foreground_service.dart` (gövde yazısı `''`; `_runningButtons`/`_idleButtons`; `_pauseToIdle`→kuyruğa aralık + idle + Başlat butonu, `stopService` YOK; `_resumeToRunning`→`timer_active_started_at=now` + running + Durdur; `timer_fg_mode` bayrağı); `study_providers.dart` (`_reconcileBackgroundTimer`→kuyruğu **server-authoritative** `_recordSession` ile yaz + FGS moduna göre sayacı uzlaştır, auth hazır değilse kuyruğu koru; `_syncBackgroundTimerState` = reconcile + widget komutu; dispose-sonrası `ref` yarışları için `_disposed`/guard'lar). Widget'ın tek-atımlık `timer_external_command` yolu (WP-42) korundu. **Test:** yeni `timer_background_reconcile_test.dart` (idle→oturum+dur; Durdur→Başlat→eski oturum+yeni çalışır; 5 çift→5 oturum). `flutter analyze` 0 + **286 test** yeşil + **beta-v11 APK `1.0.10+11` (`app-beta-release.apk`, 64 MB) PASS**. `Kodda doğrulandı` — cihaz videosu bekliyor.
  - **Ürün kararı (R2-a, açık):** Idle'da FGS canlı kaldığı için bildirim görünür kalır (flutter_foreground_task bildirimi doğası gereği `ongoing`/kaydırılamaz). Tam "kaydırıp atma" ancak WP-51 native yeniden yazımıyla gelir. Beta-v11'de idle = `00:00:00`+Başlat (temiz), ama swipe-dismiss yok. Kullanıcı onayı bekliyor.

### WP-42 (+WP-51 birleşik): V8-A · Native Sayaç Servisi — Widget/Bildirim App-Kapalı Kontrol 📲
- **Program/Faz:** V8-A · **Bağımlılık: WP-41 (kod bitti)** · **Kullanıcı kararı: WP-42 + WP-51 tam native olarak birleştirildi**
- **Ajan:** Claude (Codex'ten devir — kullanıcı talimatı)
- **Durum:** [x] **Tamamlandı** (2026-07-13) — native servis ürün kabulü · WP-51 birleşik
- **Uygulama (beta-v12, 2026-07-13, Claude):** Sayaç bildirimi + widget'ı **native Kotlin `StudyTimerService`** yönetir (flutter_foreground_task timer yolundan çıkıldı). Yeni/değişen: `timer/StudyTimerService.kt` (foreground servis: ACTION_START/STOP/STOP_SILENT/TOGGLE, native `Chronometer` bildirim, `timer_pending_intervals` kuyruğu, idle=00:00:00+Başlat kaydırılabilir), `widgets/TimerActionReceiver.kt` (widget düğmesi → servis), `widgets/StudyWidgetProviders.kt` (Chronometer `_ms` epoch anahtarından, Başlat/Durdur durum metni), `widgets/TimerWidgets.kt` (native widget tazeleme), `MainActivity.kt` (method channel `…/timer`: Dart→native start/stop, native→Dart `reconcile` + runtime receiver), `AndroidManifest.xml` (servis kaydı). Dart: `timer_foreground_service.dart` method-channel köprüsüne indirildi; `study_providers.dart` FGS task-data callback yerine `reconcile` method-channel handler + `timer_active_started_at_ms` yazımı. **Server-authoritative kayıt WP-41 reconcile'ıyla korundu** (native yalnız aralık kuyruğa yazar). `flutter analyze` 0 + **286 test** + **beta-v12 release+debug APK PASS** (Kotlin derlendi). `Kodda doğrulandı`.
- **Problem:** Yalnız timer widget besleniyor; stats/leaderboard placeholder (B4).
- **Kapsam dışı:** Bildirim (WP-41), senkron canonical projection (WP-43 sağlar; burada tüketilir).
- **SAHİP dosyalar (yaz):** `app/lib/features/android_widgets/android_widget_service.dart`, `app/android/app/src/main/kotlin/**/widgets/*` (Chronometer RemoteViews), yeni widget besleme pipeline.
- **DOKUNMA:** `study_providers.dart` timer-sync (WP-40/41 — dar okuma), notification (WP-41).
- **Adımlar:** timer widget native `Chronometer`; Başlat/Durdur app açmadan; stats/leaderboard **olay bazlı** besleme (session ekl/düzenle/sil, sync, grup değişimi, gün sınırı, manuel refresh); light/dark + dynamic color; boş-durum.
- **Kabul (ölçülebilir):** Boş durumda anlamlı metin var; oturum, senkronizasyon ve grup/membership akışlarında olay bazlı yenileme var; 48 dp dokunma alanı ile light/dark ve Android 12+ dynamic color kaynakları eklendi. `flutter analyze`, 254 test ve Android debug APK geçti (`Kodda doğrulandı`). Oturum sonrası ≤ 5 sn ve cihaz videosu / ürün kabulü `Cihazda doğrulanmalı`.
- **Tuzaklar:** Saniyede bir Flutter yeniden çizme YOK; periyodik <15 dk garanti değil → native Chronometer + olay bazlı.
- **Model önerisi:** 🔴 Opus
- **Kök neden (Claude, beta-v8 QA):** Widget ekleniyor + yazı gösteriyor ama Başlat/Durdur "işlevsiz". Sebep WP-41 ile **ORTAK**: widget/bildirim butonu `flutter.timer_external_command` prefs'ine komut yazıyor ama bunu **yalnız uygulama açık/onResume/soğuk açılış işliyor** (`study_providers._processPendingExternalCommand`, satır 448). Uygulama kapalıyken komutu tüketen canlı isolate YOK — FGS task handler (`_TimerTask`) yalnız heartbeat atıyor. → Butonlar app kapalıyken **ölü anahtar**. Gerçek düzeltme: FGS task handler'ın komut store'unu okuyup start/stop + bildirim + widget'ı ana isolate olmadan yürütmesi (arka plan komut işleme). WP-40/41/42 bu çekirdeği ertelemiş; kod-tamam kapatılmış ama app-kapalı buton gereksinimi karşılanmıyor.

### WP-51: V8-A · Dinamik Panel / Native Kronometre Bildirim Tasarımı ✨
- **Program/Faz:** V8-A polish (Saat programına köprü) · **Ajan:** Claude · **Durum:** [x] **Tamamlandı** (2026-07-13) — WP-42 ile birleşik native; OEM Live Panel ayrı polish · **Bağımlılık:** WP-41 R1/R2
- **Problem:** Kullanıcı bildirimin **native saat uygulaması gibi** görünmesini istiyor — cihazın dinamik panelinde (HyperOS "Live notifications" / Samsung "Now Bar" / Android 16 "Live Updates") büyük akan saat, dinamik ada terfisi. Şu an flutter_foreground_task her saniye **başlık metnini** güncelliyor (gerçek native `Chronometer` değil) ve dinamik panele terfi etmiyor.
- **Kök gerçek (teknik kısıt):** `flutter_foreground_task` bildirim yapıcısı `setUsesChronometer(true)`, `setWhen(base)`, `setCategory(CATEGORY_STOPWATCH)`, custom `RemoteViews` ve Android 16 `Notification.ProgressStyle` (Live Updates) **desteklemez**. Dinamik panele terfi büyük ölçüde OEM'e ve doğru bildirim kategorisi/şablonuna bağlıdır.
- **Kapsam:** (1) OEM araştırması: HyperOS/Samsung/Pixel dinamik panel terfi kuralları + Android 16 `ProgressStyle`/Live Updates API + `CATEGORY_STOPWATCH`. (2) Native Kotlin foreground bildirimi: `NotificationCompat.setUsesChronometer(true)` + `setWhen(startBase)` (native akan saat — saniyede Flutter update YOK), kategori/şablon, PendingIntent aksiyon butonları → app-kapalı işleyen `BroadcastReceiver` (R2 komut/at mantığını buna taşır). (3) FGS bu native bildirimi kullanır (flutter_foreground_task yerine kendi FGS'imiz veya bildirim override). (4) Cihaz kanıtı (dinamik panelde görünüm + app-kapalı buton).
- **Kapsam dışı:** Sayaç iş mantığı (WP-40/41), widget (WP-42), iOS Live Activity (ayrı WP).
- **SAHİP dosyalar (yaz):** `app/lib/core/background/timer_foreground_service.dart`, `app/lib/core/notifications/**`, yeni `app/android/app/src/main/kotlin/**/notifications/*` (native bildirim + BroadcastReceiver).
- **DOKUNMA:** widget native (WP-42), `study_providers` timer-sync (dar okuma).
- **Kabul (ölçülebilir):** Desteklenen OEM'de bildirim dinamik panele terfi eder + native akan saat gösterir (saniyede Flutter update yok); aksiyon butonları app-kapalı çalışır; desteklemeyen OEM'de düz ama temiz canlı bildirime düşer. `Cihazda doğrulanmalı`.
- **Tuzaklar:** Dinamik panel terfisi OEM garantisi değildir — hedef ulaşılabilir, piksel/panel garanti değil; graceful fallback şart. **Model:** 🔴 Opus

### WP-52: Adaptif Dashboard Grid ve Cihaz Yoğunluğu 🧩
- **Program/Faz:** Ana Sayfa + Windows/tablet adaptasyonu · **Ajan:** Codex · **Durum:** [~] Kod tamamlandı — cihaz QA/ürün kabulü bekliyor · **Bağımlılık:** WP-27 base shell
- **Problem:** Dashboard veri modeli ve render motoru sabit `6×N`; tablet ve geniş Windows alanında kartlar gereğinden büyük kalıyor, aynı anda daha az bilgi gösteriliyor. Kullanıcı cihaz başına daha verimli bir grid istiyor.
- **Kapsam dışı:** Dashboard kartlarının iç veri/grafik mantığını yeniden yazmak, layout'u Supabase ile cihazlar arasında senkronlamak, tema motoru, Windows shell/MSIX.
- **SAHİP dosyalar (yaz):** `app/lib/features/home/dashboard_card.dart`, `dashboard_providers.dart`, `home_screen.dart`, `app/lib/core/grid/grid_reflow.dart`, `app/lib/features/profile/settings_screen.dart` (yalnız Ana Sayfa grid ayarı), ilgili grid/dashboard/settings testleri.
- **DOKUNMA:** `supabase/**`, repository/provider veri kaynakları, `core/theme/**`, `core/navigation/**`, `app/pubspec.yaml`, notification/widget dosyaları.
- **Adımlar:**
  - [x] Cihaz-yerel `DashboardGridDensity` tercihi: **6 / 8 / 12 / 16**; kullanıcı yoğunluğu açıkça seçer, eski `automatic` tercihi güvenli biçimde 6 sütuna göçer.
  - [x] Sabit `kGridColumns=6` bağımlılığını config/reflow/render/drag/resize/backdrop boyunca parametreleştir; kart içerik boyutu aktif sütun oranına göre seçilir.
  - [x] Her sütun yoğunluğu için ayrı yerel layout profili (`6/8/12/16`) sakla. Bir profil ilk açıldığında mevcut düzenden deterministik ölçekle + reflow ile üretilir; geri dönünce önceki profil aynen gelir.
  - [x] Mevcut `dashboard_layout` 6-sütun kaydını kayıpsız v2 profile göçür; migration tamamlanana dek eski anahtarı rollback yedeği olarak koru.
  - [x] Ayarlar'da doğrudan açıklamalı seçim + anlık uygulama; reset yalnız aktif yoğunluk profilini sıfırlar.
  - [x] Düzenleme modunda tek eylemle dikey boşlukları yukarı topla; kartların `x/w/h` değerlerini koru, yalnız `y` değerlerini çakışmasız minimuma indir ve aktif profile kaydet.
  - [~] 6/8/12/16 profil/geçiş/migration/provider, yukarı toplama motoru ve ayarlar widget testleri PASS; `flutter analyze`, tüm 283 test ve Windows release build PASS. Gerçek telefon/tablet/Windows resize/görsel QA bekliyor.
- **Veri/Migration etkisi:** Sunucu/migration yok. Yalnız `SharedPreferences`; layout hesap değil cihaz bazlıdır. Geri alma = v2 profillerini yok sayıp korunan eski `dashboard_layout` anahtarına dönmek.
- **RLS/Güvenlik:** Yeni ağ/veri yetkisi yok; kullanıcı içeriği veya sır eklenmez.
- **Edge-case'ler:** 6↔8↔12↔16 tekrar geçişi, eksik/bozuk profil, kartın yeni sütun sınırını aşması, dar split-screen/tablet rotation, %200 ölçek, boş dashboard, aktif drag sırasında ayar değişimi.
- **Kabul (ölçülebilir):** 20 ardışık 6→8→12→16→6 geçişinde kart kaybı/çakışma 0; aynı profile dönüşte encode listesi birebir aynı; eski 6-grid kullanıcı düzenindeki kart sayısı/relatif sıra korunur; 600/800/1200/1440 logical px'te overflow 0; telefon, tablet ve Windows gerçek cihaz ekran görüntüsü; analyze + tüm testler yeşil. `Cihazda doğrulanmalı`.
- **Tuzaklar:** Tek layout'u her geçişte tekrar ölçekleyip yuvarlama drift'i üretmek; yüksek sütun yoğunluğunu dar ekranda zorlamak; kart içeriğini okunamayacak 1 hücreye indirmek; desktop için ikinci dashboard veri modeli kurmak.
- **Model önerisi:** 🔴 Opus
- **Kod kanıtı (2026-07-13):** R2 dahil `flutter analyze` PASS; grid/dashboard odak testleri 20/20 PASS; tüm testler 283/283 PASS; `flutter build windows --release --dart-define-from-file=env.json` PASS (`online_study_room.exe`).

### WP-53: Windows Desktop Design 2.0 — Ekran-İçi Ürün IA 🖥️
- **Program/Faz:** Windows masaüstü kalite programı · **Ajan:** Codex · **Durum:** [~] R1 Ayarlar IA kodlandı — diğer ekranlar planlandı · **Bağımlılık:** WP-52 + WP-27 base shell
- **Problem:** WP-27 gerçek Windows shell, compact focus ve responsive panel temelini kurdu; fakat birçok ekran-içi kart/form bileşeni mobil uygulamayla ortak görsel yoğunluğu ve akışı kullanıyor. Ürün hâlâ “mobil uygulama büyütülmüş” hissini tamamen atmış değil.
- **Kapsam dışı:** Backend/repository/RLS, yeni özellik veya istatistik metriği, tema motorunu yeniden yazma, MSIX/imza/update (WP-28), Flutter'ı WinUI ile yeniden yazma.
- **SAHİP dosyalar (yaz):** `app/lib/features/desktop/**`, `features/home/**`, `features/clock/**`, `features/classroom/**`, `features/stats/**`, `features/profile/**` (yalnız Windows presentation/adapters), desktop golden/widget testleri, `docs/WINDOWS-URUN-PLANI.md`.
- **DOKUNMA:** `data/**`, `supabase/**`, `core/theme/**` (tokenları yalnız tüket), `core/navigation/**` (WP-27 shell sözleşmesi korunur), notification/widget/native Android, `app/windows/**` (WP-28).
- **Adımlar:**
  - [x] **R1 Ayarlar IA:** Açılır kategori→iç ayar çift katmanını kaldır; tüm ayarları doğrudan kart/eylem yap; Gruplar sayacı ayarını bu ekrandan çıkar; Bildirim Merkezi ve sürüm notlarını tek tıkla aç.
  - [ ] Beş ana ekran için desktop wireframe ve bilgi önceliği: Ana Sayfa çalışma cockpit'i; Saat odak workspace'i; Gruplar master-detail/kamp bağlamı; İstatistik çok panelli analiz; Profil/Ayarlar kategori+detay.
  - [ ] Mobil AppBar/uzun tek kolon listelerini `≥1008` genişlikte desktop command bar, section navigation, master-detail, tablo/panel ve bağlamsal eylemlere dönüştür; mobil branch aynen korunur.
  - [ ] Fare/klavye sözleşmesi: hover/right-click, görünür focus, Tab sırası, Esc, context command ve boş/loading/error durumları; hiçbir temel yolculuk mouse zorunlu olmaz.
  - [ ] Windows 11 yoğunluk/spacing/radius katmanını mevcut tema tokenlarından türet; rastgele sabit renk veya ikinci tema sistemi kurma.
  - [ ] 1366×768/1080p/1440p × %100/%125/%150/%200 golden/overflow matrisi; Narrator/high-contrast/reduce-motion ve resize stress cihaz QA.
- **Veri/Migration etkisi:** Yok; aynı provider/repository/state tüketilir. Geri alma = Windows presentation adaptörlerini kaldırıp ortak mobil widget fallback'ine dönmek.
- **RLS/Güvenlik:** Yetki/veri değişmez; admin ve sosyal görünürlük mevcut RLS ile sınırlı kalır.
- **Edge-case'ler:** boş grup, hiç session yok, offline/cache, uzun Türkçe metin, 200% ölçek, 560 px minimum pencere, modal/tooltip overlay, çoklu monitör/DPI geçişi.
- **Kabul (ölçülebilir):** `≥1008` genişlikte beş ana ekranın hiçbirinde mobil alt menü/AppBar veya tam sayfa tek kolon akış ana IA değildir; her ekranda en az bir desktop'a özgü bağlamsal panel/komut alanı vardır; yalnız klavyeyle ana 5 yolculuk PASS; QA matrisinde overflow/kırmızı-gri ErrorWidget 0; 10 sn resize stress'te P0/P1 0; karşılaştırmalı cihaz ekran görüntülerini ürün sahibi kabul eder. `Cihazda doğrulanmalı`.
- **Tuzaklar:** Yalnız padding/rail değiştirip redesign saymak; işlevleri masaüstünde çoğaltmak; aynı veriyi ikinci provider ağacıyla çatallamak; custom title bar/Mica'yı Snap/high-contrast kanıtı olmadan eklemek.
- **Model önerisi:** 🔴 Opus
- **R1 kod kanıtı (2026-07-13):** `ExpansionTile` 0; doğrudan bildirim/sürüm navigasyon widget testi PASS; grid legacy Auto→6 göç testi PASS; `flutter analyze` + 283/283 test + Windows release build PASS. Görsel ürün kabulü `Cihazda doğrulanmalı`.

> ✅ **Çakışma/seri planı:** WP-52, Claude WP-41/42/51 notification-widget-native dosyalarıyla kesişmez ve paralel güvenlidir. WP-53, WP-52'nin `features/home/**` yüzeyini paylaştığı için **WP-52 kabulünden sonra** başlar. WP-28 paketleme/release, gerçek desktop tasarımı ürün kabulü almadan başlamaz: `WP-27 base → WP-52 → WP-53 → WP-28`.

### WP-45: V8-C · Gruplar Sırası + Kamp Ateşi + Animasyon 🔥
- **Program/Faz:** V8-C · **Bağımsız — WP-44 ile paralel güvenli (farklı dosyalar)**
- **Ajan:** Claude
- **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor
- **Problem:** Kamp ateşi üste; sıra ateş→hedef→sıralama; toparlanma animasyonu uzun (istek 4).
- **Kapsam dışı:** İstatistik sekmesi (WP-44); grup hedef/trend kartlarının iç mantığı.
- **SAHİP dosyalar (yaz):** `app/lib/features/classroom/classroom_screen.dart`, `app/lib/features/classroom/widgets/campfire_scene.dart` (animasyon süresi).
- **DOKUNMA:** `features/stats/**` (WP-44), group_goal_card/group_trend_card (yalnız yeniden sırala).
- **Adımlar:** [x] sıra = kamp ateşi → grup hedefi → trend → yönetim (davet kodu alttaki açılır "Grup bilgileri" paneline, ad+sohbet/ayarlar kompakt başlığa taşındı; grup değiştir zaten AppBar'da); [x] toparlanma animasyonu 560→420 ms; [x] `reduce-motion` desteği (sonsuz alev/ember/nefes döngüsü durur + yerleşim anında).
- **Kabul (ölçülebilir):** ✅ Yerleşim 420 ms (≤ 700 ms hedefi); reduce-motion davranışsal testle doğrulandı (pumpAndSettle artık oturuyor = sonsuz animasyon durdu); analyze 0, 261 test yeşil (`Kodda doğrulandı`). "İlk sahne ≤ 300 ms" ve görsel akıcılık `Cihazda doğrulanmalı`.
- **Tuzaklar:** Sonsuz/dekoratif animasyon batarya tüketmemeli → reduce-motion'da durur.
- **Model önerisi:** 🔵 Sonnet
- **Not (`Ürün kararı gerekiyor`):** §8.3 "Gruplar" sırasında **grup sıralaması** kartı geçiyor ama bu sekmede sıralama kartı yok (leaderboard İstatistikler sekmesinde). Ayrı sıralama kartı eklemek kapsam dışı + stats'ı çoğaltır; eklensin mi, kullanıcı kararı. Mevcut kartlarla ulaşılabilir sıra: ateş → hedef → trend → yönetim.
- **Cihaz QA turu 1 (beta-v8, 2026-07-12):** Sıra ✅ (kamp ateşi üstte). Sorun: sahne çok uzundu, üst/altta gereksiz boşluk → **düzeltildi** (`_SceneFrame` 480→360, kompozisyon orantılı sıkıştı; commit `11df506`). Yeni beta ile **cihazda yeniden doğrulanmalı**; boyut değeri gerekirse ince ayar (`Cihazda doğrulanmalı`).

### WP-46: Faz 0B · V8 Integration Test ve Android QA Matrisi 🧪
- **Program/Faz:** Faz 0B (KALITE-PROGRAMI §7, §9) · **Ajan:** Codex · **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor
- **Problem:** Native arka plan/OEM/iki cihaz davranışı ölçülebilir ve tekrarlanabilir değil.
- **Kapsam dışı:** Timer/widget ürün kodu, Sentry (→ WP-47), beta yayınlama (→ WP-48).
- **SAHİP dosyalar (yaz):** `app/integration_test/v8_critical_flows_test.dart`, `app/test/features/v8_critical_flows_test.dart`, `app/test/support/v8_test_*`, `docs/QA-V8-ANDROID.md`, `app/pubspec.yaml` (integration_test SDK).
- **DOKUNMA:** `app/lib/data/providers/study_providers.dart`, `app/lib/features/android_widgets/**`, `app/android/**`, `app/lib/main.dart`.
- **Adımlar:** [x] session insert/update/delete + Istanbul 23:59–00:01 smoke testi; [x] gerçek Android integration binding'i; [x] Samsung/Pixel cold-start, force-stop, kilit, reboot, pil optimizasyonu, widget/bildirim ve iki cihaz matrisi; [x] video/sonuç şablonu.
- **Veri/Migration etkisi:** Yok; geri alma = test/doküman dosyalarını kaldırma.
- **RLS/Güvenlik:** Test hesabı/RLS izolasyonu; service-role ve gizli değer kanıta girmez.
- **Edge-case'ler:** İzin reddi, widget yok, yanlış saat dilimi, beta/stable paket çakışması.
- **Kabul:** 11 cihaz senaryosu matrise yazıldı; 23:59–00:01 smoke testi, gerçek integration binding Windows koşumu, analyze 0, 263 test ve Android debug APK `Kodda doğrulandı`. Samsung/Pixel kanıtları ve gerçek Android `flutter test -d <cihaz> integration_test/v8_critical_flows_test.dart` koşumu `Cihazda doğrulanmalı`.
- **Tuzaklar:** Emulator OEM/foreground-service kanıtı değildir. **Dal:** `wp46-v8-qa-harness` · **Model:** 🔴 Opus

### WP-47: Faz 0B · Sentry ve Senkron Gözlemlenebilirliği 📡
- **Program/Faz:** Faz 0B (KALITE-PROGRAMI §5.1, §7) · **Ajan:** Codex · **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor · **Bağımlılık:** WP-46 kod aşaması (yönetici istisnası)
- **Problem:** Crash, foreground restore ve outbox/realtime gecikmesi üretimde ölçülemiyor.
- **Kapsam dışı:** Kullanıcı davranış analitiği, PII, server-authoritative başarı motoru.
- **SAHİP dosyalar (yaz):** `app/lib/core/observability/**`, `app/lib/main.dart`, `app/pubspec.yaml`, `app/lib/data/providers/study_providers.dart` (yalnız restore breadcrumb), `app/lib/data/repositories/offline/offline_first_study_repository.dart` (yalnız outbox/realtime breadcrumb), `app/windows/flutter/generated_plugin_registrant.cc`, `app/windows/flutter/generated_plugins.cmake`, `app/test/core/observability/**`, `docs/OBSERVABILITY-V8.md`.
- **DOKUNMA:** `core/theme/**`, `supabase/migrations/**`, timer/widget ürün mantığı.
- **Adımlar:** [x] Sentry ortam/opt-out başlatma; [x] PII içermeyen timer-restore/outbox/realtime breadcrumb'ları; [x] telemetry kapalı hata yolu testi ve release kontrol listesi.
- **Veri/Migration etkisi:** Yok; geri alma = telemetry kapatma/paket kaldırma.
- **RLS/Güvenlik:** DSN dışı gizli yok; e-posta/token/ham session gönderilmez.
- **Edge-case'ler:** DSN/ağ yok, SDK init hatası, debug-beta-stable ayrımı.
- **Kabul:** Telemetry kapalıyken SDK hiç başlatılmaz; bilinen hata ham metin yerine yalnız türüyle yakalanır; timer restore/outbox/realtime breadcrumb'ları yalnız int/bool taşır. `flutter analyze` 0, 23 ilgili test ve Android debug APK `Kodda doğrulandı`. Gerçek beta DSN ile breadcrumb/opt-out kanıtı ve ürün kabulü `Cihazda doğrulanmalı`.
- **Tuzaklar:** `pubspec.yaml`/`main.dart` sıcak dosyadır; aktif çakışma temizlenmeden başlanmaz. **Dal:** `wp47-observability` · **Model:** 🔴 Opus

### WP-48: V8 · Beta Paketi ve Cihaz QA Kanıtı 📱
- **Program/Faz:** V8 beta · **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-40–47
- **Problem:** Kodun cihaz davranışı ve beta dağıtım zinciri kanıtlanmadan güven sürümü sayılamaz.
- **Kapsam dışı:** Stable yayın (→ WP-50), yeni özellik ve büyük bug refactor'u.
- **SAHİP dosyalar (yaz):** `app/android/app/src/beta/**` (gerekirse), `docs/QA-V8-ANDROID.md` (kanıt), `docs/V8-BETA-NOTLARI.md`.
- **DOKUNMA:** `core/theme/**`, `supabase/migrations/**`; ürün bug'ı ayrı WP olur.
- **Adımlar:** [ ] Mevcut beta paket kimliğiyle APK + rollback APK; [ ] WP-46 matrisiyle Samsung/Pixel video; [ ] P0/P1 bulgularını ayrı kartlara ayır.
- **Veri/Migration etkisi:** Yok; geri alma = önceki beta APK.
- **RLS/Güvenlik:** Test hesabı, redakte edilmiş kanıtlar.
- **Edge-case'ler:** Güncelleme üstüne kurulum, force-stop, pil optimizasyonu, stable+beta aynı cihaz.
- **Kabul:** Samsung+Pixel kritik-yol videosu; 20 bildirim aksiyonu; widget ≤5 sn; P0=0.
- **Tuzaklar:** Ajan cihaz videosunu taklit ederek kapatamaz. **Dal:** `wp48-v8-beta-qa` · **Model:** 🔴 Opus

### WP-49: V8 · Beta Soak ve Hata Kapısı ⏳
- **Program/Faz:** V8 beta → soak · **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-48
- **Problem:** Tek seferlik QA arka plan, pil, gün değişimi ve güncelleme sorunlarını yakalamaz.
- **Kapsam dışı:** Yeni özellik, stable yayınlama (→ WP-50).
- **SAHİP dosyalar (yaz):** `docs/V8-SOAK-RAPORU.md`, `docs/QA-V8-ANDROID.md` (soak bölümü).
- **DOKUNMA:** `app/**`, `supabase/migrations/**`, `app/pubspec.yaml`.
- **Adımlar:** [ ] ≥3 gün günlük soak kontrolü; [ ] crash/service/outbox/widget/pil kaydı; [ ] P0/P1 stop kuralı + WP-50 özeti.
- **Veri/Migration etkisi:** Yok; geri alma = beta güncellemesini durdurup önceki APK'ya dönüş.
- **RLS/Güvenlik:** Redakte test hesabı kanıtı.
- **Edge-case'ler:** reboot, gün sınırı, ağ kaybı, iki cihaz farklı sürüm.
- **Kabul:** ≥3 gün, P0=0, açık P1 listesi ve rollback kararı.
- **Tuzaklar:** Soak kısaltılamaz. **Dal:** `wp49-v8-soak` · **Model:** 🟣 Pro

### WP-50: V8 · Stable Karar ve Rollback Paketi 🚦
- **Program/Faz:** V8 stable kalite kapısı · **Ajan:** Codex (hazırlık) · **Durum:** [~] Hazırlık dokümanları tamamlandı — kanıt/ürün kararı bekliyor · **Bağımlılık:** WP-49
- **Problem:** Kanıt ve geri dönüş planı olmadan stable kararı kullanıcıyı kırık sürümde bırakabilir.
- **Kapsam dışı:** Yeni özellik, migration/RLS genişletmesi, Saat/Tema/Başarım programını açmak.
- **SAHİP dosyalar (yaz):** `docs/V8-RELEASE-GATE.md`, `docs/V8-ROLLBACK.md`, `docs/V8-RELEASE-NOTLARI.md`.
- **DOKUNMA:** `app/**`, `supabase/migrations/**`; sürüm numarası ürün sahibinin yayın kararıyla ayrı işlem.
- **Adımlar:** [x] WP-46–49 kanıtları için kalite kapısı ve kayıt şablonu; [x] Android-safe go/no-go + rollback planı ve yayımlanamaz not taslağı; [ ] WP-46–49 kanıtlarını gerçek değerlerle doğrula, ürün kabulüyle GO/NO-GO kararı ver.
- **Veri/Migration etkisi:** Yeni migration yok; geri alma önceki imzalı APK + sunucu geri alma sırası.
- **RLS/Güvenlik:** WP-38 canlı migration/Edge Function matrisi tekrar doğrulanır; service-role artefakta girmez.
- **Edge-case'ler:** İmza uyumsuzluğu, yayın sonrası crash, migration geri alma, beta/stable ayrımı.
- **Kabul:** Release gate/rollback/notlar `Kodda doğrulandı`; gerçek kanıt alanları bilerek boş/NO-GO. Her kapı PASS/NO-GO kanıtlı olmadan ürün sahibi stable kararını vermez; cihaz QA/kabul yoksa “yayınlandı” yazılmaz.
- **Tuzaklar:** Ajan tek başına stable yayınlayamaz. **Dal:** `wp50-v8-release-gate` · **Model:** 🟣 Pro

### WP-27: Windows Desktop Shell, Etkileşim ve Compact Focus 🖥️
- **Program/Faz:** Windows masaüstü (`KALITE-PROGRAMI §8.7`, `docs/WINDOWS-URUN-PLANI.md`) · **Ajan:** Codex · **Durum:** [~] Base gerçek cihaz QA geçti — ürün kabulü WP-52/53 sonrası
- **Problem:** Uygulama Windows'ta çalışsa da mobil alt navigasyon ve genişleyen 6 sütunlu grid nedeniyle masaüstü ürünü gibi davranmıyor; mini mod bütün uygulamayı küçük pencereye sıkıştırıyor.
- **Kapsam dışı:** Installer/MSIX/imza/update (→ WP-28), yeni backend özelliği, Windows system tray ve Rahatsız Etmeyin entegrasyonu (ürün kararı).
- **SAHİP dosyalar (yaz):** `app/lib/core/desktop/**`, `app/lib/core/navigation/home_shell.dart`, `app/lib/features/desktop/**`, `app/lib/features/home/home_screen.dart`, `app/lib/features/clock/**`, `app/lib/features/classroom/**`, `app/lib/features/stats/**`, `app/lib/features/profile/**` (yalnız Windows presentation adaptörleri), ilgili desktop/widget testleri ve `docs/WINDOWS-URUN-PLANI.md`.
- **DOKUNMA:** `app/android/**`, notification/widget native ürün mantığı, `supabase/**`, repository arayüzleri, `core/theme/**` (tokenları yalnız tüket), Windows installer/runner metadata (→ WP-28).
- **Adımlar:**
  - [~] Flutter 3.44.2 + VS 2022 ile gerçek Windows release build + launch smoke PASS; debug ve ölçümlü cihaz matrisi bekliyor.
  - [x] `<640` minimal, `640–1007` kompakt rail, `≥1008` geniş etiketli rail; mobil `NavigationBar` aynen korunur.
  - [x] Desktop komut alanı + max 1440 px içerik; dashboard kayıt modeli çatallanmadı.
  - [x] Ortak Windows 11 sayfa başlığı/panel sistemi; Ana Sayfa, Saat, Gruplar, İstatistik ve Profil için mobil AppBar/list kopyası olmayan responsive desktop sunum dalları.
  - [x] Ayrı Compact Focus yüzeyi (süre/mod/ders + başlat/durdur + pin/tam pencere); tüm uygulamayı küçültme kaldırıldı. Pause mevcut timer state modelinde olmadığı için eklenmedi.
  - [~] Normal bounds/maximize/monitör/pin/compact state persist + ekran dışı clamp otomatik testli; sleep/resume/multi-monitor cihaz kabulü bekliyor.
  - [~] `Ctrl+1…5`, `Ctrl+Shift+M/P`, `F5`, tooltip, hover/right-click tamam; timer için global `Space`/`Esc` mevcut metin alanları ve dialog davranışıyla birlikte sonraki cihaz UX turunda doğrulanacak.
  - [~] Temel Semantics/focus mevcut; Narrator, high contrast, reduce motion ve %100–%200 cihaz matrisi bekliyor.
- **Otomatik kanıt (2026-07-13, retest 3):** `flutter analyze` PASS; `flutter test --dart-define-from-file=env.json` PASS (**278**); `flutter build windows --release --dart-define-from-file=env.json` PASS. Debug compact geçişi `360×220`, `Responding=True`; önceki `No Overlay widget found` + RenderFlex overflow yeniden oluşmadı. Regression testi MaterialApp builder dışında Tooltip + bağımsız compact Overlay'i doğrular. Gerçek kullanıcı compact retesti bekliyor.
- **Veri/Migration etkisi:** Yok. Yalnız yerel pencere tercihleri; geri alma = desktop shell seçimini kapatıp mevcut mobile shell fallback'ine dönmek.
- **RLS/Güvenlik:** Yeni veri yetkisi yok; gizli değer yok. Desktop da aynı Supabase/RLS ve offline repository katmanını tüketir.
- **Edge-case'ler:** 1366×768, ultra-wide, %200 ölçek, ikinci monitör çıkarma, minimize/sleep sırasında timer, offline login/cache, text field odaktayken Space kısayolu, compact modda hata/boş state.
- **Kabul (ölçülebilir):** Windows release ilk anlamlı pencere ≤2.5 sn; sekme geçişi ≤150 ms; compact↔normal ≤300 ms; 10 sn resize'da overflow/kırmızı ekran 0 ve hedef ≥55 fps; 1366×768/1080p/1440p × %100/%125/%150/%200 matriste taşma 0; yalnız klavye ile temel yolculuk PASS; Narrator/high-contrast kanıtı; mobil golden/widget testleri değişmeden yeşil. `Cihazda doğrulanmalı`.
- **Tuzaklar:** Flutter'ı WinUI'ya yeniden yazma; desktop için ikinci veri/state sistemi kurma; özel Mica title bar'ı Snap/high-contrast/DPI kanıtı olmadan açma; mini modda tam app ağacını sıkıştırma.
- **Dal önerisi:** `wp27-windows-desktop-shell` · **Model önerisi:** 🔴 Opus


### WP-54: Tema Stüdyosu R1 (Token Motoru ve Hazır Temalar) 🎨
- **Program/Faz:** Tema Stüdyosu (KALITE-PROGRAMI §8.5)
- **Ajan:** Grok
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · token motoru + 12 preset
- **Problem:** Sabit renk kullanımının sonlandırılıp, `docs/TEMA-MIMARISI.md` 5 katmanlı ThemeExtension altyapısı.
- **Kapsam dışı:** Tema seçme ekranı (→ WP-55).
- **SAHİP dosyalar:**
  - `app/lib/core/theme/theme_tokens.dart` (5 extension + context.appColors…)
  - `app/lib/core/theme/theme_presets.dart` (12 sanat ailesi)
  - `app/lib/core/theme/app_theme.dart` (fromPreset motoru)
  - `app/lib/core/theme/theme_settings.dart` (familyId kalıcı)
  - `app/lib/main.dart` (family wiring)
- **Adımlar:**
  - [x] AppColors / AppTypography / AppShapes / AppAtmosphere / AppMotion
  - [x] 12 preset (Campfire…Material You)
  - [x] `AppTheme.fromPreset` + eski AppPalette köprüsü + palette→family migrate
  - [x] ThemeSettings.familyId prefs; setPalette family hizalar
  - [x] Material bileşen temaları token’dan (Card/AppBar/Nav/Input…)
  - [~] Uygulama geneli `Colors.x` tarama: motor hazır; tek tek widget göçü kademeli (WP-55/sonraki). Yeni kod `context.appColors` kullanmalı.
- **Veri/Migration:** Yerel prefs `theme_family`. Geri alma: family yoksa palette migrate.
- **Kabul:** Analyze 0 + 7 unit/widget test PASS — `Kodda doğrulandı`. 12 ailenin görsel beta’sı — `Cihazda doğrulanmalı`.
- **Dal:** — (main) · **Model:** Grok

### WP-55: Tema Stüdyosu R2 (Katmanlı Tema Editörü UI) 🎛️
- **Program/Faz:** Tema Stüdyosu
- **Ajan:** Grok
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · Tema Stüdyosu UI
- **Problem:** 12 temadan seçim + canlı önizleme + mood.
- **Kapsam dışı:** PRO hex stüdyo; sunucu `user_preferences` JSON (yerel prefs familyId yeterli R2).
- **SAHİP:** `theme_studio_screen.dart` + `appearance_screen` glue
- **Adımlar:**
  - [x] Huni: Tema → Mood → Şekil (önizleme) → Uygula
  - [x] Canlı Dashboard + Sayaç önizlemesi (preset renkleri)
  - [x] `setFamily` / `setMode` — restart yok
  - [x] Görünüm ekranından giriş kartı
  - [x] Widget test PASS
- **Kabul:** Anında tema — `Kodda doğrulandı`. Cihaz görsel — `Cihazda doğrulanmalı`.

### WP-56: Başarım 3.0 R1 (Server-Authoritative Motor ve SQL) 🏆
- **Program/Faz:** Başarım 3.0 (KALITE-PROGRAMI §8.6)
- **Ajan:** Grok
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · ledger+wire-up · SQL 0024–0027
- **Problem:** İstemci taraflı (hileye açık) başarı hesaplamalarının `docs/BASARIM-MIMARISI.md`'deki Server-Authoritative ledger sistemine geçirilmesi.
- **Kapsam dışı:** Profil vitrini ve rozet çizimleri (→ WP-57).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/0024_achievements_ledger.sql`
  - `app/lib/data/providers/achievement_provider.dart` + `gamification_providers.dart` (wire-up)
  - `app/lib/data/repositories/supabase/supabase_gamification_repository.dart` (istemci XP yazımı kapalı)
  - (+ motor/repo/model/test)
- **DOKUNMA (oku, değiştirme):**
  - `docs/BASARIM-MIMARISI.md` · `study_providers.dart` (Claude — yalnız okuma)
- **Adımlar:**
  - [x] `xp_ledger` + RPC + dict seed + B7 RLS
  - [x] İstemci API dual repo
  - [x] **Wire-up:** `gamificationProgressSyncProvider` → `process_achievement_event` (istemci `AchievementEngine` yazımı kaldırıldı)
  - [x] Supabase `updateProfile` yalnız streak_freezes + selected_badges; `updateUserAchievements` no-op
  - [x] Profil kartı + Başarılar ekranı sync izliyor
  - [x] Birim test: ledger 8 + wire-up 1 = 9 PASS
- **Veri/Migration etkisi:** `0024` canlıya **kullanıcı uyguladı**. Geri alma: migration başı notu.
- **RLS/Güvenlik:** Ledger/RPC only; istemci XP yolu kapalı.
- **Edge-case'ler:** Idempotent event_key. Grup/sosyal metrik R1=0. `secret_break_enemy` veri yok.
- **Kabul:** Çift XP yok — `Kodda doğrulandı`. Beta: profil/başarılar aç → oturum sonrası XP artışı; ikinci açılışta çift artmama — `Cihazda doğrulanmalı`.
- **Uygulama notu (2026-07-13, Grok wire-up):** Eski client write kaldırıldı. Oturum biterken otomatik tetik profil/başarılar ekranı + oturum listesi değişimi ile (study_providers'a yazılmadı).
- **Dal:** — (main) · **Model:** Grok

### WP-57: Başarım 3.0 R2 (Oyunlaştırılmış Profil ve Rozet UI) 🏅
- **Program/Faz:** Başarım 3.0
- **Ajan:** Grok
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · vitrin/taç/confetti + polish
- **Problem:** Kullanıcının kilitli (????) veya açılmış başarımlarını görebileceği, taç/XP çubuğu bulunan sosyal profil vitrini.
- **Kapsam dışı:** Backend ledger motoru (WP-56).
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/profile/widgets/achievement_showcase.dart`
  - `app/lib/features/profile/social_profile_screen.dart`
  - glue: `social_profile_dialog.dart`, `achievements_screen.dart`, `gamification_card.dart`
- **DOKUNMA (oku):** `achievement_provider` / gamification stream (WP-56)
- **Adımlar:**
  - [x] XP seviye barı + taç etiketleri (`crownLabelTr` / `xpBarMetrics`)
  - [x] Gizli rozet: kilitliyken `?????` + siyah siluet; açıkken gerçek ad
  - [x] Confetti (CustomPainter, pubspec yok) — yeni ödülde post-frame ≤ 250 ms arm
  - [x] SocialProfileScreen (tam) + Dialog (kompakt) + AchievementsScreen yönlendirme
  - [x] Vitrin 3 rozet pin (kendi profil); başkasında salt-okunur
  - [x] Widget test 4 PASS
- **Veri/Migration etkisi:** Yok.
- **RLS/Güvenlik:** Başka kullanıcı okuma mevcut `can_see_user_sessions` stream’lerine bağlı; e-posta gösterilmez.
- **Kabul:** Gizli kilit UI + confetti arm — `Kodda doğrulandı`. Cihazda gizli başarım açılışı görsel QA — `Cihazda doğrulanmalı`.
- **Dal:** — (main) · **Model:** Grok


### WP-58: Saat Merkezi R1 (Zaman Motoru ve Exact Alarm Altyapısı) ⚙️
- **Program/Faz:** Saat (KALITE-PROGRAMI §8.4) · **Ajan:** Grok
- **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor
- **Problem:** Epoch motor + `SCHEDULE_EXACT_ALARM` + reboot/timezone dayanıklılığı.
- **SAHİP:** `app/lib/core/time_engine/**`, `ExactAlarmHelper.kt`, `AlarmReceiver.kt`, `AndroidManifest` izinleri, `alarm_notification_service.dart`, modeller
- **Adımlar:**
  - [x] Epoch clock / stopwatch / countdown saf motor
  - [x] AlarmScheduler (tekrar, skip-next, crescendo eğrisi)
  - [x] Exact alarm izin kanalı + exact/inexact schedule mode
  - [x] BOOT/TIMEZONE AlarmReceiver iskeleti
  - [x] AlarmRule + TimerInstance epoch alanları (skip/antiSnooze/crescendo/endsAt)
- **Kabul:** Unit test motor 14 PASS — `Kodda doğrulandı`. Reboot/exact izin cihaz — `Cihazda doğrulanmalı`.

### WP-59: Saat Merkezi R2 (Alarm 2.0 ve Çoklu Timer UI) ⏰
- **Program/Faz:** Saat · **Ajan:** Grok
- **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor
- **Adımlar:**
  - [x] Alarm editör: gün chip, hafta içi/her gün, anti-snooze, crescendo, erteleme
  - [x] Skip next + sıradaki alarm özeti
  - [x] AlarmRingingScreen (crescendo haptic + matematik anti-snooze)
  - [x] Exact alarm izin banner (denied)
  - [x] Multi-timer: preset şeridi, +1/+5 dk, renk, epoch ticker, bildirim planı
- **Kabul:** Widget test empty/list/editor PASS — `Kodda doğrulandı`. 3 paralel timer + alarm ses cihaz — `Cihazda doğrulanmalı`.

### WP-60: Saat Merkezi R3 (Dünya Saati, Kronometre ve StandBy Modu) 🌍
- **Program/Faz:** Saat · **Ajan:** Grok
- **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor
- **Adımlar:**
  - [x] WorldClockScreen gündüz/gece gradient + offset etiketi + şehir kataloğu
  - [x] StopwatchScreen lap analizi (en hızlı yeşil / en yavaş kırmızı) + kopyala
  - [x] StandBy: gece kırmızı ton + BurnInOffset (dakikada kayma) + sıradaki alarm
  - [x] ClockScreen hub IA: Saat · Dünya · Alarm · Timer · Kronometre · Odak (StudyTimerCard yalnız Odak)
- **Kabul:** Burn-in unit ≥10px / 60 periyot; clock hub widget PASS — `Kodda doğrulandı`. Landscape StandBy cihaz — `Cihazda doğrulanmalı`.

### WP-28: Windows MSIX, Güncelleme ve Release QA 📦
- **Program/Faz:** Windows dağıtım/release (`KALITE-PROGRAMI §8.7`) · **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-53 gerçek Windows cihaz/ürün kabulü
- **Problem:** Windows release artefaktı, doğru ürün metadata'sı, güvenilir kurulum/güncelleme, kod imzası ve Windows CI kapısı yok; mevcut Android updater Windows'ta çalışmıyor.
- **Kapsam dışı:** Desktop IA/shell (WP-27), Microsoft Store hesabı açma/satın alma, uygulama özelliği, Android release workflow davranışını değiştirme.
- **SAHİP dosyalar (yaz):** `app/windows/**` (runner metadata/ikon/manifest/DAGITIM), `app/pubspec.yaml` (yalnız Windows paket config/dev dependency), yeni `.github/workflows/windows-release.yml`, `docs/QA-WINDOWS.md`, `docs/WINDOWS-RELEASE-GATE.md`, Windows updater/channel adaptörü ve testleri.
- **DOKUNMA:** `app/android/**`, `supabase/migrations/**`, timer/widget ürün mantığı, `.github/workflows/release.yml` Android akışı (yalnız oku), `core/theme/**`.
- **Adımlar:**
  - [ ] `Odak Kampı` ProductName/FileDescription/publisher/package identity ve çok boyutlu ikon; Explorer/Start/Ayarlar metadata testi.
  - [ ] Geliştirme ZIP + beta imzalı MSIX + stable Store MSIX (önerilen) kanal sözleşmesi; Store dışıysa App Installer feed.
  - [ ] Sertifika/Store/Azure kimliğini secret store'a al; self-signed yalnız QA; PFX/service secret log/artefakta girmez.
  - [ ] Windows runner CI: analyze + test + release build + MSIX + SHA-256 + Sentry release/symbol eşlemesi.
  - [ ] Temiz VM install→launch→update→uninstall ve Windows App Certification/paket doğrulama otomasyonu.
  - [ ] Windows 11 24H2/25H2, DPI, multi-monitor, sleep/resume, offline→online, Android+Windows aynı hesap ve forward-fix rollback matrisi.
- **Veri/Migration etkisi:** Yok. Paket identity bir kez yayınlandıktan sonra kalıcıdır; geri alma = daha yüksek build numaralı, aynı identity/imzalı bilinen-iyi forward-fix paketi.
- **RLS/Güvenlik:** RLS aynı kalır. Signing private key, Store/Azure kimliği, Supabase ve Sentry release değerleri yalnız CI secrets; log redaction zorunlu.
- **Edge-case'ler:** İmza/publisher uyuşmazlığı, düşük version update, SmartScreen, VC++ runtime/plugin DLL eksikliği, install path salt-okunur MSIX container, Store ve GitHub kanallarının birbirini güncelleyememesi, offline installer.
- **Kabul (ölçülebilir):** Temiz Windows 11 VM'de standart kullanıcıyla kurulum/ilk açılış/update/uninstall PASS; aynı identity+imzayla veri kayıpsız update; WACK/paket doğrulama PASS; artefakt SHA-256 ve Sentry release eşleşir; P0=0; 24H2+25H2 cihaz/VM videosu; rollback/forward-fix provası PASS. `Cihazda doğrulanmalı`.
- **Tuzaklar:** Unsigned EXE/ZIP'i stable sayma; Store ve doğrudan MSIX identity'lerini plansız karıştırma; private key'i repoya koyma; Android updater'ı Windows'a kopyalama.
- **Dal önerisi:** `wp28-windows-msix-release` · **Model önerisi:** 🟣 Pro

---

## Tamamlanan İş Paketleri

> Biten her WP yalnız bu başlık altında tutulur. Buradaki kartlar tekrar aktif veya planlanan iş olarak yazılmaz.

| WP | Tamamlanan kapsam |
|---|---|
| WP-40 | V8-A · Native timer state store + foreground service — beta-v8 cihaz QA + ürün kabulü |
| WP-41 | V8-A · Canlı chronometer bildirim R1/R2 (beta-v11–v15 hattı) — ürün kabulü 2026-07-13 |
| WP-42+51 | V8-A · Native sayaç servisi + widget/bildirim app-kapalı + Grok in-app start fix — ürün kabulü 2026-07-13 |
| WP-54 | Tema Stüdyosu R1 · Token motoru + 12 hazır tema — ürün kabulü 2026-07-13 |
| WP-55 | Tema Stüdyosu R2 · Katmanlı editör UI — ürün kabulü 2026-07-13 |
| WP-56 | Başarım 3.0 R1 · Server-authoritative ledger + wire-up + XP eşik/saat — ürün kabulü 2026-07-13 |
| WP-57 | Başarım 3.0 R2 · Oyunlaştırılmış profil/rozet UI + polish — ürün kabulü 2026-07-13 |
| WP-43 | V8-B · Genel senkronizasyon denetimi (canonical projection, idempotency) — beta-v8 cihaz QA + ürün kabulü |
| WP-44 | V8-C · İstatistik grup sırası (sıralama üste) — beta-v8 cihaz QA + ürün kabulü |
| WP-37 | Faz 0A · Repo ve doküman gerçeği denetimi |
| WP-1 | Android Widget Foundation |
| WP-2 | Persistent Notification + Background Timer |
| WP-3 | Auth Recovery (ilk temel akış) |
| WP-4 | Home Responsive QA |
| WP-5 | Presence Lifecycle |
| WP-6 | Android Surface Extensions |
| WP-7 | Class Chat |
| WP-8 | Nudge + Notifications |
| WP-9 | Gamification |
| WP-10 | Class Metrics Pack |
| WP-11 | Windows Desktop Track |
| WP-12 | Sync & Offline Track |
| WP-13 | Release Channels |
| WP-14 | Güvenli Admin ve Geri Bildirim Temeli |
| WP-15 | Device Integrations Spike ve zengin kısayollar |
| WP-16 | Dashboard Advanced Polish |
| WP-17 | Android Canlı Sayaç Yüzeyleri |
| WP-18 | Grup Ekranı Hiyerarşisi ve Ayar Sadeleştirmesi |
| WP-19 | Device Integrations Settings Hook |
| WP-20 | Özelleştirilebilir Saat Stilleri |
| WP-21 | Gelişmiş Grid Boyutlandırma |
| WP-22 | Canlı Grup Hedefi Animasyonu |
| WP-23 | Clock Center + Landscape StandBy |
| WP-24 | Alarm + Çoklu Timer Temeli |
| WP-25 | Android 3 Tuşlu Navigasyon Safe Area QA |
| WP-26 | Tema Paleti ve Özel Slotlar |
| WP-29 | Stable/Beta App Icon & Branding Refresh |
| WP-30 | Release Notes, Updater Dialog ve Settings Hook |
| WP-31 | Hesabımı Yönet Merkezi ve çalışan şifre sıfırlama |
| WP-32 | Geri bildirim ekran görüntüsü eki |
| WP-33 | Güvenli süper-admin kullanıcı işlemleri |
| WP-34 | Süper-Admin Paneli, Grup Moderasyonu ve Duyurular |
| WP-35 | Sosyal Profil 2.0 + Başarı Yolculuğu |
| WP-36 | Beş Sekmeli IA Sadeleştirmesi + Bildirim Merkezi |
| WP-38 | Faz 0A · Canlı Backend Durum Matrisi |

### Son Teslim Notları

- **WP-41/42/51 + Grok timer hotfix (2026-07-13):** Native `StudyTimerService`, app-kapalı Başlat/Durdur, chronometer bildirim, beta-v13–v15 rötuşları; in-app start idle race fix (`94945ac`). Ürün sahibi kapatma kararı.
- **WP-54–57 (2026-07-13):** Tema Stüdyosu + Başarım 3.0 ledger/UI; taç 0/2.5k/10k/25k/75k; saat +10 XP; profil/tap/taç polish. SQL 0025–0027 canlı uygulama kullanıcının; 0028 genel yayın sıfırlaması.

- **WP-58/59/60 Saat Merkezi (2026-07-13, Grok):** Epoch time engine; exact alarm Android; Alarm 2.0 (skip/anti-snooze/crescendo); multi-timer studio; dünya saati; lap kronometre; StandBy burn-in. Hub 6 sekme. Analyze (clock paths) 0; 20 ilgili test PASS. Ürün kabulü cihaz QA sonrası.

- **WP-37:** `docs/DENETIM-FAZ0A.md` ile WP-1–36'nın kanıtlanabilir aşamaları, özellik envanteri, P0/P1/P2 listesi, risk/v8 blocker kaydı ve belge tutarsızlığı önerileri teslim edildi. `app/` diff'i boş; canlı backend teyidi WP-38'de kalır.

- **WP-38:** Canlı Supabase durumunu denetlemek için yerel migration listesi, Edge Function envanteri ve doğrulama SQL sorguları `docs/BACKEND-DURUM.md` olarak eklendi. Blocker RLS (B7) kullanıcı kararına bırakıldı.

- **WP-36:** Ayarlar'daki "Ana Sayfa" grubu kaldırıldı (sayaç anahtarı "Gruplar" grubuna taşındı); dürtme, hatırlatıcı, alarm/timer, duyuru, güncelleme ve sessiz saatleri tek yerden yöneten `NotificationCenterScreen` eklendi. `0023_notification_center.sql` (study_reminders + announcement_reads, RLS owner-only), çift `NotificationRepository`, yerel hatırlatıcı planlama servisi ve sessiz-saat mantığı; dürtme dinleyicisi ve güncelleme bildirimi tercihlere saygı gösterir. Gruplar/İstatistik sekmeleri zaten dolu doğrulandı.

- **WP-26:** Hazır paletler, kalıcı tema ayarları ve üç özel renk slotu eklendi (`bd5a906`).
- **WP-24:** Yerel alarm, preset, etiketli çoklu timer, pause/resume/reset/delete ve alarm bildirim kanalı eklendi (`c47042d`).
- **WP-23:** Clock Center, yatay StandBy görünümü ve ana shell'den Saat erişimi eklendi (`8618d86`).
- **WP-31:** Bağlı e-posta, e-posta değiştirme, güvenli çıkış ve recovery akışı ile `AccountSettingsScreen`/`RecoveryScreen` oluşturuldu.
- **WP-32:** `0019_feedback_attachments.sql`, görsel seçimi ve admin önizlemesi eklendi.
- **WP-33:** Süper-admin Edge function ve RLS logları oluşturuldu, arayüz testleri düzenlendi.
- **WP-34:** Süper-Admin çoklu sekme (Dashboard, Users, Groups, Reports, Announcements, Audit Log), duyurular ve grup moderasyonu eklendi.
- **WP-35:** Sosyal Profil vitrini (SocialProfileDialog), Başarı Yolculuğu, 60+ kademeli başarı kural motoru, güvenli Supabase upsert/senkronizasyon ve `0022` migration düzeltmesi eklendi.
