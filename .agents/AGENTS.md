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
- Dal: wp40-timer-foreground   (veya: main — ayrık dosyalarla)
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

### 1.5 Git disiplini — WP başına ayrı dal (VARSAYILAN)

Paralel ajanlar aynı `main` dalında commit atarsa `pubspec.yaml`, `progress.md`, generated dosyalar merge conflict üretir. Bu yüzden **her WP kendi dalında çalışır:**

1. **Başlarken dal aç:** `git switch -c wpNN-kisa-ad` (ör. `wp40-timer-foreground`). `progress.md` claim'ine dal adını yaz.
2. Tüm commit'ler **o dala** gider. WP başına **tek commit**. **Push yok** (kullanıcı istemedikçe).
3. **Merge kullanıcıya aittir.** Ajan `main`'e merge ETMEZ; WP "Ürün kabulü"nden geçince kullanıcı birleştirir:
   ```bash
   git switch main
   git merge wpNN-kisa-ad      # temizse birleşir; çakışma çıkarsa kullanıcı çözer
   git branch -d wpNN-kisa-ad  # birleşen dalı sil
   ```
4. Böylece paralel WP'ler birbirini kirletmez; olası çakışma yalnız **merge anında, kontrollü** çıkar.

> Solo geliştirici notu: Her iş ayrı bir "taslak katman"dır; beğenip kabul edince `main`'e alırsın, beğenmezsen dalı silersin — `main` hep temiz kalır. İzole gerçek paralellik için `git worktree` de kullanılabilir; şart değil.

**Merge otomasyonu = A (seçildi 2026-07-12):** Merge elle yapılmaz. WP dalı push edilir → `gh pr create` → CI (`.github/workflows/ci.yml`) `analyze`+`test` çalıştırır → yeşilse **PR `main`'e auto-merge** olur (squash) ve dal silinir. Böylece merge otomatiktir ve **testten geçmeyen kod main'e giremez** (kalite kapısı). Kurulum: **WP-39**. Bu, WP dallarının public repo'ya **push edilmesini** gerektirir (kullanıcı A'yı seçerek onayladı). Auto-merge/branch-protection repo ayarlarını **kullanıcı açar**.

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
- Migration'lar **sırayla** çalışır (`NNNN_ad.sql`, son numaradan devam). Sırayı bozma, kısmen uygulama. Canlı Supabase'e SQL Editor'dan uygulanır; her WP kendi migration + geri alma notunu getirir.

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

- v7 **zaten yayında** (özellik sürümü). İlk **kalite-kapılı** stable önerisi: **v8 "Güven Sürümü"**. Numara kalite kapısından geçmeden kesinleşmez → `Ürün kararı gerekiyor`.
- `app/pubspec.yaml`'da `+N` artır → `git tag vN && git push origin vN`. **Etiket `vN` = build `+N`** (CI `--build-number`'a verir). Güncelleme kontrolü yalnız Android; APK'lar GitHub Releases'te.

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
