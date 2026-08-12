import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _providerPath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/StudyWidgetProviders.kt';
const _designPath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/WidgetDesign.kt';
const _countdownPath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/CountdownWidget.kt';
const _taskPath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/TaskWidget.kt';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path yok');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

String _classBody(String source, String className, [String? nextClass]) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: '$className yok');
  final end = nextClass == null
      ? source.length
      : source.indexOf('class $nextClass', start + 1);
  expect(end, greaterThan(start), reason: '$className siniri bulunamadi');
  return source.substring(start, end);
}

String _element(String xml, String id) {
  final marker = xml.indexOf('android:id="@+id/$id"');
  expect(marker, greaterThanOrEqualTo(0), reason: '$id layoutta yok');
  final start = xml.lastIndexOf('<', marker);
  final end = xml.indexOf('>', marker);
  return xml.substring(start, end);
}

int _dp(String element, String attribute) {
  final match = RegExp('android:$attribute="(\\d+)dp"').firstMatch(element);
  expect(match, isNotNull, reason: '$attribute dp olarak beyan edilmemis');
  return int.parse(match!.group(1)!);
}

void main() {
  group('WP-725 · WP-717 gorsel dili', () {
    late String provider;
    late String stats;
    late String groupGoal;
    late String leaderboard;

    setUpAll(() {
      provider = _read(_providerPath);
      stats = _read('android/app/src/main/res/layout/odak_stats_widget.xml');
      groupGoal = _read(
        'android/app/src/main/res/layout/odak_group_goal_widget.xml',
      );
      leaderboard = _read(
        'android/app/src/main/res/layout/odak_leaderboard_widget.xml',
      );
    });

    test(
      'istatistik ve grup hedefi platform cubugu degil renk tokenini surer',
      () {
        for (final layout in <String>[stats, groupGoal]) {
          expect(layout, contains('@drawable/widget_card_bg'));
          expect(layout, contains('@color/widget_design_accent'));
          expect(layout, contains('@color/widget_design_ink'));
          expect(layout, contains('@drawable/widget_progress_bar'));
          expect(layout, isNot(contains('@color/widget_stats_surface')));
          expect(layout, isNot(contains('@color/widget_leaderboard_surface')));
        }

        final statsBody = _classBody(
          provider,
          'StudyStatsWidgetProvider',
          'GroupLeaderboardWidgetProvider',
        );
        final goalBody = _classBody(
          provider,
          'GroupGoalWidgetProvider',
          'ClockWidgetProvider',
        );
        for (final body in <String>[statsBody, goalBody]) {
          expect(body, contains('WidgetDesign.PROGRESS_MAX'));
          expect(body, contains('WidgetDesign.barPercent('));
        }
      },
    );

    test('boyut buyudukce bilgi artar; satirlar ayni anda acilmaz', () {
      expect(provider, contains('fun statsDetailVisible('));
      expect(provider, contains('fun statsStreakVisible('));
      expect(provider, contains('fun groupGoalDetailVisible('));
      expect(provider, contains('fun leaderboardRow2Visible('));
      expect(provider, contains('fun leaderboardRow3Visible('));
      expect(provider, contains('height == WidgetHeightClass.TALL'));
    });

    test('siralama duz metin degil: rank hapi, ritim ve kisisel vurgu var', () {
      for (var rank = 1; rank <= 3; rank++) {
        expect(leaderboard, contains('leaderboard_widget_rank_$rank'));
        expect(leaderboard, contains('leaderboard_widget_row_container_$rank'));
      }
      expect(leaderboard, contains('@drawable/widget_rank_first_bg'));
      expect(leaderboard, contains('@drawable/widget_rank_other_bg'));
      expect(leaderboard, contains('@drawable/widget_card_bg'));
      expect(provider, contains('leaderboardHighlightedPosition(myRank)'));
      expect(provider, contains('R.string.widget_you'));
      expect(
        provider,
        contains('if (row1HasRank) View.VISIBLE else View.GONE'),
      );
      expect(provider, contains('leaderboardRowHasContent(row2)'));
      expect(provider, contains('leaderboardRowHasContent(row3)'));
    });

    test('siralama 80/110/150 dp siniflarinda kirpilmaz', () {
      final titleSp = <int>[13, 14, 16];
      final boxHeights = <int>[80, 110, 150];
      final paddings = <int>[14, 15, 16];
      final rowCounts = <int>[1, 2, 3];
      final rowHeight = _dp(
        _element(leaderboard, 'leaderboard_widget_row_container_1'),
        'minHeight',
      );
      final firstGap = _dp(
        _element(leaderboard, 'leaderboard_widget_row_container_1'),
        'layout_marginTop',
      );
      final nextGap = _dp(
        _element(leaderboard, 'leaderboard_widget_row_container_2'),
        'layout_marginTop',
      );

      for (var i = 0; i < boxHeights.length; i++) {
        final needed =
            2 * paddings[i] +
            titleSp[i] * 1.30 +
            firstGap +
            rowCounts[i] * rowHeight +
            (rowCounts[i] - 1) * nextGap;
        expect(
          needed,
          lessThanOrEqualTo(boxHeights[i]),
          reason:
              '${boxHeights[i]}dp kutuda ${rowCounts[i]} satir $needed dp ister',
        );
      }
    });
  });

  group('WP-725 · native widget metni uygulama dilini izler', () {
    test('tercih Flutter acilmadan native SharedPreferences tan okunur', () {
      final design = _read(_designPath);
      expect(design, contains('flutter.app_language_preference'));
      expect(design, contains('FlutterSharedPreferences'));
      expect(design, contains('fun widgetLanguageCode('));
      expect(design, contains('fun widgetLocalizedContext('));
      expect(design, contains('createConfigurationContext(configuration)'));
    });

    test(
      'tum sabit metin ureten providerlar yerellestirilmis context kullanir',
      () {
        final provider = _read(_providerPath);
        for (final body in <String>[
          _classBody(
            provider,
            'StudyStatsWidgetProvider',
            'GroupLeaderboardWidgetProvider',
          ),
          _classBody(
            provider,
            'GroupLeaderboardWidgetProvider',
            'GroupGoalWidgetProvider',
          ),
          _classBody(
            provider,
            'GroupGoalWidgetProvider',
            'ClockWidgetProvider',
          ),
          _classBody(_read(_countdownPath), 'CountdownWidgetProvider', null),
          _classBody(_read(_taskPath), 'TaskWidgetProvider', null),
        ]) {
          expect(body, contains('widgetLocalizedContext(context)'));
          expect(
            body,
            contains('strings.getString('),
            reason:
                'localized context uretilmis ama sabit metinde kullanilmiyor',
          );
        }
      },
    );

    test('TR ve EN sabit rozet metinleri birlikte vardir', () {
      final en = _read('android/app/src/main/res/values/strings.xml');
      final tr = _read('android/app/src/main/res/values-tr/strings.xml');
      expect(en, contains('<string name="widget_you">YOU</string>'));
      expect(tr, contains('<string name="widget_you">SEN</string>'));
    });
  });

  test('WP-717/718/719 davranis sozlesmeleri korunur', () {
    final countdown = _read(
      'android/app/src/main/res/layout/odak_countdown_widget.xml',
    );
    final task = _read('android/app/src/main/res/layout/odak_task_widget.xml');
    final provider = _read(_providerPath);
    expect(countdown, contains('@drawable/widget_progress_arc'));
    expect(countdown, contains('countdown_widget_row_3'));
    expect(task, contains('android:layout_height="wrap_content"'));
    expect(task, contains('@drawable/widget_card_bg'));
    expect(provider, contains('TimerActionReceiver.ACTION_TOGGLE_TIMER'));
    expect(provider, contains('timerSubjectVisible(size)'));
  });
}
