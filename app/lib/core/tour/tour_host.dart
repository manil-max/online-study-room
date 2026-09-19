import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import 'tour_controller.dart';
import 'tour_models.dart';
import 'tour_overlay.dart';

/// WP-323: Bir ekranı tur motoruna bağlar.
///
/// İçerik ekranı yalnız [TourDefinition] ve hedef anahtarlarını verir. Host,
/// modal route ve uygulama yaşam döngüsünü gözleyerek izin/güncelleme
/// diyaloglarının üstüne tur bindirmez; koşul düzelince turu yeniden dener.
class TourHost extends ConsumerStatefulWidget {
  const TourHost({super.key, required this.definition, required this.child});

  final TourDefinition definition;
  final Widget child;

  @override
  ConsumerState<TourHost> createState() => _TourHostState();
}

class _TourHostState extends ConsumerState<TourHost>
    with WidgetsBindingObserver {
  Timer? _retryTimer;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  /// WP-375: gövdedeki her kaydırma bildirimi bir yeniden ölçüm tetikler.
  /// Ölçümü `build`'e değil olaya bağladığımız için her karede ölçüm yok.
  final _remeasure = ValueNotifier<int>(0);

  /// WP-869: dispose'ta `ref` ve `context` kullanılamaz; askıya alma
  /// kararı için saklanır.
  late final TourController _controller;
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(tourControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryStart());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    // WP-869: bu turun balonu açıkken ekranın rotası kapandıysa (geri
    // tuşu) tur sahipsiz "çalışıyor" kalır ve diğer tüm turları kilitler.
    // Yalnız rota gerçekten gittiyse askıya alınır; rota yerinde duruyorsa
    // (sekme değişimi vb.) davranış değişmez. Durum ağaç sökülürken
    // değiştirilemez; kare bitince askıya alınır.
    final route = _route;
    if (route != null && !route.isActive) {
      final definition = widget.definition;
      final controller = _controller;
      scheduleMicrotask(() => controller.suspend(definition));
    }
    _remeasure.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) _tryStart();
  }

  void _tryStart() {
    if (!mounted) return;
    final controller = ref.read(tourControllerProvider.notifier);
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final started = controller.maybeStart(
      widget.definition,
      routeIsCurrent: routeIsCurrent,
      appResumed: _lifecycle == AppLifecycleState.resumed,
    );
    if (started || controller.seen(widget.definition)) {
      _retryTimer?.cancel();
      return;
    }
    _retryTimer ??= Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _tryStart(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // İlk frame'de auth akışı hâlâ yükleniyor olabilir. Değer geldiğinde yeniden
    // denemek, yeni kullanıcının turunun zamanlama yarışında kaybolmasını önler.
    ref.listen(authStateProvider, (_, next) {
      if (next.asData?.value != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryStart());
      }
    });
    final state = ref.watch(tourControllerProvider);
    final l10n = AppLocalizations.of(context);
    final isThisTour =
        state.definition?.storageId == widget.definition.storageId;
    final step = isThisTour ? state.step : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (_) {
            // Tur çalışmıyorken boşuna dinleyici uyandirmayalim.
            if (step != null) _remeasure.value++;
            return false;
          },
          child: widget.child,
        ),
        if (step != null)
          TourOverlay(
            step: step,
            index: state.index,
            remeasure: _remeasure,
            onAnchorLost: () =>
                unawaited(ref.read(tourControllerProvider.notifier).next()),
            strings: TourOverlayStrings(
              skip: l10n.tourAtla,
              next: l10n.tourDevam,
            ),
            onNext: () =>
                unawaited(ref.read(tourControllerProvider.notifier).next()),
            onSkip: () =>
                unawaited(ref.read(tourControllerProvider.notifier).skip()),
          ),
      ],
    );
  }
}
