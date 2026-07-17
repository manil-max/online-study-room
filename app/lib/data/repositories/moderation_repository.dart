import '../models/profile.dart';

/// WP-116 / WP-129: UGC rapor / engel soyutlaması.
abstract class ModerationRepository {
  Future<void> acceptCommunityTerms(String version);

  Future<void> blockUser(String userId);

  Future<void> unblockUser(String userId);

  Future<List<String>> listBlockedUserIds();

  /// Engellenen kullanıcılar ekranı: id → profil özeti.
  /// Okunamayan id'ler için minimal [Profile] (maskeli ad) döner.
  Future<List<Profile>> fetchBlockedProfiles();

  Future<void> reportUgc({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
    String? snapshot,
  });
}

class ModerationException implements Exception {
  const ModerationException(this.message);
  final String message;
  @override
  String toString() => message;
}
