import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_layout.dart';

bool get _isDesktop => defaultTargetPlatform == TargetPlatform.windows;

bool get isDesktopWindow => _isDesktop;

const _defaultSize = Size(1100, 720);
const _defaultMinimumSize = Size(560, 540);
const _compactSize = Size(360, 220);
const _compactMinimumSize = Size(320, 180);

class _PreferenceKeys {
  static const x = 'desktop.window.x';
  static const y = 'desktop.window.y';
  static const width = 'desktop.window.width';
  static const height = 'desktop.window.height';
  static const maximized = 'desktop.window.maximized';
  static const pinned = 'desktop.window.pinned';
  static const compact = 'desktop.window.compact';
}

final _controller = _DesktopWindowController();

Future<void> initDesktopWindow() => _controller.initialize();

/// İlk Flutter frame çizildikten sonra çağrılmalı (WP-53-debug cold-start).
/// Aksi halde Windows boş/beyaz HWND gösterebilir.
Future<void> showDesktopWindowWhenReady() =>
    _controller.showWhenFlutterReady();

Future<void> toggleDesktopCompactMode() => _controller.toggleCompactMode();

Future<void> toggleDesktopAlwaysOnTop() => _controller.toggleAlwaysOnTop();

Widget desktopChrome(Widget child, {required Widget compactChild}) {
  if (!_isDesktop) return child;
  return _DesktopChrome(compactChild: compactChild, child: child);
}

@visibleForTesting
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

class _DesktopWindowController extends ChangeNotifier with WindowListener {
  SharedPreferences? _preferences;
  bool _initialized = false;
  bool _shown = false;
  bool _busy = false;
  bool _isCompact = false;
  bool _isPinned = false;
  bool _normalWasMaximized = false;
  Rect _normalBounds = const Rect.fromLTWH(100, 100, 1100, 720);
  Timer? _saveTimer;

  bool get isCompact => _isCompact;
  bool get isPinned => _isPinned;

  Future<void> initialize() async {
    if (!_isDesktop || _initialized) return;
    _initialized = true;
    await windowManager.ensureInitialized();
    _preferences = await SharedPreferences.getInstance();

    final primary = await screenRetriever.getPrimaryDisplay();
    final displays = await screenRetriever.getAllDisplays();
    final primaryArea = _workArea(primary);
    final saved = Rect.fromLTWH(
      _preferences?.getDouble(_PreferenceKeys.x) ??
          primaryArea.left + (primaryArea.width - _defaultSize.width) / 2,
      _preferences?.getDouble(_PreferenceKeys.y) ??
          primaryArea.top + (primaryArea.height - _defaultSize.height) / 2,
      _preferences?.getDouble(_PreferenceKeys.width) ?? _defaultSize.width,
      _preferences?.getDouble(_PreferenceKeys.height) ?? _defaultSize.height,
    );
    _normalBounds = clampDesktopWindowBounds(
      requested: saved,
      workAreas: displays.map(_workArea).toList(),
      primaryWorkArea: primaryArea,
      minimumSize: _defaultMinimumSize,
    );
    _normalWasMaximized =
        _preferences?.getBool(_PreferenceKeys.maximized) ?? false;
    _isPinned = _preferences?.getBool(_PreferenceKeys.pinned) ?? false;
    // Compact Focus bir oturum-içi çalışma yüzeyidir. Cold-start'ta Flutter
    // yüzeyi hazır olmadan 360×220 pencere göstermek bazı Windows 11/GPU
    // kombinasyonlarında gri/boş ilk frame üretiyor. Normal bounds ve pin
    // korunur; uygulama her açılışta güvenli normal kabukla başlar.
    _isCompact = false;
    await _preferences?.setBool(_PreferenceKeys.compact, false);

    // skipTaskbar: false; show henüz YOK — Flutter ilk frame sonrası
    // [showWhenFlutterReady] çağırır (beyaz boş HWND önlemi).
    final options = WindowOptions(
      size: _normalBounds.size,
      minimumSize: _defaultMinimumSize,
      center: false,
      title: 'Odak Kampı',
      titleBarStyle: TitleBarStyle.normal,
      backgroundColor: const Color(0xFF0B1020),
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setBounds(_normalBounds);
      await windowManager.setAlwaysOnTop(_isPinned);
      // show/focus/maximize → showWhenFlutterReady
    });
    windowManager.addListener(this);
  }

  Future<void> showWhenFlutterReady() async {
    if (!_isDesktop || !_initialized || _shown) return;
    _shown = true;
    try {
      // En az bir frame boyasın diye bir frame daha bekle.
      await SchedulerBinding.instance.endOfFrame;
      await windowManager.show();
      await windowManager.focus();
      // Maximize show sonrası — bazı GPU'larda maximize+boş surface birlikte
      // kalıcı beyaz ekran üretiyordu.
      if (_normalWasMaximized) {
        await Future<void>.delayed(const Duration(milliseconds: 32));
        await windowManager.maximize();
      }
    } catch (e, st) {
      debugPrint('showDesktopWindowWhenReady failed: $e\n$st');
    }
  }

  Future<void> toggleCompactMode() async {
    if (!_isDesktop || !_initialized || _busy) return;
    _busy = true;
    try {
      if (_isCompact) {
        await windowManager.setMinimumSize(_defaultMinimumSize);
        final restored = await _clampToConnectedDisplay(_normalBounds);
        await windowManager.setBounds(restored);
        if (_normalWasMaximized) await windowManager.maximize();
        await windowManager.setAlwaysOnTop(_isPinned);
        _normalBounds = restored;
        _isCompact = false;
        notifyListeners();
      } else {
        _normalWasMaximized = await windowManager.isMaximized();
        if (_normalWasMaximized) await windowManager.unmaximize();
        _normalBounds = await windowManager.getBounds();
        await _saveNormalBounds();

        // Önce ayrı Compact Focus ağacını çiz, sonra native pencereyi küçült.
        // Tersi sıra tam uygulamayı bir frame boyunca 360×220 alana sıkıştırıp
        // kullanıcı QA'sındaki boş/flicker yüzeyi üretiyordu.
        _isCompact = true;
        notifyListeners();
        await SchedulerBinding.instance.endOfFrame;
        await windowManager.setMinimumSize(_compactMinimumSize);
        await windowManager.setSize(_compactSize);
        await windowManager.setAlignment(Alignment.topRight);
        await windowManager.setAlwaysOnTop(true);
      }
      await _preferences?.setBool(_PreferenceKeys.compact, _isCompact);
      await _preferences?.setBool(
        _PreferenceKeys.maximized,
        _normalWasMaximized,
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> toggleAlwaysOnTop() async {
    if (!_isDesktop || !_initialized || _busy) return;
    _isPinned = !_isPinned;
    if (!_isCompact) await windowManager.setAlwaysOnTop(_isPinned);
    await _preferences?.setBool(_PreferenceKeys.pinned, _isPinned);
    notifyListeners();
  }

  Rect _workArea(Display display) => Rect.fromLTWH(
    display.visiblePosition?.dx ?? 0,
    display.visiblePosition?.dy ?? 0,
    display.visibleSize?.width ?? display.size.width,
    display.visibleSize?.height ?? display.size.height,
  );

  Future<Rect> _clampToConnectedDisplay(Rect requested) async {
    final primary = await screenRetriever.getPrimaryDisplay();
    final displays = await screenRetriever.getAllDisplays();
    return clampDesktopWindowBounds(
      requested: requested,
      workAreas: displays.map(_workArea).toList(),
      primaryWorkArea: _workArea(primary),
      minimumSize: _defaultMinimumSize,
    );
  }

  void _scheduleSave() {
    if (_isCompact || _busy) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _saveNormalBounds);
  }

  Future<void> _saveNormalBounds() async {
    if (_isCompact) return;
    final bounds = await windowManager.getBounds();
    _normalBounds = bounds;
    await Future.wait([
      _preferences!.setDouble(_PreferenceKeys.x, bounds.left),
      _preferences!.setDouble(_PreferenceKeys.y, bounds.top),
      _preferences!.setDouble(_PreferenceKeys.width, bounds.width),
      _preferences!.setDouble(_PreferenceKeys.height, bounds.height),
    ]);
  }

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMaximize() {
    if (_isCompact || _busy) return;
    _normalWasMaximized = true;
    unawaited(_preferences?.setBool(_PreferenceKeys.maximized, true));
  }

  @override
  void onWindowUnmaximize() {
    if (_isCompact || _busy) return;
    _normalWasMaximized = false;
    unawaited(_preferences?.setBool(_PreferenceKeys.maximized, false));
  }
}

class _DesktopChrome extends StatefulWidget {
  const _DesktopChrome({required this.child, required this.compactChild});

  final Widget child;
  final Widget compactChild;

  @override
  State<_DesktopChrome> createState() => _DesktopChromeState();
}

class _DesktopChromeState extends State<_DesktopChrome> {
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onWindowStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onWindowStateChanged);
    super.dispose();
  }

  void _onWindowStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return desktopChromeBody(
      isCompact: _controller.isCompact,
      compactChild: widget.compactChild,
      child: widget.child,
    );
  }
}
