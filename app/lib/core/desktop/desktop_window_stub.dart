import 'package:flutter/widgets.dart';

/// Web (ve masaüstü olmayan) için no-op implementasyon. Masaüstü davranışı
/// yalnız `desktop_window_io.dart`'ta gerçekleşir.

/// Uygulama masaüstünde mi çalışıyor? Web'de her zaman `false`.
bool get isDesktopWindow => false;

/// Masaüstü penceresini hazırlar (boyut, başlık). Web'de hiçbir şey yapmaz.
Future<void> initDesktopWindow() async {}

/// Masaüstünde uygulamanın etrafına "üstte tut / mini" kontrolleri ekler.
/// Web'de child'ı olduğu gibi döndürür.
Widget desktopChrome(Widget child, {required Widget compactChild}) => child;

Widget desktopChromeBody({
  required bool isCompact,
  required Widget child,
  required Widget compactChild,
}) => isCompact ? compactChild : child;

Future<void> toggleDesktopCompactMode() async {}

Future<void> toggleDesktopAlwaysOnTop() async {}
