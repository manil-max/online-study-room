# 🏛️ OSR Timer Architecture & Synchronization Deep-Dive Report (Revize V2)

**Tarih:** 2026-07-21  
**Yazar:** AI Agent (Antigravity) & Bağımsız Denetçi (Claude Opus 4.8) Geri Bildirimleriyle  
**Hedef Kitle:** Senior Developer / Technical Lead  
**Kapsam:** `StudyTimerNotifier`, `StudyTimerService.kt`, UI Yüzeyleri, Çevrimdışı Kuyruk

---

## 1. Yönetici Özeti (Executive Summary)

Bu rapor, uygulamanın kalbi olan Zamanlayıcı (Timer) ekosisteminin baştan uca mimari analizini içermektedir. Bağımsız kod denetiminden (audit) geçen ilk raporumuzun üzerine, çok daha derin ve gizli kalmış mimari borçlar tespit edilmiştir.

**Tespit Edilen 4 Ana Kriz Noktası:**
1. **Çift Sayma Hilesi ve Test Körlüğü:** `stop()` anındaki yarış durumu saniyeleri değil, **tüm oturumun süresini** (örneğin 1 saat -> 2 saat) anlık olarak ikiye katlamaktadır. Testlerin bu durumu yakalayamama sebebi, test ortamında ağ gecikmesi (RTT) olmaması ve araya "frame render" girmemesidir.
2. **Kuyruk Tekrarı (Gerçek Veritabanı Çift Yazımı):** Native servisin ürettiği aralık kuyruğu (pending intervals) kısmi ağ hatası alırsa, başarılı olan kayıtlar bir sonraki denemede tekrar yazılmaktadır.
3. **UI Semantik Borcu:** "Bugünkü toplam süre" uygulamada üç farklı ekranda, üç farklı şekilde hesaplanmaktadır.
4. **Native Pomodoro Eksikliği:** Hedefli sayaçlar, arka planda süreleri dolsa bile otomatik mola geçişini yapamamaktadır.

---

## 2. Kök Neden Analizi 1: Çift Sayma ve "Donma" (Double-Counting Race)

### 2.1. Kusurun Gerçek Boyutu ve RTT Şartı
Zıplama birkaç saniye değil, **oturumun tamamı kadardır.** Formül: `eski + (kaydedilen_süre) + (halen_akan_liveWork)`. 1 saatlik bir çalışma durdurulduğunda geçici olarak 2 saat görünür.
*Neden 650 test bunu yakalayamadı?* Çünkü testler saf fonksiyoneldir (microtask zinciridir). Gerçek cihazda ise `flushPending()` ile `_finish()` arasına gerçek bir ağ RTT'si girer, Flutter bu boşlukta bir frame çizer ve ekran bu zehirli toplamı görerek dondurur.

### 2.2. Uyanma Zehirlenmesi (Background Resume Poisoning)
Uygulama arka plandayken bildirimden "Durdur"a basıldığında, uygulama tekrar açılır açılmaz bir frame çizilir. O an `liveWork`, arka planda geçen ölü zamanı da katarak hesaba katılır ve `_reconcile` bitene kadar ekran bu şişmiş değeri sonsuza dek kilitler.

### 2.3. Üç Farklı Doğru (Architectural Debt)
Sorun sadece `StudyTimerCard`'da değil; `focus_timer_screen.dart` da aynı hatalı formülü (donma koruması bile olmadan) kullanmaktadır. `goal_card.dart` ise tamamen farklı bir canlı süre hesabı yapar.

### 2.4. Kesin Çözüm: "Unified Provider" ve `isStopping`
1. **Tek Doğru Kaynağı (UI):** Üç ekrandaki farklı hesaplamalar silinip, tek bir `canonical_today_total_provider` oluşturulacaktır. Tüm ekranlar bu provider'ı dinleyecektir.
2. **isStopping:** `StudyTimerState`'e `isStopping` bayrağı eklenecek. `stop()` veya `_reconcile` başladığı milisaniye bu bayrak kalkacak, canlı akış (`liveWork = 0`) anında kesilecektir. Dondurma işlemi de tam bu geçiş anına (öncesi `!isStopping`, sonrası `isStopping`) kilitlenecek ve değerler tavan (`clamp`) ile sınırlandırılacaktır.
3. **Gerçek Test:** Sahte (mock) veri yerine, `Future.delayed` ve `tester.pump()` barındıran gerçek bir Widget regresyon testi yazılacaktır (WP-239'u tamamlayan asıl test).

---

## 3. Kök Neden Analizi 2: Kuyruk Tekrarı (Gerçek Çift Yazım)

### 3.1. Kısmi Başarısızlık Senaryosu
App-kapalıyken atılan "Durdur" komutları Native tarafından `timer_pending_intervals` kuyruğuna yazılır. Dart uyanınca `_reconcileBackgroundTimerImpl` bu kuyruğu okur ve sırayla veritabanına yazar.
**Kritik Bug:** Eğer kuyrukta 3 aralık varsa; 1. başarıyla yazılır, 2.'de ağ koparsa `recordedOk = false` olur. Kuyruk **silinmez**. Uygulama bir sonraki açılışında kuyruğu tekrar okur ve 1. aralığı **ikinci kez** veritabanına yazar!

### 3.2. Kesin Çözüm (Idempotency)
Native Kotlin kodu `appendPendingInterval` sırasında her aralığa eşsiz bir UUID basacaktır. Dart bu aralığı `StudyRepository.addSession`'a gönderirken bu UUID'yi anahtar (id) olarak kullanacak; böylece çevrimdışı önbellek aynı id'ye sahip oturumu ikinci kez reddedecektir (Deduplication).

---

## 4. Kök Neden Analizi 3: Pomodoro Arka Plan Hayaleti

### 4.1. Kısıt
Pomodoro 25. dakikaya ulaşsa bile, Flutter izolatı OS tarafından uyutulmuşsa hiçbir geçiş yaşanmaz, sadece ileri doğru sayan Native `Chronometer` aşım yapar. Dart uyanınca aşan süreyi siler ancak kullanıcıyı uyarmaz.

### 4.2. Kesin Çözüm (Native Auto-Transition)
Native katman zaten `handleStartBreak` metoduna sahiptir ve mola aralığını bağımsız yönetebilmektedir.
1. Dart, `startTimer` derken Kotlin'e hedef süreyi de (`targetMs`) yollayacaktır.
2. Kotlin, `ExactAlarmHelper` ile hedef süreye native bir alarm kuracaktır.
3. Süre dolduğunda Dart uyanmasa bile; Alarm tetiklenecek, bildirim sesi çalacak ve Native servis kendi içindeki `handleStartBreak()` metodunu çağırarak aralığı kuyruğa atıp `phase=rest` (Mola) fazına otomatik geçecektir!

---

## 5. Manuel Ekleme (Manual Add Time) Açıkları

"Kusursuz" olduğu sanılan bu modülde iki açık ispatlanmıştır:
1. **00:00 Kenetlenmesi Eksikliği:** Sistem "bugün" için saatten geriye doğru çıkarma yapar. Gece 01:00'de 3 saat eklerseniz, süre düne (22:00) kayar ve bugünün toplamı değişmez. Bu durum ürün ekibiyle değerlendirilmelidir (bugün mü sayılmalı, düne mi sarkmalı?).
2. **Çakışma Kontrolü Yok:** Sayaç çalışırken manuel süre eklenebilmektedir. Bu durum UI yarışmasını tetiklemese de veritabanında fiziksel zaman çakışması (overlapping) yaratır. Canlı sayaç çalışırken manuel ekleme butonuna basılması `isRunning` şartıyla engellenecektir.

---

## 6. Yol Haritası ve DoD (Definition of Done)

WP numaraları çakışmaları önlemek için 250+'den başlatılmıştır.

### Faz 1: UI Senkronizasyonu ve Tekilleştirme (Tahmini WP: 250)
- **Kapsam:** `isStopping` bayrağı, `canonical_today_total_provider`, `focus_timer_screen` yaması, dondurma tavan limitleri (clamp).
- **DoD:** `pump` içeren widget testi yazılacak. Testte ağ gecikmesi simüle edilecek, donmanın zıplama olmadan kusursuz gerçekleştiği ispatlanacak.
- **Rollback:** Yeni provider hatalı çıkarsa eski lokal `liveWork` hesaplarına geri dönülecek.

### Faz 2: Veritabanı Korunması ve Native Pomodoro (Tahmini WP: 251)
- **Kapsam:** Kuyruk aralıklarına UUID eklenmesi, Native `ExactAlarm` tetikleyicisi ve `handleStartBreak` otomasyonu.
- **DoD:** İnternet kapalıyken 2 oturum kuyruğa atılacak, ağ kısmen açılıp kapatılarak kuyruk tekrarı yaratılacak, veritabanında "duplicate" oluşmadığı doğrulanacak.
- **Rollback:** `ExactAlarm` izinleri verilmezse, mevcut "uyanınca kesme" (passive FGS) mantığı fallback olarak korunacak.

### Faz 3: UX ve UI İyileştirmeleri (Tahmini WP: 252)
- **Kapsam:** Sıralamadaki ikon karışıklığı (Ateş ikonu yerine madalya vb.) ve Manuel Ekranında çakışma (overlap) koruması.
