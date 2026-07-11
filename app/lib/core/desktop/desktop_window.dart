/// Masaüstü (Windows/macOS/Linux) pencere yardımcıları — WP-11.
///
/// Web'de `window_manager` kullanılamaz (dart:io yok), bu yüzden koşullu import
/// ile web'e no-op stub, native platformlara gerçek implementasyon verilir.
/// Native'de de yalnız masaüstünde iş yapar; mobilde çağrılar sessizce geçer.
library;

export 'desktop_window_stub.dart'
    if (dart.library.io) 'desktop_window_io.dart';
