import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

import 'package:online_study_room/core/notifications/timer_external_command_store.dart';
import 'package:online_study_room/core/l10n/system_localizations.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
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
  ),

  /// WP-695: sınav geri sayımı.
  ///
  /// `consumesWidgetData: false` — sağlayıcı veriyi `home_widget`in
  /// `widgetData` sözlüğünden değil, uygulamanın kendi
  /// `FlutterSharedPreferences` kaydından (`flutter.dday.exams_v2`) okur.
  /// `true` yazmak [anyPublishedConsumesWidgetData] kapısını açar ve
  /// WP-558'in kapattığı "her anlık görüntüde 17 platform kanalı turu"
  /// gerilemesini geri getirirdi; ayrıca widget yalnız uygulama en az bir kez
  /// snapshot yazdıktan sonra dolardı.
  countdown(
    androidName: 'CountdownWidgetProvider',
    qualifiedAndroidName:
        'com.manilmax.online_study_room.widgets.CountdownWidgetProvider',
    catalogProvider: HomeWidgetProvider.countdown,
    consumesWidgetData: false,
  ),

  /// WP-701: görev listesi.
  ///
  /// `consumesWidgetData: false` — sağlayıcı `home_widget`in `widgetData`
  /// sözlüğünü değil, [TaskWidgetPrefsKeys.mirror] aynasını okur (geri
  /// sayımın deseni). `true` yazmak WP-558'in kapattığı "her anlık görüntüde
  /// 17 platform kanalı turu" gerilemesini geri getirirdi.
  task(
    androidName: 'TaskWidgetProvider',
    qualifiedAndroidName:
        'com.manilmax.online_study_room.widgets.TaskWidgetProvider',
    catalogProvider: HomeWidgetProvider.task,
    consumesWidgetData: false,
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

  /// 🔴 WP-708: sağlayıcının Kotlin `onUpdate`'inin GERÇEKTEN okuduğu anahtarlar.
  ///
  /// Neden gerekli: [anyPublishedConsumesWidgetData] **genel** bir kapıdır.
  /// WP-707 dört widget'ı yayına alınca kapı `true` oldu ve `saveSnapshot`
  /// yeniden **her** anahtarı yazmaya başladı — `widgetData`'ya hiç bakmayan
  /// sayaç widget'ının dört anahtarı dâhil. WP-558'in kapattığı israf tam
  /// olarak buydu (sayaç turu: 0 kanal turu → yine 4). Genel kapı, yayın
  /// listesi büyüdüğü anda ölçmeyi bırakan bir kapıydı.
  ///
  /// Kümeler elle sayılmadı, `StudyWidgetProviders.kt` sınıf gövdelerinden
  /// türetilip doğrulandı (`widget_key_ownership_wp708_test.dart`). Ölçüm:
  /// `stats_title` / `stats_today` / `stats_week` sabitleri tanımlı ama
  /// **hiçbir sağlayıcı okumuyor** — o üç anahtar artık hiç yazılmaz.
  Set<String> get readKeys => switch (this) {
    StudyHomeWidget.stats => const {
      AndroidWidgetKeys.dailyGoalPercent,
      AndroidWidgetKeys.dailyGoalDetail,
      AndroidWidgetKeys.statsStreak,
    },
    StudyHomeWidget.leaderboard => AndroidWidgetKeys.leaderboardGroup,
    StudyHomeWidget.groupGoal => AndroidWidgetKeys.groupGoalGroup,
    // `consumesWidgetData: false` olanlar veriyi kendi prefs kaydından okur.
    StudyHomeWidget.timer ||
    StudyHomeWidget.countdown ||
    StudyHomeWidget.task => const <String>{},
  };

  /// Yayındaki tüketicilerin okuduğu anahtarların birleşimi — `saveSnapshot`
  /// yalnız bunları yazar. Boşsa tek kanal turu bile yapılmaz.
  static Set<String> get writableKeys => {
    for (final widget in values)
      if (widget.isPublished && widget.consumesWidgetData) ...widget.readKeys,
  };
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

  /// WP-707: seri satirinin **tek** sahibi.
  ///
  /// Kendi kumesinde durur cunku uretici de ayridir: gunluk/grup hedefi yerel
  /// projeksiyondan, seri ise sunucudaki kanonik `goal_streak_projection`
  /// RPC'sinden gelir. Ayni snapshot'a katilsaydi RPC yavas/cevrimdisi
  /// oldugunda hedef yuzdesi de yazilamazdi.
  static const Set<String> streakGroup = {statsStreak};

  /// `goals` turu: gunluk + grup hedefi gercek; ozet basligi/degeri gunluk
  /// hedefin aynasi. Seri (`statsStreak`) [streakGroup] tarafindan ayri
  /// yazilir; bu tur ona dokunmaz.
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

  /// WP-707: seri satiri (`stats_streak`).
  ///
  /// 🔴 Bu kurucu once `AndroidWidgetSnapshot.stats` adiyla vardi ve `lib/`
  /// icinde HIC cagrilmiyordu; ustelik `statsGroup`u sahiplendigi icin
  /// cagrilsaydi `goals` turunun gercek gunluk hedef degerlerini ezerdi
  /// (WP-696 kusuru). Artik tek isi vardir ve tek anahtar sahiplenir.
  AndroidWidgetSnapshot.streak({
    required AppLocalizations l10n,
    required String streak,
  }) : this(
         timerTitle: l10n.desktopOdakKampi,
         timerElapsed: '00:00:00',
         timerStatus: l10n.commonCalismaHazir,
         timerAction: l10n.androidWidgetsUygulamayiAc,
         statsTitle: l10n.androidWidgetsCalismaOzeti,
         statsToday: l10n.clockMDk('0'),
         statsWeek: l10n.androidWidgetsHafta0Sa,
         statsStreak: streak,
         dailyGoalPercent: '0%',
         dailyGoalDetail: '${l10n.clockMDk('0')} / ${l10n.clockMDk('0')}',
         groupGoalPercent: '0%',
         groupGoalDetail: l10n.commonGrupHedefiBelirlenmedi,
         leaderboardTitle: l10n.androidWidgetsKampSiralamasi,
         leaderboardRows: [l10n.androidWidgetsHenuzKayitYok2, '-', '-'],
         leaderboardMyRank: l10n.commonSiralamaOlusuncaBuradaGorunur,
         emptyLeaderboardLabel: l10n.androidWidgetsHenuzGrupVerisiYok,
         ownedKeys: AndroidWidgetKeys.streakGroup,
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
    //
    // 🔴 WP-708: kapı artık ANAHTAR BASINA. Genel bayrak tek başına yetmiyor:
    // WP-707 dört widget'ı yayına alınca bayrak `true` oldu ve okuyucusu
    // OLMAYAN anahtarlar da yeniden yazılmaya başladı (sayaç turu 0 → 4 kanal).
    // Bir kapının, ölçtüğü koşul genişleyince sessizce ölçmeyi bırakması bu
    // depodaki tekrarlayan kusur; burada koşul yayın listesine değil,
    // anahtarın gerçek okuyucusuna bağlandı.
    final writable = StudyHomeWidget.writableKeys;
    if (writable.isEmpty) return;
    for (final entry in snapshot.toWidgetData().entries) {
      if (!writable.contains(entry.key)) continue;
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

// ---------------------------------------------------------------------------
// WP-701 · görev widget'ı: ayna + bekleyen kuyruk
//
// Kullanıcı ana ekranda kutucuğa dokunduğunda Flutter süreci çoğu zaman
// KAPALIDIR; gerçek `UserTasksNotifier.toggle` burada, Dart tarafındadır ve
// Supabase RPC'sine gider. Yol dört parçadır (ilk üçü Kotlin'de,
// `widgets/TaskWidget.kt` + `TaskActionReceiver.kt`):
//
//   1. Dart görev listesini [TaskWidgetPrefsKeys.mirror] anahtarına JSON
//      olarak yazar; widget yalnız bunu okur.
//   2. Dokunma anında Kotlin aynayı çevirir ve widget'ı hemen yeniden çizer
//      (kullanıcı dokunup "hiçbir şey olmadı" görmez).
//   3. Kotlin niyeti [TaskWidgetPrefsKeys.pending] kuyruğuna kalıcı yazar.
//   4. Uygulama açılınca [TaskWidgetBridge.drainPending] kuyruğu boşaltıp
//      gerçek `toggle`ı uygular.
//
// 🔴 Çift uygulama koruması kuyruğun **biçiminde**dir: kayıt bir *toggle*
// değil, **istenen mutlak durum** taşır (`done: true/false`). Kuyruk iki kez
// işlense bile sonuç değişmez; toggle taşısaydı ikinci tur işaretlemeyi geri
// alırdı. [applyPendingTaskToggles] ayrıca hedef durum zaten sağlanmışsa
// `toggle`ı hiç çağırmaz.
//
// 🔴 Tip tuzağı: iki tarafın dokunduğu her prefs değeri `String`tir. Dart
// `setInt` diske `putLong` yazar; Kotlin `getInt` okursa `ClassCastException`
// bir `BroadcastReceiver` içinde uygulama **sürecini** öldürür (v58 geri
// sayım/pomodoro çökmesi buydu). Zaman damgası bile JSON içinde metindir.
// ---------------------------------------------------------------------------

abstract final class TaskWidgetPrefsKeys {
  /// Dart tarafındaki `SharedPreferences` anahtarı.
  static const mirror = 'tasks.widget_v1';
  static const pending = 'tasks.widget_pending_v1';

  /// Flutter `shared_preferences` diske hep bu önekle yazar; Kotlin tarafı
  /// anahtarları önekli hâliyle okur.
  static const androidPrefix = 'flutter.';
  static const androidMirror = '$androidPrefix$mirror';
  static const androidPending = '$androidPrefix$pending';
}

/// Layout'taki satır sayısı (`odak_task_widget.xml`). Fazlası yazılmaz.
const int kTaskWidgetMaxRows = 5;

/// Kuyruktaki tek niyet: [taskId] görevi [done] durumuna gelsin.
@immutable
class TaskWidgetPendingToggle {
  const TaskWidgetPendingToggle({
    required this.opId,
    required this.taskId,
    required this.done,
  });

  final String opId;
  final String taskId;
  final bool done;
}

/// Widget'ın okuyacağı ayna. Başlık ve boş durum metni **buradan** gider:
/// native `strings.xml` ikinci bir çeviri kaynağı olmasın ve widget cihaz
/// dilini değil uygulamada seçilen dili konuşsun.
String encodeTaskWidgetMirror({
  required String title,
  required String emptyLabel,
  required List<UserTask> tasks,
}) {
  final visible = <Map<String, Object>>[];
  for (final task in tasks) {
    if (visible.length >= kTaskWidgetMaxRows) break;
    if (task.isArchived) continue;
    if (task.id.isEmpty || task.title.trim().isEmpty) continue;
    visible.add({
      'id': task.id,
      'title': task.title.trim(),
      'done': task.completed,
    });
  }
  return jsonEncode({
    'title': title,
    'empty': emptyLabel,
    'tasks': visible,
  });
}

/// Kotlin'in yazdığı kuyruğu çözer.
///
/// Aynı görevin birden çok niyeti varsa **sonuncusu** kalır: kullanıcı
/// uygulama kapalıyken işaretleyip geri aldıysa Dart'ın yapması gereken tek iş
/// son durumdur. Bozuk kayıt kuyruğun tamamını düşürmez, o satır atlanır.
List<TaskWidgetPendingToggle> decodeTaskWidgetPending(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const [];
  }
  if (decoded is! Map) return const [];
  final ops = decoded['ops'];
  if (ops is! List) return const [];
  final collapsed = <String, TaskWidgetPendingToggle>{};
  for (final entry in ops) {
    if (entry is! Map) continue;
    final taskId = (entry['taskId'] as String?)?.trim() ?? '';
    if (taskId.isEmpty) continue;
    collapsed.remove(taskId); // sonuncu kazanır, sırası da sona gider
    collapsed[taskId] = TaskWidgetPendingToggle(
      opId: (entry['id'] as String?)?.trim() ?? '',
      taskId: taskId,
      done: entry['done'] as bool? ?? false,
    );
  }
  return collapsed.values.toList(growable: false);
}

/// Bekleyen niyetleri gerçek `toggle`a çevirir; uygulananların kimliğini döner.
///
/// İki koruma: bilinmeyen kimlik (uygulamada silinmiş görev) atlanır, hedef
/// durum **zaten sağlanmışsa** `toggle` hiç çağrılmaz — kuyruk iki kez
/// boşaltılsa bile işaretleme geri dönmez.
@visibleForTesting
Future<List<String>> applyPendingTaskToggles({
  required List<TaskWidgetPendingToggle> pending,
  required List<UserTask> tasks,
  required Future<void> Function(String taskId) toggle,
}) async {
  final byId = {for (final task in tasks) task.id: task};
  final applied = <String>[];
  for (final op in pending) {
    final task = byId[op.taskId];
    if (task == null) continue;
    if (task.completed == op.done) continue;
    await toggle(op.taskId);
    applied.add(op.taskId);
  }
  return applied;
}

/// Görev listesi ↔ ana ekran widget'ı köprüsü.
///
/// 🔴 Bu sınıf bir kez **okunmadıkça** hiçbir şey yapmaz: `Provider` gövdesi
/// tembeldir. Uygulama açılışında (ör. kabuk kurulurken) `ref.watch/read` ile
/// çağrılmalıdır; çağrı yeri yoksa widget aynası hiç yazılmaz ve bekleyen
/// kuyruk hiç boşalmaz.
class TaskWidgetBridge {
  TaskWidgetBridge(this._ref);

  final Ref _ref;
  bool _started = false;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Bekleyen kuyruğu boşaltır ve aynanın ilk hâlini yazar.
  ///
  /// Görev listesi sonradan değiştiğinde ayna [taskWidgetBridgeProvider]
  /// gövdesindeki dinleyiciyle güncellenir; burada yalnız **açılış** turu
  /// vardır ve tekrar çağrılsa da bir kez koşar.
  Future<void> start() async {
    if (_started || !_isAndroid) return;
    _started = true;
    final tasks = await _ref.read(userTasksProvider.future);
    await drainPending(tasks: tasks);
    await syncMirror(_ref.read(userTasksProvider).value ?? tasks);
  }

  /// Görev listesini aynaya yazar ve widget'a yeniden çizim yayını gönderir.
  Future<void> syncMirror(List<UserTask> tasks) async {
    if (!_isAndroid) return;
    final prefs = _ref.read(sharedPreferencesProvider);
    final l10n = await loadSystemLocalizations();
    await prefs.setString(
      TaskWidgetPrefsKeys.mirror,
      encodeTaskWidgetMirror(
        title: l10n.taskListTitle,
        emptyLabel: l10n.taskListEmpty,
        tasks: tasks,
      ),
    );
    await _ref
        .read(androidWidgetServiceProvider)
        .refresh(widgets: const [StudyHomeWidget.task]);
  }

  /// Uygulama kapalıyken ana ekrandan yapılan işaretlemeleri uygular.
  ///
  /// Kuyruk **önce okunur, uygulandıktan sonra silinir**; arada uygulama
  /// ölürse aynı kuyruk bir daha işlenir ve [applyPendingTaskToggles] hedef
  /// durumu zaten sağlanmış kayıtlara dokunmaz.
  Future<int> drainPending({List<UserTask>? tasks}) async {
    if (!_isAndroid) return 0;
    final prefs = _ref.read(sharedPreferencesProvider);
    // Kotlin bu dosyayı süreç dışında değiştirmiş olabilir; Dart tarafındaki
    // bellek kopyası bayattır.
    await prefs.reload();
    final pending = decodeTaskWidgetPending(
      prefs.getString(TaskWidgetPrefsKeys.pending),
    );
    if (pending.isEmpty) return 0;
    final List<UserTask> current =
        tasks ?? await _ref.read(userTasksProvider.future);
    final actions = _ref.read(userTaskActionsProvider);
    final applied = await applyPendingTaskToggles(
      pending: pending,
      tasks: current,
      toggle: actions.toggle,
    );
    await prefs.remove(TaskWidgetPrefsKeys.pending);
    return applied.length;
  }
}

/// Köprünün tek örneği. Çağrı yeri uygulama açılışıdır (bkz. [TaskWidgetBridge]).
///
/// Dinleyici gövdede kurulur (`build` dışında `ref.listen` çağrılmaz) ve bu
/// sayede sağlayıcı yaşadığı sürece `userTasksProvider` de canlı kalır: WP-548
/// dersi — dinleyicisiz bir provider her okumada yeniden kurulur ve
/// güncellemeler sessizce kaybolur.
final taskWidgetBridgeProvider = Provider<TaskWidgetBridge>((ref) {
  final bridge = TaskWidgetBridge(ref);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    ref.listen<AsyncValue<List<UserTask>>>(userTasksProvider, (_, next) {
      final tasks = next.value;
      if (tasks != null) unawaited(bridge.syncMirror(tasks));
    });
  }
  return bridge;
});

/// Köprüyü **gerçekten başlatan** tek yer (WP-704).
///
/// 🔴 WP-701 köprünün her parçasını yazdı ve 20/20 yeşil test bıraktı, ama
/// `lib/` içinde [TaskWidgetBridge.start] çağıran hiçbir satır yoktu: testler
/// köprüyü kendileri başlatıyordu. O hâlde ayna hiç yazılmaz, bekleyen kuyruk
/// hiç boşalmaz — kullanıcının ana ekranda koyduğu işaret uygulama açılınca
/// **geri döner**. Depoda kayıtlı ders: *"bitmiş backend + bağlanmamış UI"*.
///
/// Neden ayrı bir sağlayıcı: [taskWidgetBridgeProvider] senkron bir `Provider`
/// ve `start()` asenkron. Kabuğun `build`'i içinden `unawaited(...)` çağırmak
/// her yeniden çizimde yeni bir tur başlatırdı; `FutureProvider` turu **bir
/// kez** koşturur ve kabuk monte kaldığı sürece diri tutar.
final taskWidgetBridgeStarterProvider = FutureProvider<void>((ref) async {
  await ref.watch(taskWidgetBridgeProvider).start();
});
