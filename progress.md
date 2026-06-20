# progress.md — İlerleme Takibi

> Bu dosya **sadece** "ne yaptık / ne yapılacak" takibidir. Detaylı fazlara ve alt-fazlara
> bölünmüştür. Proje bilgileri için → `project.md`. AI ajan kuralları için → `AGENTS.md`.
>
> Durum: `[ ]` yapılacak · `[~]` devam ediyor · `[x]` tamamlandı
> Son güncelleme: 2026-06-20

---

## Özet Durum

- **Aktif Faz:** Faz 2.3 (manuel giriş) TAMAMLANDI ✅ — Profil → Çalışma kayıtlarım: manuel ekle/düzenle/sil. Ayrıca Türkçe yerelleştirme eklendi. Önceki tamamlananlar: Faz 2.2 canlı presence, Faz 3 istatistikler. Sıradaki: Faz 1.2 profil foto (Supabase Storage bucket gerekir → kullanıcı kurulumu) / serbest tarih filtresi / Faz 4 widget.
- **Proje konumu:** `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room` (İngilizce ad — Türkçe/boşluklu yol Flutter'ı bozuyordu; aşağıdaki nota bak)
- **Sıradaki adım:** (1) Kullanıcı Supabase hesabı açar → `env.json` doldurulur → uçtan uca test. (2) Sonra Faz 3 (istatistik) gerçek veriyle.
- **Bekleyen (kullanıcı/admin):** Windows'ta eklenti derlemesi için **Geliştirici Modu** açılmalı (`ms-settings:developers`); web/Chrome çalıştırma için gerekmez.

---

## FAZ 0 — Planlama & Kurulum

### 0.1 Planlama
- [x] Proje fikri netleştirildi
- [x] Tech stack kararı (Flutter + Supabase)
- [x] Giriş yöntemi kararı (e-posta + şifre)
- [x] İlk platform kararı (Android)
- [x] Dokümanlar oluşturuldu (project.md, progress.md, AGENTS.md)
- [x] Detaylı planlama (altyapı için yeterli — kalanlar ilgili faza ertelendi)
  - [x] Genel akış / ekran haritası (3 sekme: Sınıf birleşik / İstatistik / Profil)
  - [x] Sınıf mantığı (tek sınıf, davet kodu; mimari çoklu sınıfa hazır)
  - [x] Canlı ekran (masa konsepti yok; kişi başına foto+isim+anlık+bugünkü+durum)
  - [x] Süre tutma (arka planda kesintisiz; manuel esnek; kaynak ayrımı yok)
  - [ ] İstatistik grafik detayı → Faz 3'e ertelendi
  - [ ] Widget detayı → Faz 4'e ertelendi
  - [ ] Ders/kategori sistemi kararı → ilgili faza ertelendi (subject_id opsiyonel)
  - [ ] Tasarım dili → en sona ertelendi (kullanıcı görselleri verecek)

### 0.2 Geliştirme Ortamı Kurulumu (planlama bitince)
- [x] Android Studio kurulumu (Android SDK 36 + JDK/jbr)
- [x] Flutter SDK 3.44.2 stable kurulumu (C:\src\flutter + PATH)
- [x] Android SDK bileşenleri (platform-tools, android-35/36, build-tools 35/36)
- [x] `flutter doctor` — Android toolchain ✅, JDK ✅, tüm Android lisansları kabul
- [ ] Visual Studio (C++ workload) — **Faz 4'e ertelendi** (sadece Windows masaüstü için)
- [x] İskelet uygulama (`flutter create`) — `app/`, org com.manilmax, platformlar: android/windows/web
- [x] `flutter analyze` temiz (No issues found)
- [x] Git deposu başlatma (.gitignore dâhil)
- [x] GitHub uzak deposuna bağlanma (public: manil-max/online-study-room)
- [x] **Proje temiz (İngilizce adlı) yola taşındı** → `...\Desktop\Dev\online-study-room`

> **Geliştirme ortamı yolları:**
> - Proje: `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room`
>   (klasör adı İngilizce/boşluksuz olmalı — Türkçe karakter/boşluk Flutter'ı bozuyor; OneDrive sorun değil)
> - Flutter: `C:\src\flutter` · Android SDK: `C:\Android\Sdk`
> - JDK: Android Studio jbr (`C:\Program Files\Android\Android Studio\jbr`)
> - JAVA_HOME ve PATH (User) ayarlandı. Android lisansları CI tarzı dosyaya yazılarak kabul edildi.
> - ⚠️ Gelecek oturumları bu klasörde aç. Proje yolunda Türkçe karakter/boşluk OLMAMALI.

> **Geliştirme komutları (PowerShell):** Her komuttan önce ortamı ayarla:
> ```
> $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
> $env:Path = "C:\src\flutter\bin;" + $env:Path
> Set-Location "C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room\app"
> ```
> Sonra: `flutter analyze` · `flutter test` · `flutter run -d chrome` (tarayıcıda göster) ·
> `flutter build apk --release` (telefona kurmak için APK).
> GitHub: `manil-max/online-study-room` (public, gh CLI kurulu, push yetkili).

### 0.3 Supabase Kurulumu
- [~] Ücretsiz Supabase hesabı + proje açma — **kullanıcıda** (bkz. `supabase/README.md`)
- [x] Veritabanı şeması yazıldı (`supabase/migrations/0001_initial_schema.sql`) — tablolar + trigger + RLS
- [x] Uygulamaya Supabase client bağlantısı (`main.dart` + `core/config/supabase_config.dart`)
- [x] Supabase repository implementasyonları (auth/group/study) — provider'lar anahtar varsa otomatik geçiş
- [x] Ortam değişkeni / anahtar yönetimi (`--dart-define-from-file=env.json`, `env.example.json` şablon, `env.json` gitignore)
- [x] Anahtarlar girilip uçtan uca test — kayıt/sınıf/oturum gerçek Supabase'e yazıldı ✅
- [x] Web passkeys hatası giderildi (`web/passkeys_bundle.js` + index.html)

---

## FAZ 1 — Temel: Hesap + Sınıf

### 1.0 Uygulama Kabuğu (iskelet)
- [x] Klasör mimarisi (lib/core, lib/features)
- [x] Riverpod kurulumu (ProviderScope)
- [x] 3 sekmeli navigasyon (Sınıf / İstatistik / Profil) — NavigationBar + IndexedStack
- [x] Geçici tema (Material 3, açık/koyu) — nihai tasarım en sonda
- [x] Yer tutucu ekranlar + widget testleri (geçiyor)

### 1.1 Kimlik Doğrulama
- [x] Kayıt ol (e-posta + şifre) — *bellek-içi backend ile (Supabase'e kadar geçici)*
- [x] Giriş yap / çıkış yap
- [x] AuthGate (oturuma göre giriş ekranı ↔ ana uygulama)
- [ ] Oturum kalıcılığı (cihazda açık kalma) — Supabase ile gelecek
- [ ] Şifre sıfırlama (opsiyonel)

> Mimari not: Repository deseni kullanıldı. `AuthRepository` (soyut) + `InMemoryAuthRepository`
> (geçici). Supabase gelince sadece provider'daki implementasyon değişecek, UI aynı kalacak.

### 1.2 Profil
- [ ] Profil ekranı (görünen ad)
- [ ] Profil fotoğrafı yükleme (Supabase Storage)
- [ ] Profil düzenleme

### 1.3 Sınıf / Grup
- [x] Sınıf oluşturma + davet kodu üretimi (6 haneli) — *bellek-içi*
- [x] Davet koduyla sınıfa katılma
- [x] Sınıf üyelerini listeleme (canlı)
- [x] Sınıf ekranı: sınıf yoksa oluştur/katıl, varsa ad+kod+üyeler

### 1.4 Veritabanı & Güvenlik
- [ ] Tablo şemaları (profiles, groups, group_members, study_sessions)
- [ ] RLS politikaları (veri izolasyonu)
- [ ] Migration'ların kaydı (/supabase)

---

## FAZ 2 — Canlı Çalışma

### 2.1 Süre Tutma
- [x] Çalışma başlat / durdur (timer) — sayaç kartı, canlı süre, bugünkü toplam
- [x] Oturum kaydı (study_sessions'a yazma) — *bellek-içi*
- [ ] Arka planda / kapanmada davranış — mobil arka plan servisi sonra (platform işi)
- [ ] Mola (break) mantığı — sonra

### 2.2 Canlı Sınıf Ekranı
- [x] Realtime presence altyapısı (kim online/çalışıyor) — `PresenceRepository` (in-memory + Supabase), `presence` tablosu (şemada hazırdı), sayaç başlat/durdur presence yazıyor
- [ ] Masa/lamba görselleştirmesi — tasarım aşamasına (en sona) ertelendi
- [x] Kimin ne kadar süredir çalıştığı gösterimi — üye kartında durum noktası + anlık sayaç + bugünkü toplam, çalışanlar üstte sıralı
- [ ] Çevrimdışı tespiti (uygulama kapanınca/heartbeat) — sonra (şu an yalnızca durdurunca offline)

### 2.3 Manuel Giriş
- [x] Gün sonu manuel süre ekleme — Profil → "Çalışma kayıtlarım" → Manuel ekle (tarih + saat/dk)
- [x] Manuel giriş kuralları (düzenleme, silme) — her oturum düzenlenip silinebilir; gelecek tarih seçilemez
- [x] StudyRepository'ye `updateSession` + `deleteSession` eklendi (in-memory + Supabase)
- [x] Türkçe yerelleştirme (flutter_localizations) — tarih seçici vb. Türkçe

---

## FAZ 3 — İstatistikler

- [x] Veri sorguları (günlük/haftalık/aylık/yıllık) — saf hesaplama katmanı `core/stats/study_stats.dart`
- [x] Günlük ortalama hesaplama (son 30 gün, çalışılmayan günler paydada)
- [x] Hafta içi / hafta sonu ayrımı
- [~] Seçili tarih aralığı filtreleri — trend grafiğinde 7/14/30 gün seçici var; serbest tarih aralığı sonra
- [x] Grafikler (fl_chart) — günlük çubuk grafiği + dönemler arası kıyas kartı
- [x] Kıyaslamalı görünümler (kullanıcılar / dönemler arası) — dönemler arası (hafta) + sınıf leaderboard ✅

> 3a TAMAM: İstatistik ekranı Kişisel/Sınıf sekmelerine ayrıldı. Kişisel: dönem toplamları
> (bugün/hafta/ay/yıl) + günlük ortalama + hafta içi/sonu kartları. Tüm hesaplama saf
> fonksiyonlarda, testli.
> 3b TAMAM: fl_chart 1.2.0 eklendi. Günlük çubuk grafiği (7/14/30 gün seçici) + "bu hafta
> vs geçen hafta" kıyas kartı (artış/azalış göstergesi) kişisel görünüme eklendi.
> 3c TAMAM: Sınıf sekmesi leaderboard'a dönüştü — dönem seçici (bugün/hafta/ay), sınıf
> toplamı + kişi başı ortalama, madalyalı sıralama (oransal çubuk, "sen" vurgusu).
> Kalan (sonra): serbest tarih aralığı filtresi.

---

## FAZ 4 — Çoklu Platform & Widget

### 4.1 Windows
- [ ] Windows masaüstü build + test
- [ ] Pencere/ekran uyarlamaları (responsive)

### 4.2 Widget'lar
- [ ] Android ana ekran widget'ı (home_widget)
- [ ] Widget'tan tek dokunuşla çalışma başlatma
- [ ] Windows widget'ı (always-on-top mini pencere)

### 4.3 Senkron Testi
- [ ] Birden fazla Android cihaz + Windows arası senkron testi

---

## FAZ 5 — Yayın & Dağıtım

- [ ] Release APK üretimi
- [ ] Cihazlara kurulum (sideload)
- [ ] Windows kurulum paketi
- [ ] Kullanım / kurulum notları (/docs)

---

## Yapılanlar Günlüğü

- **2026-06-20:** Proje başlatıldı. Dokümanlar oluşturuldu (project.md, progress.md,
  AGENTS.md). Tech stack, giriş yöntemi ve ilk platform kararlaştırıldı. Detaylı planlama
  aşamasına geçildi.
- **2026-06-21:** Geliştirme ortamı kuruldu (Flutter 3.44.2 + Android SDK 36). İskelet
  uygulama oluşturuldu, proje temiz yola (C:\Dev\online-study-room) taşındı. Uygulama kabuğu:
  3 sekmeli navigasyon + Riverpod + geçici tema + yer tutucu ekranlar; testler geçiyor.
- **2026-06-21 (otonom):** Veri modelleri (Profile/StudyGroup/StudySession/Presence) eklendi.
  Auth katmanı: AuthRepository + InMemoryAuthRepository + giriş/kayıt ekranı + AuthGate +
  profil ekranında çıkış. Uygulama artık giriş ekranıyla açılıyor. 8/8 test geçiyor.
- **2026-06-21 (Supabase entegrasyonu):** `supabase_flutter` eklendi. Veritabanı şeması
  (`supabase/migrations/0001_initial_schema.sql`): profiles/groups/group_members/subjects/
  study_sessions/presence + otomatik profil trigger'ı + RLS (sınıf içi tam şeffaflık) + Realtime.
  Supabase repository'leri (auth/group/study) yazıldı; provider'lar `SupabaseConfig.isConfigured`
  ile anahtar varsa Supabase'e, yoksa bellek-içine geçiyor (UI değişmedi). Anahtarlar
  `--dart-define-from-file=env.json` ile veriliyor. Analiz temiz, 18/18 test geçiyor.
  Kullanıcı kurulum rehberi: `supabase/README.md`.
- **2026-06-21 (Faz 2.2 canlı presence ✅):** Presence katmanı eklendi:
  `PresenceRepository` (soyut) + bellek-içi + Supabase (`presence` tablosuna upsert,
  Realtime stream). Sayaç başlat/durdur kendi presence'ını yazıyor (başla→çalışıyor,
  durdur→çevrimdışı). Sınıf ekranı YPT tarzı canlı listeye dönüştü: her üyede durum
  noktası (yeşil/turuncu/gri), çalışana anlık sayaç (her sn yenilenir) ve bugünkü toplam;
  çalışanlar üstte. Bugünkü toplam `study_sessions`'tan türetiliyor (presence.today_seconds
  yalnızca bilgi amaçlı). 21/21 test geçiyor, analiz temiz. Karar: heartbeat/yaşam-döngüsü
  çevrimdışı tespiti ve mola butonu sonraya bırakıldı (şu an durum: çalışıyor/çevrimdışı).
- **2026-06-21 (Supabase uçtan uca ✅):** Proje İngilizce yola taşındı
  (`...\Desktop\Dev\online-study-room`), `C:\Dev` silindi. Kullanıcı Supabase projesi açtı,
  şema kuruldu, e-posta doğrulaması kapatıldı, anahtarlar `env.json`'a girildi. Web'de passkeys
  hatası `web/passkeys_bundle.js` ile giderildi. Chrome'da kayıt → sınıf → çalışma kaydı
  test edildi; veriler gerçek veritabanında (profiles/groups/study_sessions) doğrulandı.
