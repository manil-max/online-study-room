# Dinamik panel — devir notu

> Odak Kampı (Flutter + Kotlin, Android). Sayaç çalışırken durum çubuğunda /
> kilit ekranında kalıcı bir canlı gösterge istiyoruz — THY uygulamasının adım
> göstergesi gibi. Android 16'daki adı **Live Update / promoted ongoing
> notification**, Samsung'daki yüzeyi **Now Bar**.
>
> Altı turdan fazla denendi, hiçbirinde çıkmadı. 2026-08-27'de sebep bulundu.
> Bu belge o turun tamamını devreder: ne öğrenildi, ne yapıldı, neyi bir daha
> deneme.

---

## 1. Kısa cevap

**Kodda iki kusur vardı ve ikisi de kapandı. Ama panel yine çıkmıyor, çünkü
asıl sebep bizde değil:**

> Sahibin Galaxy S23'ünde (One UI 8 / Android 16) sistem terfiyi **VERİYOR** —
> `FLAG_PROMOTED_ONGOING` (0x40000) gönderilen bildirime gerçekten yazılıyor —
> ama Samsung ortada **hiçbir şey çizmiyor**. Ne durum çubuğu çipi, ne Now Bar
> satırı. Now Bar ayarlardan açık. Pomodoro (ProgressStyle taşıyan dal) da
> denendi, değişmedi.

**Ve hiçbir API sinyali bunu önceden söylemiyor.** Bayrak yalnız "kabul ettim"
der, "göstereceğim" demez. Üç katmanlı kapının son katmanı (gönderilen
bildirimin bayrağını gözlemek) bile yakalayamıyor, çünkü bayrak gerçekten var.

Sonuç: **AOSP terfi yolu bu cihaz için kapalı sayılmalı.**

---

## 2. Kodda bulunan kök nedenler (kapandı)

### 2.1 Terfi hiçbir cihazda HİÇ istenmiyormuş

```
richPanel = useV43CustomPanel() || !mayRequestPromotion(...)
useV43CustomPanel = prefs.getBoolean(KEY_PANEL_EXPANDED, true)   // ← hep true
requestPromotedOngoing = !usesCustomView                          // ← hep false
```

Sol taraf her zaman `true` olduğu için `||` kısa devre yapıyor; sağdaki
"sistem terfi veriyor mu?" sorusu **hiç sorulmuyordu**. Zincirin sonunda
`setRequestPromotedOngoing(true)` **hiçbir cihazda hiç çağrılmadı**.

Terfi kapısı (`TimerPromotion`) eksiksiz yazılmıştı ama devreye hiç girmemişti.
Bu deponun tekrar eden kusuru: **"bitmiş arka uç, bağlanmamış ön uç."**

### 2.2 Ölçüm yanlış anda yapılıyordu

`recordOutcome`, `notify()`nin hemen ardından çağrılıyordu. Ama `notify()`
bildirimi sisteme **kuyruklar**; `NotificationManagerService` gerçek gönderimi
kendi handler'ında yapar. `activeNotifications` ise **gönderilmiş** listeyi
okur.

Yani senkron okuma bildirimi çoğu zaman bulamıyor → `postedFlags == null` →
"ölçüm yok" (doğru davranış, çünkü görememek red değildir) → verdict **hiç
yazılmıyordu**.

Düzeltme: 400 ms gecikmeli yoklama. Üstelik sınırlı — üç sonuçsuz denemeden
sonra RED yazılır, yoksa cihaz her Başlat'ta düz kartta kalırdı. Sayaç
`Build.FINGERPRINT` ile damgalı: sistem güncellemesi yolu yeniden açar, karar
kalıcı bir tavana dönmez.

### 2.3 İki durumlu tercih tuzağı (Dart)

`getBool(...) ?? true` — "anahtar yok" ile "zengin panel istiyorum" aynı
sayılıyordu. Sonuç: geliştirici anahtarını **bir kez açıp kapatan** kullanıcı
diske `true` yazdırıp dinamik paneli **kalıcı** kapatıyordu ve geri dönüşü
yoktu; "otomatik"i ifade eden bir değer kalmıyordu.

Düzeltme: üç durum diskte de ayrı. Anahtar **yok** = otomatik, `true` = zengin
panel zorla, `false` = Live Update zorla. "Otomatik"e dönüş anahtarı **siler**.

---

## 3. Yapısal kısıtlar — bunlar değişmez

* **Özel `RemoteViews` taşıyan bildirim terfi EDEMEZ.** İkisi birbirini
  dışlar. Altı turun ilk hatası ikisini aynı bildirimde tutmaya çalışmaktı:
  büyük sayaçlı gömülü düğmeli panel **ve** çip aynı anda olamaz.
* **Android 14'ten beri foreground service bildirimleri silinebilir** ve bu
  engellenemez. İstisnalar (CallStyle, medya, cihaz yöneticisi) bir çalışma
  sayacını kapsamıyor.
* **Overlay pencereleri kilit ekranının üstüne çizilmez.** Bildirim gölgesi,
  son uygulamalar ekranı ve `FLAG_SECURE` taşıyan ekranlar için de aynı.

---

## 4. Emülatörde ayrı ölçüm (Android 16 / API 36 sistem imajı)

Burada terfi **hiçbir uygulama için** mümkün değil. Dört bağımsız ölçüm:

* `pm list permissions` → 1337 izin tanımlı, 'promot' geçen **sıfır**. Yani
  `POST_PROMOTED_NOTIFICATIONS` bu platformda **tanımlı değil**; manifestteki
  satır "requested" listesinde görünür, "granted" listesinde asla.
* `device_config` taraması → yalnız `android.app.api_rich_ongoing=true`. Yani
  **API yüzeyi açık** (bu yüzden `canPostPromotedNotifications()` çağrılabiliyor
  ve extra'lar kabul ediliyor), ama terfiyi **çizen** SystemUI bayrakları —
  `ui_rich_ongoing`, `status_bar_notification_chips` — imajda **yok**. Read-only
  aconfig oldukları için root'la bile açılamıyor.
* `dumpsys notification | grep -i promot` → **boş**.
* SystemUI'da `EmptyAutomaticPromotionCoordinator` koşuyor (NO-OP sürüm).

**Sonuç:** emülatör bu özelliği doğrulamak için kullanılamaz. Tek doğrulama
yeri gerçek bir Android 16 telefon.

---

## 5. 🔴 DENENDİ VE GERİ ALINDI — bir daha deneme

**Açık uçlu kronometreye `ProgressStyle().setProgressIndeterminate(true)`
vermek.**

Hipotez mantıklıydı: "Android 16'nın Live Update yüzeyleri `ProgressStyle`
etrafında kurulu; `setRequestPromotedOngoing(true)` tek başına yalnız bayrağı
aldırır, sisteme çizecek bir öğe vermez. Bizim kronometremiz standart stil +
terfi isteği gönderiyor, o yüzden sistemin elinde gösterecek bir şey yok."

**Cihazda yanlışlandı.** Sürüm çıktı, sahip anında ölçtü:

* bildirimde soldan sağa süzülen belirsiz çubuk belirdi,
* sayaç `00:00`'a düştü,
* düğme kayboldu,
* **ve çip yine çıkmadı.**

Net kayıp. Geri alındı ve sözleşme testi artık `isNot(contains(
'setProgressIndeterminate'))` diyor.

---

## 6. 🔴 ÜÇ KEZ TEKRARLANAN SÜREÇ HATASI

**Hipotezi VARSAYILAN yola bağlamak.**

| Ne zaman | Ne yapıldı | Sonuç |
|---|---|---|
| v71 (WP-753) | Live Update cihazda doğrulanmadan varsayılan yapıldı | Bildirimde `00:00`, Start/Stop hiç çizilmedi |
| v74 (WP-762) | Yukarıdaki ProgressStyle hipotezi varsayılan yola kondu | Çalışan bildirim bozuldu |
| — | (v71'i "cihazda doğrulanmadan çıkmıştı" diye eleştirip aynısını yapmak) | — |

**Sürüm notuna "bu bir hipotezdir" yazmak YETMİYOR.** Deneysel dal zaten vardı
(Live Update seçeneği); hipotez orada durmalıydı.

Sahip kuralı kendi cümlesiyle koydu:

> *"Test ederken sadece biz görelim, sürümlerde diğerlerinde normal olsun; biz
> yapana kadar bozulmasın."*

Bu kural artık kodda ve testte kilitli.

---

## 7. Şu anki davranış

```
useRichPanel(override, mayPromote):
    null  -> true          // OTOMATİK: çalışanı seç (terfi verilse bile çizilmiyor)
    true  -> true          // kullanıcı zengin panel dedi
    false -> !mayPromote   // kullanıcı Live Update dedi: sistem izin veriyorsa dene
```

Yoklama yalnız **terfi istendiğinde** koşar. Zengin panel gönderilmişken bayrağı
aramak, bulamamak ve bunu RED diye yazmak cihaza yanlış bir karar damgalardı.

**Kullanıcı yüzeyi:** Hakkında → sürüme 7 dokunuş → gizli geliştirici bölümü:

* üç seçenek: Otomatik / Zengin panel / Live Update
* **verdict satırı**: *verdi* / *vermedi* / *henüz ölçülmedi*

Verdict `flutter.timer_promotion_verdict_v1` altında, `"<VERDICT>|<FINGERPRINT>"`
biçiminde. `flutter.` öneki kasıtlı: `shared_preferences` her anahtarı öyle
önekler, o sayede Dart okuyabiliyor.

🔴 **Bu satır olmadan altı tur boyunca cihazda ne olduğunu göremedik.** Ölçüm
her Başlat'ta yapılıyordu ama sonucunu ne sahip ne biz görebiliyorduk. Döner
döngünün asıl sebebi buydu.

---

## 8. Yeni yol: overlay penceresi (v76'da, KAPALI)

Sorun izin değil, **başkasının yüzeyine bağımlı olmak**. Çözüm: pencereyi biz
açıyoruz.

`SYSTEM_ALERT_WINDOW` + `TYPE_APPLICATION_OVERLAY` (API 26 altı: `TYPE_PHONE`).
`RemoteViews` **değil** — kendi sürecimizde normal bir View ağacı, yani
ConstraintLayout / özel View / animasyon serbest.

**Kapalı doğuyor.** Yalnız gizli geliştirici bölümünden açılır ve izin
Ayarlar'dan **elle** verilir (çalışma-zamanı izin penceresiyle istenemez).

Çözülen gizli tuzaklar (hepsi nöbetçili):

* Şerit ekran **dışına** sürüklenebiliyordu. Konum kalıcı yazıldığı için bir
  kez dışarı çıkan şerit her açılışta oraya dönerdi — sonsuza kadar görünmez, tek
  çare uygulama verisini silmek.
* **Dokunma eşiği** olmadan şerit tıklanamaz olurdu: parmak birkaç piksel kayar,
  `ACTION_UP` sürükleme sayılır, dokunma hiçbir şey yapmaz.
* **İzin saklanmaz**, her seferinde sorulur. Kullanıcı Ayarlar'dan geri alabilir;
  bayat bir "izin var" değeri `addView` sırasında çöker.
* Şerit zemini **opak**. Rastgele bir uygulamanın üstünde duruyor; altındaki
  rengi bilmiyoruz.

**Overlay'in VERMEDİĞİ:** kilit ekranı. Orada elimizdeki şey bildirim kartı ve
o değişmedi.

---

## 9. Ölçülmeyenler (dürüst liste)

* Overlay penceresinin cihazda gerçekten çizildiği, uygulama kapatılınca
  yaşadığı, ekran kapanıp açılınca döndüğü.
* Silinen bildirimin gerçekten geri geldiği (`setDeleteIntent` eklendi; sayaç
  hâlâ çalışıyorsa kart yeniden gönderiliyor — silmeyi **engellemek** değil).
* `_refreshPromotionVerdict` (ekran açılırken diskten tazeleme) — sahte
  `SharedPreferences` oturum ortasında native bir yazımı taklit edemiyor.

---

## 10. Kalıcı dersler

1. **Verilen terfi ≠ çizilen terfi.** Bayrak "kabul ettim" der, "göstereceğim"
   demez. OEM yüzeyine bağımlı hiçbir özellik API sinyaliyle doğrulanamaz.
2. **Hipotez varsayılan yola bağlanmaz.** Deneysel dal varsa hipotez oraya gider.
3. **Saf fonksiyon testleri dikişi kaçırır.** `useRichPanel` ve `panelOverride`
   tek tek doğruydu; kusur ikisinin nasıl **bağlandığındaydı**. Nöbetçi bileşimi
   ölçmeli: "taze kurulum + terfi veren cihaz → ne çiziliyor?"
4. **Ölçümün sonucu okunabilir olmalı.** Ölçüp saklamak, ölçmemekten yalnız
   biraz iyidir.
5. **Emülatör bu özellik için ölü.** Doğrulama yeri gerçek cihaz.

---

## 11. İlgili dosyalar

```
app/android/.../timer/StudyTimerService.kt           sunum kararı + yoklama + deleteIntent
app/android/.../timer/TimerPromotionCapability.kt    üç katmanlı terfi kapısı + damga
app/android/.../overlay/TimerOverlay.kt              yüzen şerit
app/lib/core/notifications/timer_panel_preference.dart      üç durumlu tercih
app/lib/core/notifications/timer_promotion_verdict.dart     verdict çözümleyici
app/lib/features/profile/about_screen.dart           gizli geliştirici bölümü
app/test/core/verified_timer_bridge_contract_test.dart      kaynak sözleşmesi
app/android/.../timer/TimerLiveUpdateWp753Test.kt    sunum kararı nöbetçileri
app/android/.../overlay/TimerOverlayWp764Test.kt     şerit nöbetçileri
```
