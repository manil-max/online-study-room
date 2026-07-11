import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Masaüstü (Windows/macOS/Linux) gerçek implementasyonu — WP-11.
/// Mobil native platformlarda (Android/iOS) `_isDesktop` false olduğundan tüm
/// çağrılar no-op'tur; `window_manager` yalnız masaüstünde devreye girer.

bool get _isDesktop =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;

bool get isDesktopWindow => _isDesktop;

const Size _kDefaultSize = Size(1100, 720);
const Size _kDefaultMinSize = Size(360, 480);
const Size _kMiniSize = Size(320, 184);
const Size _kMiniMinSize = Size(260, 140);

Future<void> initDesktopWindow() async {
  if (!_isDesktop) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: _kDefaultSize,
    minimumSize: _kDefaultMinSize,
    center: true,
    title: 'Odak Kampı',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Widget desktopChrome(Widget child) {
  debugPrint('### desktopChrome CALLED, _isDesktop=$_isDesktop, '
      'platform=$defaultTargetPlatform');
  if (!_isDesktop) return child;
  return _DesktopChrome(child: child);
}

/// Uygulamanın sağ üstüne küçük bir "üstte tut / mini pencere" kontrol kümesi
/// bindirir. Mini modda pencere küçülür ve daima üstte kalır (kamp arkadaşlarını
/// izlerken masaüstünde köşede duran mini sayaç penceresi gibi).
class _DesktopChrome extends StatefulWidget {
  const _DesktopChrome({required this.child});

  final Widget child;

  @override
  State<_DesktopChrome> createState() => _DesktopChromeState();
}

class _DesktopChromeState extends State<_DesktopChrome> {
  bool _pinned = false;
  bool _mini = false;
  bool _busy = false;

  Future<void> _togglePin() async {
    if (_busy) return;
    _busy = true;
    final next = !_pinned;
    await windowManager.setAlwaysOnTop(next);
    if (mounted) setState(() => _pinned = next);
    _busy = false;
  }

  Future<void> _toggleMini() async {
    if (_busy) return;
    _busy = true;
    if (_mini) {
      // Tam boyuta dön: önce boyutu büyüt, sonra minimum sınırı geri yükselt.
      await windowManager.setSize(_kDefaultSize);
      await windowManager.setMinimumSize(_kDefaultMinSize);
      await windowManager.center();
      if (!_pinned) await windowManager.setAlwaysOnTop(false);
      if (mounted) setState(() => _mini = false);
    } else {
      // Mini moda geç: minimum sınırı düşür, küçült, köşeye al, üstte tut.
      await windowManager.setMinimumSize(_kMiniMinSize);
      await windowManager.setSize(_kMiniSize);
      await windowManager.setAlignment(Alignment.topRight);
      await windowManager.setAlwaysOnTop(true);
      if (mounted) {
        setState(() {
          _mini = true;
          _pinned = true;
        });
      }
    }
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('### _DesktopChrome.build RUNNING (pill should render)');
    // GECICI TESHIS: build sonucu gercekten ekrana yansiyor mu?
    return const ColoredBox(color: Color(0xFFFF0000));
    // ignore: dead_code
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        // GECICI TESHIS: sade kirmizi kutu — Stack/Positioned boyaniyor mu?
        Positioned(
          top: 40,
          right: 40,
          child: IgnorePointer(
            child: Container(width: 64, height: 64, color: const Color(0xFFFF0000)),
          ),
        ),
        // Kontrol pili kendi Overlay'ine sarılır: MaterialApp.builder'da
        // Navigator'ın kardeşi olduğumuz için üstümüzde bir Overlay yok ve
        // IconButton tooltip'leri `Overlay.of(context)` arar. Kendi
        // Overlay'imizi vererek "No Overlay widget found" hatasını önler ve
        // tooltip'leri korunmuş oluruz. Boş alan tıklamayı emmez; alttaki
        // uygulama etkileşimi bozulmadan devam eder.
        Positioned.fill(
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.82),
                      elevation: 3,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _pinned
                                  ? 'Üstte tutmayı bırak'
                                  : 'Her zaman üstte tut',
                              isSelected: _pinned,
                              icon: Icon(
                                _pinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 18,
                              ),
                              onPressed: _togglePin,
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _mini ? 'Tam boyuta dön' : 'Mini pencere',
                              isSelected: _mini,
                              icon: Icon(
                                _mini
                                    ? Icons.fullscreen
                                    : Icons.picture_in_picture_alt_outlined,
                                size: 18,
                              ),
                              onPressed: _toggleMini,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
