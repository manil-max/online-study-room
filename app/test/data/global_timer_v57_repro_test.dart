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
/// Dosya iki tür iddia taşır ve ikisi de bilerek burada durur:
///
/// * `KIRMIZI HEDEF (WP-4NN)` — hâlâ ölçülmüş **kusurlu** davranış. Sahip WP
///   onu ters çevirmek zorundadır. (Bugün: V56-S02 ve S03 → WP-432.)
/// * `WP-431 onarimi:` — WP-431'in kapattığı kusurun düzeltilmiş sözleşmesi.
///   Eski kırmızı iddia silinmedi, **ters çevrildi**; böylece regresyon aynı
///   dosyadan yakalanır.
///
/// Kural: bir onarım geldiğinde test SİLİNMEZ, iddiası değiştirilir.
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
const _controllerMigrationPath =
    '../supabase/migrations/0101_global_timer_controller_contract.sql';

String _source(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

class _RecordingRepository implements GlobalTimerRepository {
  final calls = <({String action, String? runId, int? revision})>[];
  GlobalTimerSnapshot? snapshot;

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
  Future<GlobalTimerSnapshot> fetchSnapshot({String? deviceId}) async =>
      snapshot ?? (throw StateError('snapshot not configured'));
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

    test(
      'WP-431 onarimi: ayna kosusu kanonik kimlik biletini ve rolunu edinir',
      () {
        // WP-430'da bu iddia TERSTI: kanonik anahtari yalniz sunucuya komut
        // gondermis SAHIP cihaz yaziyordu, ayna hic edinmiyordu. Kimlik olmadan
        // native durdurma zarfi kurulamiyor ve Durdur sessizce dusuyordu.
        final notifier = _source(_notifierPath);
        expect(
          notifier,
          contains(
            'await prefs.setString(TimerV2CommandEnvelope.runIdKey, run.id)',
          ),
          reason:
              'ayna da sunucunun verdigi kosu kimligini kanonik anahtara yazmali',
        );
        expect(
          notifier,
          contains('TimerControllerRole.mirror.name'),
          reason:
              'rol, native tarafin gorebilecegi bicimde store icinde olmali',
        );
      },
    );

    test(
      'WP-431 onarimi: native Durdur kararini giristen degil ROLDEN verir',
      () {
        final service = _source(_servicePath);
        expect(service, contains('val isMirror = TimerStateStore.isMirror(p)'));
        expect(
          service,
          contains('if (recordInterval && !isMirror) {'),
          reason: 'ayna projeksiyonu asla yerel oturum araligi yazmamali',
        );
        expect(
          service,
          contains(
            'if (isMirror || (mode == "stopwatch" && phase == "work")) {',
          ),
          reason:
              'ayna cihazda yerel mod/faz durdurma komutunu dusurmemeli - kosu '
              'tanimi geregi global stopwatch kosusudur',
        );
      },
    );

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
      // 🔴 İddia BİÇİME değil BAĞA bakar. Eskiden tek satırlık
      // `await stop(at: pending.at);` metni aranıyordu; WP-599 çağrıya bir
      // parametre daha ekleyip satırı böldüğü an test kırmızıya düştü — oysa
      // korunması gereken davranış (durdurma anının `pending.at`ten gelmesi)
      // hiç bozulmamıştı. Biçime bakan iddia, ilgisiz bir değişiklikte yanlış
      // kırmızı verir ve zamanla "şunu da gevşetelim" baskısı üretir.
      final stopCall = notifier.indexOf('await stop(');
      expect(stopCall, isNonNegative, reason: 'Kuyruktan Durdur çağrısı yok.');
      expect(
        notifier.substring(stopCall, stopCall + 160),
        contains('at: pending.at'),
        reason:
            'Kuyruktan gelen Durdur, basma anını `pending.at` ile almıyor: '
            'oturum sonu uygulamanın AÇILDIĞI ana kayar (hayalet süre).',
      );
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
      expect(
        signalSource,
        contains('await prefs.setString(pendingKey, encoded)'),
      );
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
    test('gorulmus snapshot eksik yerel aynayi yeniden kurar', () async {
      final serverTime = DateTime.now().toUtc();
      final repository = _RecordingRepository()
        ..snapshot = GlobalTimerSnapshot(
          userId: 'user-1',
          stateVersion: 7,
          serverTime: serverTime,
          run: GlobalTimerRun(
            id: 'run-reopen',
            status: 'running',
            revision: 2,
            effectiveStartedAt: serverTime.subtract(
              const Duration(minutes: 20),
            ),
            leaseExpiresAt: serverTime.add(const Duration(seconds: 150)),
          ),
        );
      final harness = await _harness({
        'global_timer_v2_seen_user-1_device-mirror': 7,
      }, repository);

      final directive = await harness.container
          .read(globalTimerCoordinatorProvider)
          .reconcileForeground(
            localRunning: false,
            localIsMirror: false,
            localMirrorRunId: null,
          );

      expect(
        directive?.kind,
        GlobalTimerForegroundDirectiveKind.mirrorStart,
        reason:
            'seen olay dedup bilgisi yerel projection eksigini bastirmamali',
      );
    });

    test(
      'WP-491: reconcileForeground kendi cihazinin device_id\'sini '
      'planGlobalTimerForegroundApply\'a iletir',
      () async {
        // V58-N08 / V58-N08-EK: harness'in kendi deviceId'si 'device-mirror'.
        // Sunucudaki calisan kosu AYNI deviceId'yi controller olarak
        // gosteriyorsa bu, coordinator'in gercekten kendi kimligini
        // karsilastirmaya kattigini kanitlar (onceden hic iletilmiyordu).
        final serverTime = DateTime.now().toUtc();
        final repository = _RecordingRepository()
          ..snapshot = GlobalTimerSnapshot(
            userId: 'user-1',
            stateVersion: 30,
            serverTime: serverTime,
            run: GlobalTimerRun(
              id: 'run-own-overnight',
              status: 'running',
              revision: 5,
              effectiveStartedAt: serverTime.subtract(
                const Duration(hours: 10),
              ),
              leaseExpiresAt: serverTime.add(const Duration(seconds: 150)),
              controllerDeviceId: 'device-mirror',
            ),
          );
        final harness = await _harness({}, repository);

        final directive = await harness.container
            .read(globalTimerCoordinatorProvider)
            .reconcileForeground(
              localRunning: false,
              localIsMirror: false,
              localMirrorRunId: null,
            );

        expect(
          directive?.kind,
          GlobalTimerForegroundDirectiveKind.staleOwnRunCleanup,
          reason:
              'ayni cihazin dunku kosusu ayna olarak degil, sessiz '
              'temizlik olarak isaretlenmeli',
        );
      },
    );

    test('WP-431 onarimi: kirasi taze, makul yasli kosu HALA aynalanir', () {
      // Sinirlar hayalet kosuyu kesmeli ama GERCEK uzun calismayi degil.
      final serverTime = DateTime.now().toUtc();
      final directive = planGlobalTimerForegroundApply(
        snapshot: GlobalTimerSnapshot(
          stateVersion: 12,
          serverTime: serverTime,
          run: GlobalTimerRun(
            id: 'run-live',
            status: 'running',
            revision: 3,
            effectiveStartedAt: serverTime.subtract(const Duration(hours: 2)),
            leaseExpiresAt: serverTime.add(const Duration(seconds: 150)),
          ),
        ),
        localRunning: false,
        localIsMirror: false,
        localMirrorRunId: null,
      );
      expect(directive.kind, GlobalTimerForegroundDirectiveKind.mirrorStart);
    });

    test('geciken heartbeat acik kosuyu recovery penceresinde korur', () {
      // WP-430'da bu iddia TERSTI: `GlobalTimerRun` kira alanini hic
      // tasimiyordu, sunucu gondermis olsa bile `fromMap` dusuruyordu.
      final serverTime = DateTime.now().toUtc();
      final expiredLeaseRun = GlobalTimerRun.fromMap({
        'id': 'run-ghost',
        'status': 'running',
        'run_revision': 1,
        'effective_started_at': serverTime
            .subtract(const Duration(hours: 8))
            .toIso8601String(),
        'lease_expires_at': serverTime
            .subtract(const Duration(hours: 8))
            .toIso8601String(),
        'lease_expired': true,
      });

      expect(expiredLeaseRun.leaseExpired, isTrue);
      expect(expiredLeaseRun.leaseExpiresAt, isNotNull);
      expect(
        expiredLeaseRun.isDisplayableAt(serverTime),
        isTrue,
        reason:
            'kisa lease cihaz tazeligi; kullanicinin acik calisma niyeti degil',
      );

      final directive = planGlobalTimerForegroundApply(
        snapshot: GlobalTimerSnapshot(
          stateVersion: 12,
          serverTime: serverTime,
          run: expiredLeaseRun,
        ),
        localRunning: false,
        localIsMirror: false,
        localMirrorRunId: null,
      );
      expect(
        directive.kind,
        GlobalTimerForegroundDirectiveKind.mirrorStart,
        reason: 'Android Dart isolate askidayken ayna sayac kaybolmamali',
      );
    });

    test('WP-431 onarimi: ekranda duran olu ayna kosusu kapatilir', () {
      final serverTime = DateTime.now().toUtc();
      final directive = planGlobalTimerForegroundApply(
        snapshot: GlobalTimerSnapshot(
          stateVersion: 13,
          serverTime: serverTime,
          run: GlobalTimerRun(
            id: 'run-ghost',
            status: 'running',
            revision: 1,
            effectiveStartedAt: serverTime.subtract(const Duration(hours: 13)),
            leaseExpiresAt: serverTime.subtract(const Duration(hours: 13)),
            leaseExpired: true,
          ),
        ),
        localRunning: true,
        localIsMirror: true,
        localMirrorRunId: 'run-ghost',
      );
      expect(
        directive.kind,
        GlobalTimerForegroundDirectiveKind.mirrorStop,
        reason: 'hayalet sayac ekranda kalmamali',
      );
    });

    test(
      'WP-491: controllerDeviceId bu cihazla eslesirse gercek ayna degil, '
      'staleOwnRunCleanup',
      () {
        // Sahibin V58-N08 anlatisi: telefondan normal Durdur -> uyu -> sabah
        // ac -> ekranda 10 saat -> "diger cihaz" onayi -> tablete hic
        // dokunulmamis. Kok neden: dunku Durdur sunucuya ulasmamis, run
        // hala `running`; ama controller_device_id BU cihazin kendi
        // kimligi. Baska cihaz yokken "diger cihaz" diyalogu YANLIS.
        final serverTime = DateTime.now().toUtc();
        final directive = planGlobalTimerForegroundApply(
          snapshot: GlobalTimerSnapshot(
            stateVersion: 20,
            serverTime: serverTime,
            run: GlobalTimerRun(
              id: 'run-own-stale',
              status: 'running',
              revision: 4,
              effectiveStartedAt: serverTime.subtract(const Duration(hours: 10)),
              leaseExpiresAt: serverTime.add(const Duration(seconds: 150)),
              controllerDeviceId: 'device-phone-1',
            ),
          ),
          localRunning: false,
          localIsMirror: false,
          localMirrorRunId: null,
          myDeviceId: 'device-phone-1',
        );
        expect(
          directive.kind,
          GlobalTimerForegroundDirectiveKind.staleOwnRunCleanup,
          reason:
              'ayni cihazin kendi eski kosusu sessizce temizlenmeli, '
              'ayna olarak acilmamali',
        );
      },
    );

    test(
      'WP-491: controllerDeviceId farkli cihazsa hala gercek mirrorStart',
      () {
        // Regresyon kilidi: gercek coklu-cihaz senaryosu bozulmamali.
        final serverTime = DateTime.now().toUtc();
        final directive = planGlobalTimerForegroundApply(
          snapshot: GlobalTimerSnapshot(
            stateVersion: 21,
            serverTime: serverTime,
            run: GlobalTimerRun(
              id: 'run-other-device',
              status: 'running',
              revision: 2,
              effectiveStartedAt: serverTime.subtract(const Duration(hours: 1)),
              leaseExpiresAt: serverTime.add(const Duration(seconds: 150)),
              controllerDeviceId: 'device-tablet-2',
            ),
          ),
          localRunning: false,
          localIsMirror: false,
          localMirrorRunId: null,
          myDeviceId: 'device-phone-1',
        );
        expect(
          directive.kind,
          GlobalTimerForegroundDirectiveKind.mirrorStart,
          reason: 'gercekten baska cihazsa ayna deneyimi degismemeli',
        );
      },
    );

    test(
      'WP-491: myDeviceId veya controllerDeviceId eksikse guvenli varsayilan '
      'mirrorStart',
      () {
        // Eski sunucu semasi ya da henuz kayitli olmayan cihaz: karsilastirma
        // yapilamiyorsa eski (WP-431) davranisa geri dusulur, crash olmaz.
        final serverTime = DateTime.now().toUtc();
        final directive = planGlobalTimerForegroundApply(
          snapshot: GlobalTimerSnapshot(
            stateVersion: 22,
            serverTime: serverTime,
            run: GlobalTimerRun(
              id: 'run-no-controller',
              status: 'running',
              revision: 1,
              effectiveStartedAt: serverTime.subtract(const Duration(hours: 1)),
              leaseExpiresAt: serverTime.add(const Duration(seconds: 150)),
            ),
          ),
          localRunning: false,
          localIsMirror: false,
          localMirrorRunId: null,
          myDeviceId: 'device-phone-1',
        );
        expect(
          directive.kind,
          GlobalTimerForegroundDirectiveKind.mirrorStart,
          reason: 'controllerDeviceId yoksa eslesme iddia edilemez',
        );
      },
    );

    test(
      'WP-431 onarimi: yas sinirini asan kosu kira taze olsa da aynalanmaz',
      () {
        final serverTime = DateTime.now().toUtc();
        final directive = planGlobalTimerForegroundApply(
          snapshot: GlobalTimerSnapshot(
            stateVersion: 14,
            serverTime: serverTime,
            run: GlobalTimerRun(
              id: 'run-endless',
              status: 'running',
              revision: 9,
              effectiveStartedAt: serverTime.subtract(
                kGlobalTimerMaxMirrorRunAge + const Duration(minutes: 1),
              ),
              leaseExpiresAt: serverTime.add(const Duration(seconds: 150)),
            ),
          ),
          localRunning: false,
          localIsMirror: false,
          localMirrorRunId: null,
        );
        expect(
          directive.kind,
          GlobalTimerForegroundDirectiveKind.needsReconcile,
          reason:
              'kira alanini tasimayan eski sunucuya karsi ikinci set: yas siniri',
        );
      },
    );

    test('WP-431 onarimi: sunucu okuma yolu kirayi DEGERLENDIRIYOR', () {
      // WP-430'da `_global_timer_v2_snapshot` kirayi yalniz raporluyordu.
      // `0101` onu `lease_expired` olarak hesaplar; `status` bilerek
      // degistirilmez (veri durust kalir, karari istemci verir).
      final migration = _source(_controllerMigrationPath);
      final start = migration.indexOf(
        'create or replace function public._global_timer_v2_snapshot',
      );
      expect(start, greaterThan(-1));
      final body = migration.substring(
        start,
        migration.indexOf('\n\$\$;', start),
      );
      expect(body, contains("'lease_expired'"));
      expect(
        body,
        contains('r.lease_expires_at <= clock_timestamp()'),
        reason:
            'kira gercegi istemci saatine degil sunucu saatine gore olculur',
      );
      expect(
        migration,
        contains('live_study_runs_v2_single_active_idx'),
        reason: 'hesap-geneli tek aktif kosu artik sema invarianti',
      );
      expect(
        migration,
        contains('client_clock_skew_rejected'),
        reason: 'gelecekten gelen komut reddedilmeli',
      );
      expect(
        migration,
        contains('public._enqueue_global_timer_v2_sync('),
        reason: '0088 timer-sync enqueue govdesi yeni RPC de kaybolmamali',
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
