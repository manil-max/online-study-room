import 'dart:typed_data';

import '../../models/profile.dart';
import '../../models/report_target.dart';
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
    required ReportTarget target,
    required String reason,
    String? details,
    Uint8List? attachmentBytes,
    String? attachmentExt,
  }) async {
    _reports.add({
      'type': target.type.wire,
      'id': target.id,
      // WP-439: açık vaka tekilliği tür+kimlik ile; grup ile grup adı ayrı vaka.
      'case_key': target.caseKey,
      'context_group_id': target.contextGroupId,
      'reason': reason,
      'details': details,
      // WP-439: istemci ipucu kanıt değildir; kanonik snapshot sunucuda üretilir.
      'client_hint': target.clientHint,
      // WP-423: demo modda yükleme yok; testler ekin taşındığını buradan görür.
      'attachment': attachmentBytes == null ? null : (attachmentExt ?? 'jpg'),
    });
  }

  /// Test helper.
  List<Map<String, String?>> get reports =>
      List<Map<String, String?>>.unmodifiable(_reports);

  /// WP-439 test helper: bu depoda açılmış ayrık vaka anahtarları.
  Set<String> get caseKeys => {
        for (final r in _reports) r['case_key']!,
      };
}
