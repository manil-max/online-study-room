import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';

/// Masaüstü yüzey ölçüleri — mobil full-bleed yerine okunabilir panel.
class DesktopSurface {
  const DesktopSurface._();

  /// Form / ayar / stüdyo paneli — **taban** genişlik (pencere < 1200).
  ///
  /// 🔴 WP-684 ÖLÇÜMÜ (2026-08-10, HEAD `72ee426`): bu sayı bir *tabandı*
  /// değil, **tavandı**. Panel `SizedBox(width: 920)` içinde açılıyordu ve
  /// ayarlar içeriği 1008 / 1200 / 1920 / 2560 px pencerelerin **hepsinde**
  /// 844 px çizildi (`WP684PANEL` dökümü). Yani SPEC §1.2 pencere merdiveni
  /// bu ekran ailesinde hiçbir zaman tetiklenmiyordu; 2560 px'lik bir
  /// monitörde de 1008 px'lik bir laptopta da aynı kare boyanıyordu.
  static const double panelWidth = 920;
  static const double panelHeight = 680;

  /// Panel gövdesinin kendi yatay kenar boşluğu: 2 × 16 px.
  ///
  /// Uydurma değil, kodda okundu: panel içinde açılan ekranların gövdesi
  /// `EdgeInsets.fromLTRB(16, 12, 16, 24)` ile çizilir
  /// (`settings_screen.dart`, `ProfileFlowColumns`'ın gördüğü kap
  /// = panel genişliği − 32). Panelin DIŞ genişliği = iç hedef + bu.
  static const double panelChrome = 32;

  /// `large` (1200–1599) panel genişliği.
  ///
  /// İç hedef = SPEC §3 A1 master–detay satırı: **280** (master sütunu)
  /// + **16** (boşluk) + **760** (detay = form sütunu) = 1056.
  /// 1056 + [panelChrome] = **1088**, 4'ün katı (WinUI ölçek platosu kuralı).
  static const double panelWidthLarge = 1088;

  /// `xlarge` (≥ 1600) panel genişliği — **mutlak tavan**.
  ///
  /// İç hedef = SPEC §2.3 "Izgara / pano toplamı" = **1440**
  /// ([DesktopBreakpoints.maxContentWidth]).
  /// 1440 + [panelChrome] = **1472**, 4'ün katı.
  ///
  /// Neden bir tavan var: panel bir `Dialog`tır, ekranı kaplamaz. 2560 px'lik
  /// pencerede de 1472'de durur; artan yer iki yana boşluk olur. Tavanı
  /// SPEC'in ızgara toplamına bağlamak, panelin içindeki ekranın zaten
  /// uymak zorunda olduğu sınırla aynı sayıyı kullanır — panel içeriğinden
  /// geniş olamaz.
  static const double panelWidthXLarge = 1472;

  /// Geniş stüdyo (tema) — **taban** genişlik.
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

/// [showDesktopPanel] gövdesinin anahtarı — genişliği verilen kutu.
const Key kDesktopPanelBodyKey = Key('desktop-panel-body');

/// Panel genişliğini **pencere genişliğine** bağlar (SPEC §1.2 merdiveni).
///
/// | pencere sınıfı | iç hedef | + [DesktopSurface.panelChrome] | panel |
/// |---|---:|---:|---:|
/// | < 1200 (`minimal`/`compact`/`expanded`) | 888 (bugünkü bant) | 32 | **920** |
/// | 1200–1599 (`large`) | 1056 = 280 + 16 + 760 (SPEC §3 A1) | 32 | **1088** |
/// | ≥ 1600 (`xlarge`) | 1440 (SPEC §2.3 ızgara toplamı) | 32 | **1472** |
///
/// 1200'ün altı **bilerek değişmez**: WP-679'un ayarlar düzeni ölçülerek o
/// 888 px'lik banda oturtuldu (`kProfileTwoColumnBand = 880`), ve 1008–1199
/// bandında 1088'lik bir panel zaten `media.width − 48`e sıkışırdı.
///
/// [base] bir **taban**dır, tavan değil: stüdyo gibi bugün daha geniş açılan
/// yüzeyler merdivenin altına düşmez.
///
/// 🔴 Bu fonksiyon PENCERE genişliğini alır, panelin kendi kabını değil.
/// Panelin içindeki `MediaQuery` hâlâ tüm pencereyi verir; oradaki bir
/// `LayoutBuilder` panel bandını görür. İkisi karıştırılırsa panel kendi
/// genişliğini kendi genişliğinden hesaplamaya çalışır.
double desktopPanelWidthFor(
  double windowWidth, {
  double base = DesktopSurface.panelWidth,
}) {
  final ladder = switch (DesktopBreakpoints.windowClass(windowWidth)) {
    DesktopNavigationMode.minimal ||
    DesktopNavigationMode.compact ||
    DesktopNavigationMode.expanded => DesktopSurface.panelWidth,
    DesktopNavigationMode.large => DesktopSurface.panelWidthLarge,
    DesktopNavigationMode.xlarge => DesktopSurface.panelWidthXLarge,
  };
  return ladder < base ? base : ladder;
}

/// Masaüstünde ortalanmış panel (dialog + iç Navigator).
/// Mobilde klasik [MaterialPageRoute] push.
///
/// Böylece Ayarlar → Görünüm → Tema zinciri panel içinde kalır;
/// tüm pencereyi “mobil tam ekran kaydırma” gibi doldurmaz.
///
/// [width] verilmezse genişlik [desktopPanelWidthFor] ile pencereye bağlanır;
/// [baseWidth] o merdivenin tabanıdır.
Future<T?> showDesktopPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? width,
  double height = DesktopSurface.panelHeight,
  double baseWidth = DesktopSurface.panelWidth,
}) {
  if (!isDesktopWindow) {
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: builder));
  }

  final media = MediaQuery.sizeOf(context);
  final target =
      width ?? desktopPanelWidthFor(media.width, base: baseWidth);
  final w = target.clamp(360.0, media.width - 48);
  final h = height.clamp(360.0, media.height - 48);

  // Panel kendi `Navigator`ını taşır; o iç rota Esc'i yutuyordu ve Ayarlar
  // paneli klavyeyle kapanmıyordu (WP-569 cihaz ölçümü). Esc önce panel içi
  // geçmişi geri alır, geçmiş bitince paneli kapatır — Windows sözleşmesi.
  final panelNavigator = GlobalKey<NavigatorState>();

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
          // 🔴 Testler panelin GENISLIGINI buradan okur. `Dialog`in kendi
          // render kutusu tum pencereyi kaplar (`getSize(find.byType(Dialog))`
          // 2560 px pencerede 2560 dondurur) — yani Dialog'u olcmek paneli
          // degil KABI olcer. Olculecek kutu, genisligi verilen kutudur.
          key: kDesktopPanelBodyKey,
          width: w,
          height: h,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                final navigator = panelNavigator.currentState;
                if (navigator != null && navigator.canPop()) {
                  navigator.pop();
                } else {
                  Navigator.of(dialogContext).pop();
                }
              },
            },
            child: Focus(
              autofocus: true,
              child: Navigator(
                key: panelNavigator,
                onGenerateRoute: (settings) {
                  return MaterialPageRoute<T>(
                    settings: settings,
                    builder: builder,
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Geniş stüdyo paneli (tema vb.).
///
/// Aynı merdiveni kullanır, tabanı bugünkü 1040 px: stüdyo hiçbir pencerede
/// bugünkünden dar açılmaz, ama 1200 ve 1600'de panelle birlikte büyür.
Future<T?> showDesktopStudio<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDesktopPanel<T>(
    context: context,
    builder: builder,
    baseWidth: DesktopSurface.studioWidth,
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
