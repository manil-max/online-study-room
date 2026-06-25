# AGENTS.md

> Tetik: kullanıcı "**agents.md oku ve devam et**" derse → `project.md` ve `progress.md` oku,
> aktif/sıradaki mini fazı belirle, başlamadan önce planı bir cümleyle özetle.

## Must-follow constraints
- **Flutter projesinin kökü `app/` alt klasörüdür.** `flutter` komutlarını `app/` içinde çalıştır (repo kökünde değil).
- **Uygulamayı `--dart-define-from-file=env.json` olmadan çalıştırma/derleme.** Anahtarlar verilmezse uygulama sessizce **InMemory moda** düşer → giriş ve ayarlar kaybolur. Örn: `flutter run --dart-define-from-file=env.json`. CI'da aynı değerler `--dart-define` ile geçilmeli.
- **Gizli dosyalar repoya ASLA girmez:** `env.json`, `app/android/key.jks`, `app/android/key.properties`, `KEYSTORE_SECRETS.txt`, Supabase `service_role`. Hepsi `.gitignore`'da; commit'ten önce `git status` ile doğrula.
- **Tek release keystore kalıcıdır.** Yayınlanan tüm APK'lar `app/android/key.jks` ile imzalanır. Bu anahtar değişirse/kaybolursa Android güncellemeleri "imza uyuşmuyor" diye reddeder — yeni anahtar üretme/imza config'ini bozma.

## Validation before finishing
- Mini faz bitince sıra: **(1) `progress.md`/`project.md` güncelle → (2) test et → (3) sorun yoksa commit.**
- Test: `flutter analyze` temiz olmalı + uygunsa `flutter test`. **Hata varsa commit ATMA, önce düzelt.**
- Mini faz başına bir küçük commit. **Push yapma** (kullanıcı istemedikçe).

## Change safety rules
- Geri dönüşü zor kararları tek başına verme → `project.md` > "Açık Sorular"a ekle ve kullanıcıya sor.
- UI'a görünen metinler **Türkçe**; kod/teknik isimler İngilizce.
- Kullanıcı Türkçe konuşur; açıklamaları sade tut, jargonu çevir.

## Sürüm yayınlama (in-app update — GitHub Releases)
- Yeni sürüm: `app/pubspec.yaml`'da `version`'ın `+N` build numarasını artır → `git tag vN && git push origin vN`.
- **Etiketteki sayı (`vN`) = pubspec build numarası (`+N`).** CI (`.github/workflows/release.yml`) bunu `--build-number` olarak kullanır; ikisi şaşarsa güncelleme tetiklenmez.
- Güncelleme kontrolü yalnız Android'de çalışır; APK GitHub Releases'te tutulur (Supabase tablosu yok).

## Important locations
- Supabase migration'ları: `supabase/migrations/NNNN_ad.sql` (sıralı numara).
- Güncelleme sistemi: `app/lib/features/updater/`.
- Proje bağlamı/kararlar: `project.md` · İlerleme: `progress.md`.
