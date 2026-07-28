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
import '../../core/prefs/app_prefs.dart';
import '../models/global_timer.dart';
import '../repositories/global_timer_repository.dart';
import '../repositories/in_memory/in_memory_global_timer_repository.dart';
import '../repositories/supabase/supabase_global_timer_repository.dart';
import 'auth_providers.dart';

const globalTimerDeviceIdKey = 'global_timer_v2_device_id';

enum GlobalTimerMode { disabled, shadow, foregroundMirror }

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
    // `stale`, başka bir cihazın daha yeni bir gerçeği olduğunu söyler. Ayna
    // yerel olarak boş görünemez; yeni snapshot turu gerçek durumu uygular.
    if (snapshot.resultCode == 'stale') {
      throw StateError('global_timer_mirror_stop_stale');
    }
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
        // WP-373: sunucunun kabul ettiği koşu kimliğini native'e geri yaz.
        // Durdurma zarfını native kurar ve `run_id` + `expected_run_revision`
        // olmadan sunucu `stop_run_revision_required` atar; bu köprü olmadan
        // durdurma sinyali hiçbir zaman üretilemez.
        await _persistRunIdentity(prefs, snapshot);
      } catch (_) {
        // Runtime flag/RLS/ağ hatası legacy timer'ı veya kuyruktaki diğer kaydı bozmaz.
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
      if (snapshot.stateVersion <= seen) return null;
      return planGlobalTimerForegroundApply(
        snapshot: snapshot,
        localRunning: localRunning,
        localIsMirror: localIsMirror,
        localMirrorRunId: localMirrorRunId,
      );
    } catch (_) {
      return null;
    }
  }

  /// WP-373: çalışan koşunun sunucudaki kirasını tazeler.
  ///
  /// Kira 150 sn'dir (`0082:296`) ve **hiç kimse yenilemiyordu**; süpürücü de
  /// hiçbir cron'a bağlı değildi. İkisi birlikte şu anlama geliyordu: koşu
  /// sonsuza dek `running` kalır, karşı cihaz ölü bir koşuyu aynalar. Artık
  /// sahip cihaz kirayı tazeler, süpürücü de ölen cihazın koşusunu kapatır
  /// (`0089_global_timer_lease_sweeper.sql`).
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
    } catch (_) {
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
