# Odak Kampı - Dağıtım (Distribution) Notları

## İkonlar ve Markalama (WP-29)

- **Android İkonları:** `app/android/app/src/stable` ve `app/android/app/src/beta` altında ayrıştırılmıştır. Adaptive Icon (API 26+) yapılandırması mevcuttur.
- **Windows İkonu:** `app/windows/runner/resources/app_icon.ico` altında güncellenmiştir.
  - Windows release build alırken RC dosyası `IDI_APP_ICON` değerini bu `.ico` dosyasından okur.
