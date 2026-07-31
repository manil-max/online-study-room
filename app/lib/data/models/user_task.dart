import 'package:flutter/foundation.dart';

/// Kullanıcı tanımlı görev. Tamamlanma gün-damgalı completion tablosunda
/// saklanır; [completed] yalnız bugünün/tek-seferlik görevin projection'ıdır.
enum UserTaskRecurrence { once, daily }

@immutable
class UserTask {
  const UserTask({
    required this.id,
    required this.title,
    this.dueAt,
    required this.completed,
    required this.createdAt,
    this.completedAt,
    required this.sortOrder,
    this.userId,
    this.recurrence = UserTaskRecurrence.once,
    this.intervalDays = 1,
    this.anchorDate,
    this.archivedAt,
    this.updatedAt,
    this.completionDay,
  }) : assert(intervalDays >= 1);

  final String id;
  final String title;

  /// Bitiş anı (UTC saklanır). Null = süresiz.
  final DateTime? dueAt;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int sortOrder;
  final String? userId;
  final UserTaskRecurrence recurrence;

  /// Tekrarlanan görevler için sabit takvim aralığı.
  ///
  /// `1`, mevcut günlük davranıştır. Daha büyük değerlerde occurrence günleri
  /// [anchorDate] + k * [intervalDays] olarak hesaplanır; completion zamanı
  /// döngünün fazını değiştirmez.
  final int intervalDays;

  /// Europe/Istanbul takviminde tarih-only sabit faz başlangıcı.
  ///
  /// Eski günlük kayıtlarda null olabilir; recurrence motoru bu durumda
  /// `dueAt ?? createdAt` gününü geriye uyumlu anchor olarak kullanır.
  final DateTime? anchorDate;

  final DateTime? archivedAt;
  final DateTime? updatedAt;
  final DateTime? completionDay;

  bool get isRecurring => recurrence == UserTaskRecurrence.daily;
  bool get isDaily => isRecurring && intervalDays == 1;
  bool get isArchived => archivedAt != null;

  UserTask copyWith({
    String? title,
    DateTime? dueAt,
    bool? completed,
    DateTime? completedAt,
    int? sortOrder,
    UserTaskRecurrence? recurrence,
    int? intervalDays,
    DateTime? anchorDate,
    DateTime? archivedAt,
    DateTime? updatedAt,
    DateTime? completionDay,
    bool clearDueAt = false,
    bool clearCompletedAt = false,
    bool clearAnchorDate = false,
  }) {
    return UserTask(
      id: id,
      title: title ?? this.title,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      completed: completed ?? this.completed,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      sortOrder: sortOrder ?? this.sortOrder,
      userId: userId,
      recurrence: recurrence ?? this.recurrence,
      intervalDays: intervalDays ?? this.intervalDays,
      anchorDate: clearAnchorDate ? null : (anchorDate ?? this.anchorDate),
      archivedAt: archivedAt ?? this.archivedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completionDay: completionDay ?? this.completionDay,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'dueAt': dueAt?.toUtc().toIso8601String(),
    'completed': completed,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'sortOrder': sortOrder,
    'userId': userId,
    'recurrence': recurrence.name,
    'intervalDays': intervalDays,
    'anchorDate': _dateOnly(anchorDate),
    'archivedAt': archivedAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'completionDay': completionDay?.toUtc().toIso8601String(),
  };

  factory UserTask.fromMap(Map<String, dynamic> map) {
    return UserTask(
      id: map['id'] as String? ?? '',
      title: (map['title'] as String? ?? '').trim(),
      dueAt: _date(map['dueAt'] ?? map['due_at']),
      completed: map['completed'] as bool? ?? false,
      createdAt:
          _date(map['createdAt'] ?? map['created_at']) ??
          DateTime.now().toUtc(),
      completedAt: _date(map['completedAt'] ?? map['completed_at']),
      sortOrder: map['sortOrder'] as int? ?? map['sort_order'] as int? ?? 0,
      userId: map['userId'] as String? ?? map['user_id'] as String?,
      recurrence: _recurrence(map['recurrence'] as String?),
      intervalDays: _intervalDays(map['intervalDays'] ?? map['interval_days']),
      anchorDate: _calendarDate(map['anchorDate'] ?? map['anchor_date']),
      archivedAt: _date(map['archivedAt'] ?? map['archived_at']),
      updatedAt: _date(map['updatedAt'] ?? map['updated_at']),
      completionDay: _date(map['completionDay'] ?? map['completion_day']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static DateTime? _calendarDate(Object? value) {
    final parsed = _date(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static int _intervalDays(Object? value) {
    if (value == null) return 1;
    final parsed = switch (value) {
      int number => number,
      String text => int.tryParse(text),
      _ => null,
    };
    if (parsed == null || parsed < 1) {
      throw const FormatException('invalid_task_interval_days');
    }
    return parsed;
  }

  static String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static UserTaskRecurrence _recurrence(String? value) {
    return value == 'daily'
        ? UserTaskRecurrence.daily
        : UserTaskRecurrence.once;
  }

  Map<String, dynamic> toCloudMap() => {
    'id': id,
    'title': title,
    'due_at': dueAt?.toUtc().toIso8601String(),
    'sort_order': sortOrder,
    'recurrence': recurrence.name,
    'interval_days': intervalDays,
    'anchor_date': _dateOnly(anchorDate),
    'archived_at': archivedAt?.toUtc().toIso8601String(),
  };

  static const int maxTitleLength = 80;
  static const int maxTasks = 100;

  static String? normalizeTitle(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.length > maxTitleLength) return t.substring(0, maxTitleLength);
    return t;
  }
}

/// Prefs anahtarı (v2 tek liste; v1 period-anahtarları yoksayılır).
String userTasksPrefsKey(String userKey) => 'user_tasks_v2.$userKey';
