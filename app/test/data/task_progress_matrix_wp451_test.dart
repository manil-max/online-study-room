// WP-451: görev/başarım/grup ilerlemesi görev tarafı kabul matrisi.
//
// Kartın kabul kriterleri: occurrence kaybı/çifti 0; cadence drift 0; undo
// sonrası ilerleme uzlaşması doğru; WP-455'in okuyacağı fixture açık.
//
// WP-449 motoru ve WP-450 ekranı tek tek doğrulanmıştı; burada ölçülen şey
// **aralarındaki ve komşu kavramlarla olan** davranış: takvim fazının zamanla
// kaymaması, İstanbul gün sınırı, çevrimdışı, iki cihaz, silinen ders ve
// görev tamamlamanın çalışma süresine sızmaması.
//
// Sunucu eşi: `supabase/tests/034_user_task_recurrence_contract.test.sql`
// (WP-472 ile açıldı). Sözleşmenin iki ucu ayrı ayrı yaşamamalı — WP-373'te
// tam olarak bu yüzden bir özellik aylarca ölü kaldı.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/tasks/task_recurrence.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_subject_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';

/// Belirli çağrılarda patlayan repository: çevrimdışı yazma hatası.
class _FlakyTaskRepository extends InMemoryUserTaskRepository {
  _FlakyTaskRepository({required super.now});

  int failCompletions = 0;
  int completionCalls = 0;

  @override
  Future<void> setCompleted({
    required String userKey,
    required String taskId,
    required bool completed,
    required DateTime occurredAt,
    required DateTime occurrenceDay,
    required String operationId,
  }) async {
    completionCalls++;
    if (completionCalls <= failCompletions) {
      throw StateError('offline');
    }
    return super.setCompleted(
      userKey: userKey,
      taskId: taskId,
      completed: completed,
      occurredAt: occurredAt,
      occurrenceDay: occurrenceDay,
      operationId: operationId,
    );
  }
}

UserTask _recurring({
  required int intervalDays,
  required DateTime anchor,
  String id = 'task-1',
}) => UserTask(
  id: id,
  title: 'Fizik',
  completed: false,
  createdAt: DateTime.utc(2026, 1, 1),
  sortOrder: 0,
  recurrence: UserTaskRecurrence.daily,
  intervalDays: intervalDays,
  anchorDate: anchor,
);

/// Bir görevin [from] gününden başlayarak sıradaki [count] occurrence gününü
/// motorun kendisine sordurur — sabit bir liste ile karşılaştırmak, motoru
/// değil kendi aritmetiğimi test etmek olurdu.
List<DateTime> _occurrenceRun(UserTask task, DateTime from, int count) {
  final days = <DateTime>[];
  var cursor = from;
  for (var i = 0; i < count; i++) {
    final next = nextTaskOccurrenceDay(
      task,
      cursor,
      includeCurrentDay: i == 0,
    );
    days.add(next);
    cursor = DateTime.utc(next.year, next.month, next.day, 12);
  }
  return days;
}

void main() {
  group('cadence drift 0', () {
    for (final interval in [1, 2, 3, 7]) {
      test('$interval günlük görevde faz anchor + k*$interval kalır', () {
        final anchor = DateTime(2026, 3, 1);
        final task = _recurring(intervalDays: interval, anchor: anchor);
        final run = _occurrenceRun(task, DateTime.utc(2026, 3, 1, 9), 12);

        for (var k = 0; k < run.length; k++) {
          expect(
            run[k],
            anchor.add(Duration(days: k * interval)),
            reason: '$k. occurrence fazdan kaydı',
          );
          expect(isTaskCalendarOccurrenceDay(task, run[k]), isTrue);
        }
        // Ara günler occurrence üretmez (interval 1'de ara gün yoktur).
        if (interval > 1) {
          expect(
            isTaskCalendarOccurrenceDay(
              task,
              anchor.add(Duration(days: interval - 1)),
            ),
            isFalse,
            reason: 'döngü dışı gün occurrence sayılmamalı',
          );
        }
      });
    }

    test('geç tamamlama sonraki occurrence gününü kaydırmaz', () async {
      // 🔴 Asıl drift riski bu: "tamamlandığı andan itibaren N gün" mantığı
      // her geç tamamlamada döngüyü ileri iter ve haftalık görev takvimden
      // kopar. Faz yalnız anchor'a bağlı olmalı.
      var now = DateTime.utc(2026, 3, 8, 20, 30); // İstanbul 23:30
      final repo = InMemoryUserTaskRepository(now: () => now);
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userTaskRepositoryProvider.overrideWithValue(repo),
          userTaskClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userTasksProvider.future);
      final task = await container
          .read(userTaskActionsProvider)
          .add(
            rawTitle: 'Haftalık tekrar',
            recurrence: UserTaskRecurrence.daily,
            intervalDays: 7,
            anchorDate: DateTime(2026, 3, 1),
          );
      expect(task, isNotNull);

      await container.read(userTaskActionsProvider).toggle(task!.id);
      final completed = container.read(userTasksProvider).value!.single;
      expect(completed.completed, isTrue);

      expect(
        nextTaskOccurrenceDay(
          completed,
          DateTime.utc(2026, 3, 9, 9),
          includeCurrentDay: false,
        ),
        DateTime(2026, 3, 15),
        reason: 'sonraki occurrence anchor + 2*7; tamamlama anına göre değil',
      );
    });

    test('tamamlama kaydı faz hesabına HİÇ girmez', () {
      // 🔴 Bu iddia bir mutasyon turunda yazıldı: yukarıdaki "geç tamamlama"
      // testi, fazı `completionDay`e kaydıran bir mutasyonu YAKALAYAMADI.
      // Sebep yapısal — tamamlama yalnız döngü günlerinde mümkün olduğu için
      // "anchor = tamamlama günü" ile "anchor + k*N" ileriye doğru aynı
      // kafesi üretir. Fark ancak kafes dışında bir `completionDay` varken
      // görünür: eski/bozuk kayıt, saat oynaması, elle düzeltme.
      //
      // Ölçülen değişmez: faz YALNIZ anchor'a bağlıdır.
      final task = UserTask(
        id: 'legacy-1',
        title: 'Haftalık tekrar',
        completed: true,
        createdAt: DateTime.utc(2026, 1, 1),
        sortOrder: 0,
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 7,
        anchorDate: DateTime(2026, 3, 1),
        // Kafes günleri 1, 8, 15... — 5 bunlardan biri değil.
        completionDay: DateTime.utc(2026, 3, 5, 12),
      );

      expect(
        nextTaskOccurrenceDay(
          task,
          DateTime.utc(2026, 3, 9, 9),
          includeCurrentDay: false,
        ),
        DateTime(2026, 3, 15),
        reason: 'faz tamamlamadan beslenseydi 12 Mart çıkardı',
      );
      expect(taskRecurrenceAnchorDay(task), DateTime(2026, 3, 1));
      expect(isTaskCalendarOccurrenceDay(task, DateTime(2026, 3, 12)), isFalse);
    });
  });

  group('İstanbul gün sınırı ve DST bağımsızlığı', () {
    test('23:59 ile 00:01 farklı occurrence günlerine düşer', () {
      // Europe/Istanbul kalıcı UTC+3. 20:59:59Z = 23:59:59, 21:00:00Z = ertesi
      // gün 00:00. Motorun UTC gününe değil İstanbul gününe bakması gerekir.
      final lateNight = DateTime.utc(2026, 3, 8, 20, 59, 59);
      final justAfterMidnight = DateTime.utc(2026, 3, 8, 21, 0, 1);

      expect(istanbulDay(lateNight), DateTime(2026, 3, 8));
      expect(istanbulDay(justAfterMidnight), DateTime(2026, 3, 9));

      final task = _recurring(intervalDays: 2, anchor: DateTime(2026, 3, 8));
      expect(isTaskOccurrenceDay(task, lateNight), isTrue);
      expect(
        isTaskOccurrenceDay(task, justAfterMidnight),
        isFalse,
        reason: 'gece yarısını geçen tap bir sonraki güne yazılamaz',
      );
    });

    test('eski DST geçiş tarihlerinde aralık tam N gün kalır', () {
      // Türkiye 2016'da DST'yi kaldırdı; yine de faz aritmetiği saat kaymasına
      // duyarlı olsaydı bu iki hafta sonunda 1 gün kayardı. Sabitleniyor.
      for (final anchor in [DateTime(2026, 3, 22), DateTime(2026, 10, 18)]) {
        final task = _recurring(intervalDays: 7, anchor: anchor);
        final run = _occurrenceRun(task, DateTime.utc(anchor.year, anchor.month, anchor.day, 9), 4);
        for (var k = 1; k < run.length; k++) {
          expect(
            run[k].difference(run[k - 1]).inDays,
            7,
            reason: '$anchor fazında ${k}inci aralık 7 gün değil',
          );
        }
      }
    });
  });

  group('occurrence kaybı/çifti 0', () {
    late DateTime now;
    late _FlakyTaskRepository repo;
    late ProviderContainer container;

    setUp(() async {
      now = DateTime.utc(2026, 3, 8, 9);
      repo = _FlakyTaskRepository(now: () => now);
      container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userTaskRepositoryProvider.overrideWithValue(repo),
          userTaskClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      await container.read(userTasksProvider.future);
    });

    Future<UserTask> seedTask({int intervalDays = 3}) async {
      final task = await container
          .read(userTaskActionsProvider)
          .add(
            rawTitle: 'Kimya',
            recurrence: UserTaskRecurrence.daily,
            intervalDays: intervalDays,
            anchorDate: DateTime(2026, 3, 8),
          );
      return task!;
    }

    test('çevrimdışı hata occurrence tüketmez, retry tamamlar', () async {
      final task = await seedTask();
      repo.failCompletions = 1;

      await container.read(userTaskActionsProvider).toggle(task.id);
      expect(
        container.read(userTasksProvider).value!.single.completed,
        isFalse,
        reason: 'başarısız yazmadan sonra optimistic durum geri alınmalı',
      );

      // Aynı gün, aynı occurrence: kullanıcı yeniden dener ve geçer.
      await container.read(userTaskActionsProvider).toggle(task.id);
      final after = container.read(userTasksProvider).value!.single;
      expect(after.completed, isTrue);
      expect(istanbulDay(after.completionDay!), DateTime(2026, 3, 8));

      final stored = await repo.load(userKey: 'local');
      expect(stored, hasLength(1), reason: 'çift satır üretilmemeli');
    });

    test('hızlı çift tap başlangıç durumuna döner, tek satır bırakır', () async {
      final task = await seedTask();

      await container.read(userTaskActionsProvider).toggle(task.id);
      await container.read(userTaskActionsProvider).toggle(task.id);

      final after = container.read(userTasksProvider).value!.single;
      expect(after.completed, isFalse, reason: 'iki tap = tamamla + geri al');
      expect(after.completedAt, isNull);
      expect((await repo.load(userKey: 'local')), hasLength(1));
    });

    test('undo sonrası yeniden tamamlama fazı ve occurrence sayısını korur', () async {
      final task = await seedTask(intervalDays: 7);

      await container.read(userTaskActionsProvider).toggle(task.id);
      await container.read(userTaskActionsProvider).toggle(task.id); // undo
      await container.read(userTaskActionsProvider).toggle(task.id); // yeniden

      final after = container.read(userTasksProvider).value!.single;
      expect(after.completed, isTrue);
      expect(after.anchorDate, DateTime(2026, 3, 8));
      expect(
        nextTaskOccurrenceDay(
          after,
          DateTime.utc(2026, 3, 9, 9),
          includeCurrentDay: false,
        ),
        DateTime(2026, 3, 15),
        reason: 'undo/redo döngüsü fazı kaydırmamalı',
      );
      expect((await repo.load(userKey: 'local')), hasLength(1));
    });

    test('aynı operationId tekrarı iş yapmaz, çelişkili tekrarı patlar', () async {
      final task = await seedTask();
      final occurrenceDay = DateTime(2026, 3, 8);

      await repo.setCompleted(
        userKey: 'local',
        taskId: task.id,
        completed: true,
        occurredAt: now,
        occurrenceDay: occurrenceDay,
        operationId: 'op-1',
      );
      // Aktarım katmanı aynı isteği tekrarlarsa iş ikinci kez yapılmaz.
      await repo.setCompleted(
        userKey: 'local',
        taskId: task.id,
        completed: true,
        occurredAt: now,
        occurrenceDay: occurrenceDay,
        operationId: 'op-1',
      );
      expect((await repo.load(userKey: 'local')).single.completed, isTrue);

      // Aynı anahtarın BAŞKA bir niyetle kullanılması sessizce kabul edilemez.
      await expectLater(
        repo.setCompleted(
          userKey: 'local',
          taskId: task.id,
          completed: false,
          occurredAt: now,
          occurrenceDay: occurrenceDay,
          operationId: 'op-1',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('iki cihaz', () {
    test('B cihazı reload sonrası A cihazının tamamlamasını görür', () async {
      final now = DateTime.utc(2026, 3, 8, 9);
      final repo = InMemoryUserTaskRepository(now: () => now);

      ProviderContainer device() {
        final c = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            userTaskRepositoryProvider.overrideWithValue(repo),
            userTaskClockProvider.overrideWithValue(() => now),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      final deviceA = device();
      final deviceB = device();
      await deviceA.read(userTasksProvider.future);
      await deviceB.read(userTasksProvider.future);

      final task = await deviceA
          .read(userTaskActionsProvider)
          .add(
            rawTitle: 'Biyoloji',
            recurrence: UserTaskRecurrence.daily,
            intervalDays: 2,
            anchorDate: DateTime(2026, 3, 8),
          );
      await deviceA.read(userTaskActionsProvider).toggle(task!.id);

      // B henüz görevi bile görmüyor: iddianın boşa düşmediğini önce bu
      // gösteriyor, sonra reload ile yakınsama ölçülüyor.
      expect(deviceB.read(userTasksProvider).value, isEmpty);

      await deviceB.read(userTasksProvider.notifier).reload();
      final seen = deviceB.read(userTasksProvider).value!.single;
      expect(seen.id, task.id);
      expect(seen.completed, isTrue);
      expect(istanbulDay(seen.completionDay!), DateTime(2026, 3, 8));
    });
  });

  group('kavramlar arası yan etki 0', () {
    test('ders silmek görevleri ve tamamlanma durumunu etkilemez', () async {
      final now = DateTime.utc(2026, 3, 8, 9);
      final tasks = InMemoryUserTaskRepository(now: () => now);
      final subjects = InMemorySubjectRepository();
      addTearDown(subjects.dispose);

      const subject = Subject(
        id: 'sub-1',
        userId: 'u1',
        name: 'Fizik',
        color: 'chart-1',
      );
      await subjects.addSubject(subject);

      final task = _recurring(intervalDays: 3, anchor: DateTime(2026, 3, 8));
      await tasks.saveAll(userKey: 'local', tasks: [task]);
      await tasks.setCompleted(
        userKey: 'local',
        taskId: task.id,
        completed: true,
        occurredAt: now,
        occurrenceDay: DateTime(2026, 3, 8),
        operationId: 'op-subject',
      );

      await subjects.deleteSubject(subject.id);

      // Görev modeli derse hiç bağlı değil; bu iddia o ayrımın kazara
      // bozulmadığını sabitler (ör. ileride subject_id eklenirse cascade
      // silme görev kaybına dönüşebilirdi).
      final after = await tasks.load(userKey: 'local');
      expect(after, hasLength(1));
      expect(after.single.completed, isTrue);
      expect(await subjects.watchUserSubjects('u1').first, isEmpty);
    });

    test('görev tamamlamak çalışma süresi/oturum üretmez', () async {
      final now = DateTime.utc(2026, 3, 8, 9);
      final tasks = InMemoryUserTaskRepository(now: () => now);
      final study = InMemoryStudyRepository();

      final before = await study.fetchUserStudySummary('u1');

      final task = _recurring(intervalDays: 1, anchor: DateTime(2026, 3, 8));
      await tasks.saveAll(userKey: 'local', tasks: [task]);
      await tasks.setCompleted(
        userKey: 'local',
        taskId: task.id,
        completed: true,
        occurredAt: now,
        occurrenceDay: DateTime(2026, 3, 8),
        operationId: 'op-study',
      );

      final after = await study.fetchUserStudySummary('u1');
      expect(
        after.lifetimeSeconds,
        before.lifetimeSeconds,
        reason: 'görev tamamlama çalışma süresi değildir; başarım ve grup '
            'ilerlemesi yalnız oturumdan beslenir',
      );
      expect(after.yearSeconds, before.yearSeconds);
      expect(after.hotWindowSeconds, before.hotWindowSeconds);
      expect(await study.watchUserSessions('u1').first, isEmpty);
    });
  });
}
