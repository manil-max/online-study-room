import '../../models/global_timer.dart';
import '../global_timer_repository.dart';

/// Test/yerel modda remote apply üretmez; idempotent snapshot sözleşmesini taşır.
class InMemoryGlobalTimerRepository implements GlobalTimerRepository {
  GlobalTimerSnapshot _snapshot = GlobalTimerSnapshot(
    stateVersion: 0,
    serverTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
  final Map<String, GlobalTimerSnapshot> _results = {};

  @override
  Future<GlobalTimerSnapshot> fetchSnapshot({String? deviceId}) async =>
      _snapshot;

  @override
  Future<GlobalTimerSnapshot> applyCommand({
    required String commandId,
    required String deviceId,
    required String action,
    String? runId,
    int? expectedRunRevision,
    DateTime? clientOccurredAt,
    Map<String, Object?> payload = const {},
  }) async {
    final duplicate = _results[commandId];
    if (duplicate != null) return duplicate;
    final run = action == 'start'
        ? GlobalTimerRun(id: runId ?? commandId, status: 'running', revision: 1)
        : action == 'stop'
        ? null
        : _snapshot.run;
    _snapshot = GlobalTimerSnapshot(
      stateVersion: _snapshot.stateVersion + (action == 'heartbeat' ? 0 : 1),
      serverTime: DateTime.now().toUtc(),
      run: run,
      resultCode: 'applied',
    );
    return _results[commandId] = _snapshot;
  }

  @override
  Future<GlobalTimerSnapshot> acknowledge({
    required String deviceId,
    required int stateVersion,
    required String status,
    String? runId,
    int? runRevision,
    String? errorCode,
  }) async => _snapshot;
}
