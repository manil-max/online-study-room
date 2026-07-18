import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_task.dart';
import '../user_task_repository.dart';

/// v1: Prefs mirror (sunucu tablo yok). İleride PostgREST + RLS ile değişir.
///
/// "Supabase impl" ailesi seçicisini bozmadan demo/offline parity sağlar.
class SupabaseUserTaskRepository implements UserTaskRepository {
  SupabaseUserTaskRepository(this._prefs);

  final SharedPreferences _prefs;

  static String prefsKey({
    required String userKey,
    required TaskScope scope,
    required String periodKey,
  }) =>
      'user_tasks_v1.$userKey.${scope.name}.$periodKey';

  @override
  Future<List<UserTask>> load({
    required String userKey,
    required TaskScope scope,
    required String periodKey,
  }) async {
    final raw = _prefs.getStringList(
      prefsKey(userKey: userKey, scope: scope, periodKey: periodKey),
    );
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
    return sortUserTasks(tasks);
  }

  @override
  Future<void> saveAll({
    required String userKey,
    required TaskScope scope,
    required String periodKey,
    required List<UserTask> tasks,
  }) async {
    final clamped = sortUserTasks(tasks)
        .take(UserTask.maxTasksPerPeriod)
        .toList(growable: false);
    await _prefs.setStringList(
      prefsKey(userKey: userKey, scope: scope, periodKey: periodKey),
      [for (final t in clamped) jsonEncode(t.toMap())],
    );
  }
}
