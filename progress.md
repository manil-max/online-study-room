# progress.md — İlerleme Takibi

> Bu dosya **sadece** "ne yaptık / ne yapılacak" takibidir. Detaylı fazlara ve alt-fazlara
> bölünmüştür. Proje bilgileri için → `project.md`. AI ajan kuralları için → `AGENTS.md`.
>
> Durum: `[ ]` yapılacak · `[~]` devam ediyor · `[x]` tamamlandı
> Son güncelleme: 2026-06-20

---

## Özet Durum

- **Aktif Faz:** FAZ 5.1 - Otomatik Güncelleme Sistemi (GitHub Releases). Kod + CI hazır; kalan = GitHub Secrets kurulumu ve ilk `v2` tag testi.
- **Proje konumu:** `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room` (İngilizce ad — Türkçe/boşluklu yol Flutter'ı bozuyordu; aşağıdaki nota bak)
- **Sıradaki adım:** 2026-06-22 geri bildirim turu büyük ölçüde işlendi: Sınıf→Grup terminolojisi,
  Derssiz→Genel, profilden Derslerim kaldırma, uzun tarih, büyük seri, İstatistik grup
  değiştirici, seçilebilir metin, tıklanabilir sıralama + üye bilgi sayfası, grup üye serileri.
  **Kalan büyük işler (FAZ 3.11 — aşağıda):** (1) **Grup hedefi** (admin-ayarlı, migration 0006)
  ve grup serisinin gruba göre hesaplanması; (2) **Zengin & etkileşimli Ana Sayfa**: kartları
  **yeniden boyutlandırma** (küçük/orta/büyük), 2 sütun grid, veri formatı seçimi, daha çok
  kart türü; (3) **etkileşimli istatistik**: grafik dokunmatik ipuçları, takvim **ısı haritası**
  (study streak heatmap), çizgi grafiği, tablo görünümü.
- **Bekleyen (kullanıcı/admin):** Kalmadı ✅ (Tüm temel veritabanı migration'ları 0001–0007 başarıyla Supabase'e uygulandı).
- **Çözüldü (2026-06-21):** Windows **Geliştirici Modu açıldı** ✅ — eklentiler (image_picker vb.) symlink gerektirdiği için **web/Chrome derlemesi de** bunu istiyormuş (önceki not yanlıştı). Kapalıyken `flutter run -d chrome` "Error when reading ../../../../../AppData/.../package: cannot find path" + binlerce takip hatası veriyordu. `flutter clean && flutter pub get` + Geliştirici Modu ile düzeldi; `flutter build web` temiz derleniyor.

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
- [x] Oturum kalıcılığı (cihazda açık kalma) — `supabase_flutter` oturumu varsayılan
  olarak yerel depolamada tutar ve açılışta geri yükler; ek olarak profil çekimi
  çevrimdışı/hata durumunda kullanıcıyı dışarı atmaz (metadata'dan geçici profille içeride kalır)
- [ ] Şifre sıfırlama (opsiyonel)

> Mimari not: Repository deseni kullanıldı. `AuthRepository` (soyut) + `InMemoryAuthRepository`
> (geçici). Supabase gelince sadece provider'daki implementasyon değişecek, UI aynı kalacak.

### 1.2 Profil
- [x] Profil ekranı (görünen ad) — avatar, ad, çıkış, "Çalışma kayıtlarım" girişi
- [x] Profil fotoğrafı yükleme (Supabase Storage) — image_picker + `avatars` bucket'a upload;
  avatar profil/canlı liste/leaderboard'da gösteriliyor (`UserAvatar`). **Kullanıcı aksiyonu:**
  `migrations/0002_avatars_storage.sql` bir kez çalıştırılmalı (bkz. supabase/README.md §2.1)
- [x] Profil düzenleme (görünen ad) — kalem ikonu → düzenle diyaloğu (`updateDisplayName`)

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
- [x] Mola (break) mantığı — değerlendirildi ve KALDIRILDI (kullanıcı sade Başlat/Durdur istedi;
  mola süresi tutulmadığı için ayrı durum gereksizdi). Sayaç: çalışıyor / çevrimdışı.

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
- [x] Seçili tarih aralığı filtreleri — 7/14/30 gün hızlı seçici + serbest tarih aralığı kartı (toplam/günlük ort./grafik)
- [x] Grafikler (fl_chart) — günlük çubuk grafiği + dönemler arası kıyas kartı
- [x] Kıyaslamalı görünümler (kullanıcılar / dönemler arası) — dönemler arası (hafta) + sınıf leaderboard ✅

> 3a TAMAM: İstatistik ekranı Kişisel/Sınıf sekmelerine ayrıldı. Kişisel: dönem toplamları
> (bugün/hafta/ay/yıl) + günlük ortalama + hafta içi/sonu kartları. Tüm hesaplama saf
> fonksiyonlarda, testli.
> 3b TAMAM: fl_chart 1.2.0 eklendi. Günlük çubuk grafiği (7/14/30 gün seçici) + "bu hafta
> vs geçen hafta" kıyas kartı (artış/azalış göstergesi) kişisel görünüme eklendi.
> 3c TAMAM: Sınıf sekmesi leaderboard'a dönüştü — dönem seçici (bugün/hafta/ay), sınıf
> toplamı + kişi başı ortalama, madalyalı sıralama (oransal çubuk, "sen" vurgusu).
> 3d TAMAM: Serbest tarih aralığı kartı (showDateRangePicker) — seçili aralık için toplam +
> günlük ortalama + günlük grafik (≤45 gün). `dailyRange` yardımcısı testli. FAZ 3 TAMAM ✅.

---

## FAZ 3.5 — Dersler + Günlük Hedef + Seri (2026-06-21 kararı, §3.7)

> Kardeşin UI tasarımından gelen 3 özellik. İşlevsellik önce, görsel tasarım en sonda.

### 3.5.1 Dersler (kategoriler)
- [x] `subjects` repository (soyut + bellek-içi + Supabase) — ekle/düzenle/sil/listele;
  `Subject` modeli + renk paleti (`kSubjectColorTokens`, chart-1..5) + provider'lar.
  Realtime için `migrations/0003_subjects_realtime.sql` (kullanıcı bir kez çalıştırmalı).
  5 yeni test (42/42 geçiyor).
- [x] Ders yönetim UI (ad + renk paleti) — Profil → "Derslerim" (`SubjectsScreen`):
  ekle/düzenle/sil diyaloğu (ad + 5 renk seçici), silmede "derssize düşer" uyarısı.
  Renk token→Color eşlemesi `core/theme/subject_colors.dart`.
- [x] Sayaç başlatırken aktif ders seçimi → oturuma `subject_id` yazma — sayaç kartında
  ders seçici çipler ("Genel" + dersler); çalışırken seçili ders etiketi (kilitli).
  `StudyTimerState.subjectId` + `selectSubject()`; oturum o derse yazılıyor.
- [x] Manuel girişe ders seçimi — manuel ekle/düzenle diyaloğunda "Ders (opsiyonel)"
  çipleri; "Çalışma kayıtlarım" listesinde her oturumun dersi renk+ad ile gösteriliyor.
- [x] İstatistikte ders bazında dağılım — kişisel istatistikte "Ders bazında dağılım
  (son 30 gün)" kartı (oransal çubuklar, derssiz "Derssiz" altında). Saf fonksiyon
  `subjectBreakdown` + testi. **FAZ 3.5.1 TAMAM ✅**

### 3.5.2 Günlük hedef
- [x] `profiles.daily_goal_minutes` (`migrations/0005_daily_goal.sql`) + repository
  desteği (`updateDailyGoal`, Profile alanı, fromMap/toMap). **Kullanıcı çalıştırmalı.**
- [x] Hedef kartı — sayaç kartına **gömüldü**: ilerleme çubuğu + yüzde, hedefe ulaşınca
  yeşil; dokununca düzenle diyaloğu (saat/dakika sayaç, basılı-tut). `dailyGoalMinutesProvider`.

### 3.5.3 Seri (streak)
- [x] Saf hesaplama `currentStreak` (`core/stats`): hedefi tutturulan her gün +1, bugün
  sürdüğü için bugün eksikse kırılmaz (dünden sayar). 5 test.
- [x] Seri göstergesi — sayaç kartında 🔥 rozeti (`currentStreakProvider`, yalnız >0 iken).

---

## FAZ 3.6 — Sınıflar: Çoklu Sınıf + Admin (2026-06-21 kararı, §3.8)

> Eski "Sınıf" sekmesi "Sınıflar" olur; çoklu üyelik + sınıf değiştirici + admin.

- [x] Veri: `watchUserGroups` (çoğul, abstract+bellek-içi+Supabase) + `userGroupsProvider`
  (tüm üyelikler) + `activeGroupIdProvider` (seçili, şimdilik bellek-içi) + `userGroupProvider`
  artık aktif sınıfı türetiyor (AsyncValue — mevcut ekranlar değişmedi). 44/44 test.
  (Kalıcılık + yeni sınıfa otomatik geçiş sonraki adımda.)
- [x] `createGroup` oluşturanı `role='admin'` yapıyor (Supabase'de hazırdı ✅)
- [x] Sekme adı "Sınıflar"; ikona **basılı tut** → sınıf değiştirici alt sayfası
      (`class_switcher.dart`: sınıf listesi + aktif seçim + "Sınıf oluştur" + "Sınıfa katıl").
      Ayrıca üstteki sınıf adına/▾ ve sağdaki ↔ ikonuna dokununca da açılır. Oluştur/katıl
      sonrası yeni sınıf otomatik aktif olur. 44/44 test.
- [x] Sınıf başına ⋮ → `ClassDetailScreen` (bilgi: davet kodu/kopyala, oluşturulma, üyeler;
      ayarlar: sınıftan çık / admin: sınıfı sil). Admin = `group.createdBy`.
- [x] Admin işlemleri: ad değiştir, üye çıkar, davet kodu yenile, sınıfı sil (repo: soyut+
      bellek-içi+Supabase). **Supabase RLS:** `migrations/0004_group_admin.sql` (kullanıcı çalıştırmalı).
      47/47 test.
- [x] (İleride) sınıf sohbeti için yer ayrıldı — ClassDetailScreen'de "Sohbet (yakında)" tile.
- [x] Aktif sınıf kalıcılığı — `activeGroupIdProvider` artık `shared_preferences`'ta saklıyor
  (uygulama yenilenince son aktif sınıf hatırlanır). Saat stili de kalıcı oldu.

## FAZ 3.7 — Profesyonel & Özelleştirilebilir Sayaç (2026-06-21 kararı, §3.12)

> "Başka kronometre gerekmesin" hedefi. Varsayılan sade, isteyene özelleştirilebilir.

- [x] Ders seçici **dropdown** — kapalıyken seçili ders/"Genel" + ▾; dokununca alt sayfada
  ders listesi + "Dersleri düzenle" (Claude Code model seçici mantığı). Çalışırken kilitli.
- [x] **Tam ekran odak modu** (`focus_timer_screen.dart`) — kartta tam ekran ikonu → büyük
  canlı sayaç + ders + büyük Başlat/Durdur + küçült; immersive sistem çubukları.
- [x] **Özelleştirilebilir saat stilleri** (`clock_style.dart`): sade rakam (varsayılan) /
  **hedef halkası** (günlük hedefe göre dolan halka) / **renk geçişi** (hedefe yaklaştıkça
  zıt→yeşil). `StudyClock` hem kartta hem tam ekranda kullanılır; `clockStyleProvider`.
- [x] Stil seçici — kart ve tam ekrandaki **ayar (tune)** ikonundan anchored menü.
  (Seçim şimdilik bellek-içi; kalıcılık sonra.)
- [ ] (Ops.) Pomodoro / aralıklı mod + bitiş bildirimi

## FAZ 3.8 — Ana Sayfa: Esnek Dashboard ✅ (2026-06-21 kararı, §3.9)

> Kullanıcı kararı: **tam özelleştirilebilir** (sürükle-bırak); sayaç **varsayılan Ana
> Sayfa'da**, isteyen Sınıflar'a da ekler.

- [x] 4. sekme olarak **Ana Sayfa** en başa eklendi (Ana Sayfa / Sınıflar / İstatistik / Profil).
- [x] Kart kataloğu (`dashboard_card.dart`): **sayaç**, **bugün özeti** (ders dağılımı),
  **haftalık grafik** (son 7 gün), **sınıf sıralaması** (aktif sınıf, bugün).
- [x] Kullanıcı kart **ekle/çıkar/sürükle-sırala** (`DashboardEditScreen`, ReorderableListView).
  Yerleşim **cihazda kalıcı** (`shared_preferences`, `dashboardLayoutProvider`).
- [x] Sayaç varsayılan Ana Sayfa'da; Sınıflar'a eklemek için düzenle ekranında anahtar
  (`classroomShowTimerProvider`, kalıcı). Sınıflar artık varsayılan sayaçsız.
- [ ] (Sonra) Daha fazla kart türü (hedef/seri standalone, hafta içi/sonu, dönem özetleri).

## FAZ 3.9 — Çalışma Kayıtları İyileştirme (2026-06-21 kararı, §3.10)

- [x] Geçmiş günler **tek katlanabilir özet kayıt** (gün + toplam + oturum sayısı); bugün
  ayrı ayrı kalır (`_TodaySection` / `_PastDayTile` ExpansionTile).
- [x] **Saat aralığı** (ör. 14:05–14:50) sayaç oturumlarında; manuelde "Manuel" + süre + ders.
- [x] Güne dokununca alt kırılım — geçmiş gün açılınca o günün oturumları (düzenle/sil dâhil).

## FAZ 3.10 — İstatistikleri Zenginleştirme (§3.4 + §3.11) 🟡

- [x] Kişisel: ders bazında **donut grafik** + yüzdeli açıklama (kardeş tasarımı gibi);
  eski oransal çubuklar yerine `SubjectDonut` (fl_chart PieChart, ortada toplam saat).
- [x] Sınıf: **günlük trend** (son 7 gün sınıf toplamı çubuk grafiği) leaderboard üstüne.
- [ ] (Sonra) Daha fazla sınıf metriği (haftalık değişim, ders bazında sınıf kıyası, en istikrarlı üye).

---

## FAZ 3.11 — Zengin & Etkileşimli UI (2026-06-22 geri bildirim) 🟢

> Kullanıcı: "dashboard widget gibi sürüklenip boyutlandırılabilsin, dopdolu olsun ama hepsi
> ayarlanabilir; istatistikler etkileşimli olsun." Araştırma: donut/çubuk/çizgi + **takvim ısı
> haritası**, dokunmatik ipuçları, tablo; kart yeniden boyutlandırma + grid yerleşim.

**Yapıldı:**
- [x] Ders pasta/donut (kişisel), grup günlük trend, tıklanabilir+hover sıralama satırları,
  üye bilgi alt sayfası, seçilebilir metin, grup üye serileri (🔥 isim yanında).
- [x] **Ana Sayfa kart boyutu**: her kart küçük/orta/büyük (`DashboardCardSize`), küçük=yarım
  genişlik → 2 sütun grid (Wrap), orta/büyük=tam genişlik; düzenleme ekranında boyut döngü
  butonu. Düzen `"tür:boyut"` olarak kalıcı (eski sade `"tür"` ile geriye uyumlu).
- [x] **Daha çok kart türü**: günlük hedef (halka + büyük seri), dönem özeti (bugün/hafta/ay/yıl
  seçici + toplam/ort./aktif gün), hafta içi/sonu kıyas, **takvim ısı haritası** (GitHub tarzı,
  hücre ipuçlu, boyuta göre 9/15/26 hafta). Haftalık grafik büyükte 14 gün.

- [x] **Etkileşimli donut**: dilime dokununca dilim büyür + merkez o dersin adı/süresi/
  yüzdesini gösterir; ders dağılımı kartında **veri formatı seçici** (yüzde / süre).
- [x] **Grup hedefi** (migration 0006 `groups.daily_goal_minutes`): `StudyGroup.dailyGoalMinutes`
  + `updateGroupGoal` (InMemory+Supabase, 1..1440 clamp); admin ClassDetailScreen'de saat/dakika
  stepper ile ayarlar; Grup istatistiğinde "Bugünkü grup hedefi" ilerleme kartı + **grup serisi**
  (grubun günlük toplamı hedefe ulaşan üst üste günler). ⚠️ Kullanıcı `0006_group_goal.sql` çalıştırmalı.

- [x] **Çizgi grafik** kart türü (`DashboardCardType.line` + `DailyLineChart`, dokunma ipuçlu,
  büyükte 30 gün); ısı haritası ortak `StudyHeatmap` widget'ına çıkarıldı ve **kişisel istatistik**
  sekmesine de eklendi (son 6 ay).

> ✅ FAZ 3.11 tamam. Migration: kullanıcı `0006_group_goal.sql` çalıştırmalı.

## FAZ 3.12 — Tema/Renk paleti + grafik & saat rötuşları (2026-06-22 #2) 🟢

> Kullanıcı: "renkler ne, renk yok — UI'ı kardeşiminkiyle değiştir; grafiklerde imlecle
> üstüne gelmek zor (ipucu açılmıyor); saati büyütünce bozuk; eski oturumları görelim;
> grafiklere filtre."

- [x] **Renk paleti / tema**: kardeşin `globals.css` (oklch) → sRGB; koyu lacivert zemin,
  mavi primary + yeşil accent + amber/mor/mercan grafik tonları. `AppTheme` baştan yazıldı
  (özel koyu `ColorScheme` + kart/appbar/nav/segment/input temaları, 16px köşe, ince kenar);
  varsayılan **koyu tema** (`ThemeMode.dark`). `subject_colors` chart-1..5 yeni palete güncellendi;
  sabit `Colors.green/orange` → palet token'ları.
- [x] **Kolay grafik ipuçları**: çubuk grafiğe geniş `touchExtraThreshold` (üstüne/yakınına
  gelince açılır) + `fitInside`; çizgi grafiğe `touchSpotThreshold: 30`; ısı haritası ipucu
  `waitDuration: 0` (anında).
- [x] **Saat**: sabit genişlikli rakamlar (`FontFeature.tabularFigures` — süre değişirken
  zıplamıyor); odak modunda `FittedBox` ile ölçekleniyor (büyük saat taşmıyor), 72px.
- [x] **Eski oturumlar**: sayaç kartına "Geçmiş oturumlar" (history) butonu → `SessionHistoryScreen`.
- [x] **Grafik filtreleri**: çubuk kartı 7/14/30 gün, çizgi kartı 14/30/90 gün satır içi filtre.
- [x] **Masonry yerleşim**: Ana Sayfa `Wrap` yerine 2 bağımsız sütun (kısa kartın altında boşluk
  kalmıyor); küçük (yarım) kartlar sol/sağ sütuna paylaştırılır, orta/büyük tam satır.
- [x] **Dar sayaç kartı**: `StudyTimerCard` boyut-duyarlı — küçükken saat/yazılar `FittedBox` ile
  ölçeklenir, seri rozeti kompakt (yazılar artık taşmıyor/karışmıyor).
- [x] **Sıralama etkileşimi**: alttan açılan pencere kaldırıldı — üzerine gelince **basit tooltip**
  (sıra · bugün · seri), tıklayınca **tıklanan yerde** detay popup'ı (`showMenuAtPosition`).
- [x] **Seçilebilir renk paleti + tema modu** (Profil → Görünüm): 5 palet (Lacivert/Mor/Zümrüt/
  Gün Batımı/Okyanus) + Koyu/Açık/Sistem; `AppTheme` palet-parametreli, `themeSettingsProvider`
  ile kalıcı (shared_preferences). `MaterialApp` artık `ConsumerWidget`.

> **Persistence notu:** Ana Sayfa düzeni + tema `shared_preferences`'a yazılıyor, `signOut`
> temizlemiyor — kod doğru. Web'de `flutter run -d chrome` her açılışta **yeni Chrome profili**
> kullandığından localStorage uçar → kalıcı test için sabit profil: `flutter run -d chrome
> --web-browser-flag="--user-data-dir=C:\Users\muhlis2\.osr-chrome"`. Gerçek kurulumda kalıcı.

- [x] **Yerinde düzenleme modu (Android ana ekran kalıbı)**: kartı **basılı tutunca** düzenlemeye
  girilir; kartlar tek sütunda **sürükle-bırakla** sıralanır, her kartın üstündeki **S/M/L** ile
  canlı boyutlandırılır, **×** ile kaldırılır, AppBar **+** ile eklenir. Düzenlemede canlı kart
  önizlemesi gösterilir. Ayrı `DashboardEditScreen` kaldırıldı (işlevi içeri taşındı).

- [x] **Çalışma saatleri** kartı + istatistik bölümü: `hourlyTotals` (saat 0–23 → saniye) +
  etkileşimli 24 saatlik sütun grafiği (renk yoğunluğu, en verimli saat vurgulu, anlık ipuçlu).
  Yeni kart türü `hours`; kişisel istatistikte de var. Birim test eklendi.
- [x] **Haftalık ritim** ısı haritası: `weekdayHourTotals` (7 gün × 24 saat) + `WeekHourHeatmap`
  (hücre ipuçlu, eksen etiketli). Kart türü `rhythm` + kişisel istatistik. Birim test.
- [x] **Renk-kodlu karşılaştırma tablosu** (`StatHeatTable`): her sütun kendi içinde yeşil→amber→
  kırmızı (yapayzeka.oguzergin.net tarzı). Grup istatistiğinde üye × [Bugün/Hafta/Ay].
- [x] **Oturum dağılımı (scatter)**: `SessionScatterChart` (fl_chart) — her oturum bir nokta
  (x=gün, y=süre, derse göre renkli, dokununca ipucu). Kart türü `scatter` + kişisel istatistik.
- [x] **Rekorlar**: `longestStudyStreak` + `StudyRecords` (toplam, rekor seri, en verimli gün,
  aktif gün, en çok ders) renkli döşemeler. Kart türü `records` + kişisel istatistik. Birim test.
- [x] **Kartlara hover** (kalkma + parlama); ekleme menüsü **kategorili** (Sayaç/Özet/Grafik/Isı/Grup).
- [x] **Grup hedefi Ana Sayfa'da**: sıralama kartına grup günlük hedefi ilerleme çubuğu + grup serisi.
- Toplam **16 Ana Sayfa kart türü**; istatistik sekmesi donut + çubuk + çizgi + 2 ısı haritası +
  scatter + renk-kodlu tablo + rekorlar ile dopdolu ve etkileşimli.

- [x] **Çubuk grafik**: süre çubuğun üstünde **hep görünür** (`showingTooltipIndicators` + saydam
  kutu); alt eksende tarih **ay adıyla** ("21 Haz" — gün + ay kısaltması iki satır).
- [x] **Kart ekleme yenilendi**: `showCardPicker` — kategorili, ikon+başlık+açıklamalı görsel alt
  sayfa galeri (çoklu ekleme, açık kalır). Eski anchored popup kaldırıldı.
- [x] **Izgara düzenleme**: düzenleme modu artık gerçek masonry — küçükler yan yana, S/M/L **anında**
  uygulanır; **sürükle-bırak** (uzun bas → başka kartın üstüne bırak) ile sıralama.
- [x] **Grup kartları** (özelleştirilebilir): `groupGoal` (grup hedefi halkası + grup serisi),
  `groupTrend` (grup günlük çubuk). Grup bilgisi artık Ana Sayfa'ya istenen boyutta eklenebilir.
- **19 dashboard kart türü** (+ `activeMembers` "Şu an çalışanlar" — canlı aktif grup üyeleri).
- [x] **Çubuk grafik hedef çizgisi**: günlük hedef **kesikli çizgi**; hedefi tutmayan günler gri,
  tutanlar renkli; alt eksen tarih taşması düzeltildi (gün + ay görünür).
- [x] **Sürükleme düzeltildi**: tutamaçtan (⠿) anlık `Draggable` (web'de güvenilir). **Orta/büyük
  farkı belirgin**: sayaç büyükte saat 56/220, sıralama büyükte 10 üye (orta 5, küçük 3).
- [x] **Ayarlar ekranı** (Profil → Ayarlar): görünüm/tema, Gruplar'da sayaç, **Ana Sayfa'yı sıfırla**.
- [x] **Gruplar sekmesi** zenginleştirildi: grup hedefi + grup günlük trendi kartları.
- [x] **Kalıcılık (kritik):** çalıştırmada **sabit `--web-port=5005`** — web localStorage origin'e
  (host:port) bağlı; rastgele port her açılışta ayarları sıfırlıyordu. Bkz. memory `run-command-env-json`.

> **Donma düzeltmeleri:** `WeekHourHeatmap` (AspectRatio→sabit boyut) ve `HourActivityChart`
> (FractionallySizedBox→Align/açık yükseklik) "Cannot hit test a render box with no size" selini
> tetikleyip İstatistik'i donduruyordu — çözüldü.

> **Kalan (büyük, ayrı tur):** gerçek **serbest (free-form) ızgara** — kartı istenen hücreye bırakma
> + köşeden çekerek boyutlandırma. Bkz. memory `ui-design-reference`.

**Kalan (büyük):** serbest (free-form) ızgaraya bırakma + köşeden çekerek boyutlandırma; grafik/
istatistik zenginleştirme (renk-kodlu tablo, scatter — bkz. memory `ui-design-reference`).

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

### 5.1 Otomatik Güncelleme Sistemi (In-App Update — GitHub Releases) 🟢
**Tasarım:** APK'lar GitHub Releases'te tutulur (ücretsiz, public). Uygulama açılışta
GitHub API'den en son release etiketini okur, kendi `buildNumber`'ıyla karşılaştırır.
Supabase'e gerek yok. (Önceki Supabase tablolu plan iptal edildi — `0007` silindi.)
- [x] **Flutter paketleri**: `package_info_plus`, `dio`, `path_provider`, `open_filex` (`pubspec.yaml`).
- [x] **Android izinleri**: `AndroidManifest.xml` → `INTERNET` + `REQUEST_INSTALL_PACKAGES`.
- [x] **Kalıcı release keystore + signing config**: `android/key.jks` + `key.properties` (gitignored), `build.gradle.kts` release imzası. Release APK imzalı derlendi (58.6MB). ⚠️ Anahtar kalıcı, yedeklenmeli.
- [x] **Güncelleme Servisi (`UpdaterService`)**: GitHub `releases/latest` → `v<buildNumber>` etiketini mevcut sürümle karşılaştırır (`features/updater/updater_service.dart`). Sadece Android.
- [x] **Güncelleme Ekranı (`UpdaterDialog`)**: Sürüm notları + indirme % çubuğu, bitince `open_filex` ile kurulum (`features/updater/updater_dialog.dart`).
- [x] **Ana Ekrana Bağlama**: `auth_gate.dart` açılışta bir kez `maybeShowUpdateDialog`.
- [x] **CI (GitHub Actions)**: `v*` etiketi push'unda APK derleyip Releases'e koyar (`.github/workflows/release.yml`). Etiket sayısı = `versionCode`.
- [ ] **Kurulum (kullanıcı)**: GitHub Secrets (`KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`) eklenmeli; ilk `git tag v2` ile test.
- [x] **Güvenlik sertleştirme**: İndirilen APK için **SHA-256 bütünlük doğrulaması** (CI `.sha256` üretir, uygulama kurulumdan önce karşılaştırır; uyuşmazsa siler/iptal) + asset adı `app-release.apk` ile sıkı eşleşme (rastgele `.apk` reddedilir).
- **Direkt indirme linki:** `https://github.com/manil-max/online-study-room/releases/latest/download/app-release.apk`

### 5.2 Manuel Dağıtım (Eski Yöntem)
- [ ] Release APK üretimi
- [ ] Cihazlara ilk kurulum (sideload)
- [ ] Windows kurulum paketi
- [ ] Kullanım / kurulum notları (/docs)

---

## FAZ 6 — Kritik Düzeltmeler + Arayüz/Ana Ekran (new_features.md §1 & §2)

> Bu bölüm **uygulayıcı AI** içindir. Her mini-faz; amacı, dokunulacak TAM dosyaları (satırla), birebir adımları, mevcut→yeni kod/SQL örneklerini, dikkat edilecek tuzakları ve kabul kriterini içerir. Bir mini-fazı yapan AI **sadece o fazın dosyalarına dokunmalı**, faz bitince `flutter analyze` çalıştırmalı (temiz olmalı) ve mevcut testleri (47 test) bozmamalı.

### Model tier göstergesi (maliyet optimizasyonu)
- 🔴 **Opus 4.8** — en zor/novel iş: grid fiziği, akışkan animasyon, mimari karar.
- 🟣 **Gemini 3.1 Pro** — çapraz-dosya refactor + DB/mantık (güçlü reasoning, geniş bağlam, Opus'tan ucuz).
- 🔵 **Sonnet 4.6** — standart widget/provider/repo implementasyonu.
- 🟢 **Gemini 3.5 Flash** — migration çalıştırma, string/etiket değişimi, boilerplate.
- Kural: bir mini-faz tek modelle biter; model takılırsa bir üst tier'e yükselt. 🔴 tasarım fazları (1B, 2A) kendi implementasyonlarından ÖNCE bitmeli.

### Proje gerçekleri (uygulayıcının bilmesi şart)
- Flutter ^3.12, Riverpod 3.3 (Notifier/Provider), Supabase 2.15, fl_chart. Uygulama kökü: `app/`. Migrationlar: `supabase/migrations/`.
- Repo katmanı **çift implementasyonludur**: her arayüz hem `supabase/` hem `in_memory/` altında. İkisi de güncellenmeli yoksa demo/offline mod kırılır.
- Gün sınırı her yerde **Europe/Istanbul**.
- RLS aktif. İki SECURITY DEFINER helper var: `is_group_member(gid)` (0001), 0004'te admin helper'ları. `study_sessions` ve `presence` SELECT politikaları `is_group_member(group_id)`'a dayanır.
- `group_members` PK = `(group_id, user_id)`, `joined_at timestamptz not null default now()` ZATEN VAR, `role` ('admin'|'member') var.
- Realtime publication: `presence, study_sessions, group_members, groups` (0001 satır 208-211).

---

### Durum özeti (hızlı bakış)
`[X]` bitti · `[~]` kısmen · `[ ]` bekliyor

- `[X]` 1A · Grup hedefi migration apply 🟢
- `[X]` 1B · Çoklu grup mimarisi TASARIM 🔴
- `[X]` 1C · DB migration'ları (0008–0011) 🟣
- `[X]` 1D · Dart veri katmanı refactor 🟣
- `[X]` 1E · "Eski Grup Üyesi" etiketi 🟢
- `[X]` 2A · Serbest ızgara TASARIM 🔴
- `[X]` 2B · Grid veri modeli + persistence 🔵
- `[X]` 2C · Doğrudan sürükle + reflow 🔴
- `[X]` 2D · Boyutlandırma 🔴 (genişlik + yükseklik + 4 köşeden resize ✅)
- `[X]` 2E · İçerik responsive (16 kart) 🟣
- `[X]` 2F · Düzenleme odak koruma 🔵
- `[~]` 2D · Boyutlandırma 🔴 — **§2.2 REFACTOR ile yeniden yazılıyor** (akış ızgarası → gerçek 6×N 2D matris). Aşağı bak.
- `[ ]` 2G · Kamp ateşi canlı ekran 🔴+🔵 (Canlı Grup Hedefi saniye saniye akması buraya dahil)
- `[ ]` 2H · Eksiksiz saat/zamanlayıcı 🔵+🟣
- `[ ]` 2I · Ayarlar ve Grup Yönetimi overhaul 🔵+🟢 (Grup ayarlarının derli toplu hale gelmesi)

#### §2.2 — Gerçek 6×N 2D Matris Izgara REFACTOR (2026-06-26 geri bildirim)
- `[X]` R1 · 2D matris TASARIM (koordinat/hücre/reflow/migration) 🔴 Opus 4.8
- `[X]` R2 · Veri modeli x,y,w,h + persistence + eski format göçü 🟣 Gemini 3.1 Pro
- `[X]` R3 · Stack + AnimatedPositioned statik render (akış kaldırılır) 🔵 Sonnet 4.6
- `[ ]` R4 · Occupancy matrisi + çarpışma & akıcı reflow fiziği 🔴 Opus 4.8
- `[ ]` R5 · Sürükle: tam-boy yarı saydam feedback + hücre hedefleme 🟠 Opus 4.6
- `[ ]` R6 · Boyutlandırma: hücre-snap yükseklik + doğru köşe/kenar geometri 🟠 Opus 4.6
- `[ ]` R7 · Tutamaç & düzenleme UI estetiği (ince çizgi + zarif noktalar) 🔵 Sonnet 4.6
- `[ ]` R8 · Göç doğrulama + string + cilalama + analyze/test 🟢 Gemini 3.5 Flash

---

## §1 — Kritik Düzeltmeler & Mimari

> **Kilitli mimari karar:** `study_sessions.group_id` KALDIRILIR. Oturum yalnızca kullanıcıya aittir. Grup istatistiği `study_sessions ⨝ group_members` join'iyle, **üyelik penceresine** (`joined_at .. coalesce(left_at, now())`) göre hesaplanır. `group_members.left_at timestamptz null` ile yumuşak silme: üye çıkınca satır SİLİNMEZ, `left_at=now()` yazılır → geçmiş veri ve isim korunur, ad "Eski Grup Üyesi" gösterilir.

- [x] **1A · Grup hedefi migration'ı 🟢 Flash**
  - **Amaç:** Madde 1 — grup hedefi kaydedilemiyor; migration zaten yazılı ama uygulanmamış.
  - **Adım:** Supabase paneli → SQL Editor → `supabase/migrations/0006_group_goal.sql` içeriğini yapıştır → Run. (Sadece `groups.daily_goal_minutes int not null default 360` ekler.)
  - **Kabul:** Admin grup hedefini değiştirip uygulamayı kapatıp açınca değer kalıcı.
  - **Tuzak:** Kod tarafı (`updateGroupGoal`) zaten var; bu faz **sadece DB apply**.

- [x] **1B · Çoklu grup mimarisi — TASARIM 🔴 Opus — ✅ TASARIM TAMAM**
  - **Amaç:** 1C–1E'nin uygulanabilmesi için kesin teknik tasarım üretmek. Kod yazmaz; karar + sözde-kod üretir, aşağıdaki kararları doğrular/keskinleştirir.
  - **Üretilecek kararlar:**
    1. **RLS yeniden yazımı (kritik):** group_id gidince `sessions_select` politikası `is_group_member(group_id)` kullanamaz. Yeni görünürlük: "bir kullanıcının oturumunu görebilirim ⇔ kendisiyle ortak bir grubun **aktif** üyesiyim (o kişi o grubu terk etmiş olsa bile)". Bunun için yeni SECURITY DEFINER helper `can_see_user_sessions(target uuid)` tasarla (recursion'ı önlemek için DEFINER). Sözde-SQL:
       ```sql
       exists (
         select 1 from group_members me
         join group_members other on other.group_id = me.group_id
         where me.user_id = auth.uid() and me.left_at is null
           and other.user_id = target            -- other.left_at filtrelenmez → ayrılan üye geçmişi görünür
       )
       ```
    2. **`is_group_member` güncellemesi:** `and left_at is null` eklenir (ayrılan kişi gruba erişimi yitirir; ama kalan üyeler hâlâ onun satırını görür çünkü kontrol VİEWER'ın aktif üyeliğine bakar).
    3. **Soft-delete = UPDATE:** `members_delete` (sadece-self) yerine `members_update` politikaları gerekir (self + admin). 0004'teki admin "remove member" koşulu UPDATE'e taşınmalı. Hard delete sadece grup silme cascade'inde kalır.
    4. **Re-join:** PK `(group_id,user_id)` olduğundan ayrılıp dönen üye için INSERT çakışır → **upsert** (`left_at=null, joined_at=now()`).
    5. **Realtime:** `.stream().eq('group_id',…)` ve postgres-changes `group_id` filtresi artık imkânsız; tüm `study_sessions` değişikliklerine abone olup RPC'yi yeniden çağır (filtre yok).
    6. **Tarihsel doğruluk:** RPC join'i `s.start_time >= gm.joined_at and (gm.left_at is null or s.start_time < gm.left_at)` ile sınırlanır → üye katılmadan önceki/ayrıldıktan sonraki oturumlar gruba sayılmaz.
    7. **`watchGroupSessions(groupId)` ham oturum akışı:** çağıranları tespit et (`grep watchGroupSessions`). Grup geneli istatistik zaten RPC'den (`watchGroupDailyStats`) geliyorsa, ham akış için ya members listesi üzerinden `user_id in (...)` sorgusu kur ya da kullanımı kaldır. Karar bu fazda netleşir.
  - **Kabul:** 1C–1E için net SQL/Dart sözde-kodu + RLS politika metinleri hazır.

  #### 1B çıktısı — KESİNLEŞEN TASARIM (kaynak okuması ile doğrulandı)

  > Aşağısı 1C–1E'nin **birebir uygulayacağı** kilitli karardır. Mevcut kaynak kodu okunarak (0001/0004 RLS, repo'lar, çağıranlar) netleştirildi. Açık soru kalmadı.

  **K1 — Admin koşulu somut.** 0004'te `is_group_admin(gid uuid)` helper'ı var (`groups.created_by = auth.uid()`). Mevcut `members_delete` (0004) = `using (user_id = auth.uid() or public.is_group_admin(group_id))`. Soft-delete'e geçişte aynı koşul **UPDATE** politikasına taşınır:
  ```sql
  drop policy if exists members_update_self on public.group_members;
  create policy members_update_self on public.group_members
    for update to authenticated
    using (user_id = auth.uid() or public.is_group_admin(group_id))
    with check (user_id = auth.uid() or public.is_group_admin(group_id));
  ```
  > `members_delete` SİLİNMEZ (grup silme cascade + temizlik için kalır). Ayrı `members_update_admin` politikasına gerek yok — tek `members_update_self` koşulu hem self hem admin'i kapsıyor.

  **K2 — Görünürlük helper'ı (1C/0009'da yazılacak):** `can_see_user_sessions(target uuid)`, SECURITY DEFINER (recursion engeli). Kendi oturumların + seninle ortak grupta (sen aktif üye, hedef aktif/ayrılmış) olanların oturumları görünür. (SQL 1C §0009'da.)

  **K3 — `is_group_member` güncellemesi (0008):** gövdeye `and left_at is null` eklenir. Etki: ayrılan kişi gruba erişimi yitirir; **kalan üyeler** onun group_members satırını + geçmiş oturumlarını görmeye devam eder (kontrol VİEWER'ın aktif üyeliğine bakar). `presence_select`/`members_select`/`groups`/`sessions_select` bu helper'ı kullandığı için ek değişiklik gerekmez (sessions_select 0010'da can_see_user_sessions'a geçer).

  **K4 — `watchGroupSessions(groupId)` kararı NET:** UI/provider'da **çağıran YOK** (grep: yalnız arayüz + 2 impl + 1 test `study_repository_test.dart`). Karar: metot KORUNUR ama 1D'de **üyelik tabanlı** yeniden yazılır — grubun aktif+ayrılmış üyelerinin `user_id` listesiyle `study_sessions`'ı süz (`.inFilter('user_id', ids)`); in-memory eşdeğeri üyelik state'inden. İlgili test de group_id'siz senaryoya güncellenir.

  **K5 — Re-join (1E/repo):** PK `(group_id,user_id)` → ayrılıp dönende INSERT çakışır. `joinGroup` **upsert** olur: `onConflict: 'group_id,user_id'`, `left_at=null, joined_at=now()`. `createGroup`/`joinGroup` mevcut INSERT'leri (sat. ~44, ~75) buna göre.

  **K6 — Realtime:** `supabase_study_repository`:
  - `watchGroupSessions`: `.eq('group_id',…)` → K4 üye-listesi sorgusu.
  - `watchGroupDailyStats`: postgres-changes `filter: PostgresChangeFilter(column:'group_id'…)` bloğu KALDIRILIR; tüm `study_sessions` değişikliğinde `refresh()` (RPC zaten grupça süzer). Publication zaten tabloyu içeriyor.

  **K7 — RPC v2 imza-uyumlu (0011):** `group_daily_totals(p_group_id uuid) → (user_id,day,seconds)` aynı kalır → Dart `_fetchDailyStats` + `DailyStat.fromMap` **değişmez**. İçi `study_sessions ⨝ group_members` (üyelik penceresi). SECURITY INVOKER kalır (çağıranın RLS'i geçerli; K2 sonrası görünürlük doğru).

  **K8 — Migration deploy sırası (zorunlu):** `0008` (left_at + is_group_member + members_update) → `0009` (can_see_user_sessions) → `0010` (sessions_select rewrite → idx drop → column drop) → `0011` (RPC v2). **0010 içinde sıra:** politika → index → kolon. Dart (1D) bu migration'larla **aynı sürümde** çıkmalı; biri olmadan diğeri prod'u kırar (`fromMap` group_id arar / RLS kolon arar).

  **K9 — Dokunulmayacak:** `presence` tablosu `group_id`'yi KORUR (0001) → ona dokunma. `idx_sessions_user` kalır. `subjects`, `profiles` etkilenmez.

  **K10 — Tarihsel kayıp (kabul edilen):** 0010 kolonu DROP edince eski satırların orijinal group_id'si kaybolur; grup ataması üyelik penceresinden (joined_at..left_at) yeniden kurulur. Üye katılmadan önceki oturumlar artık o gruba sayılmaz (K7 join koşulu) — kilitli kararla tutarlı.

- [x] **1C · DB migration'ları 🟣 Gemini 3.1 Pro**
  - **Amaç:** 1B tasarımını migration dosyalarına dök. Önce yerel/staging Supabase'de dene, sonra prod.
  - **Dosyalar (yeni):**
    - `supabase/migrations/0008_membership_lifecycle.sql`
    - `supabase/migrations/0009_session_visibility.sql`
    - `supabase/migrations/0010_drop_session_group_id.sql`
    - `supabase/migrations/0011_group_daily_totals_v2.sql`
  - **`0008` (üyelik yaşam döngüsü):**
    ```sql
    alter table public.group_members
      add column if not exists left_at timestamptz;

    -- is_group_member artık yalnız AKTİF üyeliği sayar
    create or replace function public.is_group_member(gid uuid)
    returns boolean language sql security definer set search_path = public stable as $$
      select exists (
        select 1 from public.group_members
        where group_id = gid and user_id = auth.uid() and left_at is null
      );
    $$;

    -- soft-delete için UPDATE politikaları (eski members_delete'i tamamlar)
    drop policy if exists members_update_self on public.group_members;
    create policy members_update_self on public.group_members
      for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
    -- admin başkasını çıkarabilsin: 0004'teki admin koşulunu BURAYA kopyala
    -- (ör. is_group_admin(group_id) veya groups.created_by = auth.uid()).
    -- 0004'ü aç, members delete admin politikasının USING koşulunu birebir al.
    ```
    > Dikkat: 0004 dosyasını aç, admin koşulunu (helper adı ne ise) `members_update_admin` politikasında birebir kullan. Yanlış koşul → admin üye çıkaramaz.
  - **`0009` (oturum görünürlüğü helper'ı):**
    ```sql
    create or replace function public.can_see_user_sessions(target uuid)
    returns boolean language sql security definer set search_path = public stable as $$
      select target = auth.uid() or exists (
        select 1 from public.group_members me
        join public.group_members other on other.group_id = me.group_id
        where me.user_id = auth.uid() and me.left_at is null
          and other.user_id = target
      );
    $$;
    ```
  - **`0010` (group_id DROP — SIRALAMA ÖNEMLİ):**
    ```sql
    -- 1) Önce kolona bağlı politikayı group_id'siz yeniden yaz
    drop policy if exists sessions_select on public.study_sessions;
    create policy sessions_select on public.study_sessions
      for select to authenticated using (public.can_see_user_sessions(user_id));
    -- 2) group_id'ye bağlı index'i düşür
    drop index if exists public.idx_sessions_group;
    -- 3) kolonu düşür (NOT NULL FK idi; veri diğer kolonlarda durur)
    alter table public.study_sessions drop column if exists group_id;
    ```
    > Tuzak: kolonu önce düşürmeye çalışırsan politika bağımlılığı hata verir. Sıra: politika → index → kolon.
  - **`0011` (RPC v2):**
    ```sql
    create or replace function public.group_daily_totals(p_group_id uuid)
    returns table (user_id uuid, day date, seconds bigint)
    language sql stable security invoker set search_path = public as $$
      select s.user_id,
             (s.start_time at time zone 'Europe/Istanbul')::date as day,
             sum(s.duration_seconds)::bigint as seconds
      from public.study_sessions s
      join public.group_members gm
        on gm.user_id = s.user_id and gm.group_id = p_group_id
      where s.start_time >= gm.joined_at
        and (gm.left_at is null or s.start_time < gm.left_at)
      group by s.user_id, (s.start_time at time zone 'Europe/Istanbul')::date;
    $$;
    grant execute on function public.group_daily_totals(uuid) to authenticated;
    ```
    > İmza (`p_group_id uuid` → `(user_id,day,seconds)`) aynı kaldı → Dart `_fetchDailyStats` ve `DailyStat.fromMap` değişmez.
  - **Kabul:** 4 migration staging'de hatasız çalışır; iki gruplu test kullanıcısının tek oturumu her iki grubun `group_daily_totals` sonucunda görünür; üye `left_at` set edilince geçmiş satırları RPC'de KALIR ama yeni oturumları sayılmaz.
  - **Tuzak:** `presence` tablosu group_id'yi KORUR — ona dokunma. `idx_sessions_user` kalır.

- [x] **1D · Dart veri katmanı refactor 🟣 Gemini 3.1 Pro**
  - **Amaç:** 0010 sonrası `study_sessions` satırlarında `group_id` yok; Dart bunu yansıtmalı. group_id'siz dünyada oturum kaydı + grup okuması.
  - **Dosyalar:**
    - `app/lib/data/models/study_session.dart` — `groupId` alanını TAMAMEN kaldır: constructor `required this.groupId` (sat.13), field (sat.23), `fromMap` `groupId: map['group_id']` (sat.37), `toMap` `'group_id': groupId` (sat.50), `==` (sat.64), `hashCode` (sat.75). **Tuzak:** `fromMap`'te `map['group_id'] as String` kalırsa kolon gittiği için runtime'da patlar.
    - `app/lib/data/providers/study_providers.dart` — `_recordSession` (≈122-144): `final group = ref.read(userGroupProvider)...` ve `groupId: group.id` satırlarını SİL; `group == null` guard'ını kaldır (artık gruba bağlı değil; sadece `user == null` guard kalır). Oturum yalnız `user.id` ile yazılır.
    - `app/lib/data/repositories/supabase/supabase_study_repository.dart`:
      - `addSession` — `session.toMap()` artık group_id içermez (model'den gitti), değişiklik gerekmeyebilir; doğrula.
      - `watchGroupSessions(groupId)` — `.eq('group_id', groupId)` ARTIK YOK. 1B kararına göre: ya kaldır ya members'tan `user_id` listesiyle `.inFilter('user_id', ids)` kur.
      - `watchGroupDailyStats(groupId)` — postgres-changes filtresindeki `column:'group_id'` bloğunu KALDIR; tüm `study_sessions` değişikliğinde `refresh()` çağır (RPC zaten group'a göre süzüyor).
    - `app/lib/data/repositories/in_memory/in_memory_study_repository.dart` — `_groupSessions`/`_groupDailyStats` yardımcıları group_id'ye göre süzüyordu; bunları **üyelik tabanlı** süzmeye çevir (in-memory grup üyeliği state'inden). Demo modun davranışı Supabase ile tutarlı olmalı.
    - `app/lib/data/repositories/study_repository.dart` — arayüz imzaları büyük ihtimalle aynı kalır (groupId parametreleri grup okuması için duruyor); sadece `watchGroupSessions`'ın kaderi 1B'ye göre.
  - **Kabul:** `flutter analyze` temiz; iki gruplu kullanıcı tek "Çalış" → her iki grup leaderboard'ında görünür; kişisel toplam (profil) ÇİFT saymaz; 47 test geçer (test fixture'larında group_id varsa onları da temizle).
  - **Tuzak:** `grep -rn "groupId\|group_id" app/lib` ile tüm kalıntıları bul; test dosyaları dahil.

- [x] **1E · "Eski Grup Üyesi" etiketi 🟢 Flash**
  - **Amaç:** Madde 5 — ayrılan üyenin adı listede korunsun.
  - **Önkoşul:** 1D'de `watchMembers` artık `left_at` taşıyan üyeleri de döndürmeli (aktif + ayrılmış). Bu, member modeline `leftAt`/`isActive` bilgisi taşımayı gerektirir; 1D çıktısındaki member akışına dayan.
  - **Dosyalar/satırlar:** "İsimsiz" fallback'i, üyelik ayrılmışsa "Eski Grup Üyesi" olacak:
    - `app/lib/features/home/widgets/leaderboard_card.dart:186`
    - `app/lib/features/home/widgets/active_members_card.dart:75`
    - `app/lib/features/classroom/widgets/class_detail_screen.dart:375`
    - `app/lib/features/stats/widgets/class_stats_view.dart:79`
  - **Kural:** profil adı boş **ve** üyelik aktif → "İsimsiz" (eski davranış); üyelik ayrılmış (`left_at != null`) → "Eski Grup Üyesi" (ad olsa bile bu mu yoksa "ad (Eski Üye)" mi? — karar: sadece "Eski Grup Üyesi").
  - **Dosya:** `supabase_group_repository.dart` `removeMember` (≈163-173) ve `leaveGroup` (≈176): `.delete()` yerine `.update({'left_at': DateTime.now().toUtc().toIso8601String()})`. `joinGroup` (≈75) INSERT → **upsert** (`onConflict: 'group_id,user_id'`, `left_at=null, joined_at=now()`) ki ayrılıp dönen üye geri katılabilsin.
  - **Kabul:** Üye çıkar → listede "Eski Grup Üyesi" + geçmiş süresi grup istatistiğinde duruyor; aynı üye tekrar katılınca normal görünüyor, geçmişi bozulmuyor.

---

## §2 — Arayüz & Ana Ekran

> Mevcut Ana Sayfa `home_screen.dart`'ta **masonry** düzen (`_MasonryDashboard`) + düzenleme modu (`_EditableDashboard`, tutamaçtan DragTarget reorder). Kart tipleri+boyut `dashboard_card.dart` (16 tip, S/M/L). Layout state `dashboard_providers.dart` (`DashboardLayoutNotifier`, SharedPreferences `"tür:boyut"`). Hedef: bunları gerçek serbest ızgaraya çevirmek.

- [x] **2A · Serbest ızgara mimari TASARIM 🔴 Opus — ✅ YAPILDI (commit 843ad8e)**
  > **Uygulanan karar (tasarımdan sapma, gerekçeli):** Sabit-hücreli tam 2D (x,y,w,h + Stack/AnimatedPositioned) yerine **12 sütunlu width-cell akış ızgarası** uygulandı. Sebep: 16 kart henüz responsive değil (§2E yapılmadı); sabit hücre yüksekliği içeriği kırardı. Şipariş edilen: kart başına serbest **genişlik** (1..12 hücre), otomatik yükseklik, gövdeden sürükle + animasyonlu gap, köşeden genişlik resize. Konum = liste sırası. Tam 2D yerleşim + yükseklik resize **§2E sonrasına ertelendi**.
  - **Amaç:** masonry → hücre-tabanlı serbest grid geçiş tasarımı (kod yazmaz; karar + sözde-kod).
  - **Üretilecek kararlar:**
    1. **Koordinat sistemi:** Sütun sayısı sabit (öneri: **12 sütun**, "neredeyse serbest" his için), satır birimi yüksekliği ≈ sütun genişliği (kare hücre). Her kart `gridX, gridY (sol-üst hücre), gridW, gridH (hücre span)`, hepsi int. min 1×1, max W = sütun sayısı. (new_features: hücre oranı deneme-yanılma → 12 başla, gerekirse ayarla.)
    2. **Yerleşim widget'ı:** `_MasonryDashboard` (Row+Expanded) → `Stack` + `AnimatedPositioned` (kartlar mutlak konumlu) veya özel `MultiChildLayoutDelegate`. Reflow animasyonu için `AnimatedPositioned` önerilir.
    3. **Doluluk/çakışma:** occupancy matrisi (bool[rows][cols]); yerleştirme/taşıma çakışmayı çözer (aşağı it + yukarı sıkıştır).
    4. **Persistence:** `"tür:x:y:w:h"`; eski `"tür:boyut"` formatından göç: S→2×2, M→tam genişlik×3, L→tam genişlik×4 gibi eşle ve sırayla auto-flow ile yerleştir.
    5. **Performans:** sürükleme/resize sırasında setState yerine sadece sürüklenen kartın konumu + komşu animasyonları; 60fps hedef; `RepaintBoundary` her kartta.
  - **Kabul:** 2B–2F için net veri modeli, reflow algoritması sözde-kodu, widget ağacı kararı.

- [x] **2B · Grid veri modeli + persistence 🔵 Sonnet — ✅ YAPILDI (commit 843ad8e; Opus yaptı)**
  > Uygulanan: `DashboardCardConfig`'e `int width` (1..12 hücre) eklendi (x/y/w/h yerine width — 2A sapması). `encode()` = `"tür:genişlik"`; `decode()` yeni + eski `"tür:boyut"` + sade `"tür"` çözer. `setWidth` eklendi; `setSize/cycleSize` kaldırıldı. `DashboardCardSize` + `dashboardCardFor(type,size)` KORUNDU (size, width'ten türetilir — şim) → 16 kart bozulmadı, §2E bağımsız.
  - **Dosyalar:** `app/lib/features/home/dashboard_card.dart`, `dashboard_providers.dart`.
  - **Adımlar:**
    - `DashboardCardConfig`'e `int x, y, w, h` ekle (2A kararına göre default). `encode()` → `'${type.name}:$x:$y:$w:$h'`. `decode()` hem yeni 5-parça hem eski `"tür"`/`"tür:boyut"` formatını çözsün (geriye-uyum; eski → 2A göç kuralı). `==`/`hashCode` güncelle.
    - `DashboardLayoutNotifier`: `setSize/cycleSize/reorderItem` yerine `setBounds(type, x, y, w, h)`, `addCard(type)` (boş ilk uygun yere yerleştir), `removeCard(type)`. `_kDefaultLayout`'a x,y,w,h ver. `toggle` → grid'e ekleme/çıkarma.
    - `DashboardCardSize` enum'u kaldırılır veya deprecated; `dashboardCardFor` artık `size` yerine genişlik/oran bilgisi alabilir (2E ile koordine).
  - **Tuzak:** `dashboardCardFor(type, size)` çağrısı 16 kart widget'ına `size` geçiyor; imza değişirse 16 widget + `home_screen.dart` derlemesi kırılır — 2E ile birlikte planla veya geçici `size` shim bırak.
  - **Kabul:** Eski kayıtlı düzenler çökme olmadan yeni formata göç eder; `flutter analyze` temiz.

- [x] **2C · Doğal sürükle-bırak + akışkan reflow 🔴 Opus — ✅ YAPILDI (commit 843ad8e)**
  > Uygulanan: `LongPressDraggable` kart **gövdesinden** (tutamaç zorunluluğu kalktı). Sürüklerken `_to` konumunda kesik-çizgili gap belirir, komşular yer açar. `_packRows` width-toplamı ≤12 ile satırlara böler; bırakınca `reorderItem`. (Akış reorder; mutlak x/y Stack §2E sonrası.)
  - **Dosya:** `app/lib/features/home/home_screen.dart` (yeni grid widget'ı; `_MasonryDashboard`/`_EditableDashboard` yerini alır).
  - **Adımlar:**
    - Düzenleme modunda karta **doğrudan basılı tut → sürükle** (tutamaç ⠿ zorunluluğu kalkar; Madde 7/19). `LongPressDraggable` veya pointer event'leriyle.
    - Sürüklerken parmağın altındaki hücreyi hesapla; hedef hücreye göre komşu kartları occupancy'e göre kaydır; her kart `AnimatedPositioned` ile **pürüzsüz** yeni yerine akar (Android ana ekran hissi).
    - Bırakınca `setBounds` ile kalıcılaştır.
  - **Kabul:** Kart sürüklenince komşular tatlı animasyonla yer açar; bırakınca düzen kaydolur; FPS düşmez.

- [x] **2D · Serbest/akıcı boyutlandırma 🔴 Opus — ✅ TAMAM**
  > Uygulanan (2E sonrası): `DashboardCardConfig`'e serbest **yükseklik (px, opsiyonel)**
  > eklendi (`height`/`effectiveHeight`; null=boyuta göre `defaultCardHeight` 180/240/320,
  > sınırlar `kMinCardHeight 120`..`kMaxCardHeight 560`). Kalıcılık `"tür:genişlik:yükseklik"`
  > (ör. `line:12:300`); eski `"tür:genişlik"`/`"tür:boyut"`/`"tür"` geriye-uyumlu okunuyor.
  > Düzenleme kartı **4 köşeden** tutamaçla boyutlanır: genişlik hücreye snap (1..12),
  > yükseklik serbest px; her köşe dx/dy'yi yönüne göre uygular (sol/sağ, üst/alt). Yükseklik
  > canlı (persist:false), sürükleme bitince `persist()` ile kalıcı (prefs spam'i önler).
  > Üst kontrol çubuğu **ortalanmış hap**a taşındı (köşeler tutamaca açıldı; sürükle ipucu +
  > `g/12 · Hpx` etiketi + kaldır ×, dar kartta `FittedBox` ile küçülür). 6 yeni serileştirme
  > testi (toplam 68 test geçiyor). `dashboardCardFor`'a opsiyonel `height` parametresi.
  - **Dosyalar:** `dashboard_card.dart`, `dashboard_providers.dart`, `home_screen.dart`,
    `test/features/dashboard_card_test.dart` (yeni).
  - **Kabul:** Kullanıcı kartı 4 köşeden serbestçe büyütüp küçültür; içerik 2E sayesinde
    bozulmaz; eski kayıtlı düzen yeni formata göç eder. ✅

- [ ] **2E · İçerik responsive adaptasyonu 🟣 Gemini 3.1 Pro**
  - **Dosyalar:** `app/lib/features/home/widgets/` altındaki 16 kart (+ `study_timer_card.dart`).
  - **Adımlar:** Her kart `LayoutBuilder` ile gelen genişlik/yükseklik/orana göre içeriği yeniden düzenlesin: küçükken özet/ikon, büyükken grafik+detay. Yazı/saat/grafik **taşmasın, üst üste binmesin** (`FittedBox`, esnek font, eşik-tabanlı görünüm). Sabit boyut varsayımlarını kaldır.
  - **Bölme:** Karmaşık kartlar (line/heatmap/leaderboard/scatter/rhythm) 🟣 Pro; basit özet kartları (today/goal/records) 🔵 Sonnet'e devredilebilir.
  - **Kabul:** Her kart 1×1'den tam-genişlik×büyük'e kadar tüm oranlarda düzgün; overflow/clipping yok.

- [x] **2F · Düzenleme modu odak koruma 🔵 Sonnet — ✅ YAPILDI (commit 843ad8e; Opus yaptı)**
  > Uygulanan: tek `ScrollController` `_HomeScreenState`'te tutulup view+edit'e paylaştırıldı → mod geçişinde offset korunur, ekran başa zıplamaz.
  - **Dosya:** `home_screen.dart`.
  - **Sorun:** Bir karta basılı tutup düzenlemeye geçince ekran başa/ilk karta zıplıyor (Madde, "Kritik").
  - **Adım:** Düzenleme moduna geçişte mevcut `ScrollController.offset`'i koru; aynı scroll pozisyonunda kal. Gerekirse basılan kartın konumunu görünür tut (`Scrollable.ensureVisible` yerine offset sabitleme).
  - **Kabul:** Hangi karta basılırsa o konumda düzenleme açılır; ekran zıplamaz.

- [ ] **2G · Kamp ateşi canlı çalışma ekranı 🔴 Opus (animasyon) + 🔵 Sonnet (layout/veri)**
  - **Dosyalar:** `app/lib/features/classroom/classroom_screen.dart`, presence provider'ları (`presenceRepositoryProvider`, `groupMembersProvider`).
  - **Adımlar:** Canlı çalışanlar düz liste yerine dinamik sahne (Madde 6): ortada yanan ateş animasyonu; `status=studying` avatarları ateş etrafında, `onBreak`/`offline` karanlığa çekilir. 🔵: presence verisini avatar konumlarına bağla, layout iskeleti. 🔴: ateş/parçacık animasyonu, geçiş efektleri (AI hava durumu/etkileşim ekleyebilir — serbest).
  - **Kabul:** Çalışan üyeler ateş etrafında canlı görünür; durum değişince avatar yumuşak geçişle yer değiştirir.

- [ ] **2H · Eksiksiz saat/zamanlayıcı 🔵 Sonnet (UI) + 🟣 Gemini 3.1 Pro (state machine)**
  - **Dosyalar:** `app/lib/features/classroom/widgets/study_timer_card.dart`, `focus_timer_screen.dart`, `app/lib/data/providers/study_providers.dart` (`StudyTimerNotifier`).
  - **Adımlar:**
    - 🟣 State machine: mevcut kronometreye ek **Geri Sayım**, **Pomodoro (25/5, döngü sayısı)**, ayarlanabilir hazır planlar. Mod geçişleri, döngü sayacı, otomatik mola, bildirim/ses tetik noktaları. Her mod bittiğinde mevcut `_recordSession` akışıyla oturum kaydı tutarlı kalsın (1D sonrası group_id'siz).
    - 🔵 UI: mod seçici, estetik saat stilleri (halka/ilerleme), geri sayım/pomodoro ekranları, tam-ekran odak moduyla uyum.
  - **Tuzak:** Sayaç bildirimi (persistent notification, §5 Madde 10) bu fazda DEĞİL; sadece in-app timer. State machine'i bildirim tetik noktalarını dışarı verecek şekilde tasarla (§5'e hazır).
  - **Kabul:** Kronometre + geri sayım + pomodoro çalışır; pomodoro döngüsü mola/çalışma geçişlerini doğru yapar; her tamamlanan çalışma süresi istatistiğe yazılır.

- [ ] **2I · Ayarlar overhaul 🔵 Sonnet + 🟢 Flash**
  - **Dosyalar:** `app/lib/features/profile/` (ayarlar ekranı), `home_screen.dart` (ana ekran sıfırlama butonu konumu), `core/prefs/`.
  - **Adımlar:**
    - 🔵 Ayarlar menüsünü gruplu, genişletilebilir bir yapıya çevir ("her şey özelleştirilebilir" iskeleti; tema, sayaç, görünürlük, bildirim grupları placeholder).
    - 🟢 **Ana ekran sıfırlama** butonunu ana ayarlardan çıkar, **"ana ekran düzenleme" menüsüne** taşı (`DashboardLayoutNotifier.reset()` zaten var; sadece UI konumu + tetik).
  - **Tuzak:** Gelişmiş bildirim sistemi (her tür/öncelik) §5'e ait; burada sadece iskele + sıfırlama taşıması.
  - **Kabul:** Ayarlar menüsü gruplu; ana ekran sıfırlama düzenleme menüsünden erişilir; mevcut prefs bozulmaz.

---

## §2.2 — Gerçek 6×N 2D Matris Izgara REFACTOR (2026-06-26 geri bildirim) 🔴

> **Neden:** §2.1'de (2A–2D) uygulanan **akış (flow/Wrap) ızgarası** Android ana ekranı
> (launcher) hissini vermiyor. Kart sıra ile diziliyor; serbest (X,Y) konum yok, boşluk
> bırakılamıyor; yükseklik küsuratlı piksel; üst tutamaç ters yönde uzuyor; sürükleyince
> kart küçük çipe dönüşüyor; çarpışmada kartlar ışınlanıyor; tutamaçlar kaba. Bu refactor
> akış mantığını **tamamen** kaldırıp **gerçek 6 sütunlu 2D matris** (Stack +
> `AnimatedPositioned`) kurar.
>
> **Kullanıcının 7 şikâyeti → faz eşlemesi:** #1 (6 sütun) → R1/R2 · #2 (hücre-snap
> yükseklik) → R1/R6 · #3 (tutamaç yön/geometri) → R6 · #4 (tam-boy drag feedback) → R5 ·
> #5 (serbest 2D konum) → R3/R5 · #6 (akıcı reflow) → R4 · #7 (minimal tutamaç UI) → R7.
>
> **KİLİTLİ KARARLAR (kullanıcı emri — R1 bunları detaylandırır, değiştirmez):**
> - **Sütun = 6** (`kGridColumns = 6`). Yükseklik aşağı doğru sonsuz N satır.
> - **Hücre kare:** satır birim yüksekliği = hücre genişliği (`rowH = cellW`). Hem genişlik
>   hem yükseklik **hücreye snap** — küsuratlı px YOK.
> - **Konum mutlak (x,y):** liste sırası DEĞİL. Kullanıcı kartı boş hücrelere serbest koyar.
> - **Yerleşim:** `Stack` + `AnimatedPositioned` (akış `_packRows`/`Row`/`Expanded` kaldırılır).
> - **Sürükleme:** tam-boy, `Opacity ~0.6` feedback (çip kaldırılır).
> - **Tutamaç:** minimal — ince çerçeve + zarif köşe/kenar noktaları/hapları.

### Hücre geometrisi (R1 kilitler, R3 uygular)
- `cellW = (maxWidth - (kCols-1)*gap) / kCols` · `rowH = cellW` (kare) · `gap = 8px` (öneri).
- Kart pikseli: `left = x*(cellW+gap)`, `top = y*(rowH+gap)`,
  `w_px = w*cellW + (w-1)*gap`, `h_px = h*rowH + (h-1)*gap`.
- Sınırlar: `1 ≤ w ≤ 6`, `1 ≤ h`, `0 ≤ x ≤ 6-w`, `y ≥ 0`. Toplam yükseklik = `maxY*(rowH+gap)`;
  `SingleChildScrollView` + `SizedBox(height: toplam)` ile dikey kaydırma (sonsuz N).

### Durum özeti (R1–R8)
`[ ]` bekliyor · `[~]` kısmen · `[X]` bitti — (yukarıdaki hızlı-bakış listesiyle eş)

- [x] **R1 · 2D matris mimari TASARIM 🔴 Opus 4.8 — ✅ TASARIM TAMAM**
  - **Amaç:** Kod yazmaz; R2–R8'in birebir uygulayacağı kilitli tasarımı üretir (yukarıdaki
    kilitli kararları somutlaştırır, açık soruları kapatır). Çıktı bu bölüme yazılır.
  - **Üretilecek kararlar:**
    1. **Hücre oranı kesinleşir:** `rowH = cellW` mi yoksa sabit oran mı (içerik 1×1'de
       sığıyor mu? 16 kartın min satır gereksinimi tablosu). `gap`, dış padding netleşir.
    2. **Veri modeli:** `DashboardCardConfig(type, x, y, w, h)` (hepsi int). `==`/`hashCode`,
       `withBounds`. Eski `width`/`height` alanları kalkar.
    3. **Reflow algoritması (sözde-kod):** occupancy matrisi `bool[rows][cols]`; yerleştirme
       çakışmayı **aşağı it** + (boşsa) **yukarı sıkıştır**; sürükle/resize sırasında canlı.
       İki strateji tanımla: (a) serbest bırakma (gaps korunur) (b) çakışmada it. Hangisi
       varsayılan? **Karar: serbest konum; yalnız çakışan komşu itilir, kendiliğinden
       sıkıştırma YOK** (launcher hissi).
    4. **Migration (eski → yeni):** `"tür:genişlik[:yükseklik]"`/`"tür:boyut"`/`"tür"` →
       `w = round(eskiGenişlik/2).clamp(1,6)`; `h = max(1, round(eskiPx / nominalRowH))`
       (nominalRowH≈80); ardından **auto-flow** ile sırayla ilk uygun (x,y)'ye yerleştir.
    5. **Tutamaç geometri matematiği:** her köşe/kenar için `onPanUpdate` delta → hangi kenar
       hareket eder (top çekince `y` azalır + `h` artar; sol çekince `x` azalır + `w` artar;
       sağ/alt sadece `w`/`h` artar). Snap eşiği (hücrenin yarısı). Min 1×1 koruması.
    6. **Sürükleme:** `Draggable`/`LongPressDraggable` tam-boy feedback; parmağın altındaki
       hücreyi `(localPos / (cell+gap)).floor()` ile bul; hedef hücre **hayalet vurgu**;
       bırakınca `setBounds`. 60fps için sadece sürüklenen + itilen komşular animasyonlu.
    7. **Widget ağacı:** `_GridDashboard`/`_EditableGrid`/`_EditCard`/`_packRows`/`_row`/
       `_DragChip`/`_DropPlaceholder` → yeni `MatrixGrid` (view+edit ortak) + `GridCard` +
       `ReflowController`. Hangileri silinir/kalır listesi.
  - **Kabul:** R2–R8 için net veri modeli, reflow sözde-kodu, geometri formülleri, migration
    kuralı, widget ağacı kararı bu bölüme yazılı; açık soru kalmadı.

- [x] **R2 · Veri modeli (x,y,w,h) + persistence + eski format göçü 🟣 Gemini 3.1 Pro — ✅ YAPILDI**
  - **Dosyalar:** `app/lib/features/home/dashboard_card.dart`,
    `app/lib/features/home/dashboard_providers.dart`,
    `app/test/features/dashboard_card_test.dart` (genişlet).
  - **Adımlar:**
    - `kGridColumns = 6`. `DashboardCardConfig`: `width`/`height` → `int x, y, w, h` (R1'e göre).
      `encode()` = `"tür:x:y:w:h"`. `decode()` yeni 5-parça + eski `"tür:genişlik[:yükseklik]"`
      + `"tür:boyut"` + `"tür"` çözüp **R1 migration kuralı**yla x,y,w,h'e göçürür.
      `==`/`hashCode`/`withBounds` güncellenir.
    - `DashboardLayoutNotifier`: `setWidth`/`setHeight`/`reorderItem` → `setBounds(type,x,y,w,h)`,
      `addCard(type)` (ilk uygun boş hücre), `removeCard`/`toggle`. `_kDefaultLayout` x,y,w,h ile.
      Yükleme sırasında eski string listesi göçer ve **bir kez yeniden kaydedilir** (idempotent).
    - `size`/`effectiveHeight`/`dashboardCardFor`'un `size` köprüsü: 16 kartın imzası R3'te
      değişene dek geçici korunur (shim) ya da R3 ile aynı turda güncellenir — R1 kararına uy.
  - **Tuzak:** `dashboardCardFor(type, size)` 16 karta `size` geçiyor; imza değişimi R3 ile
    koordineli. `defaultCardHeight`/`kMin/MaxCardHeight` px sabitleri kalkar (hücre bazlı).
  - **Kabul:** Eski kayıtlı düzenler çökmeden yeni 6×N formatına göçer; serileştirme testleri
    (yeni + tüm eski formatlar) geçer; `flutter analyze` temiz.
  - **Uygulandı (2026-06-26):** `DashboardCardConfig` artık kalıcı olarak `x,y,w,h` (int hücre)
    saklıyor; format `"tür:x:y:w:h"`. Eski `"tür:genişlik[:yükseklik]"`, `"tür:boyut"` ve
    sade `"tür"` kayıtları R1 kuralıyla 6 sütuna göçüyor ve provider yüklemede prefs'i yeni formata
    bir kez yeniden kaydediyor. R3'e kadar mevcut akış ekranının derlenmesi için `width`,
    `effectiveHeight`, `setWidth`, `setHeight`, `reorderItem` köprüleri geçici bırakıldı.

- [x] **R3 · Stack + AnimatedPositioned statik render 🔵 Sonnet 4.6 — ✅ YAPILDI**
  - **Dosya:** `app/lib/features/home/home_screen.dart` (akış widget'ları kaldırılır).
  - **Adımlar:** `_packRows`/`_row`/`_GridDashboard` (akış) → `LayoutBuilder` ile `cellW`/`rowH`
    hesaplayıp her kartı `AnimatedPositioned(left,top,width,height)` ile **mutlak** çizen
    `MatrixGrid`. Normal modda kartlar (x,y,w,h)'de; basılı-tut → düzenleme. Dikey kaydırma
    `SingleChildScrollView` + toplam yükseklikli `SizedBox`. Animasyon süresi ~180ms easeOut.
  - **Tuzak:** Kart içeriği artık hücre-bazlı yükseklik alır (`h*rowH`); `dashboardCardFor`
    yüksekliği piksel yerine bu hesaptan alır. Boş hücreler düzenleme modunda hafif ızgara
    çizgisiyle gösterilebilir (R5/R7'ye hazırlık).
  - **Kabul:** Kartlar 6 sütunlu matriste doğru konum/boyutta; ekran kaydırılır; içerik (§2E)
    tüm hücre oranlarında bozulmaz; `flutter analyze` temiz, 62+ test geçer.
  - **Uygulandı (2026-06-26):** `home_screen.dart` akış/Row paketlemesinden çıkarıldı.
    Normal ve düzenleme modu ortak `_MatrixGrid` kullanıyor; kartlar `x,y,w,h` ile
    `Stack + AnimatedPositioned` içinde çiziliyor. Dikey kaydırma `SingleChildScrollView`
    ve toplam matris yüksekliğiyle korunuyor. Eski `_packRows`/`_row`/`_Slot`/
    `_DragChip`/`_DropPlaceholder` akış parçaları kaldırıldı. Sürükleme/reflow/resize
    davranışları R4–R6'ya bırakıldı.

- [ ] **R4 · Occupancy matrisi + çarpışma & akıcı reflow fiziği 🔴 Opus 4.8**
  - **Dosya:** `home_screen.dart` (+ gerekiyorsa `core/grid/reflow.dart` saf mantık).
  - **Adımlar:** R1 sözde-kodundan `bool[rows][cols]` occupancy; `placeAt(card, x, y)` çakışan
    komşuları **aşağı iter** (launcher mantığı, kendiliğinden sıkıştırma yok). İtme animasyonu
    `AnimatedPositioned` ile pürüzsüz; ışınlanma yok. Saf yerleştirme/çakışma fonksiyonları
    **birim testli** (`test/core/grid_reflow_test.dart`).
  - **Tuzak:** Sonsuz döngü/taşma (it → yeni çakışma → it...) sınırlanmalı; matris yüksekliği
    dinamik büyür. Boş bırakma korunur (yalnız gerçek çakışanlar itilir).
  - **Kabul:** Bir kart başka kartın üstüne gelince komşular akıcı (60fps) yer açar, ışınlanma
    yok; boş hücreler korunur; reflow birim testleri geçer.

- [ ] **R5 · Sürükle: tam-boy yarı saydam feedback + hücre hedefleme 🟠 Opus 4.6**
  - **Dosya:** `home_screen.dart`.
  - **Adımlar:** `_DragChip`/`_DropPlaceholder` kaldırılır. `LongPressDraggable` feedback'i
    kartın **gerçek görseli, tam boyut, `Opacity 0.6`**. Parmağın altındaki hücreyi hesapla;
    hedef (x,y)'de **hayalet/vurgu** göster; geçerli (boş veya itilebilir) ise bırakınca
    `setBounds` + R4 reflow. Geçersiz konumda eski yere döner. Düzenleme moduna geçişte scroll
    offset korunur (mevcut §2F davranışı sürdürülür).
  - **Tuzak:** Feedback tam boy olduğundan büyük kartlarda performans; sadece sürüklenen +
    itilen komşular yeniden çizilir (`RepaintBoundary`). Web'de pointer güvenilirliği (mevcut
    Draggable yaklaşımıyla uyum).
  - **Kabul:** Sürüklenen kart küçülmez, yarı saydam tam boy süzülür; hedef hücre net görünür;
    serbest boş hücreye bırakılabilir; komşular akıcı yer açar.

- [ ] **R6 · Boyutlandırma: hücre-snap yükseklik + doğru köşe/kenar geometri 🟠 Opus 4.6**
  - **Dosya:** `home_screen.dart`.
  - **Adımlar:** R1 geometri matematiğiyle 4 köşe (+ ops. 4 kenar) tutamaçları. **Hata #3 fix:**
    üstten çekince `y` azalır & `h` artar (alt kenar sabit); soldan çekince `x` azalır & `w`
    artar (sağ kenar sabit); sağ/alt sadece `w`/`h`. **Genişlik VE yükseklik hücreye snap**
    (eşik = hücrenin yarısı), küsuratlı px yok. Canlı resize'da R4 reflow; min 1×1, max w=6.
  - **Tuzak:** Snap sırasında titreme (jitter) — biriken delta + eşik ile stabilize. Sol/üst
    resize sırasında konum (x,y) değiştiği için occupancy yeniden hesaplanır.
  - **Kabul:** Kart 4 köşe/kenardan hücreye oturarak büyür/küçülür; üst tutamaç doğru yönde
    (yukarı) uzar; yükseklik satır katlarına snap eder; çakışmada akıcı reflow.

- [ ] **R7 · Tutamaç & düzenleme UI estetiği 🔵 Sonnet 4.6**
  - **Dosya:** `home_screen.dart` (+ ufak ortak widget'lar).
  - **Adımlar:** Kaba mavi yuvarlaklar → **minimal**: düzenleme modunda kartı saran **ince**
    çerçeve (1px, primary @ ~0.6) + köşelerde/kenar ortalarında **zarif ufak noktalar/haplar**
    (6–10px, yumuşak gölge). Üst kontrol hapı sadeleştirilir (sürükle ipucu + `g×s` etiketi +
    kaldır ×). Hover/aktif durumda hafif vurgulanır. Tutarlı tema renkleri.
  - **Kabul:** Tutamaçlar minimal ve profesyonel; göze batmaz ama tutması kolay; düzenleme modu
    "launcher" hissi verir; dokunma hedefleri yeterli (≥24px efektif).

- [ ] **R8 · Göç doğrulama + string + cilalama + analyze/test 🟢 Gemini 3.5 Flash**
  - **Dosyalar:** `home_screen.dart` (metinler), `progress.md`, gerekiyorsa ufak rötuşlar.
  - **Adımlar:** Eski kayıtlı düzenlerin (gerçek cihaz prefs) yeni formata göçtüğünü doğrula;
    düzenleme ipucu metnini yeni davranışa göre güncelle ("kartı tut, boş hücreye bırak;
    köşelerden hücreye snap büyüt"); kalan lint/uyarıları temizle; `flutter analyze` + tüm
    testler + manuel `flutter run` (5005 portu). progress.md R1–R8 `[X]` işaretle.
  - **Kabul:** Analiz temiz, tüm testler geçer, manuel akış pürüzsüz; eski düzen göçü sağlam.

### §2.2 Sıralama & bağımlılıklar
1. **Zorunlu sıra:** R1(🔴 tasarım) → R2(model/migration) → R3(render) → R4(reflow) →
   {R5(drag), R6(resize)} → R7(UI) → R8(cila). R5/R6 R4'e bağlı (reflow); paralel gidebilir.
2. R2'nin `dashboardCardFor` imza değişimi R3 ile **aynı turda** koordineli (16 kart kırılmasın).
3. 🔴 R1 kilitlenmeden R2+ başlamaz. R4 reflow birim testleri R5/R6'dan ÖNCE yeşil olmalı.
4. **§2.1 (akış) kodu R3'te tamamen kaldırılır** — `_packRows`/`_row`/`_DragChip`/
   `_DropPlaceholder`/eski `_EditableGrid` silinir; geriye dönüş yok.

---

## Sıralama & bağımlılıklar
1. **§1 önce, sıra zorunlu:** 1A → 1B(🔴 tasarım) → 1C(DB) → 1D(Dart) → 1E. (1C migrationları ile 1D Dart'ı birlikte deploy edilmeli — biri olmadan diğeri prod'u kırar.)
2. **§2:** 2A(🔴 tasarım) → 2B → {2C, 2D} → 2E → 2F. Grid çekirdeği (2B–2F) bitince 2G/2H/2I bağımsız ilerler. 2E ile 2B'nin `dashboardCardFor` imza değişimi koordineli olmalı.
3. 🔴 tasarım fazları (1B, 2A) kendi implementasyonlarından ÖNCE kilitlenir.

## Doğrulama (faz geneli)
- Her mini-faz sonu: `cd app && flutter analyze` temiz + 47 test geçer (`flutter test`) + ilgili ekran `flutter run` ile manuel.
- **§1 kabul senaryosu:** 2 grupta üye olan test kullanıcısıyla tek oturum tut → her iki grubun leaderboard/günlük totalinde görünür, kişisel profil toplamı çift saymaz. Bir üyeyi çıkar → listede "Eski Grup Üyesi", geçmiş süresi grupta durur, yeni oturumu o gruba yazılmaz. Çıkan üye geri katılınca normalleşir.
- **§2 kabul senaryosu:** Karta doğrudan basılı tut → sürükle, komşular animasyonla yer açar; köşeden serbest resize; tüm oranlarda içerik bozulmaz; düzenlemeye geçişte ekran zıplamaz; eski kayıtlı düzen yeni formata göç eder.


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
- **2026-06-21 (oturum kalıcılığı ✅):** Faz 1.1 son maddesi tamamlandı. `supabase_flutter`
  oturumu zaten varsayılan olarak yerel depolamada tutuyor ve `Supabase.initialize()` açılışta
  geri yüklüyor → uygulama kapanıp açılınca giriş hatırlanıyor. Ek sağlamlaştırma:
  `SupabaseAuthRepository._profileFor` artık profil satırı çekilemezse (çevrimdışı/geçici hata)
  kullanıcıyı dışarı atmıyor; oturum geçerliyse metadata'dan geçici profille içeride tutuyor
  (project.md §3.3 çevrimdışı dayanıklılık). 37/37 test geçti, analiz temiz.
- **2026-06-22 (istatistik zenginleştirme — FAZ 3.10 kısmen ✅):** Kişisel istatistikte ders
  bazında dağılım eski çubuklar yerine **donut grafik** + yüzdeli açıklama (`SubjectDonut`,
  fl_chart PieChart, ortada toplam saat). Sınıf istatistiğine **son 7 gün sınıf günlük trendi**
  çubuk grafiği eklendi (leaderboard üstü). 52/52 test, analiz temiz. Kalan: daha fazla sınıf
  metriği (haftalık değişim, ders bazında sınıf kıyası vb.).
- **2026-06-21 (Ana Sayfa esnek dashboard — FAZ 3.8 ✅):** Kullanıcı kararı: tam
  özelleştirilebilir + sayaç varsayılan Ana Sayfa'da, isteyen Sınıflar'a ekler. `shared_preferences`
  eklendi (`core/prefs/app_prefs.dart`, main'de override). 4. sekme **Ana Sayfa** en başa
  (nav 4 sekme; Sınıflar artık index 1). Kart kataloğu (`dashboard_card.dart`): sayaç / bugün
  özeti / haftalık grafik / sınıf sıralaması. `DashboardEditScreen` ile sürükle-sırala
  (ReorderableListView `onReorderItem`) + ekle/çıkar; düzen `dashboardLayoutProvider` ile
  kalıcı. Sayaç Sınıflar'a eklenebilir (`classroomShowTimerProvider`, kalıcı); Sınıflar
  varsayılan sayaçsız. widget_test 4 sekmeye güncellendi + sayaç kartının periyodik timer'ı
  pumpAndSettle'ı bekletmesin diye test düzeni sayaçsız seed'lendi. 52/52 test, analiz temiz.
- **2026-06-21 (özelleştirilebilir saat stilleri — FAZ 3.7 ✅):** `clock_style.dart`:
  3 stil — sade rakam (varsayılan), **hedef halkası** (günlük hedefe göre dolan halka +
  ortada süre), **renk geçişi** (hedefe yaklaştıkça rakam kırmızı→amber→yeşil; `goalColor`
  lerp). Ortak `StudyClock` widget'ı hem sayaç kartında (40px / halka 160) hem tam ekran
  odakta (56px / halka 280) kullanılıyor. Stil seçici `showClockStyleMenu` (anchored menü),
  kart ve tam ekrandaki **tune** ikonundan. `clockStyleProvider` (bellek-içi; kalıcılık
  sonra). 52/52 test, analiz temiz.
- **2026-06-21 (günlük hedef + seri — FAZ 3.5.2/3.5.3 ✅):** `profiles.daily_goal_minutes`
  (`migrations/0005`, varsayılan 360) + `Profile.dailyGoalMinutes` + `updateDailyGoal`
  (auth repo soyut/bellek-içi/Supabase). Saf `currentStreak` hesabı (`core/stats`): hedef
  tutturulan her gün +1; bugün sürdüğü için bugün eksikse seri kırılmaz (dünden sayar).
  Sayaç kartına **hedef ilerleme çubuğu** (yüzde, hedefe ulaşınca yeşil, dokun→düzenle) +
  🔥 **seri rozeti** gömüldü. Sayaç kartı zaten saniyede yenilendiği için canlı. Saat
  stilleri (halka/renk geçişi) artık hedefe bağlanabilir. Sayı sayaç widget'ı paylaşılan
  `core/widgets/number_stepper.dart`'a taşındı (manuel giriş + hedef düzenleme ortak).
  52/52 test, analiz temiz. **Kullanıcı: `migrations/0005_daily_goal.sql` çalıştırmalı.**
- **2026-06-21 (açılır menüler "basılan yerde" + manuel sayaç basılı-tut):** Geri bildirim:
  "alttan açılan pencere güzel değil, Claude Code model seçici gibi tam basılan yerde açılsın;
  bunu çoğu açılır seçim için yap." Eklenen `core/widgets/anchored_menu.dart`
  (`showAnchoredMenu` = tetikleyiciye göre, `showMenuAtPosition` = basış konumunda). **Ders
  seçici** ve **sınıf değiştirici** bottom-sheet'ten **anchored popup menü**ye geçti (sınıf
  ↔ ikonu Builder ile sarıldı; sekme basılı-tutta basış konumu kullanılıyor). Sınıf satırında
  ⋮ detay butonu menüyü kapatıp ayar ekranını açar. Manuel süre: **dakika adımı 1** oldu ve
  +/- tuşları **basılı tutunca sabit hızda** artırıp azaltıyor (`_HoldRepeatButton`, Listener
  tabanlı; 400ms gecikme → 80ms tekrar). 47/47 test, analiz temiz.
- **2026-06-21 (sayaç yenileme başladı — FAZ 3.7, §3.12):** Kullanıcı geri bildirimi:
  "saat çok profesyonel olmalı, başka kronometre gerekmesin; ders seçimi Claude Code model
  seçici gibi dropdown olsun; odak için tam ekran tuşu olsun; sade ama özelleştirilebilir."
  Sınıflar AppBar başlığı ("Sınıflar" yazısı) kaldırıldı (sağ üst ↔ değiştirici kaldı).
  Ders seçici çip-satırı → **dropdown hap** (kapalı: seçili ders/"Genel" + ▾; açık: alt
  sayfada liste + "Dersleri düzenle"). **Tam ekran odak modu** (`focus_timer_screen.dart`):
  büyük canlı sayaç + ders + büyük Başlat/Durdur + küçült, immersive. Saat stilleri (halka/
  renk geçişi) ve Ana Sayfa sonraki fazlara planlandı (progress FAZ 3.7–3.10 yeniden
  numaralandı). 47/47 test, analiz temiz.
- **2026-06-21 (Supabase uçtan uca ✅):** Proje İngilizce yola taşındı
  (`...\Desktop\Dev\online-study-room`), `C:\Dev` silindi. Kullanıcı Supabase projesi açtı,
  şema kuruldu, e-posta doğrulaması kapatıldı, anahtarlar `env.json`'a girildi. Web'de passkeys
  hatası `web/passkeys_bundle.js` ile giderildi. Chrome'da kayıt → sınıf → çalışma kaydı
  test edildi; veriler gerçek veritabanında (profiles/groups/study_sessions) doğrulandı.

---
