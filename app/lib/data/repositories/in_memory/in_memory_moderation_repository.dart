import 'dart:typed_data';

import '../../models/moderation_appeal.dart';
import '../../models/moderation_sanction.dart';
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

  /// Testler kendi hakkındaki yaptırımı buradan besler.
  final List<ModerationSanction> sanctions = [];
  final List<ModerationAppeal> appeals = [];

  @override
  Future<List<ModerationSanction>> fetchMySanctions() async =>
      List<ModerationSanction>.unmodifiable(sanctions);

  @override
  Future<List<ModerationAppeal>> fetchMyAppeals() async =>
      List<ModerationAppeal>.unmodifiable(appeals);

  @override
  Future<ModerationAppeal> submitAppeal({
    required String sanctionId,
    required String statement,
  }) async {
    final trimmed = statement.trim();
    if (trimmed.length < kAppealMinLength) {
      throw const ModerationException('İtiraz metni çok kısa.');
    }
    // Sunucudaki tekillik: bir yaptırıma tek itiraz.
    final existing = appeals.where((a) => a.sanctionId == sanctionId).firstOrNull;
    if (existing != null) return existing;

    final sanction = sanctions.where((s) => s.id == sanctionId).firstOrNull;
    if (sanction == null) {
      throw const ModerationException('Yaptırım bulunamadı.');
    }
    if (sanction.state != ModerationSanctionState.applied) {
      throw const ModerationException('Bu yaptırıma itiraz edilemez.');
    }
    final appeal = ModerationAppeal(
      id: 'appeal-${appeals.length + 1}',
      sanctionId: sanctionId,
      statement: trimmed,
      status: ModerationAppealStatus.open,
      createdAt: DateTime.now(),
      sanctionAction: sanction.action,
      sanctionReason: sanction.reason,
    );
    appeals.add(appeal);
    return appeal;
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
