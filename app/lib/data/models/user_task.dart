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
    this.archivedAt,
    this.updatedAt,
    this.completionDay,
  });

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
  final DateTime? archivedAt;
  final DateTime? updatedAt;
  final DateTime? completionDay;

  bool get isDaily => recurrence == UserTaskRecurrence.daily;
  bool get isArchived => archivedAt != null;

  UserTask copyWith({
    String? title,
    DateTime? dueAt,
    bool? completed,
    DateTime? completedAt,
    int? sortOrder,
    UserTaskRecurrence? recurrence,
    DateTime? archivedAt,
    DateTime? updatedAt,
    DateTime? completionDay,
    bool clearDueAt = false,
    bool clearCompletedAt = false,
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
      archivedAt: _date(map['archivedAt'] ?? map['archived_at']),
      updatedAt: _date(map['updatedAt'] ?? map['updated_at']),
      completionDay: _date(map['completionDay'] ?? map['completion_day']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
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
