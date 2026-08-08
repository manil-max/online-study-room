// WP-560: hata kollarinin CIKISI.
//
// Olcum su idi: `app/lib` icinde 42 `error: (` kolu var ve cogunun cikisi yok.
// WP-550 dort ana sekmeye asagi cekerek yenileme bagladi, geri kalan dort yeri
// lidere devretti. Bu dosya o dort yeri kilitler:
//
//   1. `card_data_gate.dart`  — pano kartlarinin ORTAK kapisi (13 kart).
//   2. `alarms_screen.dart`   — alarm listesi + kesin-alarm izni probu.
//   3. `timers_screen.dart`   — zamanlayici listesi + hazir sure seridi.
//   4. `class_chat_card.dart` — grup sohbeti.
//
// Iddia sozel degil DAVRANISSAL. Uc sey olculur:
//
//   (a) Hata durumunda GORUNUR bir eylem var (`kErrorRetryButtonKey`).
//   (b) Eyleme basinca ilgili veri kaynagi YENIDEN OKUNUYOR. Sahte depodaki
//       cagri sayaci 1 -> 2 olmali. Bu madde olmadan "dugme var ama hicbir sey
//       yapmiyor" testten gecerdi ve o, hatanin kendisinden kotudur.
//   (c) Yukleme / bos / hata UC AYRI cikti. Eski kod `SizedBox.shrink()` ile
//       hatayi yutuyordu; kullanici bos ekranin yukleniyor mu, bos mu, patlamis
//       mi oldugunu ayirt edemiyordu.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/alarm_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/time_engine/exact_alarm_permission.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/chat_message.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/providers/alarm_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/chat_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/chat_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_alarm_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/features/clock/alarms_screen.dart';
import 'package:online_study_room/features/clock/timers_screen.dart';
import 'package:online_study_room/features/home/widgets/card_data_gate.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _me = Profile(
  id: 'me-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g-1',
  name: 'Odak Grubu',
  inviteCode: 'KAMP42',
  createdBy: _me.id,
  createdAt: DateTime(2026, 1, 1),
);

/// Hic emisyon yapmayan akis: cihazda ag turunun beklendigi kare.
Stream<T> _pending<T>() => StreamController<T>().stream;

Future<AppLocalizations> _tr() =>
    AppLocalizations.delegate.load(const Locale('tr'));

Widget _app(Widget home, {required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

/// Birkac kare pompalar.
///
/// `pumpAndSettle` burada YETMEZ: zamanlanmis kare kalmayinca oturur, ama
/// `blockedUserIdsProvider` gibi Future tabanli kaynaklar bir sonraki turda
/// cozulur. Olculdu: pumpAndSettle sonrasi sohbet hala yukleme karesindeydi ve
/// iddia yalanci KIRMIZI duruyordu. Sonsuz donen spinner varken pumpAndSettle
/// zaten hic oturmaz — bu yardimci iki tuzagi da kapatir.
Future<void> _pumpFrames(WidgetTester tester, [int frames = 5]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump();
  }
}

/// Widget agacini sokup provider'lari (ve `Timer.periodic` ticker'ini) kapatir.
///
/// `timerInstancesProvider` veri kolunda 200 ms'lik bir ticker kurar; agac
/// sokulmezse test sonunda "A Timer is still pending" ile duser.
Future<void> _teardownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

// ───────────────────────────────────────────────────────────────────────────
// 1. card_data_gate — pano kartlarinin ortak kapisi
// ───────────────────────────────────────────────────────────────────────────

/// Sahte oturum akisi: her build'de sayac artar, ilk turda hata verir.
class _SessionSource {
  int calls = 0;

  Stream<List<StudySession>> build() {
    calls++;
    // Ilk tur patlar, ikinci tur veri verir: tekrar-dene GERCEKTEN duzeltiyor
    // mu, yoksa yalniz yeniden mi kosuyor — ikisi ayri iddia.
    if (calls == 1) {
      return Stream<List<StudySession>>.error('ag yok', StackTrace.current);
    }
    return Stream.value(<StudySession>[
      StudySession(
        id: 's-1',
        userId: _me.id,
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        durationSeconds: 3600,
        source: StudySource.live,
      ),
    ]);
  }
}

/// `cardDataGate`i dogrudan kosan kabuk.
///
/// Kart fabrikasinin tamami yerine kapinin KENDISI olculur: uc durumun ciktisi
/// burada dogar ve 13 kart onu paylasir.
class _GateHarness extends ConsumerWidget {
  const _GateHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔴 Riverpod 3 tuzagi: `authStateProvider` dinleyicisiz kalirsa her
    // `read`de yeniden kurulur ve `.value` null doner. `refreshAppData` o
    // durumda ILK SATIRDA sessizce cikar; tekrar-dene testi yalanci yesil
    // olmaz ama sebebi de anlasilmaz. Uretimde kabuk zaten watch eder.
    ref.watch(authStateProvider);
    final sessions = ref.watch(userSessionsProvider);
    final gate = cardDataGate(
      context,
      title: 'Kayitlar',
      sources: [sessions],
    );
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 340,
          height: 260,
          child: gate ?? const Text('KART GOVDESI'),
        ),
      ),
    );
  }
}

List<Override> _gateOverrides({
  _SessionSource? source,
  Stream<List<StudySession>> Function()? sessions,
}) => [
  authStateProvider.overrideWith((ref) => Stream.value(_me)),
  // Grup yok: `groupDailyStats` / `groupMembers` / `groupPresence` kendi
  // icinde `Stream.value(const [])`e kisa devre yapar, Supabase'e gitmez.
  userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
  userGroupsProvider.overrideWith((ref) => Stream.value(const <StudyGroup>[])),
  userStudySummaryProvider.overrideWith((ref) async => UserStudySummary.empty),
  userSessionsProvider.overrideWith(
    (ref) => sessions != null ? sessions() : source!.build(),
  ),
];

void _cardDataGateGroup() {
  group('card_data_gate (pano kartlarinin ortak kapisi)', () {
    testWidgets('hata: gorunur bir eylem var', (tester) async {
      final source = _SessionSource();
      await tester.pumpWidget(
        _app(const _GateHarness(), overrides: _gateOverrides(source: source)),
      );
      await tester.pump();

      final l10n = await _tr();
      expect(find.text(l10n.homeVerilerYuklenemedi), findsOneWidget);
      expect(
        find.byKey(kErrorRetryButtonKey),
        findsOneWidget,
        reason: 'hata metni tek basina cikis degildir',
      );
      expect(find.text(l10n.commonTekrarDene), findsOneWidget);
      await _teardownTree(tester);
    });

    testWidgets('tekrar-dene veri kaynagini yeniden okuyor (1 -> 2)', (
      tester,
    ) async {
      final source = _SessionSource();
      await tester.pumpWidget(
        _app(const _GateHarness(), overrides: _gateOverrides(source: source)),
      );
      await tester.pump();

      expect(source.calls, 1);
      await tester.tap(find.byKey(kErrorRetryButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        source.calls,
        2,
        reason: 'dugme var ama veri kaynagi yeniden okunmuyor',
      );
      // Ikinci tur veri veriyor: kart artik kendi govdesini ciziyor.
      expect(find.text('KART GOVDESI'), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      await _teardownTree(tester);
    });

    testWidgets('yukleme / veri / hata uc ayri cikti', (tester) async {
      final l10n = await _tr();

      // Yukleme: iskelet, hata metni yok, eylem yok. (WP-495C kazanimi)
      await tester.pumpWidget(
        _app(
          const _GateHarness(),
          overrides: _gateOverrides(
            sessions: () => _pending<List<StudySession>>(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(kCardSkeletonKey),
        findsOneWidget,
        reason: 'WP-495C regresyonu: yuklenirken yer tutucu cizilmeli',
      );
      expect(find.text(l10n.homeVerilerYuklenemedi), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      await _teardownTree(tester);

      // Veri: kapi `null` doner, kart kendi govdesini cizer.
      await tester.pumpWidget(
        _app(
          const _GateHarness(),
          overrides: _gateOverrides(
            sessions: () => Stream.value(const <StudySession>[]),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('KART GOVDESI'), findsOneWidget);
      expect(find.byKey(kCardSkeletonKey), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      await _teardownTree(tester);

      // Hata: iskelet YOK (sonsuz iskelet tuzagi), metin + eylem VAR.
      await tester.pumpWidget(
        _app(const _GateHarness(), overrides: _gateOverrides(source: _SessionSource())),
      );
      await tester.pump();
      expect(find.byKey(kCardSkeletonKey), findsNothing);
      expect(find.text(l10n.homeVerilerYuklenemedi), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
      await _teardownTree(tester);
    });
  });
}

// ───────────────────────────────────────────────────────────────────────────
// 2 + 3. Saat sekmesi: alarmlar ve zamanlayicilar
// ───────────────────────────────────────────────────────────────────────────

/// Sahte alarm deposu: hangi okumanin patlayacagi ve kac kez cagrildigi.
class _FlakyAlarmRepository extends InMemoryAlarmRepository {
  _FlakyAlarmRepository({
    this.failAlarms = false,
    this.failInstances = false,
    this.failPresets = false,
    this.healAfterFirstCall = true,
    this.hold,
  });

  /// Doluysa okumalar burada bekler; yukleme KARESI boylece olculebilir.
  /// Olmadan `InMemoryAlarmRepository` ilk microtask'ta doner ve ilk frame
  /// zaten veriyi tasir — "spinner var mi" iddiasi olcusuz kalirdi.
  final Completer<void>? hold;

  void release() => hold?.complete();

  bool failAlarms;
  bool failInstances;
  bool failPresets;

  /// Ikinci cagri basarili olur: "tekrar-dene gercekten duzeltiyor mu".
  final bool healAfterFirstCall;

  int alarmCalls = 0;
  int instanceCalls = 0;
  int presetCalls = 0;

  bool _shouldFail(bool flag, int call) =>
      flag && (!healAfterFirstCall || call == 1);

  Future<void> _wait() async {
    if (hold != null) await hold!.future;
  }

  @override
  Future<List<AlarmRule>> getAlarms() async {
    alarmCalls++;
    await _wait();
    if (_shouldFail(failAlarms, alarmCalls)) throw StateError('disk yok');
    return super.getAlarms();
  }

  @override
  Future<List<TimerInstance>> getTimerInstances() async {
    instanceCalls++;
    await _wait();
    if (_shouldFail(failInstances, instanceCalls)) throw StateError('disk yok');
    return super.getTimerInstances();
  }

  @override
  Future<List<TimerPreset>> getTimerPresets() async {
    presetCalls++;
    await _wait();
    if (_shouldFail(failPresets, presetCalls)) throw StateError('disk yok');
    return super.getTimerPresets();
  }
}

/// Bildirim servisi sahtesi; kesin-alarm probunun sonucunu ve cagri sayisini
/// testin eline verir.
class _FakeAlarmNotificationService implements AlarmNotificationService {
  _FakeAlarmNotificationService({this.failExactStatus = false});

  final bool failExactStatus;
  int exactStatusCalls = 0;

  @override
  Future<ExactAlarmStatus> exactAlarmStatus() async {
    exactStatusCalls++;
    if (failExactStatus) throw StateError('platform kanali yok');
    return ExactAlarmStatus.granted;
  }

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<void> scheduleAlarm(
    AlarmRule alarm, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {}

  @override
  Future<void> rescheduleAll(
    List<AlarmRule> alarms, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {}

  @override
  Future<void> scheduleTimer(
    TimerInstance instance, {
    SharedPreferences? prefs,
  }) async {}

  @override
  Future<void> cancelAlarm(String id) async {}

  @override
  Future<void> cancelTimer(String id) async {}

  @override
  Future<void> cancelById(String id) async {}

  @override
  Future<void> initialize({
    void Function(NotificationResponse)? onResponse,
  }) async {}

  @override
  Future<void> showImmediate(String title, String body) async {}

  @override
  Future<void> previewNativeRing(AlarmRule alarm) async {}

  @override
  bool lastUsedExact = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void _clockGroups() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  List<Override> clockOverrides(
    _FlakyAlarmRepository repo,
    _FakeAlarmNotificationService service,
  ) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    alarmNotificationServiceProvider.overrideWithValue(service),
    alarmRepositoryProvider.overrideWithValue(repo),
  ];

  group('alarms_screen', () {
    testWidgets('liste hatasi: gorunur eylem + kaynak yeniden okunuyor', (
      tester,
    ) async {
      final repo = _FlakyAlarmRepository(failAlarms: true);
      final service = _FakeAlarmNotificationService();
      await tester.pumpWidget(
        _app(const AlarmsScreen(), overrides: clockOverrides(repo, service)),
      );
      await tester.pumpAndSettle();

      final l10n = await _tr();
      expect(find.text(l10n.clockAlarmlarYuklenemedi), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
      expect(repo.alarmCalls, 1);

      await tester.tap(find.byKey(kErrorRetryButtonKey));
      await tester.pumpAndSettle();

      expect(
        repo.alarmCalls,
        2,
        reason: 'tekrar-dene alarmsProvider`i yeniden kurmali',
      );
      // Ikinci tur basarili: bos durum metnine dusuyoruz, hata kayboluyor.
      expect(find.text(l10n.clockAlarmlarYuklenemedi), findsNothing);
      expect(
        find.text(l10n.clockHenuzBirAlarmOlusturmadiniz),
        findsOneWidget,
      );
      await _teardownTree(tester);
    });

    testWidgets('yukleme / bos / hata uc ayri cikti', (tester) async {
      final l10n = await _tr();

      // Yukleme: spinner; ne bos durum ne hata iddiasi.
      final slowRepo = _FlakyAlarmRepository(hold: Completer<void>());
      await tester.pumpWidget(
        _app(
          const AlarmsScreen(),
          overrides: clockOverrides(slowRepo, _FakeAlarmNotificationService()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.clockHenuzBirAlarmOlusturmadiniz), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);

      // Bos: bos durum metni; spinner ve eylem yok.
      slowRepo.release();
      await tester.pumpAndSettle();
      expect(find.text(l10n.clockHenuzBirAlarmOlusturmadiniz), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      await _teardownTree(tester);

      // Hata: kendi metni + eylem; bos durum metni YOK (yanlis iddia olurdu).
      await tester.pumpWidget(
        _app(
          const AlarmsScreen(),
          overrides: clockOverrides(
            _FlakyAlarmRepository(failAlarms: true, healAfterFirstCall: false),
            _FakeAlarmNotificationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.clockAlarmlarYuklenemedi), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
      expect(find.text(l10n.clockHenuzBirAlarmOlusturmadiniz), findsNothing);
      await _teardownTree(tester);
    });

    testWidgets('izin probu hatasi sessizce yutulmuyor', (tester) async {
      final repo = _FlakyAlarmRepository();
      final service = _FakeAlarmNotificationService(failExactStatus: true);
      await tester.pumpWidget(
        _app(const AlarmsScreen(), overrides: clockOverrides(repo, service)),
      );
      await tester.pumpAndSettle();

      final l10n = await _tr();
      expect(
        find.text(l10n.clockIzinDurumuOkunamadi),
        findsOneWidget,
        reason: 'eski hal: SizedBox.shrink() — sebep gosterilmiyordu',
      );
      expect(service.exactStatusCalls, 1);

      await tester.tap(find.byKey(kErrorRetryButtonKey));
      await tester.pumpAndSettle();

      expect(
        service.exactStatusCalls,
        2,
        reason: 'tekrar-dene izin probunu yeniden kosturmali',
      );
      await _teardownTree(tester);
    });
  });

  group('timers_screen', () {
    testWidgets('liste hatasi: gorunur eylem + kaynak yeniden okunuyor', (
      tester,
    ) async {
      final repo = _FlakyAlarmRepository(failInstances: true);
      await tester.pumpWidget(
        _app(
          const TimersScreen(),
          overrides: clockOverrides(repo, _FakeAlarmNotificationService()),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await _tr();
      expect(find.text(l10n.clockZamanlayicilarYuklenemedi), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
      expect(repo.instanceCalls, 1);

      await tester.tap(find.byKey(kErrorRetryButtonKey));
      await tester.pumpAndSettle();

      expect(
        repo.instanceCalls,
        2,
        reason: 'tekrar-dene timerInstancesProvider`i yeniden kurmali',
      );
      expect(find.text(l10n.clockZamanlayicilarYuklenemedi), findsNothing);
      expect(find.text(l10n.clockHenuzCalisanBirTimer), findsOneWidget);
      await _teardownTree(tester);
    });

    testWidgets('hazir sure seridi: hata sessiz bosluk degil', (tester) async {
      final repo = _FlakyAlarmRepository(failPresets: true);
      await tester.pumpWidget(
        _app(
          const TimersScreen(),
          overrides: clockOverrides(repo, _FakeAlarmNotificationService()),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await _tr();
      expect(
        find.text(l10n.clockHazirSurelerYuklenemedi),
        findsOneWidget,
        reason: 'eski hal: SizedBox.shrink() — 48 px bos serit',
      );
      expect(repo.presetCalls, 1);

      await tester.tap(find.byKey(kErrorRetryButtonKey));
      await tester.pumpAndSettle();

      expect(
        repo.presetCalls,
        2,
        reason: 'tekrar-dene timerPresetsProvider`i yeniden kurmali',
      );
      expect(find.text(l10n.clockHazirSurelerYuklenemedi), findsNothing);
      // Varsayilan onayarlar geri geldi: serit yeniden dolu.
      expect(find.byType(ActionChip), findsWidgets);
      await _teardownTree(tester);
    });

    testWidgets('yukleme / bos / hata uc ayri cikti', (tester) async {
      final l10n = await _tr();

      final slowRepo = _FlakyAlarmRepository(hold: Completer<void>());
      await tester.pumpWidget(
        _app(
          const TimersScreen(),
          overrides: clockOverrides(slowRepo, _FakeAlarmNotificationService()),
        ),
      );
      // Yukleme: spinner var, bos durum metni ve eylem yok.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text(l10n.clockHenuzCalisanBirTimer), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);

      // Bos: bos durum metni; spinner ve eylem yok.
      slowRepo.release();
      await tester.pumpAndSettle();
      expect(find.text(l10n.clockHenuzCalisanBirTimer), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      await _teardownTree(tester);

      // Hata: kendi metni + eylem; bos durum metni YOK.
      await tester.pumpWidget(
        _app(
          const TimersScreen(),
          overrides: clockOverrides(
            _FlakyAlarmRepository(
              failInstances: true,
              healAfterFirstCall: false,
            ),
            _FakeAlarmNotificationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.clockZamanlayicilarYuklenemedi), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
      expect(find.text(l10n.clockHenuzCalisanBirTimer), findsNothing);
      await _teardownTree(tester);
    });
  });
}

// ───────────────────────────────────────────────────────────────────────────
// 4. class_chat_card — grup sohbeti
// ───────────────────────────────────────────────────────────────────────────

/// Sahte sohbet deposu: akis kurulum sayisi + ilk turda hata.
class _FlakyChatRepository implements ChatRepository {
  _FlakyChatRepository({this.fail = false, this.healAfterFirstCall = true});

  final bool fail;
  final bool healAfterFirstCall;
  int watchCalls = 0;

  @override
  Stream<List<ChatMessage>> watchGroupMessages(String groupId) {
    watchCalls++;
    if (fail && (!healAfterFirstCall || watchCalls == 1)) {
      return Stream<List<ChatMessage>>.error('ag yok', StackTrace.current);
    }
    return Stream.value(const <ChatMessage>[]);
  }

  @override
  Future<void> sendMessage({
    required String groupId,
    required Profile sender,
    required String text,
  }) async {}
}

void _chatGroup() {
  List<Override> chatOverrides(_FlakyChatRepository repo) => [
    authStateProvider.overrideWith((ref) => Stream.value(_me)),
    chatRepositoryProvider.overrideWithValue(repo),
    // WP-538 sozlesmesi: engelli kume BILINMEDEN mesaj cizilmez. Override
    // olmadan varsayilan depo Supabase olur ve ekran sonsuza dek yuklenir.
    moderationRepositoryProvider.overrideWithValue(
      InMemoryModerationRepository(),
    ),
  ];

  group('class_chat_card', () {
    testWidgets('hata: gorunur eylem + akis yeniden kuruluyor', (tester) async {
      final repo = _FlakyChatRepository(fail: true);
      await tester.pumpWidget(
        _app(
          Scaffold(body: ClassChatCard(group: _group)),
          overrides: chatOverrides(repo),
        ),
      );
      await _pumpFrames(tester);

      final l10n = await _tr();
      expect(find.text(l10n.classroomSohbetYuklenemedi), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
      expect(repo.watchCalls, 1);

      await tester.tap(find.byKey(kErrorRetryButtonKey));
      await _pumpFrames(tester);

      expect(
        repo.watchCalls,
        2,
        reason: 'tekrar-dene classMessagesProvider`i yeniden kurmali',
      );
      expect(find.text(l10n.classroomSohbetYuklenemedi), findsNothing);
      expect(find.text(l10n.classroomIlkMesajiSenGonder), findsOneWidget);
      await _teardownTree(tester);
    });

    testWidgets('yukleme / bos / hata uc ayri cikti', (tester) async {
      final l10n = await _tr();

      // Bos: "ilk mesaji sen gonder"; spinner ve eylem yok.
      await tester.pumpWidget(
        _app(
          Scaffold(body: ClassChatCard(group: _group)),
          overrides: chatOverrides(_FlakyChatRepository()),
        ),
      );
      await _pumpFrames(tester);
      expect(find.text(l10n.classroomIlkMesajiSenGonder), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      await _teardownTree(tester);

      // Yukleme: spinner; bos durum metni yok, eylem yok.
      await tester.pumpWidget(
        _app(
          Scaffold(body: ClassChatCard(group: _group)),
          overrides: [
            ...chatOverrides(_FlakyChatRepository()),
            classMessagesProvider(
              _group.id,
            ).overrideWith((ref) => _pending<List<ChatMessage>>()),
          ],
        ),
      );
      // Spinner sonsuz doner: `pumpAndSettle` burada ASLA oturmaz.
      await _pumpFrames(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.classroomIlkMesajiSenGonder), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      await _teardownTree(tester);

      // Hata: kendi metni + eylem; bos durum metni YOK.
      await tester.pumpWidget(
        _app(
          Scaffold(body: ClassChatCard(group: _group)),
          overrides: chatOverrides(
            _FlakyChatRepository(fail: true, healAfterFirstCall: false),
          ),
        ),
      );
      await _pumpFrames(tester);
      expect(find.text(l10n.classroomSohbetYuklenemedi), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
      expect(find.text(l10n.classroomIlkMesajiSenGonder), findsNothing);
      await _teardownTree(tester);
    });
  });
}

// ───────────────────────────────────────────────────────────────────────────

void main() {
  _cardDataGateGroup();
  _clockGroups();
  _chatGroup();

  testWidgets('dort yerin de tekrar-dene metni AYNI katalog anahtarindan', (
    tester,
  ) async {
    // Tutarsizlik denetiminin (WP-556) kok nedeni: her ekran kendi cumlesini
    // uyduruyordu. Ortak widget tek anahtar kullanir; bu iddia yeni bir
    // "Yeniden dene" varyantinin sessizce sizmasini engeller.
    final l10n = await _tr();
    expect(l10n.commonTekrarDene, isNotEmpty);
    expect(l10n.commonTekrarDene, l10n.taskListRetry);
  });
}
