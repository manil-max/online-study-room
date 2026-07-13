import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android 12+ exact alarm izin durumu.
enum ExactAlarmStatus {
  /// İzin verildi veya platform desteklemiyor (iOS/Windows/web).
  granted,

  /// İzin yok — inexact fallback kullanılmalı + kullanıcı uyarılmalı.
  denied,

  /// Henüz sorgulanmadı / bilinmiyor.
  unknown,
}

/// `SCHEDULE_EXACT_ALARM` kontrolü + istek.
///
/// Önce `flutter_local_notifications` Android API'si; yoksa native method channel.
class ExactAlarmPermission {
  ExactAlarmPermission({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? channel,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _channel = channel ??
            const MethodChannel('com.manilmax.online_study_room/exact_alarm');

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _channel;

  static const instance = _ExactAlarmPermissionHolder();

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<ExactAlarmStatus> status() async {
    if (!_isAndroid) return ExactAlarmStatus.granted;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final can = await android?.canScheduleExactNotifications();
      if (can == true) return ExactAlarmStatus.granted;
      if (can == false) return ExactAlarmStatus.denied;
    } catch (_) {
      /* native fallback */
    }
    try {
      final can = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      if (can == true) return ExactAlarmStatus.granted;
      if (can == false) return ExactAlarmStatus.denied;
    } catch (_) {}
    return ExactAlarmStatus.unknown;
  }

  /// Sistem ayarına yönlendir / izin iste. true = kullanıcı akışı başlatıldı.
  Future<bool> request() async {
    if (!_isAndroid) return true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.requestExactAlarmsPermission();
      if (ok == true) return true;
    } catch (_) {}
    try {
      await _channel.invokeMethod<void>('requestExactAlarmsPermission');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Exact mümkünse exactAllowWhileIdle, değilse inexactAllowWhileIdle.
  Future<AndroidScheduleMode> scheduleMode() async {
    final s = await status();
    return s == ExactAlarmStatus.granted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}

/// const erişim için ince sarmalayıcı.
class _ExactAlarmPermissionHolder {
  const _ExactAlarmPermissionHolder();

  ExactAlarmPermission get value => ExactAlarmPermission();
}
