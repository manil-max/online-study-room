# Saat Merkezi (Clock Center) Mimarisi (Faz 0)

> Bu doküman, uygulamanın saat modülünü basit bir "geri sayım" aracından çıkarıp; Apple, Google ve Samsung'un varsayılan saat uygulamalarıyla rekabet edebilecek (ve onları geçecek) kalitede, dünya standartlarında bir Zaman Motoruna (Time Engine) dönüştürme planıdır.

## 1. Zaman Motoru (Core Time Engine)
- **Problem:** Flutter'ın `Timer.periodic` fonksiyonu cihaz uyku modundayken (Doze Mode) veya ağır işlem altındayken saniye atlayabilir, senkronizasyon kaybedebilir. 
- **Mimari Çözüm:** Motor tamamen **Epoch (UTC Time) tabanlı** çalışacak. Her başlatma, durdurma ve mola aksiyonu kesin bir timestamp olarak kaydedilir.
- **Dayanıklılık:** Saat dilimi (timezone) değişiklikleri, cihazın yeniden başlatılması (reboot) ve Yaz/Kış saati (DST) geçişlerine karşı %100 dayanıklı olacak. Uygulama tamamen kapalı olsa dahi Native Android kanalları (`flutter_foreground_task` veya özel Kotlin background service) üzerinden sayım devam edecek.

## 2. Dünya Saatleri (World Clock)
- Kullanıcının seçtiği şehirlere göre zaman dilimi hesaplanacak.
- **UX Detayları:** 
  - Şehirlerin anlık güneş durumuna göre arayüzde Gündüz/Gece renk farklılıkları (Örn: Tokyo gece ise koyu tema, New York gündüz ise aydınlık tema).
  - Kullanıcının yerel saatine göre saat farkı gösterimi (Örn: "Bugün, +3 Saat", "Dün, -5 Saat").

## 3. Süper Alarm (Alarm 2.0)
Sadece uyanmak için değil, görev hatırlatmaları ve rutinler için tasarlanmış profesyonel bir alarm sistemi.
- **Exact Alarms (Kesin Alarm):** Android 12+ API 31 kuralları gereği, alarmın tam saniyesinde çalması için `SCHEDULE_EXACT_ALARM` izni istenecek. Bu izin verilmezse graceful fallback (inexact) yapılacak ancak kullanıcı kesinlikle uyarılacak.
- **Kademeli Ses (Crescendo):** Alarm çaldığında sesi aniden %100 vermek yerine (kullanıcıyı strese sokmamak için) sesi 0'dan 100'e 30 saniye içinde yavaş yavaş yükselten algoritma.
- **Tek Günlük Atlama (Skip next occurrence):** Tatil veya izin günlerinde, mevcut tekrar eden alarmı (Örn: Hafta içi her gün 07:00) bozmadan sadece "yarınki" alarmı tek seferlik devre dışı bırakabilme yeteneği.
- **Anti-Snooze (Ağır Uyananlar İçin):** İsteğe bağlı olarak, alarmı kapatabilmek veya erteleyebilmek için ekranda beliren basit bir matematik işlemini (örn: 14 + 27 = ?) çözme zorunluluğu.

## 4. Çoklu Timer (Multi-Timer Studio)
- Aynı anda sorunsuzca çalışabilen birden fazla timer desteği (Örn: Makarna Timer'ı 10 dk, Çamaşır Timer'ı 45 dk).
- **UX Detayları:**
  - Hızlı başlatma için önayarlı (Preset) timer butonları.
  - Timer çalışırken ve bitime yaklaşmışken tek tuşla "+1 Dk" veya "+5 Dk" ekleme.
  - Her timer için ayrı renk, etiket ve özel UI ikonu seçimi (Karmaşayı önlemek için).
- Tamamlandığında güvenilir ve ısrarcı bir alarm sesi çalması.

## 5. Kronometre & Tur (Lap) Motoru
- **Lap Analizi:** Sadece "Tur 1", "Tur 2" listelemek yerine turlar arası farkların hesaplanması (Örn: Önceki turdan +2 saniye yavaş, -1 saniye hızlı).
- **Görsel Bildirim:** Biten turlar arasında "En Hızlı Tur" YEŞİL, "En Yavaş Tur" KIRMIZI ile (highlight) belirginleştirilir.
- **Arayüz Geçişi:** İsteğe bağlı olarak klasik dijital yüz (00:00:00) veya profesyonel analog (ibreli) yüz (Stopwatch tarzı) kullanımı.

## 6. Yatay StandBy (Masa Saati) Modu
- Cihaz şarja takılıp yatay (landscape) konuma getirildiğinde otomatik açılan devasa masa saati görünümü.
- **AMOLED ve Göz Koruması:** 
  - Göz yormaması ve melatonini baskılamaması için koyu kırmızı/turuncu (gece) tonları.
  - **Burn-in (Piksel Yanığı) Koruması:** Ekranda sabit kalan büyük saat metninin her 1 dakikada bir yavaşça 1-2 piksel rastgele kaydırılarak piksellerin zarar görmesinin engellenmesi (Apple/Samsung kalitesi).
- Ekranda opsiyonel olarak mevcut çalışma oturumunun ufak bir barı veya güncel hava durumu yer alabilir.
