# AGENTS.md — Proje Kuralları (Kalite Programı)

> Bu dosya **tüm ajanların her zaman** uyması gereken çekirdek kurallardır.
> Rol rehberleri: planlama → `skills/planner/SKILL.md` · uygulama → `skills/worker/SKILL.md`.
> **Kanonik program:** `docs/KALITE-PROGRAMI.md` (vizyon + teknik + kalite kapıları). Çelişki olursa KALITE-PROGRAMI kazanır.

---

## 0. Temel İlke: "Tamamlandı" artık zordur

Projede iki "tamamlandı" tanımı vardır. **Yalnız (2) geçerlidir:**

1. Kod/ekran oluşturuldu. *(yetmez)*
2. Özellik kullanıcı beklentisini karşılıyor ve **gerçek cihazda güvenilir** çalışıyor. *(gerçek tamamlandı)*

Amaç daha çok WP açmak değil; **birinci sınıf kalite** ve "tamamlandı" kelimesini hak etmek. Hız için kaliteden ödün verilmez.

### İş durum merdiveni (8 aşama)

`Planlandı → Geliştiriliyor → Kod tamamlandı → Otomatik test geçti → Gerçek cihaz QA geçti → Ürün kabulü geçti → Yayınlandı → Yayın sonrası doğrulandı`

- Bir ajan kendi başına en fazla **"Otomatik test geçti"**e kadar kapatabilir.
- **"Tamamlanan İş Paketleri"ne** ancak "Gerçek cihaz QA" + "Ürün kabulü" sonrası taşınır. Cihaz/kabul kanıtı yoksa iş "Kod tamamlandı — kabul bekliyor" olarak kalır.

### Her iddiaya kanıt etiketi

Bir şey söylerken şu üç etiketten biri kullanılır (kullanıcı varsayımla gerçeği ayırabilsin):

- `Kodda doğrulandı` — dosya/satır okunarak teyit edildi.
- `Cihazda doğrulanmalı` — gerçek Android cihazda kanıt gerekir.
- `Ürün kararı gerekiyor` — kullanıcı kararı olmadan ilerlenmez.

---

## 1. Çok-Ajanlı Çalışma ve Çakışma Protokolü (KRİTİK)

Bu projede aynı anda **3–4 ajan paralel** çalışır (Gemini / Claude / Codex + gerek/ek). Tek paylaşılan gerçek `progress.md`'deki **Aktif Çalışma Kaydı**dır. Ajanlar birbirinin belleğini görmez; koordinasyon yalnız bu dosya üzerindendir.

### 1.1 Kural A — Görevi alır almaz "claim" et

Bir ajan bir Faz/WP almaya başlar başlamaz, **kod yazmadan önce** `progress.md`'deki Aktif Çalışma Kaydı'na kendi lane'ini işler:

```
### <Ajan> Lane
- Durum: [~] Aktif
- Faz/WP: V8-A · WP-40
- Aşama: Geliştiriliyor
- SAHİP yollar: app/lib/features/clock/**, app/lib/core/notifications/timer_*
- Ortak/riskli yüzey: pubspec.yaml (yeni paket), migration 0024, AndroidManifest.xml
- Dal: main   (tek dal — §1.5; çakışma ayrık SAHİP dosyalarla önlenir)
- Başlangıç: 2026-07-12 15:40 (Europe/Istanbul)
- Son güncelleme: 2026-07-12 15:40
- Not: —
```

### 1.2 Kural B — Başlamadan önce çakışma ön-kontrolü yap ve gerekiyorsa UYAR

> **BU KURAL, KULLANICI GÖREVİ AÇIKÇA ATAMIŞ OLSA BİLE GEÇERLİDİR.** "Bana bu WP verildi" diye çakışmayı görmezden gelme. Görev sana verilmiş olması, başka bir ajanla aynı anda çalışmanın güvenli olduğu anlamına gelmez. Çakışma görürsen **işe BAŞLAMA**, önce uyar, kullanıcının kararını bekle.

Kod yazmadan önce ajan **tüm Aktif Çalışma Kaydı'nı okur** ve verilen görevi diğer aktif lane'lerle karşılaştırır. Aşağıdakilerden biri varsa **DURUR ve kullanıcıyı uyarır** (kendi başına başlamaz):

- **Dosya çakışması:** Verilen WP'nin SAHİP yolları başka aktif lane'in SAHİP/ortak yollarıyla kesişiyor.
- **Ortak "sıcak dosya":** İki iş aynı anda §1.4'teki sıcak dosyalara giriyor.
- **Migration sırası:** İki iş aynı/çakışan migration numarasına ya da bağımlı şema alanına dokunuyor.
- **Büyük program çakışması:** Saat, Tema ve Başarım aynı anda açık (üçü de theme/navigation/profile/provider yüzeylerini paylaşır — asla üçü birden).
- **Bağımlılık hazır değil:** Görev, henüz "Ürün kabulü"nden geçmemiş başka bir WP'nin çıktısına dayanıyor.

Uyarı formatı (Türkçe, somut, gerekçeli):

> ⚠️ **Çakışma uyarısı:** Bana **WP-74**'ü verdin ama şu an **Gemini WP-67**'yi yapıyor (Aşama: Geliştiriliyor). İkisi de `app/lib/core/theme/app_theme.dart` ve `pubspec.yaml`'a yazıyor; aynı anda çalışırsak (1) tema token'larında çakışan tanımlar, (2) `pubspec` merge conflict, (3) tutarsız golden test çıkar. **Öneri:** WP-74'ü WP-67 "Ürün kabulü"nden sonra başlat **ya da** kapsamını yalnız `features/clock/**` ile sınırlayıp temaya dokunma. Nasıl ilerleyeyim?

Çakışma yoksa: claim'i yaz → **kaydı yeniden oku** (iki-aşamalı claim; bu sırada başkası aynı kapsamı almışsa geri çekil ve uyar) → başla.

### 1.3 Kural C — Yalnız kendi kulvarına yaz

- **Sadece kendi WP'nin SAHİP dosyalarına yaz.** Başka WP'nin SAHİP dosyasına ASLA dokunma (okuyabilirsin).
- `progress.md`'de **yalnız kendi lane'ini ve kendi WP kartını** düzenle. Başka lane'lerin kartlarını okuma-dışı bırakma; reassign yoksa dokunma.
- Yeni dosya yalnız kendi feature klasörüne.
- Ortak dosya değişikliği gerekiyorsa **WP'de açıkça yazılı olmalı**; değilse dur ve sor.

### 1.4 Sıcak dosyalar (aynı anda iki WP giremez — planner serileştirir)

`progress.md` (yalnız kendi lane) · `app/pubspec.yaml` · `app/lib/main.dart` · `app/lib/core/navigation/**` · `app/lib/core/theme/**` · `supabase/migrations/**` (numara sırası) · l10n/generated dosyalar · `AndroidManifest.xml`.

### 1.5 Git disiplini — tek dal (`main`), branch/merge/push yok

Ajanlar aynı çalışma dizinini paylaşır ve doğrudan `main` üzerinde çalışır. Çakışma; branch, PR veya auto-merge ile değil, **Aktif Çalışma Kaydı + ayrık SAHİP dosyalar** ile önlenir.

- Yeni branch açma, merge yapma veya push etme; kullanıcı özellikle istemedikçe bu işlemler yapılmaz.
- Her WP için tek, ayrık commit atılır.
- Commit öncesi `flutter analyze` (0 uyarı) ve `flutter test` yeşil olmalıdır.
- Yalnız kendi SAHİP dosyalarını açık yollarla stage/commit et. **`git add -A`** ve `git commit -a` yasaktır.
- `index.lock` görülürse başka bir ajan commit ediyordur; kısa süre bekleyip yeniden dene.

CI/PR auto-merge için WP-39 iptal edilmiştir. Yerel DoD ve gerçek cihaz QA kalite kapısı olmaya devam eder.

---

## 2. Zorunlu Kod Kuralları

### Derleme & Çalıştırma
- Tüm `flutter` komutları **`app/` içinde** çalışır, repo kökünde değil.
- Her `flutter run/test/build` komutuna **`--dart-define-from-file=env.json`** geç. Anahtar yoksa uygulama sessizce InMemory moda düşer (giriş + ayarlar kaybolur).
- `flutter analyze` **`--dart-define-from-file` bayrağını KABUL ETMEZ** — analyze'i bayraksız çalıştır.

### Repo Katmanı (çift implementasyon)
- Her repository hem `supabase/` hem `in_memory/` altında. **İkisini de güncelle**, yoksa demo/offline mod kırılır.
- Arayüz değişikliği → `data/repositories/xxx_repository.dart` (abstract).

### Veritabanı, RLS & Güvenlik (asla atlanmaz)
- **Tek yetkilendirme katmanı RLS'tir.** İstemci kontrolü kozmetiktir. Yeni erişim kuralı → `supabase/migrations/*.sql` politikası/RPC'sinde.
- SECURITY DEFINER helper'lar: `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`, `is_super_admin()`.
- **Server-authoritative:** XP/başarı/kritik ilerleme istemcide hesaplanıp yazılamaz. Append-only ledger + idempotent event + benzersiz ödül anahtarı (bkz. KALITE-PROGRAMI §8.6).
- **Sosyal profil görünürlüğü:** yalnız ortak aktif grup üyesi; e-posta görünmez; adminlik erişimi otomatik genişletmez.
- **Gizli dosyalar asla commit edilmez:** `env.json`, `app/android/key.jks`, `app/android/key.properties`, `KEYSTORE_SECRETS.txt`, Supabase `service_role`. Commit öncesi `git status` ile doğrula.
- **Release keystore kalıcıdır.** `key.jks` değişirse Android güncellemeleri reddeder — yeniden üretme.
- Migration'lar **sırayla** çalışır (`NNNN_ad.sql`, son numaradan devam). Sırayı bozma, kısmen uygulama. Tek kanonik zincir local → staging → production yönünde Supabase CLI ile terfi eder; normal deploy için SQL Editor kullanılmaz. Tam sözleşme: `docs/ORTAM-MIGRATION-YONETISIMI.md`.
- **Migration Başlık Kuralı:** Yeni bir migration dosyası oluştururken, her zaman `supabase/migrations/` klasöründeki mevcut en yüksek numarayı kontrol et ve **1 artırarak** ilerle. Migration'ın **ilk satırı, başında `-- ` olacak şekilde gerçek dosya adının tamamı olmak zorundadır**; numara veya serbest açıklama tek başına kabul edilmez (`-- 0054_ornek.sql`). Açıklama ikinci satırdan başlar. Dosyanın en üstünde işleyiş özeti ve rollback talimatı içeren şu standart yorum bloğu mutlaka bulunmalıdır:
  ```sql
  -- NNNN_dosya_adi.sql
  -- [Kısa açıklama / WP]
  --
  -- [Detaylı açıklama ve notlar]
  --
  -- Geri alma (Rollback): [Geri almak için çalıştırılması gereken SQL veya notlar]
  ```
- Commit/test öncesi **yeni veya bu işte değiştirilmiş** migration dosyalarında ilk satır denetimi yap: yorumdan `-- ` kaldırıldığında metin `Path.GetFileName(...)` ile birebir aynı olmalıdır. Daha önce uygulanmış tarihsel migration'ları sırf biçim için topluca değiştirme.

### Ortam, Supabase CLI ve production kapısı (KRİTİK)

- Ortamlar kesin ayrıdır: `local` = Docker/CLI, `staging` = beta Supabase, `production` = stable Supabase. **Beta production backend'e, stable staging backend'e bağlanamaz.** Uyuşmazlık fail-closed hatadır.
- Tek migration dizisi kullanılır. Ortama özel SQL çatalları yasaktır; staging önde, production yalnız kabul edilmiş migration head'inde olabilir.
- Bir migration herhangi bir remote ortama uygulandıktan sonra **immutable** olur. Düzeltme yeni ileri migration ile yapılır; uygulanmış dosyayı değiştirip aynı numarayla yeniden kullanma.
- SQL/migration testi gerçek local PostgreSQL'de çalışmalıdır. Yalnız dosya içeriğinde metin arayan contract testi migration'ın çalıştığını kanıtlamaz.
- Remote işlemden önce hedef ortam + project-ref açıkça doğrulanır; `migration list` ve `db push --dry-run` çıktısı kayda alınır. Saklı/önceki `supabase link` hedefine güvenilmez.
- `supabase db reset --linked` **her remote ortamda yasaktır**. Production'da truncate/drop/toplu delete/backfill ancak açık WP, backup, dry-run ve o somut işlem için kullanıcı onayıyla yapılabilir.
- Production'a migration, Edge Function, secret, backfill, `migration repair`, stable tag/release veya push **açık deploy onayı olmadan yapılmaz**. Genel “tam yetki” gelecekteki somut production mutasyonu için onay sayılmaz.
- Production normal akışı: local replay+test → staging dry-run/push → cihaz QA → ≥3 gün beta soak → backup → production dry-run → kullanıcı GO → production push → post-check.
- `exception when others` ile kritik adımı yutup başarı döndüren migration kabul edilmez. Opsiyonel yetenek degrade oluyorsa post-check bunu release bloklayıcı olarak görünür kılar.
- Migration WP'si şu invariant'ları önce/sonra raporlar: session satır/süre toplamı, XP ledger↔profil uzlaşması, duplicate reward/ledger, RLS abuse, cron/finalizer gerçek çalışması ve Europe/Istanbul sınırları.
- Secret'lar (`SUPABASE_ACCESS_TOKEN`, DB parolası, service role, env dosyaları) repoya, test çıktısına veya kullanıcı yanıtına yazılmaz.

### Dil & Stil
- Kullanıcıya görünen metin **Türkçe**; kod/teknik isim İngilizce. Gün sınırı her yerde **Europe/Istanbul** (tek yardımcıdan).
- Kullanıcıya yanıt: Türkçe, sade, jargonu çevir.

---

## 3. Definition of Done (her WP'de zorunlu)

Bir WP "Kod tamamlandı"yı geçmek için:
- [ ] Kabul kriterleri **yazılı** ve tek tek doğrulandı (ölçülebilir; "profesyonel" gibi ifade değil — bkz. KALITE-PROGRAMI §4.4).
- [ ] **Ölü anahtar yok** — her kontrol gerçek etki üretir.
- [ ] `flutter analyze` **0 uyarı**; ilgili `flutter test` yeşil.
- [ ] Yeni mantık **birim/integration** testiyle örtülü; tema/görsel değişikliği **golden** ile.
- [ ] Boş/hata/çevrimdışı durumları ele alındı.
- [ ] RLS/güvenlik değerlendirmesi yapıldı; sır istemcide yok.
- [ ] Migration + **geri alma** planı (sunucu bağımlılığı varsa).
- [ ] Erişilebilirlik: kontrast (WCAG AA kritik metin), 48 dp dokunma, koyu/açık tema.

"Tamamlandı" (kabul) için ek: **gerçek cihaz QA kanıtı** (ekran görüntüsü/video) + **ürün sahibi kabulü**.

### Release kalite kapısı (stable çıkışı)
Şunlardan biri eksikse stable release **çıkmaz:** kritik/ağır bug 0 · migration dry-run başarılı · Supabase staging başarılı · tüm testler yeşil · Android release build başarılı · **gerçek Samsung cihaz** testi başarılı · temel kullanıcı yolculukları · widget/bildirim cold-start · recovery/admin/RLS testleri · beta soak ≥ 3 gün · rollback hazır.

---

## 4. Sürüm Yayınlama

- Release gerçeği `progress.md` Proje Gerçekleri + artefakt manifestinden okunur; eski sabit sürüm notu kopyalanmaz.
- Beta ve stable aynı build numarasını veya farklı kod için aynı version/build çiftini kullanamaz. Her artefakt kanal, git SHA, backend ortamı ve beklenen migration head taşır.
- Beta tag/release yalnız staging env ile; stable tag/release yalnız production env ile oluşturulur. Build-time doğrulama yanlış eşleşmeyi reddeder.
- Tag/push/release kullanıcı özellikle istemedikçe yapılmaz. Stable release ayrıca `docs/ORTAM-MIGRATION-YONETISIMI.md` production kapısı ve Kalite Programı DoD'sinden geçer.

---

## 5. Önemli Konumlar

| Ne | Nerede |
|---|---|
| Kanonik program/plan | `docs/KALITE-PROGRAMI.md` |
| İlerleme + Aktif Çalışma Kaydı | `progress.md` |
| Backlog | `backlog.md` · Teknik referans: `project.md` |
| Güncelleme sistemi | `app/lib/features/updater/` |
| İstatistik (saf fonksiyon) | `app/lib/core/stats/study_stats.dart` |
| Tema sistemi | `app/lib/core/theme/app_theme.dart` |
| Sayaç/timer | `app/lib/data/providers/study_providers.dart`, `features/classroom/widgets/study_timer_card.dart` |
| Saat | `app/lib/features/clock/**` |
| Native widget | `app/lib/features/android_widgets/`, `app/android/app/src/main/kotlin/**/widgets/` |
| Kamp ateşi | `app/lib/features/classroom/widgets/campfire_scene.dart` |
