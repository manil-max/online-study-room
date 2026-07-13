import '../../models/achievement_ledger.dart';
import '../../models/study_session.dart';
import '../../../core/stats/achievement_ledger_engine.dart';
import '../achievement_repository.dart';

/// Demo/offline: sunucu RPC kurallarının Dart aynası (XP yalnız engine ledger).
class InMemoryAchievementRepository implements AchievementRepository {
  InMemoryAchievementRepository({AchievementLedgerEngine? engine})
    : _engine = engine ?? AchievementLedgerEngine();

  final AchievementLedgerEngine _engine;

  @override
  Future<List<AchievementDictEntry>> fetchDictionary() async {
    return List.unmodifiable(_engine.dictionary);
  }

  @override
  Future<AchievementEventResult> processEvent({
    required String eventType,
    Map<String, dynamic> payload = const {},
    List<StudySession> sessions = const [],
    int dailyGoalMinutes = 360,
    String? userId,
  }) async {
    final uid = userId ?? 'local-user';
    return _engine.processEvent(
      userId: uid,
      eventType: eventType,
      sessions: sessions,
      dailyGoalMinutes: dailyGoalMinutes,
    );
  }

  /// Test yardımcısı: mevcut defter XP'si.
  int get totalXp => _engine.totalXp;
}
