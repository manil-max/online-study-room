// WP-934 — Araçlar/saat ekranlarında Türkçe arayüzde İngilizce kalan metin.
//
// 🔴 Kusur: Türkçe arayüzde Araçlar sekmesinin adı "Timer", alarm boş
// ekranında ve alarm düzenleyicide "anti-snooze" yazıyordu; zamanlayıcı
// ekranında "Çoklu Timer", "Özel timer", "Henüz çalışan bir timer yok".
// Ayrıca görev düzenleyicideki kalan süre alanının birimi koda sabit İngilizce
// "h", alarm çalma ekranındaki ses yüzdesi İngilizce biçimde ("50%") idi.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/features/clock/clock_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

class _Notifications implements TimerNotificationService {
  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();
  @override
  Future<void> cancel() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> requestPermissionIfNeeded() async {}
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> openSystemNotificationSettings() async {}
}

class _IdleTimer extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

/// Araçlar ekranlarında Türkçe metinde kalmaması gereken İngilizce sözcükler.
final _english = RegExp(r'\b(timer|snooze)\b', caseSensitive: false);

void main() {
  test('TR katalogunda clock* metinlerinde "timer"/"snooze" kalmaz', () {
    final tr =
        jsonDecode(File('lib/l10n/app_tr.arb').readAsStringSync())
            as Map<String, dynamic>;
    final leaks = [
      for (final e in tr.entries)
        if (e.key.startsWith('clock') &&
            e.value is String &&
            _english.hasMatch(e.value as String))
          '${e.key}: ${e.value}',
    ];
    expect(leaks, isEmpty);
  });

  testWidgets('Araclar sekme seridi Turkcede "Timer" yazmaz ve tasmaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await initializeDateFormatting('tr_TR', null);
    // 320 dp telefon, yazi olcegi 1.3: en dar sahne.
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
          studyRepositoryProvider.overrideWithValue(InMemoryStudyRepository()),
          timerNotificationServiceProvider.overrideWithValue(_Notifications()),
          studyTimerProvider.overrideWith(_IdleTimer.new),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const ClockScreen(),
        ),
      ),
    );
    await tester.pump();

    final tab = find.byKey(const Key('clock_tab_timer'));
    expect(
      find.descendant(of: tab, matching: find.text('Timer')),
      findsNothing,
    );
    final texts = [
      for (final t in tester.widgetList<Text>(
        find.descendant(of: tab, matching: find.byType(Text)),
      ))
        t.data ?? '',
    ];
    expect(texts.where(_english.hasMatch), isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('gorev ve alarm ekranlarinda sabit Ingilizce birim/bicim yok', () {
    final tasks = File(
      'lib/features/clock/tasks_screen.dart',
    ).readAsStringSync();
    expect(
      tasks.contains("suffixText: 'h'"),
      isFalse,
      reason: 'Kalan saat alaninin birimi Turkcede "sa" olmali (katalogdan).',
    );
    final ringing = File(
      'lib/features/clock/alarm_ringing_screen.dart',
    ).readAsStringSync();
    expect(
      ringing.contains("round()}%'"),
      isFalse,
      reason: 'Yuzde Turkcede "%50" yazilir; yerel bicimleyici kullanilmali.',
    );
  });
}
