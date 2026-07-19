import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_task.dart';
import '../user_task_repository.dart';

/// Cloud görev RPC istemcisi. userKey hiçbir RPC'ye gönderilmez; server auth.uid()
/// ile kullanıcıyı belirler. Prefs yalnız bir-kerelik v2 göç kaynağıdır.
class SupabaseUserTaskRepository implements UserTaskRepository {
  SupabaseUserTaskRepository(this._client, this._prefs);

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  @override
  Future<List<UserTask>> load({required String userKey}) async {
    await _migratePrefsOnce(userKey);
    final raw = await _client.rpc('list_user_tasks');
    return (raw as List)
        .map((row) => UserTask.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  @override
  Future<void> saveAll({
    required String userKey,
    required List<UserTask> tasks,
  }) async {
    for (final task in tasks.take(UserTask.maxTasks)) {
      await upsert(
        userKey: userKey,
        task: task,
        operationId: task.id,
        archived: task.isArchived,
      );
      await setCompleted(
        userKey: userKey,
        taskId: task.id,
        completed: task.completed,
        occurredAt: task.completedAt ?? task.createdAt,
        operationId: task.id,
      );
    }
  }

  @override
  Future<UserTask> upsert({
    required String userKey,
    required UserTask task,
    required String operationId,
    bool archived = false,
  }) async {
    final raw = await _client.rpc(
      'upsert_user_task',
      params: {
        'p_task_id': task.id,
        'p_title': task.title,
        'p_due_at': task.dueAt?.toUtc().toIso8601String(),
        'p_recurrence': task.recurrence.name,
        'p_sort_order': task.sortOrder,
        'p_archived': archived,
        'p_client_operation_id': operationId,
      },
    );
    return UserTask.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<void> setCompleted({
    required String userKey,
    required String taskId,
    required bool completed,
    required DateTime occurredAt,
    required String operationId,
  }) async {
    await _client.rpc(
      'set_user_task_completion',
      params: {
        'p_task_id': taskId,
        'p_is_completed': completed,
        'p_occurred_at': occurredAt.toUtc().toIso8601String(),
        'p_client_operation_id': operationId,
      },
    );
  }

  @override
  Future<void> migrateLegacy({
    required String userKey,
    required List<UserTask> tasks,
    required String migrationId,
  }) async {
    await _client.rpc(
      'migrate_legacy_user_tasks',
      params: {
        'p_tasks': [for (final task in tasks) task.toMap()],
        'p_migration_id': migrationId,
      },
    );
  }

  Future<void> _migratePrefsOnce(String userKey) async {
    final local = _readLegacy(userKey);
    await migrateLegacy(
      userKey: userKey,
      tasks: local,
      migrationId: _migrationIdFor(userKey),
    );
  }

  List<UserTask> _readLegacy(String userKey) {
    final raw = _prefs.getStringList(userTasksPrefsKey(userKey));
    if (raw == null) return const [];
    final tasks = <UserTask>[];
    for (final line in raw) {
      try {
        final task = UserTask.fromMap(
          Map<String, dynamic>.from(jsonDecode(line) as Map),
        );
        if (task.id.isNotEmpty && task.title.isNotEmpty) tasks.add(task);
      } catch (_) {
        // Bozuk yerel satır cloud göçünü engellemez.
      }
    }
    return tasks.take(UserTask.maxTasks).toList(growable: false);
  }

  // UUID v5 paketi yok; migration RPC'si bir kez işaretlendiği için stabil bir
  // yerel UUID yerine yeni UUID üretmek güvenlidir. İlk başarılı çağrı işareti koyar.
  String _migrationIdFor(String userKey) =>
      '00000000-0000-4000-8000-${userKey.hashCode.abs().toString().padLeft(12, '0').substring(0, 12)}';
}
