import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Alarm/timer için cihaz izin özeti (Android).
@immutable
class ClockPermissionSnapshot {
  const ClockPermissionSnapshot({
    required this.notifications,
    required this.exactAlarm,
    required this.batteryUnrestricted,
    required this.fullScreenIntent,
  });

  final bool notifications;
  final bool exactAlarm;
  final bool batteryUnrestricted;
  final bool fullScreenIntent;

  bool get allOk =>
      notifications && exactAlarm && batteryUnrestricted && fullScreenIntent;

  List<String> missingLabels(AppLocalizations l10n) {
    final m = <String>[];
    if (!notifications) m.add(l10n.coreBildirim);
    if (!exactAlarm) m.add(l10n.clockKesinAlarmExact);
    if (!batteryUnrestricted) m.add(l10n.clockPilKisitlamasiYok);
    if (!fullScreenIntent) m.add(l10n.coreTamEkranAlarm);
    return m;
  }

  factory ClockPermissionSnapshot.fromMap(Map<Object?, Object?> map) {
    return ClockPermissionSnapshot(
      notifications: map['notifications'] as bool? ?? true,
      exactAlarm: map['exactAlarm'] as bool? ?? true,
      batteryUnrestricted: map['batteryUnrestricted'] as bool? ?? true,
      fullScreenIntent: map['fullScreenIntent'] as bool? ?? true,
    );
  }

  static const ok = ClockPermissionSnapshot(
    notifications: true,
    exactAlarm: true,
    batteryUnrestricted: true,
    fullScreenIntent: true,
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
    if (!_android) return ClockPermissionSnapshot.ok;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getPermissionSnapshot',
      );
      if (raw != null) return ClockPermissionSnapshot.fromMap(raw);
    } catch (_) {}
    return ClockPermissionSnapshot.ok;
  }

  /// Bildirim izni (Android 13+).
  Future<bool> requestNotifications() async {
    if (!_android) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final ok = await android?.requestNotificationsPermission();
      return ok ?? true;
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
