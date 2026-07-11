import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Samsung Modes & Routines ve diğer otomasyon uygulamalarından gelen
/// App Shortcut intentlerini dinleyen izole servis.
class DeviceIntegrationService {
  static const _channel =
      MethodChannel('com.manilmax.online_study_room/device_integrations');

  void Function(String action)? onActionReceived;

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

/// WP-15 Spike sonucu kurulan izole servis.
/// Dinleme ve tetikleme işlemleri device_integration_listener_provider içinde yapılır.
final deviceIntegrationServiceProvider = Provider<DeviceIntegrationService>((ref) {
  return DeviceIntegrationService();
});
