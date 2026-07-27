import 'dart:convert';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _flush() async {
    if (_ref.read(globalTimerModeProvider) == GlobalTimerMode.disabled) return;
    final user = _ref.read(authStateProvider).value;
    final prefs = _ref.read(sharedPreferencesProvider);
    final deviceId = prefs.getString(globalTimerDeviceIdKey)?.trim();
    if (user == null || deviceId == null || deviceId.isEmpty) return;
    final raw = prefs.getString(TimerForegroundService.pendingIntervalsKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final completed = <String>{};
    final repo = _ref.read(globalTimerRepositoryProvider);
    for (final item in decoded) {
      if (item is! Map) continue;
      final command = TimerV2CommandEnvelope.tryParse(item);
      if (command == null || command.accountId != user.id) continue;
      try {
        await repo.applyCommand(
          commandId: command.commandId,
          deviceId: deviceId,
          action: command.action,
          runId: command.runId,
          expectedRunRevision: command.expectedRunRevision,
          clientOccurredAt: command.clientOccurredAt,
          payload: {'origin': command.origin},
        );
        completed.add(command.commandId);
      } catch (_) {
        // Runtime flag/RLS/ağ hatası legacy timer'ı veya kuyruktaki diğer kaydı bozmaz.
      }
    }
    if (completed.isEmpty) return;
    final retained = decoded
        .where(
          (item) =>
              item is! Map ||
              TimerV2CommandEnvelope.tryParse(item)?.commandId == null ||
              !completed.contains(
                TimerV2CommandEnvelope.tryParse(item)!.commandId,
              ),
        )
        .toList();
    await prefs.setString(
      TimerForegroundService.pendingIntervalsKey,
      jsonEncode(retained),
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
