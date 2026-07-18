import 'package:flutter/foundation.dart';

/// Kullanıcı tanımlı görev (WP-196 deadline modeli).
///
/// XP yok. Tekrar (recurring) yok. `dueAt` null = süresiz.
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
  });

  final String id;
  final String title;

  /// Bitiş anı (UTC saklanır). Null = süresiz.
  final DateTime? dueAt;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int sortOrder;

  UserTask copyWith({
    String? title,
    DateTime? dueAt,
    bool? completed,
    DateTime? completedAt,
    int? sortOrder,
    bool clearDueAt = false,
    bool clearCompletedAt = false,
  }) {
    return UserTask(
      id: id,
      title: title ?? this.title,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
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
        'dueAt': dueAt?.toUtc().toIso8601String(),
        'completed': completed,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'completedAt': completedAt?.toUtc().toIso8601String(),
        'sortOrder': sortOrder,
      };

  factory UserTask.fromMap(Map<String, dynamic> map) {
    return UserTask(
      id: map['id'] as String? ?? '',
      title: (map['title'] as String? ?? '').trim(),
      dueAt: map['dueAt'] == null
          ? null
          : DateTime.tryParse(map['dueAt'] as String),
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
