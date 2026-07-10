# backlog.md — Yapılacaklar (Öncelik Sıralı)

> Üstteki en öncelikli. Yeni fikir en alta eklenir, birlikte sıralanır.
> Bir işe başlayınca buradan alınır → `progress.md`'ye WP olarak geçer.
> Kaynak: `new_features.md` (21 maddelik geri bildirim) + `progress.md` bekleyen maddeler + `project.md` açık sorular.

---

## 🔴 Yüksek Öncelik

- [~] **Android ana ekran widget sistemi** (home_widget paketi)
  - Sayaç widget'ı (tek dokunuşla başlat/durdur)
  - Günlük/haftalık istatistik panosu widget'ı
  - Grup leaderboard widget'ı
  - Çeşitli boyut/tür seçenekleri
  - **WP-1 tamamlandı (`616a92d`):** `home_widget` dependency, Android provider/layout/xml altyapısı ve Flutter widget veri servisi eklendi.
  - **Kalan:** Sayaç widget'ında gerçek başlat/durdur aksiyonları ve arka plan kontrolü WP-2 ile yapılacak.
  - *Kaynak: project.md §3.6, progress.md FAZ 4.2, new_features.md §5 Madde 4*

- [~] **Persistent notification (kalıcı bildirim + kontrol paneli)**
  - Sayaç çalışırken bildirim çubuğunda kalıcı bildirim
  - Durdur/başlat/mola aksiyonları bildirimde
  - Gelişmiş kontrol paneli görünümü
  - **WP-2 tamamlandı:** Kalıcı Android sayaç bildirimi, `Durdur` aksiyonu, notification permission ve restart sonrası timer geri yükleme eklendi.
  - **Kalan:** Ayrı `Başlat` ve manuel `Mola` aksiyonları ürün kararına göre ileride netleştirilecek.
  - *Kaynak: new_features.md §5 Madde 10*

- [ ] **E-posta doğrulama + şifre sıfırlama**
  - Supabase Confirm email aktif edilecek
  - Kayıt sonrası "e-posta onay linki" uyarısı
  - Giriş sayfasına "Şifremi Unuttum" + resetPasswordForEmail
  - *Kaynak: new_features.md §Öncelikli, progress.md FAZ 1.1 bekleyen*

- [ ] **Ana Sayfa responsive kart cilası** (2E devamı)
  - Timer kartı responsive adaptasyonu (2E'de hariç tutuldu)
  - Kalan kenar durumları ve ince ayarlar
  - *Kaynak: progress.md Tur 3*

---

## 🟡 Orta Öncelik

- [ ] **Dinamik panel / Live Activities (Android durum çubuğu baloncuğu)**
  - Yeni nesil Android "dinamik buton/hap" entegrasyonu
  - Arka plandayken durum çubuğunda minik gösterge
  - Tıklandığında üstten şık kontrol paneli
  - *Kaynak: new_features.md §5 Madde Live Activities*

- [ ] **Kilit ekranı widget'ı**
  - Android kilit ekranında sayaç/istatistik gösterimi
  - *Kaynak: kullanıcı isteği (henüz dokümanda yok)*

- [ ] **Sınıf sohbeti (chat)**
  - Her sınıfa mesajlaşma özelliği
  - ClassDetailScreen'de "Sohbet" sekmesi (yer ayrılmış)
  - *Kaynak: project.md §3.8, progress.md FAZ 3.6*

- [ ] **Oyunlaştırma: streak freeze, taç/rozet, başarımlar**
  - Streak freeze (seri dondurma) hakkı — Chess.com/Duolingo benzeri
  - Günün birincisine taç 👑, hafta birincisine rozet
  - Başarımlar: "Gece Kuşu", "Maratoncu", "Dürtücü" vb.
  - Profil sekmesi başarım alanına dönüşecek
  - *Kaynak: new_features.md §4 Madde 8, 13, 16, 17*

- [ ] **Dürtme (nudge) sistemi**
  - Grup üyelerine çalışma daveti mesajı atabilme
  - *Kaynak: new_features.md §5 Madde 8*

- [ ] **Windows masaüstü build + widget**
  - Windows masaüstü build testi
  - Pencere/ekran uyarlamaları (responsive)
  - Always-on-top mini Flutter penceresi
  - *Kaynak: project.md §3.6, progress.md FAZ 4.1-4.2*

- [ ] **Çoklu cihaz senkron testi**
  - Birden fazla Android + Windows arası senkron doğrulama
  - *Kaynak: progress.md FAZ 4.3*

- [ ] **Daha fazla sınıf metriği**
  - Haftalık değişim
  - Ders bazında sınıf kıyası
  - En istikrarlı üye
  - *Kaynak: progress.md FAZ 3.10 kalan*

- [ ] **Özelleştirilebilir saat stilleri (kalan)**
  - Sınıf "yarış"/dilim görünümü
  - Ek estetik stiller
  - *Kaynak: project.md §3.12*

- [ ] **Çevrimdışı tespiti (heartbeat/yaşam-döngüsü)**
  - Uygulama kapanınca presence'ı offline'a çevirme
  - Heartbeat sistemi
  - *Kaynak: progress.md FAZ 2.2 bekleyen*

- [x] **Arka planda süre tutma (mobil arka plan servisi)**
  - Telefon kilitlenince/arka plana alınınca sayacın devam etmesi
  - Platform-seviyesi çözüm
  - **WP-2 tamamlandı:** Aktif timer wall-clock başlangıcı cihazda saklanıyor; uygulama kapanıp açıldığında sayaç aynı oturumdan devam ediyor.
  - *Kaynak: progress.md FAZ 2.1 bekleyen*

---

## 🟢 Düşük Öncelik / Fikir

- [ ] **Beta/staging test uygulaması**
  - Ayrı paket adı (`.beta` uzantılı)
  - İki kanallı güncelleme (Stable + Beta)
  - Gizli geliştirici menüleri, debug ekranları
  - *Kaynak: new_features.md §6*

- [ ] **Admin paneli (süper-admin arayüzü)**
  - Kullanıcı/grup yönetimi, veritabanı denetimi
  - Supabase kota/limit takibi
  - Geri bildirim/hata raporu merkezi
  - Veri analizi grafikleri, toplu duyuru araçları
  - *Kaynak: new_features.md §6*

- [ ] **Samsung Modes & Routines entegrasyonu**
  - Cihaz "Ders Çalışma Modu"nu algılama
  - Otomatik odak ekranına geçiş
  - *Kaynak: new_features.md §5*

- [ ] **Otomatik e-posta raporları**
  - Ay sonlarında kullanıcılara özet e-posta
  - *Kaynak: new_features.md §5 Madde 21*

- [ ] **Yeni grafik türleri**
  - Radar grafik
  - Diğer yeni grafik/animasyon fikirleri
  - *Kaynak: new_features.md §3 Madde 15*

- [ ] **Çizgisel grup grafiği**
  - Tarihe bağlı grubun çalışma ivmesi çizgi grafiği
  - *Kaynak: new_features.md §3 Madde 12*

- [ ] **Grup içi tüm zamanlar istatistiği**
  - Sadece bugün/hafta değil, tüm zamanlar rekorları detaylı
  - *Kaynak: new_features.md §3 Madde 14*

- [ ] **Çevrimdışı cache (Drift/Hive)**
  - Yerel veri saklama, çevrimdışı dayanıklılık
  - *Kaynak: project.md §4*

- [ ] **Kapsamlı bildirim sistemi**
  - Kişiye özel çalışma hatırlatıcıları (açılıp kapatılabilen)
  - Her bildirim türü/tarzı/önceliği detaylıca ayarlanabilir
  - *Kaynak: new_features.md §5 Madde 10*

- [ ] **Windows kurulum paketi + dağıtım**
  - exe/MSIX kurulum paketi
  - Kullanım/kurulum notları
  - *Kaynak: progress.md FAZ 5.2*

- [ ] **Grid boyutlandırma gelişmiş** (kullanıcı geri bildirimi)
  - Kartların 4 kenar ve köşeden (genişlik + yükseklik) ayarlanması — Android widget mantığı
  - *Kaynak: project.md §9 Gelecek UI Geliştirmeleri*

- [ ] **Canlı grup hedefi**
  - Grup hedef ilerleme barının çalışan kişi sayısına göre saniye saniye akması
  - *Kaynak: project.md §9 Gelecek UI Geliştirmeleri*

- [ ] **Grup yönetimi UI iyileştirme**
  - Grup ayarları ve üye yönetiminin daha kolay/derli toplu yapılması
  - *Kaynak: project.md §9 Gelecek UI Geliştirmeleri*

---

## ❓ Açık Sorular

- İstatistik detayı: Hangi grafik tipleri, hangi kıyaslamalar en faydalı?
- Widget içeriği: Hangi bilgiler, hangi boyut, hangi platform öncelikli?
- Tasarım dili: Renkler/tema son halini aldı mı yoksa daha iyileştirme var mı?
- Çoklu sınıf: İlk sürüm çoklu sınıfı destekliyor — gerçekten kullanılıyor mu?
