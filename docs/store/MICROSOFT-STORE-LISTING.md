# Microsoft Store — mağaza sayfası metinleri (kopyala-yapıştır)

> **Ne işe yarar:** Partner Center'da uygulamanın "Store listing" sayfasını
> doldururken buradaki kutuları olduğu gibi kopyalayıp yapıştırırsın. Hiçbir
> metni yazmana gerek yok.
>
> **Nasıl kullanılır:** Partner Center'da her dil için **ayrı** bir listing
> vardır. Önce `Turkish (Turkey)` listing'ini aç ve **TR** bloklarını yapıştır,
> sonra `English (United States)` listing'ini aç ve **EN** bloklarını yapıştır.
>
> **Gönderim yolu ve paket:** `docs/WINDOWS-STORE-YOLU.md`.
> **Bu metinler nereden çıktı:** uydurulmadı; `app/lib` içindeki gerçek
> ekranlardan, `docs/legal/PRIVACY-POLICY.*.md` ve
> `docs/play-store/DATA-SAFETY.md` dosyalarından çıkarıldı. Play mağaza metniyle
> (`docs/play-store/YAYIN-PLANI.md` §2) aynı anlatımı sürdürür — iki mağazada
> çelişen söz yok.
>
> **Sürüm:** 2026-08-09 · uygulama sürümü `1.0.62+62`

---

## 0. Önce bunu yap: adı rezerve ederken iki ad al

Partner Center'da bir ürün için **birden fazla ad rezerve edilebilir** ve her
dil listing'i bu adlardan birini gösterir. İkisini birden al:

| Rezerve edilecek ad | Nerede görünecek |
|---|---|
| `Odak Kampı` | Türkçe listing |
| `Focus Camp` | İngilizce listing |

`Odak Kampı` alınmışsa yedek: `Odak Kampı - Focus Camp`.
(Uygulama kodunda İngilizce arayüz adı zaten `Focus Camp` —
`app/lib/l10n/app_localizations_en.dart:188`.)

---

## 1. Product name

**TR listing için seç:**
```
Odak Kampı
```

**EN listing için seç:**
```
Focus Camp
```

### Short title (isteğe bağlı, en fazla 50 karakter)
TR:
```
Odak Kampı
```
EN:
```
Focus Camp
```

---

## 2. Short description

> Partner Center sınırı: **1.000 karakter**. Arama sonuçlarında ve kartlarda
> görünür.

**TR:**
```
Arkadaşlarınla birlikte çalış, süreni takip et. Kronometre, geri sayım ve pomodoro modlu bir çalışma sayacı; grubundaki herkesin o an çalışıp çalışmadığını gösteren kamp ateşi ekranı; günlük ve haftalık istatistikler, seri, XP ve başarımlar. Ctrl+Shift+M ile küçülen mini odak penceresi masaüstünün üstünde kalır, çalışırken süreyi görmeye devam edersin.
```

**EN:**
```
Study with your friends and keep track of your time. A study timer with stopwatch, countdown and pomodoro modes; a campfire screen that shows who in your group is studying right now; daily and weekly statistics, streaks, XP and achievements. Press Ctrl+Shift+M for a compact focus window that stays on top of your other windows while you work.
```

---

## 3. Description

> Partner Center sınırı: **10.000 karakter**. Aşağıdaki metinler ~1.900 karakter,
> rahatça sığar. Partner Center bu alanda basit biçimlendirmeyi (satır başı,
> madde işareti) destekler; olduğu gibi yapıştır.

**TR:**
```
Odak Kampı, arkadaşlarınla birlikte çalışmayı kolaylaştıran bir çalışma takip uygulamasıdır. Aynı hesapla telefondan da girersin; grupların, derslerin ve istatistiklerin her iki cihazda da aynıdır.

ÇALIŞMA SAYACI
Sayaç üç modda çalışır: kronometre, geri sayım ve pomodoro. Her oturuma bir ders seçersin, süre o derse yazılır. Geçmiş oturumlarını tek tek görebilir, yanlış girilen bir oturumu düzeltebilirsin.

MİNİ ODAK PENCERESİ
Ctrl+Shift+M ile uygulama küçük bir odak penceresine küçülür. Ctrl+Shift+P ile o pencereyi her zaman üstte tutarsın — açık belgelerinin ve tarayıcının üstünde süreyi görmeye devam edersin.

BİRLİKTE ÇALIŞ
Bir grup kur, arkadaşının davet koduyla katıl ya da herkese açık grupları keşfet. Kamp ateşi ekranında grubundaki herkesin o an çalışıp çalışmadığını tek bakışta görürsün. Grup sohbeti, dürtme ve günlük hedefle birbirinizi takipte tutarsınız.

NE YAPTIĞINI RAKAMLARLA GÖR
Günlük ve haftalık istatistikler, ders bazında dağılım, çalışma ısı haritası, saat saat yoğunluk, seri takibi, kişisel rekorlar, grup liderlik tablosu, XP ve başarımlar. Verilerini dışa aktarabilirsin.

KENDİNE GÖRE
Ana ekranı istediğin kartlarla kendin dizersin. Hazır temalardan birini seç ya da Tema Stüdyosu'nda kendi temanı kur.

KLAVYE KISAYOLLARI
Ctrl+1…5 sekmeler arası geçiş · Ctrl+, ayarlar · F5 yenile · Ctrl+Shift+M mini pencere · Ctrl+Shift+P her zaman üstte

GÜVENLİK VE GİZLİLİK
Grup sohbetinde bir mesajı veya kullanıcıyı bildirebilir, istemediğin kişiyi engelleyebilirsin. Reklam yok, uygulama içi satın alma yok, konum verisi toplanmıyor. Hesabını ve verilerini uygulama içinden silmeyi talep edebilirsin.

Uygulama Türkçe ve İngilizce çalışır.

BİLMEN GEREKENLER
• Uygulama bir hesap açmanı ister ve çalışmak için internet bağlantısı gerekir.
• Alarm ve zamanlayıcı sesi Windows bildirimleri üzerinden çalmaz; bu özellikler Android sürümüne özeldir. Windows'ta çalışma sayacı, mini pencere ve görev listesi kullanılır.
```

**EN:**
```
Focus Camp is a study tracker that makes studying with friends easier. You sign in with the same account on your phone, so your groups, subjects and statistics are the same on both devices.

STUDY TIMER
The timer runs in three modes: stopwatch, countdown and pomodoro. You pick a subject for each session, and the time is recorded against that subject. You can review past sessions one by one and correct a session that was logged wrong.

COMPACT FOCUS WINDOW
Press Ctrl+Shift+M and the app shrinks into a small focus window. Ctrl+Shift+P keeps that window always on top, so the elapsed time stays visible above your documents and your browser.

STUDY TOGETHER
Create a group, join one with a friend's invite code, or browse public groups. The campfire screen shows at a glance who in your group is studying right now. Group chat, nudges and a daily goal keep everyone on track.

SEE WHAT YOU ACTUALLY DID
Daily and weekly statistics, a per-subject breakdown, a study heatmap, hour-by-hour activity, streak tracking, personal records, a group leaderboard, XP and achievements. You can export your data.

MAKE IT YOURS
Arrange the home screen with the cards you want. Pick a ready-made theme, or build your own in the Theme Studio.

KEYBOARD SHORTCUTS
Ctrl+1…5 switch tabs · Ctrl+, settings · F5 refresh · Ctrl+Shift+M compact window · Ctrl+Shift+P always on top

SAFETY AND PRIVACY
You can report a message or a user in group chat, and block anyone you do not want to hear from. No ads, no in-app purchases, no location data. You can request deletion of your account and your data from inside the app.

The app works in Turkish and English.

GOOD TO KNOW
• The app requires an account and an internet connection.
• Alarm and timer sounds do not ring through Windows notifications; those features are specific to the Android version. On Windows you get the study timer, the compact window and the task list.
```

---

## 4. What's new in this version

> Partner Center sınırı: **1.500 karakter**. **İlk gönderimde** aşağıdaki
> "ilk sürüm" metnini kullan. Sonraki gönderimlerde `CHANGELOG.md` içindeki o
> sürümün "Yenilikler" başlığından 3-5 madde kopyalanır.

**TR (ilk gönderim):**
```
Odak Kampı'nın Microsoft Store'daki ilk sürümü.

• Kronometre, geri sayım ve pomodoro modlu çalışma sayacı
• Ctrl+Shift+M ile mini odak penceresi, Ctrl+Shift+P ile her zaman üstte
• Kamp ateşi: grubunda kimin şu an çalıştığını gösteren canlı ekran
• Grup sohbeti, dürtme ve günlük hedef
• Günlük/haftalık istatistik, ısı haritası, seri, XP ve başarımlar
• Kendi düzenlediğin ana ekran ve Tema Stüdyosu
• Türkçe ve İngilizce
```

**EN (ilk gönderim):**
```
The first release of Focus Camp on the Microsoft Store.

• Study timer with stopwatch, countdown and pomodoro modes
• Compact focus window with Ctrl+Shift+M, always on top with Ctrl+Shift+P
• Campfire: a live screen showing who in your group is studying right now
• Group chat, nudges and a daily goal
• Daily/weekly statistics, heatmap, streaks, XP and achievements
• A home screen you arrange yourself, plus the Theme Studio
• Turkish and English
```

---

## 5. Product features

> Partner Center sınırı: **en fazla 20 madde**, her madde **200 karakter**.
> Aşağıda 12 madde var — her satırı ayrı bir kutuya yapıştır.

**TR:**
```
Kronometre, geri sayım ve pomodoro modlu çalışma sayacı
Her oturuma ders seçme; ders bazında süre dağılımı
Ctrl+Shift+M ile mini odak penceresi, Ctrl+Shift+P ile her zaman üstte tutma
Kamp ateşi ekranı: grubunda kimin şu an çalıştığını canlı gösterir
Davet koduyla gruba katılma, herkese açık grupları keşfetme
Grup sohbeti, dürtme ve günlük hedef
Günlük ve haftalık istatistikler, çalışma ısı haritası, saatlik yoğunluk
Seri takibi, kişisel rekorlar ve grup liderlik tablosu
XP, başarımlar ve rozetler
Kartlarla kendin dizdiğin ana ekran
Hazır temalar ve kendi temanı kurabildiğin Tema Stüdyosu
Türkçe ve İngilizce arayüz
```

**EN:**
```
Study timer with stopwatch, countdown and pomodoro modes
Pick a subject per session; see time broken down by subject
Compact focus window (Ctrl+Shift+M) and always-on-top mode (Ctrl+Shift+P)
Campfire screen: see live who in your group is studying right now
Join a group with an invite code, or browse public groups
Group chat, nudges and a daily goal
Daily and weekly statistics, study heatmap, hour-by-hour activity
Streak tracking, personal records and a group leaderboard
XP, achievements and badges
A home screen you arrange yourself with cards
Ready-made themes plus a Theme Studio for building your own
Turkish and English interface
```

---

## 6. Search terms

> Partner Center sınırı: **en fazla 7 terim**, her terim **30 karakter**,
> hepsi birlikte en fazla **21 kelime**. Kullanıcıya görünmez, yalnız aramada
> kullanılır. Her dil listing'ine kendi terimlerini gir.

**TR (7 terim):**
```
çalışma sayacı
pomodoro
odaklanma
ders takibi
birlikte çalışma
kronometre
verimlilik
```

**EN (7 terim):**
```
study timer
pomodoro
focus
study tracker
study with friends
stopwatch
productivity
```

---

## 7. Category / Subcategory

| Alan | Değer |
|---|---|
| **Category** | `Productivity` |
| **Subcategory** | yok — Productivity kategorisinin alt kategorisi yoktur |

Kategori tüm diller için **tektir**, her listing'de ayrı seçilmez.

Partner Center Productivity'yi kabul etmezse tek yedek: `Education` →
`Study aids`. Başka seçenek deneme.

---

## 8. Copyright and trademark info

> Partner Center sınırı: **200 karakter**. İsteğe bağlı ama doldurulması iyidir.

**TR:**
```
© 2026 Odak Kampı. Tüm hakları saklıdır.
```

**EN:**
```
© 2026 Focus Camp. All rights reserved.
```

> Not: Buradaki ad, Partner Center'da girdiğin **publisher display name** ile
> aynı olmalı. Kayıtta farklı bir ad (örn. kendi adın soyadın) çıkarsa bu iki
> satırdaki "Odak Kampı" / "Focus Camp" yerine onu yaz.

---

## 9. Additional license terms

> Partner Center sınırı: 10.000 karakter. Boş bırakılırsa Microsoft'un
> standart uygulama lisans sözleşmesi geçerli olur. Bizim ayrı kullanım
> koşullarımız **canlı**, bu yüzden buraya kısa bir yönlendirme yaz.

**TR:**
```
Bu uygulamanın kullanımı, Microsoft Standart Uygulama Lisans Sözleşmesi'ne ek olarak Odak Kampı Kullanım Koşulları'na tabidir:
https://manil-max.github.io/online-study-room/legal/terms-tr.html

Grup sohbeti ve diğer kullanıcı içeriği için Topluluk Kuralları geçerlidir:
https://manil-max.github.io/online-study-room/legal/community-tr.html
```

**EN:**
```
Use of this app is subject to the Focus Camp Terms of Use, in addition to the Microsoft Standard Application License Terms:
https://manil-max.github.io/online-study-room/legal/terms-en.html

Group chat and other user-generated content are subject to the Community Guidelines:
https://manil-max.github.io/online-study-room/legal/community-en.html
```

---

## 10. Privacy policy URL · Website · Support contact info

> Bu üçü Partner Center'da **Properties** sayfasında ("Privacy policy URL",
> "Website", "Support contact info") istenir ve tüm diller için ortaktır.

| Alan | Değer | Durum |
|---|---|---|
| **Privacy policy URL (TR listing)** | `https://manil-max.github.io/online-study-room/legal/privacy-tr.html` | ✅ **2026-08-09'da canlı doğrulandı** |
| **Privacy policy URL (EN listing)** | `https://manil-max.github.io/online-study-room/legal/privacy-en.html` | ✅ **2026-08-09'da canlı doğrulandı** |
| **Website** | `https://manil-max.github.io/online-study-room` | ✅ canlı (yasal metinlerin dizini) |
| **Support contact info** | 🔴 **SAHİP DOLDURACAK** | repoda hiçbir destek e-postası yok |

**Neden destek adresi boş:** Bütün depoda (uygulama kodu, yasal metinler,
belgeler) tek bir destek/iletişim e-postası geçmiyor. Gizlilik politikası bile
"uygulama içi geri bildirim ve **mağaza geliştirici e-postası**" diyor — yani
o adres senin Partner Center hesabındaki adres olacak. Uydurmadım.

> Buraya yazacağın adres kullanıcıya **görünür**. Kişisel gmail'ini yazmak
> istemezsen yeni bir adres aç (örn. `odakkampi.destek@gmail.com`) ve Partner
> Center'da onu gir. Sonrasında aynı adresi `docs/legal/PRIVACY-POLICY.*.md`
> dosyalarına da yazdırmak gerekir — o ayrı bir iş, bana söyle yaparım.

**Ek olarak canlı olan yasal adresler** (Partner Center'da istenmez ama
sertifikasyonda sorulursa hazır):

- Kullanım koşulları TR/EN: `.../legal/terms-tr.html` · `.../legal/terms-en.html`
- Topluluk kuralları TR/EN: `.../legal/community-tr.html` · `.../legal/community-en.html`
- Hesap ve veri silme TR/EN: `.../legal/data-deletion-tr.html` · `.../legal/data-deletion-en.html`

---

## 11. System requirements

**Bu alanı elle doldurma — boş bırak.**

Partner Center'daki "System requirements" kutuları isteğe bağlı **donanım**
alanlarıdır (dokunmatik, kamera, bellek, DirectX…). Uygulamanın hiçbirine
özel ihtiyacı yok; boş bırakılırsa Store hiçbir gereksinim göstermez.

Minimum işletim sistemi **paketin kendisinden** okunur, listing'den değil:

| Değer | Kaynak |
|---|---|
| Windows 10 sürüm 1809 (derleme 10.0.17763.0) veya üstü | MSIX manifest `TargetDeviceFamily MinVersion` — `msix` paketi varsayılanı |
| Mimari: x64 | `app/windows/flutter/CMakeLists.txt` → `windows-x64` |
| İnternet bağlantısı gerekir | Hesap + Supabase sunucusu zorunlu (`app/lib/features/auth/auth_gate.dart`) |

İnternet gereksinimi bir donanım alanı değil — bu yüzden yukarıdaki açıklamaya
"BİLMEN GEREKENLER / GOOD TO KNOW" maddesi olarak zaten yazıldı.

---

## 12. Age rating (IARC) — hazır cevaplar

> Anketi Partner Center **sen** dolduracaksın; sorular sırayla ekrana gelir.
> Aşağıdaki tabloda hangi soruya ne diyeceğin yazıyor. **Her cevap koddan
> doğrulandı**, tahmin yok. Yanlış cevap sonradan uygulamanın kaldırılma
> sebebidir — özellikle "kullanıcılar birbiriyle etkileşebilir" sorusu.

### 12.1 İçerik soruları — hepsi HAYIR

| Soru başlığı | Cevap | Neden |
|---|---|---|
| Şiddet (gerçekçi / çizgi film / kan) | **Hayır** | Uygulamada hiçbir şiddet içeriği yok; oyun değil |
| Cinsellik / çıplaklık | **Hayır** | Yok |
| Küfür / müstehcen dil (uygulamanın kendi içeriğinde) | **Hayır** | Uygulamanın kendi metinlerinde yok. Kullanıcıların yazdıkları §12.2'deki etkileşim sorusunda beyan edilir |
| Uyuşturucu / alkol / tütün | **Hayır** | Yok |
| Kumar veya kumar benzeri | **Hayır** | Şans oyunu, sanal para, ganimet kutusu yok |
| Korku / dehşet | **Hayır** | Yok |
| Ayrımcılık / nefret | **Hayır** | Yok |

### 12.2 Etkileşim ve çeşitli sorular — dikkat edilecek yer burası

| Soru | Cevap | Kanıt (kod) |
|---|---|---|
| Kullanıcılar birbiriyle **etkileşebilir / içerik paylaşabilir mi?** | 🔴 **EVET** | Grup sohbeti `class_messages` (`supabase/migrations/0015_class_chat.sql`), dürtme (`features/classroom/widgets/nudge_action.dart`), canlı durum (`presence`) |
| Etkileşim türü: **metin** mi, sesli/görüntülü mü? | **Yalnız metin** | Sesli/görüntülü sohbet kodu yok |
| Kullanıcılar **tanımadığı kişilerle** karşılaşabilir mi? | **Evet** | Herkese açık grup keşfi var (`0032_public_group_discovery.sql`, `group_discovery_screen.dart`) — sadece davet koduyla sınırlı değil |
| Kullanıcı içeriği **denetleniyor mu / bildirme-engelleme var mı?** | **Evet** | Şikâyet (`report_ugc`, `report_sheet.dart`), engelleme (`block_user`, `blocked_users_screen.dart`), yönetici moderasyon kuyruğu, topluluk kuralları onayı (`0038_ugc_moderation.sql`) |
| Kullanıcının **konumu** başka kullanıcılara gösteriliyor mu? | **Hayır** | Kodda ve şemada hiçbir konum API'si yok (`docs/play-store/DATA-SAFETY.md` §1, §6) |
| Kullanıcı **kişisel bilgisini üçüncü taraflara** verebiliyor mu? | **Hayır** | Veri yalnız hizmet sağlayıcılarda (Supabase / opsiyonel Sentry) işlenir; satış veya reklam ağı yok |
| **Kısıtlanmamış internet erişimi** (uygulama içi tarayıcı) var mı? | **Hayır** | Uygulama içi genel amaçlı tarayıcı yok; yalnız yasal metin bağlantıları dışarıda açılır |
| **Dijital ürün satın alma / uygulama içi satın alma** var mı? | **Hayır** | Faturalandırma/satın alma paketi yok (`in_app_purchase` bağımlılığı yok) |
| **Reklam** gösteriliyor mu? | **Hayır** | Reklam SDK'sı yok (AdMob vb. bağımlılık yok) |
| **Ganimet kutusu / ücretli rastgele içerik** var mı? | **Hayır** | Yok |
| **Hedef kitle / yaş** | **13 yaş ve üzeri, genel kitle** | Gizlilik politikası §4: "13+ / genel kitle; bilerek 13 yaş altına yönelik değildir" |

**Sonuç beklentisi:** Şiddet/cinsellik/madde soruları hayır, etkileşim evet →
IARC tipik olarak düşük bir yaş derecesi verir ama üstüne "Kullanıcılar
etkileşebilir" / "Paylaşılan bilgi" etiketlerini ekler. Bu **doğru** sonuçtur,
düzeltmeye çalışma.

---

## 13. Product declarations (Partner Center → Properties)

| Beyan | İşaretle |
|---|---|
| Bu uygulama Microsoft ticaret motoru dışında satın alma sunuyor | **Hayır** |
| Bu uygulama Microsoft dışı sürücü veya NT servisine bağlı | **Hayır** |
| Bu uygulama kullanıcıların kendi aralarında iletişim kurmasına izin verir | **Evet** |
| Microsoft bu uygulamayı kullanıcılara otomatik olarak önerebilir | **Evet** |
| Bu uygulama erişilebilirlik yönergelerine göre test edildi | **Hayır** — bağımsız erişilebilirlik testi yapılmadı, işaretleme |

---

## 14. Notes for certification — **bunu boş bırakma**

> Uygulama **girişsiz kullanılamıyor** (misafir modu yok —
> `app/lib/features/auth/`). Microsoft'un test ekibi giremezse gönderim
> reddedilir. Play tarafında da aynı madde vardı (`YAYIN-PLANI.md` §7).

Yapılacak: uygulamada bir test hesabı aç (örn. `store-review@…`), bir gruba
ekle, sonra aşağıdaki metni "Notes for certification" kutusuna yapıştır ve
`…` yerlerini doldur:

```
The app requires an account. Please use the following test account:

E-mail: ...
Password: ...

The account is already a member of a study group, so the group screens
(campfire, chat, leaderboard) have content to show.

Notes:
- The app requires an internet connection; it talks to a Supabase backend.
- No in-app purchases and no ads.
- Alarm and timer sounds are Android-only features and are intentionally
  inactive on Windows.
- Compact focus window: Ctrl+Shift+M. Always on top: Ctrl+Shift+P.
```

---

## 15. Ekran görüntüleri (listing'de zorunlu)

Partner Center en az **1** masaüstü görüntüsü ister; 4 tanesi çok daha iyi
görünür. Boyut: en az **1366 x 768**, PNG.

Uygulamayı Windows'ta aç ve şu dört ekranı yakala — **her dil için ayrı**
(uygulamayı İngilizceye alıp aynı dördünü tekrar çek, toplam 8):

1. Ana sayfa (kartlarla dizili panel)
2. Gruplar → kamp ateşi ekranı
3. Çalışma sayacı (pomodoro modunda çalışırken)
4. İstatistik (haftalık grafik + ısı haritası)

Bonus 5.: mini odak penceresi (Ctrl+Shift+M) bir belgenin üstünde dururken —
bu Windows sürümünün en ayırt edici özelliği.

**Store logo (300x300):** `references/play-store/play-icon-512.png` dosyasını
300x300'e küçültmen yeterli, üzerinde yazı yok.

---

## 16. Sahibin doldurması gereken tek şey

| Alan | Neden ben dolduramadım |
|---|---|
| **Support contact info** (destek e-postası) | Depoda hiçbir destek adresi yok; bu senin Partner Center hesabının adresi olacak. Uydurmak, kullanıcıya çalışmayan bir adres göstermek olurdu |
| **Notes for certification** içindeki test hesabı e-postası/şifresi | Hesabı uygulamadan senin açman gerekiyor; şifreyi ben yazamam ve yazmamalıyım |
| **Copyright** satırındaki ad | Partner Center kaydında çıkacak yayıncı adına bağlı; kayıt henüz açılmadı |

Bunların dışında bu sayfadaki her kutu kopyala-yapıştır hazır.

---

## 17. Açık uç (bilmen gereken, listing dışı)

**MSIX paketi şu an yalnız Türkçeyi beyan ediyor.**
`app/pubspec.yaml` → `msix_config.languages: tr-tr`. Uygulama İngilizce de
çalıştığı halde paket manifesti bunu söylemiyor; Store "bu uygulama Türkçe
destekler" yazabilir ve İngilizce arayanlara daha az görünür. Düzeltmesi tek
satır (`tr-tr, en-us`) ama kod tarafı — bu belge işinin kapsamı dışında.
Söylediğinde ayrı bir WP'de düzeltilir.
