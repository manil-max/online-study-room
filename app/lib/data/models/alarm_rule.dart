import 'package:equatable/equatable.dart';

/// Alarmların özelliklerini tanımlayan veri modeli.
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
  }) : assert(hour >= 0 && hour <= 23),
       assert(minute >= 0 && minute <= 59);

  final String id;
  
  /// Alarm saati (0-23)
  final int hour;
  
  /// Alarm dakikası (0-59)
  final int minute;
  
  /// Hangi günlerde tekrarlanacağı (1 = Pazartesi, 7 = Pazar). 
  /// Boş ise tekrarsız bir alarmdır (sadece bir kez çalar).
  final List<int> days;
  
  /// Sadece belirli bir tarihte çalacaksa (opsiyonel).
  final DateTime? date;
  
  /// Alarm etiketi
  final String label;
  
  /// Alarm aktif/açık mı?
  final bool isActive;
  
  /// Erteleme süresi (dakika)
  final int snoozeMinutes;

  AlarmRule copyWith({
    String? id,
    int? hour,
    int? minute,
    List<int>? days,
    DateTime? date,
    String? label,
    bool? isActive,
    int? snoozeMinutes,
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
    );
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
      ];
}
