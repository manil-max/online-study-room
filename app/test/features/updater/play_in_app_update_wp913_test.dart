import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/features/updater/play_in_app_update.dart';

/// WP-913 — Play in-app update kapısı ve akışı.
///
/// Testler gerçek `InAppUpdate` eklentisine **hiç** dokunmaz: tek giriş
/// [PlayInAppUpdateGateway] ve o da provider'dan ezilir. Cihaz gerekmez.
void main() {
  setUp(debugResetPlayInAppUpdateCheck);

  tearDown(() {
    debugResetPlayInAppUpdateCheck();
    debugPlayInAppUpdateChannel = null;
    debugPlayInAppUpdatePlatform = null;
  });

  group('kapı', () {
    test('yalnız Play + Android; diğer her kanalda eklenti çağrılmaz', () async {
      for (final channel in DistributionChannel.values) {
        final gateway = _FakeGateway();
        final outcome = await runPlayInAppUpdate(
          gateway: gateway,
          channel: channel,
          platform: TargetPlatform.android,
        );
        if (channel == DistributionChannel.play) {
          expect(outcome, PlayUpdateOutcome.downloaded, reason: '$channel');
          expect(gateway.checks, 1, reason: '$channel');
        } else {
          expect(outcome, PlayUpdateOutcome.notApplicable, reason: '$channel');
          expect(
            gateway.touched,
            isFalse,
            reason: '$channel kanalında eklentiye dokunulmamalı',
          );
        }
      }
    });

    test('Play kanalı bile olsa iOS / Windows / web hiç çağırmaz', () async {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        final gateway = _FakeGateway();
        expect(
          await runPlayInAppUpdate(
            gateway: gateway,
            channel: DistributionChannel.play,
            platform: platform,
          ),
          PlayUpdateOutcome.notApplicable,
          reason: '$platform',
        );
        expect(gateway.touched, isFalse, reason: '$platform');
      }

      final webGateway = _FakeGateway();
      expect(
        await runPlayInAppUpdate(
          gateway: webGateway,
          channel: DistributionChannel.play,
          isWeb: true,
        ),
        PlayUpdateOutcome.notApplicable,
      );
      expect(webGateway.touched, isFalse);
    });
  });

  group('esnek akış', () {
    test('indirme hazır demeden kurulum çağrılmaz', () async {
      final gateway = _FakeGateway(downloaded: false);
      expect(
        await runPlayInAppUpdate(
          gateway: gateway,
          channel: DistributionChannel.play,
        ),
        PlayUpdateOutcome.declined,
      );
      expect(gateway.starts, 1);
      expect(gateway.completes, 0, reason: 'indirme bitmeden kurulum yok');
    });

    // 🔴 WP-914: kurulum indirme biter bitmez ÇAĞRILMAZ. Play kurarken
    // uygulamayı yeniden başlatır; bu bir çalışma sayacı, koşan seansın
    // ortasında yeniden başlamak kabul edilemez. Kurulumu kullanıcı başlatır.
    test('indirme bitince kurulum KENDILIGINDEN cagrilmaz', () async {
      final gateway = _FakeGateway();
      expect(
        await runPlayInAppUpdate(
          gateway: gateway,
          channel: DistributionChannel.play,
        ),
        PlayUpdateOutcome.downloaded,
      );
      expect(gateway.starts, 1);
      expect(gateway.completes, 0, reason: 'kurulum kullanıcı onayı bekler');
    });

    test('completePlayUpdate kurulumu cagirir ve hatayi yutar', () async {
      final ok = _FakeGateway();
      await completePlayUpdate(ok);
      expect(ok.completes, 1);

      final broken = _FakeGateway(throwOn: _Step.complete);
      await expectLater(completePlayUpdate(broken), completes);
      expect(broken.completes, 1);
    });

    test('güncelleme yoksa indirme başlatılmaz', () async {
      final gateway = _FakeGateway(
        snapshot: const PlayUpdateSnapshot(
          updateAvailable: false,
          flexibleAllowed: true,
        ),
      );
      expect(
        await runPlayInAppUpdate(
          gateway: gateway,
          channel: DistributionChannel.play,
        ),
        PlayUpdateOutcome.noUpdate,
      );
      expect(gateway.starts, 0);
      expect(gateway.completes, 0);
    });

    test('esnek akış serbest değilse indirme başlatılmaz', () async {
      final gateway = _FakeGateway(
        snapshot: const PlayUpdateSnapshot(
          updateAvailable: true,
          flexibleAllowed: false,
        ),
      );
      expect(
        await runPlayInAppUpdate(
          gateway: gateway,
          channel: DistributionChannel.play,
        ),
        PlayUpdateOutcome.notAllowed,
      );
      expect(gateway.starts, 0);
    });

    test('eklenti hatası yutulur, yeniden fırlatılmaz', () async {
      // WP-914: `complete` artık bu akışta çağrılmıyor; kurulum hatası
      // `completePlayUpdate` testinde ölçülür.
      for (final gateway in [
        _FakeGateway(throwOn: _Step.check),
        _FakeGateway(throwOn: _Step.start),
      ]) {
        expect(
          await runPlayInAppUpdate(
            gateway: gateway,
            channel: DistributionChannel.play,
          ),
          PlayUpdateOutcome.failed,
        );
      }
    });
  });

  group('kabuk provider', () {
    testWidgets('Play dışı kanalda provider eklentiye dokunmaz', (
      tester,
    ) async {
      debugPlayInAppUpdatePlatform = TargetPlatform.android;
      debugPlayInAppUpdateChannel = DistributionChannel.githubBeta;
      final gateway = _FakeGateway();

      await tester.pumpWidget(_host(gateway));
      await tester.pumpAndSettle();

      expect(find.text('kabuk'), findsOneWidget);
      expect(gateway.touched, isFalse);
    });

    testWidgets('eklenti hata atsa da kabuk kurulur', (tester) async {
      debugPlayInAppUpdatePlatform = TargetPlatform.android;
      debugPlayInAppUpdateChannel = DistributionChannel.play;
      final gateway = _FakeGateway(throwOn: _Step.check);

      await tester.pumpWidget(_host(gateway));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('kabuk'), findsOneWidget);
      expect(gateway.checks, 1);
    });

    test('indirme bittiğinde kurulum şeridi açılır (kurulum yok)', () async {
      debugPlayInAppUpdatePlatform = TargetPlatform.android;
      debugPlayInAppUpdateChannel = DistributionChannel.play;
      final gateway = _FakeGateway();
      final container = ProviderContainer(
        overrides: [playInAppUpdateGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      expect(container.read(playUpdateRestartHintProvider), isFalse);
      container.read(playInAppUpdateProvider);
      await pumpEventQueue();

      expect(gateway.completes, 0, reason: 'şerit çıkar, kurulum beklenir');
      expect(container.read(playUpdateRestartHintProvider), isTrue);
    });

    test('aynı süreçte ikinci kontrol yapılmaz', () async {
      debugPlayInAppUpdatePlatform = TargetPlatform.android;
      debugPlayInAppUpdateChannel = DistributionChannel.play;
      final gateway = _FakeGateway();

      for (var i = 0; i < 2; i++) {
        final container = ProviderContainer(
          overrides: [
            playInAppUpdateGatewayProvider.overrideWithValue(gateway),
          ],
        );
        container.read(playInAppUpdateProvider);
        await pumpEventQueue();
        container.dispose();
      }

      expect(gateway.checks, 1, reason: 'süreç başına tek kontrol');
    });
  });
}

Widget _host(_FakeGateway gateway) {
  return ProviderScope(
    overrides: [playInAppUpdateGatewayProvider.overrideWithValue(gateway)],
    child: const MaterialApp(home: _Host()),
  );
}

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playInAppUpdateProvider);
    return const Scaffold(body: Text('kabuk'));
  }
}

enum _Step { check, start, complete }

class _FakeGateway implements PlayInAppUpdateGateway {
  _FakeGateway({
    this.snapshot = const PlayUpdateSnapshot(
      updateAvailable: true,
      flexibleAllowed: true,
    ),
    this.downloaded = true,
    this.throwOn,
  });

  final PlayUpdateSnapshot snapshot;
  final bool downloaded;
  final _Step? throwOn;

  int checks = 0;
  int starts = 0;
  int completes = 0;

  bool get touched => checks + starts + completes > 0;

  @override
  Future<PlayUpdateSnapshot> checkForUpdate() async {
    checks++;
    if (throwOn == _Step.check) throw StateError('Play Services yok');
    return snapshot;
  }

  @override
  Future<bool> startFlexibleUpdate() async {
    starts++;
    if (throwOn == _Step.start) throw StateError('indirme başlatılamadı');
    return downloaded;
  }

  @override
  Future<void> completeFlexibleUpdate() async {
    completes++;
    if (throwOn == _Step.complete) throw StateError('kurulum başarısız');
  }
}
