# progress.md — İlerleme Takibi

> Bu dosya **sadece** "ne yaptık / ne yapılacak" takibidir. Detaylı fazlara ve alt-fazlara
> bölünmüştür. Proje bilgileri için → `project.md`. AI ajan kuralları için → `AGENTS.md`.
>
> Durum: `[ ]` yapılacak · `[~]` devam ediyor · `[x]` tamamlandı
> Son güncelleme: 2026-06-20

---

## Özet Durum

- **Aktif Faz:** Faz 1 — auth + sınıf (1.1/1.3) bellek-içi çalışıyor ✅ → sıradaki Faz 2 (canlı sayaç)
- **Proje konumu:** `C:\Dev\online-study-room` (OneDrive/Türkçe yoldan taşındı — aşağıdaki nota bak)
- **Sıradaki adım (otonom):** Faz 2 — çalışma sayacı (başlat/durdur) + oturum kaydı + canlı presence (bellek-içi). Supabase kullanıcı döndüğünde.

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
- [x] **Proje temiz yola taşındı** → `C:\Dev\online-study-room`

> **Geliştirme ortamı yolları:**
> - Proje: `C:\Dev\online-study-room` (Türkçe/boşluklu/OneDrive yol Flutter'ı bozduğu için taşındı)
> - Flutter: `C:\src\flutter` · Android SDK: `C:\Android\Sdk`
> - JDK: Android Studio jbr (`C:\Program Files\Android\Android Studio\jbr`)
> - JAVA_HOME ve PATH (User) ayarlandı. Android lisansları CI tarzı dosyaya yazılarak kabul edildi.
> - ⚠️ Gelecek oturumları `C:\Dev\online-study-room` içinde aç. Proje yolunda Türkçe karakter/boşluk OLMAMALI.

### 0.3 Supabase Kurulumu
- [ ] Ücretsiz Supabase hesabı + proje açma
- [ ] Uygulamaya Supabase client bağlantısı
- [ ] Ortam değişkenleri / anahtar yönetimi (.env)

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
- [ ] Çalışma başlat / durdur (timer)
- [ ] Oturum kaydı (study_sessions'a yazma)
- [ ] Arka planda / kapanmada davranış
- [ ] Mola (break) mantığı

### 2.2 Canlı Sınıf Ekranı
- [ ] Realtime presence altyapısı (kim online/çalışıyor)
- [ ] Masa/lamba görselleştirmesi
- [ ] Kimin ne kadar süredir çalıştığı gösterimi

### 2.3 Manuel Giriş
- [ ] Gün sonu manuel süre ekleme
- [ ] Manuel giriş kuralları (limit, düzenleme, silme)

---

## FAZ 3 — İstatistikler

- [ ] Veri sorguları (günlük/haftalık/aylık/yıllık)
- [ ] Günlük ortalama hesaplama
- [ ] Hafta içi / hafta sonu ayrımı
- [ ] Seçili tarih aralığı filtreleri
- [ ] Grafikler (fl_chart)
- [ ] Kıyaslamalı görünümler (kullanıcılar / dönemler arası)

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
