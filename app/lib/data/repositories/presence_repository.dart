import '../models/presence.dart';

/// Canlı "kim çalışıyor" durumunun deposu. Kullanıcı başına tek satır (upsert).
abstract class PresenceRepository {
  /// Kullanıcının kendi canlı durumunu yazar/günceller.
  Future<void> setPresence(Presence presence);

  /// Bir sınıftaki tüm üyelerin canlı durumunu (yeni veriyle) izler.
  Stream<List<Presence>> watchGroupPresence(String groupId);
}
