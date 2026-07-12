import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

import 'package:online_study_room/core/notifications/timer_external_command_store.dart';

@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri?.host == 'timer' && uri?.path == '/toggle') {
    final prefs = await SharedPreferences.getInstance();
    final store = TimerExternalCommandStore(prefs);
    final isRunning = prefs.containsKey('timer_active_started_at');
    await store.setCommand(isRunning ? 'stop' : 'start');
  }
}

final androidWidgetServiceProvider = Provider<AndroidWidgetGateway>(
  (ref) => const AndroidWidgetService(),
);

enum StudyHomeWidget {
  timer(
    androidName: 'TimerWidgetProvider',
    qualifiedAndroidName:
        'com.manilmax.online_study_room.widgets.TimerWidgetProvider',
  ),
  stats(
    androidName: 'StudyStatsWidgetProvider',
    qualifiedAndroidName:
        'com.manilmax.online_study_room.widgets.StudyStatsWidgetProvider',
  ),
  leaderboard(
    androidName: 'GroupLeaderboardWidgetProvider',
    qualifiedAndroidName:
        'com.manilmax.online_study_room.widgets.GroupLeaderboardWidgetProvider',
  );

  const StudyHomeWidget({
    required this.androidName,
    required this.qualifiedAndroidName,
  });

  final String androidName;
  final String qualifiedAndroidName;
}

abstract final class AndroidWidgetKeys {
  static const timerTitle = 'timer_title';
  static const timerElapsed = 'timer_elapsed';
  static const timerStatus = 'timer_status';
  static const timerAction = 'timer_action';
  static const statsTitle = 'stats_title';
  static const statsToday = 'stats_today';
  static const statsWeek = 'stats_week';
  static const statsStreak = 'stats_streak';
  static const leaderboardTitle = 'leaderboard_title';
  static const leaderboardRow1 = 'leaderboard_row_1';
  static const leaderboardRow2 = 'leaderboard_row_2';
  static const leaderboardRow3 = 'leaderboard_row_3';
}

@immutable
class AndroidWidgetSnapshot {
  const AndroidWidgetSnapshot({
    required this.timerTitle,
    required this.timerElapsed,
    required this.timerStatus,
    required this.timerAction,
    required this.statsTitle,
    required this.statsToday,
    required this.statsWeek,
    required this.statsStreak,
    required this.leaderboardTitle,
    required this.leaderboardRows,
  });

  const AndroidWidgetSnapshot.placeholder()
    : timerTitle = 'Odak Kampı',
      timerElapsed = '00:00:00',
      timerStatus = 'Çalışma hazır',
      timerAction = 'Uygulamayı aç',
      statsTitle = 'Bugün',
      statsToday = '0 dk',
      statsWeek = 'Hafta: 0 sa',
      statsStreak = 'Seri: 0 gün',
      leaderboardTitle = 'Kamp sıralaması',
      leaderboardRows = const ['Henüz kayıt yok', '-', '-'];

  AndroidWidgetSnapshot.timer({
    required String elapsed,
    required String status,
    required String action,
  }) : this(
         timerTitle: const AndroidWidgetSnapshot.placeholder().timerTitle,
         timerElapsed: elapsed,
         timerStatus: status,
         timerAction: action,
         statsTitle: const AndroidWidgetSnapshot.placeholder().statsTitle,
         statsToday: const AndroidWidgetSnapshot.placeholder().statsToday,
         statsWeek: const AndroidWidgetSnapshot.placeholder().statsWeek,
         statsStreak: const AndroidWidgetSnapshot.placeholder().statsStreak,
         leaderboardTitle:
             const AndroidWidgetSnapshot.placeholder().leaderboardTitle,
         leaderboardRows:
             const AndroidWidgetSnapshot.placeholder().leaderboardRows,
       );

  AndroidWidgetSnapshot.stats({
    required String today,
    required String week,
    required String streak,
  }) : this(
         timerTitle: const AndroidWidgetSnapshot.placeholder().timerTitle,
         timerElapsed: const AndroidWidgetSnapshot.placeholder().timerElapsed,
         timerStatus: const AndroidWidgetSnapshot.placeholder().timerStatus,
         timerAction: const AndroidWidgetSnapshot.placeholder().timerAction,
         statsTitle: 'Çalışma özeti',
         statsToday: today,
         statsWeek: week,
         statsStreak: streak,
         leaderboardTitle:
             const AndroidWidgetSnapshot.placeholder().leaderboardTitle,
         leaderboardRows:
             const AndroidWidgetSnapshot.placeholder().leaderboardRows,
       );

  AndroidWidgetSnapshot.leaderboard({required List<String> rows})
    : this(
        timerTitle: const AndroidWidgetSnapshot.placeholder().timerTitle,
        timerElapsed: const AndroidWidgetSnapshot.placeholder().timerElapsed,
        timerStatus: const AndroidWidgetSnapshot.placeholder().timerStatus,
        timerAction: const AndroidWidgetSnapshot.placeholder().timerAction,
        statsTitle: const AndroidWidgetSnapshot.placeholder().statsTitle,
        statsToday: const AndroidWidgetSnapshot.placeholder().statsToday,
        statsWeek: const AndroidWidgetSnapshot.placeholder().statsWeek,
        statsStreak: const AndroidWidgetSnapshot.placeholder().statsStreak,
        leaderboardTitle: 'Grup sıralaması',
        leaderboardRows: rows,
      );

  final String timerTitle;
  final String timerElapsed;
  final String timerStatus;
  final String timerAction;
  final String statsTitle;
  final String statsToday;
  final String statsWeek;
  final String statsStreak;
  final String leaderboardTitle;
  final List<String> leaderboardRows;

  Map<String, Object> toWidgetData() {
    final rows = paddedLeaderboardRows;
    return {
      AndroidWidgetKeys.timerTitle: timerTitle,
      AndroidWidgetKeys.timerElapsed: timerElapsed,
      AndroidWidgetKeys.timerStatus: timerStatus,
      AndroidWidgetKeys.timerAction: timerAction,
      AndroidWidgetKeys.statsTitle: statsTitle,
      AndroidWidgetKeys.statsToday: statsToday,
      AndroidWidgetKeys.statsWeek: statsWeek,
      AndroidWidgetKeys.statsStreak: statsStreak,
      AndroidWidgetKeys.leaderboardTitle: leaderboardTitle,
      AndroidWidgetKeys.leaderboardRow1: rows[0],
      AndroidWidgetKeys.leaderboardRow2: rows[1],
      AndroidWidgetKeys.leaderboardRow3: rows[2],
    };
  }

  @visibleForTesting
  List<String> get paddedLeaderboardRows {
    final rows = leaderboardRows.where((row) => row.trim().isNotEmpty).toList();
    while (rows.length < 3) {
      rows.add('-');
    }
    return rows.take(3).toList(growable: false);
  }
}

abstract interface class AndroidWidgetGateway {
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot);

  Future<void> refresh({Iterable<StudyHomeWidget>? widgets});

  Future<void> seedPlaceholder();
}

class AndroidWidgetService implements AndroidWidgetGateway {
  const AndroidWidgetService();

  @override
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot) async {
    for (final entry in snapshot.toWidgetData().entries) {
      await _saveValue(entry.key, entry.value);
    }
  }

  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {
    for (final widget in widgets ?? StudyHomeWidget.values) {
      await HomeWidget.updateWidget(
        androidName: widget.androidName,
        qualifiedAndroidName: widget.qualifiedAndroidName,
      );
    }
  }

  @override
  Future<void> seedPlaceholder() async {
    await saveSnapshot(const AndroidWidgetSnapshot.placeholder());
    await refresh();
  }

  Future<void> _saveValue(String key, Object value) {
    if (value is int) {
      return HomeWidget.saveWidgetData<int>(key, value);
    }
    if (value is double) {
      return HomeWidget.saveWidgetData<double>(key, value);
    }
    if (value is bool) {
      return HomeWidget.saveWidgetData<bool>(key, value);
    }
    return HomeWidget.saveWidgetData<String>(key, value.toString());
  }
}
