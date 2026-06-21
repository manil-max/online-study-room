# progress.md — İlerleme Takibi

> Bu dosya **sadece** "ne yaptık / ne yapılacak" takibidir. Detaylı fazlara ve alt-fazlara
> bölünmüştür. Proje bilgileri için → `project.md`. AI ajan kuralları için → `AGENTS.md`.
>
> Durum: `[ ]` yapılacak · `[~]` devam ediyor · `[x]` tamamlandı
> Son güncelleme: 2026-06-20

---

## Özet Durum

- **Aktif Faz:** Oturum kalıcılığı sağlamlaştırıldı (Faz 1.1) — SDK zaten oturumu kalıcı tutuyor; profil çekimi çevrimdışında kullanıcıyı dışarı atmıyor. Tamamlananlar: Faz 1 (auth+profil+sınıf), Faz 2 (presence+manuel giriş), Faz 3 istatistikler (3a–3d). Supabase uçtan uca test edildi ✅. Kalan: Faz 4 widget (Android cihaz ister — ertelendi), Şifre sıfırlama (opsiyonel), Çevrimdışı tespiti/heartbeat, tasarım (en son).
- **Proje konumu:** `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room` (İngilizce ad — Türkçe/boşluklu yol Flutter'ı bozuyordu; aşağıdaki nota bak)
- **Sıradaki adım:** 2026-06-22 geri bildirim turu büyük ölçüde işlendi: Sınıf→Grup terminolojisi,
  Derssiz→Genel, profilden Derslerim kaldırma, uzun tarih, büyük seri, İstatistik grup
  değiştirici, seçilebilir metin, tıklanabilir sıralama + üye bilgi sayfası, grup üye serileri.
  **Kalan büyük işler (FAZ 3.11 — aşağıda):** (1) **Grup hedefi** (admin-ayarlı, migration 0006)
  ve grup serisinin gruba göre hesaplanması; (2) **Zengin & etkileşimli Ana Sayfa**: kartları
  **yeniden boyutlandırma** (küçük/orta/büyük), 2 sütun grid, veri formatı seçimi, daha çok
  kart türü; (3) **etkileşimli istatistik**: grafik dokunmatik ipuçları, takvim **ısı haritası**
  (study streak heatmap), çizgi grafiği, tablo görünümü.
- **Bekleyen (kullanıcı/admin):** (1) **`migrations/0004_group_admin.sql`** Supabase'de çalıştırılmalı — sınıf ad değiştir / kod yenile / üye çıkar / sınıf sil (admin RLS) bunsuz çalışmaz. (2) **`migrations/0005_daily_goal.sql`** çalıştırılmalı — günlük hedef (`profiles.daily_goal_minutes`); bunsuz hedef hep varsayılan (6sa) görünür ve düzenleme kalıcı olmaz. (3) `migrations/0003_subjects_realtime.sql` artık **opsiyonel** (ders deposu Realtime'a bağımlı değil; sadece çoklu cihaz canlı senkronu için).
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
