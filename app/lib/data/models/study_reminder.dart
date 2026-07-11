import 'package:flutter/foundation.dart';

/// Kullanıcının kendi zamanlanmış çalışma hatırlatıcısı (§WP-36 Bildirim Merkezi).
///
/// `weekdays` ISO gün numaralarını tutar (1=Pazartesi .. 7=Pazar, `DateTime.weekday`
/// ile uyumlu). Boş liste "her gün" demektir. Hatırlatıcılar hem Supabase'te
/// kalıcıdır hem de yerel bildirim olarak planlanır.
@immutable
class StudyReminder {
  const StudyReminder({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.hour,
    required this.minute,
    this.weekdays = const [],
    this.enabled = true,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String? body;
  final int hour;
  final int minute;
  final List<int> weekdays;
  final bool enabled;
  final DateTime createdAt;

  /// Belirli günlerde tekrar ediyor mu? Boşsa her gün çalar.
  bool get repeats => weekdays.isNotEmpty;

  /// Yeni (henüz kaydedilmemiş) bir hatırlatıcı için boş id kullanılır.
  bool get isNew => id.isEmpty;

  StudyReminder copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    int? hour,
    int? minute,
    List<int>? weekdays,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return StudyReminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory StudyReminder.fromMap(Map<String, dynamic> map) {
    final rawDays = (map['weekdays'] as List?) ?? const [];
    return StudyReminder(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      hour: (map['hour'] as num).toInt(),
      minute: (map['minute'] as num).toInt(),
      weekdays: rawDays.map((e) => (e as num).toInt()).toList()..sort(),
      enabled: (map['enabled'] as bool?) ?? true,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Insert/update için satır gövdesi (id/created_at sunucu tarafında yönetilir).
  Map<String, dynamic> toWriteMap() {
    return {
      'user_id': userId,
      'title': title,
      if (body != null) 'body': body,
      'hour': hour,
      'minute': minute,
      'weekdays': weekdays,
      'enabled': enabled,
    };
  }
}
