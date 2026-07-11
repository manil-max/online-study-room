# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-11
> Sistem: İş Paketi (WP) tabanlı. Planlama → `.agents/skills/planner/SKILL.md`, Uygulama → `.agents/skills/worker/SKILL.md`.

---

## Proje Gerçekleri (ajan referansı)

- **Framework:** Flutter ^3.12 · Riverpod 3.3 · Supabase 2.15 · fl_chart
- **Uygulama kökü:** `app/` — tüm flutter komutları burada çalışır
- **Migration'lar:** `supabase/migrations/` (son: `0018`) — sıralı, elle uygulanır
- **Repo katmanı çift:** her arayüz `supabase/` + `in_memory/` altında
- **Gün sınırı:** `Europe/Istanbul`
- **RLS helper'ları:** `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`
- **Dashboard:** 6 sütunlu 2D matris, 19 kart türü, `grid_reflow.dart` motoru
- **Tema:** 5 hazır palet, koyu varsayılan, `AppTheme` palet-parametreli; WP-26 ile ek hazır palet + 3 custom slot planlandı
- **Desktop:** WP-11 ilk EXE/build hattını açtı; WP-27/28 ile Windows'a özel masaüstü UX ve dağıtım planlandı
- **Release:** Stable/Beta kanalı GitHub Releases ile çalışır; WP-29 ikon/branding, WP-30 sürüm notları ve güncelleme geçmişi için planlandı
- **Son WP numarası:** 30 (WP-29/30 ikon ve sürüm notları sistemi için planlandı)
- **Geliştirme ortamı:**
  - Proje: `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room`
  - Flutter: `C:\src\flutter` · Android SDK: `C:\Android\Sdk`
  - JDK: `C:\Program Files\Android\Android Studio\jbr`
  - Web test: `flutter run -d chrome --web-port=5005 --dart-define-from-file=env.json`
  - GitHub: `manil-max/online-study-room` (public)

---

## ⚡ Aktif İş Paketleri

> Bu bölüm üç canlı çalışma hattına ayrıldı: `Gemini`, `Claude`, `Codex`.
> Her agent yalnız kendi lane'ini günceller. Bir WP başka ajana geçerse kart aynı editte yeni lane'e taşınır ve not düşülür.
> Her anlamlı geçişte `progress.md` güncellenir: başlatma, bloklanma, devretme, tamamlanma.

### Gemini Lane
- **Sorumlu:** Gemini
- **Durum:** [x] Boşta — WP-25 ve WP-29 tamamlandı
- **Aktif WP:** —
- **Kapsam:** Yeni atama bekleniyor.

### Claude Lane
- **Sorumlu:** Claude
- **Durum:** [x] Boşta — WP-11 ve WP-13 tamamlandı
- **Aktif WP:** —
- **Kapsam:** Yeni atama bekleniyor.
- **Kurallar:** Bu lane yalnız Claude tarafından güncellenir; ilerleme her geçişte yazılır.

### Codex Lane
- **Sorumlu:** Codex
- **Durum:** [x] Boşta — WP-30 tamamlandı
- **Aktif WP:** —
- **Kapsam:** Yeni atama bekleniyor.
- **Not:** Limit aşımı nedeniyle yarıda kalan WP-30, Gemini tarafından tamamlandı.

---

## 🧭 Plan Kuyruğu

> Bu bölüm backlog'daki işlerin uygulanma sırasını ve dosya sahipliğini önden netleştirir. Aktif çalışmaya alınacak iş, buradan seçilip yukarıdaki "Aktif İş Paketleri" bölümüne taşınır.

### V4 Hazırlık Notu
- Görünen uygulama adı Android/Web/Flutter başlıklarında **Odak Kampı** olarak ayarlandı.
- `pubspec.yaml` paket adı değiştirilmedi; import ve uygulama kimliği kırılmasın diye `online_study_room` teknik ad olarak kalır.
- V4 ile birlikte WP-17 ve WP-18 tamamlandı: canlı sayaç yüzeyleri, widget önizlemeleri, sade bildirim akışı, grup ekranı hiyerarşisi ve sayaç ayarlarının kaldırılması artık teslim durumunda görünür.
- Sınıf ekranındaki sohbet girişi ayrı **Sohbet** ekranına taşındı; grup bilgileri ve yönetim **Ayarlar** girişinden açılır.
- Gamification migration'ı üretim Supabase'e uygulanmadan da Başarılar kartı varsayılan profil ile görünür; `0017_gamification_profiles.sql` uygulanınca kalıcı seri koruma verisine otomatik döner.


### WP-20: Özelleştirilebilir Saat Stilleri 🕰️
- **Durum:** [ ] Bekliyor
- **Backlog:** Sınıf "yarış"/dilim görünümü ve ek estetik stiller
- **Kapsam:** Mevcut `ClockStyle` enum'ına yeni görsel stiller (pasta dilimi gibi dolan yarış stili, neon vb.) ekleyerek timer kartındaki CustomPainter'ı genişletmek.
- **SAHİP dosyalar:**
  - `app/lib/features/classroom/widgets/clock_style.dart`
  - `app/lib/features/classroom/widgets/study_timer_card.dart`
- **DOKUNMA:**
  - `app/lib/core/stats/**`, `supabase/migrations/**`
  - `app/lib/features/home/**`
- **Adımlar:**
  - [ ] `ClockStyle` enum'una 2 yeni stil ekle (örn. `slice` (dilim/yarış) ve `minimal`).
  - [ ] `ClockPainter` içinde bu yeni stiller için çizim mantığını (canvas.drawArc vb. kullanarak) uygula.
  - [ ] Timer üzerindeki ayarlar veya stil seçici döngüsünü güncelle.
- **Kabul:** Yeni stiller sorunsuz render edilir ve taşma yapmaz. UI testleri geçer.
- **Model matrisi:** WP-20 | Claude Sonnet 5 high / Gemini 3.5 Flash high

### WP-21: Gelişmiş Grid Boyutlandırma 📐
- **Durum:** [ ] Bekliyor
- **Backlog:** Kartların 4 kenar ve köşeden (genişlik + yükseklik) ayarlanması
- **Kapsam:** Düzenleme modundayken (Edit Mode) dashboard kartlarının köşesine boyutlandırma (resize) tutamacı eklenerek `w` ve `h` değerlerinin dinamik değiştirilmesi.
- **SAHİP dosyalar:**
  - `app/lib/features/home/widgets/dashboard_card.dart`
  - `app/lib/core/grid/grid_reflow.dart` (Gerekirse çakışma çözümü için)
  - `app/lib/data/providers/dashboard_providers.dart`
- **DOKUNMA:**
  - Kartların kendi iç içerik UI'ları (`home/widgets/*_card.dart`)
  - `app/lib/features/classroom/**`, `supabase/**`
- **Adımlar:**
  - [ ] Düzenleme modu aktifken `DashboardCard` üzerine sağ alt köşeye bir `GestureDetector` (resize handle) ekle.
  - [ ] Sürükleme (pan) miktarını grid hücre boyutuna (`rowH`, `colW`) bölerek `DashboardCardConfig`'in `w` ve `h` değerlerini güncelle.
  - [ ] Boyut değiştiğinde diğer kartların üstüne binmesini önlemek için `grid_reflow` motorunu tetikle.
- **Tuzaklar:** Resize işlemi sırasında `w` ve `h` değerlerinin minimum (1) ve maksimum (kGridColumns) sınırlarını aşmaması gerekir.
- **Kabul:** Kullanıcı kartları serbestçe uzatıp kısaltabilir ve düzen kaydedildiğinde kalıcı olur.
- **Model matrisi:** WP-21 | Claude Sonnet 5 high / GPT-5.6 Terra high

### WP-22: Canlı Grup Hedefi Animasyonu 🎯
- **Durum:** [ ] Bekliyor
- **Backlog:** Grup hedef ilerleme barının çalışan kişi sayısına göre saniye saniye akması
- **Kapsam:** Mevcut `GroupGoalCard`'ın içindeki progress bar'ın durağan (sadece veri gelince güncellenen) yapısını, aktif çalışan üye sayısına orantılı olarak her saniye pürüzsüz akan canlı bir animasyona çevirmek.
- **SAHİP dosyalar:**
  - `app/lib/features/home/widgets/group_goal_card.dart`
- **DOKUNMA:**
  - `app/lib/data/providers/**` (Sadece okunacak, state değiştirilmeyecek)
  - `supabase/**`, `app/lib/features/classroom/**`
- **Adımlar:**
  - [ ] `GroupGoalCard` içinde `activeMembersCount` (aktif çalışan sayısı) verisini oku.
  - [ ] Eğer aktif çalışan varsa, bir `Ticker` veya periyodik `Timer` kurarak hedefin görsel (sanal) ilerlemesini saniyede `activeMembersCount * 1 saniye` kadar artır.
  - [ ] Gerçek veri DB'den her yenilendiğinde (örn. 20 saniyede bir) sanal ilerlemeyi gerçek veriyle senkronize et (zıplamaları önlemek için `TweenAnimationBuilder` kullan).
- **Kabul:** Grup çalışırken bar yavaşça (canlı gibi) dolar, boşken durur.
- **Model matrisi:** WP-22 | Claude Sonnet 5 high / Gemini 3.5 Flash high

### V5 Araştırma Notu: Saat Uygulaması Yerini Alma ⏱️
- **Kaynak özeti:** Apple Clock/StandBy, Google Clock, Samsung Clock ve popüler saat/timer uygulamaları incelendi.
- **Ürün yönü:** Odak Kampı'nın çekirdeği çalışma/pomodoro olmaya devam eder; fakat kullanıcı isterse varsayılan Saat uygulamasını açmadan alarm, çoklu timer, kronometre, yatay masa/başucu saati ve dış yüzey kontrollerini buradan yönetebilmelidir.
- **Tasarım ilkeleri:**
  - Büyük, tek bakışta okunur zaman; yatay kullanım birinci sınıf davranış olmalı.
  - Timer/alarm eylemleri uygulamayı açmaya zorlamadan bildirim/widget üzerinden çalışmalı.
  - Ağır ayarlar ana akışı boğmamalı; Apple/Google Clock sadeliği + Samsung/MultiTimer pratik gücü.
  - Sleep/snore gibi hassas özellikler ilk teslimde yok; ileride ancak açık izin, yerel veri ve medikal iddia olmadan.
- **Çakışma kontrolü:** WP-23 `home_shell.dart` ve `focus_timer_screen.dart` nedeniyle WP-19 bittikten sonra başlamalı. WP-24 veri/notification temeliyle paralel başlayabilir ama `timer_notification_service.dart` değişirse WP-17/WP-19 alanıyla çakışma kontrolü yapılmalı.

### WP-23: Clock Center + Landscape StandBy 🕰️
- **Durum:** [ ] Bekliyor — WP-19 sonrası önerilir
- **Backlog:** V5 Saat uygulaması yerini alma fazı
- **Kapsam:** Apple StandBy ve modern saat uygulamalarındaki “telefonu yatay koyunca büyük, sakin, okunur saat” deneyimini Odak Kampı'nın çalışma odağıyla birleştir. Bu WP alarm motoru yazmaz; görsel merkez, navigasyon ve landscape/focus deneyimini kurar.
- **SAHİP dosyalar:**
  - `app/lib/features/clock/clock_screen.dart` (yeni)
  - `app/lib/features/clock/widgets/standby_clock_view.dart` (yeni)
  - `app/lib/features/clock/widgets/clock_mode_tabs.dart` (yeni)
  - `app/lib/features/clock/widgets/large_time_face.dart` (yeni)
  - `app/lib/features/classroom/widgets/focus_timer_screen.dart`
  - `app/lib/core/navigation/home_shell.dart`
  - `app/test/features/clock_screen_test.dart` (yeni)
- **DOKUNMA:**
  - `app/android/**`
  - `app/lib/data/providers/study_providers.dart`
  - `app/lib/core/notifications/**`
  - `supabase/migrations/**`
- **Adımlar:**
  - [ ] Yeni `ClockScreen` oluştur: sekmeler/segmentler `Saat`, `Kronometre`, `Timer`, `Odak` mantığında; mevcut `studyTimerProvider` yalnız okunur/kontrollü kullanılsın.
  - [ ] Landscape algılanınca `StandByClockView` göster: dev saat, tarih, seçili mod, çalışma/pomodoro kalan süre, düşük parlaklık/kırmızı gece tonu seçeneği.
  - [ ] `FocusTimerScreen`i StandBy tasarım ilkeleriyle büyüt: yatayda iki kolon, dokunması kolay başlat/durdur, analog/dijital saat yüzü geçişi.
  - [ ] `HomeShell`e “Saat” erişimi ekle veya mevcut Timer kartından tek dokunuşla Clock Center aç; WP-19 ile aynı anda yapılmayacak.
  - [ ] Widget testleriyle portrait/landscape taşma ve temel navigasyonu doğrula.
- **Tuzaklar:**
  - StandBy tasarımı iOS kopyası olmamalı; yalnız kullanım kalıbı alınır.
  - Yatay moda geçişte global orientation lock yapma; kullanıcı telefonu çevirdiğinde responsive düzen değişsin.
  - `HomeShell` WP-19 ile çakışırsa WP-23 bekler.
- **Kabul:** Telefon yataydayken büyük saat/odak ekranı taşmadan çalışır; mevcut kronometre/geri sayım/pomodoro durumu doğru görünür; dikeyde normal Clock Center akışı bozulmaz.
- **Model matrisi (limit dostu):** WP-23 | Claude Sonnet 5 high / GPT-5.6 Terra high / Gemini 3.5 Flash high
- **Efor:** Orta-yüksek; çoğunluk UI/responsive, düşük DB riski.

### WP-24: Alarm + Çoklu Timer Temeli ⏲️
- **Durum:** [ ] Bekliyor
- **Backlog:** V5 Saat uygulaması yerini alma fazı
- **Kapsam:** Google/Samsung Clock ve MultiTimer çizgisinde, çalışma uygulamasını bozmadan kişisel alarm ve çoklu timer altyapısını kur. İlk teslim yerel/offline çalışır; Supabase sync ve sleep tracking yok.
- **SAHİP dosyalar:**
  - `app/lib/data/models/alarm_rule.dart` (yeni)
  - `app/lib/data/models/timer_preset.dart` (yeni)
  - `app/lib/data/repositories/alarm_repository.dart` (yeni)
  - `app/lib/data/repositories/in_memory/in_memory_alarm_repository.dart` (yeni)
  - `app/lib/data/repositories/local/local_alarm_repository.dart` (yeni)
  - `app/lib/data/providers/alarm_providers.dart` (yeni)
  - `app/lib/core/notifications/alarm_notification_service.dart` (yeni)
  - `app/lib/features/clock/alarms_screen.dart` (yeni)
  - `app/lib/features/clock/timers_screen.dart` (yeni)
  - `app/test/data/alarm_repository_test.dart` (yeni)
  - `app/test/features/alarms_screen_test.dart` (yeni)
- **DOKUNMA:**
  - `app/lib/data/providers/study_providers.dart` (yalnız gerekiyorsa sonraki entegrasyon WP'si)
  - `app/lib/core/notifications/timer_notification_service.dart` (mevcut çalışma sayacı bildirimi ayrı kalsın)
  - `app/android/**` (exact alarm izinleri ayrı native WP'ye bırakılır)
  - `supabase/migrations/**`
- **Adımlar:**
  - [ ] Alarm modeli: saat/dakika, gün tekrarı, tek tarih, etiket, aktif/pasif, snooze süresi, kademeli ses seçeneği alanlarını tanımla.
  - [ ] Çoklu timer modeli: etiket, renk/ikon, süre, kalan süre, running/paused/done, preset ve recent timer mantığını kur.
  - [ ] Local repository + in-memory test double yaz; `SharedPreferences` veya mevcut prefs altyapısıyla cihazda kalıcı tut.
  - [ ] Alarm ve Timers ekranlarını ekle: hızlı alarm, preset timer, aynı anda çoklu timer, pause/resume/reset/delete.
  - [ ] `AlarmNotificationService` ile alarm/timer bitiş bildirimlerini çalışma sayacı bildiriminden ayrı kanal ve sade aksiyonlarla hazırla.
  - [ ] Repository ve ekran testleri ekle; alarm verisinin Supabase'e gitmediğini ve normal çalışma oturumlarını etkilemediğini doğrula.
- **Tuzaklar:**
  - Android exact alarm / arka plan garanti davranışı platform izni ister; bu WP'de native izin eklenmez, sonraki WP'de ele alınır.
  - Alarmy tarzı görevli alarm/anti-snooze ilk teslimde yok; önce güvenilir temel.
  - Çoklu timer ile çalışma timer'ı aynı state machine'e zorla sokulmaz; çakışma olmaması için ayrı provider ailesi tercih edilir.
- **Kabul:** Kullanıcı birden fazla timer'ı etiketli/presetli çalıştırabilir, alarm oluşturup aç/kapatabilir; uygulama yeniden açıldığında yerel durum korunur; testler geçer.
- **Model matrisi (limit dostu):** WP-24 | Claude Sonnet 5 high / GPT-5.6 Terra high / Gemini 3.1 Pro medium
- **Efor:** Yüksek; veri modeli + yerel kalıcılık + notification davranışı var.


### WP-26: Tema Paleti Genişletme + 3 Custom Slot 🎨
- **Durum:** [ ] Bekliyor
- **Backlog:** Mevcut renk paletleri yeterince iyi hissettirmiyor; daha fazla hazır seçenek ve kullanıcıya özel renk seçimi
- **Kapsam:** Görünüm ayarlarında daha profesyonel hazır paletler ekle ve 3 adet kullanıcı tanımlı custom palet slotu sun. Kullanıcı her slotta primary/accent ve gerekirse onPrimary/onAccent renklerini seçip kalıcı kaydedebilmeli. Supabase sync yok; cihazda kalıcı ayar yeterli.
- **SAHİP dosyalar:**
  - `app/lib/core/theme/app_theme.dart`
  - `app/lib/core/theme/theme_settings.dart`
  - `app/lib/features/profile/appearance_screen.dart`
  - `app/lib/features/profile/widgets/custom_palette_editor.dart` (yeni)
  - `app/test/core/theme_settings_test.dart` (yeni veya mevcutsa güncelle)
  - `app/test/features/appearance_screen_test.dart` (yeni veya mevcutsa güncelle)
- **DOKUNMA:**
  - `app/lib/features/classroom/**`
  - `app/lib/features/home/**`
  - `app/lib/data/providers/study_providers.dart`
  - `app/android/**`
  - `supabase/migrations/**`
- **Adımlar:**
  - [ ] Hazır palet sayısını artır: mevcut 5 palete ek olarak en az 6 yeni dengeli seçenek ekle (örn. Slate Mint, Rose Noir, Cyber Blue, Forest, Cream Coffee, Mono Amber). İsimler Türkçe ve kullanıcı dostu olsun.
  - [ ] `AppPalette` modelini custom paletleri de temsil edecek şekilde genişlet; eski `theme_palette` id'leri bozulmadan geriye uyumlu kalsın.
  - [ ] `ThemeSettingsNotifier` içinde 3 custom slotu `SharedPreferences` ile sakla (`custom_palette_1/2/3` gibi); geçersiz renk/eksik slot durumunda güvenli varsayılana düş.
  - [ ] Görünüm ekranında hazır paletleri daha iyi önizleme kartlarıyla göster; custom slotlarda “Düzenle / Uygula / Sıfırla” akışı ekle.
  - [ ] Basit color picker UI kur: hex girişi + renk önizleme + önerilen kontrast/on renk otomatik seçimi. Ağır paket ekleme gerekiyorsa önce mevcut Flutter bileşenleriyle çöz.
  - [ ] Kontrast tuzağına karşı `onPrimary/onAccent` için siyah/beyaz otomatik seçim veya kullanıcı override'ı sağla.
  - [ ] Tema ayarı testleri: eski palet id'si çalışır, custom slot kaydedilir/yüklenir, bozuk hex varsayılana döner, AppearanceScreen custom slotları render eder.
- **Tuzaklar:**
  - Kullanıcı okunamaz renk seçerse buton/text kontrastı bozulabilir; otomatik `on` renk hesaplaması şart.
  - Mevcut palet id'leri (`navy`, `purple`, `emerald`, `sunset`, `ocean`) değişmemeli; eski kullanıcı ayarı kırılmasın.
  - Custom paletler yerel cihaz ayarıdır; hesaplar arası sync bu WP'nin dışında.
  - `appearance_screen.dart` WP-19 ayarlar entegrasyonu ile aynı dosyaya doğrudan çakışmaz ama aynı anda çalışan ajan varsa status kontrolü yapılmalı.
- **Kabul:** Kullanıcı 10+ hazır paletten seçim yapabilir, 3 custom slotu düzenleyip kalıcı kullanabilir; uygulama yeniden açıldığında custom palet korunur; seçilen renklerde temel kontrast okunabilir kalır; tema ve appearance testleri geçer.
- **Model matrisi (limit dostu):** WP-26 | Claude Sonnet 5 medium / GPT-5.6 Terra medium / Gemini 3.5 Flash medium
- **Efor:** Orta; tema modeli + ayar UI + test, DB/native riski yok.

### Windows Desktop Faz Notu 🖥️
- **Durum:** İlk EXE Claude tarafından derlendi; mevcut Windows uygulaması işlevsel ama görsel/etkileşim olarak mobil app'in büyük ekrana taşınmış hali.
- **Ürün yönü:** Windows sürümü ayrı bir masaüstü deneyimi gibi davranmalı: solda kalıcı navigasyon/rail, geniş içerik alanı, pencere boyutuna duyarlı master-detail yerleşimler, klavye/fare rahatlığı ve mini/always-on-top akışı.
- **Karar:** Mobil `NavigationBar` Windows'ta ana navigasyon olmamalı. Desktop genişliğinde `NavigationRail` veya sol sidebar kullanılacak; mobile/tablet davranışı korunacak.
- **Çakışma kontrolü:** WP-27 `HomeShell` ve bazı ekran düzenlerine dokunur; WP-19/WP-23/WP-25 aynı anda aktifse sıraya alınmalı. WP-28 daha çok Windows dağıtım/QA dosyalarına dokunur ve WP-27 sonrasında anlamlıdır.

### WP-27: Windows Desktop Shell & Responsive Layout 🪟
- **Durum:** [ ] Bekliyor — WP-19/WP-23/WP-25 ile `HomeShell` çakışması kontrol edilmeli
- **Backlog:** Windows app mobil build gibi duruyor; masaüstüne özel tasarım gerekiyor
- **Kapsam:** Windows geniş ekranlarda mobil alt sekme navigasyonunu kaldırıp sol navigation rail/sidebar + geniş dashboard deneyimi kur. Mevcut Android/mobil davranışı bozulmaz; breakpoint ile platform/genişlik bazlı ayrım yapılır.
- **SAHİP dosyalar:**
  - `app/lib/core/navigation/home_shell.dart`
  - `app/lib/core/desktop/desktop_breakpoints.dart` (yeni, gerekirse)
  - `app/lib/features/home/home_screen.dart`
  - `app/lib/features/classroom/classroom_screen.dart`
  - `app/lib/features/stats/stats_screen.dart`
  - `app/lib/features/profile/profile_screen.dart`
  - `app/test/features/desktop_shell_test.dart` (yeni)
- **DOKUNMA:**
  - `app/android/**`
  - `supabase/migrations/**`
  - `app/lib/data/repositories/**`
  - `app/lib/data/providers/study_providers.dart`
  - `app/lib/core/notifications/**`
  - `app/windows/**` (WP-28 alanı; yalnız okunur)
- **Adımlar:**
  - [ ] Desktop breakpoint helper'ı belirle: Windows/macOS/Linux veya genişlik >= ~900 px olduğunda desktop shell.
  - [ ] `HomeShell` içinde mobile `NavigationBar`, desktop `NavigationRail`/sidebar olacak responsive yapı kur; mevcut `IndexedStack`, presence/nudge/device listener davranışı korunur.
  - [ ] Desktop sidebar'a uygulama başlığı, aktif grup/sayaç kısa durumu ve ana sekmeler ekle; mobile alt bar aynen kalsın.
  - [ ] Home/Classroom/Stats/Profile ekranlarında geniş ekranda tek kolon mobil hissini azalt: max content width, iki kolon/side panel veya daha rahat boşluklandırma stratejisi uygula.
  - [ ] Mini pencere modunda sidebar otomatik gizlenmeli veya compact rail'e düşmeli; 320 px mini pencere hâlâ kullanılabilir kalmalı.
  - [ ] Widget testlerinde 390 px mobile alt bar, 1100 px desktop rail görünürlüğü ve mini genişlik compact davranışı doğrula.
- **Tuzaklar:**
  - Platformu sadece `defaultTargetPlatform.windows` ile kilitleme; web/desktop geniş ekranlarda da breakpoint mantığı kullanılabilir ama Android tabletin davranışı ayrıca düşünülmeli.
  - `HomeShell` WP-19/WP-23/WP-25 ile ortak dosya; aynı anda verilirse çakışır.
  - Desktop rail, ekran içeriklerini sıkıştırıp dashboard kart taşmalarını artırmamalı.
- **Kabul:** Windows 1100×720 boyutta sol navigasyonlu gerçek desktop shell görünür; mobilde alt navigation davranışı korunur; mini pencere okunabilir kalır; desktop shell testleri geçer.
- **Model matrisi (limit dostu):** WP-27 | Claude Sonnet 5 high / GPT-5.6 Terra high / Gemini 3.5 Flash medium
- **Efor:** Yüksek; ortak shell ve ana ekranların responsive davranışı var.

### WP-28: Windows Distribution & Desktop Polish 📦
- **Durum:** [ ] Bekliyor — WP-27 sonrası önerilir
- **Backlog:** Windows kurulum paketi + dağıtım ve desktop kalite cilası
- **Kapsam:** İlk EXE'nin ötesinde Windows'a yakışır dağıtım ve pencere davranışı: ikon/metadata, installer notları, pencere durum kalıcılığı, updater stratejisi ve QA checklist. UI shell tasarımı WP-27'nin alanıdır.
- **SAHİP dosyalar:**
  - `app/windows/DAGITIM.md`
  - `app/windows/runner/main.cpp`
  - `app/windows/runner/Runner.rc`
  - `app/windows/runner/resources/**` (ikon/asset gerekiyorsa)
  - `.github/workflows/release.yml`
  - `app/lib/core/desktop/desktop_window.dart`
  - `app/lib/core/desktop/desktop_window_io.dart`
  - `app/lib/core/desktop/desktop_window_stub.dart`
  - `app/test/core/desktop_window_test.dart` (yeni, mümkünse)
- **DOKUNMA:**
  - `app/lib/core/navigation/home_shell.dart` (WP-27 alanı; yalnız gerekirse küçük bağlantı)
  - `app/lib/features/home/**`, `classroom/**`, `stats/**`, `profile/**` UI yeniden tasarımı
  - `app/android/**`
  - `supabase/migrations/**`
- **Adımlar:**
  - [ ] Windows app metadata/ikon/başlık durumunu doğrula; EXE'nin kullanıcıya görünen adı Odak Kampı olmalı.
  - [ ] Pencere boyutu/konumu/mini-pencere state'i için yerel kalıcılık planla veya uygula; mini mode ile full mode arasında güvenli geçiş.
  - [ ] Windows build ve release workflow'unu netleştir: artifact adı, zip/installer çıktısı, beta/stable kanalıyla ilişkisi.
  - [ ] `DAGITIM.md`'yi gerçek build komutları, imzalama/unsigned uyarısı, Windows SmartScreen beklentisi ve test checklist ile güncelle.
  - [ ] Windows updater konusu için karar ver: ilk faz manuel zip/installer mı, yoksa GitHub Releases kontrolü sonraki WP mi?
  - [ ] Visual Studio yüklü ortamda `flutter build windows --release --dart-define-from-file=env.json` ve smoke test notunu kaydet.
- **Tuzaklar:**
  - Bu makinede Visual Studio yoksa Windows build doğrulaması yerel yapılamaz; CI/VS'li makine gerekir.
  - `window_manager` generated dosyaları başka ajanlarca silinmişse commit'e karışmamalı; `flutter pub get` sonrası generated dosyalar dikkatle kontrol edilir.
  - Otomatik updater Windows için Android APK updater ile aynı değildir; yanlış söz vermemek lazım.
- **Kabul:** Windows release artifact üretim yolu belgelenir ve mümkünse CI/VS'li ortamda doğrulanır; EXE adı/ikon/pencere davranışı düzgünleşir; mobil/Android build etkilenmez.
- **Model matrisi (limit dostu):** WP-28 | Claude Sonnet 5 medium / GPT-5.6 Terra medium / Gemini 3.5 Flash medium
- **Efor:** Orta-yüksek; dağıtım/CI/desktop API riski var.



### WP-29: Stable/Beta App Icon & Branding Refresh 🔥 — 2026-07-11 ✅
- **Değişen dosyalar:** `app/android/app/src/stable/res/mipmap-*`, `app/android/app/src/beta/res/mipmap-*`, `app/generate_icons.py`, `app/windows/runner/resources/app_icon.ico`, `docs/DAGITIM.md`.
- **Ne yapıldı:** Python (Pillow) ile Android (Stable ve Beta) adaptive/launcher ikonları üretilip ilgili flavor (source-set) dizinlerine yerleştirildi. Beta sürüm için ayırt edici renk (turuncu zemin) ve kırmızı 'BETA' şeridi uygulandı. Windows dağıtımı için `app_icon.ico` eklendi.
- **Test:** Flavor (beta/stable) derlemesi hatasız. Adaptive icon XML'leri kuruldu.

### WP-25: Android 3 Tuşlu Navigasyon Safe Area QA 📱 — 2026-07-11 ✅
- **Değişen dosyalar:** `app/lib/core/widgets/safe_screen_padding.dart`, `app/lib/features/classroom/widgets/class_chat_screen.dart`, `app/lib/features/profile/settings_screen.dart`, `app/lib/features/home/home_screen.dart`, `app/lib/features/profile/profile_screen.dart`, `app/lib/features/classroom/classroom_screen.dart`, `app/lib/features/stats/widgets/class_stats_view.dart`, `app/lib/features/stats/widgets/personal_stats_view.dart`, `app/test/features/safe_area_padding_test.dart`.
- **Ne yapıldı:** Android'deki 3-tuşlu veya gesture navigasyon sistem barları ile oluşabilecek padding sorunları çözüldü. Sistem barı yüksekliğini hesaba katarak ListView'lerin ve bottom alanların güvenli alanda çizilmesi (`getSafeVerticalPadding`) sağlandı.
- **Test:** Widget testi (`safe_area_padding_test.dart`) ile `viewPadding.bottom` simüle edildi. `flutter test` başarıyla geçti.

### WP-29: Stable/Beta App Icon & Branding Refresh 🔥 — 2026-07-11 ✅
- **Ne yapıldı:** Python (Pillow) ile Android (Stable ve Beta) adaptive/launcher ikonları üretilip ilgili flavor (source-set) dizinlerine yerleştirildi. Beta sürüm için ayırt edici renk (turuncu zemin) ve kırmızı 'BETA' şeridi uygulandı. Windows dağıtımı için pp_icon.ico eklendi.
- **Test:** Flavor (beta/stable) derlemesi hatasız. Adaptive icon XML'leri kuruldu.


### WP-19: Device Integrations Settings Hook (Tamamlandı)
- **Kapsam:** Cihaz uygulama kısayollarının (Rutinler/Tasker vb.) ayarlar menüsüne bağlanması ve App Intent'lerinin (başlat, durdur vb.) Flutter state'ine (Riverpod) entegre edilmesi.
- **Detay:** `deviceIntegrationListenerProvider` ile App Shortcut'lardan gelen (soğuk/sıcak) aksiyonlar dinlenip `studyTimerProvider` ve `navIndexProvider` tetiklendi. `SettingsScreen`'e entegrasyon sekmesi eklendi ve testleri güncellendi.


> Son 5 iş. Ajan bunları okuyarak "neye dokunma, ne değişti" anlar.
> Daha eski işler aşağıdaki Geçmiş tablosuna düşer.

### WP-14: Güvenli Admin ve Geri Bildirim Temeli 🛡️ — 2026-07-11 ✅
- **Değişen dosyalar:** `supabase/migrations/0018_admin_feedback.sql`, `app/lib/data/models/feedback_ticket.dart`, `app/lib/data/repositories/admin_repository.dart`, `app/lib/data/repositories/in_memory/in_memory_admin_repository.dart`, `app/lib/data/repositories/supabase/supabase_admin_repository.dart`, `app/lib/data/providers/admin_providers.dart`, `app/lib/features/admin/admin_screen.dart`, `app/lib/features/profile/widgets/report_issue_dialog.dart`, `app/lib/features/profile/settings_screen.dart`, `app/test/data/admin_repository_test.dart`, `app/test/features/admin_screen_test.dart`, `app/test/features/settings_screen_test.dart`.
- **Ne yapıldı:** `app_admins` ve `feedback_tickets` için güvenli migration eklendi; `is_super_admin()`, admin özet/rapor listeleme ve rapor durum güncelleme RPC'leri `SECURITY DEFINER` + `set search_path=public` ile kuruldu. Normal kullanıcı yalnız kendi raporunu oluşturup takip eder; süper-admin tüm raporları ve salt-okunur özetleri görür.
- **UI:** Ayarlar ekranına `Geri bildirim gönder` eklendi; admin rolü varsa `Yönetim` ekranı görünür. Yönetim ekranı kullanıcı/grup/oturum sayıları, açık rapor sayısı, rapor listesi ve durum güncellemesiyle sınırlıdır.
- **Güvenlik/kurulum:** İlk süper-admin UUID'si migration'a yazılmadı. Migration uygulandıktan sonra Supabase SQL Editor'da `insert into public.app_admins (user_id) values ('<auth.users.id>') on conflict (user_id) do nothing;` çalıştırılmalı. Flutter istemcisine `service_role`, kota API'si veya e-posta sırrı eklenmedi.
- **Test:** `dart analyze` WP-14 dosyaları için temiz. `flutter test test/data/admin_repository_test.dart test/features/admin_screen_test.dart test/features/settings_screen_test.dart --dart-define-from-file=env.json` geçti. Tam `flutter analyze`, WP-11 alanındaki çözülmemiş `window_manager` bağımlılığı ve kapsam dışı `test_download.dart` yüzünden kırmızı; WP-14 dosyalarından hata çıkmadı.
- **Dokunma:** Android/WP15 dosyaları, `auth_repository.dart`, `classroom/**`, `home/**`, `main.dart`, `home_shell.dart` ve eski migration'lar (`0001`…`0017`) değiştirilmedi.

### WP-11: Windows Desktop Track 🖥️ — 2026-07-11 ✅
- **Değişen dosyalar:** `app/lib/main.dart`, `app/lib/core/desktop/desktop_window.dart` + `desktop_window_io.dart` + `desktop_window_stub.dart` (yeni), `app/windows/runner/main.cpp`, `app/windows/DAGITIM.md` (yeni), `app/windows/flutter/generated_plugin_registrant.cc` + `generated_plugins.cmake`, `app/pubspec.yaml` (`window_manager: ^0.4.3`).
- **Ne yapıldı:** Masaüstünde (Windows/macOS/Linux) `window_manager` ile pencere boyutu/başlığı ayarlanıyor; sağ üstte "her zaman üstte tut" (📌) ve "mini pencere" (🖼, ≈320×184 köşeye sabit, daima üstte) kontrolleri eklendi. Web/mobil güvenli: koşullu import (`dart.library.io`) sayesinde `window_manager` yalnız masaüstünde derlenir; platform ayrımı `defaultTargetPlatform` ile yapılır (dart:io yok).
- **Not:** Windows "widget" gerçek OS widget değil, üstte kalan mini Flutter penceresi olarak kaldı (planla uyumlu).
- **Test:** Dart tarafı `flutter analyze` temiz; `window_manager` eklendikten sonra Android debug APK derlendi. ⚠️ **Windows build bu makinede doğrulanmadı** (Visual Studio kurulu değil); ilk Windows derlemesi VS'li bir makinede/CI runner'da alınmalı. Detay: `app/windows/DAGITIM.md`.

### WP-13: Release Channels 🚦 — 2026-07-11 ✅
- **Değişen dosyalar:** `app/android/app/build.gradle.kts` (product flavors), `app/android/app/src/main/AndroidManifest.xml` (`${appName}` label), `app/lib/features/updater/updater_service.dart` (kanal mantığı), `.github/workflows/release.yml` (beta tetikleyici + flavor/prerelease meta), `app/pubspec.yaml` (versiyon).
- **Ne yapıldı:** İki kanallı yayın kuruldu. `stable` ve `beta` Android product flavor'ları; beta `applicationIdSuffix .beta` ile **ayrı uygulama** olarak kuruluyor (gerçek uygulamayla yan yana durur, imza çakışması olmaz), prerelease olarak yayınlanır. Updater `CHANNEL` dart-define'ına göre stable APK (`app-release.apk`) veya beta prerelease'i (`app-beta-release.apk`) arar. CI `v*` → stable, `beta-v*` → beta prerelease üretir; stable asset eski adıyla yeniden adlandırılıp mevcut kullanıcıların updater'ı bozulmadan korunur.
- **Kurallar korundu:** Build number = tag'deki tamsayı (pubspec `+N`'i ezer); tag tamsayı olmalı (`v3.1` geçersiz). `key.jks` yeniden üretilmedi.
- **Test:** `beta-v1` prerelease CI yeşil ve doğrulandı; beta APK ayrı paket olarak kuruldu. Ayrıca `v3` ve `v4` (panel düzeltmesiyle) stable sürümleri yayınlandı.

### WP-15: Device Integrations Spike — 2026-07-11 ✅
- **Değişen dosyalar:** `app/android/app/src/main/res/xml/shortcuts.xml` (yeni), `app/android/app/src/main/res/values/strings.xml` (yeni), `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/src/main/kotlin/com/manilmax/online_study_room/MainActivity.kt`, `app/lib/core/device_integrations/samsung_modes_service.dart` (yeni).
- **Ne yapıldı:** Samsung Modes & Routines ve Tasker gibi otomasyon uygulamalarıyla entegrasyon için en standart yöntem olan "App Shortcuts" (Uygulama Kısayolları) yaklaşımı spike edildi. Statik kısayollar (`shortcuts.xml`) eklendi. Samsung Rutinleri bu kısayolları doğrudan aksiyon olarak seçebilir. Tıklanan kısayollar `MainActivity` üzerinden `MethodChannel` aracılığıyla Flutter'daki izole `DeviceIntegrationService`'e iletiliyor.
- **Kararlar:** Özel izinler (DND vb.) gerektirmeden en güvenli yolun kısayollar üzerinden otomasyona "tetiklenebilir" bir API sunmak olduğuna karar verildi. Flutter tarafında UI ve State bağlaması (Timer'ı başlatma/durdurma) bir sonraki faz olan WP-19'a bırakıldı.
- **Dokunma:** `settings_screen.dart`, `study_providers.dart` ve hiçbir UI dosyasına dokunulmadı.
- **Test:** Sadece izole servis ve native kod eklendi, derleme kontrol edildi.

### WP-12: Sync & Offline Track 📴 — 2026-07-11 ✅
- **Değişen dosyalar:** `app/lib/data/providers/offline_providers.dart`, `app/lib/data/providers/study_providers.dart`, `app/lib/data/providers/presence_providers.dart`, `app/test/data/offline_first_repository_test.dart`
- **Ne yapıldı:** Study ve presence repository provider'ları offline-first cache wrapper ile sarıldı. Supabase instance hazırsa remote katman Supabase kullanılıyor, hazır değilse güvenli bellek-içi remote ile aynı wrapper devam ediyor. Cache fallback ve pending flush akışları provider seviyesine bağlandı.
- **Test:** `dart analyze lib/data/providers/offline_providers.dart lib/data/providers/study_providers.dart lib/data/providers/presence_providers.dart test/data/offline_first_repository_test.dart` temiz. `flutter test test/data/offline_first_repository_test.dart --dart-define-from-file=env.json` geçti.
- **Dokunma:** `app/lib/data/repositories/auth_repository.dart`, `app/lib/features/classroom/**`, `app/lib/features/home/**`, `app/android/**`, `supabase/migrations/**`

### WP-16: Dashboard Advanced Polish 🧩 — 2026-07-11 ✅
- **Değişen dosyalar:** `app/lib/features/home/widgets/group_card_shell.dart`, `app/lib/features/home/widgets/group_goal_card.dart`, `app/lib/features/home/widgets/group_trend_card.dart`, `app/lib/features/home/widgets/leaderboard_card.dart`, `app/lib/features/home/widgets/active_members_card.dart`, `app/lib/features/profile/profile_screen.dart`, `app/test/features/dashboard_cards_render_test.dart`, `app/test/widget_test.dart`
- **Ne yapıldı:** Grup kartlarının boş halleri eylemli hale getirildi; `Grup oluştur` / `Koda katıl` kısayolları eklendi. Profil ekranına aktif grup özeti ve `Grup değiştir` aksiyonu kondu. Dashboard kartlarının boş-durum UX'i ve profil entegrasyonu render/widget testleriyle doğrulandı.
- **Test:** `dart analyze` bu WP dosyaları için temiz. `flutter test test\features\dashboard_cards_render_test.dart test\widget_test.dart --dart-define-from-file=env.json` geçti. `flutter analyze` hâlâ WP-18 alanındaki `test\features\settings_screen_test.dart:19` `overrideWithValue` hatası nedeniyle kırmızı.
- **Dokunma:** `app/lib/features/classroom/**`, `app/lib/features/profile/settings_screen.dart`, `app/android/**`, `supabase/migrations/**`

### WP-17: Android Canlı Sayaç Yüzeyleri 📱 — 2026-07-11 ✅
- **Değişen dosyalar:** `core/notifications/timer_external_command_store.dart`, `core/notifications/timer_notification_service.dart`, `data/providers/study_providers.dart`, `features/android_widgets/android_widget_service.dart`, `AndroidManifest.xml`, `StudyWidgetProviders.kt`, `TimerActionReceiver.kt`, `odak_*_widget_info.xml`.
- **Ne yapıldı:** Widget ve kalıcı bildirimler interaktif hale getirildi. Arka planda timer başlat/durdur özellikleri eklendi. Widget tıklamaları için `TimerActionReceiver` aracılığıyla `SharedPreferences` kullanıldı. Uygulama resume edildiğinde komut deposu üzerinden timer güncelleniyor. Widget seçici için önizlemeler (`previewLayout`) eklendi.
- **Test:** Flutter testleri güncellendi, derleme hataları düzeltildi.
- **Dokunma:** Diğer ekranlara veya UI'ye dokunulmadı.

### WP-18: Grup Ekranı Hiyerarşisi ve Ayar Sadeleştirmesi 🏕️ — 2026-07-11 ✅
- **Değişen dosyalar:** `features/classroom/classroom_screen.dart`, `features/profile/settings_screen.dart`, test dosyaları.
- **Ne yapıldı:** Sınıf ekranı hiyerarşisi (Grup hedefi → Kamp ateşi → Trend) olacak şekilde yeniden düzenlendi, üst kısımdaki büyük grup bilgileri küçültülerek başlığa taşındı. Ayarlar menüsünden gereksiz Sayaç kısmı kaldırıldı.
- **Test:** Düzenlemeler için ilgili widget testleri yazıldı ve doğrulandı.

### WP-10: Class Metrics Pack — 2026-07-10 ✅
- **Değişen dosyalar:** `core/stats/study_stats.dart` (+`totalOfDayTotals`/`activeDayCount`/`peakDay`), `features/stats/widgets/class_stats_view.dart`, `test/core/study_stats_test.dart`
- **Ne yapıldı:** Grup istatistik sekmesine tüm-zamanlar metrikleri eklendi. Dönem seçicisine **"Tümü"** dönemi (leaderboard/tablo/özet tüm-zamanları kapsar). Yeni **"Grup eğilimi (son 30 gün)" çizgi grafiği** (mevcut 7 günlük çubuğa ek, `DailyLineChart` yeniden kullanıldı). Yeni **"Tüm zamanlar" kartı:** grup toplamı, aktif gün sayısı, grup rekor serisi, en yoğun gün (tarih+süre), en istikrarlı üye (en uzun ardışık çalışma serisi). Metrikler saf fonksiyonlarla (`Map<DateTime,int>` üzerinde) hesaplanır — hem grup hem kişi için kullanılabilir.
- **Kararlar:** **Migration gerekmedi** — `group_daily_totals` RPC zaten tüm-zamanlar (pencere sınırsız) per-user-per-gün veriyi döndürüyor; tüm-zamanlar metrikleri istemci tarafında `DailyStat` agregasyonuyla hesaplanır. Grup metrikleri üyelik join'iyle (RPC) gelir; `study_sessions.group_id` geri getirilmedi.
- **Dokunma:** auth/profile/native Android, dashboard/home kartları (WP-16/WP-4), classroom/campfire. Codex'in v3 hazırlık/WP dosyalarına dokunulmadı.
- **Test:** `flutter analyze` tüm proje temiz. `flutter test --concurrency=1 --dart-define-from-file=env.json` 203 test geçti (tüm-zamanlar metrikleri için 4 yeni birim testi dahil). Grup stats görünümü test-render PNG'siyle taşmasız doğrulandı.

### WP-9: Gamification — 2026-07-10 ✅
- **Değişen dosyalar:** yeni `app/lib/core/stats/gamification.dart`, yeni `app/lib/data/models/gamification_profile.dart`, yeni `gamification_repository` çift implementasyonu, yeni `app/lib/data/providers/gamification_providers.dart`, `app/lib/features/profile/profile_screen.dart`, yeni `app/lib/features/profile/widgets/gamification_card.dart`, yeni gamification testleri, yeni `supabase/migrations/0017_gamification_profiles.sql`
- **Ne yapıldı:** Profil ekranına Başarılar paneli eklendi. Seri koruma hakkı, freeze-aware seri özeti, türetilmiş başarımlar ve taç seviyesi oturum istatistiklerinden hesaplanıyor. Gamification cüzdanında kalıcı `streak_freezes` tutuluyor; başarımlar tabloya yazılmıyor.
- **Güvenlik:** `0017_gamification_profiles.sql` kullanıcının yalnız kendi gamification cüzdanını okumasına/yazmasına izin veren RLS politikaları kurar ve yeni kullanıcı için varsayılan 1 seri koruma hakkı üretir.
- **Dokunma:** Android widget/native, auth recovery, timer state machine. Claude'un kamp ateşi dosyaları ve `zz_*` görsel testleri commit'e alınmadı.
- **Test:** `flutter analyze` temiz. `flutter test --concurrency=1 --dart-define-from-file=env.json` 199 test geçti. `ANDROID_HOME=C:\Android\Sdk` ve `ANDROID_SDK_ROOT=C:\Android\Sdk` ile `flutter build apk --debug --dart-define-from-file=env.json` geçti.

### WP-8: Nudge + Notifications — 2026-07-10 ✅
- **Değişen dosyalar:** yeni `app/lib/data/models/nudge.dart`, yeni `nudge_repository` çift implementasyonu, yeni `nudge_providers.dart`, yeni `nudge_notification_listener.dart`, yeni `core/notifications/nudge_notification_service.dart`, yeni `core/notifications/notification_preferences.dart`, `core/navigation/home_shell.dart`, `features/classroom/widgets/class_detail_screen.dart`, `features/profile/settings_screen.dart`, yeni nudge/preference testleri, yeni `supabase/migrations/0016_nudges.sql`
- **Ne yapıldı:** Sınıf üye listesine `Dürt` aksiyonu eklendi. Gelen dürtmeler uygulama açıkken yerel Android bildirimi olarak gösterilir; Ayarlar > Bildirimler altında dürtme bildirimleri aç/kapat tercihi kalıcı hale geldi.
- **Güvenlik:** `0016_nudges.sql` doğrudan insert/update policy açmaz; yazma `send_nudge` ve `mark_nudge_read` SECURITY DEFINER RPC'lerinden geçer. RPC aktif grup üyeliğini, self-send engelini ve aynı alıcıya 10 dakika cooldown'u DB tarafında zorlar.
- **Dokunma:** timer state machine, Android widget/native dosyaları, auth recovery. Claude'un `camp_critter.dart` değişikliği commit'e alınmadı.
- **Test:** `flutter analyze` temiz. `flutter test --concurrency=1 --dart-define-from-file=env.json` 194 test geçti. `ANDROID_HOME=C:\Android\Sdk` ve `ANDROID_SDK_ROOT=C:\Android\Sdk` ile `flutter build apk --debug --dart-define-from-file=env.json` geçti.

### WP-7: Class Chat — 2026-07-10 ✅
- **Değişen dosyalar:** yeni `app/lib/data/models/chat_message.dart`, yeni `app/lib/data/repositories/chat_repository.dart`, yeni `in_memory/supabase` chat repository implementasyonları, yeni `app/lib/data/providers/chat_providers.dart`, yeni `app/lib/features/classroom/widgets/class_chat_card.dart`, `app/lib/features/classroom/widgets/class_detail_screen.dart`, yeni `app/test/data/chat_repository_test.dart`, yeni `supabase/migrations/0015_class_chat.sql`
- **Ne yapıldı:** Sınıf detayındaki "Yakında" sohbet alanı gerçek canlı sohbet kartına çevrildi. Mesajlar grup bazında stream edilir, bellek-içi mod demo/test için çalışır, Supabase modunda mesajlar `class_messages` tablosundan gelir ve profil adı/avatar bilgisi hydrate edilir. Boş ve 500 karakter üstü mesajlar reddedilir.
- **Güvenlik:** `0015_class_chat.sql` `class_messages` tablosunu RLS ile açar; `select` ve `insert` yalnız `public.is_group_member(group_id)` sağlayan aktif grup üyelerine izin verir. `insert` ayrıca `user_id = auth.uid()` zorlar.
- **Dokunma:** timer state machine, Android widget/native dosyaları, `profile/*`, `auth*`.
- **Test:** `flutter analyze` temiz. `flutter test --concurrency=1 --dart-define-from-file=env.json` 190 test geçti. `ANDROID_HOME=C:\Android\Sdk` ve `ANDROID_SDK_ROOT=C:\Android\Sdk` ile `flutter build apk --debug --dart-define-from-file=env.json` geçti.

### WP-6: Android Surface Extensions — 2026-07-10 ✅
- **Değişen dosyalar:** `app/lib/core/notifications/timer_notification_service.dart`, `app/lib/data/providers/study_providers.dart`, `app/lib/features/android_widgets/android_widget_service.dart`, `app/test/core/timer_notification_service_test.dart`, `app/test/features/android_widget_service_test.dart`, `app/test/features/timer_state_machine_test.dart`
- **Ne yapıldı:** Android sayaç bildirimi hedefli modlarda progress bar gösterecek şekilde genişletildi; bildirim `public` lock-screen visibility, phase subText ve ticker bilgisiyle kilit ekranında/durum yüzeylerinde daha anlamlı hale geldi. Timer start/restore/faz geçişi/durdurma akışı Android timer widget verisini güncelliyor; hedefli sayaçlarda widget kalan süreyi, kronometrede geçen süreyi gösteriyor.
- **Kararlar:** Android 16 "Live Updates" ayrı bir Flutter API'siyle uygulanmadı; mevcut `flutter_local_notifications` altyapısı üzerinde progress-centric ongoing notification fallback'i seçildi. "Kilit ekranı widget'ı" Android telefonlarda modern API olarak widget değil, kilit ekranında görünür ongoing notification davranışıyla karşılandı.
- **Dokunma:** `classroom/*`, `profile/*`, `auth*`, Supabase migration dosyaları.
- **Test:** `flutter analyze` temiz. `flutter test --concurrency=1 --dart-define-from-file=env.json` 187 test geçti. `ANDROID_HOME=C:\Android\Sdk` ve `ANDROID_SDK_ROOT=C:\Android\Sdk` ile `flutter build apk --debug --dart-define-from-file=env.json` geçti.

### WP-5: Presence Lifecycle — 2026-07-10 ✅
- **Değişen dosyalar:** `data/models/presence.dart` (+`updatedAt`), `data/providers/presence_providers.dart` (bayatlama + periyodik yeniden değerlendirme), yeni `data/providers/presence_lifecycle.dart` (heartbeat + `WidgetsBindingObserver`), `core/navigation/home_shell.dart` (tek satır aktivasyon), `test/data/presence_repository_test.dart`
- **Ne yapıldı:** Çevrimdışı tespiti + heartbeat. Sayaç yalnız başlat/faz/durdur anında presence yazdığından uzun oturumda satır bayatlıyor, uygulama öldürülünce karşı taraf "hayalet çalışıyor" görüyordu. `PresenceLifecycle` denetleyicisi (kabuk izler) çalışma sürerken 20sn'de bir presence'ı yeniden yazıp sunucu `updated_at`'ini tazeler ve uygulama öne gelince (`resumed`) hemen bir kez tazeler. Okuma tarafı `applyPresenceStaleness` ile `updated_at`'i 70sn'den eski `studying/onBreak` satırları **çevrimdışı** gösterir; `groupPresenceProvider` DB değişmese de 20sn'de bir yeniden değerlendirir. `Presence` modeline `updatedAt` eklendi (`fromMap` `updated_at` okur). **Migration gerekmedi** — `presence.updated_at` zaten 0001'de var ve her upsert tazeliyor.
- **Kararlar:** `groupPresenceProvider` `StreamProvider` olarak KALDI (Provider'a çevrilseydi `overrideWith(Stream...)` kullanan campfire/render testleri kırılırdı). `updatedAt` null (bellek-içi/eski satır) ise durum korunur → yanlış çevrimdışı yok. Heartbeat "yangına-at-unut".
- **Dokunma:** `study_providers.dart` (sayaç state machine — yalnız OKUNDU), timer widget'ları, `profile/*`, `auth*`, Codex'in WP-2/WP-3 dosyaları.
- **Test:** `flutter analyze` tüm proje temiz. `flutter test --concurrency=1 --dart-define-from-file=env.json` 185 test geçti (presence bayatlama için 5 yeni birim testi dahil).

### WP-4: Home Responsive QA — 2026-07-10 ✅
- **Değişen dosyalar:** `home/widgets/today_summary_card.dart`, `home/widgets/leaderboard_card.dart`, `home/widgets/active_members_card.dart`, `test/features/dashboard_cards_render_test.dart`
- **Ne yapıldı:** 2E'de `CardScaffold`'a taşınMAYAN 3 kart (bugün özeti, sıralama, aktif üyeler) çok kısa hücrede (telefonda tam genişlik + `h=1` ≈ 328×48) taşıyordu. Bu kartlara yükseklik-tabanlı doldur/kaydır geri düşüşü eklendi: başlık + en az bir satır sığmıyorsa `Expanded` yerine düz `Column` + dış `SingleChildScrollView` (taşma yok). Ayrıca kart başlıkları `Flexible/Expanded`+ellipsis'e, dar hücrede satır sonundaki süre/saniye metni `FittedBox(scaleDown)`'a alındı (yatay taşma yok). Render testi: `null` grup yerine gerçek grup+üye+presence+günlük istatistikle çizen ayrı grup-kartı grubu + `kisa` (328×48) boyutu eklendi.
- **Dokunma:** `classroom/*`, `profile/*`, `dashboard_providers.dart`, `dashboard_card.dart`, diğer `home/widgets/*` kartları. Codex'in WP-2/WP-3 dosyalarına dokunulmadı.
- **Test:** WP-4 dosyaları `flutter analyze` temiz; `dashboard_cards_render_test.dart` 76 test (45→76) geçiyor. Grup-kartı yolu ilk kez render-test kapsamına alındı; iki gizli yatay taşma (aktif üyeler + sıralama başlığı/satırı) yakalanıp düzeltildi.

### WP-3: Auth Recovery — 2026-07-10 ✅
- **Değişen dosyalar:** `data/repositories/auth_repository.dart`, `data/repositories/in_memory/in_memory_auth_repository.dart`, `data/repositories/supabase/supabase_auth_repository.dart`, `features/auth/auth_screen.dart`, `test/data/auth_repository_test.dart`, `test/widget_test.dart`
- **Ne yapıldı:** Auth repository arayüzüne `sendPasswordResetEmail` eklendi. Supabase implementasyonu `resetPasswordForEmail` çağırıyor; in-memory implementasyon hesap var/yok bilgisi sızdırmadan geçerli e-posta kabul ediyor. Giriş ekranına `Şifremi unuttum` akışı ve kayıt sonrası e-posta doğrulama bilgi mesajı eklendi.
- **Dokunma:** `classroom/*`, `home/*`, Android widget/native dosyaları, Supabase migration dosyaları.
- **Not:** Supabase Confirm email ayarı repo dışından açık olmalı; uygulama session dönmeyen kayıt cevabını doğrulama mesajı olarak ele alıyor.
- **Test:** `flutter analyze` temiz. `flutter test --concurrency=1 --dart-define-from-file=env.json` tüm testler geçti.

### WP-2: Persistent Notification + Background Timer — 2026-07-10 ✅
- **Değişen dosyalar:** `app/lib/core/notifications/timer_notification_service.dart`, `app/lib/data/providers/study_providers.dart`, `app/lib/main.dart`, `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/build.gradle.kts`, `app/pubspec.yaml`, `app/pubspec.lock`, `app/test/core/timer_notification_service_test.dart`, `app/test/features/timer_state_machine_test.dart`, `app/test/widget_test.dart`
- **Ne yapıldı:** `flutter_local_notifications` ile Android kalıcı sayaç bildirimi eklendi. Sayaç çalışırken bildirim chronometer gösterir ve `Durdur` aksiyonu uygulama açıkken timer state machine'e bağlanır. Aktif timer başlangıcı/modu/fazı/konusu `SharedPreferences` ile saklanır; uygulama yeniden açılınca timer kaldığı yerden wall-clock süreyle devam eder. Android 13+ `POST_NOTIFICATIONS` izni ve desugaring config eklendi.
- **Dokunma:** `profile/*`, `auth_repository*`, `home/*`, `presence_providers.dart`, Supabase migration dosyaları.
- **Kalan:** Ayrı `Başlat`/manuel `Mola` bildirim aksiyonları eklenmedi; mevcut ürün kararında mola manuel buton değil, pomodoro fazı olarak çalışıyor.
- **Test:** `flutter analyze` temiz. `flutter test --dart-define-from-file=env.json` tüm testler geçti. `flutter build apk --debug --dart-define-from-file=env.json` geçti.

### WP-1: Android Widget Foundation — 2026-07-10 ✅
- **Commit:** `616a92d`
- **Değişen dosyalar:** `app/pubspec.yaml`, `app/pubspec.lock`, `app/android/app/src/main/AndroidManifest.xml`, yeni `app/lib/features/android_widgets/android_widget_service.dart`, yeni Android widget provider/layout/xml dosyaları, yeni `app/test/features/android_widget_service_test.dart`
- **Ne yapıldı:** `home_widget` eklendi. Timer, günlük/haftalık istatistik ve grup leaderboard için Android ana ekran widget altyapısı kuruldu. Flutter tarafında native widget verisini yazan izole servis/provider eklendi.
- **Dokunma:** `classroom/*`, `profile/*`, `auth_repository*`, `study_providers.dart`, `supabase/migrations/0014_profile_animal.sql`
- **Kalan:** Timer widget başlat/durdur aksiyonları ve arka plan kontrolü WP-2'ye bırakıldı.
- **Test:** WP-1 özel test + WP-1 özel analyze temiz; `flutter build apk --debug --dart-define-from-file=env.json` geçti. Global analyze/test Claude'un aktif debug/test değişiklikleri nedeniyle bu committe bekletildi.

### Kamp Ateşi — Ormanda Hayvanlı Sahne (eski 2G, yeniden tasarım) — 2026-07-10 ✅
- **Değişen dosyalar:** `classroom/widgets/campfire_scene.dart` (baştan yazıldı), yeni
  `classroom/widgets/camp_critter.dart` (tüm çizimler), yeni `core/animals/camp_animal.dart`,
  yeni `profile/widgets/camp_animal_picker.dart`, `profile/settings_screen.dart` (+"Kamp ateşi" grubu),
  `data/models/profile.dart` (+`animal`), `data/repositories/auth_repository.dart` + `in_memory/` +
  `supabase/` (+`updateAnimal`), yeni `supabase/migrations/0014_profile_animal.sql`.
- **Ne yapıldı:** Gece ormanında **45° taşlı kamp ateşi** sahnesi (hepsi `CustomPainter`, ek paket yok).
  Tüm grup üyeleri ateş çevresinde **elipse** dizilir: üst yaydakiler **alevin ARKASINDA** (küçük/soluk),
  alt yaydakiler **ÖNÜNDE** (büyük) → gerçek derinlik. Her üye **kendi kütüğünde oturan elle çizilmiş
  tombul hayvan** (Party Animals ruhu; 12 tür, ortak gövde + türe göre kulak/renk/kuyruk/gaga). **Çalışan**
  üye gerçekçi bir **dalda marşmelov** kızartır; marşmelov **oturum süresine göre kademeli pişer**
  (çiğ→altın→kızarmış→koyu + kömür lekesi/buhar, ~40dk). İsim/süre en üst katmanda (alev arkasında bile
  okunur). Orman arka plan: ay+yıldız+katmanlı çam silüetleri (kenarlarda yoğun)+zemin açıklığı. Sahne
  yüksekliği 480px. Nefes animasyonu; çevrimdışı uyur/soluk. **Hayvan seçimi** Ayarlar→Kamp ateşi
  (`profiles.animal`, 0014 — **kullanıcı çalıştırdı**). Seçilmeyene `userId` hash'iyle deterministik varsayılan.
- **Dokunma:** `home/*`, `dashboard_card.dart`, `study_providers.dart`, timer widget'ları.
- **Test:** `camp_animal` birim testleri + `campfire_scene_test.dart` geçiyor; `flutter analyze` temiz.
  (Not: sahne, test render'ından PNG'ye çekilip görsel doğrulandı.)

### Eksiksiz Sayaç/Zamanlayıcı (eski 2H) — 2026-07-10 ✅
- **Değişen dosyalar:** `classroom/widgets/study_timer_card.dart`, `focus_timer_screen.dart`, `clock_style.dart`, `data/providers/study_providers.dart`, yeni `timer_mode_controls.dart`
- **Ne yapıldı:** `StudyTimerNotifier` mod-duyarlı state machine — `TimerMode` (stopwatch/countdown/pomodoro) + `TimerPhase` (work/rest). Geri sayım süre seçici, Pomodoro döngü sayacı + otomatik mola. Her faz bitiminde `_recordSession` ile oturum kaydı. Tam ekran odak moduyla uyumlu.
- **Dokunma:** `home/*`, `profile/*`, `supabase/migrations/*`, `presence_providers.dart`
- **Test:** 2 timer testi, toplam 135+ test geçiyor

### Ayarlar ve Grup Yönetimi Overhaul (eski 2I) — 2026-07-10 ✅
- **Değişen dosyalar:** `profile/settings_screen.dart`, `profile/profile_screen.dart`, `profile/appearance_screen.dart`, yeni `profile/widgets/*`, `core/prefs/*`
- **Ne yapıldı:** Ayarlar ekranı genişletilebilir Görünüm, Ana Sayfa, Sayaç ve Bildirimler gruplarına ayrıldı. Ana Sayfa sıfırlama düzenleme modunun AppBar'ına taşındı.
- **Dokunma:** `classroom/*`, `presence_providers.dart`, `dashboard_card.dart`, `study_timer_card.dart`

### Presence RLS Hardening — 2026-07-10 ✅
- **Değişen dosyalar:** yeni `supabase/migrations/0013_presence_membership_hardening.sql`
- **Ne yapıldı:** Kullanıcı yalnız aktif üyesi olduğu gruba `presence` insert/update atabilir (`is_group_member(group_id)` ile). Kullanıcı Supabase SQL Editor'da çalıştırmalı.
- **Dokunma:** `classroom/*`, timer widget'ları, `study_providers.dart`, `home/*`, `profile/*`

### Kart Responsive Adaptasyonu (eski 2E) — 2026-07-10 ✅
- **Değişen dosyalar:** `home/widgets/` altındaki 16 kart, yeni `home/widgets/card_scaffold.dart`
- **Ne yapıldı:** `CardScaffold` ortak iskelet (başlık + gövde, yetmezse scroll). Grafik kartları hücre yüksekliğini dolduruyor. `HourActivityChart` yeniden yazıldı. heatmap/rhythm'e dikey+yatay scroll. Dar ende ellipsis koruması. 45 render testi eklendi.
- **Dokunma:** `classroom/*`, `dashboard_card.dart`, `dashboard_providers.dart`

---

## 📋 Geçmiş (özet tablo)

| Tarih | Ne | Önemli Notlar |
|---|---|---|
| Tem 10 | 6×N 2D matris refactor (R1–R8) | `grid_reflow.dart` occupancy motoru, `DashboardCardConfig(x,y,w,h)`, eski format göçü |
| Tem 10 | Çoklu grup mimarisi (§1: 1A–1E) | `study_sessions.group_id` DROP, `group_members.left_at` soft-delete, migration 0008–0011, `can_see_user_sessions` RPC, "Eski Grup Üyesi" etiketi |
| Haz 26 | Auth refresh token düzeltmesi | Bozulmuş refresh token'da yerel oturum temizlenip giriş ekranına dönülüyor |
| Haz 22 | Tema/renk paleti (FAZ 3.12) | 5 palet (Lacivert/Mor/Zümrüt/Gün Batımı/Okyanus), koyu/açık/sistem, `AppTheme` palet-parametreli |
| Haz 22 | Zengin & etkileşimli UI (FAZ 3.11) | 19 dashboard kart türü, etkileşimli donut, grup hedefi (0006 migration), çizgi grafik, ısı haritası, scatter, rekorlar, renk-kodlu tablo, yerinde düzenleme modu |
| Haz 22 | İstatistik zenginleştirme (FAZ 3.10) | Donut grafik, sınıf günlük trend çubuğu |
| Haz 21 | Çalışma kayıtları iyileştirme (FAZ 3.9) | Geçmiş günler katlanabilir özet, saat aralığı gösterimi |
| Haz 21 | Ana Sayfa esnek dashboard (FAZ 3.8) | 4 sekme navigasyon, kart ekle/çıkar/sürükle, `dashboardLayoutProvider` kalıcı |
| Haz 21 | Profesyonel sayaç (FAZ 3.7) | Dropdown ders seçici, tam ekran odak modu, 3 saat stili (sade/halka/renk geçişi) |
| Haz 21 | Çoklu sınıf + admin (FAZ 3.6) | Sınıf değiştirici, 3-nokta menü, admin işlemleri, aktif sınıf kalıcılığı, 0004 migration |
| Haz 21 | Dersler + günlük hedef + seri (FAZ 3.5) | `subjects` tablo, `daily_goal_minutes`, `currentStreak` saf hesaplama, 0003+0005 migration |
| Haz 21 | İstatistikler (FAZ 3) | Günlük/haftalık/aylık, hafta içi/sonu, serbest tarih aralığı, fl_chart grafikler, leaderboard |
| Haz 21 | Canlı çalışma (FAZ 2) | Presence (studying/offline), sayaç başlat/durdur, canlı üye listesi, manuel giriş |
| Haz 21 | Supabase entegrasyonu | 0001 migration, çift repo (in_memory + supabase), `env.json`, oturum kalıcılığı |
| Haz 21 | Hesap + sınıf (FAZ 1) | Auth (e-posta/şifre), profil (ad + avatar), sınıf oluştur/katıl, davet kodu |
| Haz 20 | Planlama + ortam kurulumu (FAZ 0) | Flutter 3.44, Android SDK 36, proje iskeleti, dokümanlar |

---

## Önemli Mimari Kararlar

| Karar | Detay |
|---|---|
| `study_sessions.group_id` kaldırıldı | Oturum yalnızca kullanıcıya ait. Grup istatistiği `study_sessions ⨝ group_members` join'iyle hesaplanır |
| Soft-delete (group_members) | `left_at timestamptz` — üye çıkınca satır silinmez, `left_at=now()` yazılır. Geçmiş veri korunur |
| Presence `group_id` korunuyor | `presence` tablosundaki `group_id` kaldırılMADI — dokunma |
| Mola butonu kaldırıldı | Kullanıcı kararı: sade Başlat/Durdur. Durum: çalışıyor / çevrimdışı |
| Dashboard 6 sütun matris | `kGridColumns = 6`, `rowH = cellW` (kare hücre), `Stack + AnimatedPositioned` |
| İstatistikler türetilir | `study_sessions`'tan hesaplanır, ayrı istatistik tablosu yok |
| Avatar public bucket | `avatars` bucket public, URL'e `?v=<ts>` cache kırıcı |
| Re-join upsert | PK `(group_id,user_id)` → ayrılıp dönen üye için upsert (`left_at=null, joined_at=now()`) |
