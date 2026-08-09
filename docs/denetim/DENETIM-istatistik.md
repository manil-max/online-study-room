# DENETİM — İstatistik · Oyunlaştırma · Hedef/Seri

Tarih: 2026-08-09 · Salt okunur denetim (kod değiştirilmedi, test koşulmadı).
Yöntem: **belgeler kanıt sayılmadı.** `progress.md`, `docs/**` ve kod yorumları
yalnız *iddia* olarak okundu; her bulgu `dosya:satır` ile koddan doğrulandı.

Bugün (2026-08-09) bu alana dokunan WP'ler (WP-585, WP-589, WP-595, WP-596,
WP-604) `git log` ile kontrol edildi; oralarda **kapanmış** olan konular
raporlanmadı.

Bilinen ve kart konusu olduğu için **tekrar yazılmadı:** XP'nin oturum
silinince geri alınamaması (append-only defter). Aynı sınıfın *başka*
örnekleri aşağıda ayrıca aranmıştır.

---

## KANAMA

### K1 — "Geçen hafta / geçen ay / geçen yıl" aralığı bir gün fazla (Türkiye dışındaki her cihazda)

**Belirti.** Dönem şeridindeki geri okuyla geçmiş bir döneme gidildiğinde
gösterilen toplam, o dönemin **bir sonraki** gününü de içerir. "Geçen hafta"
Pazartesi–Pazar yerine Pazartesi–**Pazartesi** (8 gün) olur; bu haftanın
Pazartesi'si geçen haftanın hanesine yazılır. Günlük ortalama paydası da 8'dir.

**Kanıt.**
- `app/lib/core/stats/stats_period.dart:72` — gezinilmiş dönemin bitişi
  `endExclusive.subtract(const Duration(milliseconds: 1))`, yani **yerel**
  23:59:59.999. Başlangıç (`:94`, `:99`, `:103`) düz `DateTime(y,m,d)`, yani
  gün anahtarı; bitiş **değil**.
- `app/lib/core/stats/istanbul_calendar.dart:40-47` — `_isDayKey` yalnız
  saat/dakika/... = 0 olan değeri "anahtar" sayar. 23:59:59.999 anahtar
  değildir, `:56` ile İstanbul'a **çevrilir**.
- Cihaz UTC+3'ün batısındaysa (UTC, tüm Avrupa, Amerika — ve **CI koşucusu**,
  `TZ=UTC`) 23:59:59.999 yerel an, İstanbul'da **ertesi gündür**. `dayOf(to)`
  bir gün ileri kayar.
- Tüketiciler `to`'yu tam da bu şekilde güne indirir:
  `app/lib/core/stats/study_stats.dart:50-51` (`inRange`),
  `app/lib/features/stats/widgets/personal_stats_view.dart:118,186`,
  `app/lib/features/stats/widgets/class_stats_view.dart:106`.
- Sunucuya da yanlış tarih gider:
  `app/lib/data/repositories/supabase/supabase_analytics_query_repository.dart:13-18`
  (`_dateParam` → `dayOf(d)`), `:28`, `:49`, `:69`, `:89`.

**Ölçmeyen kapı.** Mevcut test **ham** `to` değerini doğruluyor, tüketicilerin
kullandığı `dayOf(to)`'yu değil:
`app/test/features/a11y_and_period_nav_wp554_test.dart:326`
(`expect(to, thisWeek.subtract(const Duration(milliseconds: 1)))`). Aralığın
kaç **gün** kapsadığına dair tek bir iddia yok, bu yüzden hata CI'da (UTC)
aktif olduğu hâlde görünmüyor.

**Etki.** Geçmiş dönem toplamı, kişi başı ortalaması, hafta içi/sonu kırılımı,
grup sıralaması ve sunucudan çekilen uzun dönem verisi hepsi bir gün şişer.
Türkiye'deki cihazda (UTC+3) **üretilemez** — bu yüzden sahibin gözünde
görünmez, kullanıcıların yarısında sürekli yanlış. Deponun üç kez üretime
çıkardığı sınıfın (WP-561 / WP-571 / WP-604) dördüncüsü.

> Not: kodu koşturmadım (salt okunur). İddia `_isDayKey` + `_dayKeyIn`
> okumasına dayanıyor; doğrulama testi TZ enjekte edilebilen
> `calendarDayInTimeZone` üzerinden yazılabilir (WP-561'in kullandığı yol).

**Öncelik: KANAMA**

---

### K2 — Ana ekrandaki "Rekorlar" kartı 90 günlük pencereyi "Toplam / Rekor seri / Aktif gün" diye sunuyor

**Belirti.** 400 günlük geçmişi olan kullanıcı ana ekranda "Toplam"ı yaklaşık
dörtte bir görüyor; "Rekor seri" 90'ı hiçbir zaman aşamıyor. Kartta kapsam
etiketi yok.

**Kanıt.**
- `app/lib/features/home/widgets/records_card.dart:20,28,41` — kaynak
  `userSessionsProvider`, doğrudan `StudyRecords`'a veriliyor.
- `app/lib/data/providers/study_providers.dart:187-193` — bu sağlayıcı
  **sıcak penceredir** (son 90 gün); ömür boyu toplam için
  `userStudySummaryProvider` var.
- `app/lib/features/stats/widgets/study_records.dart:49-51` — `total`,
  `longest`, `activeDays` hepsi bu 90 günlük listeden; etiketler
  `statsToplam` / `statsRekorSeri` / `statsAktifGun`.

**Karşılaştırma (aynı depoda doğrusu var).** İstatistik ekranı "Tümü"
döneminde `summary.lifetimeSeconds` kullanıyor
(`personal_stats_view.dart:221-223`) ve sıcak pencereyle sınırlı kartlara
"· 90 gün" etiketi asıyor (`:188-190`). WP-573 tam bu yalanı İstatistik
ekranında kapattı; ana ekran kartı atlandı.

**Etki.** Dashboard'un "rekorlarım" vaadi sessizce yanlış sayı gösteriyor —
"eksik veriyi tam gibi göstermek" sınıfı.

**Öncelik: KANAMA**

---

### K3 — Ana ekranda İKİ ayrı grup-serisi motoru yan yana çalışıyor

**Belirti.** "Sıralama" kartındaki 🔥 N ile "Grup hedefi" kartındaki alev
rozetindeki N **farklı sayılar** olabilir. İlkinde grace (tek gün kaçırma
koruması) yok, ikincisinde var.

**Kanıt.**
- Eski motor: `app/lib/features/home/widgets/leaderboard_card.dart:100-104`
  → `currentStreak(const [], goalSeconds, totals: groupDayTotals(stats))`;
  ekrana `:165-177`'de ateş ikonu + sayı olarak çiziliyor.
  `currentStreak` (`study_stats.dart:333-352`) grace tanımıyor ve `today`
  verilmediği için `DateTime.now()` kullanıyor.
- Kanonik motor: `app/lib/features/home/widgets/group_goal_card.dart:202,264`
  → `GoalStreakBadge` → `goalStreakProjectionProvider` → sunucu RPC'si.
- Sarmalayıcının varlık gerekçesi zaten bu:
  `app/lib/features/stats/widgets/goal_streak_flame.dart:211-217` — *"Ekranlar
  bunun yerine grace'siz eski motoru (`currentStreak()`) okuyordu … Bu
  sarmalayıcı iki motorun aynı ekranda yaşamasını engeller."* Kart bunu iddia
  ediyor; kodda **engellenmemiş**.

**Etki.** Kullanıcı aynı ekranda iki farklı "grup serisi" görüyor; hangisinin
doğru olduğunu ayırt etmesi imkânsız. Sahibin defalarca bildirdiği "alev yanlış"
şikâyetinin hâlâ ayakta olan kolu.

**Öncelik: KANAMA**

---

## RİSK

### R1 — "Bugün" sayısı ve günlük hedef halkası gece yarısında yenilenmiyor (zaman bir girdi değil)

**Belirti.** Uygulama açıkken gece yarısı geçildiğinde "Günlük hedef" kartı
dünkü toplamı ve dolu halkayı göstermeye devam eder (`%100`, ✓ "Bitti"), yeni
bir oturum yazılana kadar.

**Kanıt.**
- `app/lib/data/providers/study_providers.dart:222-226` —
  `todayRecordedSecondsProvider` bir `Provider`; içinde
  `dayOf(DateTime.now())` var ama yalnız `dailyTotalsProvider` değişince
  yeniden hesaplanır. Gece yarısında hiçbir oturum satırı değişmez.
- Aynı desen: `:254-257` `groupTodaySecondsProvider` (`todaySecondsByUser`,
  gün anahtarını `DateTime.now()`dan alır).
- Tüketici: `app/lib/features/home/widgets/goal_card.dart:24,34-37` — `pct`,
  `reached` ve halka doğrudan bu değerden.
- Doğrusu depoda var ve **bugün** yazıldı:
  `app/lib/data/providers/goal_streak_providers.dart:63-123`
  (`GoalStreakDayRollover`: İstanbul gece yarısına zamanlayıcı + öne gelme).
  Hedef halkası ve grup "bugün" haritası bu tetikleyiciye bağlanmamış.

**Etki.** WP-604'ün kapattığı hatanın **komşu yüzeyi**. Sahip serinin takılı
kalmasını bildirdi; aynı kök neden hedef halkasında duruyor.

**Öncelik: RİSK**

---

### R2 — Üst dört özet kartı sıcak pencereye düştüğünü SÖYLEMİYOR

**Belirti.** "Yıl" seçiliyken sunucu yolu yüklenirken ya da hata verirken
"Toplam / Günlük Ortalama / Hafta İçi / Hafta Sonu" kartları 90 günlük sayıyı
gösterir, başlıkta yalnız "Yıl" yazar.

**Kanıt.**
- `app/lib/features/stats/widgets/personal_stats_view.dart:102-110` — kendi
  yorumu kapsamı sayıyor: *"detay kartları (… hafta içi/sonu, **Toplam**) artık
  sunucudan beslenir"*.
- `:188-190` — `scopeSuffix` üretiliyor, ama `:197-202` (dönem başlığı) ve
  `:216-256` (dört kart) bu son eki **kullanmıyor**. Son ek yalnız `:286`,
  `:350`, `:370`, `:382`'deki bölüm başlıklarına ekleniyor.
- `split = weekdayWeekendSplit(periodSessions)` (`:133`) ve
  `periodTotalSec = totalSeconds(periodSessions)` (`:185`) — sunucu düştüğünde
  `periodSessions` sıcak pencereye eşittir (`:117-118`).

**Ölçmeyen kapı.** `app/test/features/stats/long_period_scope_wp573_test.dart:275-285`
yalnız `'Çalışma saatleri · Tümü · 90 gün'` bölüm başlığını doğruluyor; üst
dört kart hakkında tek iddia yok. `Toplam` kartı "Tümü" döneminde
`lifetimeSeconds`'a düştüğü için test yeşil, "Yıl"da değil.

**Öncelik: RİSK**

---

### R3 — `analyticsUserDayTotalsProvider` hâlâ SESSİZ sıcak-pencere geri düşmesi yapıyor (WP-585 yalnız kardeşini düzeltti)

**Belirti.** "Seçili tarih aralığı" grafiği, sunucu boş dönerse 90 günlük
veriyi seçili dönemin tamamıymış gibi çizer; kapsam etiketi yoktur.

**Kanıt.**
- `app/lib/data/providers/analytics_query_providers.dart:59-64` — `rows`
  boşsa `dailyTotals(inRange(hot, from, to))` döner; dönüş tipi düz
  `Map<DateTime,int>`, **bayrak yok**.
- Aynı dosyada kardeş sağlayıcı WP-585'te düzeltilmiş:
  `:69-77` (`AnalyticsRangeSessions.hotLimited`), `:108-116`.
- Tüketici: `app/lib/features/stats/widgets/personal_stats_view.dart:409,425-461`
  — `map` doluysa "veri geldi" varsayıp toplam + gün sayısı yazıyor.

**Öncelik: RİSK**

---

### R4 — "Aktif gün" iki farklı kuralla hesaplanıyor; biri 0 saniyelik günü sayıyor

**Belirti.** Aynı kavram iki yüzeyde farklı sayı verebilir.

**Kanıt.**
- `app/lib/features/stats/widgets/study_records.dart:52` —
  `final activeDays = daily.length;` (değere bakmıyor, 0 saniyelik gün de
  sayılıyor).
- `app/lib/features/stats/widgets/class_stats_view.dart:176` —
  `activeDayCount(groupDay)`; `app/lib/core/stats/study_stats.dart:466-467`
  doğru şekilde `> 0` filtreliyor.
- WP-561 **aynı hatayı** kardeş metrikte zaten düzeltmiş ve gerekçesini yazmış:
  `study_stats.dart:359-361` — *"değere bakılmadan `.keys` kullanmak 0
  saniyelik günü de 'çalışılmış' sayıyordu … Sıfırlanmış / silinmiş bir gün
  rekor seriyi şişiriyordu."* `activeDays` o turda atlanmış.
- Üçüncü kural: `app/lib/features/home/widgets/period_summary_card.dart:60-64`
  — `inRange(...).map((s) => s.day).toSet().length` (yine 0 saniyelik gün
  sayılır).

**Öncelik: RİSK**

---

### R5 — Ana ekran ısı haritası 52 haftaya kadar takvim çiziyor, veri 90 gün

**Belirti.** Geniş ekranda bir yıllık takvim çizilir; ilk ~9 ay bomboş görünür.
Bir yıllık geçmişi olan kullanıcı "hiç çalışmamışım" görür.

**Kanıt.**
- `app/lib/features/home/widgets/heatmap_card.dart:40-43` —
  `weeks = ((maxWidth - 40) / 18).floor().clamp(4, 52)`; kaynak `sessions`
  (`:28`) = 90 günlük sıcak pencere.
- Doğrusu aynı bileşenin diğer çağrı yerinde:
  `app/lib/features/stats/widgets/personal_stats_view.dart:269-281` —
  `weeks: 13` **ve** başlıkta açık `· 90 gün` etiketi.

**Öncelik: RİSK**

---

### R6 — Ana ekran sıralama kartında engellenen kullanıcı filtresi yok

**Belirti.** Kullanıcının engellediği kişi, İstatistik > Grup sıralamasında
gizleniyor ama ana ekrandaki "Sıralama" kartında adı ve avatarıyla görünüyor.

**Kanıt.**
- Filtreli: `app/lib/features/stats/widgets/class_stats_view.dart:103`
  (`blockedUserIdsProvider`), `:258-272`.
- Filtresiz: `app/lib/features/home/widgets/leaderboard_card.dart` —
  `blockedUserIdsProvider` dosyada **hiç geçmiyor**; `_Row` (`:272-310`)
  doğrudan `member.displayName` / `avatarUrl` çiziyor.
- Sağlayıcının tüm çağrı yerleri: `moderation_providers.dart:20` tanım +
  campfire, sohbet, class_stats_view, güvenlik ekranları. Ana ekran sıralaması
  listede yok.

**Etki.** Aynı veri, iki yüzey, tek kaynağa bağlanmamış — WP-594'te
(profil rozeti) çıkan desenin tekrarı. Moderasyon alanıyla kesişiyor.

**Öncelik: RİSK**

---

### R7 — Katalog dışı Türkçe metin üç yerde; l10n kapısı bu biçimi göremiyor

**Belirti.** İngilizce arayüzde "Ali (sen)" ve "3 ders" yazıyor.

**Kanıt.**
- `app/lib/features/stats/widgets/class_stats_view.dart:965` —
  `isMe ? '$name (sen)' : name`
- `app/lib/features/home/widgets/leaderboard_card.dart:340` — aynı satır.
- `app/lib/features/home/widgets/today_summary_card.dart:90` —
  `: '${breakdown.length} ders',`
- Katalogda karşılığı **zaten var**: `app/lib/l10n/app_tr.arb:1761`
  (`"feedbackYou": "Sen"`).

**Ölçmeyen kapı.** `scripts/l10n_audit.py:64-71` — `UI_SLOT` deseni literal'i
`Text(` **hemen ardında** arıyor. Üç bulgunun üçü de ternary'nin içinde
(`Text(\n  cond ? '…' : …`), yani tarama bu biçimi hiç görmüyor. Ayrıca
`PROSE_RE` (`:83`) harfle başlama şartı koyuyor; `'$name (sen)'` `$` ile
başladığı için ikinci elek de tutmuyor.

**Öncelik: RİSK** (kapı düzeltilmezse bu biçim sessizce çoğalır)

---

### R8 — Dönem şeridinde ham `DateTime.toString()` ekrana basılıyor

**Belirti.** Özel aralık seçildikten sonra şeridin altında
`2026-07-10 00:00:00.000 → 2026-08-09 00:00:00.000` benzeri bir satır çıkar.

**Kanıt.** `app/lib/features/stats/widgets/stats_period_bar.dart:100` —
`'${dayOf(sel.customFrom!)} → ${dayOf(sel.customTo!)}'`. Aynı dosya zaten
`DateFormat` kullanıyor (`:199`, `:204`), yani biçimlendirici elde ama bu
satırda kullanılmamış.

**Öncelik: RİSK**

---

### R9 — Serbest tarih aralığı 2 yıl geriye seçtiriyor, veri 90 gün

**Belirti.** Kullanıcı "Seçili tarih aralığı" kartından 2023'ü seçebiliyor;
kart "Toplam: 0 dk" diyor. Hiçbir yerde "bu aralıkta verim yok değil, veriye
erişimim yok" denmiyor.

**Kanıt.**
- `app/lib/features/stats/widgets/personal_stats_view.dart:677` —
  `firstDate: DateTime(now.year - 2)`.
- `:697-700` — toplam/ortalama/seri hepsi `widget.sessions` üzerinden, o da
  sıcak pencere (`stats_screen.dart:98-99` → `userSessionsProvider`).
- Karşılaştırma: aynı ekran, aynı dosya, uzun dönem için sunucu yolunu
  (`analyticsUserSessionsInRangeProvider`) kullanıyor (`:113-114`); bu kart
  ona bağlanmamış.

**Öncelik: RİSK**

---

## TEMİZLİK

### T1 — Üç ayrı, birbiriyle çelişen başarım/taç modeli; ikisi tamamen ölü

**Kanıt.**
- `app/lib/core/stats/achievement_engine.dart` — `kAllAchievements` (`:6`) ve
  `AchievementEngine` (`:125`) `app/lib` içinde **hiçbir yerden** çağrılmıyor
  (yalnız kendi dosyasında `:194`). 10 başarım × 6 kademe, farklı id'ler
  (`study_hours`, `deep_focus`, `night_owl`…), farklı XP tabloları — üretimdeki
  `kAchievementDictV3` ile taban tabana zıt. Üstelik `:185-187` seri ve
  "kusursuz hafta" değerlerini sabit `0` yazıyor.
- `app/lib/core/stats/gamification.dart` — `AchievementId` (4 başarım),
  `CrownTier {none,bronze,silver,gold}` (`:59`) ve `crownTierFor` (`:124`)
  üretimdeki 6 basamaklı taç modeliyle (`progression_visuals.dart:72-79`)
  çelişiyor.
- `GamificationSummary`in altı alanından **beşi** hiçbir widget'ta okunmuyor:
  `gamification_providers.dart:227-246`'da tanımlı `freezeAwareStreak`,
  `achievements`, `crownTier`, `totalSeconds`, `sessionCount`,
  `unlockedAchievementCount` — tek okunan `.profile`
  (`gamification_card.dart:64,89`, `data_export_screen.dart:50`). Yani
  `_buildGamificationSummary` (`:292-317`) her oturum değişiminde tam bir
  gün→saniye haritası + dondurma-farkındalıklı seri + başarım listesi üretip
  **atıyor**.
- Artık: `app/lib/l10n/app_localizations.dart:4404` yorumu hâlâ
  `${summary.freezeAwareStreak.streak} gün seri` kaynağını gösteriyor — çizilmeyen
  bir arayüzün l10n anahtarı.

**Neden önemli.** Bir sonraki tur bu dosyalardan birini "mevcut kural" sanıp
okursa yanlış ekonomiyi geri getirir. (WP-604'ün öğrettiği tuzağın aynısı:
yazılı kayıt yanlış, kod başka.)

**Öncelik: TEMİZLİK**

---

### T2 — Çağıranı olmayan sağlayıcılar

**Kanıt.**
- `app/lib/data/providers/study_providers.dart:235-241` `currentStreakProvider`
  — `app/lib` ve `app/test` içinde tek bir okuyucusu yok; yalnız üç **yorumda**
  adı geçiyor (`study_timer_card.dart:246,318`, `goal_card.dart:28`). Sürüyor
  olması K3'teki ikinci motorun canlı kalmasını kolaylaştırıyor.
- `app/lib/data/providers/achievement_provider.dart:134-138` ve `:141-145`
  (`notifySessionCompletedForAchievementsProvider`,
  `refreshAchievementsProvider`) — çağıran yok.
- `app/lib/data/providers/study_providers.dart:243-249`
  `canonicalStatsProjectionProvider` — tek okuyucusu `:2900`, o da
  `:2896-2898`'deki `isPublished` kapısıyla fiilen kapalı (WP-558).

**Öncelik: TEMİZLİK**

---

### T3 — Yorum ile sabit çelişiyor (saat XP'si)

**Kanıt.** `app/lib/core/stats/achievement_ledger_engine.dart:615` — *"Her
tamamlanan 1 saat çalışma → **10 XP**"*; sabit `:322`'de
`kStudyHourXp = 50`. Kod doğru, yorum bayat.

**Öncelik: TEMİZLİK**

---

## Kontrol ettim, SAĞLAM çıktı

- **Aynı gün ikinci kez seri artışı imkânsız.** Şema seviyesinde kilit:
  `supabase/migrations/0112_goal_streak_projection.sql:40`
  (`unique (scope_type, scope_id, event_kind, goal_day)`), yazıcıda da
  `on conflict … do nothing` (`0120:120`). "Çift olay çift artış üretmez"
  uygulama katmanına bırakılmamış.
- **İstemci "hedefimi tuttum" diyemiyor.** `record_goal_completion`
  (`0120:135-186`) yetkiyi kontrol ediyor, gelecek günü reddediyor (`:155`),
  ve karar `study_sessions` toplamından veriliyor (`0120:105-112`,
  `_goal_day_seconds` `0112:72-88`). Yazma yolu istemci arayüzünde de yok
  (`goal_streak_providers.dart:28-34`).
- **Dart projeksiyonu ile SQL projeksiyonu aynı kuralı uyguluyor** (tek gün
  kaçırma korunur, iki ardışık kaçırma sıfırlar):
  `goal_streak_projection.dart:53-69` ↔ `0112` `runs`/`state` blokları. Ayrıca
  Dart tarafı aynı `eventKey` için çelişen içerik gelirse `StateError` atıyor
  (`:20`), sessizce ilk kaydı tutmuyor.
- **XP defteri idempotent.** Sunucu: `0057_route_awards_to_inbox.sql:151`
  (`on conflict (event_key) do nothing`). İstemci/demo motoru:
  `achievement_ledger_engine.dart:599-601` ve `:617-622` (`ledgerEventKey` /
  `studyHourEventKey` + `_eventKeys`). Aynı olay iki kez XP vermiyor.
- **Grup metriklerinde çift sayım yok.** `achievement_provider.dart:31-44,65-87`
  — düz tablo gruplar arası `max` tutuyor, seçili grup yalnız **gösterimi**
  eziyor; kazanılmış kademe geri alınmıyor.
- **Ödül toplama iyimser cüzdan kullanmıyor.** `achievement_showcase.dart:1296-1297`
  ve `achievement_reward_provider.dart:57-63` — durum yalnız sunucu sonucundan
  sonra değişiyor; hata dalında tekrar-dene çıkışı var (`:1339-1361`).
- **WP-604 gerçekten kapanmış.** Gün dönüşü hem zamanlayıcı hem `resumed` ile
  tetikleniyor, saat enjekte edilebilir
  (`goal_streak_providers.dart:63-123,126-137`); sunucuya sorulan gün anahtarı
  İstanbul takviminden (`supabase_goal_streak_repository.dart:117-136`).
- **`istanbulDay` idempotent ve `TZDateTime` kapısı sağlam** (WP-561/584):
  `istanbul_calendar.dart:40-58`. Gün anahtarı düz `DateTime`, an ise her zaman
  çevriliyor.
- **WP-561 hesap düzeltmeleri yerinde:** `averageWindow` paydayı veri ufkuna
  kırpıyor (`study_stats.dart:235-254`), `weekOverWeekSeconds` kısmî haftayı
  kısmî haftayla kıyaslıyor (`:261-274`), `liveSecondsToday` gece yarısında
  kırpıyor (`:147-155`).
- **WP-585 kapsam etiketi gerçekten yazılıyor** (oturum listesi yolunda):
  `analytics_query_providers.dart:108-116` → `personal_stats_view.dart:128-129`.
  (Gün-toplamı yolundaki eksik R3'te.)
- **WP-596 ve WP-589 çıkışları duruyor:** `stats_screen.dart:148-181`
  (boş grup dalında "Bir gruba katıl" düğmesi), `class_stats_view.dart:342-357`
  (hata dalı boş daldan farklı cümle + hedefli `invalidate`).
- **Sıralama satırı taşmıyor / engellenen ad İstatistik tarafında maskeleniyor:**
  `class_stats_view.dart:258-272`.
