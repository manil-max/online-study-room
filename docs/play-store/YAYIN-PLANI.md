# Play Yayın Planı — kim neyi yapacak

> **Tarih:** 2026-08-08 · Sahip Console hesabını açtı, ücreti ödedi, 14 günlük
> kapalı teste onay verdi. Bu dosya o noktadan sonrasını anlatır.
> Kapıların teknik durumu: `docs/play-store/PLAY-RELEASE-GATE.md`.

---

## A. SENİN YAPACAKLARIN (Play Console'da)

Sırayla git. Her maddede tam olarak ne yazacağın/yükleyeceğin yazılı.

### 1. Uygulamayı oluştur
- **Uygulama adı:** Odak Kampı
- **Varsayılan dil:** Türkçe (İngilizce'yi sonra ekleyeceğiz)
- **Uygulama / Oyun:** Uygulama · **Ücretsiz / Ücretli:** Ücretsiz
- **Paket adı (değiştirilemez, dikkat):** `com.manilmax.online_study_room`

### 2. Store listing metinleri
- **Kısa açıklama (max 80 karakter):** arkadaşlarınla birlikte çalış, süreni
  takip et.
- **Uzun açıklama:** hazır metni ben vereceğim, sen yapıştıracaksın (henüz
  yazmadım — söyle, yazayım).

### 3. Görseller — **bunları senin hazırlaman gerekiyor**
Repoda hazır listing görseli yok, bunlar bende üretilemez:
- **Uygulama ikonu:** 512×512 PNG (şeffaf olmayan, kare)
- **Öne çıkan grafik (feature graphic):** 1024×500 PNG/JPG
- **Telefon ekran görüntüsü:** en az 2 tane, 4 tanesi daha iyi. Telefondan
  ekran görüntüsü al yeter. Önerim: kamp ateşi · sayaç · istatistik · gruplar.

### 4. Gizlilik ve veri
Bu iki adres **canlı**, doğrudan yapıştır:
- **Gizlilik politikası:**
  `https://manil-max.github.io/online-study-room/legal/privacy-tr.html`
- **Hesap/veri silme:**
  `https://manil-max.github.io/online-study-room/legal/data-deletion-tr.html`

### 5. Veri güvenliği (Data safety) formu
Satır satır `docs/play-store/DATA-SAFETY.md` dosyasından doldurulur. Formda
kritik cevaplar:
- Konum: **Hayır** · Reklam: **Hayır** · Veri satışı: **Hayır**
- Veri şifreli aktarılıyor: **Evet**
- Kullanıcı silme talep edebiliyor: **Evet** (yukarıdaki silme adresi)

### 6. İçerik derecelendirme anketi
Uygulamada **kullanıcı içeriği ve sohbet var** — ankette bunu **evet** işaretle.
Yanlış işaretlemek sonradan askıya alınma sebebidir.

### 7. Uygulama erişimi (App access) — **atlanırsa reddedilir**
Uygulama girişsiz kullanılamıyor, bu yüzden Google incelemecisine bir **test
hesabı** vermen gerekiyor:
- Uygulamada yeni bir hesap aç (örn. `play-review@…`), bir gruba ekle.
- Console → App access → "Tüm işlevler giriş gerektirir" → e-posta + şifreyi
  yaz.

### 8. Kapalı test
- Bir kapalı test kanalı aç, **test kullanıcılarının e-postalarını** ekle.
  (Google kişisel hesaplarda belirli bir sayı ve süre şart koşuyor; kesin sayı
  ve gün Console'da sana yazılı görünür — oradan oku, ben tahmin etmeyeyim.)
- Testçiler daveti **kabul edip uygulamayı kurmalı**; sadece e-posta eklemek
  sayılmıyor.

### 9. İmzalama anahtarı yedeği — **en kritik madde**
Anahtar CI'da secret olarak duruyor. **Çevrimdışı ikinci bir kopyasını al**
(harici disk / şifreli USB). Bu anahtar kaybolursa uygulama bir daha
güncellenemez, yeni paket adıyla sıfırdan yayınlamak gerekir.

---

## B. BENİM YAPACAKLARIM (kod tarafı)

| # | İş | Durum |
|---|---|---|
| 1 | SSS/bildirim dil hatası (arayüz İngilizce, içerik Türkçe) | ✅ bitti (WP-526) |
| 2 | Yasal site + canlı gizlilik/veri silme adresi | ✅ bitti (WP-525) |
| 3 | Hesap silmenin production'da gerçekten çalışması | ✅ bitti (WP-524) |
| 4 | **AAB (app bundle) üretimi** — Play'e yüklenecek dosya | sırada |
| 5 | v61 sürümü: dil düzeltmesi + yasal adres + AAB | 4'ten sonra |
| 6 | Durdur'daki 1-3 sn, sayaç birikmiş süre, bildirim izni hatası | kuyrukta |
| 7 | Kademeli yayın (%10→%25→%50→%100) ve durdurma runbook'u | son adım |

**Sıra mantığı:** sen Console'da 1-8'i doldururken ben 4 ve 5'i bitiriyorum.
Kapalı test kanalına yüklenecek AAB o zaman hazır olur; kimse kimseyi
beklemez.

---

## C. Bilmen gereken üç şey

1. **SSS dil hatası sunucudan değil uygulamadan.** Düzeltmesi telefonuna
   ancak **yeni sürümle** (v61) gelir. v60'ta İngilizce seçiliyken hâlâ Türkçe
   göreceksin, o normal.
2. **Play sürümünde uygulama içi güncelleme kapalıdır.** GitHub'dan APK
   indiren mevcut 3 kişi öyle devam eder; Play'den kuran kullanıcı
   güncellemeyi Play'den alır. İki kanal aynı hesapları kullanır.
3. **Kapalı test süresi takvim saatidir.** Testçiler kurulumu ne kadar geç
   yaparsa üretim erişimi o kadar geç açılır. Bu yüzden 8. madde erken
   başlamalı.
