import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_task.dart';
import '../user_task_repository.dart';

/// v2: Prefs mirror (sunucu tablo yok). Anahtar: [userTasksPrefsKey].
/// Eski `user_tasks_v1.*` anahtarları okunmaz.
class SupabaseUserTaskRepository implements UserTaskRepository {
  SupabaseUserTaskRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<List<UserTask>> load({required String userKey}) async {
    final raw = _prefs.getStringList(userTasksPrefsKey(userKey));
    if (raw == null || raw.isEmpty) return const [];
    final tasks = <UserTask>[];
    for (final line in raw) {
      try {
        final map = jsonDecode(line) as Map<String, dynamic>;
        final t = UserTask.fromMap(map);
        if (t.id.isEmpty || t.title.isEmpty) continue;
        tasks.add(t);
      } catch (_) {
        // bozuk satır atla
      }
    }
    return tasks;
  }

  @override
  Future<void> saveAll({
    required String userKey,
    required List<UserTask> tasks,
  }) async {
    final clamped = tasks.take(UserTask.maxTasks).toList(growable: false);
    await _prefs.setStringList(
      userTasksPrefsKey(userKey),
      [for (final t in clamped) jsonEncode(t.toMap())],
    );
  }
}
