import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/study_session.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/study_providers.dart';

/// Saat Merkezi Timer / Kronometre sürelerini `study_sessions`'a yazar.
///
/// - Giriş yoksa no-op
/// - [minDurationSeconds] altı sayılmaz (yanlış tıklama / gürültü)
/// - `subjectId` null → dersiz oturum (odak sayacıyla aynı)
/// - Kaynak: [StudySource.live] (istatistikte ayrım yok)
class ClockStudyRecorder {
  ClockStudyRecorder(this._ref);

  final Ref _ref;
  static const minDurationSeconds = 30;
  static const _uuid = Uuid();

  /// [durationSeconds] kadar süreyi [end] anında biten oturum olarak kaydet.
  Future<bool> recordDuration({
    required int durationSeconds,
    DateTime? end,
    String? subjectId,
  }) async {
    if (durationSeconds < minDurationSeconds) return false;
    final user = _ref.read(authStateProvider).value;
    if (user == null) return false;

    final endAt = end ?? DateTime.now();
    final startAt = endAt.subtract(Duration(seconds: durationSeconds));

    await _ref.read(studyRepositoryProvider).addSession(
          StudySession(
            id: _uuid.v4(),
            userId: user.id,
            subjectId: subjectId,
            start: startAt,
            end: endAt,
            durationSeconds: durationSeconds,
            source: StudySource.live,
          ),
        );
    return true;
  }

  /// [start]–[end] aralığını kaydet.
  Future<bool> recordRange({
    required DateTime start,
    required DateTime end,
    String? subjectId,
  }) async {
    final sec = end.difference(start).inSeconds;
    return recordDuration(
      durationSeconds: sec,
      end: end,
      subjectId: subjectId,
    );
  }
}

final clockStudyRecorderProvider = Provider<ClockStudyRecorder>((ref) {
  return ClockStudyRecorder(ref);
});
