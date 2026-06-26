# AGENTS.md

> Tetik: kullanıcı "**agents.md oku ve devam et**" derse → `project.md` + `progress.md` oku, aktif/sıradaki mini fazı belirle, başlamadan önce planı bir cümleyle özetle.

## Must-follow constraints
- **Tüm `flutter` komutlarını `app/` içinde çalıştır**, repo kökünde değil.
- **Her zaman `--dart-define-from-file=env.json` geç.** Anahtarlar olmadan uygulama sessizce **InMemory moda** düşer (giriş + ayarlar kaybolur, Supabase yok). CI aynı değerleri `--dart-define` ile geçer.
- **Gizli dosyalar asla commit edilmez:** `env.json`, `app/android/key.jks`, `app/android/key.properties`, `KEYSTORE_SECRETS.txt`, Supabase `service_role`. Hepsi `.gitignore`'da — commit öncesi `git status` ile doğrula.
- **Release keystore kalıcıdır.** Yayınlanan her APK `app/android/key.jks` ile imzalanır. Değişirse/kaybolursa Android güncellemeleri "imza uyuşmuyor" diye reddeder. Yeniden üretme, imza config'ini bozma.

## Validation before finishing
- Mini faz başına sıra: **(1) `progress.md`/`project.md` güncelle → (2) test et → (3) temizse commit.**
- `flutter analyze` temiz olmalı; uygunsa `flutter test` çalıştır. **Hatayla commit atma — önce düzelt.**
- Mini faz başına bir küçük commit. **Push yapma** (istenmedikçe).

## Repo-specific conventions
- Kullanıcıya görünen metinler **Türkçe**; kod/teknik isimler İngilizce. Kullanıcıya yanıtlar: Türkçe, sade, jargonu çevir.
- Geri dönüşü zor kararları tek başına verme → `project.md` "Açık Sorular"a ekle ve sor.

## Change safety rules
- **Tek yetkilendirme katmanı RLS'tir. İstemci-taraflı kontroller (ör. `joinGroup`'taki davet-kodu doğrulaması, admin rozetleri) kozmetiktir ve atlatılabilir.** Yeni her erişim kuralı bir `supabase/migrations/*.sql` politikası/RPC'sinde uygulanmalı, yalnız Dart'ta değil.
- **Migration'lar 0008→0009→0010→0011 sırayla çalışmalı** (`study_sessions.group_id` düşürme zinciri; oturum görünürlüğü artık `can_see_user_sessions` + `group_daily_totals` RPC'sinden akıyor). Sırayı bozma, kısmen uygulama.
- Migration'lar Supabase SQL editöründe elle uygulanıyor (otomatik runner yok) — yeni dosyalar `supabase/migrations/NNNN_ad.sql`, sıralı.

## Sürüm yayınlama (in-app update — GitHub Releases)
- `app/pubspec.yaml`'da `+N` build numarasını artır → `git tag vN && git push origin vN`.
- **Etiket sayısı `vN` = pubspec build numarası `+N`** — CI (`.github/workflows/release.yml`) bunu `--build-number`'a verir; şaşarsa güncelleme tetiklenmez.
- Güncelleme kontrolü yalnız Android'de; APK'lar GitHub Releases'te (Supabase tablosu yok).

## Important locations
- Güncelleme sistemi: `app/lib/features/updater/`.
- İstatistikler yalnız `study_sessions`'tan hesaplanır (istatistik tablosu yok) — saf fonksiyonlar `app/lib/core/stats/study_stats.dart`.
- Proje bağlamı/kararlar: `project.md` · İlerleme: `progress.md`.
