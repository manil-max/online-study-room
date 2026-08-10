// WP-647 — var olan bir görevi "her N günde bir" yapmak onu Bugün'den düşürüyordu.
//
// 🔴 Kök neden iki çağıranın **aynı kuralı paylaşmamasıydı**. `add` tekrarlı
// görev oluştururken anchor'ı açıkça kuruyor:
//   `_dateOnly(anchorDate ?? istanbulDay(dueAt ?? now))`
// Düzenleme yolu (`tasks_screen.dart` → `update`) ise anchor'a hiç değinmiyor;
// `clearAnchorDate: result.recurrence != UserTaskRecurrence.daily` yalnız
// tekrarlamayı KAPATIRKEN temizliyor. Tek seferlikten tekrarlıya geçişte anchor
// `null` kalıyor ve `taskRecurrenceAnchorDay` görevin **oluşturulma gününe**
// düşüyor.
//
// 🔴 Neden hiçbir kapı görmedi. `test/core/tasks/*` görevleri doğrudan
// `UserTask(...)` ile **anchor'lı** kuruyor; hiçbiri ekranın kurduğu `copyWith`
// şeklini taklit etmiyor. Kabuğu taklit etmeyen test bu sınıfı göremez — bu
// depoda `Scaffold.bottomSheet` dersinin aynısı.
//
// Aşağıdaki ilk test `tasks_screen.dart:57-66`'nın kurduğu nesneyi **birebir**
// üretir; ikincisi ise düzeltmenin fazla ileri gitmediğini (açık anchor'ı
// ezmediğini) sabitler.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/tasks/task_recurrence.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/data/repositories/user_task_repository.dart';

void main() {
  test('5 gun once acilan gorev bugun "her 3 gunde bir" yapilinca BUGUN sayilir',
      () async {
    // Gorev 5 Agustos'ta olusturuldu.
    var now = DateTime.utc(2026, 8, 5, 9);
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
    final created = await container
        .read(userTaskActionsProvider)
        .add(rawTitle: 'Kitap oku');
    expect(created, isNotNull);
    expect(created!.isRecurring, isFalse);

    // 10 Agustos: kullanici gorevi acip "her 3 gunde bir" yapiyor.
    now = DateTime.utc(2026, 8, 10, 9);
    await container.read(userTasksProvider.notifier).reload();

    // 🔴 `tasks_screen.dart` duzenleme dalinin BIREBIR kurdugu nesne:
    // anchorDate gecilmiyor, clearAnchorDate tekrarliya gecerken false.
    await container.read(userTaskActionsProvider).update(
          created.copyWith(
            recurrence: UserTaskRecurrence.daily,
            intervalDays: 3,
            clearDueAt: true,
            clearAnchorDate: false,
          ),
        );

    final task = container.read(userTasksProvider).value!.single;
    expect(task.isRecurring, isTrue);
    expect(
      isTaskOccurrenceDay(task, now),
      isTrue,
      reason:
          'Gorev BUGUN gorunmuyor: anchor gorevin olusturulma gunune (5 Agustos) '
          'dustu, 10 Agustos ise 3 gunluk fazin disinda. Kullanici gorevi '
          'Bugun listesinde bulamaz, "Sirada: 11 Agustos" yazisini gorur.',
    );

    // Ayni kusurun ikinci yuzu: o gun kutuya dokunmak HATA veriyordu.
    final errorsBefore = container.read(userTaskMutationErrorProvider);
    await container.read(userTaskActionsProvider).toggle(task.id);
    expect(
      container.read(userTasksProvider).value!.single.completed,
      isTrue,
      reason:
          'Gorev bugun tamamlanamiyor: `taskOccurrenceDayForCompletion` null '
          'donuyor ve kullanici hata mesaji aliyor.',
    );
    expect(container.read(userTaskMutationErrorProvider), errorsBefore);
  });

  test('KARSI IDDIA: acik anchor EZILMEZ (duzeltme fazi kaydirmaz)', () async {
    // Sabotaj kapisi. Duzeltme "her guncellemede anchor'i bugune yaz" olsaydi
    // bu test kirmizi duserdi: kullanicinin kurdugu faz her duzenlemede
    // sifirlanir, tekrarlama takvimi kayardi.
    var now = DateTime.utc(2026, 7, 30, 9);
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
    final created = await container.read(userTaskActionsProvider).add(
          rawTitle: 'Fizik',
          recurrence: UserTaskRecurrence.daily,
          intervalDays: 3,
          anchorDate: DateTime(2026, 7, 30),
        );
    expect(created!.anchorDate, DateTime(2026, 7, 30));

    now = DateTime.utc(2026, 8, 10, 9);
    await container.read(userTasksProvider.notifier).reload();
    await container
        .read(userTaskActionsProvider)
        .update(created.copyWith(title: 'Fizik tekrar'));

    expect(
      container.read(userTasksProvider).value!.single.anchorDate,
      DateTime(2026, 7, 30),
      reason: 'Sadece basligi degistiren bir duzenleme tekrarlama fazini kaydirdi.',
    );
  });
}
