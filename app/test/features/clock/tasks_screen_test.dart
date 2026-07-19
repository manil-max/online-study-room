import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/clock/clock_screen.dart';
import 'package:online_study_room/features/clock/tasks_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('TasksScreen add via actions and show active', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryUserTaskRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userTaskRepositoryProvider.overrideWithValue(repo),
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

    expect(find.byType(TasksScreen), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TasksScreen)),
    );
    await container
        .read(userTaskActionsProvider)
        .add(
          rawTitle: 'Shop',
          dueAt: DateTime.now().add(const Duration(days: 1)),
        );
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsOneWidget);
  });

  test('ClockTab includes tasks', () {
    expect(ClockTab.values, contains(ClockTab.tasks));
  });

  testWidgets('UI günlük görev ekler, bugün tamamlar ve geri alır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryUserTaskRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userTaskRepositoryProvider.overrideWithValue(repo),
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

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Daily reading');
    await tester.tap(find.text('Refresh every day'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TasksScreen)),
    );
    var task = (await container.read(userTasksProvider.future)).single;
    expect(task.recurrence, UserTaskRecurrence.daily);
    expect(find.text('Daily reading'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    await tester.pumpAndSettle();
    task = (await container.read(userTasksProvider.future)).single;
    expect(task.completed, isTrue);
    expect(find.text('Daily reading'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pumpAndSettle();
    task = (await container.read(userTasksProvider.future)).single;
    expect(task.completed, isFalse);
  });

  testWidgets('resume görev projectionını yeniden yükler', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userTasksProvider.overrideWith((ref) async {
            loads++;
            return const <UserTask>[];
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TasksScreen(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialLoads = loads;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(loads, greaterThan(initialLoads));
  });

  testWidgets('sync hatası çevrimdışı mesajı ve retry gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userTasksProvider.overrideWith(
            (ref) => Future<List<UserTask>>.error('offline'),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('tr'),
          home: const TasksScreen(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Görevler yenilenemedi. Çevrimdışı olabilirsin.'),
      findsOneWidget,
    );
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets('günlük görev editörü Almanca 360 px genişlikte taşmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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
          locale: const Locale('de'),
          home: const TasksScreen(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Täglich erneuern'), findsOneWidget);
  });
}
