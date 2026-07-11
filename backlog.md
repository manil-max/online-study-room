# backlog.md — Yapılacaklar (Öncelik Sıralı)

> Üstteki en öncelikli. Yeni fikir en alta eklenir, birlikte sıralanır.
> Bir işe başlayınca buradan alınır → `progress.md`'ye WP olarak geçer.
> Kaynak: `new_features.md` (21 maddelik geri bildirim) + `progress.md` bekleyen maddeler + `project.md` açık sorular.

---

## 🔴 Yüksek Öncelik

- [x] **Android ana ekran widget sistemi** (home_widget paketi)
  - Sayaç widget'ı (tek dokunuşla başlat/durdur)
  - Günlük/haftalık istatistik panosu widget'ı
  - Grup leaderboard widget'ı
  - Çeşitli boyut/tür seçenekleri
  - **WP-1 ve WP-17 tamamlandı:** Widget altyapısı, etkileşimli özellikler (başlat/durdur) ve önizlemeler eklendi.
  - *Kaynak: project.md §3.6, progress.md FAZ 4.2, new_features.md §5 Madde 4*

- [x] **Persistent notification (kalıcı bildirim + kontrol paneli)**
  - Sayaç çalışırken bildirim çubuğunda kalıcı bildirim
  - Durdur/başlat/mola aksiyonları bildirimde
  - Gelişmiş kontrol paneli görünümü
  - **WP-2 ve WP-17 tamamlandı:** Kalıcı bildirim, wall-clock desteği, ve uygulama dışı sayaç kontrolleri eklendi.
  - *Kaynak: new_features.md §5 Madde 10*

- [x] **E-posta doğrulama + şifre sıfırlama**
  - Supabase Confirm email aktif edilecek
  - Kayıt sonrası "e-posta onay linki" uyarısı
  - Giriş sayfasına "Şifremi Unuttum" + resetPasswordForEmail
  - **WP-3 tamamlandı.**
  - *Kaynak: new_features.md §Öncelikli, progress.md FAZ 1.1 bekleyen*

- [x] **Ana Sayfa responsive kart cilası** (2E devamı)
  - Timer kartı responsive adaptasyonu (2E'de hariç tutuldu)
  - Kalan kenar durumları ve ince ayarlar
  - **WP-4 ve WP-16 tamamlandı:** Dashboard kartları scroll, ellipsis, boş-durum yönetimi ve dar ekran testlerinden geçti.
  - *Kaynak: progress.md Tur 3*

---

## 🟡 Orta Öncelik

- [x] **Dinamik panel / Live Activities (Android durum çubuğu baloncuğu)**
  - Yeni nesil Android "dinamik buton/hap" entegrasyonu
  - Arka plandayken durum çubuğunda minik gösterge
  - Tıklandığında üstten şık kontrol paneli
  - **WP-17 tamamlandı:** Android One UI kilit ekranı progress ve kalıcı durum çubuğu bildirimi eklendi.
  - *Kaynak: new_features.md §5 Madde Live Activities*

- [x] **Kilit ekranı widget'ı**
  - Android kilit ekranında sayaç/istatistik gösterimi
  - **WP-6 tamamlandı:** Kilit ekranı (public visibility) bildirim görünürlüğü eklendi.

- [x] **Sınıf sohbeti (chat)**
  - Her sınıfa mesajlaşma özelliği
  - ClassDetailScreen'de "Sohbet" sekmesi (yer ayrılmış)
  - **WP-7 tamamlandı:** Sınıf detayında canlı `class_messages` RLS sohbeti eklendi.
  - *Kaynak: project.md §3.8, progress.md FAZ 3.6*

- [x] **Oyunlaştırma: streak freeze, taç/rozet, başarımlar**
  - Streak freeze (seri dondurma) hakkı — Chess.com/Duolingo benzeri
  - Günün birincisine taç 👑, hafta birincisine rozet
  - Başarımlar: "Gece Kuşu", "Maratoncu", "Dürtücü" vb.
  - Profil sekmesi başarım alanına dönüşecek
  - **WP-9 tamamlandı:** Profilde gamification/başarımlar cüzdanı oluşturuldu.
  - *Kaynak: new_features.md §4 Madde 8, 13, 16, 17*

- [x] **Dürtme (nudge) sistemi**
  - Grup üyelerine çalışma daveti mesajı atabilme
  - **WP-8 tamamlandı:** Profil dürtme özelliği ve Android notification entegrasyonu yapıldı.
  - *Kaynak: new_features.md §5 Madde 8*

- [~] **Windows masaüstü build + widget**
  - Windows masaüstü build testi
  - Pencere/ekran uyarlamaları (responsive)
  - Always-on-top mini Flutter penceresi
  - **WP-11 tamamlandı:** Ancak kurulum paketi (`[ ] Windows kurulum paketi + dağıtım`) henüz bekliyor.
  - *Kaynak: project.md §3.6, progress.md FAZ 4.1-4.2*

- [ ] **Çoklu cihaz senkron testi**
  - Birden fazla Android + Windows arası senkron doğrulama
  - *Kaynak: progress.md FAZ 4.3*

- [x] **Daha fazla sınıf metriği**
  - Haftalık değişim
  - Ders bazında sınıf kıyası
  - En istikrarlı üye
  - **WP-10 tamamlandı:** Grup istatistiğine grup trend çizgisi, en aktif gün, en istikrarlı üye verileri eklendi.
  - *Kaynak: progress.md FAZ 3.10 kalan*

- [~] **Özelleştirilebilir saat stilleri (kalan)** — **WP-20 planlandı**
  - Sınıf "yarış"/dilim görünümü
  - Ek estetik stiller
  - *Kaynak: project.md §3.12*

- [x] **Çevrimdışı tespiti (heartbeat/yaşam-döngüsü)**
  - Uygulama kapanınca presence'ı offline'a çevirme
  - Heartbeat sistemi
  - **WP-5 tamamlandı:** `WidgetsBindingObserver` + Heartbeat ile presence bayatlama mantığı eklendi.
  - *Kaynak: progress.md FAZ 2.2 bekleyen*

- [x] **Arka planda süre tutma (mobil arka plan servisi)**
  - Telefon kilitlenince/arka plana alınınca sayacın devam etmesi
  - Platform-seviyesi çözüm
  - **WP-2 tamamlandı.**
  - *Kaynak: progress.md FAZ 2.1 bekleyen*

---

## 🟢 Düşük Öncelik / Fikir

- [x] **Beta/staging test uygulaması**
  - Ayrı paket adı (`.beta` uzantılı)
  - İki kanallı güncelleme (Stable + Beta)
  - **WP-13 tamamlandı.**
  - *Kaynak: new_features.md §6*

- [~] **Admin paneli (süper-admin arayüzü)** — **WP-14 planlandı (Codex)**
  - İlk teslim: sunucu-doğrulamalı süper-admin, salt-okunur kullanıcı/grup/oturum özeti ve geri bildirim/hata raporu merkezi.
  - *Kaynak: new_features.md §6*

- [~] **Samsung Modes & Routines entegrasyonu** — **WP-15 tamamlandı, WP-19 planlı**
  - Cihaz "Ders Çalışma Modu"nu algılama
  - Otomatik odak ekranına geçiş
  - **WP-15 tamamlandı:** Native Android App Shortcuts ve Flutter Servis köprüsü eklendi.
  - **WP-19 Planlandı:** Settings ekranından kontrol ve Timer/Navigasyon eylemlerinin UI state'e bağlanması.
  - *Kaynak: new_features.md §5*

- [ ] **Otomatik e-posta raporları**
  - Ay sonlarında kullanıcılara özet e-posta
  - **WP-14 sonrası bekliyor.**
  - *Kaynak: new_features.md §5 Madde 21*

- [ ] **Yeni grafik türleri**
  - Radar grafik vb.

- [x] **Çizgisel grup grafiği**
  - Tarihe bağlı grubun çalışma ivmesi çizgi grafiği
  - **WP-10 tamamlandı.**

- [x] **Grup içi tüm zamanlar istatistiği**
  - Sadece bugün/hafta değil, tüm zamanlar rekorları detaylı
  - **WP-10 tamamlandı.**

- [x] **Çevrimdışı cache (Drift/Hive)**
  - Yerel veri saklama, çevrimdışı dayanıklılık
  - **WP-12 tamamlandı:** Supabase ve in-memory repo'lar `offline_first_repository` pattern'iyle sarıldı.

- [ ] **Kapsamlı bildirim sistemi**
  - Kişiye özel çalışma hatırlatıcıları (açılıp kapatılabilen)

- [ ] **Windows kurulum paketi + dağıtım**
  - exe/MSIX kurulum paketi

- [~] **Grid boyutlandırma gelişmiş** (kullanıcı geri bildirimi) — **WP-21 planlandı**
  - Kartların 4 kenar ve köşeden (genişlik + yükseklik) ayarlanması

- [~] **Canlı grup hedefi** — **WP-22 planlandı**
  - Grup hedef ilerleme barının çalışan kişi sayısına göre saniye saniye akması

- [x] **Grup yönetimi UI iyileştirme**
  - Grup ayarları ve üye yönetiminin daha kolay/derli toplu yapılması
  - **WP-18 tamamlandı:** Ayarlar menüsü ve grup yönetimi ekranı sadeleştirildi.

---

## ❓ Açık Sorular

- Otomatik aylık rapor için hangi e-posta sağlayıcısı ve hangi gönderen adresi kullanılacak?
- Çoklu sınıf özelliği aktif olarak kullanılıyor mu yoksa tek sınıfa mı odaklanılmalı?
- Gelecek Widget planlamalarında ekranda en çok görülmek istenen bilgiler netleşti mi?
