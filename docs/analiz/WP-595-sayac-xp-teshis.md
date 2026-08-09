# WP-595 — Gece boyu açık kalan sayaç + geri alınamayan XP: teşhis

**Tarih:** 2026-08-09 · **Olay:** 2026-08-08 gecesi · **Kullanıcı:** gerçek kullanıcı (proje sahibinin kardeşi)
**Kanıt:** `odak-kampi-timer-journal.json` (240 kayıt, tek cihaz `1870cdfd99ef`, tek hesap `e126488480ac`)
**Sürüm:** olay anında en son etiket **v62** (`c66c230`, 2026-08-08 22:12 +03) — olaydan **28 dakika önce**.

---

## 0. Tek cümleyle

Kullanıcı sayacı **durdurmadı, yeniden başlattı**; uygulama 11 sa 22 dk boyunca hiçbir yerde
"bu makul değil" demedi; sabah Durdur'a basınca oturum yazıldı ve **XP geri alınamaz biçimde
bankalandı** — çünkü XP türetilmiş değil, **append-only defterde biriken** bir bakiyedir.

---

## 1. Gece tam olarak ne oldu (günlük, UTC → İstanbul = UTC+3)

Günlükteki **kullanıcı eylemi** satırlarının tamamı (ısı vuruşları hariç):

| İstanbul | UTC | Olay | Sonuç | Koşu |
|---|---|---|---|---|
| 22:39:04 | 19:39:04 | `stop_requested` (elapsed 215 sn) | applied | — |
| 22:39:04 | 19:39:04 | `session_recorded` | applied | 3 dk 35 sn yazıldı |
| **22:39:10** | 19:39:10 | **`start_requested`** | applied | `c945075022fc` — durdurmadan **6 sn sonra** |
| 22:39:21 | 19:39:21 | `stop_requested` (elapsed 11 sn) | applied | — |
| **22:39:23** | 19:39:23 | **`start_requested`** | applied | `f883b10d853c` — `run_terminal`'dan **1 sn sonra** |
| 22:40:24 | 19:40:24 | `stop_requested` (elapsed 61 sn) | applied | — |
| **22:40:28** | 19:40:28 | **`start_requested`** | applied | **`6191a3982963`** — `run_terminal`'dan **3 sn sonra** |
| 22:40:39 | 19:40:39 | `cold_start_restore` (elapsed 10) | applied | koşu geri yüklendi |
| 22:41:12 | 19:41:12 | `cold_start_restore` (elapsed 44) | applied | koşu geri yüklendi |
| — | — | *11 sa 22 dk boyunca yalnız `lease_heartbeat` + `snapshot_reconciled`* | — | — |
| 10:02:47 | 07:02:47 | `stop_requested` **elapsed_seconds = 40938** | applied | **11 sa 22 dk 18 sn** |
| 10:02:47 | 07:02:47 | `session_recorded` + `run_terminal` | applied | oturum yazıldı |
| 10:06:45 | 07:06:45 | `start_requested` | applied | yeni koşu |

**Gecenin son kullanıcı eylemi bir DURDURMA değil, bir BAŞLATMADIR.**

Gece boyunca `lease_heartbeat` **9 kez `failed`**, aralarda 862 sn – 8209 sn (2 sa 17 dk) boşluklar
var. Yani süreç uyudu/öldü, koşu yaşamaya devam etti; süre ısı vuruşundan değil
`startedAt → stopAt` duvar saati farkından hesaplanıyor.

---

## 2. Hipotezler: hangisi doğru

### ✅ H1 — Aynı yerdeki toggle tuzağı: **DOĞRU, kök neden bu**

Kanıt (kod):

* `app/lib/features/classroom/widgets/study_timer_card.dart:431-473` — **tek** `SizedBox(width: double.infinity)`
  içinde `timer.isRunning ? FilledButton.icon(Durdur) : FilledButton.icon(Başlat)`.
  Aynı konum, aynı genişlik, aynı dokunma hedefi. Durdurma bitince buton yerinde
  **"Çalışmaya Başla"ya döner**.
* `app/lib/features/classroom/widgets/focus_timer_screen.dart:172-188` — tam ekran odakta daha da
  keskin: `SizedBox(96×96)` dairesel buton, `onPressed: timer.isRunning ? notifier.stop : notifier.start`.
  Ne onay, ne `isStopping` kilidi, ne bekleme.
* `app/lib/data/providers/study_providers.dart:1936-1937` — `void start() { if (state.isRunning) return; ... }`.
  Tek koruma budur. **Az önce durdurulmuş olmak bir engel değildir**; soğuma süresi, "az önce
  durdurdun, emin misin?" sorusu, çift dokunma filtresi YOK.
* Karşılaştırma: `stop()` için koruma VAR (`study_providers.dart:2109` `if (_stopInFlight) return;`,
  WP-246). Yani ikinci Durdur'a karşı korunuyoruz, **ikinci Başlat'a karşı korunmuyoruz.**

Kanıt (günlük): **arka arkaya üç kez** dur → 6 sn / **1 sn** / 3 sn sonra başlat.
Bir insanın üst üste üç kez, bir kez de 1 saniye içinde, "yeni oturum açmaya" karar vermesi
gerçekçi değil. Bu, durdurma zinciri bitip butonun yeşile döndüğü anda sabırsız parmağın
tekrar inmesidir. Üçüncüsünde kullanıcı sonucu görmeden ekranı bıraktı.

**Neden "kapattım" sandı:** son dokunuşunun ne yaptığını gösteren hiçbir şey yok. Buton
metni değişiyor ama kullanıcı zaten ekrandan ayrılıyor; onay yok, geri bildirim (snackbar/haptik)
yok. `_onTimerEvent` yalnız pomodoro/geri sayım faz geçişlerinde ses/titreşim veriyor
(`study_timer_card.dart:76-92`) — kronometre başlatmada hiçbir şey yok.

### ✅ H2 — Uygulamayı kapatmak sayacı durdurmuyor: **DOĞRU ve kullanıcıya HİÇ söylenmiyor**

* İki `cold_start_restore … applied` (22:40:39 ve 22:41:12) = süreç iki kez baştan doğdu ve
  koşuyu geri yükledi (`study_providers.dart:869-925`). Kullanıcı bu dakikalarda uygulamayı
  kapatıp açmış.
* Foreground service tasarım gereği devam eder — bu bir hata değil. **Hata, bunun hiçbir yerde
  yazmaması.** Katalog taraması: `app_tr.arb` içinde "arka planda çalışmaya devam eder /
  uygulamayı kapatsan da durmaz" anlamına gelen **sıfır** dize var.
* Sahip bunu daha önce de yaşamış: `study_providers.dart:908-910` yorumunda aynen
  *"Sahibin 'sabah kalktım sekiz saat görünüyordu' vakasında zaman çizelgesinin ilk satırı budur"*
  yazıyor (WP-430). Yani **teşhis aracı yazıldı, korkuluk yazılmadı.**

### ⚠️ H3 — Bildirim yoktu: **KANITLANAMAZ (günlükte izi yok), ama uyarı da yoktu**

Günlük şeması izin durumu taşımıyor (`event/reason/outcome/origin/run/…` — bkz.
`lib/core/observability/timer_diagnostic_journal.dart`). Bu yüzden "bildirim göründü mü"
sorusu **bu kanıtla cevaplanamaz**. Kesin olan:

* Bildirim izni kapalıyken sayaç görünmez çalışıyordu ve kullanıcıya söylenmiyordu — bu
  WP-592'de bulundu ve **düzeltmesi `25ca299`, 2026-08-09 10:34 +03**, yani **olaydan sonra**
  ve v62'de **yok**. Olay gecesi böyle bir uyarı ekranda olamazdı.
* Kalıcı bildirim gece boyunca tek işaretti. Görünmediyse kullanıcının hiçbir şansı yoktu;
  göründüyse bile uyuyan kişi görmez.

### ✅ H4 — Makul olmayan süreye karşı korkuluk YOK: **DOĞRU, ve tek başına ürün kanaması**

`lib/core/time_engine/**`, `lib/data/providers/study_providers.dart`, `lib/core/stats/**` ve
native `StudyTimerService.kt` tarandı:

* Maksimum oturum süresi **yok**.
* Hareketsizlik/"hâlâ orada mısın?" **yok**.
* Otomatik durdurma **yok**. Kronometrede zamanlayıcı bile kurulmuyor:
  `study_providers.dart:2276-2278` — *"Kronometrede otomatik geçiş yok; timer yalnız geri
  sayım/pomodoro için."*
* `kMaxTimerMinutes = 180` (`study_providers.dart:204`) yalnız geri sayım/pomodoro **ayar**
  sınırıdır; kronometreyi sınırlamaz.
* Native servis tarafında da süre üst sınırı yok (`StudyTimerService.kt`).

Ürün ekonomisi bunu **ödüllendiriyor**: `steel_will` en üst kademesi tek oturumda 480 dk,
`day_hero` en üst kademesi tek günde 12 saat. Yani 11 saatlik uyku, sistemin gözünde
zirveye yakın bir performanstır.

---

## 3. Soru 2 — Çalışma kaydı silinince XP/başarım geri alınabilir mi?

### 3.1 XP türetilmiş mi, biriktirilmiş mi? → **BİRİKTİRİLMİŞ**

`supabase/migrations/0024_achievements_ledger.sql`:

* `xp_ledger` **append-only**, `unique(event_key)`, satır 80: `revoke insert, update, delete
  on public.xp_ledger from authenticated, anon;`
* `_apply_xp_ledger_row()` (satır ~180) profili **artırır**:
  `set xp = public.gamification_profiles.xp + excluded.xp` — hiçbir yerde oturumlardan
  yeniden hesaplanmaz.
* `_guard_gamification_xp_write()` istemcinin `xp`/`crown_rank` yazmasını **geri alır**
  (`new.xp := old.xp`).

Yani XP, oturum listesinin bir **fonksiyonu değil**, oturum olaylarının bir **kalıntısıdır**.
Oturumu silmek kalıntıya dokunmaz.

### 3.2 `achievement_ledger` ne? → **Tek yönlü "kazanıldı" damgası**

* İstemci ikizi `app/lib/core/stats/achievement_ledger_engine.dart:576-631`:
  `if (_eventKeys.contains(key)) continue; _eventKeys.add(key); _ledgerXp[key] = tier.xp;`
  — kayıt eklenir, **hiçbir kod yolu silmez**. Sınıfta geri alma/iptal metodu yok.
* `user_achievements` projeksiyonu `tier = greatest(mevcut, yeni)` ile **monoton**: kademe
  yalnız yükselir.
* `event_key` formatı `uid|achievement|tier_N` ve saat XP'si `uid|study_hour_xp|h_N`
  (`achievement_ledger_engine.dart:367-372`). Saat XP'si **saat indeksine** bağlıdır: sahte
  11 saat `h_N` anahtarlarını **harcar**. Kayıt silinse bile o anahtarlar defterde durur —
  yani kardeş ileride o saatleri **gerçekten** çalışırsa onlar için **bir daha XP alamaz**.
  Çift zarar.

### 3.3 Oturum silme yolu XP'yi haberdar ediyor mu? → **HAYIR, hiç**

* `app/lib/features/profile/session_history_screen.dart:344-366` — `_delete` yalnız
  `studyRepositoryProvider.deleteSession(session.id)` çağırır. Gamification'a tek satır yok.
* `supabase/migrations/**` içinde `study_sessions` üzerindeki tetikleyiciler:
  `study_sessions_project_break_enemy` (0063), `study_sessions_project_group_metrics` (0063),
  `study_sessions_stamp_day` (0073), `a_study_sessions_capture_group_attribution` (0080),
  `study_sessions_project_goal_completion` (0120). **Hiçbiri XP'ye dokunmaz.**
* Zincir şurada kesiliyor: `deleteSession` → satır siliniyor → `userSessionsProvider` yeniden
  yayınlıyor → `AchievementProgressLifecycle` (`gamification_providers.dart:123-156`)
  `session_completed` olayı fırlatıyor → RPC metrikleri **düşmüş** görüyor →
  ama RPC yalnız **yeni eşik geçişi** arar, geriye dönük iptal yolu **yoktur**.

### 3.4 Geri alınabilir mi? → **İkiye ayrılır**

| Ne | Durum | Geri alınabilir mi |
|---|---|---|
| **Saat XP'si** (`study_hour_xp`, 50 XP/saat, ~11 saat = ~550 XP) | Kullanıcı hiçbir şey yapmadan **doğrudan bankalandı** (0057: *"Saat XP pasif ödüldür; inbox'a taşınmaz, doğrudan bankalanır"*) | ❌ **Hayır.** Yalnız `service_role` ile elle SQL. İstemcinin hiçbir yolu yok. |
| **Başarım kademe ödülleri** (0057'den beri) | XP **bankalanmaz**; `achievement_rewards` tablosuna `pending` satır yazılır, XP yalnız kullanıcı **"Topla"ya basınca** verilir (`0047` `_claim_achievement_reward`) | ⚠️ **Henüz TOPLAMADIYSA evet** — `pending` satırlar silinebilir. **Topladıysa hayır.** |

🔴 **Zaman kritik bulgu:** `_claim_achievement_reward` (`0047:139-212`) topla anında metriği
**yeniden doğrulamaz** — depolanmış `xp_amount`'u olduğu gibi bankalar. Yani sahte oturum
silinmiş olsa bile, gelen kutusundaki ödül hâlâ toplanabilir ve toplandığı anda kalıcılaşır.
`achievement_rewards` istemciye `select`-only (`0047:51`), yani iptali **yalnız sunucu** yapar.

11 sa 22 dk'lık tek oturumun mevcut sözlükte (0065) tetiklediği kademeler:
`steel_will` 1-6 (682 dk ≥ 480) = 28.000 XP, `day_hero` 1-5 (11 sa; 6. kademe 12 sa) = 11.700 XP.
Toplam ≈ **39.700 XP pending + ~550 XP bankalanmış**. `levelForXp` (`level_curve.dart:7`)
`floor(sqrt(xp/50))+1` olduğundan bu tek gece **onlarca seviye** demektir.

### 3.5 Ne gerekir

* **İstemci tarafında geri alma imkânsızdır** — RLS ve `_guard_gamification_xp_write` bunu
  bilerek engelliyor (doğru tasarım; istemcinin XP'yi düzeltebilmesi hile kapısı olurdu).
* Geri alma **yalnız sunucuda**, `service_role` ile mümkündür ve iki ayrı iş gerektirir:
  1. `achievement_rewards` içindeki ilgili `pending` satırları silmek (geri alınabilir kısım),
  2. `xp_ledger`'daki `study_hour_xp` satırlarını silip `gamification_profiles.xp`'yi yeniden
     toplamak (append-only sözleşmeyi **kasten** delmek demektir; bu bir ürün/mimari kararıdır).
* Kalıcı çözüm bir **düzeltme (compensating) migration'ı** ister: negatif tutarlı ledger satırı
  ya da `session_deleted` olayında ilgili `event_key`'leri iptal eden bir yol. Bu WP sunucuya
  **yazmadı** (talimat gereği; migration head beş yerde pinli).

---

## 4. Bu WP'de düzeltilen

**H4'ün istemci tarafındaki payı: makul olmayan süre korkuluğu.**

* `app/lib/core/time_engine/implausible_run_guard.dart` (**yeni**) — saf, **zaman enjekteli**
  kural. `kImplausibleRunThreshold = 6 saat`. `DateTime.now()` çağırmaz.
* `app/lib/features/classroom/widgets/timer_mode_controls.dart` — `TimerVerificationNotice`
  WP-430'dan beri **ölü bir `SizedBox.shrink()`** idi; oysa sayaç çalışırken **hem kartta
  hem tam ekran odakta** çiziliyordu. Yani iki yüzeyde de hazır ve boş bir yuva vardı.
  Artık koşu 6 saati geçtiğinde uyarı çizer ve **sonucu açıkça söyler**: "Durdur'a bastığında
  bu süre çalışma olarak kaydedilir; verilen XP ve başarımlar geri alınamaz."
  Renk `warningColorsOn` ile **zeminden** türetilir (WP-358; `colorScheme.error` kırmızı
  temada görünmez olurdu — tam da bu olayın hatasını tekrarlardı).
* `app/lib/l10n/app_tr.arb` + `app_en.arb` — `classroomSayacCokUzunSuredirAcik({duration})`.

Testler (kırmızı-yeşil kanıtlı):

* `app/test/core/implausible_run_guard_wp595_test.dart` — 8 iddia, tamamı enjekte zamanlı.
* `app/test/features/classroom/timer_implausible_run_wp595_test.dart` — 5 iddia, **iki yönlü**:
  6 sa ve 11 sa 22 dk'da uyarı **çıkar**; 45 dk, 5 sa 59 dk ve "sayaç duruyor" hâllerinde
  **çıkmaz**.
* **Kırmızı kanıtı:** gövde geçici olarak eski `SizedBox.shrink()` davranışına döndürüldü →
  "çıkar" iddiaları düştü (`Found 0 widgets with key [<'timer-implausible-run'>]`),
  "çıkmaz" iddiaları yeşil kaldı → düzeltme geri kondu → 13/13 yeşil.

---

## 5. Düzeltilmeyenler ve nedeni

| Eksik | Neden yapılmadı |
|---|---|
| **H1 — yanlışlıkla yeniden başlatma engeli** (durdurmadan sonra soğuma / onay / çift dokunma filtresi) | Düğmeler `study_timer_card.dart` ve `focus_timer_screen.dart`'ta, `start()` ise `study_providers.dart`'ta. **Üçü de bu ajanın SAHİP yolları değildi.** Kök neden budur ve **bir sonraki WP'nin birinci maddesi olmalıdır.** |
| **H2 — "uygulamayı kapatmak sayacı durdurmaz" bilgisi** | Doğru yer başlatma anındaki geri bildirim + kalıcı bildirim metni (`timer_notification_service.dart`) — sahip yolu değil. Katalogda böyle bir dize hiç yok. |
| **Otomatik durdurma / süre tavanı** | Ürün kararı. Kayıt kesmek (`_recordSession`) veya süreyi kırpmak `study_providers.dart` gerektirir; ayrıca "gerçekten 9 saat çalıştım" diyen kullanıcının verisini sessizce silmek yeni bir sessiz veri kaybı olurdu. Sahip karar vermeli: tavan mı, onay mı, kırpma mı. |
| **Kardeşin sahte XP'sinin silinmesi** | Talimatla yasak (sahip kararı) + zaten yalnız sunucudan yapılabilir. |
| **`session_deleted` → XP iptali (sunucu)** | Migration yazımı bu WP'de yasak. Gerekli iş §3.5'te yazılı. |
| **Bildirim izni durumunun günlüğe eklenmesi** | H3'ü kanıtlanabilir kılacak tek şey bu; `timer_diagnostic_journal.dart` sahip yolu değil. **Öneri:** günlük şemasına `notifications_enabled` alanı eklensin, yoksa bu soru bir dahaki olayda da cevapsız kalır. |

---

## 6. Sahibe not — sırayla yapılması gerekenler

1. **Şimdi:** kardeşin `achievement_rewards` tablosundaki `pending` satırlarına bakılsın.
   Henüz "Topla"ya basmadıysa ~39.700 XP hâlâ **iptal edilebilir**; bastığı an kalıcılaşır.
2. **Sonraki WP:** H1 düzeltmesi — durdurduktan sonra Başlat butonu birkaç saniye pasif
   kalsın ya da "yeni oturum başlat" ayrı bir dokunuş istesin.
3. **Sonra:** `session_deleted` olayında XP iptali (sunucu migration'ı) — yoksa her yanlış
   kayıt kalıcı sahte seviye üretmeye devam eder.
