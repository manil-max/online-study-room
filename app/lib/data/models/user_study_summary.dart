import 'package:flutter/foundation.dart';

/// Hafif özet: 1 yıllık / ömür boyu toplamlar (tek satır, RAM ucuz).
/// Detay oturumlar [kUserSessionsHotWindowDays] penceresinde ayrı akıtılır.
@immutable
class UserStudySummary {
  const UserStudySummary({
    required this.lifetimeSeconds,
    required this.yearSeconds,
    required this.hotWindowSeconds,
  });

  /// Tüm kayıtlı çalışma süresi (saniye).
  final int lifetimeSeconds;

  /// Bu takvim yılı (Europe/Istanbul yılı) toplamı.
  final int yearSeconds;

  /// Sıcak pencere (son 90 gün) toplamı — tutarlılık kontrolü.
  final int hotWindowSeconds;

  static const empty = UserStudySummary(
    lifetimeSeconds: 0,
    yearSeconds: 0,
    hotWindowSeconds: 0,
  );

  factory UserStudySummary.fromMap(Map<String, dynamic> map) {
    int asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return UserStudySummary(
      lifetimeSeconds: asInt(map['lifetime_seconds']),
      yearSeconds: asInt(map['year_seconds']),
      hotWindowSeconds: asInt(map['hot_window_seconds']),
    );
  }

  Map<String, dynamic> toMap() => {
        'lifetime_seconds': lifetimeSeconds,
        'year_seconds': yearSeconds,
        'hot_window_seconds': hotWindowSeconds,
      };
}
