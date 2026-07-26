import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;

import '../../models/presence.dart';
import '../presence_repository.dart';

/// Supabase tabanlı presence deposu. UI hiç değişmeden bellek-içi yerine geçer.
class SupabasePresenceRepository implements PresenceRepository {
  SupabasePresenceRepository(
    this._client, {
    this.mode = PresenceProjectionMode.legacy,
  });

  final SupabaseClient _client;
  final PresenceProjectionMode mode;
  Object? _lastError;

  @override
  Future<void> setPresence(Presence presence) async {
    switch (mode) {
      case PresenceProjectionMode.legacy:
        await _writeLegacy(presence);
        return;
      case PresenceProjectionMode.shadow:
        // Eski yol çalışmaya devam eder; V3 gölge hatası timer akışını veya
        // legacy görünürlüğü kesmez, ancak readSyncStatus ile gözlemlenir.
        await _writeLegacyIfPossible(presence);
        try {
          await _applyServerDerivedState(presence);
        } catch (error) {
          _lastError = error;
        }
        return;
      case PresenceProjectionMode.projection:
        await _applyServerDerivedState(presence);
        return;
    }
  }

  @override
  Future<void> heartbeatPresence(Presence presence) async {
    switch (mode) {
      case PresenceProjectionMode.legacy:
        await _writeLegacy(presence);
        return;
      case PresenceProjectionMode.shadow:
        await _writeLegacyIfPossible(presence);
        await _renewOrApplyServerDerivedState(presence, swallowError: true);
        return;
      case PresenceProjectionMode.projection:
        await _renewOrApplyServerDerivedState(presence);
        return;
    }
  }

  @override
  Stream<List<Presence>> watchGroupPresence(String groupId) {
    return switch (mode) {
      PresenceProjectionMode.legacy => _watchLegacyGroupPresence(groupId),
      PresenceProjectionMode.shadow => _watchDualGroupPresence(groupId),
      PresenceProjectionMode.projection => _watchProjectionGroupPresence(
        groupId,
      ),
    };
  }

  @override
  Future<PresenceSyncStatus> readSyncStatus() async =>
      PresenceSyncStatus(pendingCount: 0, lastError: _lastError);

  Future<void> _writeLegacy(Presence presence) async {
    if (presence.groupId == null) {
      throw StateError('legacy_presence_requires_group');
    }
    // user_id birincil anahtar → upsert tek satırı günceller.
    await _client.from('presence').upsert(presence.toMap());
  }

  Future<void> _writeLegacyIfPossible(Presence presence) async {
    if (presence.groupId != null) await _writeLegacy(presence);
  }

  Future<void> _applyServerDerivedState(Presence presence) async {
    await _client.rpc(
      'apply_multi_group_presence_state',
      params: {
        'p_status': presence.status.name,
        'p_started_at': presence.startedAt?.toUtc().toIso8601String(),
        'p_today_seconds': presence.todaySeconds,
        'p_subject_id': presence.subjectId,
      },
    );
  }

  Future<void> _renewOrApplyServerDerivedState(
    Presence presence, {
    bool swallowError = false,
  }) async {
    try {
      await _client.rpc('heartbeat_multi_group_presence');
    } catch (error) {
      // Soğuk açılışta state henüz oluşmamış olabilir; aynı idempotent apply
      // çağrısı bunu kurar. Ağ/RLS hatası da böylece normal offline kuyruğuna
      // taşınır (shadow modunda yalnız gözleme alınır).
      try {
        await _applyServerDerivedState(presence);
      } catch (applyError) {
        _lastError = applyError;
        if (!swallowError) rethrow;
      }
    }
  }

  Stream<List<Presence>> _watchLegacyGroupPresence(String groupId) {
    return _client
        .from('presence')
        .stream(primaryKey: ['user_id'])
        .eq('group_id', groupId)
        .map((rows) => rows.map(Presence.fromMap).toList());
  }

  Stream<List<Presence>> _watchProjectionGroupPresence(String groupId) {
    return _client
        .from('group_live_presence')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('group_id', groupId)
        .map((rows) => rows.map(Presence.fromMap).toList());
  }

  Stream<List<Presence>> _watchDualGroupPresence(String groupId) {
    late final StreamController<List<Presence>> controller;
    StreamSubscription<List<Presence>>? legacySub;
    StreamSubscription<List<Presence>>? projectionSub;
    var legacy = const <Presence>[];
    var projection = const <Presence>[];

    void emitMerged() {
      final byUser = <String, Presence>{
        for (final row in legacy) row.userId: row,
        // Projection aynı kullanıcı için legacy'den önceliklidir.
        for (final row in projection) row.userId: row,
      };
      controller.add(byUser.values.toList(growable: false));
    }

    controller = StreamController<List<Presence>>(
      onListen: () {
        legacySub = _watchLegacyGroupPresence(groupId).listen((rows) {
          legacy = rows;
          emitMerged();
        }, onError: controller.addError);
        projectionSub = _watchProjectionGroupPresence(groupId).listen((rows) {
          projection = rows;
          emitMerged();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await legacySub?.cancel();
        await projectionSub?.cancel();
      },
    );
    return controller.stream;
  }
}
