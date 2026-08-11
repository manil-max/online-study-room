import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

import 'package:online_study_room/core/notifications/timer_external_command_store.dart';
import 'package:online_study_room/core/l10n/system_localizations.dart';
import 'package:online_study_room/features/android_widgets/published_home_widgets.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri?.host == 'timer' && uri?.path == '/toggle') {
    final prefs = await SharedPreferences.getInstance();
    final store = TimerExternalCommandStore(prefs);
    final isRunning = prefs.containsKey('timer_active_started_at');
    await store.setCommand(isRunning ? 'stop' : 'start');
  }
}

/// Android dışı platformlarda no-op: Windows/web'de home_widget kanalı yok;
/// her saniye MissingPluginException + async fırtınası jank/RAM şişirir.
final androidWidgetServiceProvider = Provider<AndroidWidgetGateway>((ref) {
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  return isAndroid
      ? const AndroidWidgetService()
      : const _NoopAndroidWidgetService();
});

class _NoopAndroidWidgetService implements AndroidWidgetGateway {
  const _NoopAndroidWidgetService();

  @override
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot) async {}

  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {}

  @override
  Future<void> seedPlaceholder() async {}
}

/// WP-696: cizimi native akan, Flutter yayinina IHTIYACI OLMAYAN saglayicilar.
///
/// `ClockWidgetProvider.onUpdate` yalniz layout'u sisirir; iki `TextClock`
/// sistem saatiyle kendi akar (`StudyWidgetProviders.kt:356-368`). Bu yuzden
/// [StudyHomeWidget] uyesi olmasina gerek yoktur.
///
/// `AlarmWidgetProvider` (`StudyWidgetProviders.kt:371-410`) bu listede DEGIL:
/// `flutter.native_alarm_mirror_v1`'i yalniz `onUpdate` icinde okur ve mirror
/// degistiginde (`native_alarm_bridge.dart:145`) kimse ona yayin gondermez;
/// tek tazeleme kaynagi `odak_alarm_widget_info.xml`'deki 30 dakikalik
/// `updatePeriodMillis`'tir.
const Set<HomeWidgetProvider> kSelfUpdatingHomeWidgets = {
  HomeWidgetProvider.clock,
};

/// Yayindaki bir saglayicinin tazeleme yolu var mi?
///
/// Iki gecerli yol: [StudyHomeWidget] uyesi olmak (Flutter `updateWidget`
/// gonderir) ya da [kSelfUpdatingHomeWidgets] icinde olmak.
bool hasHomeWidgetRefreshPath(HomeWidgetProvider provider) =>
    kSelfUpdatingHomeWidgets.contains(provider) ||
    StudyHomeWidget.values.any((widget) => widget.catalogProvider == provider);

enum StudyHomeWidget {
  timer(
    androidName: 'TimerWidgetProvider',
    qualifiedAndroidName:
        'com.manilmax.online_study_room.widgets.TimerWidgetProvider',
    catalogProvider: HomeWidgetProvider.timer,
    consumesWidgetData: false,
  ),
  stats(
    androidName: 'StudyStatsWidgetProvider',
    qualifiedAndroidName:
        'com.manilmax.online_study_room.widgets.StudyStatsWidgetProvider',
    catalogProvider: HomeWidgetProvider.studyStats,
    consumesWidgetData: true,
  ),
  leaderboard(
    androidName: 'GroupLeaderboardWidgetProvider',
    qualifiedAndroidName:
        'com.manilmax.online_study_room.widgets.GroupLeaderboardWidgetProvider',
    catalogProvider: HomeWidgetProvider.groupLeaderboard,
    consumesWidgetData: true,
  ),
  groupGoal(
    androidName: 'GroupGoalWidgetProvider',
    qualifiedAndroidName:
        'com.manilmax.online_study_room.widgets.GroupGoalWidgetProvider',
    catalogProvider: HomeWidgetProvider.groupGoal,
    consumesWidgetData: true,
  );

  const StudyHomeWidget({
    required this.androidName,
    required this.qualifiedAndroidName,
    required this.catalogProvider,
    required this.consumesWidgetData,
  });

  final String androidName;
  final String qualifiedAndroidName;

  /// WP-558: yayın bayrağının **tek** kaynağına köprü.
  ///
  /// Bu enum ile [HomeWidgetProvider] birbirinden habersiz iki listeydi; boru
  /// hattı yalnız bunu kullandığı için `published: false` olan üç widget'a
  /// her veri değişiminde yayın gitmeye devam ediyordu.
  final HomeWidgetProvider catalogProvider;

  /// Sağlayıcının `onUpdate`'i `widgetData`'yı gerçekten okuyor mu?
  ///
  /// `TimerWidgetProvider.onUpdate` `widgetData` parametresine hiç dokunmaz;
  /// süreyi ve düğme etiketini doğrudan `TimerStateStore` prefs'inden projekte
  /// eder (`StudyWidgetProviders.kt`). Bu yüzden sayaç için `false`.
  final bool consumesWidgetData;

  /// Yayında olmayan sağlayıcıya `updateWidget` gönderilmez.
  bool get isPublished => isHomeWidgetPublished(catalogProvider);

  /// `saveWidgetData` yalnız yayında **ve** veriyi okuyan bir tüketici varsa
  /// anlamlıdır; yoksa her snapshot 17 boş platform kanalı turudur.
  static bool get anyPublishedConsumesWidgetData =>
      values.any((widget) => widget.isPublished && widget.consumesWidgetData);
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
  static const dailyGoalPercent = 'daily_goal_percent';
  static const dailyGoalDetail = 'daily_goal_detail';
  static const groupGoalPercent = 'group_goal_percent';
  static const groupGoalDetail = 'group_goal_detail';
  static const leaderboardTitle = 'leaderboard_title';
  static const leaderboardRow1 = 'leaderboard_row_1';
  static const leaderboardRow2 = 'leaderboard_row_2';
  static const leaderboardRow3 = 'leaderboard_row_3';
  static const leaderboardMyRank = 'leaderboard_my_rank';

  /// WP-696: her snapshot yalniz KENDI anahtarlarini yazar.
  ///
  /// `_syncStatsWidgets` ayni turda iki kez `saveSnapshot` cagiriyor; her
  /// snapshot 17 anahtarin hepsini yazdigi icin ikinci cagri birincinin gercek
  /// degerlerini placeholder ile eziyordu (gunluk hedef ve grup hedefi hep
  /// `%0`). Sahiplik kumeleri bu ezmeyi imkansiz kilar.
  static const Set<String> timerGroup = {
    timerTitle,
    timerElapsed,
    timerStatus,
    timerAction,
  };
  static const Set<String> statsGroup = {
    statsTitle,
    statsToday,
    statsWeek,
    statsStreak,
  };
  static const Set<String> dailyGoalGroup = {dailyGoalPercent, dailyGoalDetail};
  static const Set<String> groupGoalGroup = {groupGoalPercent, groupGoalDetail};
  static const Set<String> leaderboardGroup = {
    leaderboardTitle,
    leaderboardRow1,
    leaderboardRow2,
    leaderboardRow3,
    leaderboardMyRank,
  };

  /// `goals` turu: gunluk + grup hedefi gercek; ozet basligi/degeri gunluk
  /// hedefin aynasi. Seri (`statsStreak`) icin gercek uretici YOKTUR, bu yuzden
  /// bu tur ona dokunmaz — saglayici kendi kaynak yedegini gosterir.
  static const Set<String> goalsGroup = {
    ...dailyGoalGroup,
    ...groupGoalGroup,
    statsTitle,
    statsToday,
    statsWeek,
  };

  static const Set<String> all = {
    ...timerGroup,
    ...statsGroup,
    ...dailyGoalGroup,
    ...groupGoalGroup,
    ...leaderboardGroup,
  };
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
    required this.dailyGoalPercent,
    required this.dailyGoalDetail,
    required this.groupGoalPercent,
    required this.groupGoalDetail,
    required this.leaderboardMyRank,
    required this.emptyLeaderboardLabel,
    this.ownedKeys = AndroidWidgetKeys.all,
  });

  AndroidWidgetSnapshot.placeholder(AppLocalizations l10n)
    : timerTitle = l10n.desktopOdakKampi,
      timerElapsed = '00:00:00',
      timerStatus = l10n.commonCalismaHazir,
      timerAction = l10n.androidWidgetsUygulamayiAc,
      statsTitle = l10n.statsBugun,
      statsToday = l10n.clockMDk('0'),
      statsWeek = l10n.androidWidgetsHafta0Sa,
      statsStreak = l10n.androidWidgetsHedefSerisi0Gun,
      dailyGoalPercent = '0%',
      dailyGoalDetail = '${l10n.clockMDk('0')} / ${l10n.clockMDk('0')}',
      groupGoalPercent = '0%',
      groupGoalDetail = l10n.commonGrupHedefiBelirlenmedi,
      leaderboardTitle = l10n.androidWidgetsKampSiralamasi,
      leaderboardRows = [l10n.androidWidgetsHenuzKayitYok2, '-', '-'],
      leaderboardMyRank = l10n.commonSiralamaOlusuncaBuradaGorunur,
      emptyLeaderboardLabel = l10n.androidWidgetsHenuzGrupVerisiYok,
      ownedKeys = AndroidWidgetKeys.all;

  AndroidWidgetSnapshot.timer({
    required AppLocalizations l10n,
    required String elapsed,
    required String status,
    required String action,
  }) : this(
         timerTitle: l10n.desktopOdakKampi,
         timerElapsed: elapsed,
         timerStatus: status,
         timerAction: action,
         statsTitle: l10n.statsBugun,
         statsToday: l10n.clockMDk('0'),
         statsWeek: l10n.androidWidgetsHafta0Sa,
         statsStreak: l10n.androidWidgetsHedefSerisi0Gun,
         dailyGoalPercent: '0%',
         dailyGoalDetail: '${l10n.clockMDk('0')} / ${l10n.clockMDk('0')}',
         groupGoalPercent: '0%',
         groupGoalDetail: l10n.commonGrupHedefiBelirlenmedi,
         leaderboardTitle: l10n.androidWidgetsKampSiralamasi,
         leaderboardRows: [l10n.androidWidgetsHenuzKayitYok2, '-', '-'],
         leaderboardMyRank: l10n.commonSiralamaOlusuncaBuradaGorunur,
         emptyLeaderboardLabel: l10n.androidWidgetsHenuzGrupVerisiYok,
         ownedKeys: AndroidWidgetKeys.timerGroup,
       );

  AndroidWidgetSnapshot.stats({
    required AppLocalizations l10n,
    required String today,
    required String week,
    required String streak,
  }) : this(
         timerTitle: l10n.desktopOdakKampi,
         timerElapsed: '00:00:00',
         timerStatus: l10n.commonCalismaHazir,
         timerAction: l10n.androidWidgetsUygulamayiAc,
         statsTitle: l10n.androidWidgetsCalismaOzeti,
         statsToday: today,
         statsWeek: week,
         statsStreak: streak,
         dailyGoalPercent: '0%',
         dailyGoalDetail: '${l10n.clockMDk('0')} / ${l10n.clockMDk('0')}',
         groupGoalPercent: '0%',
         groupGoalDetail: l10n.commonGrupHedefiBelirlenmedi,
         leaderboardTitle: l10n.androidWidgetsKampSiralamasi,
         leaderboardRows: [l10n.androidWidgetsHenuzKayitYok2, '-', '-'],
         leaderboardMyRank: l10n.commonSiralamaOlusuncaBuradaGorunur,
         emptyLeaderboardLabel: l10n.androidWidgetsHenuzGrupVerisiYok,
         ownedKeys: AndroidWidgetKeys.statsGroup,
       );

  AndroidWidgetSnapshot.leaderboard({
    required AppLocalizations l10n,
    required List<String> rows,
    String? myRank,
  }) : this(
         timerTitle: l10n.desktopOdakKampi,
         timerElapsed: '00:00:00',
         timerStatus: l10n.commonCalismaHazir,
         timerAction: l10n.androidWidgetsUygulamayiAc,
         statsTitle: l10n.statsBugun,
         statsToday: l10n.clockMDk('0'),
         statsWeek: l10n.androidWidgetsHafta0Sa,
         statsStreak: l10n.androidWidgetsHedefSerisi0Gun,
         dailyGoalPercent: '0%',
         dailyGoalDetail: '${l10n.clockMDk('0')} / ${l10n.clockMDk('0')}',
         groupGoalPercent: '0%',
         groupGoalDetail: l10n.commonGrupHedefiBelirlenmedi,
         leaderboardTitle: l10n.homeGrupSiralamasi,
         leaderboardRows: rows,
         leaderboardMyRank: myRank ?? l10n.commonSiralamaOlusuncaBuradaGorunur,
         emptyLeaderboardLabel: l10n.androidWidgetsHenuzGrupVerisiYok,
         ownedKeys: AndroidWidgetKeys.leaderboardGroup,
       );

  AndroidWidgetSnapshot.goals({
    required AppLocalizations l10n,
    required String dailyPercent,
    required String dailyDetail,
    required String groupPercent,
    required String groupDetail,
  }) : this(
         timerTitle: l10n.desktopOdakKampi,
         timerElapsed: '00:00:00',
         timerStatus: l10n.commonCalismaHazir,
         timerAction: l10n.androidWidgetsUygulamayiAc,
         statsTitle: l10n.profileGunlukHedef,
         statsToday: dailyPercent,
         statsWeek: dailyDetail,
         statsStreak: l10n.androidWidgetsHedefSerisi0Gun,
         dailyGoalPercent: dailyPercent,
         dailyGoalDetail: dailyDetail,
         groupGoalPercent: groupPercent,
         groupGoalDetail: groupDetail,
         leaderboardTitle: l10n.androidWidgetsKampSiralamasi,
         leaderboardRows: [l10n.androidWidgetsHenuzKayitYok2, '-', '-'],
         leaderboardMyRank: l10n.commonSiralamaOlusuncaBuradaGorunur,
         emptyLeaderboardLabel: l10n.androidWidgetsHenuzGrupVerisiYok,
         ownedKeys: AndroidWidgetKeys.goalsGroup,
       );

  final String timerTitle;
  final String timerElapsed;
  final String timerStatus;
  final String timerAction;
  final String statsTitle;
  final String statsToday;
  final String statsWeek;
  final String statsStreak;
  final String dailyGoalPercent;
  final String dailyGoalDetail;
  final String groupGoalPercent;
  final String groupGoalDetail;
  final String leaderboardTitle;
  final List<String> leaderboardRows;
  final String leaderboardMyRank;
  final String emptyLeaderboardLabel;

  /// Bu snapshot'in GERCEK deger tasidigi anahtarlar; yalniz bunlar yazilir.
  final Set<String> ownedKeys;

  Map<String, Object> toWidgetData() {
    final rows = paddedLeaderboardRows;
    final all = <String, Object>{
      AndroidWidgetKeys.timerTitle: timerTitle,
      AndroidWidgetKeys.timerElapsed: timerElapsed,
      AndroidWidgetKeys.timerStatus: timerStatus,
      AndroidWidgetKeys.timerAction: timerAction,
      AndroidWidgetKeys.statsTitle: statsTitle,
      AndroidWidgetKeys.statsToday: statsToday,
      AndroidWidgetKeys.statsWeek: statsWeek,
      AndroidWidgetKeys.statsStreak: statsStreak,
      AndroidWidgetKeys.dailyGoalPercent: dailyGoalPercent,
      AndroidWidgetKeys.dailyGoalDetail: dailyGoalDetail,
      AndroidWidgetKeys.groupGoalPercent: groupGoalPercent,
      AndroidWidgetKeys.groupGoalDetail: groupGoalDetail,
      AndroidWidgetKeys.leaderboardTitle: leaderboardTitle,
      AndroidWidgetKeys.leaderboardRow1: rows[0],
      AndroidWidgetKeys.leaderboardRow2: rows[1],
      AndroidWidgetKeys.leaderboardRow3: rows[2],
      AndroidWidgetKeys.leaderboardMyRank: leaderboardMyRank,
    };
    return {
      for (final entry in all.entries)
        if (ownedKeys.contains(entry.key)) entry.key: entry.value,
    };
  }

  @visibleForTesting
  List<String> get paddedLeaderboardRows {
    final rows = leaderboardRows.where((row) => row.trim().isNotEmpty).toList();
    if (rows.isEmpty) {
      rows.add(emptyLeaderboardLabel);
    }
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
    // WP-558: yayında `widgetData` okuyan sağlayıcı yoksa tek anahtar bile
    // yazılmaz — 17 anahtar × ayrı kanal turu boşuna gidiyordu.
    if (!StudyHomeWidget.anyPublishedConsumesWidgetData) return;
    for (final entry in snapshot.toWidgetData().entries) {
      await _saveValue(entry.key, entry.value);
    }
  }

  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {
    // WP-558: allowlist tek kapı — yayında olmayan sağlayıcıya yayın yok.
    final targets = (widgets ?? StudyHomeWidget.values).where(
      (widget) => widget.isPublished,
    );
    for (final widget in targets) {
      await HomeWidget.updateWidget(
        androidName: widget.androidName,
        qualifiedAndroidName: widget.qualifiedAndroidName,
      );
    }
  }

  @override
  Future<void> seedPlaceholder() async {
    final l10n = await loadSystemLocalizations();
    await saveSnapshot(AndroidWidgetSnapshot.placeholder(l10n));
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
