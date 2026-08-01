// WP-480 (V57-N03): "Görevde 'kaç günde bir yenilensin' seçiliyor ama metin
// hâlâ 'Refresh every day' diyor."
//
// WP-449/450 N-günlük tekrarı getirdi ama üç yüzey sabit günlük metni
// gösteriyordu: veri N gün, metin 1 gün. Ayrıca ipucu "gece yarısı yeniden
// aktif olur" diyordu — bu N=1 için doğru, N>1 için **yanlış bilgi**.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tasks/task_deadline.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/clock/tasks_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpTasksScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        userTaskRepositoryProvider.overrideWithValue(
          InMemoryUserTaskRepository(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const TasksScreen(embedded: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final tr = AppLocalizationsTr();
  final en = AppLocalizationsEn();

  group('taskRecurrenceSummary aralığı söyler', () {
    test('N=1 günlük, N=2 ve N=7 aralığı yazar (TR)', () {
      expect(taskRecurrenceSummary(tr, 1), 'Her gün yenilenir');
      expect(taskRecurrenceSummary(tr, 2), '2 günde bir yenilenir');
      expect(taskRecurrenceSummary(tr, 7), '7 günde bir yenilenir');
    });

    test('aynı ayrım İngilizce katalogda da var', () {
      expect(taskRecurrenceSummary(en, 1), 'Refresh every day');
      expect(taskRecurrenceSummary(en, 2), 'Refresh every 2 days');
      expect(taskRecurrenceSummary(en, 7), 'Refresh every 7 days');
    });

    test('bozuk aralık sunucudaki 1–365 sınırına kısılır', () {
      expect(taskRecurrenceSummary(tr, 0), taskRecurrenceSummary(tr, 1));
      expect(taskRecurrenceSummary(tr, -3), taskRecurrenceSummary(tr, 1));
      expect(taskRecurrenceSummary(tr, 9999), taskRecurrenceSummary(tr, 365));
    });
  });

  group('taskRecurrenceHint N>1 için "gece yarısı" demiyor', () {
    test('N=1 bugünü ve gece yarısını söyler', () {
      final hint = taskRecurrenceHint(tr, 1);
      expect(hint, contains('bugünü'));
      expect(hint, contains('gece yarısı'));
    });

    // 🔴 Kartın "ek kusur" maddesi: bu iddia olmadan yanlış bilgi geri gelir.
    test('N=2 ve N=7 "yalnız bugün" iddiasında bulunmuyor', () {
      for (final days in [2, 7]) {
        final hint = taskRecurrenceHint(tr, days);
        expect(hint, isNot(contains('bugünü')), reason: 'N=$days');
        expect(hint, contains('$days gün'), reason: 'N=$days');
      }
    });

    test('İngilizce ipucu da aynı ayrımı yapıyor', () {
      expect(taskRecurrenceHint(en, 1), contains('today only'));
      expect(taskRecurrenceHint(en, 3), isNot(contains('today only')));
      expect(taskRecurrenceHint(en, 3), contains('3 days'));
    });
  });


  // 🔴 Saf fonksiyon doğru olsa bile yüzey onu **çağırmıyorsa** hata durur:
  // sahibin gördüğü ekran düzenleyicidir, bu yüzden gerçekten sürülüyor.
  testWidgets('düzenleyici başlığı ve ipucu yazılan aralığı izler', (
    tester,
  ) async {
    await _pumpTasksScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Biology');

    // Tekrar kapalıyken seçenek günlük olarak okunur.
    expect(find.text('Refresh every day'), findsOneWidget);

    await tester.tap(find.text('Refresh every day'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Repeat interval (days)'),
      '5',
    );
    await tester.pumpAndSettle();

    // Sahibin bildirdiği hata tam olarak buydu: aralık 5 iken metin "every day".
    expect(find.text('Refresh every day'), findsNothing);
    expect(find.text('Refresh every 5 days'), findsOneWidget);
    // Ek kusur: "gece yarısı yeniden aktif olur" N>1'de yanlış bilgi.
    expect(find.textContaining('today only'), findsNothing);
    expect(find.textContaining('5 days later'), findsOneWidget);
  });
}
