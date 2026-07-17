import '../moderation_repository.dart';

class InMemoryModerationRepository implements ModerationRepository {
  final _blocked = <String>{};
  final _reports = <Map<String, String>>[];
  String? termsVersion;

  @override
  Future<void> acceptCommunityTerms(String version) async {
    termsVersion = version;
  }

  @override
  Future<void> blockUser(String userId) async {
    _blocked.add(userId);
  }

  @override
  Future<void> unblockUser(String userId) async {
    _blocked.remove(userId);
  }

  @override
  Future<List<String>> listBlockedUserIds() async => _blocked.toList();

  @override
  Future<void> reportUgc({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
    String? snapshot,
  }) async {
    _reports.add({
      'type': targetType,
      'id': targetId,
      'reason': reason,
    });
  }
}
