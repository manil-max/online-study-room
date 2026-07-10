# AGENTS.md — Proje Kuralları

> Bu dosya tüm ajanların her zaman uyması gereken kurallardır.
> İş paketi (WP) sistemi için → `skills/planner/SKILL.md` ve `skills/worker/SKILL.md`.

---

## İş Paketi (WP) Sistemi

Proje **tek faz, iş paketi** (Work Package) tabanlı ilerler:
- `backlog.md` → yapılacak tüm işler (öncelik sıralı)
- `progress.md` → aktif WP'ler + son tamamlananlar + geçmiş tablo
- `project.md` → teknik referans (mimari, veri modeli, güvenlik)

**Tetik:** Kullanıcı "progress.md oku ve WP-N'yi yap" derse → `progress.md` oku, kendi WP'ni bul, adımları sırayla uygula.

---

## Zorunlu Kurallar

### Derleme & Çalıştırma
- **Tüm `flutter` komutlarını `app/` içinde çalıştır**, repo kökünde değil.
- **Her zaman `--dart-define-from-file=env.json` geç.** Anahtarlar olmadan uygulama sessizce InMemory moda düşer (giriş + ayarlar kaybolur, Supabase yok).
- CI aynı değerleri `--dart-define` ile geçer.

### Güvenlik & Gizlilik
- **Gizli dosyalar asla commit edilmez:** `env.json`, `app/android/key.jks`, `app/android/key.properties`, `KEYSTORE_SECRETS.txt`, Supabase `service_role`. Hepsi `.gitignore`'da — commit öncesi `git status` ile doğrula.
- **Release keystore kalıcıdır.** `app/android/key.jks` değişirse/kaybolursa Android güncellemeleri reddeder. Yeniden üretme, imza config'ini bozma.
- **Tek yetkilendirme katmanı RLS'tir.** İstemci-taraflı kontroller kozmetiktir. Yeni erişim kuralı → `supabase/migrations/*.sql` politikası/RPC'sinde uygulanmalı.

### Veritabanı & Migration
- **Migration'lar sırayla çalışmalı** (0001→...→0013). Sırayı bozma, kısmen uygulama.
- Migration'lar Supabase SQL Editor'da elle uygulanıyor — yeni dosyalar `supabase/migrations/NNNN_ad.sql`, sıralı.
- Repo katmanı **çift implementasyonludur**: her arayüz hem `supabase/` hem `in_memory/` altında. İkisi de güncellenmeli yoksa demo/offline mod kırılır.

### Doğrulama & Commit
- WP başına sıra: **(1) progress.md güncelle → (2) test et → (3) temizse commit.**
- `flutter analyze` temiz olmalı; uygunsa `flutter test` çalıştır. **Hatayla commit atma — önce düzelt.**
- WP başına bir commit. **Push yapma** (istenmedikçe).

### Dil & Stil
- Kullanıcıya görünen metinler **Türkçe**; kod/teknik isimler İngilizce.
- Kullanıcıya yanıtlar: Türkçe, sade, jargonu çevir.

### Paralel Çalışma
- **Sadece kendi WP'nin SAHİP dosyalarına yaz.** Başka WP'nin dosyasına ASLA dokunma; oku ama değiştirme.
- `progress.md`'de sadece kendi WP bölümünü düzenle.
- Yeni dosya eklemek serbest ama yalnız kendi feature klasörüne.
- Her WP sonunda `cd app && flutter analyze` temiz + `flutter test` geçmeli.

### Karar Alma
- Geri dönüşü zor kararları tek başına verme → `backlog.md` "Açık Sorular"a ekle ve kullanıcıya sor.

---

## Sürüm Yayınlama (GitHub Releases)

- `app/pubspec.yaml`'da `+N` build numarasını artır → `git tag vN && git push origin vN`.
- **Etiket sayısı `vN` = pubspec build numarası `+N`** — CI (`.github/workflows/release.yml`) bunu `--build-number`'a verir.
- Güncelleme kontrolü yalnız Android; APK'lar GitHub Releases'te.

---

## Önemli Konumlar

| Ne | Nerede |
|---|---|
| Güncelleme sistemi | `app/lib/features/updater/` |
| İstatistik hesaplama | `app/lib/core/stats/study_stats.dart` (saf fonksiyonlar) |
| Grid reflow motoru | `app/lib/core/grid/grid_reflow.dart` |
| Dashboard kartları | `app/lib/features/home/widgets/` (19 tür) |
| Kamp ateşi sahnesi | `app/lib/features/classroom/widgets/campfire_scene.dart` |
| Sayaç/timer | `app/lib/features/classroom/widgets/study_timer_card.dart` |
| Tema sistemi | `app/lib/core/theme/app_theme.dart` (5 palet) |
| Proje bağlamı | `project.md` · İlerleme: `progress.md` · Backlog: `backlog.md` |
