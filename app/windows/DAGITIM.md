# Windows Masaüstü — Derleme ve Dağıtım Notları (WP-11)

Odak Kampı'nın Windows sürümü **normal bir Flutter masaüstü uygulamasıdır**.
"Windows widget" ayrı bir OS bileşeni değildir; **üstte kalan mini Flutter
penceresidir** (sağ üstteki 📌 / 🖼 kontrolleriyle açılır).

## Gereksinimler (derleme makinesi)
- **Visual Studio 2022** + **"Desktop development with C++"** iş yükü
  (MSVC, Windows 10/11 SDK, CMake). `flutter doctor` çıktısında
  `[√] Visual Studio - develop Windows apps` görünmeli.
- Flutter stable (proje: 3.44.x ile denendi).

> Not: CI ve mevcut geliştirme makinesinde Visual Studio **kurulu değildi**,
> bu yüzden Windows derlemesi henüz **yerel olarak doğrulanmadı**. Dart tarafı
> `flutter analyze` ile temiz; Android derlemesi `window_manager` eklendikten
> sonra da geçiyor. Windows build'i VS kurulu bir makinede ilk kez alınmalı.

## Derleme
```powershell
cd app
flutter config --enable-windows-desktop   # bir kez
flutter build windows --release --dart-define-from-file=env.json
```
Çıktı:
```
app\build\windows\x64\runner\Release\
  online_study_room.exe        # çalıştırılabilir
  flutter_windows.dll, *.dll   # motor + eklenti kütüphaneleri
  data\                        # Flutter asset/ICU verisi
```
Bu **Release klasörünün tamamı** birlikte dağıtılmalıdır (exe tek başına çalışmaz).

## Dağıtım seçenekleri
1. **ZIP (en basit):** `Release\` klasörünü zip'le, kullanıcı açıp `.exe`'yi
   çalıştırır. Kurulum gerektirmez (portable).
2. **Installer (önerilen, sonraki adım):** [Inno Setup] veya MSIX ile tek
   `.exe`/`.msix` kurulum paketi. Başlat menüsü kısayolu + kaldırma sağlar.
   - MSIX için: `msix` paketi + `flutter pub run msix:create`.
   - Kod imzalama sertifikası yoksa SmartScreen uyarısı çıkar (beklenen).

## Güncelleme
Android'deki GitHub-Releases otomatik güncelleyici **yalnız Android**'de çalışır
(`updater_service.dart` → `Platform.isAndroid`). Windows için otomatik güncelleme
şimdilik yok; yeni sürüm elle dağıtılır. (Sonraki WP: Windows updater / installer.)

## Mini pencere (üstte kalan)
- Sağ üstteki 📌 **her zaman üstte tut**, 🖼 **mini pencere** (≈320×184, köşeye
  sabit, daima üstte) kontrolleri masaüstünde otomatik görünür.
- Mini moddan 🔳 ile tam boyuta dönülür.
- Kontroller `lib/core/desktop/` altında; web/mobilde otomatik devre dışı.
