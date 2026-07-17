import 'package:flutter/material.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';

/// Masaüstü yüzey ölçüleri — mobil full-bleed yerine okunabilir panel.
class DesktopSurface {
  const DesktopSurface._();

  /// Form / ayar / stüdyo paneli.
  static const double panelWidth = 920;
  static const double panelHeight = 680;

  /// Geniş stüdyo (tema).
  static const double studioWidth = 1040;
  static const double studioHeight = 720;

  /// Okuma genişliği (liste sayfaları ortalanır).
  static const double readingWidth = 760;

  /// Kart seçici / picker.
  static const double pickerWidth = 720;
  static const double pickerHeight = 560;
}

/// İçeriği masaüstünde ortalar ve max genişlikle sınırlar.
/// Mobilde child olduğu gibi geçer.
class DesktopReadingBody extends StatelessWidget {
  const DesktopReadingBody({
    required this.child,
    this.maxWidth = DesktopSurface.readingWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindow) {
      return Padding(padding: padding, child: child);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Masaüstünde ortalanmış panel (dialog + iç Navigator).
/// Mobilde klasik [MaterialPageRoute] push.
///
/// Böylece Ayarlar → Görünüm → Tema zinciri panel içinde kalır;
/// tüm pencereyi “mobil tam ekran kaydırma” gibi doldurmaz.
Future<T?> showDesktopPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = DesktopSurface.panelWidth,
  double height = DesktopSurface.panelHeight,
}) {
  if (!isDesktopWindow) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: builder),
    );
  }

  final media = MediaQuery.sizeOf(context);
  final w = width.clamp(360.0, media.width - 48);
  final h = height.clamp(360.0, media.height - 48);

  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        backgroundColor: scheme.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: w,
          height: h,
          child: Navigator(
            onGenerateRoute: (settings) {
              return MaterialPageRoute<T>(
                settings: settings,
                builder: builder,
              );
            },
          ),
        ),
      );
    },
  );
}

/// Geniş stüdyo paneli (tema vb.).
Future<T?> showDesktopStudio<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDesktopPanel<T>(
    context: context,
    builder: builder,
    width: DesktopSurface.studioWidth,
    height: DesktopSurface.studioHeight,
  );
}

/// Masaüstü: dialog picker; mobil: bottom sheet içeriği [builder] ile.
Future<T?> showDesktopPicker<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = DesktopSurface.pickerWidth,
  double height = DesktopSurface.pickerHeight,
}) {
  if (!isDesktopWindow) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: builder,
    );
  }

  final media = MediaQuery.sizeOf(context);
  final w = width.clamp(360.0, media.width - 48);
  final h = height.clamp(320.0, media.height - 48);

  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: w, height: h, child: builder(dialogContext)),
      );
    },
  );
}

/// Geniş ekranda kaç sütun (grid) kullanılacağını verir.
int desktopGridColumns(
  double width, {
  int compact = 2,
  int medium = 3,
  int expanded = 4,
}) {
  if (width >= DesktopBreakpoints.expanded) return expanded;
  if (width >= 720) return medium;
  return compact;
}
