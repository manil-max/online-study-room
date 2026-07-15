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

  /// Aktif [watchGroupPresence] dinleyicilerine setPresence sonrası anında push.
  final Map<String, StreamController<List<Presence>>> _presenceLocalHubs = {};

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
    final groupId = presence.groupId;
    if (groupId != null) {
      await _publishLocalGroupPresence(groupId);
    }
    try {
      await flushPending();
      await _remote.setPresence(presence);
    } catch (_) {
      await _cache.queuePresence(presence);
    }
  }

  @override
  Stream<List<Presence>> watchGroupPresence(String groupId) {
    final controller = StreamController<List<Presence>>();
    StreamSubscription<List<Presence>>? remoteSub;
    StreamSubscription<List<Presence>>? localSub;
    var active = true;

    Future<void> emitCached() async {
      final cached = await _cache.readGroupPresence(groupId);
      if (!active || controller.isClosed) return;
      if (cached != null) {
        controller.add(cached);
      }
    }

    Future<void> start() async {
      await emitCached();
      if (!active || controller.isClosed) return;

      localSub = _presenceHub(groupId).stream.listen((rows) {
        if (!controller.isClosed) controller.add(rows);
      });

      try {
        unawaited(flushPending());
        remoteSub = _remote.watchGroupPresence(groupId).listen(
          (rows) async {
            await _cache.saveGroupPresence(groupId, rows);
            if (!controller.isClosed) controller.add(rows);
            unawaited(flushPending());
          },
          onError: (Object error, StackTrace stackTrace) async {
            final fallback = await _cache.readGroupPresence(groupId);
            if (controller.isClosed) return;
            if (fallback != null) {
              controller.add(fallback);
            } else {
              controller.addError(error, stackTrace);
            }
          },
        );
      } catch (error, stackTrace) {
        final fallback = await _cache.readGroupPresence(groupId);
        if (controller.isClosed) return;
        if (fallback != null) {
          controller.add(fallback);
        } else {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller
      ..onListen = () {
        unawaited(start());
      }
      ..onCancel = () async {
        active = false;
        await remoteSub?.cancel();
        await localSub?.cancel();
      };

    return controller.stream;
  }

  StreamController<List<Presence>> _presenceHub(String groupId) {
    return _presenceLocalHubs.putIfAbsent(
      groupId,
      () => StreamController<List<Presence>>.broadcast(),
    );
  }

  Future<void> _publishLocalGroupPresence(String groupId) async {
    final hub = _presenceLocalHubs[groupId];
    if (hub == null || hub.isClosed || !hub.hasListener) return;
    final cached =
        await _cache.readGroupPresence(groupId) ?? const <Presence>[];
    if (!hub.isClosed) {
      hub.add(cached);
    }
  }
}
