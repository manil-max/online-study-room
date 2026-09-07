// WP-811 — `markRead` yazilmisti ama HIC cagrilmiyordu.
//
// 🔴 Olculmus kusur: `NudgeRepository.markRead` (nudge_repository.dart:70) ve
// sunucu RPC'si `public.mark_nudge_read` (0016_nudges.sql) VARDI; `app/lib`
// icinde ise SIFIR cagri yeri. Sonuc: her durtme satiri sunucuda omur boyu
// `read_at = null` kaliyordu. Uc somut bedeli:
//   1. Dinleyicideki `.where((n) => n.readAt == null)` suzgeci ETKISIZDI.
//   2. `notified_nudge_ids` seti SharedPreferences'te, yani CIHAZ BASINA:
//      ayni hesabin ikinci cihazi (Windows masaustu + Android) ayni durtmeyi
//      BIR DAHA bildiriyordu.
//   3. `SupabaseNudgeRepository.kNudgeWindow` bu eksigin telafisiydi.
//
// 🔴 `read_at`'in bu uygulamadaki gercek anlami: "bir istemci bu durtmeyi
// teslim alip ISLEDI" — "kullanici gozuyle okudu" degil. Ortada durtme gelen
// kutusu EKRANI yok; `receivedNudgesProvider`in tek tuketicisi dinleyicidir.
// Bu yuzden asagidaki iddialar bildirim GOSTERILMEYEN dallarda da (sessiz
// saat, susturma, gecmis) `markRead` bekler.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart'
    show NotificationPreferencesNotifier;
import 'package:online_study_room/core/notifications/nudge_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/nudge.dart';
import 'package:online_study_room/data/models/nudge_mute.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/nudge_notification_listener.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/repositories/nudge_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNudgeService implements NudgeNotificationGateway {
  final List<Nudge> shown = [];

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> showNudge(Nudge nudge) async => shown.add(nudge);
}

/// Cagrilari SIRAYLA toplayan sahte repository.
///
/// [throwFor] icindeki id'ler icin `markRead` firlatir — hem senkron hem
/// asenkron yolu ayni anda sinamak icin once senkron `throw`, cunku
/// `unawaited(...)` senkron firlatilan bir hatayi yakalamaz.
class _FakeNudgeRepository implements NudgeRepository {
  _FakeNudgeRepository({this.throwFor = const <String>{}});

  final Set<String> throwFor;
  final List<String> markReadCalls = [];

  @override
  Future<void> markRead(String nudgeId) {
    markReadCalls.add(nudgeId);
    if (throwFor.contains(nudgeId)) {
      // Senkron firlatir: dinleyici bunu da yutmali.
      throw const NudgeException(NudgeErrorCode.markReadFailed);
    }
    return Future<void>.value();
  }

  @override
  Stream<List<Nudge>> watchReceivedNudges(String userId) =>
      const Stream<List<Nudge>>.empty();

  @override
  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  }) => throw UnimplementedError();

  @override
  Future<List<String>> listMutedNudgeSenderIds() async => const <String>[];

  @override
  Future<List<NudgeMute>> fetchNudgeMutes() async => const <NudgeMute>[];

  @override
  Future<void> muteNudgesFrom(String userId) async {}

  @override
  Future<void> unmuteNudgesFrom(String userId) async {}
}

Nudge _nudge(
  String id, {
  DateTime? readAt,
  DateTime? createdAt,
  String senderId = 's1',
}) => Nudge(
  id: id,
  groupId: 'g1',
  senderId: senderId,
  recipientId: 'u1',
  createdAt: createdAt ?? DateTime(2026),
  readAt: readAt,
);

/// Dinleyici kurulduktan SONRA olusmus sayilan bir an (canli durtme).
DateTime _live() => DateTime.now().toUtc().add(const Duration(days: 1));

Future<void> _tick() =>
    Future.delayed(const Duration(milliseconds: 10), () => null);

void main() {
  const userId = 'u1';

  Future<(ProviderContainer, _FakeNudgeService, _FakeNudgeRepository)> boot(
    SharedPreferences prefs,
    Stream<List<Nudge>> nudges, {
    Set<String> mutedSenderIds = const <String>{},
    Set<String> markReadThrowsFor = const <String>{},
  }) async {
    final fake = _FakeNudgeService();
    final repo = _FakeNudgeRepository(throwFor: markReadThrowsFor);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: userId, displayName: 'Ben', createdAt: DateTime(2026)),
          ),
        ),
        nudgeNotificationServiceProvider.overrideWithValue(fake),
        // 🔴 Riverpod 3 auto-dispose tuzagi: `overrideWithValue` sabit ornek
        // dondurur, yoksa dinleyicisiz `ref.read` her cagrida YENI repo
        // uretir ve toplanan cagrilar kaybolurdu.
        nudgeRepositoryProvider.overrideWithValue(repo),
        receivedNudgesProvider(userId).overrideWith((ref) => nudges),
        mutedNudgeSenderIdsProvider.overrideWith((ref) async => mutedSenderIds),
      ],
    );
    container.listen(nudgeNotificationListenerProvider, (prev, next) {});
    await container.read(authStateProvider.future);
    await container.read(mutedNudgeSenderIdsProvider.future);
    await _tick();
    return (container, fake, repo);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('1) canli durtme bildirilince markRead TAM BIR KEZ cagrilir', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = StreamController<List<Nudge>>();
    addTearDown(controller.close);
    final (container, fake, repo) = await boot(prefs, controller.stream);
    addTearDown(container.dispose);

    controller.add([_nudge('canli', createdAt: _live())]);
    await _tick();

    expect(fake.shown.map((n) => n.id), ['canli']);
    expect(
      repo.markReadCalls,
      ['canli'],
      reason:
          'Bildirim gosterildi ama sunucuya okundu bilgisi gitmedi: satir '
          'omur boyu read_at = null kalir.',
    );
  });

  test('2) ayni durtme akista tekrar gorununce IKINCI markRead cikmaz', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = StreamController<List<Nudge>>();
    addTearDown(controller.close);
    final (container, _, repo) = await boot(prefs, controller.stream);
    addTearDown(container.dispose);

    final canli = _nudge('canli', createdAt: _live());
    controller.add([canli]);
    await _tick();
    // Realtime tazelendi: AYNI satir tekrar dustu (sunucu cevabi henuz
    // yansimadigi icin hala read_at = null).
    controller.add([canli]);
    await _tick();
    controller.add([canli, _nudge('baska', createdAt: _live())]);
    await _tick();

    expect(
      repo.markReadCalls.where((id) => id == 'canli').length,
      1,
      reason:
          'markRead her karede cagriliyor: akis her tazelendiginde gereksiz '
          'RPC. Cagri yeri kalici setin BUYUDUGU an olmali.',
    );
    expect(repo.markReadCalls, ['canli', 'baska']);
  });

  test('3) sessiz saatte bildirim YOK ama markRead VAR', () async {
    // Tercihler gercek `NotificationPreferencesNotifier` uzerinden okunur;
    // sessiz saati prefs anahtarlariyla acmak stub'a gore uretimi daha iyi
    // temsil eder. Aralik gunun TAMAMI (0 → 1440) ki test hangi saatte
    // kosarsa kossun sessiz saatte olsun (1439 verilseydi 23:59'da flake).
    SharedPreferences.setMockInitialValues({
      NotificationPreferencesNotifier.kQuietEnabled: true,
      NotificationPreferencesNotifier.kQuietStart: 0,
      NotificationPreferencesNotifier.kQuietEnd: 1440,
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = StreamController<List<Nudge>>();
    addTearDown(controller.close);
    final (container, fake, repo) = await boot(prefs, controller.stream);
    addTearDown(container.dispose);

    controller.add([_nudge('sessiz', createdAt: _live())]);
    await _tick();

    expect(fake.shown, isEmpty, reason: 'Sessiz saatte bildirim gosterildi.');
    expect(
      repo.markReadCalls,
      ['sessiz'],
      reason:
          'Sessiz saatte markRead atlandi: sessiz saati biten kullanicinin '
          'IKINCI cihazi ayni durtmeyi patlatir.',
    );
  });

  test('4) susturulmus gonderen: bildirim YOK ama markRead VAR', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = StreamController<List<Nudge>>();
    addTearDown(controller.close);
    final (container, fake, repo) = await boot(
      prefs,
      controller.stream,
      mutedSenderIds: {'sessiz-kisi'},
    );
    addTearDown(container.dispose);

    controller.add([
      _nudge('m', senderId: 'sessiz-kisi', createdAt: _live()),
      _nudge('n', senderId: 'baska', createdAt: _live()),
    ]);
    await _tick();

    expect(fake.shown.map((n) => n.id), ['n']);
    expect(
      repo.markReadCalls..sort(),
      ['m', 'n'],
      reason:
          'Susturulmus gonderenin satiri sunucuda okunmamis birakildi; '
          'pencereyi kirletmekten baska ise yaramaz.',
    );
  });

  test('5) markRead HATA firlatinca dinleyici cokmez, digerleri islenir', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = StreamController<List<Nudge>>();
    addTearDown(controller.close);
    final (container, fake, repo) = await boot(
      prefs,
      controller.stream,
      markReadThrowsFor: {'patlayan'},
    );
    addTearDown(container.dispose);

    controller.add([
      _nudge('patlayan', createdAt: _live()),
      _nudge('saglam', createdAt: _live()),
    ]);
    await _tick();

    expect(repo.markReadCalls..sort(), ['patlayan', 'saglam']);
    expect(
      fake.shown.map((n) => n.id).toList()..sort(),
      ['patlayan', 'saglam'],
      reason:
          'markRead hatasi dongunun kalanini dusurdu: bir satirin sunucu '
          'hatasi yuzunden kullanici DIGER durtmeleri hic gormuyor.',
    );
  });

  test('6) readAt != null gelen durtme icin markRead cagrilmaz', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = StreamController<List<Nudge>>();
    addTearDown(controller.close);
    final (container, fake, repo) = await boot(prefs, controller.stream);
    addTearDown(container.dispose);

    controller.add([
      _nudge('okunmus', createdAt: _live(), readAt: DateTime(2026, 5)),
      _nudge('yeni', createdAt: _live()),
    ]);
    await _tick();

    expect(fake.shown.map((n) => n.id), ['yeni']);
    expect(
      repo.markReadCalls,
      ['yeni'],
      reason:
          'Sunucuda zaten read_at tasiyan satir icin tekrar RPC gonderildi.',
    );
  });

  test(
    '7) dinleyiciden ONCE olusmus gecmis durtme: bildirim YOK, markRead VAR',
    () async {
      // Karar (WP-811): bunlar da markRead edilir. Kullanici onlari zaten
      // kacirdi ve bir daha bildirim uretmeyecekler; sunucuda okunmamis
      // durmalari yalnizca pencereyi (kNudgeWindow) kirletir ve ikinci
      // cihazda ayni "hep okunmamis" yanilgisini surdurur.
      final prefs = await SharedPreferences.getInstance();
      final controller = StreamController<List<Nudge>>();
      addTearDown(controller.close);
      final (container, fake, repo) = await boot(prefs, controller.stream);
      addTearDown(container.dispose);

      controller.add([_nudge('gecmis')]); // createdAt = DateTime(2026)
      await _tick();

      expect(fake.shown, isEmpty, reason: 'Gecmis durtme bildirim uretti.');
      expect(
        repo.markReadCalls,
        ['gecmis'],
        reason:
            'Gecmis durtme sunucuda okunmamis birakildi; ikinci cihaz onu '
            'hala "okunmamis" gorur.',
      );
    },
  );
}
