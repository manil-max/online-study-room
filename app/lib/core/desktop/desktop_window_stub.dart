import 'package:flutter/widgets.dart';

/// Web (ve masaüstü olmayan) için no-op implementasyon. Masaüstü davranışı
/// yalnız `desktop_window_io.dart`'ta gerçekleşir.

/// Uygulama masaüstünde mi çalışıyor? Web'de her zaman `false`.
bool get isDesktopWindow => false;

/// Masaüstü penceresini hazırlar (boyut, başlık). Web'de hiçbir şey yapmaz.
Future<void> initDesktopWindow() async {}

/// İlk frame sonrası pencere gösterimi (web no-op).
Future<void> showDesktopWindowWhenReady() async {}

/// Masaüstünde uygulamanın etrafına "üstte tut / mini" kontrolleri ekler.
/// Web'de child'ı olduğu gibi döndürür.
Widget desktopChrome(Widget child, {required Widget compactChild}) => child;

Widget desktopChromeBody({
  required bool isCompact,
  required Widget child,
  required Widget compactChild,
}) {
  if (!isCompact) return child;
  return Overlay(
    key: const ValueKey('desktop-compact-overlay'),
    initialEntries: [OverlayEntry(builder: (_) => compactChild)],
  );
}

Future<void> toggleDesktopCompactMode() async {}

Future<void> toggleDesktopAlwaysOnTop() async {}

Listenable get desktopWindowListenable => const _NoopListenable();

bool get isDesktopAlwaysOnTop => false;

bool get isDesktopCompactMode => false;

class _NoopListenable extends Listenable {
  const _NoopListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
