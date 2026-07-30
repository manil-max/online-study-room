import '../../models/moderation_case.dart';
import '../admin_moderation_repository.dart';

/// WP-440: Demo/offline ve test kuyruğu.
///
/// Sunucu sözleşmesini birebir taklit eder: durum yazımı vaka bazlıdır ve
/// [ModerationCaseStatus.open] yazılamaz — yanlışlıkla kapatılan vaka
/// `in_review` ile geri alınır.
class InMemoryAdminModerationRepository implements AdminModerationRepository {
  InMemoryAdminModerationRepository({List<ModerationCase>? seed})
      : _cases = [...?seed];

  final List<ModerationCase> _cases;

  /// Testlerin çağrı sırasını görebilmesi için.
  final List<String> statusWrites = [];

  bool failNextWrite = false;

  @override
  Future<List<ModerationCase>> fetchQueue() async =>
      List<ModerationCase>.unmodifiable(_cases);

  @override
  Future<int> setCaseStatus({
    required ModerationCase moderationCase,
    required ModerationCaseStatus status,
  }) async {
    if (!status.writable) {
      throw const ModerationException(
        'Vakayı yeniden açma sunucuda henüz tanımlı değil.',
      );
    }
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
        sanctionReasons: const [],
      );
}
