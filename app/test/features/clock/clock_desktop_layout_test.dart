// WP-678 — SAAT / ARACLAR SEKMESININ MASAUSTU DUZEN KAPISI.
//
// Sahip v64 Windows surumunu reddetti: "dikey mobil uygulama icin tasarlanan
// arayuzler yatay pc ekraninda cok kotu duruyor". Dort ekran (ana pano,
// istatistik, profil/basarimlar, gruplar) WP-673/674/675'te olculdu ve
// duzeltildi. **Araclar sekmesi hic olculmemisti.**
//
// Bu dosya kusuru ANLATMAZ, OLCER. Her iddia cizilen kareden okunur
// (`ClockStretchProbe`, WP-671); kaynakta `maxWidth` gormek kanit sayilmaz —
// depoda kayitli ders: "kullanicinin GORDUGU satiri test et".
//
// ===================== OLCULEN SAYILAR (2026-08-10) ==========================
//
// Uc alt sekme x iki pencere. "icerik" = boyanan en sol glif ile en sag glif
// arasi; "satir" = en genis etiket-deger satiri; "kart" = en genis `Card` ve
// parantez icinde o kartin ICINDEKI en genis metin.
//
// ONCE (6/6 kirmizi, 26 ihlal):
//   alarm        1920 -> icerik 1680, kart 1720 (595), satir  641
//   alarm        2560 -> icerik 2320, kart 2360 (595), satir  855
//   zamanlayici  1920 -> icerik 1472, kart 1720 (180), satir  641
//   zamanlayici  2560 -> icerik 2005, kart 2360 (180), satir  855
//   gorevler     1920 -> icerik 1472,              satir  999
//   gorevler     2560 -> icerik 2005,              satir 1319
//
// SONRA (6/6 yesil):
//   alarm        1920 -> icerik 1365, kart  632 (549), satir  265
//   alarm        2560 -> icerik 1365, kart  632 (549), satir  265
//   zamanlayici  1920 -> icerik 1332, kart  632 (180), satir  265
//   zamanlayici  2560 -> icerik 1332, kart  632 (180), satir  265
//   gorevler     1920 -> icerik 1005,              satir  427
//   gorevler     2560 -> icerik 1005,              satir  427
//
// Asil kanit sayilarin kucuklugu degil, 1920 ile 2560 sutunlarinin ARTIK AYNI
// olmasidir: duzen pencereyle birlikte buyumeyi biraktI.
//
// En keskin tek olcum zamanlayici kartiydi: 2360 px genisliginde bir kutu,
// icinde tek bir "15:00" (180 px) — 2180 px olu alan. Sahibin "her biri 800 px
// genisliginde, icinde tek bir sayi" cumlesinin birebir karsiligi.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/models/achievement_reward.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/achievement_reward_provider.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/clock/clock_desktop_layout.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/v8_test_setup.dart';
import 'clock_stretch_probe.dart';

/// SPEC §2.3 "Izgara / pano toplami" — `DesktopBreakpoints.maxContentWidth`.
const double kMaxContentSpanPx = DesktopBreakpoints.maxContentWidth;

/// SPEC KURAL 2.2 sert tavani (80 karakter x 7.5 px, WCAG 2.1 SC 1.4.8).
const double kMaxLabelValueSpanPx = DesktopBreakpoints.maxLabelValueWidth;

/// SPEC §2.3 "Form / ayar satiri" — bir kart yuzeyi icin depodaki EN
/// MUSAMAHAKAR tavan. WP-671 kapisi da bu sayiyi kullanir.
const double kMaxCardWidthPx = DesktopBreakpoints.maxFormWidth;

/// Bir kartin "dev kutu, tek satir" olcusu: kart genisligi eksi icindeki en
/// genis metnin genisligi.
///
/// **Bu esik SPEC'te YOK; WP-671 sectI ve burada aynen kullanilir** ki iki kapi
/// ayni seyi iki farkli sayiyla olcmesin. 480 px = 2 x 240 px kenar; SPEC §4
/// masaustu sayfa kenar boslugunu en genis bantta 24 px diyor, 240 onun on
/// kati. Bir kartin her iki yaninda 240 px'ten fazla olu alan varsa o kart
/// icerigine gore degil PENCEREYE gore boyutlanmistir.
const double kMaxCardDeadWidthPx = 480;

enum ClockSub { alarm, timer, tasks }

void main() {
  final tr = AppLocalizationsTr();

  Future<void> onWindows(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> settle(WidgetTester tester) async {
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
    } catch (_) {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
  }

  /// Bos ekran hicbir sey olcmez. Uc alt sekmenin de gercek veriyle cizilmesi
  /// icin alarm/zamanlayici prefs'e, gorevler bellek deposuna tohumlanir.
  Future<SharedPreferences> seededPreferences() async {
    const alarms = [
      AlarmRule(
        id: 'alarm-1',
        hour: 7,
        minute: 30,
        days: [1, 2, 3, 4, 5],
        label: 'Sabah rutini',
      ),
      AlarmRule(id: 'alarm-2', hour: 22, minute: 0, label: 'Uyku'),
    ];
    const presets = [
      TimerPreset(id: 'preset_25', label: '25 dk', durationSeconds: 1500),
      TimerPreset(id: 'preset_5', label: '5 dk', durationSeconds: 300),
    ];
    const instances = [
      TimerInstance(
        id: 'timer-1',
        label: 'Odak blogu',
        durationSeconds: 1500,
        remainingSeconds: 900,
      ),
      TimerInstance(
        id: 'timer-2',
        label: 'Kisa mola',
        durationSeconds: 300,
        remainingSeconds: 120,
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'dashboard_layout': ['today', 'leaderboard'],
      'local_alarms': [for (final a in alarms) jsonEncode(a.toMap())],
      'local_timer_presets': [for (final p in presets) jsonEncode(p.toMap())],
      'local_timer_instances': [
        for (final i in instances) jsonEncode(i.toMap()),
      ],
    });
    return SharedPreferences.getInstance();
  }

  List<UserTask> seedTasks() {
    final now = DateTime.now();
    return [
      UserTask(
        id: 'task-1',
        title: 'Matematik tekrari',
        completed: false,
        createdAt: now,
        sortOrder: 0,
        dueAt: now.add(const Duration(hours: 5)).toUtc(),
      ),
      UserTask(
        id: 'task-2',
        title: 'Gunluk okuma',
        completed: false,
        createdAt: now,
        sortOrder: 1,
        recurrence: UserTaskRecurrence.daily,
      ),
      // Capa ILERI tarihte: bugun occurrence gunu DEGIL, bu yuzden gorev
      // "Tekrarlanan" bolumune duser. Uc bolumun ucu de dolu olsun ki masaustu
      // izgarasi gercekten birden fazla blok dizsin.
      UserTask(
        id: 'task-3',
        title: 'Uc gunde bir spor',
        completed: false,
        createdAt: now,
        sortOrder: 2,
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 3,
        anchorDate: DateTime(now.year, now.month, now.day + 2),
      ),
      UserTask(
        id: 'task-4',
        title: 'Donem projesi',
        completed: false,
        createdAt: now,
        sortOrder: 3,
        dueAt: now.add(const Duration(days: 10)).toUtc(),
      ),
    ];
  }

  Future<ClockStretchProbe> openTools(
    WidgetTester tester, {
    required Size window,
    required ClockSub sub,
  }) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);

    final preferences = await seededPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);
    final profile = (await auth.authStateChanges().first)!;
    final groupRepository = InMemoryGroupRepository();
    await groupRepository.createGroup(name: 'Odak Kampi', creator: profile);
    final taskRepository = InMemoryUserTaskRepository();
    await taskRepository.saveAll(userKey: profile.id, tasks: seedTasks());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(groupRepository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          userTaskRepositoryProvider.overrideWithValue(taskRepository),
          // Bekleyen odul serididir; bos tutulur ki olcum yalniz saat
          // sekmesinin kendi icerigini gorsun.
          pendingAchievementRewardSummaryProvider.overrideWith(
            (ref) => AchievementRewardSummary.empty,
          ),
          deviceIntegrationServiceProvider.overrideWithValue(
            V8TestDeviceIntegrationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(V8TestWidgetGateway()),
        ],
        child: const OnlineStudyRoomApp(),
      ),
    );
    await settle(tester);

    // 🔴 Masaustu seridi mobil `navTools` ("Araclar") etiketini KULLANMAZ;
    // `desktop_home_shell.dart:48` bu sekmeye `desktopSaat` ("Saat") diyor.
    // Ilk kosumda test "Araçlar" arayip 6/6 bulunamadi hatasi verdi.
    expect(
      find.text(tr.desktopSaat),
      findsWidgets,
      reason:
          'Masaustu kabugu cizilmedi: "${tr.desktopSaat}" sekmesi yok. Once '
          'kabugun ayakta oldugundan emin ol.',
    );
    await tester.tap(find.text(tr.desktopSaat).first);
    await settle(tester);
    // 🔴 OLCULDU, tahmin degil. `RewardToast` tac yukselme kutlamasini
    // (`_CrownCelebration`, `reward_toast.dart:188`) ekranin UST-ORTASINDA
    // cizer; olculen kutu 1920 px'te (862.5, 8)–(1057.5, 56) idi ve Araclar
    // ikon seridinin ORTA ogesini ("Timer", merkez 1048,39) tamamen ortuyordu.
    // Ilk kosumda `tester.tap(clock_tab_timer)` "would not hit test on the
    // specified widget" uyarisi verdi, sekme HIC degismedi ve olcum sessizce
    // ALARM sekmesini olctu (uc alt sekme ayni sayilari raporluyordu).
    // Kutlama 1800 ms'lik bir `Timer` ile kalkar; `pumpAndSettle` daha erken
    // oturdugu icin sahte saatte hic dolmuyordu. Bu pump onu doldurur.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

    final stripKey = switch (sub) {
      ClockSub.alarm => const Key('clock_tab_alarm'),
      ClockSub.timer => const Key('clock_tab_timer'),
      ClockSub.tasks => const Key('clock_tab_tasks'),
    };
    expect(
      find.byKey(stripKey),
      findsOneWidget,
      reason: 'Araclar ikon seridi cizilmedi: $stripKey yok.',
    );
    await tester.tap(find.byKey(stripKey));
    await settle(tester);

    return ClockStretchProbe(tester);
  }

  String label(ClockSub sub) => switch (sub) {
    ClockSub.alarm => 'araclar/alarm',
    ClockSub.timer => 'araclar/zamanlayici',
    ClockSub.tasks => 'araclar/gorevler',
  };

  for (final window in const [Size(1920, 1080), Size(2560, 1440)]) {
    final w = window.width.toInt();
    final h = window.height.toInt();
    for (final sub in ClockSub.values) {
      testWidgets('${label(sub)} @ ${w}x$h — masaustunde mobil gerilmesi yok', (
        tester,
      ) async {
        await onWindows(() async {
          final probe = await openTools(tester, window: window, sub: sub);

          final failures = <String>[];
          final notes = <String>[];

          final bounds = probe.contentInkBounds();
          if (bounds == null) {
            failures.add('OLCUM 1: ekranda hic boyanmis metin yok.');
          } else {
            notes.add(
              'icerik araligi: ${bounds.width.toStringAsFixed(0)} px '
              '(${bounds.left.toStringAsFixed(0)}..'
              '${bounds.right.toStringAsFixed(0)}), pencere $w px',
            );
            if (bounds.width > kMaxContentSpanPx) {
              failures.add(
                'OLCUM 1 (SPEC §2.3 izgara tavani '
                '${kMaxContentSpanPx.toInt()} px): icerik ekranda '
                '${bounds.width.toStringAsFixed(0)} px yayiliyor.',
              );
            }
          }

          final rows = probe.labelValueRows();
          if (rows.isNotEmpty) {
            final worst = rows.first;
            notes.add(
              'en genis etiket-deger satiri: '
              '${worst.span.toStringAsFixed(0)} px '
              '${worst.label.text} -> ${worst.value.text}',
            );
          }
          for (final row in rows
              .where((r) => r.span > kMaxLabelValueSpanPx)
              .take(5)) {
            failures.add(
              'OLCUM 2 (SPEC KURAL 2.2 sert tavan '
              '${kMaxLabelValueSpanPx.toInt()} px): "${row.label.text}" -> '
              '"${row.value.text}" satiri ${row.span.toStringAsFixed(0)} px.',
            );
          }

          final cards = probe.paintedCards();
          if (cards.isNotEmpty) {
            final widest = cards.first;
            notes.add(
              'en genis kart: ${widest.rect.width.toStringAsFixed(0)} px, '
              'icindeki en genis metin '
              '${widest.widestText.toStringAsFixed(0)} px '
              '("${widest.label}")',
            );
          }
          for (final card in cards
              .where((c) => c.rect.width > kMaxCardWidthPx)
              .take(4)) {
            failures.add(
              'OLCUM 3 (SPEC §2.3 form/ayar sutunu '
              '${kMaxCardWidthPx.toInt()} px): kart '
              '${card.rect.width.toStringAsFixed(0)} px genisliginde, '
              'icindeki en genis metin sadece '
              '${card.widestText.toStringAsFixed(0)} px ("${card.label}").',
            );
          }
          for (final card in cards
              .where((c) => c.deadWidth > kMaxCardDeadWidthPx)
              .take(3)) {
            failures.add(
              'OLCUM 3b (olu alan tavani ${kMaxCardDeadWidthPx.toInt()} px — '
              "esigi WP-671 sectI, SPEC'te yok): kart "
              '${card.rect.width.toStringAsFixed(0)} px, icerigi '
              '${card.widestText.toStringAsFixed(0)} px, olu alan '
              '${card.deadWidth.toStringAsFixed(0)} px ("${card.label}").',
            );
          }

          expect(
            failures,
            isEmpty,
            reason:
                '\n=== ${label(sub).toUpperCase()} @ ${w}x$h ===\n'
                'IHLAL (${failures.length}):\n'
                '${failures.map((f) => "  - $f").join("\n")}\n'
                'OLCUM:\n'
                '${notes.map((n) => "  · $n").join("\n")}\n',
          );
        });
      });
    }
  }

  // ===================== ISLEV KAYBI YOK (SPEC §7) ===========================
  //
  // Duzen degisti, urun yuzeyi degismedi. Bu testler kutu genisligi degil
  // KONTROLLERIN VARLIGINI olcer: bir A2 izgarasina tasinirken bir eylemin
  // dusmesi, genislik kapisini yesil birakan ama urunu bozan bir hatadir.
  testWidgets('araclar/alarm @ 1920 — alarm eylemleri masaustunde duruyor', (
    tester,
  ) async {
    await onWindows(() async {
      await openTools(
        tester,
        window: const Size(1920, 1080),
        sub: ClockSub.alarm,
      );
      // Iki tohumlanmis alarm, ikisi de cizilmis olmali (izgara hicbirini
      // dusurmedi).
      expect(find.text('07:30'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      // Ac/kapat, atla, duzenle, onizle, sil + "Alarm ekle" eylemi.
      expect(find.byType(Switch), findsNWidgets(2));
      expect(find.text(tr.clockSonrakiniAtla), findsNWidgets(2));
      expect(find.text(tr.profileDuzenle), findsNWidgets(2));
      expect(find.text(tr.clockOnizle), findsNWidgets(2));
      expect(find.byTooltip(tr.profileSil), findsNWidgets(2));
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  testWidgets(
    'araclar/zamanlayici @ 1920 — sayac kontrolleri masaustunde duruyor',
    (tester) async {
      await onWindows(() async {
        await openTools(
          tester,
          window: const Size(1920, 1080),
          sub: ClockSub.timer,
        );
        expect(find.text('15:00'), findsOneWidget);
        expect(find.text('02:00'), findsOneWidget);
        // Duraklatilmis/ilk durumdaki sayacta baslat + sifirla + sil.
        expect(find.byTooltip(tr.desktopBaslat), findsNWidgets(2));
        expect(find.byTooltip(tr.homeSifirla), findsNWidgets(2));
        expect(find.byTooltip(tr.profileSil), findsNWidgets(2));
        // Hazir sure cipleri + "Ozel" cipi.
        expect(find.text(tr.clockOzel), findsOneWidget);
      });
    },
  );

  testWidgets('araclar/gorevler @ 1920 — gorev eylemleri masaustunde duruyor', (
    tester,
  ) async {
    await onWindows(() async {
      await openTools(
        tester,
        window: const Size(1920, 1080),
        sub: ClockSub.tasks,
      );
      expect(find.text('Matematik tekrari'), findsOneWidget);
      expect(find.text('Gunluk okuma'), findsOneWidget);
      expect(find.text('Uc gunde bir spor'), findsOneWidget);
      expect(find.text('Donem projesi'), findsOneWidget);
      // 🔴 WP-647 dersi: "her N gunde bir" gorevi Bugun listesinden
      // dusuruyordu. Uc bolum de yerinde olmali; izgara bolum DUSURMEZ.
      expect(find.text(tr.taskListSectionToday), findsOneWidget);
      expect(find.text(tr.taskListSectionRecurring), findsOneWidget);
      expect(find.text(tr.taskListSectionOther), findsOneWidget);
      expect(find.text(tr.taskListRepeatEvery(3)), findsWidgets);
      expect(find.byTooltip(tr.taskListEdit), findsNWidgets(4));
      expect(find.byTooltip(tr.taskListDelete), findsNWidgets(4));
      expect(find.byTooltip(tr.taskListAdd), findsOneWidget);
      // Uc bolum YAN YANA: "Bugun" ile "Tekrarlanan" ayni dy'de, farkli dx'te
      // (tek sutun olsaydi dy'leri farkli olurdu).
      final today = tester.getTopLeft(find.text(tr.taskListSectionToday));
      final recurring = tester.getTopLeft(
        find.text(tr.taskListSectionRecurring),
      );
      expect(recurring.dy, today.dy);
      expect(recurring.dx, greaterThan(today.dx));
    });
  });

  // ======================= MOBIL REGRESYON (SPEC §7) =========================
  //
  // "Mobil dal degismez." Bu iddia SOZDE degil OLCULUR: 390x844'te masaustu
  // widget'lari agacta HIC bulunmamali ve serit ekranin tamamini kaplamali
  // (masaustunde 600 px'e sinirlanan sey burada sinirlanmamali).
  testWidgets('mobil 390x844 — saat sekmesinde masaustu kolu HIC acilmiyor', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final preferences = await seededPreferences();
      final auth = await signedInV8AuthRepository(prefs: preferences);
      final profile = (await auth.authStateChanges().first)!;
      final taskRepository = InMemoryUserTaskRepository();
      await taskRepository.saveAll(userKey: profile.id, tasks: seedTasks());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
            sharedPreferencesProvider.overrideWithValue(preferences),
            userTaskRepositoryProvider.overrideWithValue(taskRepository),
            pendingAchievementRewardSummaryProvider.overrideWith(
              (ref) => AchievementRewardSummary.empty,
            ),
            deviceIntegrationServiceProvider.overrideWithValue(
              V8TestDeviceIntegrationService(),
            ),
            androidWidgetServiceProvider.overrideWithValue(
              V8TestWidgetGateway(),
            ),
          ],
          child: const OnlineStudyRoomApp(),
        ),
      );
      await settle(tester);
      await tester.tap(find.text(tr.navTools).first);
      await settle(tester);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);

      // Masaustu kolunun hicbir parcasi mobil agacta olmamali.
      expect(find.byType(ClockCommandStrip), findsNothing);
      expect(find.byType(ClockBlockGrid), findsNothing);
      expect(find.byType(DesktopContent), findsNothing);

      // Serit ekranin tamamini kaplar: 390 − 2×8 (mobil dis Padding)
      // − 2×2 (serit Material'inin ic yatay dolgusu) = **370**, ucu esit.
      // Masaustunde ayni serit 600 px'e sinirlanir; mobilde sinirlanmaz.
      final alarmItem = tester.getSize(find.byKey(const Key('clock_tab_alarm')));
      final timerItem = tester.getSize(find.byKey(const Key('clock_tab_timer')));
      final tasksItem = tester.getSize(find.byKey(const Key('clock_tab_tasks')));
      expect(
        alarmItem.width + timerItem.width + tasksItem.width,
        closeTo(370, 1),
      );

      // Alarm listesi mobilde tek sutun: iki kart AYNI dx'te, farkli dy'de.
      final first = tester.getTopLeft(find.text('07:30'));
      final second = tester.getTopLeft(find.text('22:00'));
      expect(first.dx, second.dx);
      expect(second.dy, greaterThan(first.dy));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
