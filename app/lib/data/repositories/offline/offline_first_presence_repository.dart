import 'dart:async';

import '../../models/presence.dart';
import '../presence_repository.dart';
import 'offline_cache_store.dart';

class OfflineFirstPresenceRepository implements PresenceRepository {
  OfflineFirstPresenceRepository({
    required PresenceRepository remote,
    required OfflineCacheStore cache,
  }) : this._(remote, cache);

  OfflineFirstPresenceRepository._(this._remote, this._cache);

  final PresenceRepository _remote;
  final OfflineCacheStore _cache;
  bool _isFlushing = false;

  Future<void> flushPending() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final pending = await _cache.readPendingPresence();
      final remaining = <Presence>[];

      for (var i = 0; i < pending.length; i++) {
        final presence = pending[i];
        try {
          await _remote.setPresence(presence);
        } catch (_) {
          remaining.addAll(pending.skip(i));
          break;
        }
      }

      await _cache.replacePendingPresence(remaining);
    } finally {
      _isFlushing = false;
    }
  }

  @override
  Future<void> setPresence(Presence presence) async {
    await _cache.upsertCachedPresence(presence);
    try {
      await flushPending();
      await _remote.setPresence(presence);
    } catch (_) {
      await _cache.queuePresence(presence);
    }
  }

  @override
  Stream<List<Presence>> watchGroupPresence(String groupId) async* {
    final cached = await _cache.readGroupPresence(groupId);
    if (cached != null) yield cached;

    try {
      await flushPending();
      await for (final rows in _remote.watchGroupPresence(groupId)) {
        await _cache.saveGroupPresence(groupId, rows);
        yield rows;
        unawaited(flushPending());
      }
    } catch (error, stackTrace) {
      final fallback = await _cache.readGroupPresence(groupId);
      if (fallback != null) {
        yield fallback;
      } else {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }
}
