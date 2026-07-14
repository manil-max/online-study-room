import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

void main() {
  test(
    'hedef snapshotı günlük ve grup oranlarını native anahtarlara yazar',
    () {
      final snapshot = AndroidWidgetSnapshot.goals(
        dailyPercent: '75%',
        dailyDetail: '135 dk / 180 dk',
        groupPercent: '40%',
        groupDetail: '4 sa / 10 sa',
      );

      expect(
        snapshot.toWidgetData()[AndroidWidgetKeys.dailyGoalPercent],
        '75%',
      );
      expect(
        snapshot.toWidgetData()[AndroidWidgetKeys.dailyGoalDetail],
        '135 dk / 180 dk',
      );
      expect(
        snapshot.toWidgetData()[AndroidWidgetKeys.groupGoalPercent],
        '40%',
      );
      expect(
        snapshot.toWidgetData()[AndroidWidgetKeys.groupGoalDetail],
        '4 sa / 10 sa',
      );
    },
  );

  test('sıralama snapshotı küçük widget için kullanıcının sırasını korur', () {
    final snapshot = AndroidWidgetSnapshot.leaderboard(
      rows: const ['Ada · 2 sa', 'Ece · 1 sa'],
      myRank: 'Sen · #2',
    );

    expect(
      snapshot.toWidgetData()[AndroidWidgetKeys.leaderboardMyRank],
      'Sen · #2',
    );
    expect(snapshot.paddedLeaderboardRows, ['Ada · 2 sa', 'Ece · 1 sa', '-']);
  });
}
