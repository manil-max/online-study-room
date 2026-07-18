import '../models/user_task.dart';

/// Kişisel görev listesi — tek kullanıcı listesi (WP-196).
abstract class UserTaskRepository {
  Future<List<UserTask>> load({required String userKey});

  Future<void> saveAll({
    required String userKey,
    required List<UserTask> tasks,
  });
}
