# OPTIMIZATIONS.md

> Salt-okuma optimizasyon denetimi (Flutter istemci + Supabase). Hiçbir değişiklik
> uygulanmadı. Bulgular ROI'ye göre sıralı. Ölçümle kanıtlanamayan yerler **"likely"**
> olarak işaretlendi ve neyin ölçülmesi gerektiği belirtildi.
> Kapsam: `app/lib` (veri katmanı, provider'lar, stats, canlı ekranlar) + APK çıktısı.

---

## 0) Uygulanma Durumu (sonradan eklendi)

| Bulgu | Durum |
|---|---|
| F2, F3, F5, F7 | ✅ Uygulandı (commit'ler: SecondTicker + map/dedup; dailyTotals memoize) |
| F6a (indirme timeout/iptal) | ✅ Uygulandı |
| **F1 (sunucu agregasyonu)** | ✅ Uygulandı — `group_daily_totals` RPC (migration `0007`) + realtime sinyalli `watchGroupDailyStats`; grup geneli tüm tüketiciler agregaya bağlandı. ⚠️ **Migration Supabase'e uygulanmalı ve canlı doğrulanmalı.** Gün sınırı `Europe/Istanbul`. Rollback: tüketicileri `groupSessionsProvider`'a geri al. |
| F4 (profil join), F6b (split-APK) | ⏸️ Yapılmadı (kullanıcı kapsam dışı bıraktı) |

## 1) Optimization Summary

**Mevcut durum:** Mimari temiz (saf stats fonksiyonları, repository soyutlaması). Ciddi
bir hata yok; ancak birkaç desen **veri büyüdükçe** doğrusalın üstünde maliyet üretiyor.
Şu anki küçük N'de (kişisel proje, küçük sınıflar) sorun hissedilmez — asıl risk ölçeklenme.

**En yüksek etkili 3 iyileştirme:**
1. **Sınırsız oturum stream'leri** (`watchGroupSessions` / `watchUserSessions`) — tüm geçmiş her tick'te realtime akıyor. Zaman penceresi + sunucu tarafı agregasyon.
2. **Saniyelik `setState(() {})` ile tüm liste rebuild** — canlı üye/leaderboard her saniye yeniden sıralanıp baştan çiziliyor. Tick'i en küçük widget'a (geçen-süre metni) indirgemek.
3. **`build()` içinde tekrarlı `dailyTotals` ve tam-liste taramaları** — stats ekranı her rebuild'de aynı O(n) haritayı defalarca kuruyor. Tek sefer hesaplayıp paylaş / memoize.

**Değişmezse en büyük risk:** Sınıf birkaç aylık veri biriktirince canlı ekran her
oturum eklemesinde tüm geçmişi indirip yeniden işler → artan ağ/DB maliyeti, bellek
şişmesi ve düşük cihazlarda saniyelik jank/batarya tüketimi.

---

## 2) Findings (Prioritized)

### F1 — Sınırsız grup oturum stream'i (tüm geçmiş, realtime)
- **Category:** DB / Network / Memory
- **Severity:** High (veri büyüdükçe Critical'e yaklaşır)
- **Impact:** Ağ baytları, DB yükü, istemci belleği, leaderboard/stats latency
- **Evidence:** [supabase_study_repository.dart:41-48](app/lib/data/repositories/supabase/supabase_study_repository.dart) `watchGroupSessions` → `.stream(primaryKey:['id']).eq('group_id', …).order('start_time')` filtresiz tüm geçmişi çeker; bunu [study_providers.dart:35](app/lib/data/providers/study_providers.dart) `groupSessionsProvider` besler ve `groupTodaySecondsProvider`, leaderboard, sınıf istatistikleri tümü bu tek listeden türetilir.
- **Why it's inefficient:** Supabase realtime `.stream()` ilgili satır kümesini istemcide tutar ve değişimde günceller; sınıftaki **her üyenin tüm zamanların her oturumu** istemciye iniyor. N (oturum) ayda lineer büyür; "bugünün toplamı" gibi türevler bile tüm geçmiş üzerinde yeniden hesaplanır.
- **Recommended fix:**
  - Canlı/leaderboard görünümü için stream'i pencerele: `.gte('start_time', <son 60-90 gün>)`.
  - "Tüm zamanlar" gereken yerler için ayrı, **on-demand** sorgu veya Postgres **view/RPC** ile sunucu tarafı agregasyon (`group_id,user_id → sum(duration)` ve `group_id,day → sum`). Böylece istemciye ham satır yerine özet iner.
  - `study_sessions(group_id, start_time)` ve `(user_id, start_time)` bileşik index'leri.
- **Tradeoffs / Risks:** Pencereleme, "tüm zamanlar leaderboard"ı bölmeyi gerektirir; agregasyon RPC bakım yükü ekler. Realtime + agregasyon birlikte tasarım ister.
- **Expected impact:** Büyük veride payload ve istemci CPU'sunda **%70–95** azalma (geçmiş boyutuna bağlı); küçük veride nötr.
- **Removal Safety:** Needs Verification (RLS ve realtime davranışı doğrulanmalı)
- **Reuse Scope:** service-wide

### F2 — Saniyelik `setState(() {})` tüm üye listesini yeniden sıralayıp çiziyor
- **Category:** Frontend / CPU
- **Severity:** High
- **Impact:** Çerçeve süresi (jank), batarya, CPU — ekran açıkken sürekli 1Hz
- **Evidence:** [classroom_screen.dart:190-192](app/lib/features/classroom/classroom_screen.dart) `_LiveMembers` her saniye `setState(() {})`; ardından `build` içinde [classroom_screen.dart:215](app/lib/features/classroom/classroom_screen.dart) `[...members]..sort(...)` + tüm `_MemberTile`'lar yeniden kurulur. Aynı desen [active_members_card.dart:33-35](app/lib/features/home/widgets/active_members_card.dart) (her saniye `presence.where(...).toList()..sort(...)`).
- **Why it's inefficient:** Saniyede değişen tek şey "ne kadar süredir çalışıyor" metni. Oysa her tick'te tüm liste kopyalanıp sıralanıyor, presence/maps yeniden kuruluyor ve tüm satırlar (avatar dâhil) yeniden inşa ediliyor. Üye sayısı arttıkça 1Hz maliyeti lineer büyür.
- **Recommended fix:** Tick'i izole et: sadece geçen-süre gösteren küçük bir `_ElapsedText` widget'ı kendi 1sn timer'ına sahip olsun (ya da `ValueListenableBuilder`/`AnimatedBuilder`). Liste sıralaması ve tile inşası yalnızca presence/members **gerçekten değiştiğinde** (provider tetiklediğinde) yapılsın. Satırlara `const`/`RepaintBoundary` ekle.
- **Tradeoffs / Risks:** Küçük refactor; sıralama ölçütü "süreye göre" ise sıranın saniyelik güncellenmemesi kabul edilmeli (genelde fark edilmez).
- **Expected impact:** 1Hz rebuild işini üye başına tek `Text` güncellemesine indirir → canlı ekran CPU'sunda **~%80+** azalma.
- **Removal Safety:** Safe
- **Reuse Scope:** module (classroom + home)

### F3 — `build()` içinde tekrar tekrar `dailyTotals` ve tam-liste taramaları
- **Category:** CPU / Algorithm
- **Severity:** Medium
- **Impact:** Stats ekranı rebuild latency'si; gereksiz tekrar hesap
- **Evidence:** [personal_stats_view.dart:31-49](app/lib/features/stats/widgets/personal_stats_view.dart) `build` içinde `secondsOnDay`, `inRange`×4+, `dailyAverageSeconds`, `weekdayWeekendSplit`; alt widget'lar bağımsızca yeniden tarıyor: `lastNDays`→`dailyTotals` ([study_stats.dart:67](app/lib/core/stats/study_stats.dart)), `StudyRecords`→`longestStudyStreak`→`dailyTotals` ([study_stats.dart:192](app/lib/core/stats/study_stats.dart)), `hourlyTotals`, `weekdayHourTotals`, `subjectBreakdown`, `StudyHeatmap`. `dailyTotals(sessions)` aynı rebuild'de **birden çok kez** sıfırdan kuruluyor.
- **Why it's inefficient:** Her fonksiyon O(n) ama hiçbiri memoize değil; `groupSessionsProvider`/`userSessionsProvider` her tick'te yeni liste yayınladığında **veya** herhangi bir üst rebuild olduğunda tüm grafik hesapları yeniden koşar. `inRange(...).toList()` ([:152](app/lib/features/stats/widgets/personal_stats_view.dart)) ek kopya üretir.
- **Recommended fix:** `dailyTotals`'ı bir kez hesaplayıp aşağı geçir; ya da oturum listesine bağlı türev bir provider'da bir "StatsBundle" (dailyTotals, hourly, weekdayHour, subjectBreakdown, records) üret — veri değiştiğinde bir kez hesaplanır, rebuild'lerde yeniden kullanılır. Saf fonksiyonları `DateTime` anahtarlı map yerine `int` epoch-day anahtarıyla kurmak hash maliyetini de düşürür (mikro).
- **Tradeoffs / Risks:** Hafif yeniden yapı; bundle invalidasyonu sessions referansına bağlanmalı.
- **Expected impact:** Stats sekmesi rebuild CPU'sunda **%40–60** (veri arttıkça artar).
- **Removal Safety:** Likely Safe
- **Reuse Scope:** module (stats)

### F4 — Grup repo'da iki-adımlı "stream + her tick'te yeniden select" (N+1 benzeri)
- **Category:** Network / DB
- **Severity:** Medium
- **Impact:** Üyelik değişiminde fazladan tur (RTT); ayrıca profil güncellemeleri yansımaz
- **Evidence:** [supabase_group_repository.dart:106-119](app/lib/data/repositories/supabase/supabase_group_repository.dart) `watchMembers`: `group_members` stream'i her emisyonda `profiles.select().inFilter('id', ids)` ile ayrı sorgu. Aynı desen `watchUserGroups` ([:89-104](app/lib/data/repositories/supabase/supabase_group_repository.dart)).
- **Why it's inefficient:** Her stream tick'i ek bir round-trip doğurur; `profiles` tablosu izlenmediği için isim/avatar değişiklikleri canlı yansımaz (doğruluk/tazelik açığı). `asyncMap` ardışık çalışır (paralel değil).
- **Recommended fix:** Sunucu tarafı `view`/RPC ile join (üye + profil tek sorgu) ya da profilleri istemcide cache'leyip yalnız **eksik id'leri** çek. Profil tazeliği gerekiyorsa `profiles`'ı da stream'e dâhil et.
- **Tradeoffs / Risks:** View/RPC bakım yükü; cache invalidasyonu. Küçük gruplarda kazanç sınırlı.
- **Expected impact:** Üyelik tick'i başına 1 RTT eksi; orta.
- **Removal Safety:** Needs Verification
- **Reuse Scope:** module (group)

### F5 — Döngü içinde lineer arama (`subjectFor` / `memberFor`)
- **Category:** Algorithm / CPU
- **Severity:** Low
- **Impact:** O(slices×subjects) / O(active×members) — küçük ama gereksiz
- **Evidence:** [personal_stats_view.dart:518-535](app/lib/features/stats/widgets/personal_stats_view.dart) `subjectFor` her slice için listeyi tarar; [active_members_card.dart:62-66](app/lib/features/home/widgets/active_members_card.dart) `memberFor` her aktif için.
- **Why it's inefficient:** Liste araması döngü içinde; map ile O(1) yapılabilir.
- **Recommended fix:** Döngü öncesi `{for (final s in subjects) s.id: s}` / `{for (final m in members) m.id: m}` map'i kur.
- **Tradeoffs / Risks:** Yok.
- **Expected impact:** İhmal edilebilir ama bedava; çok ders/üyede fark eder.
- **Removal Safety:** Safe
- **Reuse Scope:** local file

### F6 — Güncelleme indirmesinde timeout/iptal/yeniden-deneme yok (universal APK)
- **Category:** Reliability / Cost / Network
- **Severity:** Medium
- **Impact:** Takılı indirme UX'i; gereksiz büyük indirme
- **Evidence:** [updater_dialog.dart](app/lib/features/updater/updater_dialog.dart) `Dio().download(...)` `receiveTimeout`/`CancelToken` olmadan; her çağrıda yeni `Dio()`. Ayrıca CI `flutter build apk --release` **universal APK** üretiyor (gözlemlenen **58.6MB**; tüm ABI'ler tek dosyada).
- **Why it's inefficient:** Yavaş/kopuk bağlantıda ilerleme çubuğu sonsuz takılabilir, kullanıcı iptal edemez. Universal APK, cihazın kullanmadığı ABI'leri de indirtir → güncelleme başına ~2× gereksiz bayt (kendi-güncelleme modelinde doğrudan maliyet).
- **Recommended fix:** `receiveTimeout` + `CancelToken` + "İptal" düğmesi; bozuk dosyada otomatik tek retry. Boyut için `--split-per-abi` (arm64 ~%50 küçük) — ancak tek-link indirme modeliyle uyumu için indirme linkinde ABI seçimini çözmek gerekir; ya da `appbundle` Play Store dışı dağıtımda işe yaramaz, bu yüzden split-per-abi + servis tarafında `arm64-v8a` linkini seçmek en uygunu.
- **Tradeoffs / Risks:** Split APK, "latest/download/app-release.apk" sabit linkini ABI-bilinçli yapmaya zorlar; updater_service asset seçimini cihaz ABI'sine göre güncellemeli.
- **Expected impact:** Güncelleme indirme boyutunda **~%50** (arm64 cihazlar); güvenilirlikte belirgin UX iyileşmesi.
- **Removal Safety:** Needs Verification (ABI'ye göre asset eşleme tasarlanmalı)
- **Reuse Scope:** module (updater + CI)

### F7 — Çoğaltılmış yardımcı: `_isSameDay`
- **Category:** Reuse / Maintainability
- **Severity:** Low
- **Impact:** Bakım/drift riski (mantık iki yerde)
- **Evidence:** [study_providers.dart:41-42](app/lib/data/providers/study_providers.dart) yerel `_isSameDay`, [study_stats.dart:11-12](app/lib/core/stats/study_stats.dart) `isSameDay` ile birebir aynı.
- **Why it's inefficient:** Kopya mantık; biri değişirse sapma.
- **Recommended fix:** `study_stats.dart`'taki `isSameDay`'i kullan, yereli sil. → **Reuse Opportunity**
- **Tradeoffs / Risks:** Yok.
- **Expected impact:** Sadece bakım.
- **Removal Safety:** Safe
- **Reuse Scope:** module

---

## 3) Quick Wins (Do First)

| # | Değişiklik | Süre | Etki |
|---|---|---|---|
| F5 | Döngü öncesi id→nesne map'i (subjectFor/memberFor) | ~10 dk | Küçük ama bedava |
| F7 | `_isSameDay` kopyasını sil, `isSameDay` kullan | ~5 dk | Bakım |
| F2 | 1Hz tick'i `_ElapsedText`'e izole et | ~1-2 sa | **Yüksek** (canlı ekran CPU/batarya) |
| F6a | dio `receiveTimeout` + `CancelToken` + İptal düğmesi | ~30 dk | Güvenilirlik |

## 4) Deeper Optimizations (Do Next)

- **F1:** Oturum stream'lerini pencereleme + Postgres view/RPC ile sunucu-tarafı agregasyon; bileşik index'ler. (Mimari; en yüksek ölçek getirisi.)
- **F3:** Veriye bağlı türev provider'da tek "StatsBundle" hesabı; saf fonksiyonlarda `int` epoch-day anahtarı.
- **F4:** Üye+profil join'ini view/RPC'ye taşı veya profil cache'i.
- **F6b:** `--split-per-abi` + updater_service'te ABI-bilinçli asset seçimi (güncelleme boyutu ~%50).

## 5) Validation Plan

- **Profiling:** Flutter DevTools → Performance; classroom/home ekranı açıkken 10 sn kaydet. Hedef: 1Hz rebuild'lerde "raster + UI thread" süresinin düşmesi, `_LiveMembers.build` sayısının sabit kalması (sadece `_ElapsedText` rebuild).
- **Rebuild sayacı:** `debugProfileBuildsEnabled` veya geçici `print`/`Timeline` ile F2 öncesi/sonrası `build` çağrısı sayısını karşılaştır.
- **Veri ölçeği testi:** `study_sessions`'a sentetik 5k/20k satır seed'leyip (a) stream payload boyutu (DevTools Network), (b) `groupSessionsProvider` ilk-emisyon süresi, (c) stats sekmesi açılış süresini F1/F3 öncesi-sonrası ölç.
- **Metics karşılaştırma:** indirilen bayt (Supabase logs / network), istemci bellek (DevTools Memory), stats build mikrosaniyesi (`Stopwatch` ile `dailyTotals` çağrı sayısı).
- **Doğruluk korunumu:** Mevcut `flutter test` (bildirilen 18/18) yeşil kalmalı; özellikle `study_stats` testleri F3 refactor sonrası değişmemeli. Leaderboard/streak değerleri F1 pencereleme sonrası "tüm zamanlar" vs "pencere" ayrımıyla beklenen sonucu vermeli (yeni test ekle).

## 6) Optimized Code / Patch (öneri taslakları — UYGULANMADI)

**F5 — map ile lookup:**
```dart
// önce: subjectFor her slice'ta listeyi tarar
final subjectById = {for (final s in subjects) s.id: s};
Subject? subjectFor(String? id) => id == null ? null : subjectById[id];
```

**F2 — tick'i izole et (kavramsal):**
```dart
// _LiveMembers artık 1sn setState YAPMAZ; sıralama yalnız provider değişince.
// Her satırda geçen süreyi gösteren küçük, kendi timer'lı widget:
class _ElapsedText extends StatefulWidget {
  const _ElapsedText({required this.startedAt});
  final DateTime startedAt;
  // initState'te Timer.periodic(1s) -> sadece bu Text setState olur
}
```

**F1 — pencereli stream (repository):**
```dart
Stream<List<StudySession>> watchGroupSessions(String groupId) {
  final since = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
  return _client.from('study_sessions')
    .stream(primaryKey: ['id']).eq('group_id', groupId)
    .gte('start_time', since)        // ← pencere
    .order('start_time')
    .map((rows) => rows.map(StudySession.fromMap).toList());
}
// "tüm zamanlar" toplamları için ayrı RPC: rpc('group_totals', {gid}) → userId,sum
```

**F6a — indirme güvenilirliği:**
```dart
final cancel = CancelToken();
await dio.download(url, savePath, cancelToken: cancel,
  options: Options(receiveTimeout: const Duration(minutes: 3)),
  onReceiveProgress: ...);
// UI: "İptal" -> cancel.cancel();
```

---

### Notlar / Varsayımlar
- Üretim verisi ölçeği gözlemlenmedi; F1/F3 etkileri **veri büyüklüğüne bağlı** ("likely"). Küçük N'de fark hissedilmez — denetim ölçeklenme riskine odaklıdır.
- Mikro-optimizasyonlardan (örn. `DateTime`→`int` anahtar) yalnız F3 refactor'üne dâhil edilebilecek olanlar önerildi; tek başına yapılması önerilmez.
- RLS, doğru index'ler ve realtime yayın boyutu sunucu tarafında doğrulanmalı (kod tek başına kanıtlamaz).
