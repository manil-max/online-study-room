import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Samsung Modes & Routines ve diğer otomasyon uygulamalarından gelen
/// App Shortcut intentlerini dinleyen izole servis.
class DeviceIntegrationService {
  static const _channel =
      MethodChannel('com.manilmax.online_study_room/device_integrations');

  final void Function(String action)? onActionReceived;

  DeviceIntegrationService({this.onActionReceived}) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onIntentAction') {
      final action = call.arguments as String?;
      if (action != null) {
        onActionReceived?.call(action);
      }
    }
  }

  /// Uygulama ilk açıldığında gelen intent aksiyonunu alır.
  Future<String?> getInitialAction() async {
    try {
      final action = await _channel.invokeMethod<String>('getInitialAction');
      return action;
    } on PlatformException {
      return null;
    }
  }
}

/// WP-15 Spike sonucu: UI'a veya timer state'ine doğrudan bağlanmamıştır.
/// WP-19 aşamasında Settings UI ve StudyProviders'a bağlanacaktır.
final deviceIntegrationServiceProvider = Provider<DeviceIntegrationService>((ref) {
  return DeviceIntegrationService(
    onActionReceived: (action) {
      // TODO (WP-19): action'a göre timer'ı başlat veya durdur.
      // Örnek: if (action == 'com.manilmax.online_study_room.START_TIMER') ...
    },
  );
});
