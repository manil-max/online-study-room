# PROJECT.md — Online Çalışma Sınıfı (Teknik Tasarım Dokümanı)

> Bu doküman projenin tek referans kaynağıdır (Single Source of Truth). Vizyon, gereksinimler,
> mimari, veri modeli, güvenlik, maliyet ve dağıtım kararlarının tamamını içerir.
> İlerleme takibi `progress.md`'de, AI ajan kuralları `AGENTS.md`'dedir.
>
> Durum etiketleri: ✅ Kararlaştırıldı · 🟡 Öneri (onay bekliyor) · ❓ Açık (sonra konuşulacak)
> Son güncelleme: 2026-06-20

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

### 3.0 Ekran Yapısı / Navigasyon ✅
Alt menüde **3 sekme**:

| Sekme | İçerik |
|---|---|
| 🏠👥 **Sınıf** | Ana sayfa + canlı sınıf **tek ekranda birleşik**. Üstte kendi çalışma kontrolün (Başla/Durdur, bugünkü süre), altta YPT tarzı canlı sınıf (masa/lamba — kim çalışıyor). |
| 📊 **İstatistik** | İki tür: **(1) Kişisel** istatistik, **(2) Sınıf** (ortak) istatistik. Bkz. §3.4. |
| 👤 **Profil** | Foto, görünen ad, ayarlar, davet kodu, sınıftan çıkış. |

- Birleştirme gerekçesi: Tek sınıfa girileceği için ayrı "ana sayfa" ve "canlı sınıf" ekranı
  gereksiz; tek ekranda toplamak daha sade.

> **Not (genel ilke):** Görsel tasarım (renkler, görseller, yerleşim, tema) **en sona**
> bırakılacaktır. Önce işlevsellik ve altyapı; tasarım en son iş.

### 3.1 Grup / Sınıf Sistemi ✅
- Bir kullanıcı sınıf oluşturur, **davet kodu** üretilir.
- Diğerleri kodla sınıfa katılır.
- 🟡 İlk sürümde tek sınıf yeterli; mimari ileride çoklu sınıfa izin verecek şekilde kurulacak.
- ❓ Davet kodunun süresi/yenilenmesi, üye çıkarma gibi detaylar sonra.

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

- **profiles** — `id` (auth user), `display_name`, `avatar_url`, `created_at`
- **groups** (sınıf) — `id`, `name`, `invite_code`, `created_by`, `created_at`
- **group_members** — `group_id`, `user_id`, `role` (admin/member), `joined_at`
- **subjects** (ders — ❓ kullanılacak mı belirsiz) — `id`, `user_id`, `name`, `color`
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

- **Ders/kategori sistemi:** Kendi derslerini mi tanımlayacaklar (Matematik, Fizik...),
  yoksa tek "çalışma" sayacı mı?
- **Mola (break) mantığı:** Kullanıcı elle "mola" durumuna geçebilecek mi? Mola süresi ayrı
  mı tutulsun yoksa sadece "durum" göstergesi mi olsun?
- **İstatistik detayı:** Hangi grafik tipleri, hangi kıyaslamalar?
- **Widget içeriği:** Hangi bilgiler, hangi boyut, hangi platform öncelikli?
- **Tasarım dili:** Renkler, tema (açık/koyu), genel görünüm/his.
- **Tek mi çok mu sınıf:** İlk sürüm tek sınıf; çoklu sınıf gerçekten istenecek mi?

---

## 10. Karar Günlüğü

- **2026-06-20:** Proje başlatıldı. Stack: Flutter + Supabase (ücretsiz, APK sideload ile
  0 maliyet). Giriş: e-posta + şifre. İlk hedef platform: Android. iOS kapsam dışı.
  Öncelik: önce altyapı/ana hatlar. Ders sistemi sonraya bırakıldı.
