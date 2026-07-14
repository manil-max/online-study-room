import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  test(
    'hedef snapshotı günlük ve grup oranlarını native anahtarlara yazar',
    () {
      final snapshot = AndroidWidgetSnapshot.goals(
        l10n: l10n,
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
      l10n: l10n,
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
