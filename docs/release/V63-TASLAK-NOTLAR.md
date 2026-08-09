# v63 — sürüm notu TASLAĞI (yayınlanmadı)

> 🔴 **Bu bir sürüm değildir.** `pubspec.yaml` hâlâ `1.0.62+62`, tag yok, build
> yok. Sürüm/tag çıkarmak proje sahibinin açık onayını gerektiriyor.
>
> **Neden ayrı dosyada duruyor:** notları `CHANGELOG.md` ve
> `app/assets/release_notes.json`'a şimdiden yazmak tehlikeli olurdu — sürüm
> numarası `62`de kalırken notlar `63` derse, yayın hattı sürümü `pubspec`ten
> okuyup **eski notlarla** çıkar ve bunu kimse fark etmez. Numara ile notlar
> **birlikte** ilerlemeli.
>
> **Sahip "çıkar" dediğinde sıra:** `pubspec` → `1.0.63+63` · aşağıdaki blok
> `CHANGELOG.md`'nin başına · aynı içerik `release_notes.json`'a
> `buildNumber: 63, channel: stable` olarak · sonra yayın turu.
>
> Sürüm hattı `0125` uygulandıktan sonra açık olacak (yerel ve sunucu şema
> numarası eşitlenince).

---

## Kullanıcıya görünen metin (TR)

**Başlık:** `v63: sessizce kaybolan işler artık kaybolmuyor`

**Öne çıkanlar**

- **Hesap silme gerçekten çalışıyor.** Sayacı bir kez çalıştırmış, bildirim
  almış ya da bir grupta aktif olmuş hesaplarda silme isteği sessizce takılı
  kalıyordu. Artık istek işleniyor.
- **İnternet yokken uygulama hemen açılıyor.** Bağlantı yokken açılışta yaklaşık
  yirmi saniye dönen çember bekliyordu; artık beklemiyor.
- **Ayarların kayboluyorsa artık söylüyoruz.** Günlük hedef, ad, avatar, kamp
  hayvanı, ünvan — bağlantı koptuğunda bu değişiklikler hiçbir uyarı vermeden
  eski hâline dönüyordu. Artık ya kaydediliyor ya da neden kaydedilemediği
  yazıyor. Aynısı sohbet mesajı, dürtme ve sessize alma için de geçerli.

**Düzeltmeler**

- Durdurduğun oturumun kaydedilmeden kaybolabildiği durum kapatıldı.
- Seri alevi bazı durumlarda bugünün durumunu yanlış gösteriyordu; ayrıca gece
  yarısı gün değişince kendini yenilemiyordu.
- "Geçen hafta" özeti Türkiye dışındaki saat dilimlerinde sekiz gün sayıyordu.
- Windows'ta hatırlatma alarmları hiç kurulmuyordu.
- Windows'ta şifre sıfırlama ekranı "gönderildi" diyordu ama gönderilmiyordu.
- Bildirimdeki "Çalışmaya dön" düğmesi pomodoro turunu ilerletmiyordu.
- Sayaç bildirimi mola/çalışma geçişinde eski süreyi göstermeye devam
  edebiliyordu.
- Renk okunabilirliği: bazı temalarda okunması zor kalan yazı ve rozetler
  düzeltildi.
- Bildirim izni kapalıyken sayaç arka planda görünmez çalışıyordu; artık
  durumu söylüyor.
- İstatistik ekranında hiç grubu olmayan kullanıcı için boş ekran çıkmaz
  sokaktı; artık gruba katılma yolu var.
- Aylık çalışma raporu e-postası anahtarı, gönderim henüz başlamadığı hâlde
  açık geliyordu. Artık kapalı geliyor ve ekran gönderimin başlamadığını
  söylüyor.

**Notlar**

- Windows sürümü artık Microsoft Store üzerinden dağıtılabilir hâlde.
- Uygulama içi dil desteği ve mağaza metinleri Türkçe + İngilizce.

---

## User-facing text (EN)

**Title:** `v63: work that quietly disappeared no longer does`

**Highlights**

- **Account deletion actually works.** Accounts that had ever run the timer,
  received a notification or been active in a group had their deletion request
  silently stuck. Requests are now processed.
- **The app opens immediately without internet.** Opening offline used to sit on
  a spinner for about twenty seconds. It no longer waits.
- **If a setting fails to save, we now say so.** Daily goal, name, avatar, camp
  animal and title used to revert with no warning when the connection dropped.
  They now either save or explain why they could not. The same applies to chat
  messages, nudges and muting.

**Fixes**

- Closed a case where a session you stopped could disappear without being saved.
- The streak flame could show today's state incorrectly, and did not refresh
  itself when the day rolled over at midnight.
- The "last week" summary counted eight days outside Türkiye's time zone.
- Reminder alarms were never scheduled on Windows.
- Password reset on Windows said "sent" without sending anything.
- The "Back to work" button in the notification did not advance the pomodoro
  round.
- The timer notification could keep showing the old duration across a
  break/work transition.
- Colour readability: text and badges that stayed hard to read in some themes
  were corrected.
- With notification permission off, the timer ran invisibly in the background;
  it now says so.
- On the statistics screen, users with no group hit a dead end; there is now a
  way to join one.
- The monthly study report email switch was on by default even though sending
  has not started. It is now off, and the screen says sending has not started.

**Notes**

- The Windows build can now be distributed through the Microsoft Store.
- In-app language support and store listings are Turkish and English.
