import '../models/user_task.dart';

/// Kişisel görev listesi — tek kullanıcı listesi (WP-196).
abstract class UserTaskRepository {
  Future<List<UserTask>> load({required String userKey});

  /// Eski prefs yolu ve in-memory test desteği; cloud implementasyonu bunu
  /// idempotent upsert'lere çevirir.
  Future<void> saveAll({
    required String userKey,
    required List<UserTask> tasks,
  });

  Future<UserTask> upsert({
    required String userKey,
    required UserTask task,
    required String operationId,
    bool archived = false,
  });

  Future<void> setCompleted({
    required String userKey,
    required String taskId,
    required bool completed,
    required DateTime occurredAt,
    required String operationId,
  });

  Future<void> migrateLegacy({
    required String userKey,
    required List<UserTask> tasks,
    required String migrationId,
  });
}
