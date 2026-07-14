# backlog.md — Yapılacaklar (Öncelik Sıralı)

> Üstteki en öncelikli. Yeni fikir en alta eklenir, birlikte sıralanır.
> Bir işe başlayınca buradan alınır → `progress.md`'ye WP olarak geçer.
> **Öncelik artık `docs/KALITE-PROGRAMI.md` faz sırasına tabidir** (Faz 0 → V8 Güven → Saat → Tema → Başarım → Masaüstü). Kaynak: KALITE-PROGRAMI + `progress.md` + `project.md` açık sorular.

---

## 🔴 Yüksek Öncelik

- [x] **Kalite Programı — Faz 0 + V8 Güven Sürümü** — **WP-37–47 teslim edildi; v8 yayımlandı**
  - **Faz 0A:** Tek kaynak & tamamlanma denetimi — **WP-37 + WP-38 tamamlandı**; canlı migration/RLS uygulama teyidi release kapısında yeniden doğrulanır.
  - **Faz 0B:** Test & gözlemlenebilirlik temeli — **WP-46 (integration + native QA matrisi), WP-47 (Sentry/gözlemlenebilirlik)**.
  - **V8-A:** Sayaç–bildirim–widget tek doğruluk kaynağı — **WP-40 (state store+foreground), WP-41 (chronometer bildirim), WP-42 (widget paritesi) planlandı.**
  - **V8-B:** Genel senkronizasyon denetimi — **WP-43 planlandı.**
  - **V8-C:** Küçük IA — **WP-44 (istatistik sırası) + WP-45 (gruplar sırası/kamp ateşi/animasyon) planlandı.**
  - **V8 yayın kararı:** v8 yayımlandı; WP-48/49/50, ürün sahibinin doğrudan yayın ve soak'ı atlama kararıyla kaldırıldı. Yeni yayın sorunu ayrı debug/release WP'si olur.
  - *Kaynak: kalite pivotu 2026-07-12; KALITE-PROGRAMI §7–8. WP-39 kullanıcı kararıyla iptal edildi.*

- [x] **Kamp Ateşi R2 — görsel yeniden tasarım + PNG seti + animasyon** — **WP-61 (onaylandı), WP-62 (kod tamamlandı/QA bekliyor)**
  - WP-61, özgün görsel yönü ve PNG asset sözleşmesini kapattı.
  - WP-62, onaylı assetleri katmanlı, performanslı sahneye dönüştürdü. Demo/Cihaz QA bekliyor.

- [x] **Android Widget R2 — native yüzeyler** — **WP-63 + WP-68 tamamlandı (Tamamlanan)**
  - 1×1 Başlat/Durdur sayaç; günlük hedef, grup hedef ve grup sıralaması widget'ları WP-68'de kodlandı.
  - Kilit ekranında/büyük widget'ta veri gösterimi ayarlandı. Cihaz QA bekliyor.

- [~] **Hesap silme ve veri saklama politikası** — **WP-66 karar dokümanı hazır (Tamamlanan); RETENTION KARARI bekliyor**
  - Soft-delete, geri alma süresi, kalıcı silme onayı ve retention süreleri **senin kararınla** netleşince implementasyon WP'si açılır.

- [x] **"Tamamlandı" görünüp ürün kabulü bekleyenler** — Faz 0'da yeniden sınıflandırılmıştı.
  - WP-23 (Saat), WP-26 (Tema), WP-35 (Başarım), WP-36 (IA) yeniden çalışılarak V8 (Güven Sürümü) ve diğer programlarda (Saat, Tema Stüdyosu, Sosyal Profil 3.0) tamamlandı.

- [x] **Hesabımı yönet merkezi** — **WP-31 tamamlandı**
  - Profil/Ayarlar içinde bağlı e-posta, şifre sıfırlama, e-posta değiştirme ve güvenli çıkış özellikleri kodlandı.

- [x] **Geri bildirime ekran görüntüsü ekleme** — **WP-32 tamamlandı**
  - Hata/öneri gönderirken güvenli ekran görüntüsü ekleme yeteneği kodlandı.

- [x] **Süper-admin operasyon merkezi** — **WP-33 ve WP-34 tamamlandı**
  - Kullanıcı listesi, güvenli reset, grup moderasyonu ve uygulama içi duyurular yapıldı. (Hesap silme ayrı bir kart/politika [WP-66] ile planlanıyor).

- [x] **Sosyal Profil 3.0 + aşamalı Başarı Yolculuğu** — **WP-35, WP-56, WP-57 tamamlandı**
  - Profil zenginleştirildi; sunucu onaylı (server-authoritative) 60+ başarı, XP, seri alevi ve grup vitrini tamamlandı.

- [x] **Beş sekmeli bilgi mimarisi + Bildirim Merkezi** — **WP-36 tamamlandı**
  - Ana Sayfa çalışma alanına dönüştürüldü; Saat/Gruplar/İstatistik/Profil ayrı alanlara sahip oldu.
  - Ayarlar içindeki Bildirim Merkezi (hatırlatıcı, duyuru, ayarlar) tamamlandı.

- [x] **Stable/Beta app icon + release notes sistemi** — **WP-29 ve WP-30 tamamlandı**
  - Stable uygulama ikonu `references/app icon/` içindeki referans görselden yenilenecek.
  - Beta uygulama ikonu stable'dan ayırt edilebilir olacak (rozet/renk/şerit gibi).
  - Sürüm listesi hem GitHub release tarafında hem repo içinde MD/JSON olarak tutulacak.
  - Güncelleme sonrası tek seferlik “Yenilikler” pop-up'ı gösterilecek.
  - Profil/Ayarlar’dan geçmişten bugüne güncelleme notları okunabilecek.
  - Yeni güncelleme varsa izinli cihazlarda local update bildirimi değerlendirilecek; gerçek push/FCM ayrı fazdır.
  - *Kaynak: kullanıcı geri bildirimi; WP-29/WP-30.*

- [x] **Windows desktop ürünü + güvenilir dağıtım** — **WP-27/52/53/28/70/71 tamamlandı (Tamamlanan; cihaz smoke sorun→debug)**
  - Yerel denetim: Flutter 3.44.2, Visual Studio 2022 ve Windows SDK hazır; eski “build ortamı yok” notu güncel değil. Mevcut uygulama hâlâ mobil alt navigasyon + sınırsız büyüyen grid kullanıyor.
  - **WP-27:** Windows-only adaptif sol rail (`<640` minimal, `640–1007` kompakt, `≥1008` geniş), max 1440 px desktop içerik, klavye/fare/Narrator/high-contrast, pencere state'i ve bütün uygulamayı küçültmeyen ayrı Compact Focus.
  - **WP-52:** Telefon/tablet/Windows için cihaz-yerel 6/8/12/16 sütun dashboard profilleri; güvenli layout göçü ve kayıpsız yoğunluk geçişi.
  - **WP-53:** Beş ana ekranın command bar/master-detail/çok panel düzenleriyle gerçek Windows ekran-içi ürün tasarımı; büyütülmüş mobil akış ana IA olmayacak.
  - **WP-28:** Odak Kampı runner metadata/ikon, MSIX kimliği/imza, Windows CI, Store/App Installer update stratejisi, temiz VM install→update→uninstall ve release QA.
  - Stable önerisi Microsoft Store MSIX; ZIP yalnız geliştirme/portable yedek. Yalnız Windows 11 hedeflenir; Windows 10 kapsam dışıdır.
  - Kanonik araştırma/tasarım: `docs/WINDOWS-URUN-PLANI.md` · program kapısı: `docs/KALITE-PROGRAMI.md §8.7`.
  - *Kaynak: kullanıcı geri bildirimi + WP-11 Windows EXE sonrası durum + Microsoft/Flutter resmi dokümanları.*

- [x] **Görünüm Sistemi 2.0 — tam tema stüdyosu + sabit renk temizliği** — **WP-26, WP-54, WP-55 tamamlandı**
  - Sabit renk/`Colors.*` kullanımları tokenlara bağlandı.
  - Atmosfer temaları, renk rolleri, köşe/gradient slotları Tema Stüdyosu'nda uygulandı.

- [x] **Android 3 tuşlu navigasyon safe-area düzeltmesi** — **WP-25 tamamlandı**
  - Samsung S26 Ultra gibi 3 tuşlu navigation kullanan cihazlarda sohbet/form/bottom action alanları sistem tuşlarının altında kalmamalı.
  - Gesture navigation kullanan cihazlarda gereksiz ekstra boşluk oluşturmayacak şekilde `viewPadding.bottom` / `SafeArea` standardı kurulacak.
  - *Kaynak: kullanıcı geri bildirimi; WP-25.*

- [x] **Saat sekmesi / Clock Center — dünya standartlarında zaman deneyimi** — **WP-23, WP-24, WP-58, WP-59, WP-60 tamamlandı**
  - Beş sekmeli yapı kuruldu, yatay StandBy ekranı getirildi.
  - Dünya saati, kronometre, çoklu timer, alarm (kesin, görevli vb.) sorunsuz çalışır hale getirildi.
  - `timer_foreground_service` ve WP-41/42 native bildirimlerle desteklendi.

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
  - Timer karti responsive adaptasyonu (2E'de hariç tutuldu)
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
  - [x] **Arka plan güvenilirliği — büyük ölçüde YAPILDI:** native `Chronometer` widget canlı saat (`StudyWidgetProviders.kt`, `odak_timer_widget.xml`), `StudyTimerService.kt` foreground service, `StudyStatsWidgetProvider`/`GroupLeaderboardWidgetProvider` gerçek veri (WP-68). (2026-07-14 teyit.)
  - [ ] **Kalan dar bug (cihazda tekrar üret → debug WP):** idle bildirim varken uygulamadan kronometre başlatınca bildirim 00:00:00 Başlat'ta kalıyor (senkron). Hafıza: `notif-not-syncing-on-inapp-start`.
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

- [x] **Windows masaüstü build + widget**
  - Windows masaüstü build testi
  - Pencere/ekran uyarlamaları (responsive)
  - Always-on-top mini Flutter penceresi
  - **WP-11 tamamlandı:** Ancak kurulum paketi (`[ ] Windows kurulum paketi + dağıtım`) henüz bekliyor.
  - *Kaynak: project.md §3.6, progress.md FAZ 4.1-4.2*

- [x] **Çoklu cihaz senkron testi** — **WP-64 tamamlandı (Tamamlanan; şablon/matris + kurtarma provası)**
  - Birden fazla Android + Windows arası senkron doğrulama
  - WP-53 ürün kabulünden sonra iki Android + Windows ile QA/kurtarma provası yapılacak.

- [x] **Daha fazla sınıf metriği**
  - Haftalık değişim
  - Ders bazında sınıf kıyası
  - En istikrarlı üye
  - **WP-10 tamamlandı:** Grup istatistiğine grup trend çizgisi, en aktif gün, en istikrarlı üye verileri eklendi.
  - *Kaynak: progress.md FAZ 3.10 kalan*

- [x] **Özelleştirilebilir saat stilleri (kalan)** — **YAPILDI**
  - `clock_style.dart` `ClockStyle` enum: `slice` (yarış dilimi), `ring`, `colorShift`, `minimal`, `digits` = 5 stil. (2026-07-14 teyit; eski WP-20 gereksiz.)
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

- [x] **Admin paneli (süper-admin arayüzü)** — **WP-14 tamamlandı**
  - Sunucu-doğrulamalı süper-admin, salt-okunur kullanıcı/grup/oturum özeti ve geri bildirim/hata raporu merkezi teslim edildi.
  - Ayarlar'daki `Yönetim` girişi yalnız `app_admins` tablosunda tanımlı süper-adminlere görünür; normal kullanıcılar geri bildirim gönderip kendi raporlarını takip edebilir.
  - Kurulum notu: `0018_admin_feedback.sql` uygulandıktan sonra ilk yönetici, Supabase SQL Editor'dan `app_admins` tablosuna eklenmelidir.
  - *Kaynak: new_features.md §6*

- [x] **Samsung Modes & Routines entegrasyonu** — **WP-15 ve WP-19 tamamlandı**
  - Cihaz "Ders Çalışma Modu"nu algılama
  - Otomatik odak ekranına geçiş
  - **WP-15 tamamlandı:** Native Android App Shortcuts ve Flutter Servis köprüsü eklendi.
  - **WP-19 tamamlandı:** Settings ekranından kontrol ve Timer/Navigasyon eylemlerinin UI state'e bağlanması.
  - *Kaynak: new_features.md §5*

- [x] **Otomatik e-posta raporları** — **WP-65 onaylandı, WP-69 kodlandı**
  - Ay sonlarında (her ayın 2'sinde) e-posta üzerinden çalışma raporu gönderme altyapısı kuruldu (Resend + pg_cron). E-posta onayı (opt-in) eklendi.

- [~] **Yeni grafik türleri** — **WP-67 brief hazır (Tamamlanan); implementasyon için ONAY bekliyor**
  - Radar grafik vb. Katalog/brief teslim edildi; **senin onayınla** kod WP'si açılır.

- [x] **Çizgisel grup grafiği**
  - Tarihe bağlı grubun çalışma ivmesi çizgi grafiği
  - **WP-10 tamamlandı.**

- [x] **Grup içi tüm zamanlar istatistiği**
  - Sadece bugün/hafta değil, tüm zamanlar rekorları detaylı
  - **WP-10 tamamlandı.**

- [x] **Çevrimdışı cache (Drift/Hive)**
  - Yerel veri saklama, çevrimdışı dayanıklılık
  - **WP-12 tamamlandı:** Supabase ve in-memory repo'lar `offline_first_repository` pattern'iyle sarıldı.

- [x] **Windows kurulum paketi + dağıtım** — **WP-28 tamamlandı** (MSIX + imza + update + release QA hattı)

- [x] **Grid boyutlandırma gelişmiş / serbest sürükle-bırak** (kullanıcı geri bildirimi) — **YAPILDI**
  - `home_screen.dart`: `LongPressDraggable` + `DragTarget` ile serbest taşıma, `_ResizeHandle` (4 kenar/köşe) ile boyutlandırma, canlı reflow önizleme. (2026-07-14 proje denetiminde teyit; eski WP-21 gereksiz.)

- [x] **Canlı grup hedefi** — **YAPILDI**
  - `group_goal_card.dart`: çalışan sayısına göre saniye saniye biriken `_virtualOffset` + `TweenAnimationBuilder` akan bar. (2026-07-14 teyit; eski WP-22 gereksiz.)
  - Grup hedef ilerleme barının çalışan kişi sayısına göre saniye saniye akması

- [x] **Grup yönetimi UI iyileştirme**
  - Grup ayarları ve üye yönetiminin daha kolay/derli toplu yapılması
  - **WP-18 tamamlandı:** Ayarlar menüsü ve grup yönetimi ekranı sadeleştirildi.

---

## ❓ Açık Sorular

- Çoklu sınıf özelliği aktif olarak kullanılıyor mu yoksa tek sınıfa mı odaklanılmalı?
- WP-63 için: Gelecek Widget düzenlemesinde ekranda en çok görülmek istenen bilgi, boyut ve etkileşim nedir?
- WP-66 için: Hesap silme sunulacak mı; geri alma süresi, retention ve kalıcı silme onayı nasıl olacak?

## Windows Masaüstü Optimizasyonu
- [x] **WP-70 Windows performans tabanı** — tamamlandı (Tamamlanan). p95 Working Set 85.9 MB / pencere 437 ms; 300–400 MB iddiası temiz release'te üretilmedi. Bulgu çıkarsa ayrı düzeltme WP'si.
- **Sorun:** Windows release'i boşta 300-400 MB RAM tüketiyor ve hafif donmalar var.
- **Aksiyon:** Önce tekrarlanabilir yerel örnekleme ve p50/p95 tabanı alınacak; yalnız kanıtlanan render/bellek darboğazları ayrı WP'lerde çözülecek.
