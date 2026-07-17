import '../../models/profile.dart';
import '../moderation_repository.dart';

class InMemoryModerationRepository implements ModerationRepository {
  final _blocked = <String>{};
  final _reports = <Map<String, String?>>[];
  final Map<String, Profile> profileSeed;

  /// Testlerde bilinen ad/avatar enjekte etmek için [profileSeed].
  InMemoryModerationRepository({Map<String, Profile>? profileSeed})
      : profileSeed = profileSeed ?? {};

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
  Future<List<Profile>> fetchBlockedProfiles() async {
    final out = <Profile>[];
    for (final id in _blocked) {
      final known = profileSeed[id];
      if (known != null) {
        out.add(known);
      } else {
        out.add(
          Profile(
            id: id,
            displayName: id.length > 8 ? '${id.substring(0, 8)}…' : id,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
      }
    }
    out.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return out;
  }

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
      'details': details,
      'snapshot': snapshot,
    });
  }

  /// Test helper.
  List<Map<String, String?>> get reports =>
      List<Map<String, String?>>.unmodifiable(_reports);
}
