# Codex görevi — FAZ 2I: Ayarlar Overhaul

Sen Codex'sin ve **Claude ile AYNI ANDA, paralel** çalışıyorsun. Claude FAZ 2G'yi
(classroom kamp ateşi ekranı) yapıyor. Çakışmayı önlemek için **sadece aşağıdaki dosyalara
yazabilirsin**; başkasına dokunma.

## Proje
- Flutter uygulaması, kök: `app/`. Riverpod 3.x (Notifier/Provider), Supabase.
- Kalıcı ayarlar `shared_preferences` ile (`app/lib/core/prefs/app_prefs.dart` →
  `sharedPreferencesProvider`; `main()` içinde override edilir).
- Çalıştırma: `cd app && flutter analyze` (temiz olmalı) + `flutter test` (geçmeli).
  Gerekirse `flutter run -d chrome --web-port=5005 --dart-define-from-file=env.json`.
- Detaylı bağlam: `progress.md` içinde **"⚡ PARALEL ÇALIŞMA — Dosya Sahipliği"** ve
  **"2I · Ayarlar overhaul"** bölümlerini oku.

## SENİN SAHİP OLDUĞUN DOSYALAR (yalnız bunlara yaz)
- `app/lib/features/profile/settings_screen.dart`
- `app/lib/features/profile/profile_screen.dart`  (ayar giriş noktaları)
- `app/lib/features/profile/appearance_screen.dart`  (gerekirse)
- Yeni: `app/lib/features/profile/widgets/*`
- `app/lib/core/prefs/*`  (yeni pref anahtarı gerekirse)
- **SINIRLI izin:** `app/lib/features/home/home_screen.dart` — SADECE düzenleme modunun
  AppBar'ına "Ana Sayfa'yı sıfırla" butonu eklemek için. Grid/reflow/sürükle/boyutlandırma
  koduna **DOKUNMA**. (`ref.read(dashboardLayoutProvider.notifier).reset()` zaten var.)

## ASLA DOKUNMA (Claude'un veya Tur 2'nin alanı)
`app/lib/features/classroom/*`, `data/providers/presence_providers.dart`,
`app/lib/features/home/dashboard_card.dart`, `app/lib/features/home/dashboard_providers.dart`,
`app/lib/features/classroom/widgets/study_timer_card.dart`,
`app/lib/features/classroom/widgets/focus_timer_screen.dart`.

## Yapılacaklar
1. **Ayarlar menüsünü gruplu, genişletilebilir bir yapıya çevir.** Şu an
   `settings_screen.dart` düz bir `ListView` (bkz. mevcut hali). Bunu kategorili bölümlere
   ayır — mantıklı gruplar: **Görünüm** (tema/palet — mevcut `AppearanceScreen`'e giriş),
   **Ana Sayfa** (Gruplar'da sayaç anahtarı + sıfırlama), **Sayaç** (placeholder — Tur 2'de
   2H dolduracak), **Bildirimler** (placeholder — §5'e ait, şimdilik boş/pasif). "Her şey
   özelleştirilebilir" iskeleti hissi ver ama var olmayan özellik için sahte anahtar koyma;
   placeholder'ları "yakında" olarak pasif göster.
2. **Ana ekran sıfırlama butonunu ana ayarlardan çıkar, ana ekran DÜZENLEME menüsüne taşı.**
   - `settings_screen.dart`'taki "Ana Sayfa'yı sıfırla" ListTile'ını kaldır (veya Ana Sayfa
     grubunda yalnız düzenlemeye yönlendiren bir ipucu bırak).
   - `home_screen.dart` düzenleme modunun AppBar'ına (edit mode aktifken görünen) bir
     "Sıfırla" aksiyonu ekle; aynı onay diyaloğu + `reset()` çağrısı. **Sadece bu buton;
     grid koduna dokunma.**
3. `profile_screen.dart`'taki "Ayarlar" ListTile alt yazısını güncel yapıya göre güncelle.

## Kurallar
- Mevcut prefs anahtarlarını bozma (`classroomShowTimerProvider`, tema/palet, dashboard düzeni).
- `dashboardLayoutProvider.reset()` mevcut davranışı korunsun (onay diyaloğu + snackbar).
- Bitince: `cd app && flutter analyze` temiz, `flutter test` geçsin. Bozulan test varsa düzelt.
- `progress.md`'de 2I maddesini `[x]` yap ve kısa bir "Uygulandı (2026-07-10)" notu ekle —
  ama progress.md'de **sadece 2I ile ilgili satırları** değiştir (Claude 2G'yi işaretleyecek).

## Kabul kriteri
Ayarlar menüsü gruplu/kategorili; Ana Sayfa sıfırlama artık düzenleme menüsünden erişiliyor
(ana ayarlarda değil); mevcut prefs bozulmuyor; analyze temiz, testler geçiyor.
