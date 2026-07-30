import '../../models/moderation_appeal.dart';
import '../../models/moderation_case.dart';
import '../../models/moderation_sanction.dart';
import '../admin_moderation_repository.dart';

/// WP-440 / WP-441: Demo/offline ve test kuyruğu.
///
/// Sunucu sözleşmesini birebir taklit eder:
/// * durum yazımı vaka bazlıdır ve `0105` sonrası dört durum da yazılabilir;
/// * yaptırım **idempotenttir** — aynı anahtar ikinci satır açmaz;
/// * hedef başına yalnız tek aktif kısıtlayıcı yaptırım olabilir.
class InMemoryAdminModerationRepository implements AdminModerationRepository {
  InMemoryAdminModerationRepository({List<ModerationCase>? seed})
    : _cases = [...?seed];

  final List<ModerationCase> _cases;
  final List<ModerationSanction> _sanctions = [];
  final Map<String, String> _keyToSanctionId = {};

  /// Testlerin çağrı sırasını görebilmesi için.
  final List<String> statusWrites = [];
  final List<String> quarantineWrites = [];

  bool failNextWrite = false;

  /// Testler süre dolmasını simüle edebilsin diye enjekte edilebilir saat.
  DateTime Function() clock = DateTime.now;

  @override
  Future<List<ModerationCase>> fetchQueue() async =>
      List<ModerationCase>.unmodifiable(_cases);

  @override
  Future<int> setCaseStatus({
    required ModerationCase moderationCase,
    required ModerationCaseStatus status,
  }) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw const ModerationException('Sunucuya ulaşılamadı.');
    }
    final index = _cases.indexWhere((c) => c.caseKey == moderationCase.caseKey);
    if (index < 0) return 0;
    statusWrites.add('${moderationCase.caseKey}=${status.wire}');
    _cases[index] = _cases[index].copyWith(status: status);
    return _cases[index].reportCount;
  }

  @override
  Future<ModerationCaseDetail> fetchDetail(String reportId) async =>
      ModerationCaseDetail(
        snapshot: 'demo snapshot $reportId',
        details: null,
        contextMessages: const [],
        reportCount: _cases.isEmpty ? 0 : _cases.first.reportCount,
        sanctionReasons: [for (final sanction in _sanctions) sanction.reason],
      );

  @override
  Future<ModerationSanction> applySanction(
    ModerationSanctionRequest request,
  ) async {
    if (!request.isValid) {
      throw const ModerationException('Gerekçe ve hedef zorunludur.');
    }
    if (failNextWrite) {
      failNextWrite = false;
      throw const ModerationException('Sunucuya ulaşılamadı.');
    }
    final existingId = _keyToSanctionId[request.idempotencyKey];
    if (existingId != null) {
      return _sanctions.firstWhere((s) => s.id == existingId);
    }
    final at = clock();
    if (request.action.isRestrictive &&
        _sanctions.any(
          (s) => s.targetUserId == request.targetUserId && s.isActive(at),
        )) {
      throw const ModerationException('Hedefte zaten aktif bir kısıt var.');
    }
    final duration = request.action.duration;
    final sanction = ModerationSanction(
      id: 'sanction-${_sanctions.length + 1}',
      targetUserId: request.targetUserId,
      action: request.action,
      reason: request.reason.trim(),
      state: ModerationSanctionState.applied,
      caseId: request.caseId,
      appliedAt: at,
      expiresAt: duration == null ? null : at.add(duration),
    );
    _sanctions.add(sanction);
    _keyToSanctionId[request.idempotencyKey] = sanction.id;
    return sanction;
  }

  @override
  Future<ModerationSanction> revokeSanction({
    required String sanctionId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ModerationException('Gerekçe zorunludur.');
    }
    final index = _sanctions.indexWhere((s) => s.id == sanctionId);
    if (index < 0) {
      throw const ModerationException('Yaptırım bulunamadı.');
    }
    final current = _sanctions[index];
    if (current.state != ModerationSanctionState.applied &&
        current.state != ModerationSanctionState.pending) {
      throw const ModerationException('Bu yaptırım geri alınamaz.');
    }
    final revoked = ModerationSanction(
      id: current.id,
      targetUserId: current.targetUserId,
      action: current.action,
      reason: current.reason,
      state: ModerationSanctionState.revoked,
      caseId: current.caseId,
      appliedAt: current.appliedAt,
      expiresAt: current.expiresAt,
      revokedAt: clock(),
    );
    _sanctions[index] = revoked;
    return revoked;
  }

  @override
  Future<List<ModerationSanction>> fetchSanctions(
    String targetUserId,
  ) async => [
    for (final sanction in _sanctions.reversed)
      if (sanction.targetUserId == targetUserId) sanction,
  ];

  /// Testler itiraz kuyruğunu buradan besler.
  final List<ModerationAppeal> appeals = [];
  final List<String> appealDecisions = [];

  @override
  Future<List<ModerationAppeal>> fetchAppeals() async =>
      List<ModerationAppeal>.unmodifiable(appeals);

  @override
  Future<ModerationAppeal> decideAppeal({
    required ModerationAppeal appeal,
    required bool overturn,
    required String note,
  }) async {
    if (note.trim().isEmpty) {
      throw const ModerationException('Gerekçe zorunludur.');
    }
    if (!appeal.decidable) {
      throw const ModerationException(
        'Kendi verdiğin yaptırımın itirazını karara bağlayamazsın.',
      );
    }
    final index = appeals.indexWhere((a) => a.id == appeal.id);
    if (index < 0) throw const ModerationException('İtiraz bulunamadı.');
    final current = appeals[index];
    // Karar idempotenttir: kararı verilmiş itiraz yeniden yazılmaz.
    if (current.status.isDecided) return current;

    final decided = ModerationAppeal(
      id: current.id,
      sanctionId: current.sanctionId,
      statement: current.statement,
      status: overturn
          ? ModerationAppealStatus.overturned
          : ModerationAppealStatus.upheld,
      createdAt: current.createdAt,
      appellantId: current.appellantId,
      sanctionAction: current.sanctionAction,
      sanctionReason: current.sanctionReason,
      decisionNote: note.trim(),
      decidable: current.decidable,
    );
    appeals[index] = decided;
    appealDecisions.add('${current.id}=${decided.status.wire}');

    if (overturn) {
      final sanctionIndex = _sanctions.indexWhere(
        (s) => s.id == current.sanctionId,
      );
      if (sanctionIndex >= 0 &&
          _sanctions[sanctionIndex].state == ModerationSanctionState.applied) {
        final sanction = _sanctions[sanctionIndex];
        _sanctions[sanctionIndex] = ModerationSanction(
          id: sanction.id,
          targetUserId: sanction.targetUserId,
          action: sanction.action,
          reason: sanction.reason,
          state: ModerationSanctionState.revoked,
          caseId: sanction.caseId,
          appliedAt: sanction.appliedAt,
          expiresAt: sanction.expiresAt,
          revokedAt: clock(),
        );
      }
    }
    return decided;
  }

  @override
  Future<void> setQuarantine({
    required ModerationCase moderationCase,
    required bool quarantined,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ModerationException('Gerekçe zorunludur.');
    }
    if (!moderationCase.supportsCaseActions) {
      throw const ModerationException(
        'Bu tarihsel kayıt vakaya bağlı değil; karantina uygulanamaz.',
      );
    }
    final index = _cases.indexWhere((c) => c.caseKey == moderationCase.caseKey);
    if (index < 0) return;
    quarantineWrites.add('${moderationCase.caseKey}=$quarantined');
    _cases[index] = _cases[index].copyWith(quarantined: quarantined);
  }
}
