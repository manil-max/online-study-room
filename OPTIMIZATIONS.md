# OPTIMIZATIONS.md

Kapsam: `online-study-room` tam optimizasyon denetimi (Flutter uygulaması `app/` + Supabase arka ucu `supabase/migrations/`). Yalnızca kod analizi; çalışma zamanı profillenmedi. Koddan kanıtlanamayan iddialar **olası** etiketiyle ve neyin ölçüleceğiyle birlikte verildi.

> Bu turda hiçbir şey değiştirilmedi — yalnızca bulgular (optimizasyon-prompt kuralı gereği). Önceki `OPTIMIZATIONS.md` migration yorumlarında "F1" olarak anılıyor (`group_daily_totals` sunucu-taraflı agregasyonu). Çakışmamak için yeni bulgu kimlikleri **N1+** olarak numaralandırıldı.

---

## 1) Optimizasyon Özeti

Mevcut durum: temiz mimari (repository deseni, Riverpod, in-memory ↔ Supabase geçişi). Sunucu-taraflı günlük agregasyon (`group_daily_totals`) en büyük veri-hacmi sorununu zaten çözmüş. Kalan sorunlar: **realtime fan-out / yeniden agregasyon**, **sınırsız stream'ler** ve tüm oturum listesi üzerinde **gereksiz istemci-taraflı yeniden hesap**.

En yüksek etkili 3 iyileştirme:
1. **`watchGroupDailyStats`'ı debounce et + daralt** — `study_sessions` tablosundaki *herhangi* bir satır değişimi (tablo geneli, filtresiz), abone olan her istemci için tüm grup agregasyon RPC'sini yeniden çalıştırıyor. Eşzamanlı kullanıcı arttıkça asıl ölçeklenme uçurumu bu (DB CPU + ağ).
2. **`watchUserSessions`'ı sınırla** — kullanıcının tüm oturum geçmişini, sınırsız, sıralı, her değişimde akıtıyor. Bellek + transfer + sonraki yeniden hesaplar sınırsız büyür.
3. **Tek `dailyTotals` hesabını paylaş** — `currentStreakProvider`, `todayRecordedSecondsProvider` ve istatistik widget'ları aynı oturum listesini bağımsız olarak tekrar tarıyor (her rebuild'de birden çok O(n) geçiş); tek bir memoize edilmiş haritadan türetmek yerine.

Değişmezse en büyük risk: birkaç kullanıcıyla sorunsuz çalışır, ama tablo-geneli realtime yeniden agregasyon maliyeti **(aktif kullanıcı × gün başına oturum × abone sayısı)** ile ölçeklenir — gerçek sınıf yükünde tam RPC yeniden-çalıştırmalarından oluşan bir "thundering herd".

---

## 2) Bulgular (Öncelik Sırasıyla)

### N1 — Tablo-geneli realtime tetiği tüm RPC'yi yeniden agregasyona zorluyor
- **Kategori:** DB / Network / Caching
- **Önem:** High
- **Etki:** DB CPU, gecikme, çıkış trafiği, pil; ölçeklenme tavanı
- **Kanıt:** `supabase_study_repository.dart:63-96` (`watchGroupDailyStats`). Realtime kanalı `study_sessions`'a **filtresiz** abone (`event: all`, tüm tablo — `group_id` 0010'da kaldırıldı) ve her değişimde `refresh()` çağırıyor. `refresh()` `group_daily_totals(p_group_id)`'i (tam `study_sessions ⨝ group_members` GROUP BY) sıfırdan çalıştırıp tüm sonucu yeniden gönderiyor.
- **Neden verimsiz:** Herhangi bir kullanıcının tek bir oturum kaydı, herhangi bir gruba abone tüm istemcileri uyandırıp sıfırdan agregasyon yaptırıyor. Debounce/birleştirme yok: yazma patlaması = tam RPC patlaması. 1 satırlık değişimde bile tüm sonuç kümesi yeniden gönderiliyor.
- **Önerilen düzeltme:** (a) `refresh()`'i **debounce** et (~750ms–2s içindeki olayları birleştir — her olayda sıfırlanan bir `Timer`). (b) Kaynaktaki gürültüyü azalt: oturumları daha seyrek yaz veya flush'lar arası istemcide topla. (c) Uzun vadede trigger ile güncellenen materyalize bir `group_daily_totals` tablosu tut; okuma anında yeniden agregasyon yerine onu group'a göre filtreli akıt.
- **Tradeoff / Risk:** Debounce, canlı leaderboard'a N saniyeye kadar bayatlık ekler (çalışma takipçisi için kabul edilebilir). Materyalize tablo yazma yoluna karmaşıklık + migration ekler.
- **Beklenen etki:** High — O(yazma × abone) tam agregasyonu, debounce penceresi başına O(1)'e indirir; yük altında büyük DB-yükü azalması.
- **Kaldırma Güvenliği:** Doğrulama Gerekir (kabul edilebilir bayatlık ürün tarafıyla teyit edilmeli)
- **Yeniden Kullanım Kapsamı:** servis-geneli (tüm grup istatistik tüketicileri)

### N2 — Sınırsız `watchUserSessions` stream'i
- **Kategori:** Memory / Network
- **Önem:** High
- **Etki:** İstemci belleği, transfer, sonraki CPU
- **Kanıt:** `supabase_study_repository.dart:34-41` kullanıcının **tüm** `study_sessions`'ını `start_time`'a göre sıralı, `.limit()`/sayfalama olmadan akıtıyor. `study_providers.dart:29-33` bunu uygulama geneline açıyor; istatistik ekranları ve `currentStreak`/`todayRecorded` tüm listeyi tüketiyor.
- **Neden verimsiz:** Yoğun kullanıcı binlerce satır biriktirir; her realtime değişimde tüm küme yeniden akıtılıp decode edilir, sonra her bağımlı provider yeniden tarar.
- **Önerilen düzeltme:** Çoğu görünüm yalnızca yakın bir pencereye ihtiyaç duyar (ör. son 90–365 gün) — akıtılan kümeye sunucu-taraflı tarih filtresi / `.limit()` ekle, eski geçmişi talep üzerine getir (geçmiş ekranı sayfalasın). Tüm-zaman agregalarını sunucuda tut (grup için RPC ile zaten öyle; tüm-zaman kişisel istatistik gerekiyorsa kullanıcı başına bir `user_daily_totals` RPC ekle).
- **Tradeoff / Risk:** "Tüm-zaman" kişisel istatistikler (en uzun seri, ömür boyu toplam) tam istemci listesi yerine sunucu agregası gerektirir. Hangi ekranların gerçekten tüm geçmişe ihtiyaç duyduğunu doğrula.
- **Beklenen etki:** Medium–High; hesap yaşından bağımsız sınırlı bellek/transfer.
- **Kaldırma Güvenliği:** Doğrulama Gerekir (hangi ekranlar tüm geçmişe muhtaç)
- **Yeniden Kullanım Kapsamı:** servis-geneli

### N3 — Provider'lar arası gereksiz tam-liste yeniden hesabı
- **Kategori:** Algorithm / CPU
- **Önem:** Medium
- **Etki:** Rebuild'lerde CPU, jank (**olası** — ölç)
- **Kanıt:** `study_providers.dart:46-65`. `todayRecordedSecondsProvider` tüm listeyi fold ediyor; `currentStreakProvider` `currentStreak(sessions, ...)` çağırıyor, o da içeride tüm geçmiş üzerinde `dailyTotals(sessions)` (`study_stats.dart:51-57`) kuruyor. İstatistik widget'ları `lastNDays` / `dailyRange` / `longestStudyStreak` çağırıyor; paylaşılan `totals` haritası verilmedikçe her biri `dailyTotals`'ı yeniden kuruyor. Aynı veride frame/rebuild başına birden çok bağımsız O(n) tarama.
- **Neden verimsiz:** `dailyTotals` aynı kaynaktan defalarca yeniden hesaplanıyor; bunu önlemek için var olan `totals`-enjeksiyon parametresi var ama provider'lar paylaşılan harita sunmuyor.
- **Önerilen düzeltme:** Tek bir `dailyTotalsProvider` ekle (`userSessionsProvider`'dan türetilmiş memoize `Map<DateTime,int>`); streak/today/range provider'ları ve istatistik widget'ları bunu mevcut `totals:` parametreleriyle tüketsin.
- **Tradeoff / Risk:** İşlevsel olarak yok; tarama sayısını azaltır.
- **Beklenen etki:** Medium; ~4–6 tam taramayı veri değişimi başına 1'e indirir.
- **Kaldırma Güvenliği:** Muhtemelen Güvenli
- **Yeniden Kullanım Kapsamı:** modül (`study_providers` + istatistik widget'ları)
- **Sınıflandırma:** Yeniden Kullanım Fırsatı

### N4 — Grup/üye stream'lerinde realtime yeniden-getirme + O(n·m) eşleştirme
- **Kategori:** DB / Algorithm
- **Önem:** Medium
- **Etki:** Round-trip, üyelik değişiminde CPU
- **Kanıt:** `supabase_group_repository.dart:92-125`. `watchUserGroups` ve `watchMembers` `.stream(...).asyncMap(...)` kullanıyor → **her** üyelik değişiminde ikinci bir sorgu (`groups`/`profiles ... inFilter(ids)`) atıyor. `watchMembers`'ta `rows.firstWhere((r) => r['user_id'] == profile.id)` (satır 121) profiller üzerindeki `.map` içinde çalışıyor → O(profil × satır).
- **Neden verimsiz:** Değişim olayı başına ekstra round-trip; aktif-bayrak join'i için karesel eşleştirme. Küçük sınıflarda sorun değil, üyelik büyüyünce/değişince israf.
- **Önerilen düzeltme:** Map'lemeden önce bir kez `Map<userId, row>` kur (O(n)), `firstWhere` yerine. Üye+profilleri tek sorguda almak için gömülü join'li RPC/`select` düşün (PostgREST resource embedding `group_members(*, profiles(*))`); stream-sonra-yeniden-getir yerine.
- **Tradeoff / Risk:** Gömülü join realtime semantiğini değiştirir (embed'ler realtime değil); stream'i tetik olarak koru, aramayı optimize et.
- **Beklenen etki:** Low–Medium; kareseli kaldırır, round-trip'i yarıya indirir.
- **Kaldırma Güvenliği:** Muhtemelen Güvenli (`firstWhere`→map değişimi); Doğrulama Gerekir (embedding)
- **Yeniden Kullanım Kapsamı:** modül

### N5 — Atomik olmayan grup oluşturma (2 yazma, rollback yok)
- **Kategori:** Reliability
- **Önem:** Medium
- **Etki:** Yetim gruplar, tutarsız durum
- **Kanıt:** `supabase_group_repository.dart:24-57`. `createGroup` önce `groups`'a, sonra ayrı olarak oluşturanı `group_members`'a ekliyor. İkinci insert başarısız olursa (ağ/RLS) grup admin üyesi olmadan kalır.
- **Neden sorun:** Transaction yok; retry döngüsü yalnız davet-kodu çakışmasını kapsıyor, üyelik adımını değil.
- **Önerilen düzeltme:** Grubu + admin üyeliğini tek transaction'da ekleyen `create_group(name)` SECURITY DEFINER RPC'si (davet-kodu gizliliği sorununu da çözer — bkz. Güvenlik denetimi). İstemci tek RPC çağırır.
- **Tradeoff / Risk:** Migration ekler; mantığı sunucuya taşır (bütünlük için artı).
- **Beklenen etki:** Reliability (niteliksel); yetim durumu yok eder.
- **Kaldırma Güvenliği:** Doğrulama Gerekir
- **Yeniden Kullanım Kapsamı:** servis-geneli

### N6 — `placeGridItem` reflow'u tekrarlı lineer taramalarla O(n²)
- **Kategori:** Algorithm / Frontend
- **Önem:** Low (**olası** olarak mevcut ölçekte ihmal edilebilir)
- **Etki:** Kart sürükleme/yeniden boyutlamada CPU
- **Kanıt:** `grid_reflow.dart:50-111`. Her BFS adımında: `result.firstWhere(id)` (lineer), `result.where(overlaps).toList()..sort()` (tüm öğeleri tarar), collider başına `result.indexWhere(...)`. Guard sınırı `n²·4`. Her sürükleme tick'inde çalışıyor.
- **Neden verimsiz:** Düğüm başına tekrarlı lineer arama + tam overlap taraması; reflow başına O(n²). ~10–30 kartlık dashboard için ihmal edilebilir, ama yüksek frekanslı (sürükleme) bir yolda.
- **Önerilen düzeltme:** Öğeleri bir kez id'ye göre `Map`'le; yalnız taşınan alt kümeyi yeniden tara. Profil sürükleme jank'i göstermedikçe uğraşma.
- **Tradeoff / Risk:** Küçük N için erken — önce ölç.
- **Beklenen etki:** Low.
- **Kaldırma Güvenliği:** Muhtemelen Güvenli
- **Yeniden Kullanım Kapsamı:** yerel dosya

### N7 — build dizininde commit edilmiş Chrome aygıt-profili kalıntıları
- **Kategori:** Build / Cost (repo hijyeni)
- **Önem:** Low
- **Etki:** Repo şişkinliği, klon süresi, kazara veri
- **Kanıt:** `app/.dart_tool/chrome-device/Default/...` (History, Login Data, Web Data, vb.) diskte mevcut. `.gitignore` `.dart_tool/`'u kapsıyor → izlenmiyor; `git ls-files` ile doğrula. Ignore kuralından önce girdiyse geçmişi şişirir.
- **Neden sorun:** Flutter web debug Chrome profili VCS'e asla girmemeli; içinde bir tarayıcı `Login Data` SQLite dosyası var.
- **Önerilen düzeltme:** Hiçbirinin izlenmediğini teyit et (`git ls-files | grep chrome-device` → boş). Geçmişte varsa temizle. Yoksa işlem yok.
- **Kaldırma Güvenliği:** Güvenli (izlenmiyorsa)
- **Yeniden Kullanım Kapsamı:** yerel
- **Sınıflandırma:** Ölü Kod / kalıntı (güvenli kaldırma adayı — izlenmediği doğrulanmalı)

### N8 — Repository arayüzünde tutulan ölü metot
- **Kategori:** Code Reuse / Dead Code
- **Önem:** Low
- **Etki:** Anlaşılırlık, bakım
- **Kanıt:** `supabase_study_repository.dart:44-49` `watchGroupSessions`, çağıranı olmadığını (group_id 0010'da kaldırıldı) belirten yorumla `Stream.value(const [])` döndürüyor. Arayüz metodu + in-memory implementasyonu yalnız biçim için tutuluyor.
- **Neden sorun:** Hep boş dönen bir metot, gelecekteki çağıranlar için tuzak (sessiz boş veri).
- **Önerilen düzeltme:** `StudyRepository`'den ve tüm implementasyonlardan kaldır, ya da yüksek sesle belgele. Önce sıfır referans doğrula.
- **Kaldırma Güvenliği:** Doğrulama Gerekir (çağıranları grep'le)
- **Yeniden Kullanım Kapsamı:** modül
- **Sınıflandırma:** Ölü Kod

---

## 3) Hızlı Kazanımlar (Önce Yap)
- **N1 debounce** — `refresh()`'i olayda-sıfırlanan bir `Timer` (≈1s) ile sar. Küçük değişiklik, büyük yük azalması.
- **N3 paylaşılan `dailyTotalsProvider`** — mevcut `totals:` parametrelerini besleyen tek memoize harita.
- **N4 `firstWhere`→`Map` araması** `watchMembers`'ta — kareseli kaldırır.
- **N8** çağıranı olmadığını teyit ettikten sonra hep-boş `watchGroupSessions`'ı sil.

## 4) Daha Derin Optimizasyonlar (Sonra Yap)
- **N1 (tam):** trigger ile güncellenen materyalize `group_daily_totals` tablosu; okuma anında yeniden agregasyon yerine onu group'a göre filtreli akıt.
- **N2:** akıtılan geçmişi yakın pencereyle sınırla + geçmiş ekranını sayfala; tüm-zaman kişisel istatistik için kullanıcı başına günlük-toplam RPC'si ekle.
- **N5:** transaction'lı `create_group` RPC'si (davet-kodu gizlilik açığını da kapatır).

## 5) Doğrulama Planı
- **N1:** 50 eşzamanlı yazıcı simüle et; debounce öncesi/sonrası Supabase'te RPC çağrısı/sn (Logs/`pg_stat_statements`) ve istemci çıkış trafiğini ölç. Doğruluk: debounce'lu stream'in nihai değeri, sakinleştikten sonra debounce'suz değere eşit olmalı.
- **N2:** 5k oturumlu bir hesap tohumla; pencereleme öncesi/sonrası stream payload boyutu, decode süresi, provider rebuild süresini ölç. Geçmiş ekranı sayfalamayla eski veriye hâlâ ulaşmalı.
- **N3:** `dailyTotals`'a sayaç/log ekle; paylaşılan provider öncesi/sonrası veri değişimi başına çağrı sayısını say. İstatistik çıktılarını golden-test ile sabitle.
- **N4/N6:** sentetik 200-üyeli grup / 30-kartlık grid ile mikro-benchmark; duvar saatini kıyasla. Widget test'leri özdeş üye listeleri / yerleşimleri doğrulasın.
- **N5:** entegrasyon testi: üyelik insert'ini başarısız olmaya zorla, (RPC düzeltmesinden sonra) yetim grup kalmadığını doğrula.
- Genel: `flutter analyze` temiz kalsın; `study_stats.dart` etrafına unit test ekle (saf fonksiyonlar — refactor öncesi davranışı kilitlemek kolay).

## 6) Optimize Kod / Yama (örnekleme — uygulanmadı)

**N1 — debounce'lu refresh** (`supabase_study_repository.dart`):
```dart
Timer? _debounce;
void scheduleRefresh() {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 1000), refresh);
}
// kanal callback'i:
callback: (_) => scheduleRefresh(),
// onCancel: _debounce?.cancel(); ...
```

**N3 — paylaşılan günlük toplamlar** (`study_providers.dart`):
```dart
final dailyTotalsProvider = Provider<Map<DateTime, int>>((ref) {
  final sessions = ref.watch(userSessionsProvider).value ?? const [];
  return dailyTotals(sessions);            // bir kez hesaplanır
});

final currentStreakProvider = Provider<int>((ref) {
  final totals = ref.watch(dailyTotalsProvider);
  final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
  return currentStreak(const [], goalSeconds, totals: totals); // haritayı yeniden kullan
});
```

**N4 — O(n) üye eşleştirme** (`supabase_group_repository.dart`):
```dart
final byUser = {for (final r in rows) r['user_id'] as String: r};
return profs.map<Profile>((pMap) {
  final p = Profile.fromMap(pMap);
  return p.copyWith(isActive: byUser[p.id]?['left_at'] == null);
}).toList();
```
