import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Cihaz IANA timezone'unu ayarlar (alarm duvar saati = cihaz saati).
///
/// Çalışma gün sınırı (Europe/Istanbul) **istatistik** içindir; kişisel
/// alarm/timer cihaz yerel saatine bağlıdır.
class DeviceTimezone {
  DeviceTimezone._();

  static bool _ready = false;
  static String? lastId;

  static const _channel =
      MethodChannel('com.manilmax.online_study_room/exact_alarm');

  static Future<void> ensureInitialized() async {
    if (_ready) return;
    tzdata.initializeTimeZones();

    String? id;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        id = await _channel.invokeMethod<String>('getLocalTimezoneId');
      } catch (_) {}
    }
    id ??= _guessFromOffset();

    try {
      tz.setLocalLocation(tz.getLocation(id));
      lastId = id;
    } catch (_) {
      // Bilinmeyen id → UTC offset yaklaşık (Istanbul yedek değil)
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
        lastId = 'UTC';
      } catch (_) {}
    }
    _ready = true;
  }

  /// Offset'e göre kaba eşleme (plugin yoksa).
  static String _guessFromOffset() {
    final min = DateTime.now().timeZoneOffset.inMinutes;
    // Yaygın ofsetler — tam IANA değil ama duvar saati kaymasını azaltır.
    return switch (min) {
      180 => 'Europe/Istanbul',
      120 => 'Europe/Berlin',
      60 => 'Europe/London',
      0 => 'UTC',
      -300 => 'America/New_York',
      -480 => 'America/Los_Angeles',
      540 => 'Asia/Tokyo',
      _ => 'UTC',
    };
  }
}
