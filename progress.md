# progress.md — İlerleme Takibi

> Bu dosya **sadece** "ne yaptık / ne yapılacak" takibidir. Detaylı fazlara ve alt-fazlara
> bölünmüştür. Proje bilgileri için → `project.md`. AI ajan kuralları için → `AGENTS.md`.
>
> Durum: `[ ]` yapılacak · `[~]` devam ediyor · `[x]` tamamlandı
> Son güncelleme: 2026-06-20

---

## Özet Durum

- **Aktif Faz:** Faz 0.2 — Geliştirme Ortamı Kurulumu (Android ortamı hazır ✅)
- **Sıradaki adım:** İskelet Flutter uygulamasını oluşturmak (`flutter create app`).

---

## FAZ 0 — Planlama & Kurulum

### 0.1 Planlama
- [x] Proje fikri netleştirildi
- [x] Tech stack kararı (Flutter + Supabase)
- [x] Giriş yöntemi kararı (e-posta + şifre)
- [x] İlk platform kararı (Android)
- [x] Dokümanlar oluşturuldu (project.md, progress.md, AGENTS.md)
- [~] Detaylı planlama (akış, ekranlar, özellik detayları) — *devam ediyor*
  - [ ] Genel akış / ekran haritası (sekmeler, navigasyon)
  - [ ] Sınıf mantığı detayı (tek/çok sınıf, davet kodu akışı)
  - [ ] Canlı çalışma ekranı detayı (masa/lamba, gösterilecek bilgiler)
  - [ ] Süre tutma mantığı (arka plan, kapanma, manuel giriş kuralları)
  - [ ] İstatistik detayı (grafik tipleri, metrikler, kıyaslamalar)
  - [ ] Widget detayı (içerik, boyut, platform önceliği)
  - [ ] Ders/kategori sistemi kararı
  - [ ] Tasarım dili (renk, tema, his) + örnek mockup'lar

### 0.2 Geliştirme Ortamı Kurulumu (planlama bitince)
- [x] Android Studio kurulumu (Android SDK 36 + JDK/jbr)
- [x] Flutter SDK 3.44.2 stable kurulumu (C:\src\flutter + PATH)
- [x] Android SDK bileşenleri (platform-tools, android-35/36, build-tools 35/36)
- [x] `flutter doctor` — Android toolchain ✅, JDK ✅, tüm Android lisansları kabul
- [ ] Visual Studio (C++ workload) — **Faz 4'e ertelendi** (sadece Windows masaüstü için)
- [ ] İskelet uygulama (`flutter create app`)
- [x] Git deposu başlatma (.gitignore dâhil)
- [x] GitHub uzak deposuna bağlanma (public: manil-max/online-study-room)

> Not: Flutter `C:\src\flutter`, Android SDK `C:\Android\Sdk`, JDK Android Studio jbr
> (`C:\Program Files\Android\Android Studio\jbr`). JAVA_HOME ve PATH (User) ayarlandı.
> Android lisanslarını CI tarzı dosyaya yazarak kabul ettik (interaktif prompt'tan kaçınmak için).

### 0.3 Supabase Kurulumu
- [ ] Ücretsiz Supabase hesabı + proje açma
- [ ] Uygulamaya Supabase client bağlantısı
- [ ] Ortam değişkenleri / anahtar yönetimi (.env)

---

## FAZ 1 — Temel: Hesap + Sınıf

### 1.1 Kimlik Doğrulama
- [ ] Kayıt ol (e-posta + şifre)
- [ ] Giriş yap / çıkış yap
- [ ] Oturum kalıcılığı (cihazda açık kalma)
- [ ] Şifre sıfırlama (opsiyonel)

### 1.2 Profil
- [ ] Profil ekranı (görünen ad)
- [ ] Profil fotoğrafı yükleme (Supabase Storage)
- [ ] Profil düzenleme

### 1.3 Sınıf / Grup
- [ ] Sınıf oluşturma + davet kodu üretimi
- [ ] Davet koduyla sınıfa katılma
- [ ] Sınıf üyelerini listeleme

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
