import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Alarm/timer için cihaz izin özeti (Android).
enum ClockPermissionAvailability { available, unsupported, unknown }

@immutable
class ClockPermissionSnapshot {
  const ClockPermissionSnapshot({
    required this.availability,
    required this.notifications,
    required this.exactAlarm,
    required this.batteryUnrestricted,
    required this.fullScreenIntent,
  });

  final ClockPermissionAvailability availability;
  final bool notifications;
  final bool exactAlarm;
  final bool batteryUnrestricted;
  final bool fullScreenIntent;

  bool get allOk =>
      availability == ClockPermissionAvailability.available &&
      notifications &&
      exactAlarm &&
      batteryUnrestricted &&
      fullScreenIntent;

  int get missingCount => allOk
      ? 0
      : [
          notifications,
          exactAlarm,
          batteryUnrestricted,
          fullScreenIntent,
        ].where((granted) => !granted).length;

  List<String> missingLabels(AppLocalizations l10n) {
    final m = <String>[];
    if (!notifications) m.add(l10n.coreBildirim);
    if (!exactAlarm) m.add(l10n.clockKesinAlarmExact);
    if (!batteryUnrestricted) m.add(l10n.clockPilKisitlamasiYok);
    if (!fullScreenIntent) m.add(l10n.coreTamEkranAlarm);
    return m;
  }

  factory ClockPermissionSnapshot.fromMap(Map<Object?, Object?> map) {
    final notifications = map['notifications'];
    final exactAlarm = map['exactAlarm'];
    final batteryUnrestricted = map['batteryUnrestricted'];
    final fullScreenIntent = map['fullScreenIntent'];
    if (notifications is! bool ||
        exactAlarm is! bool ||
        batteryUnrestricted is! bool ||
        fullScreenIntent is! bool) {
      return ClockPermissionSnapshot.unknown;
    }
    return ClockPermissionSnapshot(
      availability: ClockPermissionAvailability.available,
      notifications: notifications,
      exactAlarm: exactAlarm,
      batteryUnrestricted: batteryUnrestricted,
      fullScreenIntent: fullScreenIntent,
    );
  }

  static const ok = ClockPermissionSnapshot(
    availability: ClockPermissionAvailability.available,
    notifications: true,
    exactAlarm: true,
    batteryUnrestricted: true,
    fullScreenIntent: true,
  );

  static const unsupported = ClockPermissionSnapshot(
    availability: ClockPermissionAvailability.unsupported,
    notifications: false,
    exactAlarm: false,
    batteryUnrestricted: false,
    fullScreenIntent: false,
  );

  static const unknown = ClockPermissionSnapshot(
    availability: ClockPermissionAvailability.unknown,
    notifications: false,
    exactAlarm: false,
    batteryUnrestricted: false,
    fullScreenIntent: false,
  );
}

/// İzin sorgu + ayar yönlendirme.
class ClockPermissions {
  ClockPermissions({
    MethodChannel? channel,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _channel =
           channel ??
           const MethodChannel('com.manilmax.online_study_room/exact_alarm'),
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static final instance = ClockPermissions();

  final MethodChannel _channel;
  final FlutterLocalNotificationsPlugin _plugin;

  bool get _android => !kIsWeb && Platform.isAndroid;

  Future<ClockPermissionSnapshot> snapshot() async {
    if (!_android) return ClockPermissionSnapshot.unsupported;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getPermissionSnapshot',
      );
      if (raw != null) return ClockPermissionSnapshot.fromMap(raw);
    } catch (_) {}
    return ClockPermissionSnapshot.unknown;
  }

  /// Bildirim izni (Android 13+).
  Future<bool> requestNotifications() async {
    if (!_android) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final ok = await android?.requestNotificationsPermission();
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openExactAlarmSettings() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('requestExactAlarmsPermission');
    } catch (_) {}
  }

  Future<void> openBatterySettings() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  /// Pil optimizasyonunun hem açılıp hem kapatılabildiği Android sistem listesi.
  Future<void> openBatteryOptimizationManagementSettings() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>(
        'openBatteryOptimizationManagementSettings',
      );
    } catch (_) {}
  }

  Future<void> openNotificationSettings() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (_) {}
  }

  Future<void> openFullScreenSettings() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('openFullScreenIntentSettings');
    } catch (_) {}
  }

  /// Alarm kaydetmeden önce: bildirim iste + eksikleri raporla.
  Future<ClockPermissionSnapshot> ensureForAlarm() async {
    await requestNotifications();
    return snapshot();
  }
}
