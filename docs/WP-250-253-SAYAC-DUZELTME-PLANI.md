# WP-250 → WP-253 — Sayaç Düzeltme Uygulama Planı

**Tarih:** 2026-07-21 · **Yazan:** Claude (Opus 4.8) — kod denetimiyle doğrulanmış
**Kaynak analiz:** `docs/TIMER_ARCHITECTURE_REPORT.md` (V2) + iki turluk bağımsız denetim
**Hedef okuyucu:** Bu işi **uygulayacak ajan**. Bu belge bir tartışma metni değil, **uygulama talimatıdır**.

---

---

## ⚑ DURUM (2026-07-21 — belge canlı, uygulandıkça güncellenir)

| WP | Durum | Kanıt |
|---|---|---|
| **WP-250** | ✅ **Kod tamam** — cihaz QA bekliyor | commit `1f2bd09` (notifier) + `62bacac` (UI + reconcile serileştirme). analyze 0 issue · 657 test yeşil · kırmızı-yeşil ispatı yapıldı |
| **WP-251** | ✅ **Kod tamam** — cihaz QA bekliyor | commit `cf57caf`. Kotlin derlemesi yerelde doğrulanamadı (gradle env kapısı) → beta build hattında bakılacak |
| **WP-252** | ⛔ **Onay bekliyor** — başlanmadı | ürün kararı gerekiyor |
| **WP-253** | ⛔ **Karar bekliyor** — başlanmadı | ikon kararı ürün sahibinde |

**WP-250 uygulanırken plandan sapılan tek nokta (bilerek korundu):** `stop()`, kayıttan önce native durumla uzlaşır (`await _reconcileBackgroundTimer()`), ve aralığı yalnız `state.startedAt == startedAt` ise yazar. Bu, planın A10.2'deki "app-kapalı Durdur sonrası uyanma" testi için **zorunluydu** — plan metni bu adımı atlamıştı (A7.1 tek başına yetmiyor; kanıt: satır çıkarılınca test 1800 yerine 3300 veriyor). Uygulayıcı ajan bunu ilk turda serileştirilmemiş `_reconcileBackgroundTimerImpl()` ile yapmıştı; WP-241/243 yarışını geri açtığı için sarmalayıcıya çevrildi.

---

## 0. BU BELGE NASIL KULLANILIR — ÖNCE BUNU OKU

Bu plan, hiçbir mimari karar vermek zorunda kalmayacak şekilde yazıldı. Kararlar **zaten verildi**. Senin işin:

1. **Sırayla uygula.** WP-250 → WP-251 → WP-253. WP-252 kullanıcı onayı olmadan **BAŞLATILMAZ**.
2. **Kod bloklarını olduğu gibi kullan.** Her adımda `ESKİ KOD` (dosyada birebir aranacak metin) ve `YENİ KOD` (yerine yazılacak metin) var. Kendi yorumunu katma, isim değiştirme, "daha iyisini" yapma.
3. **Adım atlamak yasak.** Bir adım "şunu doğrula" diyorsa doğrula ve çıktıyı yanıtına yaz.
4. **Bir şey tutmazsa DUR.** `ESKİ KOD` bloğunu dosyada bulamıyorsan, dosya bu plandan sonra değişmiş demektir → **tahmin etme**, kullanıcıya sor.
5. **Kapsam dışına çıkma.** Her WP'nin "DOKUNMA" listesi var. O listedeki dosyalara tek karakter yazma.

### 0.1 ÇAPA UYARILARI — bu üç metin dosyada BİRDEN FAZLA kez geçer

Aşağıdakileri ararken **yanlış yeri değiştirme riski var.** Doğru yeri ayırt etme kuralı:

| Aranan | Kaç kez geçer | Hangisini değiştireceksin |
|---|---|---|
| `if (t.finished) {` | 2 (~1145 ve ~1157) | **~1157**: gövdesinde `_finish(lastEvent: t.event);` olan. ~1145'teki `liveRunToken` bloğunun içindedir — **DOKUNMA**. |
| `clearLiveRun: true,` | 2 (~926 ve ~1225) | A5 için **~926** (`start()` içinde, üstünde `accumulatedSeconds: 0,` ve `lastUpdatedAt: now,` var). A4 için **~1225** (`_finish()` içinde, üstünde `lastEvent: lastEvent,` var). |
| `await prefs.reload();` | 3+ | A7.1 için yalnız `_reconcileBackgroundTimerImpl` fonksiyonunun **ilk satırlarındaki**, hemen altında `// 1. App-kapalı Durdur'ların…` yorumu olan. |

Her adımda verdiğim `ESKİ KOD` bloğu bu ayrımı yapabilmen için **çevresindeki satırları da içeriyor** — bloğun tamamını ara, tek satırı değil.

### Bu düzeltmelerin çözdüğü gerçek problem (bir paragraf)

Sayaç durdurulduğunda oturum önce veritabanına yazılıyor (`await`), sonra sayaç kapatılıyor. Bu iki iş arasında **gerçek ağ gecikmesi** var ve Flutter o boşlukta bir kare çiziyor. O karede kayıtlı toplam **artmış** ama sayaç hâlâ "çalışıyor" göründüğü için canlı süre de ekleniyor → **oturumun tamamı iki kez sayılıyor** (1 saat çalışma → 2 saat görünüyor). Ekrandaki "dondurma" mekanizması bu zehirli sayıyı yakalayıp gün boyu kilitliyor. Çözüm: ekranın kendi gösterdiği sayıyı geri okumasını tamamen bırakmak; bunun yerine notifier'ın "veritabanına şu kadar saniye verdim" bilgisini **kesin** olarak yayınlaması.

---

## 1. ÖN KOŞULLAR VE ORTAK KURALLAR

### 1.1 Çalışma dizini ve komutlar

Tüm `flutter` komutları **`app/` klasöründe** çalışır (repo kökünde değil).

```powershell
# Analiz (dart-define ALMAZ — bayrak eklersen hata verir)
cd app; flutter analyze

# Test (tek dosya)
cd app; flutter test test/core/study_stats_test.dart

# Test (tümü)
cd app; flutter test
```

- `flutter analyze` çıktısı **0 issue** olmak zorunda. 1 uyarı bile varsa commit yok.
- `flutter test` çıktısında **failing yok**. "All tests passed!" görmeden ilerleme.

### 1.2 Git disiplini (`.agents/AGENTS.md` §1.5)

- Tek dal: `main`. **Branch açma, merge etme, push etme, tag atma.**
- Her WP = **tek commit**. Sadece o WP'nin SAHİP dosyalarını açık yolla stage et.
- **`git add -A` ve `git commit -a` YASAK.**
- Commit mesajı formatı: `WP-250: sayac durdurma cift-sayimi (settling) kesin fix`
  (Türkçe karakter kullanma — mevcut commit geçmişi ASCII.)

### 1.3 İşe başlamadan önce zorunlu claim

`progress.md` içindeki **Aktif Çalışma Kaydı**'na kendi lane'ini yaz (§6.1'de hazır metin var), sonra kaydı **yeniden oku** — başka aktif lane aynı dosyalara yazıyorsa **BAŞLAMA**, kullanıcıyı uyar.

Bu planın dokunduğu dosyalar başka bir lane'de açıksa çakışma vardır:
`app/lib/data/providers/study_providers.dart` · `app/lib/core/stats/study_stats.dart` · `app/lib/features/classroom/widgets/*` · `app/android/**/timer/*`

### 1.4 Bu projede daha önce tuzağa düşülen 3 nokta (tekrarlama)

1. **Riverpod 3 auto-dispose:** Dinleyicisi olmayan provider her `read`'de yeniden kurulur. Testte bir provider'ın canlı kalmasını istiyorsan `container.listen(...)` ile dinle ve `addTearDown(sub.close)` ekle. Yoksa test **sessizce anlamsızlaşır**.
2. **Saf fonksiyon testi ≠ regresyon testi.** WP-239 tam da bu yüzden bug'ı kaçırdı: saf fonksiyon doğru çalışıyordu, ona **yanlış girdi** veriliyordu. Bu planda her düzeltmenin bir de **davranış** testi var.
3. **`flutter analyze` `--dart-define-from-file` kabul etmez.** `flutter test`/`run`/`build` alır, `analyze` almaz.

---

# 2. WP-250 — Durdurma Çift-Sayımının Kesin Çözümü (P0)

## 2.0 Amaç ve kabul kriterleri

**Problem:** 1 saat kayıtlı + 1 saat canlı sayaç (ekran 2 saat) iken Durdur'a basınca ekran anlık **3 saat** gösteriyor ve gün boyu o değerde kalıyor. Uygulamayı kapatıp açınca düzeliyor (yani veritabanı doğru, ekran yanlış).

**Kabul kriterleri (hepsi ölçülebilir):**

- [ ] K1 — Durdurma anında ekrandaki "Bugün" toplamı **hiç değişmez** (ne artar ne azalır), kayıt yerleştikten sonra da aynı kalır.
- [ ] K2 — Uygulama arka plandayken bildirimden Durdur'a basılıp uygulama açıldığında, "Bugün" toplamı arka planda geçen ölü zamanı **içermez**.
- [ ] K3 — Pomodoro çalışma fazı bitip molaya geçtiğinde toplam **düşmez** (kayıt yerleşene kadar).
- [ ] K4 — Gece yarısını aşan bir oturum durdurulduğunda dünün süresi bugüne **sızmaz**.
- [ ] K5 — Tam ekran odak modu (`FocusTimerScreen`) ile kart aynı sayıyı gösterir.
- [ ] K6 — `flutter analyze` 0 issue; `flutter test` tamamı yeşil; 3 yeni test var ve **düzeltme olmadan düşüyor**.

## 2.1 SAHİP dosyalar (yalnız bunlara yazacaksın)

```
app/lib/core/stats/study_stats.dart
app/lib/data/providers/study_providers.dart
app/lib/features/classroom/widgets/study_timer_card.dart
app/lib/features/classroom/widgets/focus_timer_screen.dart
app/test/core/study_stats_test.dart
app/test/features/timer_background_reconcile_test.dart
app/test/features/classroom/study_timer_card_stop_test.dart   (YENİ)
progress.md   (yalnız kendi lane'in + kendi WP kartın)
```

## 2.2 DOKUNMA (bu WP'de kesinlikle değiştirilmeyecek)

- `app/lib/features/home/widgets/goal_card.dart` — **canlı süre göstermiyor, bu bilinçli.** Onu da "birleştirmek" ürün kararıdır, bu WP'nin kapsamı değil. Tek satır bile ekleme.
- `app/android/**` — WP-250 tamamen Dart tarafı.
- `resolveTodayDisplayTotal` dışındaki hiçbir `study_stats.dart` fonksiyonu.
- Native/kotlin, migration, tema, navigation.

## 2.3 Çözümün tek cümlelik mantığı (uygulamadan önce anla)

> Ekran artık "en son ne gösterdiysem onu dondurayım" demiyor. Notifier durdurma anında **veritabanına verdiği saniye sayısını** (`settlingSeconds`) ve **o an kayıtlı toplamı** (`settlingBaseline`) yayınlıyor. Ekran şunu hesaplıyor:
> `toplam = max(kayıtlı_toplam, baseline + settling) + canlı_süre`
> Kayıt yerleşmeden önce `kayıtlı_toplam == baseline` olduğu için sonuç `baseline + settling`. Yerleştikten sonra `kayıtlı_toplam` tam olarak `baseline + settling` değerine ulaşıyor. **İki durumda da aynı sayı** → ne zıplama ne düşme. Ayrıca `isStopping` bayrağı, durdurma başladığı milisaniyede canlı süreyi keser ki toplam iki kez sayılmasın.

---

## ADIM A1 — `study_stats.dart`: saf fonksiyonu değiştir

**Dosya:** `app/lib/core/stats/study_stats.dart`

**ESKİ KOD** (55–79. satırlar; birebir ara):

```dart
/// Saat kartı "bugün toplam" dondurma kuralı (saf).
///
/// Durdur anında kayıtlı toplam + oturum henüz stream'e düşmeden ekranda düşmesin
/// diye geçici freeze kullanılır. **Freeze yalnız aynı Istanbul gününde geçerlidir**;
/// gece yarısından sonra dünün 1s 5dk'sı bugün 0 iken ekranda kalmamalı.
({int total, int? keepFrozen}) resolveTodayDisplayTotal({
  required int recordedToday,
  required int liveWorkSeconds,
  int? frozenTotal,
  DateTime? frozenOnDay,
  required DateTime today,
}) {
  final todayKey = dayOf(today);
  final base = recordedToday + liveWorkSeconds;
  if (frozenTotal == null || frozenOnDay == null) {
    return (total: base, keepFrozen: null);
  }
  if (!isSameDay(dayOf(frozenOnDay), todayKey)) {
    return (total: base, keepFrozen: null);
  }
  if (base >= frozenTotal) {
    return (total: base, keepFrozen: null);
  }
  return (total: frozenTotal, keepFrozen: frozenTotal);
}
```

**YENİ KOD** (tamamının yerine):

```dart
/// Saat kartı / odak ekranı "bugün toplam" hesabı (saf, TEK kaynak).
///
/// WP-250: eski `frozenTotal` mantığı KALDIRILDI. Dondurma değeri ekranın kendi
/// gösterdiği sayıydı; `stop()` içindeki DB yazımı (ağ RTT'si) sırasında bir kare
/// çizilirse o sayı zaten şişmiş oluyordu ve dondurma **hatayı kalıcılaştırıyordu**
/// (1 saat çalışma → 2 saat görünüyordu). Artık notifier, DB'ye verilmiş ama henüz
/// [recordedToday]'e yansımamış saniyeyi KESİN olarak bildirir:
///
/// - [settlingSeconds]  : az önce kaydedilen çalışma aralığının süresi,
/// - [settlingBaseline] : kayıt başlarken [recordedToday] kaç idi,
/// - [settlingDay]      : o aralığın ait olduğu Istanbul günü (gece yarısı koruması).
///
/// Kural: `max(recordedToday, settlingBaseline + settlingSeconds) + liveWorkSeconds`.
/// Kayıt yerleşmeden önce `recordedToday == settlingBaseline` → sonuç
/// `baseline + settling`; yerleştikten sonra `recordedToday` aynı değere ulaşır →
/// **iki durumda da aynı sayı** (ne zıplama ne düşme).
int resolveTodayDisplayTotal({
  required int recordedToday,
  required int liveWorkSeconds,
  int settlingSeconds = 0,
  int settlingBaseline = 0,
  DateTime? settlingDay,
  required DateTime today,
}) {
  final live = liveWorkSeconds < 0 ? 0 : liveWorkSeconds;
  final base = recordedToday < 0 ? 0 : recordedToday;
  if (settlingSeconds <= 0 || settlingDay == null) return base + live;
  // Aralık başka bir Istanbul gününe aitse (gece yarısını aşan oturum) bugüne
  // uygulanmaz — dünün süresi bugünün toplamına sızmaz.
  if (!isSameDay(dayOf(settlingDay), dayOf(today))) return base + live;
  final settled = settlingBaseline + settlingSeconds;
  return (base > settled ? base : settled) + live;
}
```

> ⚠️ Dönüş tipi **record'dan `int`'e** değişti. Bunu bilerek yapıyoruz; tüm çağrı yerlerini A7/A8'de düzelteceğiz. `.total` yazan hiçbir yer kalmayacak.

---

## ADIM A2 — `StudyTimerState`: 4 yeni alan

**Dosya:** `app/lib/data/providers/study_providers.dart`

### A2.1 — Constructor

**ESKİ KOD** (251–271):

```dart
class StudyTimerState {
  const StudyTimerState({
    this.mode = TimerMode.stopwatch,
    this.isRunning = false,
    this.startedAt,
    this.subjectId,
    this.phase = TimerPhase.work,
    this.cycle = 1,
    this.countdownMinutes = 25,
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.cycles = 4,
    this.eventSeq = 0,
    this.lastEvent,
    this.accumulatedSeconds = 0,
    this.commandSeq = 0,
    this.lastUpdatedAt,
    this.liveRunId,
    this.liveRunToken,
    this.verification = TimerVerification.idle,
  });
```

**YENİ KOD:**

```dart
class StudyTimerState {
  const StudyTimerState({
    this.mode = TimerMode.stopwatch,
    this.isRunning = false,
    this.isStopping = false,
    this.startedAt,
    this.subjectId,
    this.phase = TimerPhase.work,
    this.cycle = 1,
    this.countdownMinutes = 25,
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.cycles = 4,
    this.eventSeq = 0,
    this.lastEvent,
    this.accumulatedSeconds = 0,
    this.commandSeq = 0,
    this.lastUpdatedAt,
    this.liveRunId,
    this.liveRunToken,
    this.verification = TimerVerification.idle,
    this.settlingSeconds = 0,
    this.settlingBaseline = 0,
    this.settlingDay,
  });
```

### A2.2 — Alan tanımları

**ESKİ KOD** (273–275):

```dart
  final TimerMode mode;
  final bool isRunning;

  /// Çalışırken mevcut FAZ segmentinin başlangıcı (anlık süre buradan hesaplanır).
  final DateTime? startedAt;
```

**YENİ KOD:**

```dart
  final TimerMode mode;
  final bool isRunning;

  /// WP-250: durdurma BAŞLADI ama henüz bitmedi (DB yazımı/ağ bekleniyor).
  /// Bu bayrak kalktığı an UI canlı süreyi saymayı bırakır. `isRunning` hâlâ
  /// true'dur — çünkü sayaç teknik olarak kapanmadı; ama kullanıcı açısından
  /// süre durmuştur. Bu ayrım olmadan, DB yazımı beklenirken kayıtlı toplam
  /// güncellenince canlı süre ikinci kez ekleniyordu (oturum boyu kadar şişme).
  final bool isStopping;

  /// Çalışırken mevcut FAZ segmentinin başlangıcı (anlık süre buradan hesaplanır).
  final DateTime? startedAt;
```

**ESKİ KOD** (304–306):

```dart
  final TimerVerification verification;

  bool get isVerifiedRun => liveRunId != null && liveRunToken != null;
```

**YENİ KOD:**

```dart
  final TimerVerification verification;

  /// WP-250 — "yerleşmeyi bekleyen" kayıt bilgisi. `study_sessions`'a yazılmış
  /// ama `todayRecordedSecondsProvider`'a henüz yansımamış olabilecek aralık:
  /// [settlingSeconds] o aralığın süresi, [settlingBaseline] yazım başlarken
  /// kayıtlı olan bugünkü toplam, [settlingDay] aralığın Istanbul günü.
  /// UI bu üçlüyle toplamı sabit tutar (bkz. `resolveTodayDisplayTotal`).
  /// Kayıt yerleşince `recorded >= baseline + settling` olur ve alanlar
  /// kendiliğinden etkisizleşir; ayrıca her yeni `start()` bunları sıfırlar.
  final int settlingSeconds;
  final int settlingBaseline;
  final DateTime? settlingDay;

  bool get isVerifiedRun => liveRunId != null && liveRunToken != null;
```

### A2.3 — `copyWith`

**ESKİ KOD** (317–360, tamamı):

```dart
  StudyTimerState copyWith({
    TimerMode? mode,
    bool? isRunning,
    DateTime? startedAt,
    bool clearStartedAt = false,
    String? subjectId,
    bool clearSubject = false,
    TimerPhase? phase,
    int? cycle,
    int? countdownMinutes,
    int? workMinutes,
    int? breakMinutes,
    int? cycles,
    int? eventSeq,
    TimerEvent? lastEvent,
    int? accumulatedSeconds,
    int? commandSeq,
    DateTime? lastUpdatedAt,
    String? liveRunId,
    String? liveRunToken,
    bool clearLiveRun = false,
    TimerVerification? verification,
  }) {
    return StudyTimerState(
      mode: mode ?? this.mode,
      isRunning: isRunning ?? this.isRunning,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      phase: phase ?? this.phase,
      cycle: cycle ?? this.cycle,
      countdownMinutes: countdownMinutes ?? this.countdownMinutes,
      workMinutes: workMinutes ?? this.workMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      cycles: cycles ?? this.cycles,
      eventSeq: eventSeq ?? this.eventSeq,
      lastEvent: lastEvent ?? this.lastEvent,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      commandSeq: commandSeq ?? this.commandSeq,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      liveRunId: clearLiveRun ? null : (liveRunId ?? this.liveRunId),
      liveRunToken: clearLiveRun ? null : (liveRunToken ?? this.liveRunToken),
      verification: verification ?? this.verification,
    );
  }
```

**YENİ KOD:**

```dart
  StudyTimerState copyWith({
    TimerMode? mode,
    bool? isRunning,
    bool? isStopping,
    DateTime? startedAt,
    bool clearStartedAt = false,
    String? subjectId,
    bool clearSubject = false,
    TimerPhase? phase,
    int? cycle,
    int? countdownMinutes,
    int? workMinutes,
    int? breakMinutes,
    int? cycles,
    int? eventSeq,
    TimerEvent? lastEvent,
    int? accumulatedSeconds,
    int? commandSeq,
    DateTime? lastUpdatedAt,
    String? liveRunId,
    String? liveRunToken,
    bool clearLiveRun = false,
    TimerVerification? verification,
    int? settlingSeconds,
    int? settlingBaseline,
    DateTime? settlingDay,
    bool clearSettling = false,
  }) {
    return StudyTimerState(
      mode: mode ?? this.mode,
      isRunning: isRunning ?? this.isRunning,
      isStopping: isStopping ?? this.isStopping,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      phase: phase ?? this.phase,
      cycle: cycle ?? this.cycle,
      countdownMinutes: countdownMinutes ?? this.countdownMinutes,
      workMinutes: workMinutes ?? this.workMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      cycles: cycles ?? this.cycles,
      eventSeq: eventSeq ?? this.eventSeq,
      lastEvent: lastEvent ?? this.lastEvent,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      commandSeq: commandSeq ?? this.commandSeq,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      liveRunId: clearLiveRun ? null : (liveRunId ?? this.liveRunId),
      liveRunToken: clearLiveRun ? null : (liveRunToken ?? this.liveRunToken),
      verification: verification ?? this.verification,
      // clearSettling her zaman kazanır (null geçilemeyen alanları sıfırlamanın
      // tek yolu budur; `settlingDay: null` "değiştirme" anlamına gelir).
      settlingSeconds: clearSettling ? 0 : (settlingSeconds ?? this.settlingSeconds),
      settlingBaseline: clearSettling
          ? 0
          : (settlingBaseline ?? this.settlingBaseline),
      settlingDay: clearSettling ? null : (settlingDay ?? this.settlingDay),
    );
  }
```

---

## ADIM A3 — `stop()`: bayrağı ve settling'i ilk `await`'ten ÖNCE yaz

**Dosya:** `app/lib/data/providers/study_providers.dart` (~1064)

**ESKİ KOD** (`Future<void> stop({DateTime? at}) async {` satırından, ona ait kapanış `}` dâhil — 1064–1108):

```dart
  Future<void> stop({DateTime? at}) async {
    // WP-246 (D2): devam eden bir durdurma varken ikinci giriş, aynı aralığı
    // tekrar kaydedip toplamı şişiriyordu → reddet.
    if (_stopInFlight) return;
    _stopInFlight = true;
    try {
      if (!state.isRunning) {
```

… (aradaki gövde) …

```dart
      } finally {
        // WP-246 (D4): kayıt/finalize hata verse bile sayaç DURMALI. Oturum
        // offline-first cache/outbox'ta zaten güvende; aksi halde tek bir hata
        // "sayaç durdurulamıyor"a dönüşüyordu (D1 mayınının belirtisi buydu).
        _finish();
      }
    } finally {
      _stopInFlight = false;
    }
  }
```

**YENİ KOD** (fonksiyonun TAMAMI — eskisini komple sil, bunu yaz):

```dart
  Future<void> stop({DateTime? at}) async {
    // WP-246 (D2): devam eden bir durdurma varken ikinci giriş, aynı aralığı
    // tekrar kaydedip toplamı şişiriyordu → reddet.
    if (_stopInFlight) return;
    _stopInFlight = true;
    try {
      if (!state.isRunning) {
        // WP-233: uygulama ÖNPLANDAYKEN bildirimden Başlat'a basılırsa resume
        // olayı hiç tetiklenmez, dolayısıyla native SSOT bu isolate'e adopte
        // edilmez ve state.isRunning false kalır. Eskiden burada sessizce
        // dönerdik → kullanıcı sayacı uygulama içinden durduramıyordu.
        // Pes etmeden önce native durumla bir kez uzlaş.
        await _reconcileBackgroundTimer();
        if (_disposed || !state.isRunning) return;
      }
      final startedAt = state.startedAt;
      final subjectId = state.subjectId;
      final wasWork = state.phase == TimerPhase.work;
      final end = (at != null && startedAt != null && at.isAfter(startedAt))
          ? at
          : DateTime.now();

      // WP-250 (KRİTİK — sıra değiştirilemez): aşağıdaki `await`'lerin toplamı
      // gerçek cihazda 100ms+ sürer (offline cache yazımı → yerel stream emit →
      // ardından ağ RTT'si). Flutter bu boşlukta bir kare çizer. O karede
      // `recorded` YENİ oturumu zaten içerir; sayaç hâlâ `isRunning` olduğu için
      // canlı süre de eklenirse toplam, oturumun tamamı kadar şişer.
      // Bu yüzden ilk await'ten ÖNCE:
      //   (1) canlı akışı kes  → isStopping = true
      //   (2) DB'ye verilecek saniyeyi + o anki kayıtlı toplamı yayınla
      // Böylece UI, kayıt yerleşmeden de yerleştikten de AYNI sayıyı gösterir.
      final recordedSeconds = (wasWork && startedAt != null)
          ? end.difference(startedAt).inSeconds
          : 0;
      if (recordedSeconds > 0 && startedAt != null) {
        state = state.copyWith(
          isStopping: true,
          settlingSeconds: recordedSeconds,
          settlingBaseline: ref.read(todayRecordedSecondsProvider),
          // Oturum `dayOf(start)` gününe yazılır; bugün değilse bugüne uygulanmaz.
          settlingDay: dayOf(startedAt),
        );
      } else {
        // Mola durduruldu ya da süre 0 → kaydedilecek bir şey yok.
        state = state.copyWith(isStopping: true, clearSettling: true);
      }

      await _verifiedStartFuture;

      // WP-104: oturum kaydını native FGS teardown (_finish → STOP_SILENT)
      // öncesine al. Süreç erken ölürse bile offline-first cache/outbox oturumu
      // tutar; STOP_SILENT kuyruğa interval yazmadığı için çift kayıt üretmez.
      try {
        if (wasWork && startedAt != null) {
          if (state.liveRunToken case final token?) {
            await _finalizeVerifiedRun(token);
          } else {
            await _recordSession(startedAt, end, subjectId);
          }
        }
      } finally {
        // WP-246 (D4): kayıt/finalize hata verse bile sayaç DURMALI. Oturum
        // offline-first cache/outbox'ta zaten güvende; aksi halde tek bir hata
        // "sayaç durdurulamıyor"a dönüşüyordu (D1 mayınının belirtisi buydu).
        _finish();
      }
    } finally {
      _stopInFlight = false;
    }
  }
```

> ⚠️ **`state = state.copyWith(isStopping: true, ...)` satırı `await _verifiedStartFuture;`'dan ÖNCE olmak zorunda.** Tek bir `await` bile önüne geçerse düzeltme çalışmaz.

---

## ADIM A4 — `_finish()`: bayrağı temizle, settling'i taşı

**Dosya:** `app/lib/data/providers/study_providers.dart` (~1211)

**ESKİ KOD:**

```dart
  /// Sayacı durdurur (kayıt yapmadan): timer'ı iptal et, çevrimdışına çek.
  void _finish({TimerEvent? lastEvent}) {
    _tick?.cancel();
    _tick = null;
    // WP-243: durdurulan çalışmanın startedAt-ms'ini hatırla. Native STOP diske
    // düşmeden gelen echo `reconcile` bu ms ile `running` okursa yeniden
    // benimsenmez (içerik-temelli durdurma yarışı koruması).
    _stoppedStartedAtMs = state.startedAt?.millisecondsSinceEpoch;
    state = state.copyWith(
      isRunning: false,
      clearStartedAt: true,
      phase: TimerPhase.work,
      cycle: 1,
      eventSeq: lastEvent != null ? state.eventSeq + 1 : state.eventSeq,
      lastEvent: lastEvent,
      clearLiveRun: true,
      verification: TimerVerification.idle,
    );
```

**YENİ KOD** (yalnız bu blok; altındaki `_clearActiveTimer();` ve devamı **aynen kalır**):

```dart
  /// Sayacı durdurur (kayıt yapmadan): timer'ı iptal et, çevrimdışına çek.
  ///
  /// WP-250: [settlingSeconds] > 0 verilirse "yerleşmeyi bekleyen kayıt" bilgisi
  /// bu geçişte state'e yazılır (pomodoro faz sonu gibi, kaydın `_finish`'ten
  /// SONRA yapıldığı yollar için). Verilmezse mevcut settling* değerleri
  /// korunur — `stop()` bunları zaten kendisi yazmıştır.
  void _finish({
    TimerEvent? lastEvent,
    int settlingSeconds = 0,
    int settlingBaseline = 0,
    DateTime? settlingDay,
  }) {
    _tick?.cancel();
    _tick = null;
    // WP-243: durdurulan çalışmanın startedAt-ms'ini hatırla. Native STOP diske
    // düşmeden gelen echo `reconcile` bu ms ile `running` okursa yeniden
    // benimsenmez (içerik-temelli durdurma yarışı koruması).
    _stoppedStartedAtMs = state.startedAt?.millisecondsSinceEpoch;
    state = state.copyWith(
      isRunning: false,
      // WP-250: sayaç kapandı; "durduruluyor" ara durumu da bitti.
      isStopping: false,
      clearStartedAt: true,
      phase: TimerPhase.work,
      cycle: 1,
      eventSeq: lastEvent != null ? state.eventSeq + 1 : state.eventSeq,
      lastEvent: lastEvent,
      clearLiveRun: true,
      verification: TimerVerification.idle,
      settlingSeconds: settlingSeconds > 0 ? settlingSeconds : null,
      settlingBaseline: settlingSeconds > 0 ? settlingBaseline : null,
      settlingDay: settlingSeconds > 0 ? settlingDay : null,
    );
```

> Not: `null` geçmek copyWith'te "değiştirme" demektir — `stop()` yolunda settling zaten doğru, korunması gerekiyor.

---

## ADIM A5 — `start()`: yeni koşu settling'i sıfırlasın

**Dosya:** `app/lib/data/providers/study_providers.dart` (~919)

**ESKİ KOD:**

```dart
    state = state.copyWith(
      isRunning: true,
      startedAt: now,
      phase: TimerPhase.work,
      cycle: 1,
      accumulatedSeconds: 0,
      lastUpdatedAt: now,
      clearLiveRun: true,
      verification: TimerVerification.idle,
    );
```

**YENİ KOD:**

```dart
    state = state.copyWith(
      isRunning: true,
      // WP-250: yeni koşu → durdurma ara durumu ve bekleyen kayıt bilgisi sıfır.
      isStopping: false,
      clearSettling: true,
      startedAt: now,
      phase: TimerPhase.work,
      cycle: 1,
      accumulatedSeconds: 0,
      lastUpdatedAt: now,
      clearLiveRun: true,
      verification: TimerVerification.idle,
    );
```

---

## ADIM A6 — `_completePhase()`: faz geçişinde de settling yaz

**Dosya:** `app/lib/data/providers/study_providers.dart` (~1129)

Bu fonksiyonda faz değişimi **kayıttan önce** yapılıyor (doğru sıra). Ama kayıt yerleşene kadar toplam **düşer** (canlı süre sıfırlanır, kayıt henüz görünmez). Eskiden bunu kartın "dondurma"sı gizliyordu; dondurmayı sildiğimiz için burada settling yazmalıyız.

**ESKİ KOD** (1157–1183 arası — `if (t.finished) {`'den fonksiyon sonuna kadar):

```dart
    if (t.finished) {
      _finish(lastEvent: t.event);
    } else {
      final now = DateTime.now();
      state = state.copyWith(
        phase: t.nextPhase,
        cycle: t.nextCycle,
        startedAt: now,
        eventSeq: state.eventSeq + 1,
        lastEvent: t.event,
      );
      _publishPresence(
        status: t.nextPhase == TimerPhase.work
            ? PresenceStatus.studying
            : PresenceStatus.onBreak,
        startedAt: now,
      );
      _persistActiveTimer();
      _startTick();
      unawaited(_syncTimerSurfaces());
    }

    // Çalışma fazı hedefe ulaştıysa süreyi kaydet (mola kaydedilmez).
    if (t.recordWork && !state.isVerifiedRun) {
      await _recordSession(startedAt, phaseEnd, subjectId);
    }
  }
```

**YENİ KOD:**

```dart
    // WP-250: bu geçişte `study_sessions`'a kaç saniye yazılacağını ÖNCEDEN
    // hesapla. `state` birazdan değişeceği için `isVerifiedRun` kontrolü de
    // burada yapılmalı — eskiden `_finish()` liveRun'ı temizledikten SONRA
    // kontrol ediliyordu ve verified koşuda hem finalize hem ek kayıt üretme
    // riski vardı (bugün ölü yol, yine de tutarlı hale getiriyoruz).
    final willRecord = t.recordWork && !state.isVerifiedRun;
    final settling = willRecord ? targetSeconds : 0;
    final settlingBaseline = willRecord
        ? ref.read(todayRecordedSecondsProvider)
        : 0;
    final settlingDay = willRecord ? dayOf(startedAt) : null;

    if (t.finished) {
      _finish(
        lastEvent: t.event,
        settlingSeconds: settling,
        settlingBaseline: settlingBaseline,
        settlingDay: settlingDay,
      );
    } else {
      final now = DateTime.now();
      state = state.copyWith(
        phase: t.nextPhase,
        cycle: t.nextCycle,
        startedAt: now,
        eventSeq: state.eventSeq + 1,
        lastEvent: t.event,
        settlingSeconds: settling,
        settlingBaseline: settlingBaseline,
        settlingDay: settlingDay,
        clearSettling: !willRecord,
      );
      _publishPresence(
        status: t.nextPhase == TimerPhase.work
            ? PresenceStatus.studying
            : PresenceStatus.onBreak,
        startedAt: now,
      );
      _persistActiveTimer();
      _startTick();
      unawaited(_syncTimerSurfaces());
    }

    // Çalışma fazı hedefe ulaştıysa süreyi kaydet (mola kaydedilmez).
    if (willRecord) {
      await _recordSession(startedAt, phaseEnd, subjectId);
    }
  }
```

---

## ADIM A7 — `_reconcileBackgroundTimerImpl()`: uyanma zehirlenmesini kapat

Bu, raporun "§2.2 Uyanma Zehirlenmesi" dediği hata. Uygulama arka plandayken bildirimden Durdur'a basılırsa, uygulama öne geldiğinde **önce bir kare çizilir** (canlı süre arka planda geçen ölü zamanı da içerir), **sonra** reconcile kuyruğu kaydedip `_finish()` çağırır. Çözüm: reconcile'a girer girmez, native'in zaten idle olduğunu görüp canlı akışı kesmek.

**Dosya:** `app/lib/data/providers/study_providers.dart` (~658)

### A7.1 — Fonksiyonun başına erken bayrak

**ESKİ KOD:**

```dart
  Future<void> _reconcileBackgroundTimerImpl() async {
    if (_disposed) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.reload();
    if (_disposed) return;

    // 1. App-kapalı Durdur'ların ürettiği tamamlanmış aralıkları oturum yaz.
```

**YENİ KOD:**

```dart
  Future<void> _reconcileBackgroundTimerImpl() async {
    if (_disposed) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.reload();
    if (_disposed) return;

    // WP-250: native taraf ZATEN idle ise (app-kapalı Durdur), bu tur kesinlikle
    // `_finish()` ile bitecek. Aşağıdaki kuyruk kaydı ağ bekler; o sırada ekranın
    // canlı süreyi saymaya devam etmesi, arka planda geçen ölü zamanı da toplama
    // ekliyordu. Bayrağı ŞİMDİ kaldır: canlı katkı anında 0 olur.
    // DİKKAT: bu bayrak reconcile'ın TAMAMINDA değil, yalnız bu koşulda kalkar.
    // Reconcile uygulama önplandayken her Başlat/Durdur broadcast'inde de çalışır;
    // koşulsuz kaldırılırsa yeni başlamış sayaç 0 saniye görünür (regresyon).
    final nativeIdleAtEntry =
        !((prefs.getString(_kActiveStartedAt)?.isNotEmpty ?? false) ||
            (prefs.getInt(_kActiveStartedAtMs) ?? 0) > 0);
    if (state.isRunning && !state.isStopping && nativeIdleAtEntry) {
      // Kuyruk kaydı `recorded`'ı zaten güncelleyecek → settling'e gerek yok.
      state = state.copyWith(isStopping: true, clearSettling: true);
    }

    // 1. App-kapalı Durdur'ların ürettiği tamamlanmış aralıkları oturum yaz.
```

### A7.2 — Sayaç yaşamaya devam eden iki dalda bayrağı geri al

**ESKİ KOD** (~749):

```dart
      } else if (state.isRunning && hasActiveStart && fgMode == 'idle') {
        // Nadir tutarsızlık: start keys var ama fg idle — native'i yeniden it.
        final started = state.startedAt;
```

**YENİ KOD:**

```dart
      } else if (state.isRunning && hasActiveStart && fgMode == 'idle') {
        // Nadir tutarsızlık: start keys var ama fg idle — native'i yeniden it.
        // WP-250: sayaç YAŞAMAYA DEVAM ediyor → erken kaldırılmış olabilecek
        // durdurma bayrağını geri al, yoksa canlı süre 0'da kilitli kalır.
        if (state.isStopping) {
          state = state.copyWith(isStopping: false);
        }
        final started = state.startedAt;
```

**ESKİ KOD** (~814):

```dart
    if (fgStart != null && stateNeedsNativeUpdate) {
      state = state.copyWith(
        isRunning: true,
        startedAt: fgStart,
```

**YENİ KOD:**

```dart
    if (fgStart != null && stateNeedsNativeUpdate) {
      state = state.copyWith(
        isRunning: true,
        // WP-250: native'den çalışan bir koşu benimsendi → durdurma bayrağı düşer.
        isStopping: false,
        startedAt: fgStart,
```

---

## ADIM A8 — `study_timer_card.dart`: dondurmayı sil

**Dosya:** `app/lib/features/classroom/widgets/study_timer_card.dart`

### A8.1 — Alanları sil

**ESKİ KOD** (41–51) — **tamamını sil, yerine hiçbir şey yazma**:

```dart
  /// Durdur/Mola anında bugünün toplamını geçici dondurur: biten oturum
  /// veritabanına yazılıp kayıtlı toplam güncellenene kadar değer düşmesin.
  /// Yalnız [_frozenOnDay] Istanbul günü için geçerlidir (gece yarısı sızıntısı yok).
  int? _frozenTotal;
  DateTime? _frozenOnDay;

  /// WP-239: en son build'de ekranda gösterilen bugünkü toplam (canlı süre
  /// dahil). Durdurma anında freeze değeri buradan alınır; recorded'ın o anki
  /// durumundan bağımsızdır, böylece canlı süre ikinci kez eklenip çift
  /// sayım (2s→3s) oluşmaz.
  int _lastDisplayedTotal = 0;
```

### A8.2 — `ref.listen` bloğunu sadeleştir

**ESKİ KOD** (130–148):

```dart
    // Durdurmada bugünün toplamını dondur + faz geçişinde ses/titreşim/uyarı (§2H).
    ref.listen<StudyTimerState>(studyTimerProvider, (prev, next) {
      if (prev == null) return;
      if (prev.isRunning && !next.isRunning && prev.startedAt != null) {
        // WP-239: durdurma anında EKRANDA GÖRÜNEN toplamı dondur. Eskiden
        // `recorded + extra` yazılıyordu; ama biten oturum offline cache'e
        // senkron yazılıp `recorded` provider'ı stop'tan ÖNCE güncellenince
        // `extra` (canlı süre) ikinci kez eklenip toplam şişiyordu (2s→3s,
        // kronometreyi kapat-aç ile düzeliyordu). Son gösterilen toplam zaten
        // canlı süreyi içeriyor: recorded ne zaman güncellenirse güncellensin
        // bu değer düşmeyi engeller ve çift saymaz.
        // Freeze anındaki Istanbul günü: gece yarısı sonrası dünün değeri sızmasın.
        _frozenOnDay = dayOf(DateTime.now());
        _frozenTotal = _lastDisplayedTotal;
      }
      if (next.eventSeq != prev.eventSeq && next.lastEvent != null) {
        _onTimerEvent(next.lastEvent!);
      }
    });
```

**YENİ KOD:**

```dart
    // Faz geçişinde ses/titreşim/uyarı (§2H).
    // WP-250: "durdurmada ekranı dondur" bloğu KALDIRILDI. Dondurulan değer
    // ekranın kendi gösterdiği sayıydı ve `stop()` sırasındaki kare çiziminde
    // zaten şişmiş olabiliyordu → hata kalıcılaşıyordu. Artık toplam, notifier'ın
    // bildirdiği settling* alanlarından türetilir (bkz. resolveTodayDisplayTotal).
    ref.listen<StudyTimerState>(studyTimerProvider, (prev, next) {
      if (prev == null) return;
      if (next.eventSeq != prev.eventSeq && next.lastEvent != null) {
        _onTimerEvent(next.lastEvent!);
      }
    });
```

### A8.3 — Toplam hesabı

**ESKİ KOD** (161–175):

```dart
    // Bugünün toplamına yalnız ÇALIŞMA fazının canlı süresi eklenir (mola hariç).
    // Gece yarısını aşan canlı oturum: elapsed hâlâ doğru; "bugün" kaydı
    // stream güncellenince recorded ile hizalanır (oturum start günü Istanbul).
    final liveWork = (timer.isRunning && inWork) ? elapsed : 0;
    // freeze alanlarını build içinde silme (setState riski yok); kural saf
    // resolveTodayDisplayTotal içinde: farklı gün → freeze yok sayılır.
    final todayTotal = resolveTodayDisplayTotal(
      recordedToday: recorded,
      liveWorkSeconds: liveWork,
      frozenTotal: _frozenTotal,
      frozenOnDay: _frozenOnDay,
      today: todayKey,
    ).total;
    // WP-239: durdurma anında dondurulacak "görünen toplam" için sakla.
    _lastDisplayedTotal = todayTotal;
```

**YENİ KOD:**

```dart
    // Bugünün toplamına yalnız ÇALIŞMA fazının canlı süresi eklenir (mola hariç).
    // WP-250: durdurma başladığı an (isStopping) canlı akış kesilir; aradaki
    // saniyeler settling* alanlarıyla taşınır → ne zıplama ne düşme.
    final liveWork = (timer.isRunning && !timer.isStopping && inWork)
        ? elapsed
        : 0;
    final todayTotal = resolveTodayDisplayTotal(
      recordedToday: recorded,
      liveWorkSeconds: liveWork,
      settlingSeconds: timer.settlingSeconds,
      settlingBaseline: timer.settlingBaseline,
      settlingDay: timer.settlingDay,
      today: todayKey,
    );
```

> ⚠️ **`elapsed` ve `displaySeconds` değişkenlerine DOKUNMA.** Büyük saatin durdurma anında birkaç yüz milisaniye daha ilerlemesi kabul edilir; `elapsed`'i sıfırlarsan saat bir an 00:00'a düşer, bu daha kötü bir görsel hatadır.

---

## ADIM A9 — `focus_timer_screen.dart`: aynı hesabı kullan

**Dosya:** `app/lib/features/classroom/widgets/focus_timer_screen.dart`

### A9.1 — Import ekle

**ESKİ KOD** (8. satır):

```dart
import '../../../core/theme/subject_colors.dart';
```

**YENİ KOD:**

```dart
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
```

### A9.2 — Hesabı değiştir

**ESKİ KOD** (78–79):

```dart
    final liveWork = (timer.isRunning && inWork) ? elapsed : 0;
    final todayTotal = recorded + liveWork;
```

**YENİ KOD:**

```dart
    // WP-250: kart ile birebir aynı kural (iki ekranın farklı sayı göstermesi
    // bug'dı). Durdurma başlayınca canlı akış kesilir; bekleyen kayıt settling*
    // alanlarıyla taşınır.
    final liveWork = (timer.isRunning && !timer.isStopping && inWork)
        ? elapsed
        : 0;
    final todayTotal = resolveTodayDisplayTotal(
      recordedToday: recorded,
      liveWorkSeconds: liveWork,
      settlingSeconds: timer.settlingSeconds,
      settlingBaseline: timer.settlingBaseline,
      settlingDay: timer.settlingDay,
      today: DateTime.now(),
    );
```

---

## ADIM A10 — Testler

### A10.1 — `study_stats_test.dart` (saf fonksiyon)

**Dosya:** `app/test/core/study_stats_test.dart`

**ESKİ KOD** — 31–98 arasındaki **üç testi** (`resolveTodayDisplayTotal: freeze dünse…`, `resolveTodayDisplayTotal: aynı günde freeze…`, `WP-239: freeze = görünen toplam…`) komple sil.

**YENİ KOD** (yerine):

```dart
  group('WP-250: resolveTodayDisplayTotal (settling modeli)', () {
    final today = DateTime(2026, 7, 21);

    test('settling yokken: kayıtlı + canlı', () {
      expect(
        resolveTodayDisplayTotal(
          recordedToday: 3600,
          liveWorkSeconds: 600,
          today: today,
        ),
        4200,
      );
    });

    test('kayıt yerleşmeden ÖNCE: baseline + settling (canlı 0)', () {
      // Durdurma anı: 1sa kayıtlı + 1sa canlı (ekran 2sa) → Durdur.
      // recorded henüz eski (3600), settling 3600, canlı kesildi.
      expect(
        resolveTodayDisplayTotal(
          recordedToday: 3600,
          liveWorkSeconds: 0,
          settlingSeconds: 3600,
          settlingBaseline: 3600,
          settlingDay: today,
          today: today,
        ),
        7200,
        reason: '2 saat görünmeli',
      );
    });

    test('kayıt yerleştikten SONRA: aynı sayı (zıplama yok)', () {
      // Stream emit etti: recorded = 7200. Sonuç DEĞİŞMEMELİ.
      expect(
        resolveTodayDisplayTotal(
          recordedToday: 7200,
          liveWorkSeconds: 0,
          settlingSeconds: 3600,
          settlingBaseline: 3600,
          settlingDay: today,
          today: today,
        ),
        7200,
        reason: 'eski hata burada 10800 (3 saat) üretiyordu',
      );
    });

    test('settling başka güne aitse bugüne uygulanmaz (gece yarısı)', () {
      expect(
        resolveTodayDisplayTotal(
          recordedToday: 0,
          liveWorkSeconds: 0,
          settlingSeconds: 3900,
          settlingBaseline: 0,
          settlingDay: DateTime(2026, 7, 20),
          today: today,
        ),
        0,
        reason: 'dünün süresi bugünün toplamına sızmamalı',
      );
    });

    test('araya başka bir kayıt girse de düşmez', () {
      // Manuel ekleme vs. recorded'ı 3600 → 5400 yaptı; settling hâlâ bekliyor.
      expect(
        resolveTodayDisplayTotal(
          recordedToday: 5400,
          liveWorkSeconds: 0,
          settlingSeconds: 3600,
          settlingBaseline: 3600,
          settlingDay: today,
          today: today,
        ),
        7200,
        reason: 'max() kuralı: hangisi büyükse o',
      );
    });
  });
```

> Dosyanın en üstünde `void main() {` var; bu `group(...)` bloğunu **`main()` gövdesinin içine**, sildiğin testlerin yerine koy.

### A10.2 — `timer_background_reconcile_test.dart` (davranış testi — ASIL regresyon)

**Dosya:** `app/test/features/timer_background_reconcile_test.dart`

**Değişiklik 1 — `_buildContainer` yardımcısına opsiyonel repo parametresi ekle.**

**ESKİ KOD:**

```dart
Future<(ProviderContainer, InMemoryStudyRepository, Profile)> _buildContainer(
  Map<String, Object> initialPrefs,
) async {
```

**YENİ KOD:**

```dart
Future<(ProviderContainer, InMemoryStudyRepository, Profile)> _buildContainer(
  Map<String, Object> initialPrefs, {
  InMemoryStudyRepository? repository,
}) async {
```

**ESKİ KOD:**

```dart
  final studyRepo = InMemoryStudyRepository();
```

**YENİ KOD:**

```dart
  final studyRepo = repository ?? InMemoryStudyRepository();
```

**Değişiklik 2 — dosyanın en üstündeki import'lara ekle:**

```dart
import 'package:online_study_room/core/stats/study_stats.dart';
```

**Değişiklik 3 — `_NoopAndroidWidgetService` sınıfının hemen altına yavaş repo ekle:**

```dart
/// WP-250: gerçek cihazdaki yazım sırasını taklit eder — önce yerel cache'e
/// yazılır ve `userSessions` stream'i EMIT EDER, sonra ağ RTT'si beklenir.
/// Bu gecikme olmadan bug reprodüksiyonu imkânsızdır (test ortamı saf
/// microtask zinciridir, araya kare/emit girmez).
class _SlowStudyRepository extends InMemoryStudyRepository {
  @override
  Future<void> addSession(StudySession session) async {
    await super.addSession(session); // yerel emit
    await Future<void>.delayed(const Duration(milliseconds: 150)); // "ağ"
  }
}
```

`StudySession` import'u gerekiyorsa ekle:

```dart
import 'package:online_study_room/data/models/study_session.dart';
```

**Değişiklik 4 — dosyanın sonuna (son `}` içinde, `main()` gövdesinin sonuna) yeni grup:**

```dart
  group('WP-250: durdurma çift-sayımı (settling modeli)', () {
    test(
      'DB yazımı (RTT) sürerken ekran toplamı ne zıplar ne düşer',
      () async {
        final start = DateTime.now().subtract(const Duration(minutes: 20));
        final slowRepo = _SlowStudyRepository();
        final (container, studyRepo, profile) = await _buildContainer({
          'timer_active_started_at': start.toIso8601String(),
          'timer_active_started_at_ms': start.millisecondsSinceEpoch,
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
        }, repository: slowRepo);

        // Riverpod 3: dinleyicisiz provider her read'de yeniden kurulur →
        // stream'i canlı tutmak için ikisini de dinle (yoksa test anlamsızlaşır).
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        final sessionsSub = container.listen(
          userSessionsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sessionsSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(studyTimerProvider).isRunning, isTrue);

        // Ekranın gösterdiği sayıyı, UI ile BİREBİR aynı kuralla hesapla.
        int displayed() {
          final t = container.read(studyTimerProvider);
          final elapsed = (t.isRunning && !t.isStopping && t.startedAt != null)
              ? DateTime.now().difference(t.startedAt!).inSeconds
              : 0;
          return resolveTodayDisplayTotal(
            recordedToday: container.read(todayRecordedSecondsProvider),
            liveWorkSeconds: t.phase == TimerPhase.work ? elapsed : 0,
            settlingSeconds: t.settlingSeconds,
            settlingBaseline: t.settlingBaseline,
            settlingDay: t.settlingDay,
            today: DateTime.now(),
          );
        }

        final before = displayed(); // ≈ 1200 sn
        expect(before, greaterThan(1100));

        final stopFuture = container.read(studyTimerProvider.notifier).stop();

        // RTT penceresi: yerel cache emit oldu, `_finish()` HENÜZ çalışmadı.
        // Düzeltme olmadan burada toplam ~2x olur (oturum boyu kadar şişme).
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(
          container.read(studyTimerProvider).isStopping,
          isTrue,
          reason: 'durdurma başlar başlamaz canlı akış kesilmeli',
        );
        expect(
          displayed(),
          closeTo(before, 2),
          reason: 'RTT penceresinde toplam şişmemeli (asıl bug)',
        );

        await stopFuture;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          displayed(),
          closeTo(before, 2),
          reason: 'durdurma bittikten sonra da aynı sayı',
        );

        final sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(sessions, hasLength(1));
      },
    );

    test(
      'app-kapalı Durdur sonrası uyanma: ölü zaman toplama eklenmez',
      () async {
        // Kullanıcı 30 dk çalıştı, 25 dk önce bildirimden Durdur'a bastı,
        // uygulamayı ŞİMDİ açıyor. Kuyrukta gerçek aralık var; state ise
        // (arka planda uyuyan isolate gibi) hâlâ "çalışıyor".
        final start = DateTime.now().subtract(const Duration(minutes: 55));
        final end = DateTime.now().subtract(const Duration(minutes: 25));
        final (container, _, _) = await _buildContainer({
          'timer_active_started_at': start.toIso8601String(),
          'timer_active_started_at_ms': start.millisecondsSinceEpoch,
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
        });
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        final sessionsSub = container.listen(
          userSessionsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sessionsSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Native Durdur'u taklit et: start anahtarları silinir, kuyruğa aralık.
        final prefs = container.read(sharedPreferencesProvider);
        await prefs.remove('timer_active_started_at');
        await prefs.remove('timer_active_started_at_ms');
        await prefs.setString('timer_fg_mode', 'idle');
        await prefs.setString(
          'timer_pending_intervals',
          '[{"start":"${start.toIso8601String()}",'
              '"end":"${end.toIso8601String()}","subject":""}]',
        );

        await container.read(studyTimerProvider.notifier).stop();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final t = container.read(studyTimerProvider);
        expect(t.isRunning, isFalse);
        final total = resolveTodayDisplayTotal(
          recordedToday: container.read(todayRecordedSecondsProvider),
          liveWorkSeconds: 0,
          settlingSeconds: t.settlingSeconds,
          settlingBaseline: t.settlingBaseline,
          settlingDay: t.settlingDay,
          today: DateTime.now(),
        );
        // Gerçekten çalışılan 30 dk kaydedilir; aradaki 25 dk ölü zaman
        // toplama EKLENMEZ (eski hata: ~55 dk gösterip gün boyu kilitlerdi).
        expect(total, closeTo(30 * 60, 5));
      },
    );
  });
```

### A10.3 — Widget testi (ekranda gerçekten zıplamıyor mu?)

**YENİ DOSYA:** `app/test/features/classroom/study_timer_card_stop_test.dart`

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Gerçek notifier'ın (kanal/dinleyici kurulumu olan) build()'ini atlayan sahte.
/// Testte state'i biz elle sürüyoruz; amaç UI'ın hesabını doğrulamak.
class _FakeTimerNotifier extends StudyTimerNotifier {
  _FakeTimerNotifier(this._initial);

  final StudyTimerState _initial;

  @override
  StudyTimerState build() => _initial;

  void push(StudyTimerState next) => state = next;
}

void main() {
  testWidgets(
    'WP-250: Durdur sırasında "Bugün" toplamı zıplamaz',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      final startedAt = now.subtract(const Duration(hours: 1));
      // Bugün zaten kayıtlı 1 saat.
      final recordedSession = StudySession(
        id: 'rec-1',
        userId: 'u1',
        start: now.subtract(const Duration(hours: 3)),
        end: now.subtract(const Duration(hours: 2)),
        durationSeconds: 3600,
        source: StudySource.live,
      );
      // Durdurulan 1 saatlik oturum DB'ye düştüğünde eklenecek satır.
      final stoppedSession = StudySession(
        id: 'rec-2',
        userId: 'u1',
        start: startedAt,
        end: now,
        durationSeconds: 3600,
        source: StudySource.live,
      );

      final sessions = StreamController<List<StudySession>>.broadcast();
      addTearDown(sessions.close);

      final running = StudyTimerState(
        isRunning: true,
        startedAt: startedAt,
        phase: TimerPhase.work,
      );
      final fake = _FakeTimerNotifier(running);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userSessionsProvider.overrideWith((ref) => sessions.stream),
            userSubjectsProvider.overrideWith(
              (ref) => Stream.value(const <Subject>[]),
            ),
            dailyGoalMinutesProvider.overrideWithValue(240),
            userGroupProvider.overrideWithValue(
              const AsyncData<StudyGroup?>(null),
            ),
            studyTimerProvider.overrideWith(() => fake),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(width: 380, height: 900, child: StudyTimerCard()),
            ),
          ),
        ),
      );

      sessions.add([recordedSession]);
      await tester.pump();

      // 1 saat kayıtlı + 1 saat canlı = 2 saat.
      expect(find.text(formatHumanSeconds(7200)), findsWidgets);

      // --- Durdur'a basıldı: notifier ilk await'ten önce bunu yayınlar. ---
      fake.push(
        running.copyWith(
          isStopping: true,
          settlingSeconds: 3600,
          settlingBaseline: 3600,
          settlingDay: DateTime(now.year, now.month, now.day),
        ),
      );
      await tester.pump();
      expect(
        find.text(formatHumanSeconds(7200)),
        findsWidgets,
        reason: 'durdurma anında toplam değişmemeli',
      );

      // --- RTT penceresi: kayıt yerel cache'e düştü, stream emit etti,
      //     ama `_finish()` HENÜZ çalışmadı (isRunning hâlâ true). ---
      sessions.add([recordedSession, stoppedSession]);
      await tester.pump();
      expect(
        find.text(formatHumanSeconds(7200)),
        findsWidgets,
        reason: 'ASIL BUG: burada 3 saat görünüyordu',
      );
      expect(find.text(formatHumanSeconds(10800)), findsNothing);

      // --- `_finish()` çalıştı. ---
      fake.push(
        const StudyTimerState().copyWith(
          settlingSeconds: 3600,
          settlingBaseline: 3600,
          settlingDay: DateTime(now.year, now.month, now.day),
        ),
      );
      await tester.pump();
      expect(find.text(formatHumanSeconds(7200)), findsWidgets);
    },
  );
}
```

**Bu test derlenmezse (olası 2 durum):**

- `userGroupProvider` bulunamadı → import yolunu `grep -rn "final userGroupProvider" app/lib` ile bul ve düzelt.
- Ek bir provider "override edilmeli" hatası verirse (`UnimplementedError`), hata mesajındaki provider'ı overrides listesine ekle. **Testi silme, hatayı çöz.**

---

## ADIM A11 — Kırmızı–yeşil ispatı (ZORUNLU, atlanmaz)

Testlerin gerçekten bu bug'ı yakaladığını kanıtla. **Sırayla:**

1. Her şey yeşilken çalıştır ve çıktıyı kaydet:
   ```powershell
   cd app; flutter test test/core/study_stats_test.dart test/features/timer_background_reconcile_test.dart test/features/classroom/study_timer_card_stop_test.dart
   ```
2. **Geçici olarak** `study_timer_card.dart` A8.3'teki satırı bozarak eski davranışa döndür:
   ```dart
   final liveWork = (timer.isRunning && inWork) ? elapsed : 0;   // GEÇİCİ
   ```
   → `study_timer_card_stop_test.dart` **DÜŞMELİ** (`3 sa` bulunacak). Düşmüyorsa test yanlıştır, düzelt.
3. Satırı geri al (`!timer.isStopping` geri gelsin), test yeşile dönsün.
4. **Geçici olarak** `stop()` içindeki `state = state.copyWith(isStopping: true, …)` bloğunu `await _verifiedStartFuture;` satırının **altına** taşı.
   → `timer_background_reconcile_test.dart`'taki "RTT penceresi" testi **DÜŞMELİ**. (Düşmezse gecikme yetersizdir; `_SlowStudyRepository` gecikmesini 300 ms yap.)
5. Bloğu doğru yerine geri al, test yeşile dönsün.

Yanıtında bu 5 adımın çıktısını **özetle** (hangi test düştü, hangi mesajla).

---

## ADIM A12 — Kapanış

```powershell
cd app; flutter analyze          # 0 issue
cd app; flutter test             # tümü yeşil
```

`flutter analyze` şu iki hatayı verebilir, ikisi de beklenen ve senin düzeltmen gerekir:

- `The getter 'total' isn't defined for the type 'int'` → bir yerde hâlâ `resolveTodayDisplayTotal(...).total` var. `grep -rn "resolveTodayDisplayTotal" app/` ile bul, `.total`'ı sil.
- `The named parameter 'frozenTotal' isn't defined` → eski çağrı kalmış, A8.3/A9.2'ye göre düzelt.

**Commit:**

```powershell
git add app/lib/core/stats/study_stats.dart app/lib/data/providers/study_providers.dart app/lib/features/classroom/widgets/study_timer_card.dart app/lib/features/classroom/widgets/focus_timer_screen.dart app/test/core/study_stats_test.dart app/test/features/timer_background_reconcile_test.dart app/test/features/classroom/study_timer_card_stop_test.dart progress.md
git commit -m "WP-250: sayac durdurma cift-sayimi - settling modeli (freeze kaldirildi)"
```

## 2.4 WP-250 cihaz QA listesi (kullanıcı yapacak — sen sadece yaz)

1. 2 dk çalış → Durdur. "Bugün" toplamı **anlık olarak bile** zıplamamalı; uygulamayı kapatıp açınca aynı kalmalı.
2. 1 sa kayıt varken 1 dk daha çalış → Durdur → toplam tam 1 sa 1 dk.
3. Uçak modunda çalış → Durdur → toplam doğru (offline yazım).
4. Çalışırken uygulamayı arka plana al, bildirimden Durdur, 5 dk sonra uygulamayı aç → toplam yalnız gerçek çalışma kadar artmalı.
5. Pomodoro 1 dk çalışma / 1 dk mola ile: çalışma bitip molaya geçerken toplam **düşmemeli**.
6. Tam ekran odak modunu aç/kapa → iki ekran aynı sayıyı göstermeli.

## 2.5 WP-250 rollback

Tek commit olduğu için: `git revert <commit-sha>`. Kısmi geri alma yok — `settling` alanları kaldırılırsa UI derlenmez.

---

# 3. WP-251 — Kuyruk Çift-Yazımı ve Kayıp Oturum (P1)

## 3.0 Problem (kodda doğrulandı)

`_reconcileBackgroundTimerImpl` içinde, app-kapalı Durdur'ların bıraktığı aralık kuyruğu işleniyor. İki ayrı kusur var:

1. **Replay (çift oturum):** Kuyrukta 3 aralık varsa ve 2.'si hata alırsa `recordedOk = false` olur, kuyruk **hiç** temizlenmez; sonraki açılışta 1. aralık **tekrar** yazılır. Her açılışta bir kopya daha eklenir.
2. **Kayıp oturum:** Temizleme `prefs.remove(pendingIntervalsKey)` ile **tüm anahtarı** siliyor. Reconcile ağ beklerken kullanıcı bildirimden Durdur'a basarsa native kuyruğa yeni bir aralık ekler ve Dart onu **okumadan siler** → o çalışma tamamen kaybolur.

**İyi haber:** yazım katmanı zaten idempotent — `supabase_study_repository.dart:113` `upsert(..., onConflict: 'id')`, offline cache de id ile upsert ediyor. Yani sadece **kuyruk kaydına kalıcı bir id** koymak ve **kısmi silme** yapmak yeterli. Repository'ye dokunmayacaksın.

## 3.1 SAHİP dosyalar

```
app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt
app/lib/data/providers/study_providers.dart
app/test/features/timer_background_reconcile_test.dart
progress.md
```

**DOKUNMA:** repository dosyaları, `StudyTimerService.kt`, migration, UI.

---

## ADIM B1 — Kotlin: kuyruk kayıtlarına UUID

**Dosya:** `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt`

**ESKİ KOD** (7. satır civarı):

```kotlin
import java.time.Instant
```

**YENİ KOD:**

```kotlin
import java.time.Instant
import java.util.UUID
```

**ESKİ KOD:**

```kotlin
        list.put(
            JSONObject()
                .put("start", Instant.ofEpochMilli(startMs).toString())
                .put("end", Instant.ofEpochMilli(endMs).toString())
                .put("subject", subject)
                .put("origin", origin),
        )
```

**YENİ KOD:**

```kotlin
        list.put(
            JSONObject()
                // WP-251: kalıcı idempotency anahtarı. Dart bunu doğrudan
                // `study_sessions.id` olarak kullanır; kuyruk kısmen başarısız
                // olup tekrar işlense bile upsert AYNI satıra düşer → çift
                // oturum yazılmaz. Aynı anahtar kuyruktan "yalnız işlenenleri
                // sil" için de kullanılır (toptan silme oturum kaybettiriyordu).
                // DİKKAT: değer UUID biçiminde OLMAK ZORUNDA — sütun tipi uuid;
                // serbest metin ("native-123" gibi) insert'i patlatır.
                .put("id", UUID.randomUUID().toString())
                .put("start", Instant.ofEpochMilli(startMs).toString())
                .put("end", Instant.ofEpochMilli(endMs).toString())
                .put("subject", subject)
                .put("origin", origin),
        )
```

**ESKİ KOD** (`appendPendingVerifiedCommand` içinde):

```kotlin
        list.put(
            JSONObject()
                .put("action", action)
                .put("runToken", runToken)
                .put("origin", origin),
        )
```

**YENİ KOD:**

```kotlin
        list.put(
            JSONObject()
                // WP-251: bu kayıt oturum değil (komut); id yalnız kuyruktan
                // güvenli silme içindir, DB'ye gitmez.
                .put("id", UUID.randomUUID().toString())
                .put("action", action)
                .put("runToken", runToken)
                .put("origin", origin),
        )
```

---

## ADIM B2 — Dart: `_recordSession` id alsın

**Dosya:** `app/lib/data/providers/study_providers.dart` (~1239)

**ESKİ KOD:**

```dart
  /// Tamamlanan bir aralığı `study_sessions`'a yazar.
  Future<void> _recordSession(
    DateTime start,
    DateTime end,
    String? subjectId,
  ) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final duration = end.difference(start).inSeconds;
    if (duration <= 0) return;

    await ref
        .read(studyRepositoryProvider)
        .addSession(
          StudySession(
            id: _uuid.v4(),
```

**YENİ KOD:**

```dart
  /// Tamamlanan bir aralığı `study_sessions`'a yazar.
  ///
  /// WP-251: [sessionId] verilirse oturum id'si olarak KULLANILIR. Native
  /// kuyruktan gelen aralıklar kendi kalıcı UUID'lerini taşır; aynı aralık
  /// tekrar işlenirse `upsert(onConflict: id)` aynı satıra düşer → çift oturum
  /// oluşmaz. Verilmezse (canlı durdurma) yeni uuid üretilir.
  Future<void> _recordSession(
    DateTime start,
    DateTime end,
    String? subjectId, {
    String? sessionId,
  }) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final duration = end.difference(start).inSeconds;
    if (duration <= 0) return;

    await ref
        .read(studyRepositoryProvider)
        .addSession(
          StudySession(
            id: sessionId ?? _uuid.v4(),
```

---

## ADIM B3 — Dart: kuyruk işleme döngüsünü değiştir

**Dosya:** `app/lib/data/providers/study_providers.dart` (~664–731)

**ESKİ KOD** (`// 1. App-kapalı Durdur'ların…` yorumundan, `      if (recordedOk) {` … `    }` bloğunun kapanışına kadar TAMAMI):

```dart
    // 1. App-kapalı Durdur'ların ürettiği tamamlanmış aralıkları oturum yaz.
    // Kimlik henüz hazır değilse kuyruğu KORU (clear yarışı yok — WP-136).
    final raw = prefs.getString(TimerForegroundService.pendingIntervalsKey);
    if (raw != null && ref.read(authStateProvider).value != null) {
      var recordedOk = true;
      ...
      // WP-136: yalnız başarılı (veya bozuk) kuyruk temizlenir; partial fail korunur.
      if (recordedOk) {
        await prefs.remove(TimerForegroundService.pendingIntervalsKey);
      }
    }
```

**YENİ KOD** (tamamının yerine):

```dart
    // 1. App-kapalı Durdur'ların ürettiği tamamlanmış aralıkları oturum yaz.
    // Kimlik henüz hazır değilse kuyruğu KORU (clear yarışı yok — WP-136).
    //
    // WP-251: eskiden "hepsi başarılıysa anahtarı komple sil" mantığı vardı.
    // İki kusur üretiyordu: (a) tek kayıt hata alınca başarılı olanlar da
    // kuyrukta kalıp bir sonraki açılışta TEKRAR yazılıyordu (çift oturum),
    // (b) toptan silme, reconcile sürerken native'in eklediği YENİ aralığı da
    // siliyordu (oturum kaybı). Artık yalnız işlenen kayıtlar, kimlikleriyle
    // kuyruktan düşürülür.
    final raw = prefs.getString(TimerForegroundService.pendingIntervalsKey);
    if (raw != null && ref.read(authStateProvider).value != null) {
      final processedKeys = <String>{};
      var queueBroken = false;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          queueBroken = true;
        } else {
          for (final entry in decoded) {
            if (_disposed) return;
            if (entry is! Map) continue;
            final key = _pendingEntryKey(entry);
            final runToken = entry['runToken']?.toString();
            final action = entry['action']?.toString();

            // (a) Verified komut kayıtları (pause/resume/finalize).
            if (runToken != null && runToken.isNotEmpty && action != null) {
              try {
                final repo = ref.read(studyRepositoryProvider);
                switch (action) {
                  case 'pause':
                    await repo.pauseLiveRun(runToken);
                  case 'resume':
                    await repo.resumeLiveRun(runToken);
                  case 'finalize':
                    await _finalizeVerifiedRun(runToken);
                  default:
                    throw const FormatException('unknown verified command');
                }
                processedKeys.add(key);
              } on FormatException {
                // Tanınmayan komut sonsuza kadar kuyrukta kalmasın.
                processedKeys.add(key);
              } catch (_) {
                // Ağ/sunucu hatası → kuyrukta kalsın, sonra denenir.
              }
              continue;
            }

            // (b) Tamamlanmış çalışma aralıkları.
            final start = DateTime.tryParse(entry['start']?.toString() ?? '');
            final end = DateTime.tryParse(entry['end']?.toString() ?? '');
            final subjectRaw = entry['subject']?.toString();
            final subject = (subjectRaw == null || subjectRaw.isEmpty)
                ? null
                : subjectRaw;
            if (start == null || end == null || !end.isAfter(start)) {
              // Anlamsız kayıt: düş, yoksa kuyruk sonsuza kadar tıkanır.
              processedKeys.add(key);
              continue;
            }
            try {
              final rawId = entry['id']?.toString();
              await _recordSession(
                start,
                end,
                subject,
                sessionId: (rawId != null && rawId.isNotEmpty) ? rawId : null,
              );
              // Oturum yazıldı → kuyruktan düşer. Telemetri hatası bunu
              // geri almamalı (yoksa aynı oturum tekrar tekrar denenir).
              processedKeys.add(key);
              try {
                final origin = entry['origin']?.toString();
                final build = await _clientBuildNumber();
                await ref
                    .read(studyRepositoryProvider)
                    .recordVerifiedSessionRollout(
                      platform: _rolloutPlatform,
                      clientBuild: build,
                      capability: true,
                      origin: origin == 'native_widget'
                          ? LiveStartOrigin.nativeWidget
                          : LiveStartOrigin.nativeNotification,
                      outcome: LiveRolloutOutcome.unverifiedFallback,
                    );
              } catch (_) {
                // Telemetri best-effort.
              }
            } catch (_) {
              // Kayıt başarısız → kuyrukta kalsın.
            }
          }
        }
      } catch (_) {
        queueBroken = true;
      }
      if (queueBroken) {
        await prefs.remove(TimerForegroundService.pendingIntervalsKey);
      } else if (processedKeys.isNotEmpty) {
        await _dropProcessedPendingEntries(processedKeys);
      }
    }
```

---

## ADIM B4 — Dart: iki yeni yardımcı metod

**Dosya:** `app/lib/data/providers/study_providers.dart`

`_reconcileBackgroundTimerImpl` fonksiyonunun **kapanış `}`'ının hemen altına** ekle (yani bir sonraki metodun üstüne):

```dart
  /// WP-251: kuyruk kaydının kalıcı kimliği. Native artık her kayda `id` yazar;
  /// eski sürümlerden kalmış id'siz kayıtlar için içerikten türetilen anahtar
  /// kullanılır (aynı kaydı iki kez işlememek için yeterli).
  static String _pendingEntryKey(Map<dynamic, dynamic> entry) {
    final id = entry['id']?.toString();
    if (id != null && id.isNotEmpty) return 'id:$id';
    return 'legacy:${entry['action']}|${entry['runToken']}|'
        '${entry['start']}|${entry['end']}|${entry['subject']}';
  }

  /// İşlenen kayıtları kuyruktan düşürür.
  ///
  /// Kuyruk TAZE okunur: biz ağ beklerken native yeni bir aralık eklemiş
  /// olabilir. Eski davranış (anahtarı komple silme) o aralığı da siliyordu →
  /// kullanıcının çalışması kayboluyordu.
  Future<void> _dropProcessedPendingEntries(Set<String> processedKeys) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.reload();
    final raw = prefs.getString(TimerForegroundService.pendingIntervalsKey);
    if (raw == null) return;
    List<dynamic> decoded;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        await prefs.remove(TimerForegroundService.pendingIntervalsKey);
        return;
      }
      decoded = parsed;
    } catch (_) {
      await prefs.remove(TimerForegroundService.pendingIntervalsKey);
      return;
    }
    final remaining = [
      for (final entry in decoded)
        if (entry is! Map || !processedKeys.contains(_pendingEntryKey(entry)))
          entry,
    ];
    if (remaining.isEmpty) {
      await prefs.remove(TimerForegroundService.pendingIntervalsKey);
    } else {
      await prefs.setString(
        TimerForegroundService.pendingIntervalsKey,
        jsonEncode(remaining),
      );
    }
  }
```

> `jsonEncode` tanınmazsa dosyanın üstünde `import 'dart:convert';` zaten var demektir (jsonDecode kullanılıyor). Yoksa ekle.

---

## ADIM B5 — WP-251 testleri

`app/test/features/timer_background_reconcile_test.dart` sonuna ekle:

```dart
  group('WP-251: kuyruk kısmi başarısızlığı (çift yazım / kayıp yok)', () {
    Future<void> fireReconcile3() async {
      const channel = MethodChannel('com.manilmax.online_study_room/timer');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(const MethodCall('reconcile')),
            (_) {},
          );
    }

    test(
      '2. aralık hata alsa da 1. tekrar yazılmaz, 2. sonra tamamlanır',
      () async {
        const idA = '11111111-1111-4111-8111-111111111111';
        const idB = '22222222-2222-4222-8222-222222222222';
        final s1 = DateTime.now().subtract(const Duration(hours: 3));
        final e1 = s1.add(const Duration(minutes: 20));
        final s2 = DateTime.now().subtract(const Duration(hours: 2));
        final e2 = s2.add(const Duration(minutes: 30));

        final flaky = _FlakyStudyRepository()..failIds.add(idB);
        final (container, studyRepo, profile) = await _buildContainer({
          'timer_fg_mode': 'idle',
          'timer_pending_intervals':
              '[{"id":"$idA","start":"${s1.toIso8601String()}",'
              '"end":"${e1.toIso8601String()}","subject":""},'
              '{"id":"$idB","start":"${s2.toIso8601String()}",'
              '"end":"${e2.toIso8601String()}","subject":""}]',
        }, repository: flaky);
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // 1. tur: yalnız A yazıldı, B kuyrukta kaldı.
        var sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(sessions.map((s) => s.id), [idA]);
        final prefs = container.read(sharedPreferencesProvider);
        expect(
          prefs.getString('timer_pending_intervals'),
          contains(idB),
          reason: 'başarısız kayıt kuyrukta kalmalı',
        );
        expect(
          prefs.getString('timer_pending_intervals'),
          isNot(contains(idA)),
          reason: 'başarılı kayıt kuyruktan düşmeli (replay kaynağı buydu)',
        );

        // 2. tur: ağ düzeldi.
        flaky.failIds.clear();
        await fireReconcile3();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(
          sessions.map((s) => s.id).toSet(),
          {idA, idB},
          reason: 'iki oturum da yazılmalı',
        );
        expect(sessions, hasLength(2), reason: 'A ikinci kez yazılmamalı');
        expect(prefs.getString('timer_pending_intervals'), isNull);
      },
    );
  });
```

Ve `_SlowStudyRepository`'nin altına:

```dart
/// WP-251: seçilen id'lerde ağ hatası taklidi.
class _FlakyStudyRepository extends InMemoryStudyRepository {
  final Set<String> failIds = <String>{};

  @override
  Future<void> addSession(StudySession session) async {
    if (failIds.contains(session.id)) {
      throw StateError('network_down');
    }
    await super.addSession(session);
  }
}
```

**Kırmızı–yeşil ispatı:** `_dropProcessedPendingEntries(processedKeys)` çağrısını geçici olarak eski davranışla değiştir (`await prefs.remove(...)` — koşulsuz). Test **düşmeli** (`A` kuyrukta kalmadığı için 2. turda tek oturum yerine kayıp/çift oluşur). Sonra geri al.

**Komutlar + commit:**

```powershell
cd app; flutter analyze
cd app; flutter test
git add app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt app/lib/data/providers/study_providers.dart app/test/features/timer_background_reconcile_test.dart progress.md
git commit -m "WP-251: kuyruk idempotency + kismi silme (cift oturum ve kayip fix)"
```

## 3.2 WP-251 cihaz QA

1. Uçak modunu aç → bildirimden Başlat/Durdur ile 2 oturum üret → uygulamayı aç (kayıt başarısız olacak) → kapat → uçak modunu kapat → uygulamayı aç. **Toplam:** tam 2 oturum, kopya yok.
2. Uygulama açılırken (reconcile sürerken) bildirimden hızlıca Durdur'a bas → o çalışma **kaybolmamalı**.

---

# 4. WP-252 — Native Pomodoro (ExactAlarm) — ⛔ ÖNCE ONAY

> **Bu WP'ye kullanıcı "başla" demeden DOKUNMA.** Ürün davranışını değiştirir (arka planda otomatik mola) ve native tarafta yeni bir yaşam döngüsü açar. Aşağısı, onay gelirse uygulanacak spesifikasyondur.

## 4.0 Problem

`StudyTimerService.kt` hedef süreyi **bilmiyor**: bildirimdeki `Chronometer` yalnız ileri sayıyor (`StudyTimerService.kt:396`), `AlarmManager` yok. Pomodoro'nun 25. dakikayı görüp molaya geçmesi tamamen Dart'taki `Timer.periodic`'e bağlı (`_onTick` → `_completePhase`). Uygulama görevlerden kaydırılınca Flutter motoru yok edilir → geçiş hiç olmaz; bildirim "50:00, 60:00…" diye sayar. Uygulama açılınca Dart aşan süreyi **siler**, hedefi kaydeder ve molaya geçer — yani uyarı 30 dk geç gelir.

## 4.1 Kapsam kararı (net ol)

İki seçenek var; **B seçilmiştir:**

- **A (dar):** yalnız ilk faz geçişi native olur, sonrası uygulama açılmasını bekler. → Yarım çözüm, kullanıcı yine kaçırır.
- **B (tam):** native, faz sürelerini prefs'te tutar ve **her geçişte bir sonraki alarmı kendi kurar**. Uygulama hiç açılmadan pomodoro turu tamamlanır.

## 4.2 Sahiplik kuralı (çift kayıtın tek çaresi — atlanamaz)

Alarm tetiklendiğinde Dart izolatı hâlâ hayatta olabilir. O zaman hem native (kuyruğa aralık) hem Dart (`_completePhase` → `_recordSession`) **aynı aralığı** yazar; ikisinin id'si farklı olduğu için WP-251'in dedupe'u bunu yakalamaz.

**Kural:** Native alarm hedef anından **3 saniye SONRA** kurulur (`kPhaseAlarmGraceMs = 3000`) ve tetiklendiğinde şunları doğrular:

- `KEY_STARTED_AT_MS` hâlâ alarmın kurulduğu değerle **aynı mı**,
- `KEY_PHASE` hâlâ beklenen faz mı,
- `now >= targetEndMs` mi.

Üçü de doğruysa native devralır; biri bile değişmişse Dart zaten halletmiştir → **no-op**. Dart canlıyken tick hedefte (±1 sn) çalışıp prefs'i güncellediği için 3 sn payı yeterlidir.

## 4.3 Dosya listesi

```
YENİ  app/android/.../timer/TimerPhaseAlarm.kt
YENİ  app/android/.../timer/TimerPhaseAlarmReceiver.kt
DEĞİŞ app/android/.../timer/TimerStateStore.kt          (4 yeni anahtar)
DEĞİŞ app/android/.../timer/StudyTimerService.kt        (arm/cancel + ACTION_PHASE_END)
DEĞİŞ app/android/app/src/main/AndroidManifest.xml      (receiver kaydı)
DEĞİŞ app/android/app/src/main/res/values/strings.xml   (+2 string)
DEĞİŞ app/android/app/src/main/res/values-tr/strings.xml(+2 string)
DEĞİŞ app/android/.../MainActivity.kt                   (yeni argümanlar)
DEĞİŞ app/lib/core/background/timer_foreground_service.dart
DEĞİŞ app/lib/data/providers/study_providers.dart       (start çağrılarına parametre)
```

## ADIM C1 — `TimerStateStore.kt`: hedef bilgisi prefs'e

Anahtarlara ekle:

```kotlin
    const val KEY_WORK_MS = "flutter.timer_active_work_ms"
    const val KEY_BREAK_MS = "flutter.timer_active_break_ms"
    const val KEY_CYCLES = "flutter.timer_active_cycles"
    /** Mevcut fazın bitmesi gereken epoch-ms (0 = hedefsiz kronometre). */
    const val KEY_TARGET_END_MS = "flutter.timer_active_target_end_ms"
```

`writeRunning` imzasına ekle: `workMs: Long = 0L, breakMs: Long = 0L, cycles: Int = 1, targetEndMs: Long = 0L` ve `.putLong(...)/.putInt(...)` satırlarını yaz. `writeIdle`'a `.remove(KEY_TARGET_END_MS)` ekle (diğer üçü kalabilir; hedef bilgisi mod ayarıdır).

## ADIM C2 — `TimerPhaseAlarm.kt` (YENİ)

```kotlin
package com.manilmax.online_study_room.timer

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * WP-252: faz sonu (pomodoro/geri sayım) için native exact alarm.
 *
 * Neden: Flutter izolatı uygulama kapatılınca yok edilir; hedefe dayalı modlar
 * o an sessizce ölür. Alarm, uygulama hiç açılmadan mola geçişini yaptırır.
 *
 * Sahiplik: alarm hedeften [GRACE_MS] sonra kurulur. Tetiklendiğinde Dart
 * geçişi zaten yapmışsa (started_at/phase değişmişse) receiver no-op olur.
 */
object TimerPhaseAlarm {
    const val ACTION_PHASE_ALARM = "com.manilmax.online_study_room.timer.PHASE_ALARM"
    const val EXTRA_EXPECT_STARTED_AT_MS = "expectStartedAtMs"
    const val EXTRA_EXPECT_PHASE = "expectPhase"
    const val EXTRA_TARGET_END_MS = "targetEndMs"

    /** Dart canlıysa geçişi kendisi yapsın diye tanınan pay. */
    const val GRACE_MS = 3_000L

    private const val REQUEST_CODE = 7100

    fun arm(
        context: Context,
        startedAtMs: Long,
        phase: String,
        targetEndMs: Long,
    ) {
        if (targetEndMs <= 0L) {
            cancel(context)
            return
        }
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = targetEndMs + GRACE_MS
        val pi = pendingIntent(context, startedAtMs, phase, targetEndMs)
        runCatching {
            val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                am.canScheduleExactAlarms()
            if (canExact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                // İzin yoksa sessizce degrade: gecikmeli ama çalışır.
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        }
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        runCatching { am.cancel(pendingIntent(context, 0L, "", 0L)) }
    }

    private fun pendingIntent(
        context: Context,
        startedAtMs: Long,
        phase: String,
        targetEndMs: Long,
    ): PendingIntent {
        val intent = Intent(context, TimerPhaseAlarmReceiver::class.java).apply {
            action = ACTION_PHASE_ALARM
            putExtra(EXTRA_EXPECT_STARTED_AT_MS, startedAtMs)
            putExtra(EXTRA_EXPECT_PHASE, phase)
            putExtra(EXTRA_TARGET_END_MS, targetEndMs)
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
```

## ADIM C3 — `TimerPhaseAlarmReceiver.kt` (YENİ)

```kotlin
package com.manilmax.online_study_room.timer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * WP-252: faz sonu alarmını yakalar. Exact alarm alıcıları Android 12+'da kısa
 * süreli arka plan başlatma muafiyeti alır → buradan FGS ayağa kaldırılabilir.
 */
class TimerPhaseAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TimerPhaseAlarm.ACTION_PHASE_ALARM) return
        val p = TimerStateStore.prefs(context)

        val expectStartedAt =
            intent.getLongExtra(TimerPhaseAlarm.EXTRA_EXPECT_STARTED_AT_MS, 0L)
        val expectPhase =
            intent.getStringExtra(TimerPhaseAlarm.EXTRA_EXPECT_PHASE).orEmpty()
        val targetEndMs =
            intent.getLongExtra(TimerPhaseAlarm.EXTRA_TARGET_END_MS, 0L)

        // SAHİPLİK KONTROLÜ — üçü de tutmuyorsa Dart zaten devraldı, no-op.
        val currentStartedAt = TimerStateStore.startedAtMs(p)
        val currentPhase = p.getString(TimerStateStore.KEY_PHASE, "work").orEmpty()
        if (currentStartedAt != expectStartedAt) return
        if (currentPhase != expectPhase) return
        if (targetEndMs <= 0L || System.currentTimeMillis() < targetEndMs) return

        runCatching {
            StudyTimerService.sendCommand(
                context,
                StudyTimerService.ACTION_PHASE_END,
            )
        }
    }
}
```

## ADIM C4 — `StudyTimerService.kt`

1. `companion object`'e ekle:
   ```kotlin
   const val ACTION_PHASE_END = "com.manilmax.online_study_room.timer.PHASE_END"
   const val EXTRA_WORK_MS = "workMs"
   const val EXTRA_BREAK_MS = "breakMs"
   const val EXTRA_CYCLES = "cycles"
   const val EXTRA_TARGET_END_MS = "targetEndMs"
   private const val PHASE_NOTIFICATION_ID = 7041
   private const val PHASE_CHANNEL_ID = "study_timer_phase"
   ```
   `sendCommand` imzasına `workMs/breakMs/cycles/targetEndMs` opsiyonel parametreleri ve `putExtra` satırlarını ekle.

2. `onStartCommand` `when` bloğuna ekle: `ACTION_PHASE_END -> handlePhaseEnd()`.

3. `handleStart`: `writeRunning`'e yeni alanları geçir, ardından
   ```kotlin
   TimerPhaseAlarm.arm(this, startedAtMs, phase, targetEndMs)
   ```

4. `handleStop`: `TimerStateStore.writeIdle(p)` satırının hemen ÜSTÜNE `TimerPhaseAlarm.cancel(this)`.

5. `handleStartBreak` / `handleEndBreak`: yeni faz için `targetEndMs` hesapla
   (`nowMs + breakMs` / `nowMs + workMs`), `writeRunning`'e geçir, `TimerPhaseAlarm.arm(...)` çağır.

6. Yeni metod:
   ```kotlin
   /** WP-252: faz süresi doldu, Dart devralmadı → geçişi native yap. */
   private fun handlePhaseEnd() {
       val p = prefs()
       val phase = p.getString(TimerStateStore.KEY_PHASE, "work") ?: "work"
       val mode = p.getString(TimerStateStore.KEY_MODE, "stopwatch") ?: "stopwatch"
       val cycle = p.getInt(TimerStateStore.KEY_CYCLE, 1)
       val cycles = p.getInt(TimerStateStore.KEY_CYCLES, 1)

       if (phase == "rest") {
           handleEndBreak()
           notifyPhaseEnd(isBreakStarting = false)
           return
       }
       val lastCycle = mode != "pomodoro" || cycle >= cycles
       if (lastCycle) {
           handleStop(recordInterval = true)
           notifyPhaseEnd(isBreakStarting = false)
       } else {
           handleStartBreak()
           notifyPhaseEnd(isBreakStarting = true)
       }
   }
   ```
   `notifyPhaseEnd` ayrı bir kanal (`PHASE_CHANNEL_ID`, `IMPORTANCE_HIGH`, varsayılan ses + titreşim) üzerinden **tek atımlık** bildirim atar; başlık `timer_phase_break_title` / `timer_phase_done_title`.

## ADIM C5 — Manifest

`</application>` üstüne:

```xml
        <!-- WP-252: pomodoro faz sonu exact alarm alıcısı (explicit intent). -->
        <receiver
            android:name=".timer.TimerPhaseAlarmReceiver"
            android:exported="false" />
```

İzin eklemeye **gerek yok** — `SCHEDULE_EXACT_ALARM` ve `USE_EXACT_ALARM` zaten manifestte.

## ADIM C6 — Strings (iki dosyaya da)

`values/strings.xml`:
```xml
    <string name="timer_phase_break_title">Work done — break time</string>
    <string name="timer_phase_done_title">Session complete</string>
```
`values-tr/strings.xml`:
```xml
    <string name="timer_phase_break_title">Çalışma bitti — mola zamanı</string>
    <string name="timer_phase_done_title">Oturum tamamlandı</string>
```

## ADIM C7 — Dart tarafı

`timer_foreground_service.dart` → `start()` imzasına `int workMs, int breakMs, int cycles, int targetEndMs` ekle ve `invokeMethod` map'ine koy. `MainActivity.kt` `startTimer` dalında bunları oku ve `sendCommand`'a geçir.

Sonra **tüm çağrı yerlerini** bul ve güncelle:

```powershell
cd app; Select-String -Path lib -Pattern "TimerForegroundService.start\(" -Recurse
```

Çıkan **her** çağrıya şunları ekle (hedefsiz kronometrede `targetEndMs: 0`):

```dart
        workMs: state.workMinutes * 60 * 1000,
        breakMs: state.breakMinutes * 60 * 1000,
        cycles: state.cycles,
        targetEndMs: state.phaseTargetSeconds == null
            ? 0
            : (state.startedAt ?? DateTime.now())
                    .millisecondsSinceEpoch +
                state.phaseTargetSeconds! * 1000,
```

## 4.4 WP-252 DoD ve cihaz QA

- [ ] 1 dk çalışma / 1 dk mola / 2 döngü pomodoro başlat → uygulamayı **görevlerden kaydır** → telefon kilitli beklet. Her faz sonunda bildirim + ses gelmeli, bildirimdeki sayaç sıfırlanıp mola saymalı.
- [ ] Tur bitiminde sayaç durmalı; uygulamayı açınca **tam 2 dk** çalışma kaydı olmalı (fazla/eksik yok, **çift kayıt yok**).
- [ ] Uygulama AÇIKKEN aynı senaryo: geçişler Dart tarafından yapılmalı, native alarm no-op olmalı → yine tek kayıt.
- [ ] Ayarlar'dan "Alarmlar ve hatırlatıcılar" iznini kapat → uygulama çökmemeli, geçiş gecikmeli de olsa olmalı.
- [ ] Kronometre modunda alarm **hiç kurulmamalı** (hedef yok).

## 4.5 WP-252 rollback

`TimerPhaseAlarm.arm(...)` çağrılarını `TimerPhaseAlarm.cancel(this)` ile değiştirmek davranışı eski haline (pasif FGS) döndürür; receiver ve prefs anahtarları zararsız kalır.

---

# 5. WP-253 — UX Düzeltmeleri (küçük, bağımsız)

## 5.1 Sıralamadaki ateş ikonu — ⚠️ ürün kararı gerekiyor

**Kodda doğrulanan gerçek:** Sıralamadaki ateş ikonu **hedef serisi değildir**. `class_stats_view.dart:120-122` `studyStreak(...)` kullanır = "üst üste **en az 1 sn** çalışılan gün". Sayaç kartındaki ateş ise `currentStreak(sessions, goalSeconds)` = **hedef tutturma serisi** (`study_providers.dart:112-117`). Grup tarafında hedef serisi kullanılamaz çünkü herkesin günlük hedefi bilinmiyor — gerekçe kodda yazılı (`study_stats.dart:245-246`).

Yani sorun "yanlış metrik" değil, **tek ikonun iki farklı anlamı taşıması**.

Kullanıcıya şu iki seçeneği sor, **cevap gelmeden dokunma:**

- **Seçenek 1 (varsayılan öneri — `progress.md`'deki niyet bu):** Sıralama satırından seri rozetini tamamen kaldır. `class_stats_view.dart` içindeki `_LeaderboardRow`'un `if (streak > 0) ...[ ... ]` bloğunu ve artık kullanılmayan `streak` parametresi + `streaks` haritasını sil.
- **Seçenek 2:** Rozeti bırak ama ayırt et: ikon `Icons.local_fire_department` yerine `Icons.event_available`, yanına `Tooltip(message: 'Üst üste çalışılan gün')`.

> **"Madalya kullan" önerisini uygulama** — satırda zaten sıra madalyası (🥇🥈🥉) ve alpha kurdu (🐺) var; üçüncü bir madalya karışıklığı artırır.

## 5.2 Manuel süre eklemede çakışma koruması

**Doğru kural (geniş yasak DEĞİL):** Geçmiş gün seçilirse `end = 23:59:59` olduğu için canlı oturumla çakışma **imkânsızdır** — o akışı engellemek meşru kullanımı kırar. Yalnız **bugün + sayaç çalışıyor** kombinasyonu garanti çakışmadır.

**Dosya:** `app/lib/features/profile/widgets/manual_session_dialog.dart`

`addManualSessionFlow` içinde, `showManualSessionDialog` sonucu alındıktan **sonra**, `manualSessionRange` çağrısından **önce**:

```dart
  // WP-253: bugüne manuel ekleme, çalışan sayacın aralığıyla fiziksel olarak
  // çakışır (end = şimdi, start = şimdi - süre). Geçmiş günlerde çakışma
  // imkânsız olduğu için o akış serbest bırakılır.
  final timer = ref.read(studyTimerProvider);
  final istToday = dayOf(DateTime.now());
  if (timer.isRunning && isSameDay(dayOf(result.date), istToday)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sayaç çalışırken bugüne manuel süre eklenemez; '
          'önce sayacı durdur.',
        ),
      ),
    );
    return;
  }
```

Guard **butona değil bu akışa** konur — `addManualSessionFlow` iki ekrandan çağrılıyor (`study_timer_card.dart:329` ve `session_history_screen.dart`), tek butonu kapatmak deliği kapatmaz.

**Test** (`app/test/features/manual_session_range_test.dart` içine):
- Geçmiş gün + sayaç çalışıyor → oturum yazılır.
- Bugün + sayaç çalışıyor → oturum **yazılmaz**.

---

# 6. `progress.md` GÜNCELLEMELERİ (hazır metin)

## 6.1 Lane claim (işe başlamadan önce)

`### Claude Lane` bloğunu **kendi ajan adınla** güncelle:

```
### <Ajan> Lane
- **Durum:** [~] Aktif
- **Faz/WP:** WP-250 (sayaç durdurma çift-sayımı — P0) → WP-251 (kuyruk idempotency)
- **Aşama:** Geliştiriliyor
- **SAHİP yollar:** `app/lib/core/stats/study_stats.dart`, `app/lib/data/providers/study_providers.dart`, `app/lib/features/classroom/widgets/study_timer_card.dart`, `app/lib/features/classroom/widgets/focus_timer_screen.dart`, `app/android/.../timer/TimerStateStore.kt`, ilgili testler, `progress.md`
- **Ortak/riskli yüzey:** yok (manifest/migration/tema dışı)
- **Dal:** `main`
- **Başlangıç:** <tarih> (Europe/Istanbul)
- **Son güncelleme:** <tarih>
- **Not:** Plan: `docs/WP-250-253-SAYAC-DUZELTME-PLANI.md`
```

## 6.2 Numara defterini düzelt (ZORUNLU — şu an tutarsız)

`progress.md` satır 23'te "Son WP numarası: **248** … Sıradaki boş numara WP-249" yazıyor. **Yanlış:** WP-249 `94947fc` commit'inde (stable release preparation, v42) kullanıldı. Ayrıca commit'lenmemiş bir satır WP-249'u sıralama işine veriyor — o satırı **WP-253'e taşı**.

- Satır 23'ü şöyle güncelle: `**Son WP numarası:** **249** … **Sıradaki boş numara WP-250.**`
- Tablodaki `| WP-249 | [ ] Bekliyor | Grup Sıralamasında Seriyi Gizleme…` satırını `| WP-253 | …` yap.

## 6.3 Yeni WP kartları (tabloya ekle)

```
| WP-250 | [ ] Planlandı | 🔴 P0: Durdurma çift-sayımı — DB yazımı (RTT) sırasında canlı süre ikinci kez sayılıyor; oturum boyu kadar şişme + gün boyu kilitlenme | `docs/WP-250-253-SAYAC-DUZELTME-PLANI.md` · WP-239'un tamamlanmamış kısmı |
| WP-251 | [ ] Planlandı | 🔴 P1: Native aralık kuyruğu — kısmi hatada başarılı kayıtlar tekrar yazılıyor (çift oturum) + toptan silme yeni aralığı kaybediyor | idempotent UUID + kısmi silme |
| WP-252 | [ ] Onay bekliyor | Pomodoro arka planda ölüyor — native ExactAlarm + otomatik faz geçişi | ürün onayı şart; sahiplik kuralı (3 sn pay) zorunlu |
| WP-253 | [ ] Planlandı | UX: sıralamadaki seri rozeti (iki farklı metrik aynı ikon) + manuel eklemede bugün/çakışma koruması | ikon kararı ürün sahibinde |
```

---

# 7. SIK YAPILAN HATALAR — BUNLARI YAPMA

| ❌ Yapma | Neden | ✅ Bunu yap |
|---|---|---|
| `isStopping`'i `_reconcile`'ın başında **koşulsuz** kaldırmak | Reconcile uygulama önplandayken her Başlat/Durdur broadcast'inde çalışır; yeni başlamış sayaç 0 sn görünür | Yalnız A7.1'deki `nativeIdleAtEntry` koşuluyla |
| Canlı süreyi saniyede bir yeniden hesaplayan bir **provider** yazmak | Tüm dinleyiciler saniyede bir rebuild olur; kart bunu bilerek yerel `setState` ile yapıyor (`study_timer_card.dart:56`) | Saf fonksiyon + widget'ın kendi ticker'ı |
| `goal_card.dart`'ı da "birleştirmek" | Bugün canlı süre göstermiyor; değiştirmek **ürün davranışı** değişikliğidir | Dokunma, kullanıcıya sor |
| `elapsed`/`displaySeconds`'a `isStopping` guard'ı koymak | Büyük saat bir an 00:00'a düşer | Yalnız `liveWork`'e koy |
| Kuyruk id'sini `"native-123"` gibi serbest metin yapmak | `study_sessions.id` uuid sütunu; insert patlar | `UUID.randomUUID().toString()` |
| Testleri "geçsin diye" gevşetmek (`closeTo` payını 600 yapmak vb.) | Test bug'ı yakalamaz hale gelir — WP-239 böyle kaçtı | Kırmızı-yeşil ispatını çalıştır |
| `git add -A` | AGENTS.md §1.5 yasak; başka lane'in dosyasını commit'lersin | Açık yollarla `git add` |
| `flutter analyze --dart-define-from-file=env.json` | analyze bu bayrağı kabul etmez | Bayraksız çalıştır |
| WP-252'yi onay almadan başlatmak | Ürün davranışı değişikliği | Önce sor |

---

# 8. ÖZET İŞ SIRASI (kopyala-yapıştır kontrol listesi)

```
[ ] 0. progress.md Aktif Çalışma Kaydı'nı oku → çakışma var mı? Varsa DUR, uyar.
[ ] 1. Lane claim yaz (§6.1) + numara defterini düzelt (§6.2) + WP kartları (§6.3)
[ ] 2. WP-250 A1 → A9 (kod)
[ ] 3. WP-250 A10 (3 test dosyası)
[ ] 4. WP-250 A11 kırmızı-yeşil ispatı — çıktıyı yanıtına yaz
[ ] 5. flutter analyze (0) + flutter test (yeşil)
[ ] 6. WP-250 commit
[ ] 7. WP-251 B1 → B5
[ ] 8. B5 kırmızı-yeşil ispatı
[ ] 9. flutter analyze + flutter test
[ ] 10. WP-251 commit
[ ] 11. WP-253 için ürün kararını sor (§5.1), cevap gelince uygula + commit
[ ] 12. WP-252 için onay iste — onay yoksa DURDUR
[ ] 13. Kullanıcıya cihaz QA listesini ver (§2.4, §3.2, §4.4)
```

**Kanıt etiketi kuralı (AGENTS.md §0):** Yanıtında her iddia için `Kodda doğrulandı` / `Cihazda doğrulanmalı` / `Ürün kararı gerekiyor` etiketlerinden birini kullan. Bu plandaki tüm kod analizi `Kodda doğrulandı`; tüm QA maddeleri `Cihazda doğrulanmalı`.
