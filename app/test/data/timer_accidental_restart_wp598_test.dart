import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

/// WP-598 (H1): "durdurdum sandım, aslında yeniden başlattım" korkuluğu.
///
/// 🔴 Ölçülen olay (`docs/analiz/WP-595-sayac-xp-teshis.md` §1): kullanıcı
/// 22:40:24'te durdurdu, **3 sn sonra** yeniden başlattı, uygulamayı bıraktı;
/// sabah 10:02'de 11 sa 22 dk "çalışma" kaydedildi ve XP geri alınamadı.
///
/// İddialar **iki yönlüdür**: pencere içinde koruma tetiklenmeli, pencere
/// dışında **hiç** tetiklenmemeli. Tek yönlü ölçüm "her Başlat'ı engelle"
/// sabotajını yeşil geçirirdi.
///
/// Zaman **enjekte** edilir ([studyTimerClockProvider]); hiçbir iddia gerçek
/// saate bakmaz — bu repoda gece yarısı flake'i iki kez sürüm koşumunu kırdı.
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
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // studyTimerProvider.build() bir AppLifecycleListener kurar → binding şart.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('startNeedsRestartConfirmation (saf karar)', () {
    final stoppedAt = DateTime.utc(2026, 8, 8, 19, 40, 24);

    test('gerçek olay: durdurmadan 3 sn sonra Başlat → onay ister', () {
      expect(
        startNeedsRestartConfirmation(
          lastStoppedAt: stoppedAt,
          now: stoppedAt.add(const Duration(seconds: 3)),
        ),
        isTrue,
      );
    });

    test('günlükteki üç vakanın üçü de pencere içinde (6 sn / 1 sn / 3 sn)', () {
      for (final gap in const [
        Duration(seconds: 6),
        Duration(seconds: 1),
        Duration(seconds: 3),
      ]) {
        expect(
          startNeedsRestartConfirmation(
            lastStoppedAt: stoppedAt,
            now: stoppedAt.add(gap),
          ),
          isTrue,
          reason: '$gap sonra gelen Başlat onaysız geçmemeli',
        );
      }
    });

    test('pencere sınırı: 9 sn 999 ms ister, tam 10 sn istemez', () {
      expect(
        startNeedsRestartConfirmation(
          lastStoppedAt: stoppedAt,
          now: stoppedAt.add(
            kAccidentalRestartCooldown - const Duration(milliseconds: 1),
          ),
        ),
        isTrue,
      );
      expect(
        startNeedsRestartConfirmation(
          lastStoppedAt: stoppedAt,
          now: stoppedAt.add(kAccidentalRestartCooldown),
        ),
        isFalse,
      );
    });

    test('meşru kullanım: 5 dk sonra yeni oturum onay İSTEMEZ', () {
      expect(
        startNeedsRestartConfirmation(
          lastStoppedAt: stoppedAt,
          now: stoppedAt.add(const Duration(minutes: 5)),
        ),
        isFalse,
      );
    });

    test('hiç durdurulmamışsa (ilk başlatma) onay istemez', () {
      expect(
        startNeedsRestartConfirmation(
          lastStoppedAt: null,
          now: stoppedAt.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('saat geriye gittiyse onay istemez (WP-542 ile karıştırma)', () {
      expect(
        startNeedsRestartConfirmation(
          lastStoppedAt: stoppedAt,
          now: stoppedAt.subtract(const Duration(hours: 2)),
        ),
        isFalse,
      );
    });
  });

  group('StudyTimerNotifier.start kaza korkuluğu', () {
    test('durdurmadan 3 sn sonra Başlat KOŞU AÇMAZ ve kullanıcıya söyler', () async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 40, 24));
      final container = await _container(clock);
      final notifier = container.read(studyTimerProvider.notifier);

      notifier.start();
      expect(container.read(studyTimerProvider).isRunning, isTrue);
      await notifier.stop();
      expect(container.read(studyTimerProvider).isRunning, isFalse);

      clock.advance(const Duration(seconds: 3));
      notifier.start();

      expect(
        container.read(studyTimerProvider).isRunning,
        isFalse,
        reason: 'ASIL BUG: bu dokunuş 11 saatlik sahte oturumu başlatmıştı',
      );
      expect(
        container.read(accidentalRestartNoticeProvider),
        isTrue,
        reason: 'sessiz yutma yasak: kullanıcı neden başlamadığını görmeli',
      );
    });

    test('açıklamayı gören kullanıcının İKİNCİ dokunuşu başlatır', () async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 40, 24));
      final container = await _container(clock);
      final notifier = container.read(studyTimerProvider.notifier);

      notifier.start();
      await notifier.stop();
      clock.advance(const Duration(seconds: 2));

      notifier.start();
      expect(container.read(studyTimerProvider).isRunning, isFalse);

      // Pencere hâlâ açık ama kullanıcı bilerek ısrar ediyor.
      clock.advance(const Duration(seconds: 1));
      notifier.start();
      expect(
        container.read(studyTimerProvider).isRunning,
        isTrue,
        reason: 'koruma kilit değil, onaydır',
      );
    });

    test('OLUMSUZ: 5 dk sonra tek dokunuş başlatır, açıklama ÇIKMAZ', () async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 40, 24));
      final container = await _container(clock);
      final notifier = container.read(studyTimerProvider.notifier);

      notifier.start();
      await notifier.stop();
      clock.advance(const Duration(minutes: 5));

      notifier.start();
      expect(
        container.read(studyTimerProvider).isRunning,
        isTrue,
        reason: 'meşru yeni oturum ikinci dokunuş istememeli',
      );
      expect(
        container.read(accidentalRestartNoticeProvider),
        isFalse,
        reason: 'gereksiz açıklama kullanıcıyı kilitli hissettirir',
      );
    });

    test('her durdurma kendi penceresini açar (onay taşınmaz)', () async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 40, 24));
      final container = await _container(clock);
      final notifier = container.read(studyTimerProvider.notifier);

      notifier.start();
      await notifier.stop();
      clock.advance(const Duration(seconds: 3));
      notifier.start(); // reddedildi → onay hazırlandı
      expect(container.read(studyTimerProvider).isRunning, isFalse);
      notifier.start(); // onaylandı → çalışıyor
      expect(container.read(studyTimerProvider).isRunning, isTrue);

      await notifier.stop();
      clock.advance(const Duration(seconds: 3));
      notifier.start();
      expect(
        container.read(studyTimerProvider).isRunning,
        isFalse,
        reason: 'önceki onay ikinci durdurmadan sonra da geçerli olamaz',
      );
    });

    test(
      'geri bildirim kanalı olmayan çağrı (bildirim/widget kuyruğu) yutulmaz',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 40, 24));
        final container = await _container(clock);
        final notifier = container.read(studyTimerProvider.notifier);

        notifier.start();
        await notifier.stop();
        clock.advance(const Duration(seconds: 3));

        notifier.start(guardAccidentalRestart: false);
        expect(
          container.read(studyTimerProvider).isRunning,
          isTrue,
          reason:
              'app kapalıyken basılan Başlat reddedilseydi düzeltmenin kendisi '
              'yeni bir sessiz yutma olurdu',
        );
        expect(container.read(accidentalRestartNoticeProvider), isFalse);
      },
    );
  });

  group('WP-598 (H2) arka plan açıklaması', () {
    test('ilk başlatmada sinyal yanar, gösterildikten sonra bir daha yanmaz',
        () async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 0));
      final container = await _container(clock);
      final notifier = container.read(studyTimerProvider.notifier);

      expect(container.read(timerBackgroundHintNoticeProvider), isFalse);
      notifier.start();
      expect(
        container.read(timerBackgroundHintNoticeProvider),
        isTrue,
        reason: '"uygulamayı kapatmak sayacı durdurmaz" hiçbir yerde yazmıyordu',
      );

      // Yüzey gösterdi → ömürlük bayrak şimdi yazılır.
      notifier.acknowledgeBackgroundHint();
      expect(container.read(timerBackgroundHintNoticeProvider), isFalse);

      await notifier.stop();
      clock.advance(const Duration(minutes: 10));
      notifier.start();
      expect(
        container.read(timerBackgroundHintNoticeProvider),
        isFalse,
        reason: 'her açılışta bağıran uyarı değil, bir kez öğreten açıklama',
      );
    });

    test('bayrak zaten yazılıysa sinyal hiç yanmaz', () async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 8, 19, 0));
      final container = await _container(
        clock,
        prefsSeed: const {'timer_background_hint_seen': true},
      );
      final notifier = container.read(studyTimerProvider.notifier);

      notifier.start();
      expect(container.read(timerBackgroundHintNoticeProvider), isFalse);
    });
  });
}
