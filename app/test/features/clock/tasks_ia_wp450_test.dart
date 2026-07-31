import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/data/repositories/user_task_repository.dart';
import 'package:online_study_room/features/clock/tasks_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tamamlama yazımlarını sayan repository; çift tap korumasını doğrular.
class _CountingRepository implements UserTaskRepository {
  _CountingRepository(this._inner);

  final InMemoryUserTaskRepository _inner;
  var completionWrites = 0;

  @override
  Future<List<UserTask>> load({required String userKey}) =>
      _inner.load(userKey: userKey);

  @override
  Future<void> saveAll({
    required String userKey,
    required List<UserTask> tasks,
  }) => _inner.saveAll(userKey: userKey, tasks: tasks);

  @override
  Future<UserTask> upsert({
    required String userKey,
    required UserTask task,
    required String operationId,
    bool archived = false,
  }) => _inner.upsert(
    userKey: userKey,
    task: task,
    operationId: operationId,
    archived: archived,
  );

  @override
  Future<void> setCompleted({
    required String userKey,
    required String taskId,
    required bool completed,
    required DateTime occurredAt,
    required DateTime occurrenceDay,
    required String operationId,
  }) async {
    completionWrites += 1;
    // Yazma gecikmesi olmadan çift tap koruması gözlemlenemez.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await _inner.setCompleted(
      userKey: userKey,
      taskId: taskId,
      completed: completed,
      occurredAt: occurredAt,
      occurrenceDay: occurrenceDay,
      operationId: operationId,
    );
  }

  @override
  Future<void> migrateLegacy({
    required String userKey,
    required List<UserTask> tasks,
    required String migrationId,
  }) => _inner.migrateLegacy(
    userKey: userKey,
    tasks: tasks,
    migrationId: migrationId,
  );
}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  required UserTaskRepository repo,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
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
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const TasksScreen(embedded: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(TasksScreen)));
}

void main() {
  final today = istanbulDay(DateTime.now());

  testWidgets('aktif sekme Bugün, Tekrarlanan ve Diğer bölümlerine ayrılır', (
    tester,
  ) async {
    final repo = InMemoryUserTaskRepository();
    final container = await _pumpScreen(tester, repo: repo);
    final actions = container.read(userTaskActionsProvider);

    await actions.add(
      rawTitle: 'Physics today',
      recurrence: UserTaskRecurrence.daily,
      intervalDays: 3,
      anchorDate: today,
    );
    await actions.add(
      rawTitle: 'Chemistry later',
      recurrence: UserTaskRecurrence.daily,
      intervalDays: 3,
      anchorDate: today.add(const Duration(days: 1)),
    );
    await actions.add(
      rawTitle: 'Future once',
      dueAt: DateTime.now().add(const Duration(days: 9)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Recurring'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Every 3 days'), findsNWidgets(2));

    // Sırası gelmemiş occurrence tamamlanamaz: satır tap'i kapalıdır.
    final chemistryTile = find.ancestor(
      of: find.text('Chemistry later'),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(chemistryTile).onTap, isNull);
    await tester.tap(find.text('Chemistry later'));
    await tester.pumpAndSettle();
    final chemistry = (await container.read(
      userTasksProvider.future,
    )).firstWhere((task) => task.title == 'Chemistry later');
    expect(chemistry.completed, isFalse);
  });

  testWidgets('satır tap tamamlar, snackbar undo aynı occurrence\'ı geri açar', (
    tester,
  ) async {
    final repo = InMemoryUserTaskRepository();
    final container = await _pumpScreen(tester, repo: repo);
    await container
        .read(userTaskActionsProvider)
        .add(
          rawTitle: 'Reading',
          recurrence: UserTaskRecurrence.daily,
          intervalDays: 2,
          anchorDate: today,
        );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();
    var task = (await container.read(userTasksProvider.future)).single;
    expect(task.completed, isTrue);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    task = (await container.read(userTasksProvider.future)).single;
    expect(task.completed, isFalse);
    expect(task.completedAt, isNull);
    // Faz korunur: aynı occurrence yeniden açılır, döngü kaymaz.
    expect(task.anchorDate, today);
    expect(task.intervalDays, 2);
  });

  testWidgets('yazma sürerken ikinci tap yeni bir tamamlama üretmez', (
    tester,
  ) async {
    final repo = _CountingRepository(InMemoryUserTaskRepository());
    final container = await _pumpScreen(tester, repo: repo);
    await container
        .read(userTaskActionsProvider)
        .add(
          rawTitle: 'Double tap',
          recurrence: UserTaskRecurrence.daily,
          anchorDate: today,
        );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Double tap'));
    await tester.pump();
    await tester.tap(find.text('Double tap'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repo.completionWrites, 1);
    final task = (await container.read(userTasksProvider.future)).single;
    expect(task.completed, isTrue);
  });

  testWidgets('uzun başlık ve 2x metin ölçeğinde satır taşmaz', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = InMemoryUserTaskRepository();
    final container = await _pumpScreen(tester, repo: repo, textScale: 2.0);
    await container
        .read(userTaskActionsProvider)
        .add(
          rawTitle:
              'Çok uzun bir görev başlığı: bugünün tekrar eden okuma planını '
              'tamamla ve notlarını gözden geçir',
          recurrence: UserTaskRecurrence.daily,
          intervalDays: 3,
          anchorDate: today,
        );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('editör N günlük tekrar aralığını kaydeder', (tester) async {
    final repo = InMemoryUserTaskRepository();
    final container = await _pumpScreen(tester, repo: repo);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Biology');
    await tester.tap(find.text('Refresh every day'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Repeat interval (days)'),
      '3',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await tester.pumpAndSettle();

    final task = (await container.read(userTasksProvider.future)).single;
    expect(task.recurrence, UserTaskRecurrence.daily);
    expect(task.intervalDays, 3);
    expect(task.anchorDate, today);
  });
}
