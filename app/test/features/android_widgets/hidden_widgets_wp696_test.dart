// WP-696: gizli bes widget yayina alinabilir mi? Boru hattinin GERCEK yazdigi
// deger olculur — bayrak degil.
//
// Bulgu: `_syncStatsWidgets` ayni turda iki kez `saveSnapshot` cagirir
// (`lib/data/providers/study_providers.dart:3027` ve `:3046`). Her snapshot
// 17 anahtarin HEPSINI yazar; ikinci yazim birincinin gercek degerlerini
// placeholder ile ezer. Sonuc: `StudyStatsWidgetProvider` (daily_goal_percent,
// `StudyWidgetProviders.kt:227`) ve `GroupGoalWidgetProvider`
// (group_goal_percent, `:326`) yayina alinirsa kullanici SONSUZA KADAR %0
// gorur.
//
// Bu dosya kapali bayraga bagimli degildir: olcum, prefs'e dusen son degeri
// simule eden saf bir birlestirmedir.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/android_widgets/published_home_widgets.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// `HomeWidgetPreferences` dosyasinin bir tur sonundaki hali.
///
/// `AndroidWidgetService.saveSnapshot` her anahtari ayri ayri yazar; ayni
/// anahtara ikinci yazim birinciyi ezer. Sira `_syncStatsWidgets` ile birebir:
/// once `goals`, sonra `leaderboard`.
Map<String, Object> _prefsAfterOneStatsSync(
  AndroidWidgetSnapshot goals,
  AndroidWidgetSnapshot leaderboard,
) {
  final prefs = <String, Object>{};
  for (final snapshot in [goals, leaderboard]) {
    for (final entry in snapshot.toWidgetData().entries) {
      prefs[entry.key] = entry.value;
    }
  }
  return prefs;
}

/// Kotlin saglayicilarinin KOSAN satirlarindaki anahtar sabitleri.
///
/// Yorum satirlari disarida birakilir (WP-640 tuzagi): yalniz
/// `const val Ad = "deger"` biciminde kod satirlari okunur.
Map<String, String> _kotlinWidgetKeys() {
  final file = File(
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/'
    'StudyWidgetProviders.kt',
  );
  expect(file.existsSync(), isTrue, reason: '${file.path} yok');
  final pattern = RegExp(r'^\s*const val (\w+) = "([^"]+)"');
  final keys = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    if (line.trimLeft().startsWith('//')) continue;
    final match = pattern.firstMatch(line);
    if (match != null) keys[match.group(1)!] = match.group(2)!;
  }
  return keys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  AndroidWidgetSnapshot goalsSnapshot() => AndroidWidgetSnapshot.goals(
    l10n: l10n,
    dailyPercent: '73%',
    dailyDetail: '73 dk / 100 dk',
    groupPercent: '41%',
    groupDetail: '205 dk / 500 dk',
  );

  AndroidWidgetSnapshot leaderboardSnapshot() =>
      AndroidWidgetSnapshot.leaderboard(
        l10n: l10n,
        rows: const ['Ayse - 2 sa', 'Mehmet - 1 sa', 'Zeynep - 40 dk'],
        myRank: '#2',
      );

  group('WP-696 · istatistik turu prefs sonucu', () {
    test('StudyStatsWidgetProvider okudugu daily_goal_percent EZILMEZ', () {
      final prefs = _prefsAfterOneStatsSync(
        goalsSnapshot(),
        leaderboardSnapshot(),
      );

      expect(
        prefs[AndroidWidgetKeys.dailyGoalPercent],
        '73%',
        reason:
            'ikinci saveSnapshot gunluk hedefi %0 ile eziyorsa stats widgeti '
            'yayina alindiginda hep %0 gosterir',
      );
      expect(prefs[AndroidWidgetKeys.dailyGoalDetail], '73 dk / 100 dk');
    });

    test('GroupGoalWidgetProvider okudugu group_goal_percent EZILMEZ', () {
      final prefs = _prefsAfterOneStatsSync(
        goalsSnapshot(),
        leaderboardSnapshot(),
      );

      expect(prefs[AndroidWidgetKeys.groupGoalPercent], '41%');
      expect(prefs[AndroidWidgetKeys.groupGoalDetail], '205 dk / 500 dk');
    });

    test('liderlik anahtarlari da ayakta kalir (ters yonde ezme yok)', () {
      final prefs = _prefsAfterOneStatsSync(
        goalsSnapshot(),
        leaderboardSnapshot(),
      );

      expect(prefs[AndroidWidgetKeys.leaderboardRow1], 'Ayse - 2 sa');
      expect(prefs[AndroidWidgetKeys.leaderboardMyRank], '#2');
      expect(prefs[AndroidWidgetKeys.leaderboardTitle], l10n.homeGrupSiralamasi);
    });

    test('her snapshot yalniz kendi anahtarlarini yazar', () {
      expect(
        goalsSnapshot().toWidgetData().keys,
        isNot(contains(AndroidWidgetKeys.leaderboardRow1)),
        reason: 'goals snapshot liderlik satirini yazarsa onu placeholder yapar',
      );
      expect(
        leaderboardSnapshot().toWidgetData().keys,
        isNot(contains(AndroidWidgetKeys.dailyGoalPercent)),
      );
      // Tohumlama turu hala 17 anahtarin hepsini yazar (ilk cizim bos kalmasin).
      expect(
        AndroidWidgetSnapshot.placeholder(l10n).toWidgetData().length,
        17,
      );
    });
  });

  group('WP-696 · tazeleme yolu', () {
    test('yayindaki her saglayicinin bir tazeleme yolu var', () {
      final orphans = publishedHomeWidgets
          .where((provider) => !hasHomeWidgetRefreshPath(provider))
          .toList();

      expect(
        orphans,
        isEmpty,
        reason:
            'bu saglayici yayinda ama ne StudyHomeWidget uyesi ne de native '
            'kendi akan bir widget: eklendiginde bir kez cizilir, bir daha '
            'guncellenmez',
      );
    });

    test('ALARM widgetinin tazeleme yolu YOK — yayina alinamaz', () {
      // Olculen kusur: `native_alarm_mirror_v1` degistiginde
      // (`native_alarm_bridge.dart:145`) hicbir yerden `updateWidget`
      // gitmiyor; `StudyHomeWidget` enumunda alarm uyesi yok.
      expect(
        hasHomeWidgetRefreshPath(HomeWidgetProvider.alarm),
        isFalse,
        reason:
            'alarm widgetine yayin yolu eklendiyse bu iddia bayat: WP-696 '
            'raporu guncellenmeli',
      );
      // Saatte boyle bir kusur yok: cizim native akar.
      expect(hasHomeWidgetRefreshPath(HomeWidgetProvider.clock), isTrue);
      // Uc istatistik saglayicisinin yolu Flutter tarafindan gelir.
      for (final provider in const [
        HomeWidgetProvider.timer,
        HomeWidgetProvider.studyStats,
        HomeWidgetProvider.groupGoal,
        HomeWidgetProvider.groupLeaderboard,
      ]) {
        expect(hasHomeWidgetRefreshPath(provider), isTrue, reason: '$provider');
      }
    });
  });

  group('WP-696 · Dart anahtarlari Kotlin saglayicilariyla ayni mi', () {
    test('Kotlin okudugu her anahtarin Dart tarafinda yazani var', () {
      final kotlin = _kotlinWidgetKeys();
      expect(
        kotlin,
        isNotEmpty,
        reason: 'regex hicbir sey yakalamadiysa bu test bos gecerdi',
      );

      const dartKeys = <String>{
        AndroidWidgetKeys.timerTitle,
        AndroidWidgetKeys.timerElapsed,
        AndroidWidgetKeys.timerStatus,
        AndroidWidgetKeys.timerAction,
        AndroidWidgetKeys.statsTitle,
        AndroidWidgetKeys.statsToday,
        AndroidWidgetKeys.statsWeek,
        AndroidWidgetKeys.statsStreak,
        AndroidWidgetKeys.dailyGoalPercent,
        AndroidWidgetKeys.dailyGoalDetail,
        AndroidWidgetKeys.groupGoalPercent,
        AndroidWidgetKeys.groupGoalDetail,
        AndroidWidgetKeys.leaderboardTitle,
        AndroidWidgetKeys.leaderboardRow1,
        AndroidWidgetKeys.leaderboardRow2,
        AndroidWidgetKeys.leaderboardRow3,
        AndroidWidgetKeys.leaderboardMyRank,
      };

      expect(
        kotlin.values.toSet().difference(dartKeys),
        isEmpty,
        reason: 'Kotlin bu anahtarlari okuyor ama Dart tarafi yazmiyor',
      );
    });
  });
}
