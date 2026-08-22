import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _kotlinDir =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets';

/// 🔴 WP-752: alti saglayici tek dosyadan (`StudyWidgetProviders.kt`) alti ayri
/// dosyaya bolundu. Bolme SAF TASIMAdir: sinif adlari ve paket degismedi
/// (`AndroidManifest.xml` onlara tam nitelikli adla referans verir ve bir ad
/// degisikligi DERLEME HATASI URETMEDEN widget'i oldururdu). Bu dosyanin isi
/// degismedi; yalnizca hangi metni nerede aradigi degisti.
const _commonPath = '$_kotlinDir/WidgetCommon.kt';
const _timerPath = '$_kotlinDir/TimerWidget.kt';
const _statsPath = '$_kotlinDir/StatsWidget.kt';
const _leaderboardPath = '$_kotlinDir/LeaderboardWidget.kt';
const _groupGoalPath = '$_kotlinDir/GroupGoalWidget.kt';
const _designPath = '$_kotlinDir/WidgetDesign.kt';
const _countdownPath = '$_kotlinDir/CountdownWidget.kt';
const _taskPath = '$_kotlinDir/TaskWidget.kt';

const _resDir = 'android/app/src/main/res';

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
    late String timer;
    late String statsProvider;
    late String groupGoalProvider;
    late String leaderboardProvider;
    late String stats;
    late String groupGoal;
    late String leaderboard;

    setUpAll(() {
      timer = _read(_timerPath);
      statsProvider = _read(_statsPath);
      groupGoalProvider = _read(_groupGoalPath);
      leaderboardProvider = _read(_leaderboardPath);
      stats = _read('$_resDir/layout/odak_stats_widget.xml');
      groupGoal = _read('$_resDir/layout/odak_group_goal_widget.xml');
      leaderboard = _read('$_resDir/layout/odak_leaderboard_widget.xml');
    });

    test(
      'istatistik ve grup hedefi platform cubugu degil renk tokenini surer',
      () {
        for (final layout in <String>[stats, groupGoal]) {
          expect(layout, contains('@drawable/widget_card_bg'));
          expect(layout, contains('@color/widget_design_ink'));
        }
        expect(stats, contains('@color/widget_design_accent'));
        expect(stats, contains('@drawable/widget_progress_bar'));
        expect(groupGoal, contains('@drawable/widget_progress_arc'));
        // WP-730: grup hedefinde accent artik yuzde METNINDE degil, yayin
        // dolgu seklinde tasinir; yay icindeki yuzde okunur `ink` tonuna
        // alindi. Token yine de cizilen zincirde bulunmak ZORUNDA.
        expect(
          _read('$_resDir/drawable/widget_arc_fill_shape.xml'),
          contains('@color/widget_design_accent'),
        );

        final statsBody = _classBody(statsProvider, 'StudyStatsWidgetProvider');
        final goalBody = _classBody(
          groupGoalProvider,
          'GroupGoalWidgetProvider',
        );
        expect(statsBody, contains('WidgetDesign.PROGRESS_MAX'));
        expect(statsBody, contains('WidgetDesign.barPercent('));
        expect(goalBody, contains('WidgetDesign.PROGRESS_MAX'));
        expect(goalBody, contains('WidgetDesign.arcPercent('));
      },
    );

    test(
      'grup hedefi yuzdeyi yarim yayin icinde YALNIZ BIR KEZ gosterir',
      () {
        expect(groupGoal, contains('group_goal_widget_gauge'));
        expect(groupGoal, contains('@drawable/widget_progress_arc'));
        expect(
          RegExp('android:id="@\\+id/group_goal_widget_percent"')
              .allMatches(groupGoal)
              .length,
          1,
          reason: 'yuzde widgetta iki kez ciziliyor',
        );
        expect(
          _element(groupGoal, 'group_goal_widget_percent'),
          contains('android:layout_gravity="center_horizontal|bottom"'),
        );
      },
    );

    test('boyut buyudukce bilgi artar; satirlar ayni anda acilmaz', () {
      expect(statsProvider, contains('fun statsDetailVisible('));
      expect(statsProvider, contains('fun statsStreakVisible('));
      expect(groupGoalProvider, contains('fun groupGoalDetailVisible('));
      expect(leaderboardProvider, contains('fun leaderboardRow2Visible('));
      expect(leaderboardProvider, contains('fun leaderboardRow3Visible('));
      expect(statsProvider, contains('height == WidgetHeightClass.TALL'));
      expect(leaderboardProvider, contains('height == WidgetHeightClass.TALL'));
    });

    test('siralama duz metin degil: rank hapi, ritim ve kisisel vurgu var', () {
      for (var rank = 1; rank <= 3; rank++) {
        expect(leaderboard, contains('leaderboard_widget_rank_$rank'));
        expect(leaderboard, contains('leaderboard_widget_row_container_$rank'));
      }
      expect(leaderboard, contains('@drawable/widget_rank_first_bg'));
      expect(leaderboard, contains('@drawable/widget_rank_other_bg'));
      expect(leaderboard, contains('@drawable/widget_card_bg'));
      expect(
        leaderboardProvider,
        contains('leaderboardHighlightedPosition(myRank)'),
      );
      expect(leaderboardProvider, contains('R.string.widget_you'));
      expect(
        leaderboardProvider,
        contains('if (row1HasRank) View.VISIBLE else View.GONE'),
      );
      expect(leaderboardProvider, contains('leaderboardRowHasContent(row2)'));
      expect(leaderboardProvider, contains('leaderboardRowHasContent(row3)'));
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

    test('sayac kontrol yolu bolme sonrasi ayni dosyada duruyor', () {
      // Bolme SAF TASIMA olmali: govdeler degismedi.
      expect(timer, contains('TimerActionReceiver.ACTION_TOGGLE_TIMER'));
      expect(timer, contains('timerSubjectVisible(size)'));
      expect(timer, contains('class TimerWidgetProvider : HomeWidgetProvider()'));
    });
  });

  // ==========================================================================
  // 🔴 WP-752 — OLU PALET SILINDI (bu iddia yeniden yazildi, silinmedi)
  //
  // Eski hali "duzenler `@color/widget_stats_surface` KULLANMASIN" diyordu.
  // Olculdu: o simgeleri tanimlayan uc dosya (`values`, `values-night`,
  // `values-v31` / `widget_colors.xml`) tamamen OLUydu -- hicbir duzen, cizim
  // ya da Kotlin satiri okumuyordu. Dosyalar silindi, dolayisiyla "kullanma"
  // iddiasi konusuz kaldi.
  //
  // Yerine gecen iddia daha genis: o palet HICBIR YERDE geri gelmemeli ve
  // widget yigininda tek bir Material You (`@android:color/system_*`)
  // referansi kalmamali -- silinen `values-v31/widget_colors.xml` yigindaki
  // TEK dinamik renk referansiydi.
  // ==========================================================================
  group('WP-752 · olu palet geri gelmedi', () {
    const deadSymbols = <String>[
      'widget_stats_surface',
      'widget_leaderboard_surface',
      'widget_heading',
      'widget_primary_text',
      'widget_secondary_text',
    ];

    test('olu kaynak dosyalari yok', () {
      for (final path in const <String>[
        '$_resDir/values/widget_colors.xml',
        '$_resDir/values-night/widget_colors.xml',
        '$_resDir/values-v31/widget_colors.xml',
      ]) {
        expect(
          File(path).existsSync(),
          isFalse,
          reason: '$path geri geldi: olu palet dirildi',
        );
      }
    });

    test('olu simgeler res/ ve kotlin/ agacinda hic gecmiyor', () {
      final roots = <Directory>[
        Directory(_resDir),
        Directory('android/app/src/main/kotlin'),
      ];
      final hits = <String>[];
      for (final root in roots) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.xml') && !entity.path.endsWith('.kt')) {
            continue;
          }
          final text = entity.readAsStringSync();
          for (final symbol in deadSymbols) {
            if (text.contains(symbol)) hits.add('${entity.path} -> $symbol');
          }
        }
      }
      expect(hits, isEmpty, reason: 'olu simge geri sizdi: $hits');
    });

    test('widget yigininda Material You referansi yok', () {
      // `values/widget_design.xml:17-27` gerekcesi: rengi duvar kagidi secer,
      // kontrasti kimse olcmez. Silinen `values-v31/widget_colors.xml` bu
      // yigindaki TEK `@android:color/system_*` referansiydi.
      final hits = <String>[];
      for (final entity in Directory(_resDir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.xml')) continue;
        if (!entity.path.contains('widget')) continue;
        final text = entity
            .readAsStringSync()
            .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
        if (text.contains('@android:color/system_')) hits.add(entity.path);
      }
      expect(hits, isEmpty, reason: 'dinamik renk widget yiginina girdi: $hits');
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
        for (final body in <String>[
          _classBody(_read(_statsPath), 'StudyStatsWidgetProvider'),
          _classBody(_read(_leaderboardPath), 'GroupLeaderboardWidgetProvider'),
          _classBody(_read(_groupGoalPath), 'GroupGoalWidgetProvider'),
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
      final en = _read('$_resDir/values/strings.xml');
      final tr = _read('$_resDir/values-tr/strings.xml');
      expect(en, contains('<string name="widget_you">YOU</string>'));
      expect(tr, contains('<string name="widget_you">SEN</string>'));
    });
  });

  test('WP-717/718/719 davranis sozlesmeleri korunur', () {
    final countdown = _read('$_resDir/layout/odak_countdown_widget.xml');
    final task = _read('$_resDir/layout/odak_task_widget.xml');
    final timer = _read(_timerPath);
    expect(countdown, contains('@drawable/widget_progress_arc'));
    expect(countdown, contains('countdown_widget_row_3'));
    expect(task, contains('android:layout_height="wrap_content"'));
    expect(task, contains('@drawable/widget_card_bg'));
    expect(timer, contains('TimerActionReceiver.ACTION_TOGGLE_TIMER'));
    expect(timer, contains('timerSubjectVisible(size)'));
  });

  test('paylasilan zemin saglayici TASIMAZ', () {
    // WP-752'nin bolme gerekcesi: uc ajan ayni dosyaya yazamaz. Zemin dosyasi
    // yeniden saglayici toplamaya baslarsa bolme sessizce geri alinmis olur.
    final common = _read(_commonPath);
    expect(
      RegExp(r'\nclass \w+Provider').hasMatch(common),
      isFalse,
      reason: 'paylasilan zemine saglayici geri tasindi',
    );
    expect(common, contains('internal object StudyWidgetKeys'));
    expect(common, contains('internal fun widgetSizeClass('));
  });
}
