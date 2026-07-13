import 'package:equatable/equatable.dart';

/// Alarm özellik modeli (Alarm 2.0).
class AlarmRule extends Equatable {
  const AlarmRule({
    required this.id,
    required this.hour,
    required this.minute,
    this.days = const [],
    this.date,
    this.label = '',
    this.isActive = true,
    this.snoozeMinutes = 5,
    this.skipNextOn,
    this.antiSnooze = false,
    this.crescendo = true,
    this.vibrate = true,
  })  : assert(hour >= 0 && hour <= 23),
        assert(minute >= 0 && minute <= 59);

  final String id;

  /// Alarm saati (0-23)
  final int hour;

  /// Alarm dakikası (0-59)
  final int minute;

  /// Tekrar günleri (1 = Pazartesi … 7 = Pazar). Boş = tek seferlik.
  final List<int> days;

  /// Yalnız belirli bir tarihte (opsiyonel).
  final DateTime? date;

  final String label;
  final bool isActive;
  final int snoozeMinutes;

  /// Bu takvim günündeki occurrence atlanır (tek günlük skip).
  final DateTime? skipNextOn;

  /// Kapatmak için matematik sorusu.
  final bool antiSnooze;

  /// 30 sn kademeli ses/haptic.
  final bool crescendo;

  final bool vibrate;

  AlarmRule copyWith({
    String? id,
    int? hour,
    int? minute,
    List<int>? days,
    DateTime? date,
    String? label,
    bool? isActive,
    int? snoozeMinutes,
    DateTime? skipNextOn,
    bool clearSkipNextOn = false,
    bool? antiSnooze,
    bool? crescendo,
    bool? vibrate,
  }) {
    return AlarmRule(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      days: days ?? this.days,
      date: date ?? this.date,
      label: label ?? this.label,
      isActive: isActive ?? this.isActive,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      skipNextOn: clearSkipNextOn ? null : (skipNextOn ?? this.skipNextOn),
      antiSnooze: antiSnooze ?? this.antiSnooze,
      crescendo: crescendo ?? this.crescendo,
      vibrate: vibrate ?? this.vibrate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'days': days,
      'date': date?.toIso8601String(),
      'label': label,
      'isActive': isActive,
      'snoozeMinutes': snoozeMinutes,
      'skipNextOn': skipNextOn?.toIso8601String(),
      'antiSnooze': antiSnooze,
      'crescendo': crescendo,
      'vibrate': vibrate,
    };
  }

  factory AlarmRule.fromMap(Map<String, dynamic> map) {
    return AlarmRule(
      id: map['id'] as String,
      hour: (map['hour'] as num).toInt(),
      minute: (map['minute'] as num).toInt(),
      days: List<int>.from(map['days'] ?? []),
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
      label: map['label'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      snoozeMinutes: (map['snoozeMinutes'] as num?)?.toInt() ?? 5,
      skipNextOn: map['skipNextOn'] != null
          ? DateTime.parse(map['skipNextOn'] as String)
          : null,
      antiSnooze: map['antiSnooze'] as bool? ?? false,
      crescendo: map['crescendo'] as bool? ?? true,
      vibrate: map['vibrate'] as bool? ?? true,
    );
  }

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Türkçe kısa gün özeti.
  String get daysSummary {
    if (days.isEmpty) return 'Bir kez';
    const names = {
      1: 'Pzt',
      2: 'Sal',
      3: 'Çar',
      4: 'Per',
      5: 'Cum',
      6: 'Cmt',
      7: 'Paz',
    };
    final sorted = [...days]..sort();
    if (sorted.length == 7) return 'Her gün';
    if (sorted.length == 5 &&
        sorted.every((d) => d >= 1 && d <= 5)) {
      return 'Hafta içi';
    }
    if (sorted.length == 2 && sorted.contains(6) && sorted.contains(7)) {
      return 'Hafta sonu';
    }
    return sorted.map((d) => names[d] ?? '$d').join(', ');
  }

  @override
  List<Object?> get props => [
        id,
        hour,
        minute,
        days,
        date,
        label,
        isActive,
        snoozeMinutes,
        skipNextOn,
        antiSnooze,
        crescendo,
        vibrate,
      ];
}
