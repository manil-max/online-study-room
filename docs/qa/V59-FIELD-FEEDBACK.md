# v59 sonrası saha geri bildirim raporu (sahip notu + kod doğrulaması)

Tarih: 2026-08-08 · Durum: **yalnız rapor, kod değişmedi** (başka ajan aktif)
Kaynak: sahibin sesli/yazılı notu + Gruplar ekranı ekran görüntüsü
Doğrulama: `app/lib` okundu, her madde dosya:satır ile karşılandı.

---

## Özet tablo

| # | Konu | Sahip iddiası doğrulandı mı | Sınıf | Tahmini boy |
|---|------|------------------------------|-------|-------------|
| 1 | Ana ekran kartlarında sahte kaydırma | ✅ Evet, **tek kart değil, 12 yerde** | Hata | Orta (ortak yardımcı) |
| 2 | Sohbet "pencere içinde pencere" | ✅ Evet | Hata/UX | Orta |
| 3 | Grup değiştir butonu üst şeritte | ✅ Evet | UX | Küçük (+2 gizli adım) |
| 4 | Grup ayarlarında sohbet kartı | ✅ Evet | Temizlik | Çok küçük |
| 5 | Kamp ateşi kartında dürtme yok | ✅ Evet | Eksik özellik | Orta |
| 6 | Taç kademeleri keşfedilemiyor | ✅ Evet | UX | Küçük |
| 7 | "Timer diagnostic log" ne? | Açıklama aşağıda | Karar gerekiyor | — |
| 8 | SSS iki kat derinde | ✅ Evet | UX | Çok küçük |
| 9 | Ad/grup adı karakter sınırı yok | ✅ Evet, **hiçbir katmanda yok** | Hata/UX | Küçük |
| 10 | Sayacı kapatırken ~3 sn gecikme | ✅ Kodda kuvvetli aday bulundu | Hata (kritik alan) | Dikkatli |

Ek olarak sahibin fark etmediği **6 bulgu** (E1–E6) aşağıda.

---

## 1) Kartların içindeki "kaydırıyorum ama kaymıyor" tuzağı

**Belirti (sahip):** Ana ekranda aşağı kaydırırken parmağım *Şu an çalışanlar* kartının
üstüne denk gelince sayfa kaymıyor; buna rağmen bir kaydırma animasyonu oluyor.

**Doğrulandı, kök neden:**
`active_members_card.dart:191` — kart sınırlı yükseklikte (Ana Sayfa ızgarası her karta
sabit piksel yükseklik verir, `dashboard_card.dart:500`) **her zaman** bir
`ListView.builder` kuruyor, `physics` verilmemiş.

Flutter'da bir `Scrollable`, içeriği kutusuna sığsa bile dikey sürükleme jestini
gesture arena'da kazanır (en içteki kazanır). İçerik sığdığı için pozisyon oynamaz →
kart "donmuş" gibi görünür ve **dış sayfa da kaymaz**. Android'in Material 3 "stretch"
overscroll efekti bu sırada tetiklendiği için sahibin gördüğü "kaydırma animasyonu var
ama kaymıyor" görüntüsü çıkar. Yani animasyon bir süs değil, tam olarak hatanın kanıtı.

**Bu tek karta özel değil.** Aynı desen (sınırlı yükseklik + varsayılan physics'li iç
kaydırıcı) şu dosyalarda var:

| Dosya:satır | Kaydırıcı | Not |
|---|---|---|
| `home/widgets/active_members_card.dart:191` | `ListView.builder` | sahibin fark ettiği kart |
| `home/widgets/today_summary_card.dart:61` | `SingleChildScrollView` | kompakt dal |
| `home/widgets/today_summary_card.dart:130` | `ListView.builder` | ders kırılımı |
| `home/widgets/goal_card.dart:76` ve `:128` | `SingleChildScrollView` | **her iki dal da koşulsuz** |
| `home/widgets/period_summary_card.dart:156` | `SingleChildScrollView` | koşulsuz |
| `home/widgets/records_card.dart:39` | `SingleChildScrollView` | |
| `home/widgets/heatmap_card.dart:45-46` | dikey + yatay iç içe | taşma gerçekten olabilir |
| `home/widgets/rhythm_card.dart:39-40` | dikey + yatay iç içe | taşma gerçekten olabilir |
| `home/widgets/tasks_card.dart:134` | `ListView.separated` | |
| `home/widgets/leaderboard_card.dart:236` | `SingleChildScrollView` | kısa/bounded dal |
| `home/widgets/group_goal_card.dart:156` | `SingleChildScrollView` | |
| `home/widgets/group_card_shell.dart:123` | `SingleChildScrollView` | "gruba katıl" daveti |
| `home/widgets/card_scaffold.dart:97` | `SingleChildScrollView` | **ortak iskelet — hepsini etkiler** |

**Doğrusu repoda zaten iki yerde var** (yani desen biliniyor, sadece yayılmamış):
`group_card_shell.dart:159` ve `leaderboard_card.dart:252` →
`physics: const NeverScrollableScrollPhysics()`.

**🔒 SAHİP KARARI (2026-08-08, bağlayıcı):** *"sığdığında kaydırıcı hiç kurulmasın,
taşarsa kart içinde kayabilsin."* Aşağıdaki öneri onaylandı, tartışma kapandı.

**Önerim (sahip onayladı):**
Kartlar körü körüne "hiç kaydırmasın" yapılmamalı — o zaman taşan içerik kırpılır ve
WP-497'de bilerek düzeltilen "sığmayan üye tamamen kayboluyordu" hatası geri gelir.
Doğru kural: **iç kaydırma yalnız içerik gerçekten taşıyorsa açılsın.**
Tek bir ortak yardımcı (`cardScrollIfOverflows(...)` gibi) yazılıp yukarıdaki 13 çağrı
ona bağlanmalı; `card_scaffold.dart` tek kapı olduğu için işin yarısı orada bitiyor.
Isı haritası / ritim kartlarında içerik gerçekten taşabilir, orada kaydırma korunur
ama yine yalnız taşma varken.

**Neden sessizce girdi (test boşluğu):** `test/features/classroom/group_scroll_nesting_test.dart`
yalnız **sınırsız** yükseklik yolunu (Gruplar listesi) koruyor. Ana Sayfa'nın sınırlı
hücresinde "kartın üstünden sürüklersen sayfa kayar" iddiasını kanıtlayan test yok.
Düzeltmeyle birlikte bu test şart, yoksa aynı hata üçüncü kez döner.

---

## 2) Sohbet: pencere içinde pencere

**Doğrulandı.** `classroom/widgets/class_chat_screen.dart:21-34`:
ekran bir `Scaffold` + `AppBar("Sohbet")`, gövdesi bir `ListView`, içinde önce
`Text(group.name)`, sonra `ClassChatCard` — ve o kart mesaj listesine
**sabit yükseklik** veriyor (`messageListHeight`, ekranda `300..560` arası kırpılıyor,
kartın kendi varsayılanı `class_chat_card.dart:22` = 280).

Sahibin tarifi birebir bu: üstte "Sohbet" başlığı, altında grup adı, altında kutu içinde
sohbet. Yan etkisi sadece görsel değil — sabit yükseklikli liste + dış `ListView` yüzünden
yazma alanı klavyeyle birlikte doğru davranmaz ve mesaj listesi ekranın boş kalan yerini
kullanmaz.

**Önerim:** `ClassChatScreen` tam ekran sohbete dönsün:
`AppBar(title: grup adı)` + gövde `Column(Expanded(mesaj listesi), yazma alanı)`,
`resizeToAvoidBottomInset` ile klavye. `ClassChatCard`'ın "kart" kabuğu ve
`messageListHeight` parametresi kaldırılır (madde 4 uygulanınca kartın başka çağıranı
kalmıyor). Parametre bırakılırsa aynı "kart içinde kart" bir gün geri gelir.

---

## 3) Grup değiştir butonu → sohbet/ayarların yanına

**Doğrulandı.** Buton `classroom_screen.dart:108-119`, sekmenin üst eylem şeridinde tek
başına duruyor (`Icons.swap_horiz`). Sohbet + ayarlar ise aşağıda, grup adının sağında
(`_CompactGroupHeader`, `classroom_screen.dart:257-270`).

**Bu taşımanın iki gizli zorunlu adımı var — atlanırsa yeni hata çıkar:**

1. Üst şerit boşalınca `buildTabActionBar` **`null` döner** (`core/navigation/tab_action_bar.dart:20`).
   O zaman gövdeyi çağıran ekran `SafeArea(bottom: false)` ile sarmak zorunda; yoksa
   kamp ateşi durum çubuğunun altına girer. (Kazanç tarafı: ekran görüntüsündeki
   ~48px + durum çubuğu payı kadar ölü alan tamamen kalkar, kamp ateşi yukarı gelir.)
2. Tanıtım turu çapası `_groupSwitcherTourAnchor` (`classroom_screen.dart:38` ve `:112`)
   yeni butona taşınmalı. Taşınmazsa Gruplar turundaki "grup değiştir" adımı hedefsiz
   balon olarak ekranın ortasında açılır (`features/tours/app_tours.dart`, `switcherAnchor`).

**İsim sığması (senin uyarın doğru):** 3 adet varsayılan `IconButton` = ~144px dokunma
alanı; uzun grup adı ellipsis'e düşer. Çözüm ikonları küçültmek:
`visualDensity: VisualDensity.compact` + daraltılmış `constraints` ile üçü ~108px'e iner.
Sıra önerim: **grup değiştir → sohbet → ayarlar** (soldan sağa), çünkü "değiştir" en sık
kullanılan ve şu an en solda (üst şeritte sağ üstte ama tek başına).

---

## 4) Grup ayarlarında sohbet kartı kalksın

**Doğrulandı.** `classroom/widgets/class_detail_screen.dart:287-289` — "--- Sohbet ---"
başlığıyla `ClassChatCard(group: group)` duruyor; `import` satırı `:30`.

Not: bu dosyanın kendi yorumunda (satır 226-229) **aynı hatanın bir kez daha yaşandığı**
yazıyor: davet kodu hem başlıkta hem detayda duruyordu, iki kopya farklı davranıyordu,
WP-446'da tek kanonik yere indirildi. Sohbet aynı tuzağın ikinci örneği. Kaldırılınca
`ClassChatCard`'ın tek çağıranı sohbet ekranı kalır → madde 2 ile birlikte tek WP olmalı.

---

## 5) Kamp ateşinde birine tıklayınca açılan yerde dürtme olsun

**Doğrulandı.** `classroom/widgets/campfire_scene.dart:826-905` (`_showCamperDetails`):
açılan alt sayfada yalnız hayvan çizimi, isim, durum, bugünkü toplam ve o anki oturum var.
Dürtme yok, rapor etme yok, profile gitme yok.

Dürtme mantığı şu an `class_detail_screen.dart` içinde **private**:
`_NudgeButton` (`:1001`), `_MuteNudgeButton` (`:1010`), `_sendNudge` (`:1145`).
Doğrudan kopyalanırsa iki uygulama ayrışır ve biri şu kuralları kaçırır:
- hata metinleri (`core/l10n/nudge_error_text.dart`),
- karşı tarafın susturma tercihi (`mutedNudgeSenderIdsProvider`),
- sunucu tarafı odak koruması (`supabase/migrations/0116_nudge_focus_guard.sql`,
  testi `supabase/tests/042_nudge_focus_guard.test.sql`).

**Önerim:** dürtme butonu paylaşılan bir bileşene çıkarılsın (ör.
`features/classroom/widgets/nudge_action.dart`), hem üye listesi hem kamp ateşi sayfası
onu kullansın. Kendi kendini dürtme gizlenmeli; engellenmiş üye zaten tıklanamıyor.

---

## 6) Taç kademeleri (XP eşikleri) bulunamıyor

**Doğrulandı ve tarifin birebir tutuyor.**
- Kademe listesini açan fonksiyon: `core/widgets/crown_tiers_sheet.dart:11` (`showCrownTiers`).
- **Tek çağıranı** `profile/widgets/gamification_card.dart:158` — yani yalnız Profil
  ekranındaki avatarın tacına basınca açılıyor. Bunu bir kullanıcının kendiliğinden
  bulması gerçekten çok zor.
- Başarımlar ekranı: `achievements_screen.dart` → `SocialProfileScreen` → `AchievementShowcase`.
  Senin tarif ettiğin "solda rütbe adı, sağında toplam XP" satırı =
  `profile/widgets/achievement_showcase.dart:684-739` (`_CrownHeader`). **Tıklanabilir değil.**
  Hemen altındaki 6 kademe şeridi de (`:791-825`) tıklanabilir değil.

**Önerim:** `_CrownHeader` `InkWell` ile sarılıp `showCrownTiers(context, currentXp: xp)`
açsın; aynı şey kademe şeridine de bağlansın. Keşfedilebilirlik için satırın sağına küçük
bir `ⓘ`/`chevron` ipucu koymak yeterli — yeni ekran gerekmiyor, var olan sayfa
ikinci (ve doğru) kapıdan açılıyor.

---

## 7) "Timer diagnostic log" (Sayaç tanılama kaydı) nedir?

Kısa cevap: **kullanıcı ayarı değil, sayacın kara kutusu.**

- Ne yapar: her sayaç geçişini `olay + neden + sonuç` olarak cihazda saklar
  (`core/observability/timer_diagnostic_journal.dart:10-30`). WP-430'da eklendi.
- Neden var: v56'daki dört şikayet ("ayna cihazdan durdurma", "kendiliğinden başlama",
  "aralıklı senkron", "sekiz saatlik hayalet koşu") hep "bazen oluyor" sınıfındaydı ve
  elimizde olayın hangi sırayla olduğunu gösteren tek bir kayıt yoktu.
- Ekran neden eklendi: kayıt WP-430'dan beri tutuluyordu ama `app/lib` içinden
  **hiç okunmuyordu** — yani kimse göremiyordu (`timer_journal_screen.dart:12-24`).
  WP-490'daki hayalet koşu teşhisinin 2. adımı doğrudan bu kayda bağlıydı.
- Gizlilik: kayıt cihazdan çıkmaz; yalnız sen "Kaydı paylaş" dersen JSON olarak paylaşılır.
  Kimlikler tuzlanmış kısa özete çevrilir, serbest metin/e-posta/token saklanmaz, TTL'li.
- **Senin için pratik faydası:** sayaçla ilgili tuhaf bir şey yaşarsan (durmadı, kendi
  başına başladı, süre atladı) o ekrandan paylaş → hangi komutun geldiğini ve uygulanıp
  uygulanmadığını kesin görürüz, "bende olmuyor" döngüsü biter.

🔴 **Ama yeri yanlış.** Şu an `Ayarlar > Hesap` altında, "Hesabımı yönet" ile
"Verilerimi dışa aktar" arasında (`settings_screen.dart:213-230`). Normal kullanıcı için
orada olmamalı — bu, 8. maddeyle aynı sorunun öbür yüzü: Ayarlar'da kullanıcı işi ile
geliştirici işi karışmış.

### Görünürlük kararı (sahip sorusu 2026-08-08: "admin'e mi alsak?")

**Öneri: admin değil, gizli geliştirici kapısı (Android deseni).**
`Ayarlar > Hakkında` ekranındaki sürüm satırına 7 kez basınca açılan gizli mod; tanılama
kaydı yalnız o mod açıkken görünür. Maliyet: bir sayaç + prefs'te bir bool. Migration yok,
sunucu rolü yok, gizlilik sözleşmesi değişmiyor.

Gerekçe — **admin-only aracın varlık sebebini öldürür.** Kaydın değeri *başkasının*
başına gelen, tekrar üretilemeyen hataları kanıtlayabilmek. Kayıt görünürlükten bağımsız
olarak zaten her cihazda tutuluyor; admin kapısı üretimini değil yalnız **okunmasını**
engeller → veri toplanıyor ama ulaşılamıyor, en kötü kombinasyon. Gizli kapıda sahip bir
arkadaşına telefonda "Hakkında > sürüme 7 kez bas > paylaş" diyerek 20 saniyede kaydı
alabilir; admin-only'de bu imkânsız.

**❌ Reddedilen alternatif — geri bildirime ek olarak iliştirmek** (önceki turda önerilmişti,
kanıt görülünce geri çekildi): `feedback_tickets.attachment_path` var ama ek dosya
**yalnız görsel** — `image/jpeg|png|webp` listesi sunucudaki güvenlik fonksiyonuyla
zorlanıyor (`0096_report_attachments.sql:130`). JSON eklemek o güvenlik fonksiyonuna
migration atmayı gerektirir; mesaj alanına gömmek de olmaz (1200 karakter sınırı).
Yılda birkaç kez kullanılacak bir şey için güvenlik yoluna dokunmak kötü takas.

🔴 **Zamanlama şartı:** bu taşıma **madde 10 kapanmadan yapılmaz.** 3 saniyelik gecikmenin
tek kanıt kaynağı bu ekran; erişilebilir kalmalı. WP-F zaten sıranın sonunda.

---

## 8) SSS Ayarlar'ın en altına

**Doğrulandı.** Şu an: `Ayarlar > Sürüm ve Güncellemeler > SSS`
(`profile/about_screen.dart:182-188` → `features/support/faq_screen.dart`). İki kat derinde
ve "Hakkında" başlığı altında kimse yardım aramaz.

**Önerim:** Ayarlar'ın en altına kendi bölümü — **Yardım**: SSS + Geri bildirim
(geri bildirim şu an `settings_screen.dart:338-344`'te "Hakkında ve yasal" bölümünde).
Hakkında ekranındaki SSS bağlantısı kalabilir; ekran tek ve kanonik (`FaqScreen`),
ikinci kapı zararsız.

---

## 9) Görünen ad ve grup adına karakter sınırı (yeni madde, 2026-08-08)

**Doğrulandı — durum sandığımdan kötü: sınır hiçbir katmanda yok.**

Dört giriş noktasının **hiçbirinde** `maxLength` yok:

| Yer | Dosya:satır |
|---|---|
| Profil > görünen adı düzenle | `profile/profile_screen.dart:241` |
| Grup adını değiştir | `classroom/widgets/class_detail_screen.dart:327` |
| Grup oluştur | `classroom/widgets/class_switcher.dart:211` |
| Kayıt ekranı (ad alanı) | `auth/auth_screen.dart:52` (`_nameController`) |

Sunucu tarafı da boş: `supabase/migrations/*.sql` içinde `profiles.display_name` ya da
`study_groups.name` için **hiçbir `char_length` kısıtı yok.** Karşılaştırma — sohbet 500,
dürtme mesajı 120, geri bildirim 80/1200, görev başlığı 80, tema adı sınırlı. Yani
proje bu deseni biliyor, sadece iki en görünür alana uygulanmamış.

🔴 **Sessiz tutarsızlık:** `0032_public_group_discovery.sql:96` grup adını **64 karakterde
kesiyor/reddediyor**, ama yalnız keşif akışında. Yani 64'ten uzun adlı bir grup
oluşturulabiliyor ama herkese açık listede görünemiyor — kullanıcıya hiçbir açıklama
çıkmadan. Sınır konulunca bu da kendiliğinden kapanır.

**Nerede kırılır:** kamp ateşinde hayvanın altındaki isim etiketi, sıralama satırları,
`_CompactGroupHeader`'daki grup adı (madde 3'te üçüncü ikon eklenince alan daha da daralıyor),
bildirim metinleri, dürtme bildirimi. Çoğu yerde `ellipsis` var yani patlamıyor — ama
100 karakterlik ad her yerde "Mehmet Ali Yıl…" oluyor ve kimse kimseyi ayırt edemiyor.
Ayrıca sınırsız ad bir moderasyon yüzeyi (uzun spam metni isim alanına yazılabiliyor).

**Önerim (sayıyı sahip seçer — kozmetik iş kuralı gereği önce önizleme):**
görünen ad **24**, grup adı **30**. Gerekçe: kamp ateşi etiketi ve üç ikonlu grup başlığı
bu civarda kırpılmadan duruyor. Uygulama sırasında önce parametrik önizleme çıkarılır,
sahip sayıyı onaylar, sayı teste bağlanır.

**Üç katman birlikte gitmeli**, yoksa yarım iş olur:
1. İstemci: `maxLength` + trim (kullanıcı sınırı görsün, sayaç görünsün),
2. Sunucu: `check (char_length(btrim(...)) between 1 and N)` — istemci atlanabilir,
3. Mevcut veri: sınırdan uzun adlar zaten varsa migration onları kesmeli ya da kısıt
   `not valid` başlayıp temizlik sonrası doğrulanmalı; yoksa migration production'da düşer.

---

## 10) Sayacı kapatırken bazen ~3 saniye bekleme (yeni madde, 2026-08-08)

**Sahip:** *"bazen sayacı kapatırken 3 sn bekliyor sonra kapatıyor, her zaman olmuyor,
genelde olmuyor. Baya denedim, neden olduğunu anlamadım."*

**Kodda kuvvetli aday buldum — ama bu bir hipotez, cihazda kanıtlanmadı.**

`stop()` (`data/providers/study_providers.dart:2037`) sayacı ekrandan kaldıran `_finish()`
çağrısını **en sona** koyuyor (satır 2136, `finally` içinde). Ondan önce sırayla şunlar
`await` ediliyor:

1. **`_reconcileBackgroundTimer()`** (satır 2111) — native sayaçla uzlaşma. Kritik detay:
   zaten devam eden bir uzlaşma varsa bu çağrı **ona katılıp bitmesini bekler**
   (`:1343-1352`) ve o tur kendini bir kez daha tekrarlayabilir (`_reconcileAgainRequested`,
   `:1355-1365`). Uygulama az önce öne geldiyse ya da bildirimden/widget'tan komut
   düştüyse bu tur zaten koşuyor olabilir → **"bazen"in birinci kaynağı.**
2. **`await _verifiedStartFuture`** (satır 2113) — sunucuda doğrulanmış başlatma hâlâ
   havadaysa, durdurma onun bitmesini bekler.
3. **`_finalizeVerifiedRun(token)`** (satır 2127 → `:2268`) — içinde **iki ardışık ağ
   çağrısı** var: `repo.finalizeLiveRun(token)` ve hemen ardından
   `repo.recordVerifiedSessionRollout(...)`. İkisi de `await` ediliyor.
   🔴 İkisi de **çevrimdışı kuyruğu atlayıp doğrudan Supabase'e gidiyor**
   (`repositories/offline/offline_first_study_repository.dart:58-59` ve `:66-72` —
   `_remote`'a düz geçiş, outbox yok).

**Zincirde hiçbir `timeout` yok.** Yani toplam süre = uzlaşma + iki ardışık ağ turu.
Bağlantı sıcakken hepsi 100-200 ms (sahibin "genelde olmuyor"u). Mobil veri uyanıyorsa,
Supabase bağlantısı yeniden kuruluyorsa ya da bir retry varsa 3 saniye tam buradan çıkar.

**Kullanıcı neden "hiçbir şey olmadı" görüyor:** `isStopping` anında `true` oluyor ve
Durdur butonu **yalnızca griye düşüyor** (`classroom/widgets/study_timer_card.dart:399`).
Spinner yok, yazı değişmiyor, sayaç ekranda durmaya devam ediyor. Yani gecikme 3 saniye
ama his "buton öldü".

### Ne yapılmalı — sıra önemli

**Adım 0 (kanıt, koddan önce):** sahip belirtiyi bir kez daha yaşadığında
`Ayarlar > Hesap > Sayaç tanılama kaydı > Kaydı paylaş`. Kayıtta `stopRequested` satırının
saati ile `runTerminal` satırının saati arasındaki fark = aranan 3 saniye; `reason`/`outcome`
alanları da hangi adımda geçtiğini söyler. **Bu kayıt tam olarak bu sınıf hata için
yazılmıştı** (madde 7). Tahminle kod değiştirmenin bedeli bu dosyada çok yüksek.

**Adım 1 (düşük risk, sıra bozulmuyor):** `recordVerifiedSessionRollout` **saf telemetri** —
kullanıcının Durdur'unu bekletmesi için hiçbir sebep yok. `await`siz hâle getirilirse
zincirden bir ağ turu düşer. Hata yolundaki telemetri zaten `.catchError((_){})` ile
ateşle-unut yazılmış (`:2281-2288`); başarı yolunda `await` edilmesi tutarsızlık.

**Adım 2 (his düzeltmesi, davranışı değiştirmez):** Durdur butonu `isStopping` iken
spinner + "Durduruluyor…" göstersin. Gecikmeyi çözmez ama "ölü buton" hissini bitirir.

**Adım 3 (dikkat — kanıtsız yapılmaz):** zincire timeout. `_finish()` zaten `finally`de
olduğu için timeout eklemek *"kayıt sunucuya yazılmadan sayaç kapandı"* riskini doğurur.

### 🔴 Bu dosyaya dokunacak ajan için uyarı

`stop()` gövdesindeki her `await`in başında **hangi hatayı kapattığını anlatan bir yorum**
var ve hepsi gerçek saha hatası: WP-250 *"sıra değiştirilemez"* (toplam süre şişmesi),
WP-241/243 (eşzamanlı uzlaşma → DB'de çift oturum), WP-246 D2/D4 (çift durdurma, hata
yutulunca sayaç durmuyor), WP-233 (bildirimden başlatılan sayaç uygulamadan durdurulamıyor),
WP-104 (süreç erken ölürse oturum kaybı). **Sırayı "hızlansın diye" değiştirmek bu
hatalardan birini geri getirir** ve geri gelenler 3 saniyeden çok daha kötüdür
(şişmiş toplam, hayalet oturum, çift kayıt).

Kural: önce kayıt (Adım 0), sonra en dıştaki güvenli katman (Adım 1-2), zincirin
sırasına ancak kanıtla dokun.

---

## Sahibin fark etmediği ek bulgular

**E1 — Kamp ateşinde ölü dokunma davranışı (madde 5 ile aynı dosya).**
`campfire_scene.dart:440-443` bir `GestureDetector` kuruyor ve `SocialProfileDialog.show`
açıyor. Ama çocuğu `_CritterBody` kendi `GestureDetector`ını `HitTestBehavior.opaque` ile
kuruyor (`:694-698`) ve arena'da **en içteki kazanıyor** → o dış handler hiç çalışmıyor.
Yani kodda iki farklı "üyeye tıklayınca ne olsun" tasarımı var, biri tümüyle ölü.
Dürtme eklenmeden önce hangisinin kanonik olduğuna karar verilmeli; yoksa "bazen profil
açılıyordu galiba" diye kalıcı bir kafa karışıklığı üretir.

**E2 — İki kartta zaman bombası.**
`goal_card.dart` ve `period_summary_card.dart` `SingleChildScrollView`'ü **koşulsuz**
kuruyor; diğer kartlarda olan `unbounded` kontrolü bunlarda yok. Bugün yalnız Ana Sayfa'da
kullanıldıkları için patlamıyorlar, ama kartlar taşınabilir; biri Gruplar listesine
eklenirse sınırsız yükseklikte layout hatası verir.

**E3 — Test boşluğu (madde 1'in "neden sessizce girdi" cevabı).**
Var olan `group_scroll_nesting_test.dart` yalnız sınırsız yolu koruyor. Ana Sayfa'nın
sınırlı hücresi için "kart üstünden sürükle → dış sayfa kaydı" testi yok.

**E4 — Ayarlar bilgi mimarisi bir bütün olarak elden geçmeli.**
Tanılama kaydı Hesap'ta, geri bildirim "Hakkında ve yasal"da, SSS iki kat derinde.
Madde 7 + 8 + bu, tek bir "Ayarlar yeniden düzeni" WP'si olarak yapılmalı; parça parça
yapılırsa üç ayrı l10n turu ve üç ayrı test turu maliyeti çıkar.

**E5 — `ClassChatCard`'ın çift kimliği.** Madde 2 + 4 birlikte yapılmazsa kart hem
tam ekranda hem ayarlarda yaşamaya devam eder; `messageListHeight` parametresi kaldığı
sürece "kart içinde kart" geri dönebilir.

**E6 — Ekran görüntüsündeki ölü üst alan.** Gruplar sekmesinde tek bir ikon için tam bir
eylem şeridi + durum çubuğu payı harcanıyor. Madde 3 uygulanınca bu alan tamamen kalkıyor
— görünür kazanç, ek maliyeti yok.

---

## Önerilen paketleme (sıra: kullanıcı acısı / maliyet)

0. **WP-0 · Sayaç durdurma gecikmesi** — madde 10. Önce kanıt (tanılama kaydı), sonra
   telemetri `await`ini düşür + butona spinner. Kritik dosya, tek başına bir tur.
1. **WP-A · Kart kaydırma tuzağı** — madde 1 + E2 + E3. En yüksek acı, her ekranda
   hissediliyor. Ortak yardımcı + 13 çağrı + Home drag testi.
2. **WP-B · Gruplar üst düzeni** — madde 3 + 4 + E6. Küçük ama görünür; tur çapası ve
   `SafeArea` adımları unutulmamalı.
3. **WP-C · Tam ekran sohbet** — madde 2 + E5. B'den sonra, çünkü B kartın son çağıranını
   kaldırıyor.
4. **WP-D · Kamp ateşi üye sayfası: dürtme** — madde 5 + E1. Ortak dürtme bileşeni.
5. **WP-E · Taç kademeleri keşfedilebilirliği** — madde 6. En ucuz kazanç, istersen 1. sıraya alınabilir.
6. **WP-F · Ayarlar yeniden düzeni** — madde 7 + 8 + E4. Tek turda, yeni l10n anahtarları
   burada toplansın.
7. **WP-G · Ad karakter sınırları** — madde 9. İstemci + sunucu + mevcut veri temizliği
   birlikte; sayı için önce önizleme, sahip onaylar.

Not: B, C, E, F yeni l10n anahtarı üretir → `scripts/l10n_audit.py` kapısı her WP'de
yeşil bırakılmalı, aksi halde `test_all.py` kırmızıya döner.

---

## Kapanan kararlar

- **Madde 1 (2026-08-08, sahip):** sığdığında kaydırıcı hiç kurulmasın, taşarsa kart
  içinde kayabilsin. ✅ karar verildi.
- **Madde 7 görünürlüğü (2026-08-08):** admin kapısı değil, sürüm satırına 7 kez basmayla
  açılan gizli geliştirici modu. Geri bildirime iliştirme fikri kanıtla reddedildi
  (ek dosya yalnız görsel). Uygulama madde 10 kapandıktan sonra, WP-F içinde.

## Açık soru kalmadı

Sıradaki tetik sahipten gelecek ("şu maddeyi yap"). O zamana kadar kod ellenmiyor.
