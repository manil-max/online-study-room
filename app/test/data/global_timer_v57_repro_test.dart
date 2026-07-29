import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/background/timer_foreground_service.dart';
import 'package:online_study_room/core/background/timer_v2_command_outbox.dart';
import 'package:online_study_room/core/notifications/timer_external_command_store.dart';
import 'package:online_study_room/core/notifications/timer_sync_signal.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/global_timer.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/global_timer_providers.dart';
import 'package:online_study_room/data/repositories/global_timer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-430 — v56 saha bulgularının (V56-S01…S04) **tekrar üretim** paketi.
///
/// 🔴 Bu dosya bugünün DOĞRU davranışını değil, ölçülmüş KUSURLU davranışını
/// sabitler. Her testin başında `KIRMIZI HEDEF` satırı, WP-431…433'ün hangi
/// iddiayı ters çevirmesi gerektiğini yazar. Onarım geldiğinde bu testler
/// kırmızıya döner ve düzeltilmiş sözleşmeyle değiştirilir — silinmez.
///
/// Kanıt anlatısı: `docs/qa/V57-TIMER-EVIDENCE.md`.
const _storePath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt';
const _servicePath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt';
const _notifierPath = 'lib/data/providers/study_providers.dart';
const _syncSignalPath = 'lib/core/notifications/timer_sync_signal.dart';
const _notificationServicePath =
    'lib/core/notifications/timer_notification_service.dart';
const _migrationPath = '../supabase/migrations/0082_global_timer_v2.sql';

String _source(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

class _RecordingRepository implements GlobalTimerRepository {
  final calls = <({String action, String? runId, int? revision})>[];

  @override
  Future<GlobalTimerSnapshot> applyCommand({
    required String commandId,
    required String deviceId,
    required String action,
    String? runId,
    int? expectedRunRevision,
    DateTime? clientOccurredAt,
    Map<String, Object?> payload = const {},
  }) async {
    calls.add((action: action, runId: runId, revision: expectedRunRevision));
    return GlobalTimerSnapshot(
      stateVersion: 2,
      serverTime: DateTime.utc(2026),
      resultCode: 'applied',
    );
  }

  @override
  Future<GlobalTimerSnapshot> acknowledge({
    required String deviceId,
    required int stateVersion,
    required String status,
    String? runId,
    int? runRevision,
    String? errorCode,
  }) => throw UnimplementedError();

  @override
  Future<GlobalTimerSnapshot> fetchSnapshot({String? deviceId}) =>
      throw UnimplementedError();
}

Future<({ProviderContainer container, SharedPreferences prefs})> _harness(
  Map<String, Object> seed,
  _RecordingRepository repository,
) async {
  SharedPreferences.setMockInitialValues({
    globalTimerDeviceIdKey: 'device-mirror',
    ...seed,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith(
        (_) => Stream.value(
          Profile(
            id: 'user-1',
            displayName: 'Kullanıcı',
            createdAt: DateTime.utc(2026),
          ),
        ),
      ),
      globalTimerModeProvider.overrideWithValue(
        GlobalTimerMode.foregroundMirror,
      ),
      globalTimerRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  // Riverpod 3 auto-dispose: dinleyicisiz stream provider ilk değeri yaymadan
  // dispose olabilir; koordinatör gerçek auth snapshot'ını görmelidir.
  container.listen(authStateProvider, (_, _) {});
  await container.read(authStateProvider.future);
  return (container: container, prefs: prefs);
}

void main() {
  group('V56-S01 — ayna cihazın bildirim/widget Durdur’u sunucuya ulaşmıyor', () {
    test(
      'ayna başlatması native V2 zarfı üretmez → koşu niyeti kimliği hiç yazılmaz',
      () {
        // KIRMIZI HEDEF (WP-431): ayna cihaz da sunucunun koşu kimliğini
        // bilmeli; bildirim/widget Durdur’u onaylı bir global stop üretmeli.
        final service = _source(_servicePath);
        expect(
          service,
          contains(
            'if (mode == "stopwatch" && phase == "work" && '
            'startOrigin != "global_timer_mirror") {',
          ),
          reason:
              'ayna başlatması bilerek zarf üretmiyor; sonucu run_intent_id de '
              'yazılmamasıdır',
        );

        final store = _source(_storePath);
        // Kimliksiz stop, `run_intent_id` yoksa hiç kayıt yazamaz: fonksiyon
        // `?: return false` ile sessizce vazgeçer.
        expect(
          store,
          contains(
            'val runIntentId = p.getString(KEY_V2_RUN_INTENT_ID, null)\n'
            '            ?.takeIf { it.isNotBlank() }\n'
            '            ?: return false',
          ),
          reason:
              'ayna cihazda intent kimliği yok → terminal niyet kaydı bile '
              'oluşmaz, Durdur sessizce kaybolur',
        );
      },
    );

    test('Dart, ayna koşusunun sunucu kimliğini kanonik anahtara yazmıyor', () {
      // KIRMIZI HEDEF (WP-431): mirrorStart uygulanırken
      // `TimerV2CommandEnvelope.runIdKey` + revision da yazılmalı; aksi halde
      // native durdurma zarfı kurulamaz ve FCM hızlı yolu da eşleşemez.
      final notifier = _source(_notifierPath);
      expect(
        notifier,
        isNot(contains('setString(TimerV2CommandEnvelope.runIdKey')),
        reason:
            'kanonik koşu kimliğini yalnız sunucu apply yolu yazıyor; ayna '
            'cihaz onu asla edinmiyor',
      );
      expect(
        notifier,
        contains('await prefs.remove(TimerV2CommandEnvelope.runIdKey)'),
        reason: 'anahtar yalnız okunup silinen bir yüzey olarak kullanılıyor',
      );
    });

    test(
      'kimliksiz terminal niyeti sunucuya hiçbir komut göndermeden kuyrukta kalır',
      () async {
        // KIRMIZI HEDEF (WP-431): eş start kabulünü bekleyemeyecek bir terminal
        // niyeti (ayna cihaz) ya çözülmeli ya da açıkça `needs_reconcile`
        // durumuna düşmeli; sessizce kuyrukta beklememeli.
        final now = DateTime.now().toUtc();
        final deferredStop = {
          'kind': TimerV2CommandEnvelope.kind,
          'schema_version': TimerV2CommandEnvelope.schemaVersion,
          'command_id': 'stop-mirror',
          'account_id': 'user-1',
          'installation_id': 'installation-mirror',
          'action': 'stop',
          'client_occurred_at': now.toIso8601String(),
          'origin': 'notification',
          'run_intent_id': 'intent-mirror',
          'deferred_until_run_identity': true,
        };
        final repository = _RecordingRepository();
        final harness = await _harness({
          TimerForegroundService.pendingIntervalsKey: jsonEncode([
            deferredStop,
          ]),
        }, repository);

        await harness.container
            .read(globalTimerCoordinatorProvider)
            .flushShadow();

        expect(
          repository.calls,
          isEmpty,
          reason:
              'ayna cihazda `timer_v2_run_id` yok → durdurma sunucuya HİÇ '
              'gitmez, kaynak cihaz çalışmaya devam eder',
        );
        expect(
          harness.prefs.getString(TimerForegroundService.pendingIntervalsKey),
          jsonEncode([deferredStop]),
          reason: 'niyet kuyrukta çözülmeyi beklerken kaybolmuş görünür',
        );
      },
    );
  });

  group('V56-S02 — başlatmanın kaynağı ve yaşı bilinmiyor', () {
    test('dış komut üreticileri komutun ANINI hiç yazmıyor', () async {
      // KIRMIZI HEDEF (WP-432): her dış komut `at` (üretim anı) taşımalı ve
      // yaşı eşiği geçen komut yeni koşu doğurmamalı.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = TimerExternalCommandStore(prefs);

      await store.setCommand('start');
      final pending = store.pendingCommand;
      expect(pending, isNotNull);
      expect(pending!.command, 'start');
      expect(
        pending.at,
        isNull,
        reason:
            'komutun yaşı bilinmiyor → aylar önce kuyruğa düşmüş bir Başlat da '
            'soğuk açılışta yeni koşu doğurabilir',
      );

      // Bildirim arka plan yazıcısı da yalnız command + sequence yazar.
      final handlerSource = _source(_notificationServicePath);
      expect(
        handlerSource,
        contains("jsonEncode({'command': command, 'sequence': sequence}),"),
      );
      expect(
        handlerSource,
        isNot(contains("'at':")),
        reason: 'bildirim yazıcısı zaman damgası bırakmıyor',
      );
    });

    test('`at` yazılmadığı için app-kapalı Durdur ölü zamanı kesemiyor', () {
      // KIRMIZI HEDEF (WP-432): `stop(at:)` gerçek basma anını almalı; bugün
      // her zaman null gelir ve `DateTime.now()`a düşer.
      final notifier = _source(_notifierPath);
      expect(notifier, contains('await stop(at: pending.at);'));
      expect(
        notifier,
        contains(
          "final end = (at != null && startedAt != null && at.isAfter(startedAt))\n"
          "          ? at\n"
          "          : DateTime.now();",
        ),
        reason:
            '`at` null olduğu için oturum sonu, uygulamanın AÇILDIĞI ana '
            'kayıyor: hayalet sürenin ikinci kaynağı',
      );
    });
  });

  group('V56-S03 — arka plandaki senkron sinyali ana isolate’e ulaşmıyor', () {
    test('kaydedilen sinyal, sonradan bağlanan dinleyiciye ulaşmaz', () async {
      // KIRMIZI HEDEF (WP-432): kalıcı sinyal, uygulama/isolate açılışında
      // yeniden okunup uzlaştırılmalı.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Arka plan FCM isolate'i sinyali kaydeder.
      await TimerSyncSignal.record({
        'notification_type': 'timer_sync',
        'schema_version': '1',
        'kind': 'timer_sync',
        'run_id': 'run-remote',
        'state_version': '9',
        'run_revision': '4',
      }, eventId: 'event-1');

      expect(
        prefs.getString(TimerSyncSignal.pendingKey),
        'event-1|run-remote|9|4',
        reason: 'sinyal diske yazıldı',
      );

      // Ana isolate sonradan dinlemeye başlar (uygulama açılışı).
      final received = <TimerSyncSignal>[];
      final subscription = TimerSyncSignal.stream.listen(received.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      expect(
        received,
        isEmpty,
        reason:
            'broadcast akışı tekrar oynatmaz ve kalıcı sinyali okuyan bir API '
            'yok → uzak durdurma öğrenilmez',
      );
    });

    test('kalıcı sinyal anahtarını okuyan hiçbir tüketici yok', () {
      // KIRMIZI HEDEF (WP-432): `pendingKey` için `takePending()` benzeri bir
      // okuyucu eklenmeli ve soğuk açılışta tüketilmeli.
      final signalSource = _source(_syncSignalPath);
      // Anahtar yalnız yaz / karşılaştır / sil biçiminde kullanılıyor.
      expect(signalSource, contains('await prefs.setString(pendingKey, encoded)'));
      expect(signalSource, contains('.remove(pendingKey)'));
      expect(
        signalSource,
        isNot(contains('fromStorage')),
        reason: 'diskteki sinyali TimerSyncSignal’a çeviren bir yol yok',
      );

      final notifier = _source(_notifierPath);
      expect(
        notifier,
        isNot(contains('TimerSyncSignal.pendingKey')),
        reason:
            'tüketici (notifier) kalıcı anahtarı hiç okumuyor; yalnız '
            'TimerSyncSignal.clear() çağırıyor',
      );
    });
  });

  group('V56-S04 — sekiz saatlik hayalet ayna koşusu', () {
    test('sekiz saat önce başlamış uzak koşu sorgusuz aynalanıyor', () {
      // KIRMIZI HEDEF (WP-431): ayna benimseme yaş/kira sınırına takılmalı;
      // sınır aşılırsa koşu "uzlaştırma gerekli" olarak görünmeli.
      final startedEightHoursAgo = DateTime.now().subtract(
        const Duration(hours: 8),
      );
      final directive = planGlobalTimerForegroundApply(
        snapshot: GlobalTimerSnapshot(
          stateVersion: 12,
          serverTime: DateTime.now().toUtc(),
          run: GlobalTimerRun(
            id: 'run-ghost',
            status: 'running',
            revision: 1,
            effectiveStartedAt: startedEightHoursAgo,
          ),
        ),
        localRunning: false,
        localIsMirror: false,
        localMirrorRunId: null,
      );

      expect(
        directive.kind,
        GlobalTimerForegroundDirectiveKind.mirrorStart,
        reason:
            'koşunun yaşı hiç sorgulanmıyor: telefon sabah sekiz saatlik bir '
            'koşuyu canlıymış gibi açıyor',
      );
    });

    test('istemci modeli kira bilgisini tamamen düşürüyor', () {
      // KIRMIZI HEDEF (WP-431): `GlobalTimerRun` kira son tarihini taşımalı ve
      // kirası dolmuş koşu aynalanmamalı.
      final run = GlobalTimerRun.fromMap({
        'id': 'run-ghost',
        'status': 'running',
        'run_revision': 1,
        'effective_started_at': DateTime.now()
            .subtract(const Duration(hours: 8))
            .toIso8601String(),
        // Kira sekiz saat önce doldu; sunucu henüz süpürmediyse istemci bunu
        // göremez çünkü model alanı yok.
        'lease_expires_at': DateTime.now()
            .subtract(const Duration(hours: 8))
            .toIso8601String(),
      });

      expect(run.status, 'running');
      expect(
        GlobalTimerRun.fromMap({
          'id': 'x',
          'status': 'running',
          'run_revision': 1,
        }).effectiveStartedAt,
        isNull,
      );
      final modelSource = _source('lib/data/models/global_timer.dart');
      expect(
        modelSource,
        isNot(contains('lease_expires_at')),
        reason: 'kira alanı istemci sözleşmesinde hiç yok',
      );
    });

    test('sunucu okuma yolu da kira süzmüyor', () {
      // KIRMIZI HEDEF (WP-431/464): snapshot fonksiyonu kirası dolmuş koşuyu
      // `running` diye döndürmemeli (ya da açıkça `stale` işaretlemeli).
      final migration = _source(_migrationPath);
      final start = migration.indexOf(
        'create or replace function public._global_timer_v2_snapshot',
      );
      expect(start, greaterThan(-1));
      final body = migration.substring(
        start,
        migration.indexOf('\n\$\$;', start),
      );
      expect(body, contains("'lease_expires_at', r.lease_expires_at"));
      expect(
        body,
        isNot(contains('lease_expires_at <=')),
        reason:
            'okuma yolu kirayı yalnız RAPORLUYOR, süzmüyor: süpürücü gecikirse '
            'ölü koşu canlı görünür',
      );
    });

    test('ayna koşusunun sonu hiçbir oturum yazmaz', () {
      // KIRMIZI HEDEF (WP-431/433): ayna kapanışı ya sunucuda kesinleşmiş
      // oturumu göstermeli ya da kullanıcıya "kayıt oluşmadı" demeli; sessiz
      // kaybolmamalı.
      final notifier = _source(_notifierPath);
      final finishStart = notifier.indexOf('  void _finish({');
      expect(finishStart, greaterThan(-1));
      final finishBody = notifier.substring(
        finishStart,
        notifier.indexOf('\n  }\n', finishStart),
      );
      expect(
        finishBody,
        isNot(contains('_recordSession')),
        reason:
            '`_finish()` yalnız kapatır; ayna koşusu için oturum yazan başka '
            'bir yol da yok → görünen sekiz saat iz bırakmadan yok olur',
      );
      expect(
        finishBody,
        contains('TimerJournalOutcomes.ghostNoSession'),
        reason:
            'WP-430 en azından hayalet kapanışı makine-okunur biçimde '
            'işaretlemeli',
      );
    });
  });
}
