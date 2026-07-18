import 'package:flutter/foundation.dart';

import '../../core/stats/istanbul_calendar.dart';
import '../../core/stats/study_stats.dart';

/// Günlük / haftalık kişisel görev kapsamı (WP-188).
enum TaskScope {
  daily,
  weekly;

  static TaskScope? tryParse(String raw) {
    for (final v in TaskScope.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

/// Kullanıcı tanımlı görev maddesi — XP yok (v1 checklist).
@immutable
class UserTask {
  const UserTask({
    required this.id,
    required this.title,
    required this.scope,
    required this.completed,
    required this.createdAt,
    this.completedAt,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final TaskScope scope;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int sortOrder;

  UserTask copyWith({
    String? title,
    bool? completed,
    DateTime? completedAt,
    int? sortOrder,
    bool clearCompletedAt = false,
  }) {
    return UserTask(
      id: id,
      title: title ?? this.title,
      scope: scope,
      completed: completed ?? this.completed,
      createdAt: createdAt,
      completedAt: clearCompletedAt
          ? null
          : (completedAt ?? this.completedAt),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'scope': scope.name,
        'completed': completed,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'completedAt': completedAt?.toUtc().toIso8601String(),
        'sortOrder': sortOrder,
      };

  factory UserTask.fromMap(Map<String, dynamic> map) {
    final scope = TaskScope.tryParse(map['scope'] as String? ?? '') ??
        TaskScope.daily;
    return UserTask(
      id: map['id'] as String? ?? '',
      title: (map['title'] as String? ?? '').trim(),
      scope: scope,
      completed: map['completed'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      completedAt: map['completedAt'] == null
          ? null
          : DateTime.tryParse(map['completedAt'] as String),
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  static const int maxTitleLength = 80;
  static const int maxTasksPerPeriod = 20;

  /// Başlık clamp + boş red için normalize.
  static String? normalizeTitle(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.length > maxTitleLength) return t.substring(0, maxTitleLength);
    return t;
  }
}

/// Europe/Istanbul gün/hafta anahtarı (WP-146 ruhu).
String taskPeriodKey(TaskScope scope, {DateTime? now}) {
  final day = istanbulDay(now ?? DateTime.now());
  return switch (scope) {
    TaskScope.daily =>
      'd:${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}',
    TaskScope.weekly => () {
        final start = startOfWeek(day);
        return 'w:${start.year.toString().padLeft(4, '0')}-'
            '${start.month.toString().padLeft(2, '0')}-'
            '${start.day.toString().padLeft(2, '0')}';
      }(),
  };
}

/// Açık maddeler üstte, tamamlananlar altta; sortOrder ikincil.
List<UserTask> sortUserTasks(List<UserTask> tasks) {
  final copy = [...tasks];
  copy.sort((a, b) {
    if (a.completed != b.completed) return a.completed ? 1 : -1;
    final o = a.sortOrder.compareTo(b.sortOrder);
    if (o != 0) return o;
    return a.createdAt.compareTo(b.createdAt);
  });
  return copy;
}
