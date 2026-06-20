import 'dart:async';

import '../../models/presence.dart';
import '../presence_repository.dart';

/// Bellek-içi (kalıcı olmayan) presence deposu. Supabase yoksa devreye girer.
class InMemoryPresenceRepository implements PresenceRepository {
  InMemoryPresenceRepository();

  final Map<String, Presence> _byUser = {}; // userId -> son durum
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<Presence> _forGroup(String groupId) {
    final list =
        _byUser.values.where((p) => p.groupId == groupId).toList(growable: false);
    return List.unmodifiable(list);
  }

  @override
  Future<void> setPresence(Presence presence) async {
    _byUser[presence.userId] = presence;
    _changes.add(null);
  }

  @override
  Stream<List<Presence>> watchGroupPresence(String groupId) async* {
    yield _forGroup(groupId);
    await for (final _ in _changes.stream) {
      yield _forGroup(groupId);
    }
  }

  void dispose() => _changes.close();
}
