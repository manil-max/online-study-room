# Play Yayın Planı — kim neyi yapacak

> **Tarih:** 2026-08-08 · Sahip Console hesabını açtı, ücreti ödedi, 14 günlük
> kapalı teste onay verdi. Bu dosya o noktadan sonrasını anlatır.
> Kapıların teknik durumu: `docs/play-store/PLAY-RELEASE-GATE.md`.

---

## A. SENİN YAPACAKLARIN (Play Console'da)

Sırayla git. Her maddede tam olarak ne yazacağın/yükleyeceğin yazılı.

### 0. Karar: tek uygulama, iki dilli tek liste (2026-08-08)
Ayrı uygulama açılmıyor. Tek listenin altında iki dil olur:

| | Varsayılan (dünya) | Türkçe |
|---|---|---|
| Uygulama adı | Focus Camp | Odak Kampı |
| Açıklamalar | İngilizce | Türkçe |
| Ekran görüntüleri | İngilizce arayüz | Türkçe arayüz |
| Öne çıkan grafik | `play-feature-graphic-en-1024x500.png` | `play-feature-graphic-1024x500.png` |
| İkon | aynı dosya (üzerinde yazı yok) | aynı dosya |

**İmzalama kararı (geri dönüşü yok):** Play kendi app signing key'ini üretir.
Sonucu: GitHub'dan kurmuş 3 kişi Play sürümüne güncelleyemez, önce kaldırıp
yeniden kurarlar. Hesap verisi sunucuda olduğu için kaybolmaz. Ayrıntı ve
kabul edilen diğer sonuçlar: `docs/play-store/AAB-YOLU.md`.

### 1. Uygulamayı oluştur
- **Uygulama adı:** Focus Camp
- **Varsayılan dil:** English (United States) — Türkçe çeviri olarak eklenecek
- **Uygulama / Oyun:** Uygulama · **Ücretsiz / Ücretli:** Ücretsiz
- **Paket adı (değiştirilemez, dikkat):** `com.manilmax.online_study_room`

### 2. Store listing metinleri
- **Kısa açıklama (max 80 karakter):** arkadaşlarınla birlikte çalış, süreni
  takip et.
- **Uzun açıklama:** aşağıdaki metni olduğu gibi yapıştır.

```
Odak Kampı, arkadaşlarınla birlikte çalışmayı kolaylaştıran bir çalışma
takip uygulamasıdır.

Sayaç üç modda çalışır: kronometre, geri sayım ve pomodoro. Sayaç açıkken
süre bildirim alanında canlı görünür; uygulamayı kapatsan da saymaya devam
eder.

Bir grup kur ya da arkadaşının davet koduyla katıl. Kamp ateşi ekranında
grubundaki herkesin o an çalışıp çalışmadığını tek bakışta görürsün. Grup
sohbeti, dürtme ve günlük hedef ile birbirinizi takipte tutarsınız.

Ne yaptığını rakamlarla gör: günlük ve haftalık istatistikler, ders bazında
dağılım, seri takibi, XP ve başarımlar.

Ana ekranı kendine göre düzenle, hazır temalardan birini seç ya da kendi
temanı oluştur. Alarm, zamanlayıcı ve görev listesi de uygulamanın içinde.

Uygulama Türkçe ve İngilizce çalışır.
```

- **İngilizce listing** (sonra ekleyeceğiz, zorunlu değil):

```
Odak Kampı (Focus Camp) is a study tracker that makes studying with friends
easier.

The timer runs in three modes: stopwatch, countdown and pomodoro. While it
runs, the elapsed time stays live in your notification area and keeps
counting even if you close the app.

Create a group or join one with a friend's invite code. The campfire screen
shows at a glance who in your group is studying right now. Group chat,
nudges and a daily goal keep everyone on track.

See what you actually did: daily and weekly statistics, per-subject
breakdown, streaks, XP and achievements.

Arrange the home screen your way, pick a ready-made theme or build your own.
An alarm, a standalone timer and a task list are included.

The app works in Turkish and English.
```

### 3. Görseller
İkon ve öne çıkan grafik **üretildi**, `references/play-store/` altında:
- `play-icon-512.png` — her iki dilde de aynı (üzerinde yazı yok)
- `play-feature-graphic-1024x500.png` — Türkçe liste
- `play-feature-graphic-en-1024x500.png` — İngilizce liste

Üreten komut: `python scripts/build_store_art.py` (görsel değişirse yeniden
koştur, elle düzenleme).

**Ekran görüntüleri sahipten:** her dil kendi görüntüsünü ister.
- Uygulamayı İngilizce yap → 4 görüntü (kamp ateşi · sayaç · istatistik · gruplar)
- Türkçeye al → aynı 4 görüntü
- Toplam 8

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
