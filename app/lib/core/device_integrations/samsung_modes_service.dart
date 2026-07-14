import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Samsung Modes & Routines ve diğer otomasyon uygulamalarından gelen
/// App Shortcut intentlerini dinleyen izole servis.
///
/// Yalnız Android: Windows/web'de MethodChannel yok → MissingPluginException
/// log fırtınası ve boşa async (WP-71 perf).
class DeviceIntegrationService {
  static const _channel =
      MethodChannel('com.manilmax.online_study_room/device_integrations');

  void Function(String action)? onActionReceived;
  final bool _enabled;

  DeviceIntegrationService({this.onActionReceived, bool? enabled})
    : _enabled =
          enabled ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    if (_enabled) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }
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
    if (!_enabled) return null;
    try {
      final action = await _channel.invokeMethod<String>('getInitialAction');
      return action;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// WP-15 Spike sonucu kurulan izole servis.
/// Dinleme ve tetikleme işlemleri device_integration_listener_provider içinde yapılır.
final deviceIntegrationServiceProvider = Provider<DeviceIntegrationService>((
  ref,
) {
  return DeviceIntegrationService();
});
