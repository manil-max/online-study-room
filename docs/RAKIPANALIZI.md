# Rakip Analizi — Kullanıcı Yorumlarından Çıkan Şikayetler ve İstenen Özellikler

> **Amaç:** "Online Çalışma Sınıfı" (YPT benzeri grup çalışma uygulaması) ürününün rakiplerinin
> mağaza yorumlarında **beğenilmeyen yanlar**, **bildirilen hatalar** ve **istenip de olmayan
> özellikler** listesi.
> **Kapsam:** Ürün stratejisi / backlog girdisi. Bu doküman kod veya mimari kararı değiştirmez;
> `backlog.md`'ye aday madde üretmek için referanstır.
>
> Son güncelleme: 2026-07-28 · Kaynak: YPT Google Play yorum dökümü (birinci el) + web araştırması

---

## 0. Yöntem ve kanıt kalitesi

Bu dokümanda **iki farklı kanıt seviyesi** var; karıştırmayın:

### A) Birinci el — YPT Google Play (§2.1)
Proje sahibinin Play Store'dan aldığı ham yorum dökümü ayrıştırıldı:

| Ölçüm | Değer |
|---|---|
| Ayrıştırılan kayıt | 557 (geliştirici cevapları dahil) |
| **Gerçek kullanıcı yorumu** | **439** |
| Geliştirici (Pallo Inc) cevabı | 118 |
| Tarih aralığı | Temmuz 2021 – Temmuz 2026 (2026: 237, 2025: 111, 2024: 94) |
| Şikayet/istek işareti taşıyan yorum | **293 (%66)** |
| Uygulamanın Play puanı | 4.5 (75.5K oy) · yorum ortalaması 4.4 (65.1K) |

> ⚠️ **Sınır:** Döküm **yıldız bilgisi içermiyor** (Play'in metin kopyasında yok) ve **dil filtresi
> İngilizce**. Yani "kaç yıldız verilmiş" bilinmiyor; sayımlar "kaç yorumda bu konu geçiyor"
> ölçüsüdür. Ayrıca bu bir *örneklem*: Play varsayılan olarak "en yararlı" yorumları öne çıkarır,
> rastgele örneklem değildir. Türkçe yorum neredeyse yok (1 kayıt) — TR pazarı için ayrı döküm gerek.

### B) İkinci el — diğer rakipler (§2.2 ve sonrası)
`apps.apple.com`, `play.google.com`, `justuseapp.com`, `producthunt.com` bu ortamdan çekilemedi
(HTTP 403 / bot koruması). Diğer uygulamalar için elimizde **arama motoru özetleri** var; birebir
alıntı değil, **tema/sinyal** olarak okunmalı. Güven işaretleri:
🟢 birden fazla kaynak · 🟡 tek kaynak · ⚪ dolaylı/çıkarım.

---

## 1. Rakip haritası

| Katman | Uygulamalar | Bize yakınlık |
|---|---|---|
| **Doğrudan** (grup + canlı durum + süre takibi) | **YPT (Yeolpumta)**, **FLIP (RinaSoft)**, **StudyStream** (+ Study Together), Study Spaces / StudyClock / Prodpod / GroupStudyTimer (web odaları) | Aynı iş: birlikte çalışma hissi + süre + sıralama |
| **Yarı doğrudan** (eşlik/hesap verebilirlik) | **Focusmate**, Flow Club, Caveday, StudyBuddies.live | Canlı beraberlik var, ders/istatistik derinliği yok |
| **Dolaylı** (tekil odak + oyunlaştırma) | **Forest**, **Flora**, **Study Bunny**, Focus To-Do, Session, Milki, FocusFlow | Sayaç + motivasyon; grup zayıf |
| **Komşu** (planlama/alışkanlık) | Habitica, My Study Life, Ders Takip / Öğrenci Takip (TR), YKS konu takip uygulamaları | Plan/görev tarafı; canlı presence yok |

---

## 2.1 YPT — 439 gerçek yorumun analizi (BİRİNCİ EL)

### 2.1.0 Önce: insanlar bu uygulamayı neden seviyor

Rakibin gücünü anlamadan açığını doğru okuyamayız. 439 yorumda tekrarlayan övgüler:

1. **"Neredeyse her şey ücretsiz"** — açık ara en sık övgü. *"I love that mostly all the features
   are free and not behind pay walls"*, *"they considered that their audience are students with no
   way to earn money themselves"*.
2. **Başkalarını çalışırken görmek** — *"seeing others studying is like a boost"*; kullanıcılar
   3 saatten 10–12 saate çıktıklarını yazıyor.
3. **Derinlemesine istatistik/insight** — ders bazlı, gün/hafta/ay, yıllık analiz.
4. **Tek uygulamada her şey** — beyaz gürültü, sözlük, hesap makinesi, flashcard, planner, D-Day.
5. **Kişiselleştirme** — temalar, studicon (çalışma karakteri), ev ekranı düzeni.

> **Ders:** Bizim ürün küçük/kapalı gruba odaklı; "ücretsizlik" ve "canlı görünürlük" bizde de var.
> Ama YPT'nin *tek uygulamada araç yoğunluğu* (sözlük/hesap makinesi/beyaz gürültü/flashcard)
> beklenti çıtasını yükseltmiş durumda.

### 2.1.1 Şikayet temaları — sayımla

Aşağıdaki tablo "kaç yorumda bu konu geçiyor / bunların kaçında şikayet-istek işareti var"
şeklinde okunur. (Konu geçen her yorum şikayet değildir; ör. "no ads" övgüsü de "reklam"
temasında sayılır.)

| Tema | Şikayet işaretli / toplam | Yorum |
|---|---|---|
| **Çökme / donma / lag / açılmama** | **69 / 79** | En büyük tek başlık. Güncelleme sonrası beyaz ekran, uygulamanın hiç açılmaması, sayaç ekranında kilitlenme |
| **Bildirim / alarm sesi** | 46 / 67 | Pomodoro bitişinde ses yok, bildirim 2 dk gecikiyor, mola bitişi duyurulmuyor |
| **To-do / planner / takvim bugları** | 43 / 69 | Görevler kayboluyor, tarihler kayıyor, tekrarlayan görevler bozuluyor |
| **Flame / ödeme / premium** | 38 / 53 | Para ödeyip ürün gelmemesi, "çalışarak kazanılamıyor" itirazı, bölge kilidi |
| **Sunucu / bağlantı hatası** | **36 / 41** | "Failed to connect to server" — 2021'den 2026'ya kesintisiz şikayet |
| **Süre kaybı / yanlış kayıt** | **34 / 39** | Saatlerin sıfırlanması, yanlış güne yazılması, hiç kaydedilmemesi |
| **Allowed apps (zorunlu engelleme)** | 33 / 40 | Kapatılamıyor, tek tek seçtirme, sistem uygulamalarını da engelliyor, bazı cihazlarda hiç çalışmıyor |
| **Güncelleme regresyonu** | 32 / 41 | "Eski sürümü geri verin" — özellikle Ağustos 2025 UI değişimi |
| **Sohbet bugları** | 29 / 40 | Okundu bilgisi hatalı, foto/video gönderilemiyor, mesajlar yüklenmiyor |
| **Hesap / giriş / veri kaybı** | 29 / 33 | Girişte kilitlenme, şifre sıfırlamada hata, yılların verisinin kaybı |
| **Dil sorunu** | 26 / 34 | Uygulama kendiliğinden Endonezce/Korece'ye dönüyor, geri döndürülemiyor |
| **Gün sınırı 05:00 / yanlış gün** | **21 / 24** | Gece/sabah erken çalışanların saatleri düne yazılıyor |
| **Saat dilimi / bölge kilidi** | 16 / 24 | TZ eşleşmezse uygulamaya girilemiyor; ülke listesinde eksikler |
| **Çevrimdışı mod** | 16 / 19 | Çevrimdışı saatler toplamlara/gruba işlenmiyor; çevrimdışıyken sayaç durdurulamıyor |
| **Grup üye limiti (50)** | 15 / 21 | İyi gruplar dolu; bekleme listesi isteniyor |
| **Sıralama / rekabet** | 14 / 28 | Haftalık sıralama yanlış hesaplanıyor; sıralama yerine seviye isteniyor |
| **Reklam** | 12 / 19 | 2026'da eklenen açılış/başlangıç reklamları büyük tepki |
| **Moderasyon / güvenlik** | 10 / 13 | Müstehcen gruplar, spam, rapor sisteminin işlememesi |
| **PC / masaüstü / web** | 6 / 13 | Talep net; geliştirici "web'i değerlendiriyoruz" demiş |
| **Widget** | 3 / 3 | Az konuşuluyor ama konuşulduğunda hep "çalışmıyor" |

### 2.1.2 Şikayetler — kanıtlı ayrıntı

#### (1) Sunucu bağımlılığı: uygulamanın en ölümcül tasarım hatası
Her şey sunucuya bağlı. İnternet giderse **sayacı durduramıyorsun**, çünkü durdurma isteği
sunucuya gidiyor:

> *"if wifi goes out suddenly and you want to pause the timer, it wont let you and show error.
> which is annoying bcs you wont be able to use other apps bcs of it."* (16 Nis 2026)

> *"I clicked on one of my allowed apps in the middle of a study session and it showed that there
> is a server error… I went to stop the timer and it wont let me do that as well. I literally had
> to force stop the app from my settings."* (19 Ağu 2021 — **5 yıl önce aynı şikayet**)

> *"PLEASE STABILISE YOUR SERVERS I BEG OR JUST PROVIDE TODO OPTION OFFLINE"* (18 Haz 2026)

Kampüs/kurumsal wifi'de tamamen çalışmadığı, sadece mobil veriyle açıldığı da raporlanmış.

> **Bizim için:** Bu, Drift + yerel-önce (offline-first) mimarimizin **doğrudan karşılığı**.
> "Ağ yoksa sayaç yine de çalışır ve durdurulabilir" bizde pazarlık konusu olmamalı; rakibin
> 5 yıldır çözemediği şey bu.

#### (2) Süre kaybı ve yanlış güne yazma — güveni bitiren hata
> *"When I wanted to take a break, I paused the timer, and you know what? When I returned to work
> and opened ypt, MY DAMN PROGRESS WAS LOST EVERY TIME."* (15 Tem 2026)

> *"THE TIMER STOPS ONLY AFTER MANY SECONDS OF SPAMMING THE PAUSE BUTTON! … Today my study log was
> lost (reset to 00:00) for no reason. update: It happened again! 2 hours of studying lost."*

> *"The timer pause/stop button often does not work, so the timer keeps running and creates **fake
> study time**. I also frequently get the error message 'Null check operator used on a null value'"*
> (10 May 2026 — sızmış Dart/Flutter hatası; rakip de Flutter kullanıyor)

> *"it's the next day and it still records that it's the previous day… I go to edit the logs on both
> days, both days get reduced to the exact same hours even though I deleted different hours"*

Geliştiricinin kendi cevabı: *"There was an issue where records around 5:00 AM were being logged as
duplicate time."*

Ayrıca **"stop" butonunun aslında sil anlamına gelmesi**:
> *"If I need to pause, I hit the 'stop' forgetting that obviously the devs can't speak English and
> 'stop' means 'delete'. Fix this. I have lost track of my records twice."*

#### (3) Gün başlangıcı 05:00'e sabit — en net ve en ucuz kazanç
En az 6 ayrı yorumda, farklı ülkelerden, aynı istek:

> *"I wake 3:30 am so 1 hr go to yesterday session… please change into 12:am"*
> *"I begin studying at 3 AM, but since the app resets at 5 AM, any activity I log at that time is
> still counted under the previous day."*
> *"for people like me who pull all nighters… that makes the whole time tracking thing useless,
> plus in all the groups it just shows that I haven't studied today."*

Geliştiricinin cevabı "05:00 politikadır" şeklinde — yani **çözmeyi reddettikleri bir talep**.

#### (4) Manuel/düzenlenmiş sürenin gruba yansımaması — bizim mimarimizin tam hedefi
> *"add the option to add a timeslot that has already passed if in case someone forgets to start the
> timer. it may sound little but it ruins the insight feature because most people do forget."*
> *"when u add a study log through editing which was missed earlier, such additional time doesn't get
> reflected in your total focus time when seeing in any group u have joined."*
> *"edited record hours doesn't get counted in group. It's kinda frustrating like sometimes I work by
> keeping my phone away so I can't just add those hours."*
> *"agar maine time log edit kiya to home screen pai adjustment ho gaya but group mai show nahi ho raha"*
> *"there is option to cut off time but no option to add"*

Yani: **manuel giriş var ama grup muhasebesine girmiyor.** Kullanıcı ekran görüntüsü paylaşıp
gruba "gerçekten çalıştım" diye kanıt sunmak zorunda kalıyor.

> **Bizim için:** `study_sessions.source` (`live|manual`) alanı ve immutable
> `study_session_group_attribution` tasarımı bu sorunu doğru çözebilecek yerde. Kritik karar:
> manuel süre gruba **girsin** (aksi halde YPT'nin hatasını tekrarlarız) ama **işaretli** girsin
> (aksi halde hile kapısı açılır).

#### (5) Zorunlu uygulama engelleme — "özellik" sanılan terk sebebi
YPT'nin ayırt edici özelliği aynı zamanda en çok küfür edilen yanı:

> *"I just wish I didn't have to block all the apps on my phone! I can focus without the app FORCING
> me to stay off of TikTok"*
> *"there really, REALLY needs to be an 'disable disabling apps' feature… Disabling apps during study
> session should be an option, not an obligation."* (Türk kullanıcı, 28 Şub 2026)
> *"I had to pick every single phone function to allow in order for me to be able to leave the app or
> answer a call."*
> *"Even the main app search menu from my phone got blocked."* / *"it blocks settings as well"*
> *"I want to use my phone freely while studying, I don't need this feature… I may not keep using this
> app because of this."*

Bir de **çalışmadığı** durumlar: *"I can just simply turn on the timer, and go to home screen and start
using other apps"*, *"if you go to home screen and at the same time lock the phone… you can easily use
any app"*. Yani hem zorla dayatıyor hem güvenilir değil.

İyi fikir olarak gelen öneri: *"allowed apps could be dependent on what you're studying"* (derse göre
izinli uygulama listesi).

#### (6) Güncelleme regresyonu — Ağustos 2025 vakası (ders kitabı örneği)
Yeni "Planner" ana ekranı ve zorunlu takvim entegrasyonu geldi, kullanıcılar ayaklandı:

> *"The new update is worst. I used this app as it was minimal, simple and less time consuming…
> after the newest update everyone has been changed"*
> *"I can't see my subjects anymore… I have to compulsorily set a time limit for my to dos which is
> extremely annoying. I do not want to see the calendar"*
> *"you Removed the only 2 thing I was here for I'll leave this app & switch to my previous study app"*

Geliştirici geri adım attı ve **"Klasik / Yeni ana ekran" seçeneği** ekledi:
> Pallo Inc: *"we have completed an update that allows you to choose the previous version (Classic) as
> your home screen"* → sonrasında *"Thanks for bringing the option of choosing home screen type. Now the
> app is better than before."*

Kaldırılan diğer şeylerin yasları: tam ekran masa modu, ikonsuz ekran koruyucu (burn-in), to-do'yu
işaretleyip tamamlama, veri sıfırlama, story ekleme, eski aesthetic tema ayarı.

> **Bizim için:** Kalite programındaki sürüm kapıları + "kullanıcıya görünen davranış değişiminde
> geçiş yolu" kuralı bu vakayla doğrulanıyor. Büyük UI değişimi yapılacaksa **eski düzeni seçenek
> olarak bırakmak** kanıtlanmış çözüm.

#### (7) Sohbet ve sosyal katman
> *"Messages sometimes don't load, read counts are wrong, and chats randomly close. As a gc owner, I
> can't even assign or revoke warnings right now. Check-ins fail, offline hours don't log, and the
> timer is completely broken. These aren't minor bugs—they ruin the core experience. Please focus on
> stability instead of pushing more updates."* (13 Nis 2026 — tek yorumda tüm tablo)
> *"A single person reacted it will show all the reactions, you can't send pics in chat, whenever you
> send any message in group it shows almost everyone has seen your message."*
> *"I will see notifications for messages, but when I click it open the messages are not there. it takes
> 2 or 4 hours for it to appear."*

İstenenler: alıntı/reply, görsel + video, özel mesaj (DM), "high five"/emoji tepkisi (şu an sadece
"wake up" dürtmesi var).

#### (8) Moderasyon ve güvenlik — açık pazarın vergisi
> *"some guys are making groups to ask for nudes and stuff and I m tired of reporting them"*
> *"Pls do something about vulgar grps spamming in India region… report feature doesnt even work.
> This is a serious issue given teens use this app and even chat ain't moderated."*
> *"The worst part is you cannot report private groups."*
> *"there was a person who being extremely racist… even after being banned, they were still able to
> join back"*
> *"even after putting someone in Block List they can still text in the Group"*

Ters yön de var — **yanlış raporla haksız ceza**:
> *"my account was wrongly restricted after a false report. I lost all my points, data, groups, and
> connections without warning. Support hasn't replied at all."*

> **Bizim için:** Davet kodlu kapalı grup modeli bu riski büyük ölçüde bertaraf ediyor — bu bizim
> *yapısal avantajımız*, pazarlama mesajı olabilir. Yine de: engellenen kullanıcı gerçekten
> susturulabilmeli, admin işlemleri `admin_audit_log`'a düşmeli (WP-33) ve ceza gerekçesi
> kullanıcıya görünmeli.

#### (9) Para modeli: reklamın gelişi ve "çalışarak kazanamama"
> *"A study timer meant for focus should not have Ads. The 1st thing that I see after turning on a
> timer is Popup Ad."*
> *"great app but slowly little by little they are infusing ads. Consider adding a one time purchase
> for ad free interface, instead."*
> *"whenever i open the app ads pop out and sometimes there won't be a cancellation sign"*
> *"I don't support this new subscription based model."*
> *"we have to buy flames with real money 🫠. Developers, let us earn the flames for the hours that we
> study. It doesn't have to be 1 flame per 1 hour, you can make it 8 hours = 1 flame."*
> *"flames are very hard to get and can't be obtained unless you see an ad"*
> *"we can't have premium themes cause we're in Iran"* (bölge kilidi)

Ödeme hataları da tekrar ediyor: *"I did pay for the flames but I didn't even get them"* (birden çok
yorum; destek bazen hızlı çözüyor, bazen cevapsız).

> **Bizim için:** 0 TL / reklamsız duruş, rakibin en taze öfke kaynağının tam karşısında. Eğer
> ileride kozmetik/ödül ekonomisi kurarsak: **kazanım çalışmayla olmalı**, satın almayla değil.

#### (10) Hesap, veri ve göç
> *"I logged out and signed back in using the same email… all my 2025-2026 records disappeared, and
> the app reverted back to my old 2024 data."*
> *"when i resetting my password it says 'lan is required' and not recover my password and by this i
> lost my 3 yrs of all study data"*
> *"Doesn't work on new phone, a whole year of data is lost. Support offered absolutely no help"*
> *"pls i request to add an option to change the gmail of an account… i want my 2 years of data"*

> **Bizim için:** Şifre sıfırlama runbook'u (`docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md`) ve hesap silme/
> retention kararı zaten var. Eksik olabilecek: **e-posta değiştirme** ve **cihaz değişiminde
> veri sürekliliğinin görünür garantisi**.

#### (11) Bölge/saat dilimi kapısı — girişte kullanıcı kaybı
> *"The app doesn't let me set my time zone to Denmark because it says it doesn't match my phone's
> time zone, and then says your phone's time zone is in Denmark."*
> *"the app checks the phone's time zone e.g. GMT+1 but internally it uses a floating point number
> GMT+1.0 and it thinks they are different so doesn't let the user access the app."* ← float
> karşılaştırma hatası, kullanıcıyı uygulamaya **hiç sokmuyor**
> *"my country (greece) is not one of the region options"* · *"I'm from Nigeria and I had to set England"*
> *"the app had defaulted me to England instead of Asia… I can't join my friends who are in Asia"*

Bölge ayrıca **hangi gruplara girebileceğini** belirliyor: *"why limit groups you can join to ones
within your region? It would be great if I could use the app together with international friends."*

> **Bizim için:** Bizde bölge kavramı yok, davet kodu var — bu kapı bizde hiç açılmıyor. Ama ders:
> **onboarding'de zorunlu, doğrulanamayan bir alan koyma.**

#### (12) Bildirim ve alarm — Pomodoro'nun sessiz ölümü
> *"when timer ends, person only gets to know this by opening the app, and not via timer notification,
> which fails the purpose of pomodoro"*
> *"The Pomodoro timer notifications are delayed by about 2 minutes most of the time."*
> *"there's no Alarm sounds or Rings to confirm the end time of break time. Therefore, there comes time
> when I take long breaks without knowing."*
> *"add pause and play button in notification bar of timer"*
> *"disable the notifications during the time when the timer is on"* (odak sırasında DND)

#### (13) Widget
> *"after the update, the home page widgets are not working well and are just blank or don't display data"*
> *"if I use the subject selection widget it opens the app for me and starts the timer but doesn't
> update it on the widgets"*
Geliştirici 2022'de *"What kind of widget do you want?"* diye sormuş — yani widget hâlâ olgunlaşmamış.

#### (14) Hile ve sıralamanın güvenilirliği
> *"Imagine someone studying for 8:30 hrs continuously without even a single break lol… Once I set
> timer and went to sleep… tomorrow morning it shows 8 hrs concentration. **Nobody knows whether u
> genuinely study or not.**"*
> *"Instead of showing everyone's ranking, divide students study time into levels, just like what
> Duolingo does. Let others in the study group see the name of the allowed app… That way, we know
> that person isn't cheating."*
> *"The weekly rankings in the study groups are often incorrect and it ruins the whole competition."*
> *"i see someone with less study time ranking 8 [while] i [am] ranking 2225… this always make me loss
> my feeling to study"*

Rakip 18–20 saatte sayacı kesiyor ama bu da yeni sorun doğuruyor:
> *"can you adjust so that it still keeps track of time after 20 hours? Sometimes I swipe off the app
> thinking it has switched off the timer but the timer continues to run and my study time before that
> is not tracked as it has reached 20 hours."*

### 2.1.3 YPT kullanıcılarının açıkça istediği özellikler (talep listesi)

Sıklık sırasına yakın, hepsi gerçek yorumlardan:

| # | Talep | Örnek |
|---|---|---|
| 1 | **PC / Windows / web sürümü** | *"provide a version on a Windows laptop… When a solution to this is found, I will give it full stars"* — 2021'den beri tekrarlıyor, geliştirici "web'i düşünüyoruz" diyor |
| 2 | **Gün başlangıç saatini seçebilme** | 05:00 dayatması; 00:00 veya 03:00 isteyenler |
| 3 | **Geçmişe süre ekleme + bunun gruba yansıması** | "sayacı açmayı unuttum" senaryosu |
| 4 | **Streak (seri) sistemi ve günlük hedef** | *"add study goals like 3 hours a day and… a streak system"* |
| 5 | **Sıralama yerine seviye/lig** | Duolingo benzeri kademe önerisi |
| 6 | **Arkadaş listesi + arkadaş liderlik tablosu** (gruptan bağımsız) | *"option to add friends and have a section called friends separate from group section"* |
| 7 | **Özel mesaj (DM)** | *"no option to search an individual's account and message them privately"* |
| 8 | **Tepki/emoji ("high five", ateş emojisi)** | Şu an yalnız "wake up" dürtmesi var |
| 9 | **Sesli/görüntülü canlı ortak seans, grup çağrısı** | *"adding live study sessions would enhance the app… pin others' videos without direct chats"* |
| 10 | **Molada studicon'un dinlenme pozu** | Karakterin durumu görünür olsun |
| 11 | **Mola bakiyesi / oran sistemi (5:1)** ve alt görevler | *"Break balance system that gives you breaktime according to your study schedule"* |
| 12 | **Çalışma dışı kategoriler** (spor, uyku, hobi) ayrı sayılsın | *"i track my whole day here… make different categories for study and non study"* |
| 13 | **Ders klasörleri / uzun ders adı** | 50 ders arasında kaydırma derdi |
| 14 | **AMOLED siyah tema, burn-in korumalı tam ekran** | Uzun seans + OLED gerçeği |
| 15 | **Grup üye limitinin artması + dolu gruba bekleme listesi** | 50 kişi sınırı |
| 16 | **Grup için çoklu kategori** | Tek sınav kategorisi yetmiyor |
| 17 | **Takvim entegrasyonu (Google + Notion)** | Mevcut Google bağlantısı bozuk raporlanıyor |
| 18 | **Ekrandan hızlı başlat (floating buton/kısayol)** | Uygulamayı açmadan sayaç |
| 19 | **Oturum bazlı (sitting) kırılım** | Toplam yerine her oturuş ayrı görünsün |
| 20 | **Ekran süresi takibi / offline+online modun birlikte çalışması** | |

---

## 2.2 FLIP (RinaSoft) — Kore *(ikinci el)*

- 🟡 Çalışma günlüğüne fotoğraf yüklerken **süre yanlış yansıyor**.
- 🟡 5M+ indirmeye rağmen **düşük puan yoğunluğu** (2.000+ düşük oy) → kronik istikrar/UX sorunu.
- ⚪ Global çalışma grubu + "FLIP TALK" panosu var; moderasyon ince nokta.

## 2.3 StudyStream (+ Study Together) — kameralı 7/24 odalar, Play ~3.8 *(ikinci el)*

| # | Şikayet | Güven |
|---|---|---|
| 1 | Ücretsiz katmanda süre tavanı (ilk günler 2 saat, 5 gün sonra 1 saat) | 🟢 |
| 2 | Agresif paywall — "birden fazla grup gönderisi için bile abonelik" | 🟡 |
| 3 | Fiyat öğrenciye ağır (~10 $/ay) | 🟢 |
| 4 | Abonelik/ödeme sorunları, destek cevapsız | 🟡 |
| 5 | Kamerayı açıp kapatınca çökme | 🟡 |
| 6 | Güncelleme sonrası profil/istatistik güncellenmiyor | 🟡 |
| 7 | **Taciz ve moderasyon zaafı** — mağdur cezalandırılabiliyor | 🟢 |
| 8 | Kamera açık oda modeli mahremiyet endişesi | 🟡 |

## 2.4 Focusmate *(ikinci el)*

- 🟢 Fiyat sürekli sürtünme; 🟢 **no-show / geç iptal** ("5 seansın 2'sinde partner gelmedi");
  🟡 ilgisiz partner; 🟡 iptalde kötü destek.
- 🟢 Güçlü yön: **randevulu, taahhütlü** yapı yüksek sadakat üretiyor (özellikle ADHD kullanıcıları).

## 2.5 Forest *(ikinci el)*

- 🟢 Kaldırılan istatistikler → aboneliğe yönlendirme algısı; 🟡 görev/checklist eksik;
  🟡 oyunlaştırma "çocuksu"; 🟡 entegrasyon yok; 🟡 ağaç kaybolması, zayıf alarm.

## 2.6 Flora — "arkadaşlarla Forest" *(ikinci el)*

- 🟢 **Ekran açık kalmadan sayaç ilerlemiyor**; 🟢 tek cihaz kısıtı, senkron yok;
  🟡 **host çıkınca herkesin ağacı ölüyor** (kolektif ceza); 🟡 arkadaş davet edilmezse ilerleme durur.

## 2.7 Study Bunny — reklam modelinin ne yapılmaması gerektiği *(ikinci el)*

- 🟢 Aşırı/atlanamayan reklam; 🟢 çevrimdışı kilitleme; 🟡 cihazlar arası taşıma ücretli;
  🟡 **7 dk üstü mola cezası**; 🟡 düşük ses kalitesi.

## 2.8 Habitica *(ikinci el)*

- 🟢 Karmaşık onboarding, sosyal özellikler öğreticiden kopuk; 🟢 buglı/hantal;
  🟡 sosyal özellikler menülerde gömülü.

## 2.9 Planlama/takip komşuları *(ikinci el)*

- 🟢 My Study Life: büyük güncelleme sonrası "eski sürümü geri verin" isyanı, yeni UI hantal,
  reklam + ücretli özellik tepkisi; 🟡 veri kaybı; 🟡 sürekli oturum düşmesi.
- 🟡 Focus To-Do: senkron aksaklıkları, cihazlar arası senkron ücretli.
- 🟡 TR pazarı: AI plan koçu modası; öğrenciler rekabet/sıralama, düello, oyunlaştırma istiyor.

## 2.10 Yeni oyuncuların kapatmaya çalıştığı açıklar *(pazar sinyali)*

Masaüstü/web + senkron · ortak çalışma odaları · hesapsız/çevrimdışı çalışma ·
**anti-hile / idle tespiti** ("ghost hours") · paylaşılan pomodoro + lofi + isteğe bağlı kamera ·
streak analitiği · temalı odalar (lofi kafe, dark academia…).

---

## 3. Sentez — en sık tekrarlayan şikayet temaları (tüm rakipler)

| # | Tema | Kanıt gücü |
|---|---|---|
| 1 | **Süre/sayaç doğruluğu** (kayıp saatler, yanlış gün, durdurulamayan sayaç, arka planda ölen sayaç) | 🟢 birinci el (34/39) + Flora, FLIP |
| 2 | **Ağ bağımlılığı / çevrimdışı çalışamama** — sunucu düşünce ürün tamamen ölüyor | 🟢 birinci el (36/41) |
| 3 | **Kararlılık: çökme, donma, açılmama** — özellikle güncelleme sonrası | 🟢 birinci el (69/79) |
| 4 | **Güncelleme regresyonu** — özellik kaldırma, zorunlu yeni UI | 🟢 birinci el (32/41) + My Study Life, Forest |
| 5 | **Zorunlu/katı mekanikler** (uygulama engelleme, mola cezası, kolektif ceza) | 🟢 birinci el + Study Bunny, Flora |
| 6 | **Reklam/paywall agresifliği ve para karşılığı ödül** | 🟢 birinci el + Study Bunny, StudyStream |
| 7 | **Sosyal katman kalitesi** — sohbet bugları, moderasyon, taciz, no-show | 🟢 birinci el + StudyStream, Focusmate |
| 8 | **Hile ve sıralamanın güvenilirliği** | 🟡 birinci el (net ama az sayıda), GroupStudyTimer konumlandırması |
| 9 | **Rekabet baskısı** — sıralama düşük sıradakini kaçırıyor | 🟡 birinci el + oyunlaştırma araştırması |
| 10 | **Hesap/veri sürekliliği** — giriş, şifre sıfırlama, cihaz değişimi, e-posta değiştirme | 🟢 birinci el (29/33) |
| 11 | **Bildirim/alarm güvenilirliği** | 🟢 birinci el (46/67) |
| 12 | **Masaüstü/web ve çoklu cihaz eksikliği** | 🟢 birinci el + Flora, FocusFlow |
| 13 | **Onboarding'de gereksiz kapı** (bölge/TZ zorunluluğu, karmaşık ilk kurulum) | 🟢 birinci el + Habitica |

---

## 4. Bizim ürüne yansıması

### 4.1 Rakip açığına denk gelen mevcut kararlarımız

| Rakip açığı (kanıt) | Bizdeki karşılık |
|---|---|
| Sunucu düşünce sayaç durdurulamıyor (36/41) | **Drift (SQLite) yerel depo** + offline-first akış |
| Arka planda ölen sayaç | **flutter_foreground_task + Kotlin foreground service** |
| Masaüstü yok, 5 yıldır isteniyor | **Windows birinci sınıf hedef** + Compact Focus penceresi |
| Widget çalışmıyor/olgunlaşmamış | **home_widget** ile Android widget hedefi |
| Süre yanlış gruba/güne yazılıyor | `study_sessions.group_id` kaldırıldı; immutable `study_session_group_attribution` |
| Çoklu cihaz karmaşası | **V3 global timer/presence**, `state_version` + idempotent komut |
| Hile/veri güvenilirliği | **Server-authoritative XP/başarı** (Edge Functions + pg_cron) |
| Moderasyon şeffaflığı yok, rapor işlemiyor | `admin_audit_log` (WP-33), `feedback_tickets` |
| Reklam/paywall öfkesi | **0 TL hedefi, reklamsız kapalı grup** |
| Açık pazarın taciz/spam vergisi | **Davet kodlu kapalı grup** — yapısal bağışıklık |

### 4.2 Riskler — rakiplerin düştüğü çukurlar bizde de mümkün

1. **Sayaç doğruluğu ürünün canı.** 439 yorumun en sert cümleleri buradan geliyor. Çoklu cihaz +
   çevrimdışı + gün sınırı kesişimi, tek bir yanlış muhasebede güveni bitirir.
2. **"Stop" ≠ "sil".** Rakipte kullanıcılar yanlış butonla saatlerini sildi. Bizim sayaç
   kontrollerinde yıkıcı eylem net ayrılmalı ve geri alınabilir olmalı.
3. **Kolektif ceza tasarımı** (Flora dersi) — kamp ateşi/grup hedefi mekaniklerinde "birinin
   hatası herkesi cezalandırıyor" hissinden bilinçli kaçınılmalı.
4. **Rekabet baskısı:** küçük grupta bile açık sıralama en yavaş üyeyi kaçırabilir.
   Sıralamayı gizleme / kişisel hedefe göre yüzde / grup toplamı görünümleri erken gelmeli.
5. **Güncelleme regresyonu:** rakibin 1 numaralı öfke sebebi. Büyük UI değişiminde
   **eski düzeni seçenek olarak bırakmak** kanıtlanmış çözüm (YPT Ağustos 2025 vakası).
6. **Manuel süre ikilemi:** girmezse "unuttum" öfkesi, kontrolsüz girerse hile. Çözüm: gruba
   **girsin ama `source=manual` işaretiyle ayırt edilebilsin.**
7. **Onboarding kapısı koyma:** rakip, doğrulanamayan bölge/TZ eşleşmesi yüzünden kullanıcıyı
   uygulamaya hiç sokamıyor. Bizde zorunlu alanları asgaride tut.

### 4.3 Backlog'a aday maddeler (öncelikli)

| Öncelik | Madde | Kanıt |
|---|---|---|
| **P0** | Çevrimdışıyken sayaç başlat/durdur/kaydet — ağ yokken ürün ölmesin | 36/41 sunucu şikayeti; 5 yıldır çözülmemiş |
| **P0** | Sayaç durumu ve gün kırılımının çakışmasız muhasebesi (çoklu cihaz + gece yarısı + 05:00) | 34/39 süre kaybı/yanlış gün |
| **P1** | Gün başlangıç saati ayarı (kullanıcı seçer) | 21/24; rakip "politika" deyip reddediyor |
| **P1** | Manuel süre ekleme/düzenleme + `manual` rozeti + **gruba yansıması** | En az 5 ayrı yorum, rakipte kırık |
| **P1** | Sıralamayı gizleme / "sadece kendi hedefim" modu | Rekabet baskısı + yanlış sıralama şikayetleri |
| **P1** | Pomodoro/mola bitişinde **gerçek alarm** (ses + titreşim) ve bildirimden duraklat/başlat | 46/67 bildirim teması |
| **P2** | Streak + günlük hedef görünürlüğü | Doğrudan talep |
| **P2** | Sohbette görsel + link, güvenilir okundu bilgisi, alıntı/reply | 29/40 sohbet şikayeti |
| **P2** | Boşta kalma (idle) tespiti + "süre nasıl sayıldı" şeffaflığı | Uyuyup 8 saat yazdıran vaka |
| **P2** | Grup içi rapor + engelleme **gerçekten sussun** + admin işlem kaydı | Rakipte engellenen hâlâ yazabiliyor |
| **P2** | Odak/uygulama engelleme **isteğe bağlı** olsun (varsayılan kapalı) | 33/40 allowed apps şikayeti |
| **P3** | Molada karakter/durum görselinin değişmesi (dinlenme pozu) | Tekrarlayan istek |
| **P3** | Ders klasörleri, uzun ders adı, oturum bazlı kırılım | Tekrarlayan istek |
| **P3** | AMOLED siyah tema + burn-in korumalı tam ekran odak | Uzun seans + OLED |
| **P3** | Çalışma dışı kategoriler (spor/uyku) toplam süreye karışmasın | Tekrarlayan istek |
| **P3** | Hesap e-postası değiştirme + cihaz değişiminde veri sürekliliği | 29/33 hesap teması |

---

## 5. Sıradaki araştırma adımları

1. **Türkçe yorumlar** — mevcut dökümde 1 tane var. Play'de dil filtresi TR ile YPT + rakip
   dökümü alınırsa TR öğrenci beklentisi (YKS/KPSS bağlamı) birinci elden çıkar.
2. **Yıldız bilgisi** — döküm yıldızsız. 1–2 yıldızlı yorumlar ayrı alınırsa "terk sebebi"
   sıralaması netleşir.
3. **Diğer rakipler için ham döküm** — öncelik: StudyStream, FLIP, Study Bunny, Flora.
4. **Rakip sürüm notları** — YPT'nin son 12 ay changelog'u, hangi şikayetin ne zaman kapandığını
   gösterir; bizim için "hangi açık hâlâ açık" haritası olur.

---

## 6. Kaynaklar

**Birinci el:** YPT Google Play yorum dökümü (proje sahibi tarafından sağlandı; 439 kullanıcı
yorumu, Tem 2021 – Tem 2026, İngilizce).

**İkinci el (web):**
- YPT: [Google Play](https://play.google.com/store/apps/details?id=com.pallo.passiontimerscoped&hl=en) ·
  [App Store yorumları](https://apps.apple.com/gb/app/ypt-study-group/id1441909643?see-all=reviews&platform=iphone) ·
  [JustUseApp](https://justuseapp.com/en/app/1441909643/ypt-yeolpumta/reviews)
- FLIP: [Google Play](https://play.google.com/store/apps/details?id=kr.co.rinasoft.yktime&hl=en_IN)
- StudyStream: [Google Play](https://play.google.com/store/apps/details?id=live.studystream.app&hl=en) ·
  [iOS yorumları](https://appshunter.io/ios/app/6461722416/reviews) ·
  [Taciz/moderasyon yazısı](https://medium.com/@IonutMehh/studystreams-harassment-problem-3e87db32a336)
- Focusmate: [Trustpilot](https://www.trustpilot.com/review/www.focusmate.com?page=3) ·
  [flat.social incelemesi](https://flat.social/guides/focusmate-review)
- Forest: [JustUseApp](https://justuseapp.com/en/app/866450515/forest-stay-focused/reviews) ·
  [Product Hunt](https://www.producthunt.com/products/forest/reviews)
- Flora: [JustUseApp](https://justuseapp.com/en/app/1225155794/flora-green-focus/reviews) ·
  [Google Play](https://play.google.com/store/apps/details?id=com.appfinca.flora.android)
- Study Bunny: [JustUseApp](https://justuseapp.com/en/app/1478345385/study-bunny-focus-timer/reviews)
- Habitica: [Trustpilot](https://www.trustpilot.com/review/habitica.com) ·
  [alternatif analizi](https://habi.app/insights/habitica-alternatives/)
- Planlayıcılar: [My Study Life](https://mwm.ai/apps/my-study-life-school-planner/910639339) ·
  [Focus To-Do incelemesi](https://goalsandprogress.com/focus-to-do-review-2026/)
- Yeni oyuncular: [GroupStudyTimer](https://groupstudytimer.in/) · [Study Spaces](https://studyspaces.org/welcome) ·
  [Prodpod](https://prodpod.app/virtual-study-rooms) · [StudyClock](https://studyrooms.studyclock.com/)
- Oyunlaştırma riski: [Growth Engineering — Dark Side of Gamification](https://www.growthengineering.co.uk/dark-side-of-gamification/) ·
  [Practido — leaderboard stresi](https://practido.com/blog/7-smart-ways-to-use-leaderboards-for-students/)
- TR pazarı: [Technopat tartışması](https://www.technopat.net/sosyal/konu/yks-calismak-icin-mobil-uygulama-onerisi.2730743/)
