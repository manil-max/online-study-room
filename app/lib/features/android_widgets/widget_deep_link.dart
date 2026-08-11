import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/nav_index.dart';

/// WP-700: ana ekran widget'ina dokununca acilacak bolum.
///
/// [nativeName] Kotlin `WidgetDeepLink.ROUTES` ile birebir aynidir; ayrisma
/// `widget_deep_link_wp700_test.dart` icindeki sozlesme iddiasini kirmiziya
/// dusurur.
///
/// Rota **iki seviyelidir**: [tab] ana kabugun alt sekmesini secer, Araclar
/// sekmesinin ikinci seviyesini (`ClockTab`) `clock_screen.dart` kendisi
/// cozer. Ikinci seviye bilerek burada durmuyor: `ClockTab` o dosyaya ait ve
/// enum'u buraya kopyalamak iki gercek uretirdi.
enum WidgetRoute {
  /// Sayac karti panonun varsayilan duzeninde ilk siradadir
  /// (`dashboard_providers.dart` `defaultDashboardLayout`).
  timer('timer', AppTab.home),

  /// Sinav geri sayimi WP-632'den beri **kartin kendisinden** duzenlenir
  /// (`home/widgets/dday_card.dart` -> `showDDayEditorSheet`), yani sahibin
  /// "oradan duzenlerler" dedigi yuzey de Ana Sayfa panosudur.
  countdown('countdown', AppTab.home),
  stats('stats', AppTab.stats),

  /// Grup hedefi ve siralama ayni ekranin iki karti.
  group('group', AppTab.groups),
  clock('clock', AppTab.tools),

  /// WP-701 gorev widget'i icin; mekanizma genel yazildi.
  tasks('tasks', AppTab.tools);

  const WidgetRoute(this.nativeName, this.tab);

  final String nativeName;
  final AppTab tab;

  static WidgetRoute? fromNative(String? nativeName) {
    for (final route in values) {
      if (route.nativeName == nativeName) return route;
    }
    return null;
  }
}

/// Son istenen rota + [tick].
///
/// [tick] sart: kullanici ayni widget'a ikinci kez dokundugunda rota degismez,
/// yalniz sayac artar. Tick olmasa ikinci dokunus ikinci seviyeyi (Araclar alt
/// sekmesi) geri getirmezdi — yani widget'in yarisi olu bir anahtar olurdu.
@immutable
class WidgetRouteRequest {
  const WidgetRouteRequest({this.route, this.tick = 0});

  final WidgetRoute? route;
  final int tick;
}

class WidgetRouteNotifier extends Notifier<WidgetRouteRequest> {
  @override
  WidgetRouteRequest build() => const WidgetRouteRequest();

  void open(WidgetRoute route) {
    state = WidgetRouteRequest(route: route, tick: state.tick + 1);
    ref.read(navIndexProvider.notifier).setTab(route.tab);
  }
}

final widgetRouteProvider =
    NotifierProvider<WidgetRouteNotifier, WidgetRouteRequest>(
      WidgetRouteNotifier.new,
    );

/// Native taraftan rotayi alan izole servis.
///
/// Cihaz entegrasyonu kanali (`/device_integrations`) BILEREK paylasilmadi:
/// oradaki `getInitialAction` tek seferliktir ve `deviceIntegrationListener`
/// tarafindan tuketilir — paylasilsa iki dinleyici yarisirdi ve hangisi once
/// okursa digeri `null` alirdi.
class WidgetDeepLinkService {
  WidgetDeepLinkService({bool? enabled})
    : _enabled =
          enabled ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    if (_enabled) {
      channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  static const channel = MethodChannel(
    'com.manilmax.online_study_room/widget_deep_link',
  );

  final bool _enabled;

  /// SICAK yol: uygulama zaten acikken gelen rota.
  void Function(WidgetRoute route)? onRouteReceived;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onWidgetRoute') return;
    final route = WidgetRoute.fromNative(call.arguments as String?);
    if (route != null) onRouteReceived?.call(route);
  }

  /// SOGUK yol: surec widget intent'iyle dogdu, `onNewIntent` hic cagrilmadi.
  Future<WidgetRoute?> getInitialRoute() async {
    if (!_enabled) return null;
    try {
      final name = await channel.invokeMethod<String>('getInitialWidgetRoute');
      return WidgetRoute.fromNative(name);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

final widgetDeepLinkServiceProvider = Provider<WidgetDeepLinkService>(
  (ref) => WidgetDeepLinkService(),
);

/// Iki yolu da kuran dinleyici. `home_shell.dart` bunu izler.
final widgetDeepLinkListenerProvider = Provider<void>((ref) {
  // Windows/web: kanal yok.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  // Riverpod 3: dinleyicisi olmayan provider her okumada yeniden kurulur ve
  // [WidgetRouteRequest.tick] sifirlanirdi. `watch` DEGIL `listen`: rota her
  // degistiginde bu dinleyici yeniden kurulsa kanal handler'i yeniden
  // baglanir ve soguk yol tekrar sorulurdu.
  ref.listen(widgetRouteProvider, (_, _) {});

  final service = ref.watch(widgetDeepLinkServiceProvider);

  service.getInitialRoute().then((route) {
    if (route != null) ref.read(widgetRouteProvider.notifier).open(route);
  });

  service.onRouteReceived = (route) {
    ref.read(widgetRouteProvider.notifier).open(route);
  };
});
