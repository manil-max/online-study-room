import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/session_window.dart';
import 'package:online_study_room/data/models/study_session.dart';

void main() {
  group('sessionHotWindow', () {
    // WP-146: now duvar saati; pencere istanbulDay ile hizalanır.
    final now = DateTime(2026, 7, 14);

    StudySession sess(DateTime start) => StudySession(
          id: start.toIso8601String(),
          userId: 'u',
          start: start,
          end: start.add(const Duration(hours: 1)),
          durationSeconds: 3600,
          source: StudySource.live,
        );

    test('90 gün içi sıcak, 91. gün dışı', () {
      expect(
        isSessionInHotWindow(DateTime(2026, 7, 1), now: now),
        isTrue,
      );
      expect(
        isSessionInHotWindow(DateTime(2026, 4, 16), now: now),
        isTrue,
      );
      // 89 gün geri = 16 Nisan 2026 (July 14 - 89 = April 16)
      // 90 gün geri = 15 Nisan — window is 90 days including today
      // start = today - 89 days = April 16
      expect(
        isSessionInHotWindow(DateTime(2026, 4, 15), now: now),
        isFalse,
      );
    });

    test('filterHotWindowSessions eskiyi eler', () {
      final list = [
        sess(DateTime(2026, 7, 10)),
        sess(DateTime(2025, 1, 1)),
        sess(DateTime(2026, 6, 1)),
      ];
      final hot = filterHotWindowSessions(list, startOf: (s) => s.start, now: now);
      expect(hot.length, 2);
      expect(hot.any((s) => s.start.year == 2025), isFalse);
    });
  });
}
