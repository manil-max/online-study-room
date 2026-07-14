import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  test('placeholder snapshot exposes native widget keys', () {
    final snapshot = AndroidWidgetSnapshot.placeholder(l10n);

    expect(snapshot.toWidgetData(), contains(AndroidWidgetKeys.timerElapsed));
    expect(snapshot.toWidgetData(), contains(AndroidWidgetKeys.statsToday));
    expect(
      snapshot.toWidgetData(),
      contains(AndroidWidgetKeys.leaderboardRow1),
    );
  });

  test('timer snapshot keeps non-timer slots on placeholders', () {
    final snapshot = AndroidWidgetSnapshot.timer(
      l10n: l10n,
      elapsed: '00:24:59',
      status: 'Çalışıyor',
      action: 'Durdurmak için aç',
    );

    expect(snapshot.timerElapsed, '00:24:59');
    expect(snapshot.timerStatus, 'Çalışıyor');
    expect(snapshot.statsToday, '0 dk');
    expect(snapshot.paddedLeaderboardRows, ['Henüz kayıt yok', '-', '-']);
  });

  test('leaderboard rows are trimmed to three slots', () {
    const snapshot = AndroidWidgetSnapshot(
      timerTitle: 'Timer',
      timerElapsed: '01:00:00',
      timerStatus: 'Çalışıyor',
      timerAction: 'Aç',
      statsTitle: 'Bugün',
      statsToday: '60 dk',
      statsWeek: 'Hafta: 4 sa',
      statsStreak: 'Seri: 3 gün',
      leaderboardTitle: 'Sıralama',
      leaderboardRows: ['1. Ada', '2. Ece', '3. Can', '4. Mert'],
      dailyGoalPercent: '0%',
      dailyGoalDetail: '-',
      groupGoalPercent: '0%',
      groupGoalDetail: '-',
      leaderboardMyRank: '-',
      emptyLeaderboardLabel: '-',
    );

    expect(snapshot.paddedLeaderboardRows, ['1. Ada', '2. Ece', '3. Can']);
  });

  test('leaderboard rows are padded when empty', () {
    const snapshot = AndroidWidgetSnapshot(
      timerTitle: 'Timer',
      timerElapsed: '00:00:00',
      timerStatus: 'Hazır',
      timerAction: 'Aç',
      statsTitle: 'Bugün',
      statsToday: '0 dk',
      statsWeek: 'Hafta: 0 sa',
      statsStreak: 'Seri: 0 gün',
      leaderboardTitle: 'Sıralama',
      leaderboardRows: [],
      dailyGoalPercent: '0%',
      dailyGoalDetail: '-',
      groupGoalPercent: '0%',
      groupGoalDetail: '-',
      leaderboardMyRank: '-',
      emptyLeaderboardLabel: 'Henüz grup verisi yok',
    );

    expect(snapshot.paddedLeaderboardRows, ['Henüz grup verisi yok', '-', '-']);
  });
}
