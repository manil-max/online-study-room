import '../models/user_task.dart';

/// Kişisel günlük/haftalık görev listesi (WP-188).
abstract class UserTaskRepository {
  /// [periodKey] dönemi için görevleri yükler (yoksa boş).
  Future<List<UserTask>> load({
    required String userKey,
    required TaskScope scope,
    required String periodKey,
  });

  /// Dönem listesini komple yazar (clamp max 20).
  Future<void> saveAll({
    required String userKey,
    required TaskScope scope,
    required String periodKey,
    required List<UserTask> tasks,
  });
}
