import '../models/nudge.dart';
import '../models/profile.dart';

const Duration kNudgeCooldown = Duration(minutes: 10);
const int kMaxNudgeMessageLength = 120;

class NudgeException implements Exception {
  const NudgeException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class NudgeRepository {
  Stream<List<Nudge>> watchReceivedNudges(String userId);

  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  });

  Future<void> markRead(String nudgeId);
}

String? normalizeNudgeMessage(String? message) {
  final normalized = message?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > kMaxNudgeMessageLength) {
    throw const NudgeException('Dürtme notu en fazla 120 karakter olabilir.');
  }
  return normalized;
}
