import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/classroom/widgets/focus_timer_screen.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-598 — YÜZEY KABLOSU: düğmeden korkuluğa, korkuluktan ekrandaki cümleye.
///
/// Sağlayıcı katmanının iki yönlü iddiaları
/// `test/data/timer_accidental_restart_wp598_test.dart` içinde. Buradaki testler
/// GERÇEK notifier'ı ve GERÇEK düğmeleri kullanır: "korkuluk vardı ama düğme
/// ona uğramıyordu" hatası ancak böyle yakalanır. İki yüzey de sınanır çünkü
/// olay gecesinde kullanılabilecek iki ayrı Başlat düğmesi vardı.
class _FakeClock {
  _FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

class _NoopTimerNotificationService implements TimerNotificationGateway {
  const _NoopTimerNotificationService();

  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}
}

class _NoopAndroidWidgetService implements AndroidWidgetGateway {
  const _NoopAndroidWidgetService();

  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {}

  @override
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot) async {}

  @override
  Future<void> seedPlaceholder() async {}
}

const _kRestartNotice =
    'Az önce durdurdun; sayaç yeniden başlatılmadı. '
    'Yeni bir oturum başlatmak istiyorsan tekrar dokun.';
const _kBackgroundHint =
    'Sayaç arka planda çalışır: uygulamayı kapatsan da durmaz, '
    'süre işlemeye devam eder. Bitirince Durdur\'a bas.';

Future<ProviderContainer> _container(
  _FakeClock clock, {
  Map<String, Object> prefsSeed = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(prefsSeed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      studyTimerClockProvider.overrideWithValue(clock.call),
      timerNotificationServiceProvider.overrideWithValue(
        const _NoopTimerNotificationService(),
      ),
      androidWidgetServiceProvider.overrideWithValue(
        const _NoopAndroidWidgetService(),
      ),
      userSessionsProvider.overrideWith(
        (_) => Stream.value(const <StudySession>[]),
      ),
      userSubjectsProvider.overrideWith((_) => Stream.value(const <Subject>[])),
      dailyGoalMinutesProvider.overrideWithValue(240),
      userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
    ],
  );
  return container;
}

Future<void> _pumpSurface(
  WidgetTester tester,
  ProviderContainer container,
  Widget surface,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SizedBox(width: 380, height: 900, child: surface)),
      ),
    ),
  );
  await _settleNotices(tester);
}

/// Kare sonrası geri çağırım + SnackBar giriş animasyonu.
/// `pumpAndSettle` kullanılamaz: sayaç yüzeyleri saniyelik ticker kurar.
Future<void> _settleNotices(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Ekrandaki SnackBar'ı **belirlenimli** olarak kaldırır.
///
/// Süresinin dolmasını beklemek burada işe yaramıyor: sayaç yüzeyi saniyelik
/// ticker'ını kurduğu için "kaç kare pump edeyim" sorusu testi zamana bağlardı.
Future<void> _dismissSnackBar(WidgetTester tester) async {
  final finder = find.byType(SnackBar);
  if (finder.evaluate().isEmpty) return;
  ScaffoldMessenger.of(
    tester.element(find.byType(Scaffold).first),
  ).removeCurrentSnackBar();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// GERÇEK notifier `build()` içinde periyodik zamanlayıcılar kurar
/// (`_startGlobalTimerForegroundRefresh` vb.). `addTearDown` çok geç kalıyor:
/// flutter_test "bekleyen Timer" denetimini test GÖVDESİ biter bitmez yapar.
/// Bu yüzden ağacı söküp konteyneri gövde içinde kapatıyoruz.
Future<void> _teardown(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final surface in <String, Widget Function()>{
    'sayaç kartı': () => const StudyTimerCard(),
    'tam ekran odak': () => const FocusTimerScreen(),
  }.entries) {
    testWidgets(
      '${surface.key}: durdurduktan 3 sn sonra Başlat koşu AÇMAZ ve söyler',
      (tester) async {
        final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 40, 24));
        // H2 açıklaması bu testin konusu değil; bayrağı yazılı başlat.
        final container = await _container(
          clock,
          prefsSeed: const {'timer_background_hint_seen': true},
        );
        final notifier = container.read(studyTimerProvider.notifier);

        notifier.start();
        await notifier.stop();
        clock.advance(const Duration(seconds: 3));

        await _pumpSurface(tester, container, surface.value());
        expect(container.read(studyTimerProvider).isRunning, isFalse);

        // Kartta metinli düğme, odakta ikonlu dairesel düğme.
        final startButton = surface.key == 'sayaç kartı'
            ? find.text('Çalışmaya başla')
            : find.byIcon(Icons.play_arrow);
        await tester.tap(startButton);
        await _settleNotices(tester);

        expect(
          container.read(studyTimerProvider).isRunning,
          isFalse,
          reason: 'ASIL BUG: bu dokunuş 11 sa 22 dk sahte oturumu başlatmıştı',
        );
        expect(
          find.text(_kRestartNotice),
          findsOneWidget,
          reason: 'sessiz yutma yasak: kullanıcı "düğme bozuk" dememeli',
        );

        // İkinci dokunuş bilinçlidir → başlatır.
        await tester.tap(startButton);
        await _settleNotices(tester);
        expect(
          container.read(studyTimerProvider).isRunning,
          isTrue,
          reason: 'koruma kilit değil, onaydır',
        );
        await _dismissSnackBar(tester);
        await _teardown(tester, container);
      },
    );

    testWidgets('${surface.key}: OLUMSUZ — 5 dk sonra tek dokunuş başlatır', (
      tester,
    ) async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 40, 24));
      final container = await _container(
        clock,
        prefsSeed: const {'timer_background_hint_seen': true},
      );
      final notifier = container.read(studyTimerProvider.notifier);

      notifier.start();
      await notifier.stop();
      clock.advance(const Duration(minutes: 5));

      await _pumpSurface(tester, container, surface.value());
      await tester.tap(
        surface.key == 'sayaç kartı'
            ? find.text('Çalışmaya başla')
            : find.byIcon(Icons.play_arrow),
      );
      await _settleNotices(tester);

      expect(
        container.read(studyTimerProvider).isRunning,
        isTrue,
        reason: 'meşru yeni oturum ikinci dokunuş istememeli',
      );
      expect(
        find.text(_kRestartNotice),
        findsNothing,
        reason: 'gereksiz uyarı kullanıcıyı kilitli hissettirir',
      );
      await _dismissSnackBar(tester);
      await _teardown(tester, container);
    });
  }

  testWidgets(
    'H2: ilk kez başlatan kullanıcı "uygulamayı kapatsan da durmaz" cümlesini görür',
    (tester) async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 0));
      final container = await _container(clock);

      await _pumpSurface(tester, container, const StudyTimerCard());
      expect(find.text(_kBackgroundHint), findsNothing);

      await tester.tap(find.text('Çalışmaya başla'));
      await _settleNotices(tester);

      expect(container.read(studyTimerProvider).isRunning, isTrue);
      expect(find.text(_kBackgroundHint), findsOneWidget);
      await _dismissSnackBar(tester);
      await _teardown(tester, container);
    },
  );

  testWidgets(
    'H2: sayaç uygulama kapalıyken başladıysa açıklama açılışta gösterilir',
    (tester) async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 0));
      final container = await _container(clock);

      // Widget/bildirim yolundan başlatma: yüzey henüz takılı değil.
      container
          .read(studyTimerProvider.notifier)
          .start(guardAccidentalRestart: false);
      expect(container.read(timerBackgroundHintNoticeProvider), isTrue);

      await _pumpSurface(tester, container, const StudyTimerCard());

      expect(
        find.text(_kBackgroundHint),
        findsOneWidget,
        reason: 'sinyal biz takılmadan önce yanmıştı; kaybolmamalı',
      );
      await _dismissSnackBar(tester);
      await _teardown(tester, container);
    },
  );

  testWidgets('H2: açıklama ömürde bir kez gösterilir', (tester) async {
    final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 0));
    final container = await _container(clock);

    await _pumpSurface(tester, container, const StudyTimerCard());
    await tester.tap(find.text('Çalışmaya başla'));
    await _settleNotices(tester);
    expect(find.text(_kBackgroundHint), findsOneWidget);
    await _dismissSnackBar(tester);

    await container.read(studyTimerProvider.notifier).stop();
    clock.advance(const Duration(minutes: 30));
    await _settleNotices(tester);
    await tester.tap(find.text('Çalışmaya başla'));
    await _settleNotices(tester);

    expect(
      find.text(_kBackgroundHint),
      findsNothing,
      reason: 'her başlatmada bağıran uyarı değil, bir kez öğreten açıklama',
    );
    await _dismissSnackBar(tester);
    await _teardown(tester, container);
  });
}
