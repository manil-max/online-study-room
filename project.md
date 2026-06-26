# PROJECT.md — Online Çalışma Sınıfı (Teknik Tasarım Dokümanı)

> Bu doküman projenin tek referans kaynağıdır (Single Source of Truth). Vizyon, gereksinimler,
> mimari, veri modeli, güvenlik, maliyet ve dağıtım kararlarının tamamını içerir.
> İlerleme takibi `progress.md`'de, AI ajan kuralları `AGENTS.md`'dedir.
>
> Durum etiketleri: ✅ Kararlaştırıldı · 🟡 Öneri (onay bekliyor) · ❓ Açık (sonra konuşulacak)
> Son güncelleme: 2026-06-21

---

## 1. Vizyon ve Amaç

Küçük bir grubun (ör. 3–5 kişi) birlikte kullanacağı, **YPT (Yeolpumta) benzeri ortak online
çalışma uygulaması**. Kullanıcılar aynı "sınıfa" katılır, birbirlerinin **canlı çalışma
durumunu** görür, çalışma sürelerini takip eder ve **detaylı istatistiklerle** kıyaslar.

**Temel motivasyon:** Birlikte çalışma hissi, motivasyon ve sağlıklı dayanışma/rekabet.
Birbirini görerek çalışmak sosyal sorumluluk etkisiyle düzenli çalışmayı teşvik eder.

**Kapsam sınırı:** Kapalı, özel bir kullanıcı grubu için tasarlanmıştır. Halka açık, kitlesel
bir ürün hedeflenmemektedir. Büyük ölçeklenebilirlik öncelik değildir; sadelik, güvenilirlik
ve iyi kullanıcı deneyimi önceliklidir.

---

## 2. Hedef Kullanıcılar ve Platformlar

**Kullanıcılar:** Küçük, sabit bir grup. Büyük kullanıcı artışı beklenmiyor.

**Platformlar:**
- **Android** — telefon ve tablet (birincil mobil hedef).
- **Windows** — masaüstü.
- **iOS** — kapsam dışı (ilk sürümde hedeflenmiyor).

Uygulama tüm bu cihazlar arasında **senkronize** çalışır; aynı hesaba farklı cihazlardan
giriş yapıldığında veriler eşitlenir.

---

## 3. Özellik Gereksinimleri

### 3.0 Ekran Yapısı / Navigasyon ✅ (2026-06-21'de 4 sekmeye güncellendi)
Alt menüde **4 sekme**:

| Sekme | İçerik |
|---|---|
| 🏠 **Ana Sayfa** | **Esnek/özelleştirilebilir kontrol paneli** (dashboard). Öğrenci hangi kartları/widget'ları göreceğini ve sıralamasını kendi seçer: sayaç, bugünkü/dönem süreleri, gün serisi, sınıflar, sınıf içi sıralama, seçili istatistikler vb. Bkz. §3.9. |
| 👥 **Sınıflar** | Canlı sınıf ekranı + **çoklu sınıf** desteği. Sekme ikonuna **basılı tutunca** katılınan sınıflar arası geçiş penceresi açılır (+ sınıf oluştur / sınıfa katıl). Sınıf başına 3-nokta menü: bilgi, ayarlar, admin hakları. Bkz. §3.8. |
| 📊 **İstatistik** | İki tür: **(1) Kişisel** istatistik, **(2) Sınıf** (ortak) istatistik. Bkz. §3.4. |
| 👤 **Profil** | Foto, görünen ad, ayarlar, davet kodu, çalışma kayıtları, dersler. |

- **Değişiklik (2026-06-21):** Eski "Sınıf" sekmesi (ana sayfa + canlı birleşik) ayrıldı:
  başa **esnek Ana Sayfa** eklendi, "Sınıf" → **"Sınıflar"** olup çoklu sınıfa açıldı.
  Sayaç kontrolü hem Ana Sayfa'da (widget olarak) hem Sınıflar'da bulunabilir.

> **Not (genel ilke):** Görsel tasarım (renkler, görseller, yerleşim, tema) **en sona**
> bırakılacaktır. Önce işlevsellik ve altyapı; tasarım en son iş.

### 3.1 Grup / Sınıf Sistemi ✅
- Bir kullanıcı sınıf oluşturur, **davet kodu** üretilir.
- Diğerleri kodla sınıfa katılır.
- ✅ **Çoklu sınıf** (2026-06-21 kararı): Kullanıcı birden fazla sınıfa üye olabilir;
  aralarında geçiş yapar. Ayrıntı §3.8.
- ✅ **Roller:** Sınıfı **oluşturan = admin**; diğerleri üye (`group_members.role`).
- ❓ Davet kodunun süresi/yenilenmesi, üye çıkarma gibi detaylar §3.8'de.

### 3.2 Profil ✅
- E-posta + şifre ile hesap (✅ giriş yöntemi kararlaştırıldı).
- Görünen ad (display name).
- Profil fotoğrafı (yükleme + depolama).
- ❓ Ek profil alanları (hedef süre, biyografi, vb.) sonra konuşulacak.

### 3.3 Çoklu Cihaz + Senkronizasyon ✅
- Aynı hesaba farklı cihazlardan giriş → veriler anlık eşitlenir.
- Canlı durum (kim çalışıyor) gerçek zamanlı yayılır (Realtime).
- Çevrimdışı dayanıklılık: bağlantı koptuğunda veri kaybolmamalı (yerel cache + sonradan
  senkron). 🟡

### 3.4 Detaylı İstatistikler ✅ (öncelikli özellik)

**İki ayrı istatistik türü olacak:**

**(1) Kişisel İstatistik** — kullanıcının kendi verisi:
- Günlük ortalama çalışma süresi
- **Hafta içi / hafta sonu** ayrımı
- Zaman aralıkları: son 1 ay, son 1 yıl, **seçili tarih aralığı**
- Dönemler arası kıyaslama (örn. bu hafta vs geçen hafta) grafikleri

**(2) Sınıf (Ortak) İstatistik** — sınıfa özel toplu/kıyaslamalı veriler:
- **Görünürlük: tam şeffaf** ✅ — herkes herkesin verisini görür (güven grubu, YPT mantığı).
- Sınıf üyelerinin **kıyaslamalı** grafikleri/tabloları (kim ne kadar çalışmış)
- Sınıf toplamı / sınıf ortalaması
- **Sıralama (leaderboard): günlük + haftalık + aylık** ✅
- ❓ Hangi grafik tipleri, ek metrikler sonra.

- ❓ Detaylar (grafik tipleri, ek metrikler) netleşecek. Bkz. §9 Açık Sorular.

### 3.5 Canlı Çalışma Ekranı ✅
- Sınıftaki kullanıcılar **kart/öğe** olarak gösterilir (klasik YPT "masa" konsepti YOK).
  **Görsel temsil kullanıcı tarafından sağlanacak bir PNG/foto ile yapılacak** — bu nedenle
  görselin nasıl yerleşeceği **tasarım aşamasında (en sona)** netleşecek.
- Her kişide gösterilecek bilgiler ✅:
  - Profil fotoğrafı + görünen ad
  - **Anlık süre** (o an ne kadardır çalışıyor — canlı sayaç)
  - **Bugünkü toplam süre**
  - **Durum:** çalışıyor / mola / çevrimdışı
- **Süre tutma davranışı:** Sayaç arka planda **kesintisiz çalışır** ✅ — telefon kilitlense
  veya başka uygulamaya geçilse de durmaz (otomatik mola/durdurma yok).
- **Manuel süre girişi:** Esnek ✅ — bugüne veya **geçmiş bir tarihe** süre eklenebilir,
  düzenlenebilir, silinebilir. (Dürüstlük güvene dayalı.)
- **Kaynak ayrımı yok** ✅ — manuel ve otomatik süre **aynı sayılır**, istatistikte ayrı
  gösterilmez.

### 3.6 Widget'lar ✅
- **Android ana ekran widget'ı:** Uygulamayı açmadan tek dokunuşla "çalışmaya başla",
  süreyi widget üzerinden görme.
- **Windows widget'ı:** Masaüstünde her zaman görünür mini bilgi/kontrol.
- ❓ İçerik, boyut, hangi platform öncelikli — sonra konuşulacak.

### 3.7 Dersler, Günlük Hedef ve Seri ✅ (2026-06-21 kararı)

Kardeşin tasarladığı arayüz referansından gelen 3 özellik kararlaştırıldı:

**Dersler (kategoriler) ✅** — Kullanıcı **kendi derslerini** tanımlar (kişisel takip için):
- Her ders: **ad** + **renk**. Renk paleti tasarım referansıyla aynı: `chart-1..chart-5`
  (mavi/yeşil/sarı/mor/kırmızı). Kullanıcı ekler/düzenler/siler. **Ders sayısı sınırı yok.**
- **Ders seçimi zorunlu DEĞİL** ✅ — sadece kronometre tutmak isteyen derssiz çalışabilir
  (`subject_id` boş kalır). İsteyen sayacı bir derse bağlar.
- İstatistik **ders bazında** ayrışır (donut/çubuk dağılımı — bkz. §3.4); derssiz süreler
  "Genel/Derssiz" altında toplanır.
- Manuel girişte de ders seçilebilir (zorunlu değil).
- **Ders silinince** o derse ait geçmiş oturumlar **silinmez, derssize düşer**
  (`subject_id` null olur) — çalışma süresi korunur, sadece etiket gider.
- Dersler **kişiye özel** (her kullanıcı kendi derslerini görür); sınıf görünümünü etkilemez.
- Veri: `subjects` tablosu (şemada hazırdı, artık kullanılıyor) + `study_sessions.subject_id`
  (nullable, `ON DELETE SET NULL`).

**Günlük hedef ✅** — Kullanıcı günlük bir çalışma hedefi koyar (örn. 6sa):
- Ana ekranda ilerleme çubuğu + yüzde (bugünkü toplam / hedef).
- Hedef düzenlenebilir. Kişiye özel (kullanıcı başına bir değer).
- Veri: `profiles.daily_goal_minutes` (varsayılan bir değerle).

**Seri (streak) ✅** — Günlük hedefe bağlı alışkanlık göstergesi:
- **Kural:** Günlük hedefi tutturduğun (süreyi doldurduğun) **her gün seri +1** artar.
  Hedefi dolduramadığın gün seri **sıfırlanır**. Üst üste hedef tutturulan gün sayısı = seri.
- Hesaplama `study_sessions` + günlük hedeften **türetilir** (ayrı tabloda tutulmaz; §6 ilkesi).

---

## 4. Teknoloji Yığını (Tech Stack)

| Katman | Seçim | Durum | Gerekçe |
|---|---|---|---|
| Uygulama (UI) | **Flutter (Dart)** | ✅ | Tek kod tabanı → Android (telefon+tablet) + Windows + (gerekirse Web). Ücretsiz, olgun. |
| Backend / Sunucu | **Supabase (Free tier)** | 🟡 | Auth + Postgres + Realtime + Storage. Küçük grup için ücretsiz limit fazlasıyla yeter. |
| State management | **Riverpod** | 🟡 | Test edilebilir, modern, yaygın. |
| Grafikler | **fl_chart** | 🟡 | İstatistik için esnek grafik kütüphanesi. |
| Android widget | **home_widget** paketi | 🟡 | Native Android widget'ını Flutter'dan beslemek için. |
| Windows widget | Always-on-top mini Flutter penceresi | 🟡 | Windows 11 "Widgets board" zor; basit ve kontrollü yol bu. |
| Yerel veri / cache | **Drift** veya **Hive** | ❓ | Çevrimdışı destek + hız (ileride seçilecek). |

**Neden Flutter?** Tek kodla Android (telefon + tablet) ve Windows. Olgun ekosistem, büyük
topluluk, ücretsiz.

**Neden Supabase (Firebase yerine)?** İkisi de ücretsiz çalışır. Supabase açık kaynak ve
**SQL (Postgres)** kullanır → detaylı istatistik sorguları (agregasyon, tarih aralıkları,
kıyaslama) çok daha kolay ve veri taşınabilir. Karar 🟡 (henüz kesinleşmedi, ama güçlü tercih).

---

## 5. Sistem Mimarisi

```
┌─────────────────────────────────────────────────────────┐
│  Flutter Uygulaması (Android telefon/tablet · Windows)    │
│  • UI katmanı (sınıf · profil · istatistik · canlı)       │
│  • Riverpod ile durum yönetimi                            │
│  • Yerel cache (çevrimdışı dayanıklılık)                  │
│  • Widget besleme (home_widget / Windows mini pencere)    │
└──────────────────┬────────────────────────────────────────┘
                   │ HTTPS (REST) + WebSocket (Realtime)
┌──────────────────▼────────────────────────────────────────┐
│  Supabase (Backend-as-a-Service)                          │
│  • Auth        → e-posta/şifre giriş                      │
│  • Postgres    → kullanıcı, grup, oturum, ders verisi     │
│  • Realtime    → canlı "kim çalışıyor" (presence)         │
│  • Storage     → profil fotoğrafları                      │
│  • RLS         → satır seviyesi güvenlik (veri izolasyonu)│
└────────────────────────────────────────────────────────────┘
```

**Katmanlı uygulama yapısı (planlanan):**
- **Presentation** (UI / ekranlar / widget'lar)
- **Application/State** (Riverpod provider'ları, use-case'ler)
- **Data** (repository'ler, Supabase client, modeller, yerel cache)

---

## 6. Veri Modeli (Taslak)

> İlk taslak; geliştikçe netleşecek. Ders/kategori sistemi ❓ (sonra karar verilecek).

- **profiles** — `id` (auth user), `display_name`, `avatar_url`, `daily_goal_minutes`
  (günlük hedef, §3.7), `created_at`
- **groups** (sınıf) — `id`, `name`, `invite_code`, `created_by`, `created_at`
- **group_members** — `group_id`, `user_id`, `role` (admin/member), `joined_at`
- **subjects** (ders ✅ kullanılıyor — §3.7) — `id`, `user_id`, `name`, `color`
- **study_sessions** — `id`, `user_id`, `group_id`, `subject_id?`, `start_time`,
  `end_time`, `duration_seconds`, `source` (`live`|`manual` — sadece kayıt amaçlı,
  istatistikte/UI'da ayrım yapılmaz), `date`
- **presence** (Realtime, kalıcı olmayabilir) — `user_id`, `status`
  (`studying`/`break`/`offline`), `current_subject_id?`, `started_at`

**İstatistikler ayrı tabloda tutulmaz**; `study_sessions` üzerinden sorgu/agregasyonla üretilir
(gerekirse performans için materialized view / önbellek eklenir).

---

## 7. Güvenlik

- **RLS (Row Level Security) zorunlu:** Her kullanıcı yalnızca kendi grubunun verisine erişir.
- **Anahtar yönetimi:** Supabase `anon key` istemcide olabilir; `service_role key` **asla**
  istemciye veya repoya konmaz.
- **Gizli değerler** `.env` / derleme zamanı değişkeni ile verilir, repoya commit edilmez.
- Şifreler Supabase Auth tarafından yönetilir (hash'lenmiş, biz saklamayız).

---

## 8. Maliyet ve Dağıtım

**Hedef: 0 TL.**

| Kalem | Maliyet | Not |
|---|---|---|
| Flutter SDK | Ücretsiz | Açık kaynak |
| Supabase Free tier | Ücretsiz | Küçük grup için limitler fazlasıyla yeter |
| Android dağıtımı | Ücretsiz | **APK sideload** — cihazlara doğrudan kurulum, Play Store gerekmez |
| Windows dağıtımı | Ücretsiz | Doğrudan exe/kurulum paketi |
| Google Play hesabı | (Gerekmez) | İstenirse $25 tek seferlik — ama gerek yok |

**Risk:** Supabase ücretsiz limitleri aşılırsa (küçük grupta neredeyse imkansız) →
kendi sunucumuzu (self-host) veya başka ücretsiz katmanı değerlendiririz.

---

## 9. Açık Sorular (sonra konuşulacak) ❓

- ~~**Ders/kategori sistemi**~~ ✅ KARAR (2026-06-21): Kullanıcı **kendi derslerini** ekler
  (ad + renk); sayaç bir derse bağlanır; istatistik ders bazında ayrışır. Bkz. §3.7.
- ~~**Mola (break) mantığı**~~ ✅ KARAR (2026-06-21): Mola butonu KALDIRILDI. Kullanıcı sade
  bir Başlat/Durdur akışı istedi — mola süresi tutulmadığı için ayrı "mola" durumu gereksiz
  karmaşa yaratıyordu. Durum yalnızca: çalışıyor / çevrimdışı. (PresenceStatus.onBreak enum'u
  ve turuncu gösterim ileride istenirse diye şemada/kodda duruyor ama kullanılmıyor.)
- **İstatistik detayı:** Hangi grafik tipleri, hangi kıyaslamalar?
- **Widget içeriği:** Hangi bilgiler, hangi boyut, hangi platform öncelikli?
- **Tasarım dili:** Renkler, tema (açık/koyu), genel görünüm/his.
- **Tek mi çok mu sınıf:** İlk sürüm tek sınıf; çoklu sınıf gerçekten istenecek mi?
- ❓ **Gelecek UI Geliştirmeleri (Kullanıcı Geri Bildirimi - 26 Haziran):**
  - **Grid Boyutlandırma:** Ana ekrandaki kartların sadece sağ alt köşeden (genişlik) değil, Android widget'ları gibi 4 kenar ve köşeden (hem genişlik hem yükseklik) ayarlanabilmesi.
  - **Canlı Grup Hedefi:** Grup hedef ilerleme barının (örn. 360 dk), üyeler durdur tuşuna basmadan *canlı* olarak (çalışan kişi sayısına göre saniye saniye) akması.
  - **Grup Yönetimi Arayüzü:** Grup ayarları ve üye yönetiminin daha kolay/derli toplu yapılabilmesi için UI/UX iyileştirmeleri.

---

## 10. Karar Günlüğü

- **2026-06-20:** Proje başlatıldı. Stack: Flutter + Supabase (ücretsiz, APK sideload ile
  0 maliyet). Giriş: e-posta + şifre. İlk hedef platform: Android. iOS kapsam dışı.
  Öncelik: önce altyapı/ana hatlar. Ders sistemi sonraya bırakıldı.
- **2026-06-21 (profil fotoğrafı):** Avatar'lar **public** bir Supabase Storage bucket'ında
  (`avatars`) tutulur; dosya yolu `<uid>/avatar` (RLS: kullanıcı yalnızca kendi klasörüne yazar).
  Public bucket seçildi çünkü `avatar_url`'i doğrudan göstermek basit; URL'e önbellek kırıcı
  `?v=<ts>` eklenir. Yükleme yalnızca Supabase modunda çalışır (bellek-içi modda hata verir).
  Kurulum: `migrations/0002_avatars_storage.sql`.
- **2026-06-21 (canlı presence):** Presence yazımı **sayaç başlat/durdur** anında yapılıyor
  (başla → `studying`, durdur → `offline`). Çevrimdışı tespiti için heartbeat/yaşam-döngüsü
  henüz yok → uygulama kapanırsa durum bir süre "çalışıyor" kalabilir; sonraki fazda
  iyileştirilecek. Üyenin "bugünkü toplam"ı presence satırından değil `study_sessions`
  agregasyonundan türetiliyor (tek doğru kaynak; presence.today_seconds yalnızca bilgi
  amaçlı). Mola (break) durumu UI'da gösterime hazır ama buton yok (Açık Sorular §9'da).
- **2026-06-21 (ilk kullanım geri bildirimi → büyük yön):** Kullanıcı uygulamayı Chrome'da
  denedi. Kararlar: (1) Navigasyon **4 sekme**: Ana Sayfa / Sınıflar / İstatistik / Profil
  (§3.0). (2) **Çoklu sınıf** + basılı-tut sınıf değiştirici + sınıf başına 3-nokta menü
  (bilgi/ayarlar/admin); oluşturan **admin** (§3.8); sınıflara **chat** ileride planlı.
  (3) **Esnek Ana Sayfa** dashboard'u — kullanıcı widget'ları kendi düzenler (§3.9, tasarımda
  netleşecek). (4) **Çalışma kayıtları**: geçmiş günler tek kayıtta toplansın + saat aralığı
  göster (§3.10). (5) **Sınıf istatistiklerini** zenginleştir (§3.11). Bug: ders eklenince
  listede görünmüyordu → Realtime bağımlılığı kaldırılarak çözüldü.
- **2026-06-21 (dersler + hedef + seri):** Kardeşin hazırladığı UI tasarımı referansı
  (`project-continuation/`, Next.js — koddan değil tasarımdan yararlanılacak) incelendi.
  3 yeni özellik kararlaştırıldı (§3.7): (1) Kullanıcı tanımlı **dersler** (ad+renk),
  (2) **günlük hedef**, (3) günlük hedefe bağlı **seri** (hedef tutturulan her gün +1,
  tutturulamazsa sıfır). Veri modeli: `subjects` aktifleşti, `study_sessions.subject_id`
  kullanılacak, `profiles.daily_goal_minutes` eklenecek. Seri hesaplaması türetilecek.
  Tasarım dili (koyu tema, renk paleti) de bu referanstan alınacak ama uygulama en sona.
- **2026-06-21 (oturum kalıcılığı):** Ayrı bir oturum-saklama kodu yazılmadı; `supabase_flutter`
  oturumu varsayılan olarak yerel depolamada tutar ve açılışta otomatik geri yükler. Karar:
  profil çekimi başarısız olursa (çevrimdışı/geçici hata) kullanıcı **dışarı atılmaz** —
  geçerli oturum varsa metadata'dan geçici profille içeride kalır (§3.3 çevrimdışı dayanıklılık).
  Böylece internet olmadan da uygulama açılınca giriş korunur.
- **2026-06-26 (Ana Sayfa gerçek 6×N matris):** Akış/Wrap tabanlı dashboard yerine
  Android launcher hissi için 6 sütunlu, aşağı doğru sınırsız 2D matris seçildi. Kalıcı kart
  düzeni `DashboardCardConfig(type, x, y, w, h)` ve `"tür:x:y:w:h"` formatıdır. Eski yerel
  kayıtlar (`"tür:genişlik[:yükseklik]"`, `"tür:boyut"`, `"tür"`) uygulama açılışında
  güvenli biçimde yeni formata göçürülür; gizli/veritabanı verisi içermez.

### 3.8 Sınıflar — Çoklu Sınıf + Admin ✅ (2026-06-21 kararı)

Eski tek-sınıf "Sınıf" sekmesi **"Sınıflar"** olarak çoklu sınıfa açıldı.

- **Çoklu üyelik:** Kullanıcı birden fazla sınıfa katılabilir. Bir anda bir **aktif
  sınıf** görüntülenir (canlı liste, sıralama vb. aktif sınıfa göre).
- **Sınıf değiştirici (Instagram hesap değiştirme mantığı):** "Sınıflar" sekme ikonuna
  **basılı tutunca** bir pencere/alt sayfa açılır:
  - Katılınan tüm sınıflar listelenir → birine dokununca aktif sınıf değişir.
  - **"Sınıf oluştur"** ve **"Sınıfa katıl"** seçenekleri.
- **Sınıf başına 3-nokta (⋮) menüsü** (listede her sınıfın yanında):
  - **Sınıf bilgileri:** ad, davet kodu, üye sayısı/listesi, oluşturulma.
  - **Sınıf ayarları:** (herkes) sınıftan çık; (admin) sınıf adını değiştir, üye çıkar,
    davet kodunu yenile, sınıfı sil.
  - **Admin'e özel haklar:** yalnızca oluşturan/admin görür.
- **Roller:** Oluşturan `role='admin'`. (Şema `group_members.role`'da hazır; `createGroup`
  admin atayacak şekilde güncellenecek.)
- **İleride (planlı):** Her sınıfa **sohbet (chat)** eklenecek — bu menü/ekran yapısı
  ona uygun kurulacak (sınıf detayında bir "Sohbet" sekmesi yeri ayrılır). ❓ Detay sonra.

**Veri/mimari:** `userGroupsProvider` (tüm üyelikler) + `activeGroupProvider` (seçili sınıf,
yerelde kalıcı). Mevcut tek-`userGroupProvider` bunun üstüne taşınacak; canlı/istatistik
sorguları aktif sınıfa bağlanacak.

### 3.9 Ana Sayfa — Esnek Kontrol Paneli (Dashboard) ✅ (2026-06-21 kararı, uygulandı)

Başa eklenen **Ana Sayfa** sekmesi **tamamen özelleştirilebilir**: öğrenci hangi kartları
göreceğini ve sıralamasını kendi belirler (ekle/çıkar/**sürükle-bırak sırala**).

- **Kart kataloğu (ilk sürüm):** **sayaç** (kronometre + günlük hedef + seri), **bugün özeti**
  (bugünkü toplam + ders dağılımı), **haftalık grafik** (son 7 gün), **sınıf sıralaması**
  (aktif sınıf, bugün). İleride: hedef/seri standalone, hafta içi/sonu, dönem özetleri.
- **Düzenleme UX (karar):** Ayrı bir "düzenle" ekranı (`DashboardEditScreen`):
  görünen kartlar `ReorderableListView` ile sürüklenerek sıralanır + kaldırılır;
  "eklenebilir kartlar" listesinden eklenir.
- **Saklama (karar):** Yerleşim **cihazda yerel** (`shared_preferences`,
  `dashboardLayoutProvider`) — `profiles`'ta JSON değil (kişisel cihaz tercihi olduğu için).
- **Sayaç yeri (karar):** Sayaç **varsayılan Ana Sayfa'da**; isteyen düzenle ekranındaki
  anahtarla **Sınıflar'a da ekler** (`classroomShowTimerProvider`, kalıcı). Sınıflar ekranı
  artık varsayılan sayaçsız (yalnız canlı üyeler + sınıf bilgisi).

### 3.10 Çalışma Kayıtları — Gün Sonu Toplama + Okunaklı Gösterim ✅ (2026-06-21 kararı)

Profil → "Çalışma kayıtlarım"da en küçük oturum bile ayrı kaydedildiği için liste şişiyor.

- **Gün-sonu toplama:** **Bugünün** oturumları ayrı ayrı görünür (canlı takip için); ama
  **geçmiş günler** o güne ait tek bir özet kayıtta toplanır (gün + toplam süre).
  Detay istenirse o güne dokununca alt kırılım açılabilir (ders bazında / oturumlar). ❓
- **Okunaklı gösterim:** Tek satırda yalnız "1sn / Sayaç" yerine **saat aralığı** (örn.
  "14:05–14:50") ve/veya süre + ders + kaynak gibi daha anlamlı bilgi gösterilecek.
- **Not:** Toplama yalnızca **görünüm** içindir; `study_sessions` ham verisi korunur
  (istatistikler ham veriden üretilmeye devam eder, §6).

### 3.11 Sınıf İstatistiklerini Geliştirme 🟡 (2026-06-21 kararı)
Mevcut sınıf sekmesi (leaderboard) zenginleştirilecek: daha fazla metrik ve daha iyi
görünüm. ❓ Hangi metrikler (örn. sınıf günlük trendi, en istikrarlı üye, ders bazında
sınıf kıyası, haftalık değişim) tasarım/uygulama sırasında netleşecek.

### 3.12 Profesyonel & Özelleştirilebilir Sayaç (Saat) ✅ (2026-06-21 kararı)

**Amaç:** Sayaç o kadar iyi olmalı ki kullanıcı **başka hiçbir kronometre/odak uygulamasına
ihtiyaç duymasın** — bu uygulama yetsin. İlke: **varsayılan sade, ama özelleştirilebilir.**
Sadece kronometre tutmak isteyen kişi 100 ayar görmez; isteyen "Sayaç görünümü"nden
zenginleştirir. (Forest/Flow gibi rakiplerden esinlenildi; bkz. Karar Günlüğü.)

- **Ders seçici = "dropdown" ✅** — Düz, yan yana butonlar yerine **kapalıyken seçili dersi
  (veya "Genel") gösteren bir hap**; dokununca seçenekler açılır (Claude Code model seçici
  mantığı). Liste sonunda "Dersleri düzenle". Çalışırken kilitli (yalnız etiket).
- **Tam ekran odak modu ✅** — Sayaç kartındaki **tam ekran** ikonu, dikkat dağıtmayan
  tam ekran bir sayaç açar (büyük canlı süre + ders + büyük Başlat/Durdur + küçült tuşu).
  Sistem çubukları gizlenir (immersive), çıkışta geri yüklenir.
- **Özelleştirilebilir saat stilleri 🟡 (sıradaki)** — Kullanıcı saat görünümünü seçer:
  - **Sade rakam** (varsayılan) — şu anki sayaç.
  - **Halka / dial** — günlük hedefe göre dolan ilerleme halkası.
  - **Renk geçişi** — hedefe yaklaştıkça renk **zıt → yeşil** (örn. kırmızı→sarı→yeşil)
    döner. (Günlük hedefe bağlı, §3.7.)
  - **(İleride)** sınıf "yarış"/dilim görünümü (üyelerle kıyas hissi).
- **(İleride, opsiyonel)** Pomodoro / aralıklı çalışma modu (25/5 vb.), bitiş bildirimi.
- **Saklama:** Seçilen saat stili + tam-ekran tercihi kişiye özel (yerel; ileride profilde).
