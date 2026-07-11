import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/nudge_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/nudge.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/nudge_notification_listener.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNudgeService implements NudgeNotificationGateway {
  final List<Nudge> shown = [];

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> showNudge(Nudge nudge) async => shown.add(nudge);
}

Nudge _nudge(String id, {DateTime? readAt}) => Nudge(
      id: id,
      groupId: 'g1',
      senderId: 's1',
      recipientId: 'u1',
      createdAt: DateTime(2026),
      readAt: readAt,
    );

Future<void> _tick() => Future.delayed(const Duration(milliseconds: 10), () => _);

void main() {
  const userId = 'u1';

  Future<(ProviderContainer, _FakeNudgeService)> boot(
    SharedPreferences prefs,
    Stream<List<Nudge>> nudges,
  ) async {
    final fake = _FakeNudgeService();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: userId, displayName: 'Ben', createdAt: DateTime(2026)),
          ),
        ),
        nudgeNotificationServiceProvider.overrideWithValue(fake),
        receivedNudgesProvider(userId).overrideWith((ref) => nudges),
      ],
    );
    container.listen(nudgeNotificationListenerProvider, (_, __) {});
    await container.read(authStateProvider.future);
    await _tick();
    return (container, fake);
  }

  test('ilk gözlem mevcut okunmamışları sessizce işaretler (patlama yok)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = StreamController<List<Nudge>>();
    final (container, fake) = await boot(prefs, controller.stream);
    addTearDown(container.dispose);
    addTearDown(controller.close);

    controller.add([_nudge('a')]);
    await _tick();

    expect(fake.shown, isEmpty);
  });

  test('seed sonrası yeni dürtme bir kez bildirilir, tazelemede tekrar etmez',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = StreamController<List<Nudge>>();
    final (container, fake) = await boot(prefs, controller.stream);
    addTearDown(container.dispose);
    addTearDown(controller.close);

    controller.add([_nudge('a')]); // seed
    await _tick();
    controller.add([_nudge('a'), _nudge('b')]); // b yeni
    await _tick();
    controller.add([_nudge('a'), _nudge('b')]); // stream tazelendi → tekrar yok
    await _tick();

    expect(fake.shown.map((n) => n.id), ['b']);
  });

  test('uygulama yeniden açılınca (kalıcı set) eski dürtme tekrar bildirilmez',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // 1. oturum: b bildirildi ve kalıcı sete yazıldı.
    final c1 = StreamController<List<Nudge>>();
    final (cont1, fake1) = await boot(prefs, c1.stream);
    c1.add([_nudge('a')]);
    await _tick();
    c1.add([_nudge('a'), _nudge('b')]);
    await _tick();
    expect(fake1.shown.map((n) => n.id), ['b']);
    cont1.dispose();
    await c1.close();

    // 2. oturum: aynı prefs; a ve b sette → hiç bildirim yok.
    final c2 = StreamController<List<Nudge>>();
    final (cont2, fake2) = await boot(prefs, c2.stream);
    addTearDown(cont2.dispose);
    addTearDown(c2.close);
    c2.add([_nudge('a'), _nudge('b')]);
    await _tick();

    expect(fake2.shown, isEmpty);
  });
}
