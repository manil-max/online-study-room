import 'dart:convert';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/background/timer_foreground_service.dart';
import '../../core/background/timer_v2_command_outbox.dart';
import '../../core/config/rollout_config.dart';
import '../../core/config/supabase_config.dart';
import '../../core/observability/timer_diagnostic_journal.dart';
import '../../core/prefs/app_prefs.dart';
import '../models/global_timer.dart';
import '../repositories/global_timer_repository.dart';
import '../repositories/in_memory/in_memory_global_timer_repository.dart';
import '../repositories/supabase/supabase_global_timer_repository.dart';
import 'auth_providers.dart';

const globalTimerDeviceIdKey = 'global_timer_v2_device_id';

enum GlobalTimerMode { disabled, shadow, foregroundMirror }

/// WP-431: bir komut hatasının **ne yapılması gerektiğini** söyleyen sınıf.
///
/// 🔴 Eskiden `catch (_)` üç farklı dünyayı tek torbaya atıyordu: geçici ağ
/// hatası, hesabı uymayan zarf ve sunucunun ASLA kabul etmeyeceği bozuk kayıt.
/// Sonuç iki yönlü kayıptı — bozuk kayıt kuyruğu sonsuza kadar tıkıyor, geçici
/// hata ise bazen kaydın düşmesine yol açıyordu.
enum GlobalTimerCommandFailure {
  /// Geçici: kuyrukta kalır, sonraki turda yeniden denenir.
  retry,

  /// Hesap/cihaz bağı yok: saklanır ama bu hesap adına gönderilmez.
  quarantine,

  /// Sunucu bu zarfı hiçbir zaman kabul etmeyecek: kuyruktan düşer.
  terminal,
}

/// Sunucu hata kodlarının kanonik sınıflandırması.
///
/// `0082`/`0101` `raise exception '<kod>'` ile konuşur; PostgREST bu kodu hata
/// mesajının içinde taşır. Tanınmayan hata **retry**'dir: veri kaybetmemek,
/// kuyruğu bir tur fazla denemekten daha önemlidir.
GlobalTimerCommandFailure classifyGlobalTimerFailure(Object error) {
  final message = error.toString().toLowerCase();
  const terminal = <String>[
    'invalid_global_timer_command',
    'invalid_global_timer_origin',
    'command_id_payload_mismatch',
    'stop_run_revision_required',
    'global_timer_v2_run_required',
    'global_timer_run_not_found',
    'subject_ownership_required',
    'client_clock_skew_rejected',
  ];
  const quarantine = <String>[
    'authentication_required',
    'active_device_required',
  ];
  for (final code in terminal) {
    if (message.contains(code)) return GlobalTimerCommandFailure.terminal;
  }
  for (final code in quarantine) {
    if (message.contains(code)) return GlobalTimerCommandFailure.quarantine;
  }
  return GlobalTimerCommandFailure.retry;
}

/// WP-415: native, çevrimdışı bir start henüz sunucuda koşu kimliği almadan
/// durursa bu yerel terminal niyetini yazar. Bu nesne hiçbir zaman RPC'ye
/// doğrudan gönderilmez; eş start kabul edilince gerçek CAS-stop'a çözülür.
class DeferredGlobalTimerStop {
  const DeferredGlobalTimerStop({
    required this.commandId,
    required this.accountId,
    required this.installationId,
    required this.clientOccurredAt,
    required this.origin,
    required this.runIntentId,
  });

  final String commandId;
  final String accountId;
  final String installationId;
  final DateTime clientOccurredAt;
  final String origin;
  final String runIntentId;

  static DeferredGlobalTimerStop? tryParse(Map<dynamic, dynamic> raw) {
    String? value(String key) {
      final rawValue = raw[key]?.toString().trim();
      return rawValue == null || rawValue.isEmpty ? null : rawValue;
    }

    if (raw['kind'] != TimerV2CommandEnvelope.kind ||
        raw['schema_version'] != TimerV2CommandEnvelope.schemaVersion ||
        raw['action'] != 'stop' ||
        raw['deferred_until_run_identity'] != true) {
      return null;
    }
    final commandId = value('command_id');
    final installationId = value('installation_id');
    final occurredAt = DateTime.tryParse(value('client_occurred_at') ?? '');
    final origin = value('origin');
    final runIntentId = value('run_intent_id');
    if (commandId == null ||
        installationId == null ||
        occurredAt == null ||
        origin == null ||
        runIntentId == null ||
        !TimerV2CommandEnvelope.canonicalOrigins.contains(origin)) {
      return null;
    }
    return DeferredGlobalTimerStop(
      commandId: commandId,
      accountId: raw['account_id']?.toString().trim() ?? '',
      installationId: installationId,
      clientOccurredAt: occurredAt.toUtc(),
      origin: origin,
      runIntentId: runIntentId,
    );
  }

  TimerV2CommandEnvelope resolve({
    required String runId,
    required int expectedRunRevision,
  }) => TimerV2CommandEnvelope(
    commandId: commandId,
    accountId: accountId,
    installationId: installationId,
    action: 'stop',
    clientOccurredAt: clientOccurredAt,
    origin: origin,
    runId: runId,
    expectedRunRevision: expectedRunRevision,
  );
}

/// WP-365: kademe artık sabit kod değil, tek rollout yapılandırma noktasından
/// gelir. Presence kademesinden **bağımsızdır**: biri kapatılsa diğeri çalışır.
final globalTimerModeProvider = Provider<GlobalTimerMode>(
  (_) => RolloutConfig.globalTimerMode,
);
final globalTimerRepositoryProvider = Provider<GlobalTimerRepository>(
  (_) => SupabaseConfig.isConfigured
      ? SupabaseGlobalTimerRepository(Supabase.instance.client)
      : InMemoryGlobalTimerRepository(),
);

/// Shadow-only flush: native'ın tek producer olduğu envelope'u tüketir; timer UI
/// veya local state'i değiştirmez. Hesap/cihaz bağından yoksun kayıt kuyrukta kalır.
class GlobalTimerCoordinator {
  GlobalTimerCoordinator(this._ref);
  final Ref _ref;
  Future<void>? _inFlight;

  /// WP-430: her sunucu turu tanı kaydına neden + sonuç bırakır.
  TimerDiagnosticJournal get _journal =>
      _ref.read(timerDiagnosticJournalProvider);

  Future<void> flushShadow() {
    final current = _inFlight;
    if (current != null) return current;
    final future = _flush();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  /// WP-379: Ayna cihaz, uzak koşuyu ancak sunucunun güncel run kimliği ve
  /// revizyonuyla durdurabilir. Native ayna başlatması bilerek V2 zarfı
  /// üretmediği için bu, normal native outbox'ı değil aynı V2 RPC sözleşmesini
  /// doğrudan kullanan onaylı kullanıcı niyetidir.
  Future<GlobalTimerSnapshot> stopMirroredRun({
    required String runId,
    required int expectedRunRevision,
  }) async {
    if (_ref.read(globalTimerModeProvider) !=
        GlobalTimerMode.foregroundMirror) {
      throw StateError('global_timer_mirror_disabled');
    }
    if (runId.trim().isEmpty || expectedRunRevision < 1) {
      throw StateError('global_timer_mirror_identity_required');
    }
    final user = _ref.read(authStateProvider).value;
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.reload();
    final deviceId = prefs.getString(globalTimerDeviceIdKey)?.trim();
    if (user == null || deviceId == null || deviceId.isEmpty) {
      throw StateError('global_timer_mirror_device_required');
    }
    final snapshot = await _ref
        .read(globalTimerRepositoryProvider)
        .applyCommand(
          commandId: const Uuid().v4(),
          deviceId: deviceId,
          action: 'stop',
          runId: runId,
          expectedRunRevision: expectedRunRevision,
          clientOccurredAt: DateTime.now(),
          payload: const {'origin': 'app'},
        );
    // WP-431: koşu zaten kapanmışsa bu bir hata değil, istenen sonuçtur —
    // terminal durum her zaman üstün gelir. Yalnız `stale` (başka cihazın daha
    // yeni gerçeği) aynayı yerel olarak kapatmayı engeller.
    if (snapshot.resultCode == 'stale') {
      await _journal.record(
        event: TimerJournalEvents.mirrorStopRequested,
        reason: TimerJournalReasons.userAction,
        outcome: TimerJournalOutcomes.stale,
        origin: TimerJournalOrigins.app,
        accountId: user.id,
        runId: runId,
        deviceId: deviceId,
        runRevision: expectedRunRevision,
        stateVersion: snapshot.stateVersion,
      );
      throw StateError('global_timer_mirror_stop_stale');
    }
    // WP-431: kimlik bileti bu koşuyla birlikte tükendi. Bırakılırsa `_finish()`
    // yolundaki native STOP_SILENT ölü koşuya ikinci, zehirli bir stop zarfı
    // üretirdi.
    await _persistRunIdentity(prefs, snapshot);
    await _journal.record(
      event: TimerJournalEvents.mirrorStopRequested,
      reason: TimerJournalReasons.userAction,
      outcome: TimerJournalOutcomes.applied,
      origin: TimerJournalOrigins.app,
      accountId: user.id,
      runId: snapshot.run?.id ?? runId,
      deviceId: deviceId,
      runRevision: snapshot.run?.revision ?? expectedRunRevision,
      stateVersion: snapshot.stateVersion,
    );
    return snapshot;
  }

  Future<void> _flush() async {
    if (_ref.read(globalTimerModeProvider) == GlobalTimerMode.disabled) return;
    final user = _ref.read(authStateProvider).value;
    final prefs = _ref.read(sharedPreferencesProvider);
    // WP-373: kuyruğun YAZICISI native'dir; Dart'ın SharedPreferences'ı ise
    // bellekte önbelleklidir. `reload()` olmadan buradaki okuma, native az önce
    // yazmış olsa bile ESKİ içeriği görür. WP-368'in "başlatma anında yayınla"
    // düzeltmesi tam da bu yüzden fiilen no-op'tu; yayını yalnız broadcast
    // yolundaki `_reconcileBackgroundTimer` (kendi `reload()`'u ile) kurtarıyordu.
    await prefs.reload();
    final deviceId = prefs.getString(globalTimerDeviceIdKey)?.trim();
    if (user == null || deviceId == null || deviceId.isEmpty) return;
    final raw = prefs.getString(TimerForegroundService.pendingIntervalsKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final queued =
        <
          ({TimerV2CommandEnvelope? command, DeferredGlobalTimerStop? deferred})
        >[];
    final startIntentIdByCommandId = <String, String>{};
    for (final item in decoded) {
      if (item is! Map) continue;
      final command = TimerV2CommandEnvelope.tryParse(item);
      final deferred = command == null
          ? DeferredGlobalTimerStop.tryParse(item)
          : null;
      if (command != null || deferred != null) {
        queued.add((command: command, deferred: deferred));
      }
      if (command?.action == 'start') {
        final intentId = item['run_intent_id']?.toString().trim();
        if (intentId != null && intentId.isNotEmpty) {
          startIntentIdByCommandId[command!.commandId] = intentId;
        }
      }
    }
    // Native yazımı sırayı zaten korur; zaman sırası ise diskten geri yükleme
    // veya farklı yazıcı sürümlerinde de start'ın terminal niyetinden önce
    // çözülmesini açıkça garanti eder.
    queued.sort(
      (left, right) =>
          (left.command?.clientOccurredAt ?? left.deferred!.clientOccurredAt)
              .compareTo(
                right.command?.clientOccurredAt ??
                    right.deferred!.clientOccurredAt,
              ),
    );
    const staleStartLimit = Duration(hours: 24);
    final now = DateTime.now().toUtc();
    final staleIntentIds = <String>{};
    for (final entry in queued) {
      final command = entry.command;
      if (command == null || command.action != 'start') continue;
      final intentId = startIntentIdByCommandId[command.commandId];
      if (intentId != null &&
          now.difference(command.clientOccurredAt) > staleStartLimit) {
        staleIntentIds.add(intentId);
      }
    }

    final completed = <String>{};
    final repo = _ref.read(globalTimerRepositoryProvider);
    for (final entry in queued) {
      final deferred = entry.deferred;
      var command = entry.command;
      final accountId = command?.accountId ?? deferred!.accountId;
      if (accountId != user.id) continue;
      if (command?.action == 'start' &&
          now.difference(command!.clientOccurredAt) > staleStartLimit) {
        completed.add(command.commandId);
        // WP-430 / V56-S02: bayat bir başlatma niyeti düşürüldü. Bu satır
        // olmadan "sayaç kendiliğinden başladı" iddiası ölçülemez.
        await _journal.record(
          event: TimerJournalEvents.startRequested,
          reason: TimerJournalReasons.queueReplay,
          outcome: TimerJournalOutcomes.dropped,
          origin: command.origin,
          accountId: command.accountId,
          deviceId: deviceId,
          commandId: command.commandId,
          queueAgeMs: now.difference(command.clientOccurredAt).inMilliseconds,
        );
        continue;
      }
      if (deferred != null) {
        if (staleIntentIds.contains(deferred.runIntentId)) {
          completed.add(deferred.commandId);
          continue;
        }
        final runId = prefs.getString(TimerV2CommandEnvelope.runIdKey)?.trim();
        final runRevision = int.tryParse(
          prefs.getString(TimerV2CommandEnvelope.runRevisionKey) ?? '',
        );
        if (runId == null ||
            runId.isEmpty ||
            runRevision == null ||
            runRevision < 1) {
          continue;
        }
        command = deferred.resolve(
          runId: runId,
          expectedRunRevision: runRevision,
        );
      }
      try {
        final snapshot = await repo.applyCommand(
          commandId: command!.commandId,
          deviceId: deviceId,
          action: command.action,
          runId: command.runId,
          expectedRunRevision: command.expectedRunRevision,
          clientOccurredAt: command.clientOccurredAt,
          payload: {'origin': command.origin},
        );
        completed.add(command.commandId);
        await _journal.record(
          event: TimerJournalEvents.commandFlushed,
          reason: deferred == null
              ? TimerJournalReasons.queueReplay
              : TimerJournalReasons.externalCommandQueue,
          outcome: switch (snapshot.resultCode) {
            'duplicate' => TimerJournalOutcomes.duplicate,
            'stale' => TimerJournalOutcomes.stale,
            _ => TimerJournalOutcomes.applied,
          },
          origin: command.origin,
          accountId: command.accountId,
          runId: snapshot.run?.id ?? command.runId,
          deviceId: deviceId,
          commandId: command.commandId,
          runRevision: snapshot.run?.revision ?? command.expectedRunRevision,
          stateVersion: snapshot.stateVersion,
          queueAgeMs: now.difference(command.clientOccurredAt).inMilliseconds,
        );
        // WP-373: sunucunun kabul ettiği koşu kimliğini native'e geri yaz.
        // Durdurma zarfını native kurar ve `run_id` + `expected_run_revision`
        // olmadan sunucu `stop_run_revision_required` atar; bu köprü olmadan
        // durdurma sinyali hiçbir zaman üretilemez.
        await _persistRunIdentity(prefs, snapshot);
      } catch (error) {
        // WP-431: hata sınıfı ne yapacağımızı belirler. Runtime flag/RLS/ağ
        // hatası legacy timer'ı veya kuyruktaki diğer kaydı bozmaz.
        final failure = classifyGlobalTimerFailure(error);
        if (failure == GlobalTimerCommandFailure.terminal) {
          // Sunucu bu zarfı hiçbir zaman kabul etmeyecek: kuyrukta kalıcı zehir
          // olmasındansa düşsün. Kaybolan şey bir kullanıcı çalışması değil,
          // uygulanamaz bir komuttur.
          completed.add(command!.commandId);
        }
        // WP-430: sessiz yutma artık iz bırakır — "senkron bazen çalışmıyor"
        // iddiası ancak başarısız turun kaydıyla kanıtlanabilir.
        final failed = command;
        if (failed != null) {
          await _journal.record(
            event: TimerJournalEvents.commandFlushed,
            reason: TimerJournalReasons.queueReplay,
            outcome: switch (failure) {
              GlobalTimerCommandFailure.terminal =>
                TimerJournalOutcomes.dropped,
              GlobalTimerCommandFailure.quarantine =>
                TimerJournalOutcomes.deferred,
              GlobalTimerCommandFailure.retry => TimerJournalOutcomes.failed,
            },
            origin: failed.origin,
            accountId: failed.accountId,
            runId: failed.runId,
            deviceId: deviceId,
            commandId: failed.commandId,
            queueAgeMs: now.difference(failed.clientOccurredAt).inMilliseconds,
          );
        }
      }
    }
    if (completed.isEmpty) return;
    final retained = decoded
        .where(
          (item) =>
              item is! Map ||
              !completed.contains(item['command_id']?.toString()),
        )
        .toList();
    await prefs.setString(
      TimerForegroundService.pendingIntervalsKey,
      jsonEncode(retained),
    );
  }

  /// Sunucunun döndürdüğü koşu kimliğini native durdurma zarfı için saklar.
  ///
  /// Koşu artık çalışmıyorsa anahtarlar SİLİNİR: bayat bir kimlik, sonraki
  /// durdurmada ölü bir koşuya `stale` stop göndermeye yol açardı.
  static Future<void> _persistRunIdentity(
    SharedPreferences prefs,
    GlobalTimerSnapshot snapshot,
  ) async {
    final run = snapshot.run;
    if (run == null || run.status != 'running') {
      await prefs.remove(TimerV2CommandEnvelope.runIdKey);
      await prefs.remove(TimerV2CommandEnvelope.runRevisionKey);
      return;
    }
    await prefs.setString(TimerV2CommandEnvelope.runIdKey, run.id);
    await prefs.setString(
      TimerV2CommandEnvelope.runRevisionKey,
      run.revision.toString(),
    );
  }

  /// WP-343: foreground uygulamasına yalnız doğrulanmış sunucu snapshot'ından
  /// bir talimat üretir. Uygulama işlemi StudyTimerNotifier'da yapılır; böylece
  /// bu katman normal timer state'ini ya da native görünümü doğrudan değiştirmez.
  Future<GlobalTimerForegroundDirective?> reconcileForeground({
    required bool localRunning,
    required bool localIsMirror,
    required String? localMirrorRunId,
  }) async {
    if (_ref.read(globalTimerModeProvider) !=
        GlobalTimerMode.foregroundMirror) {
      return null;
    }
    final prefs = _ref.read(sharedPreferencesProvider);
    final deviceId = prefs.getString(globalTimerDeviceIdKey)?.trim();
    final user = _ref.read(authStateProvider).value;
    if (user == null || deviceId == null || deviceId.isEmpty) return null;
    try {
      final snapshot = await _ref
          .read(globalTimerRepositoryProvider)
          .fetchSnapshot(deviceId: deviceId);
      if (snapshot.userId != null && snapshot.userId != user.id) return null;
      final seenKey = 'global_timer_v2_seen_${user.id}_$deviceId';
      final seen = prefs.getInt(seenKey) ?? 0;
      final directive = planGlobalTimerForegroundApply(
        snapshot: snapshot,
        localRunning: localRunning,
        localIsMirror: localIsMirror,
        localMirrorRunId: localMirrorRunId,
        myDeviceId: deviceId,
      );
      // `seen` bir olay-dedup anahtarıdır; yerel projection doğruluğunun yerine
      // geçemez. Soğuk açılışta ayna güvenlik gereği temizlenir. Sunucu sürümü
      // değişmemiş olsa bile yerel ayna eksikse aynı snapshot yeniden uygulanır.
      if (snapshot.stateVersion <= seen &&
          directive.kind == GlobalTimerForegroundDirectiveKind.deferred) {
        await _journal.record(
          event: TimerJournalEvents.snapshotReconciled,
          reason: TimerJournalReasons.remoteSnapshot,
          outcome: TimerJournalOutcomes.duplicate,
          accountId: user.id,
          runId: snapshot.run?.id,
          deviceId: deviceId,
          runRevision: snapshot.run?.revision,
          stateVersion: snapshot.stateVersion,
        );
        return null;
      }
      final run = snapshot.run;
      await _journal.record(
        event: TimerJournalEvents.snapshotReconciled,
        reason: TimerJournalReasons.remoteSnapshot,
        outcome: switch (directive.kind) {
          GlobalTimerForegroundDirectiveKind.deferred =>
            TimerJournalOutcomes.deferred,
          // WP-431 (K2): sunucu `running` diyor ama koşu gösterilebilir değil.
          // Bu, hayalet koşunun artık ekrana çıkmadan yakalandığı noktadır.
          GlobalTimerForegroundDirectiveKind.needsReconcile =>
            TimerJournalOutcomes.stale,
          _ => TimerJournalOutcomes.applied,
        },
        origin: switch (directive.kind) {
          GlobalTimerForegroundDirectiveKind.mirrorStart =>
            TimerJournalOrigins.mirror,
          // WP-491: gerçek ayna değil, bu cihazın kendi terk edilmiş koşusu —
          // `unknown`'a düşerse "sürpriz ayna" sanılıp yanlış teşhis edilir.
          GlobalTimerForegroundDirectiveKind.staleOwnRunCleanup =>
            TimerJournalOrigins.recovery,
          _ => TimerJournalOrigins.unknown,
        },
        accountId: user.id,
        runId: run?.id,
        deviceId: deviceId,
        runRevision: run?.revision,
        stateVersion: snapshot.stateVersion,
        // Uzak koşu bu cihaza kaç ms gecikmeyle ulaştı: "aralıklı senkron"
        // (V56-S03) yalnız bu gecikme dağılımıyla ölçülebilir.
        queueAgeMs: run?.effectiveStartedAt == null
            ? null
            : snapshot.serverTime
                  .difference(run!.effectiveStartedAt!.toUtc())
                  .inMilliseconds,
      );
      return directive;
    } catch (_) {
      await _journal.record(
        event: TimerJournalEvents.snapshotReconciled,
        reason: TimerJournalReasons.remoteSnapshot,
        outcome: TimerJournalOutcomes.failed,
        accountId: user.id,
        deviceId: deviceId,
      );
      return null;
    }
  }

  /// WP-373: çalışan koşunun sunucudaki kirasını tazeler.
  ///
  /// Kısa kira 150 sn'lik controller tazeliğidir (`0082:296`). Sahip cihaz
  /// kirayı tazeler; `0119` sonrasında ilk kaçırılan tur açık çalışma niyetini
  /// kapatmaz. Süpürücü ancak bounded recovery grace aşılırsa koşuyu abandoned
  /// yapar (`0089` cron + `0119` fonksiyon gövdesi).
  ///
  /// Yalnız koşunun SAHİBİ cihaz çağırır; ayna cihazın kira üzerinde söz hakkı
  /// yoktur ([TimerV2CommandEnvelope.runIdKey] onda yazılı değildir).
  Future<void> heartbeat() async {
    if (_ref.read(globalTimerModeProvider) !=
        GlobalTimerMode.foregroundMirror) {
      return;
    }
    final prefs = _ref.read(sharedPreferencesProvider);
    final deviceId = prefs.getString(globalTimerDeviceIdKey)?.trim();
    final user = _ref.read(authStateProvider).value;
    final runId = prefs.getString(TimerV2CommandEnvelope.runIdKey)?.trim();
    if (user == null ||
        deviceId == null ||
        deviceId.isEmpty ||
        runId == null ||
        runId.isEmpty) {
      return;
    }
    try {
      final snapshot = await _ref
          .read(globalTimerRepositoryProvider)
          .applyCommand(
            commandId: const Uuid().v4(),
            deviceId: deviceId,
            action: 'heartbeat',
            runId: runId,
            clientOccurredAt: DateTime.now().toUtc(),
          );
      await _persistRunIdentity(prefs, snapshot);
      await _journal.record(
        event: TimerJournalEvents.leaseHeartbeat,
        reason: TimerJournalReasons.periodicPoll,
        outcome: snapshot.run == null
            ? TimerJournalOutcomes.dropped
            : TimerJournalOutcomes.applied,
        accountId: user.id,
        runId: runId,
        deviceId: deviceId,
        runRevision: snapshot.run?.revision,
        stateVersion: snapshot.stateVersion,
      );
    } catch (_) {
      await _journal.record(
        event: TimerJournalEvents.leaseHeartbeat,
        reason: TimerJournalReasons.periodicPoll,
        outcome: TimerJournalOutcomes.failed,
        accountId: user.id,
        runId: runId,
        deviceId: deviceId,
      );
      // Koşu sunucuda kapanmışsa `global_timer_run_not_active` gelir; kira
      // yenilemek zaten anlamsızdır ve sıradaki reconcile durumu düzeltir.
    }
  }

  Future<void> acknowledgeForeground(
    GlobalTimerForegroundDirective directive, {
    required String status,
    String? runId,
    int? runRevision,
    String? errorCode,
  }) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final deviceId = prefs.getString(globalTimerDeviceIdKey)?.trim();
    final user = _ref.read(authStateProvider).value;
    if (user == null || deviceId == null || deviceId.isEmpty) return;
    await _ref
        .read(globalTimerRepositoryProvider)
        .acknowledge(
          deviceId: deviceId,
          stateVersion: directive.snapshot.stateVersion,
          status: status,
          runId: runId,
          runRevision: runRevision,
          errorCode: errorCode,
        );
    await prefs.setInt(
      'global_timer_v2_seen_${user.id}_$deviceId',
      directive.snapshot.stateVersion,
    );
  }
}

final globalTimerCoordinatorProvider = Provider<GlobalTimerCoordinator>(
  (ref) => GlobalTimerCoordinator(ref),
);
final globalTimerSnapshotProvider = FutureProvider<GlobalTimerSnapshot?>((
  ref,
) async {
  if (ref.watch(globalTimerModeProvider) == GlobalTimerMode.disabled) {
    return null;
  }
  final deviceId = ref
      .watch(sharedPreferencesProvider)
      .getString(globalTimerDeviceIdKey);
  if (ref.watch(authStateProvider).value == null || deviceId == null) {
    return null;
  }
  return ref
      .watch(globalTimerRepositoryProvider)
      .fetchSnapshot(deviceId: deviceId);
});
