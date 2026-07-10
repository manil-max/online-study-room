import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;

import '../../core/config/supabase_config.dart';
import '../models/presence.dart';
import '../repositories/presence_repository.dart';
import '../repositories/in_memory/in_memory_presence_repository.dart';
import '../repositories/supabase/supabase_presence_repository.dart';
import 'group_providers.dart';

/// Heartbeat aralığı: yerel kullanıcı çalışırken presence satırı bu sıklıkta
/// yeniden yazılır (sunucu `updated_at`'i tazelenir). Bkz. [presence_lifecycle].
const Duration kPresenceHeartbeatInterval = Duration(seconds: 20);

/// Bir presence satırının "canlı" sayılması için son yazımdan bu yana geçebilecek
/// azami süre. Heartbeat aralığının katı (+ pay); uygulama öldürülünce/çökünce
/// heartbeat durur, satır bu süre sonra bayatlar ve çevrimdışı gösterilir.
const Duration kPresenceStaleThreshold = Duration(seconds: 70);

/// Aktif PresenceRepository. Anahtarlar verilmişse Supabase, yoksa bellek-içi.
final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabasePresenceRepository(Supabase.instance.client);
  }
  final repo = InMemoryPresenceRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Bayat presence satırlarını çevrimdışına çeker (§WP-5 çevrimdışı tespiti).
///
/// `updated_at`'i [kPresenceStaleThreshold]'dan eski olan `studying`/`onBreak`
/// satırlar, uygulaması artık heartbeat atmayan (kapanmış/çökmüş) kullanıcıları
/// temsil eder ve çevrimdışı gösterilir. `updatedAt` bilinmiyorsa (bellek-içi
/// mod veya eski satır) durum korunur; yanlış çevrimdışı üretilmez.
List<Presence> applyPresenceStaleness(
  List<Presence> rows, {
  required DateTime now,
  Duration threshold = kPresenceStaleThreshold,
}) {
  return [
    for (final p in rows)
      if (p.status == PresenceStatus.offline ||
          p.updatedAt == null ||
          now.difference(p.updatedAt!) <= threshold)
        p
      else
        p.copyWith(status: PresenceStatus.offline),
  ];
}

/// Kullanıcının sınıfındaki tüm üyelerin canlı durumu; bayat satırlar (heartbeat
/// atmayan, kapanmış uygulamalar) çevrimdışı olarak gösterilir (§WP-5).
///
/// Bayatlama zaman-tabanlıdır: DB değişmese bile liste [kPresenceHeartbeatInterval]
/// aralığıyla yeniden değerlendirilir; böylece eşik dolan bir üye, başka bir DB
/// olayı beklenmeden çevrimdışına düşer. `StreamProvider` olarak kalır → mevcut
/// `.value` kullanan tüketiciler ve `overrideWith((ref) => Stream...)` testleri
/// aynen çalışır.
final groupPresenceProvider = StreamProvider<List<Presence>>((ref) {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return Stream.value(const []);

  final repo = ref.watch(presenceRepositoryProvider);
  final controller = StreamController<List<Presence>>();
  var latest = const <Presence>[];

  final sub = repo.watchGroupPresence(group.id).listen(
    (rows) {
      latest = rows;
      controller.add(rows);
    },
    onError: controller.addError,
  );
  // Periyodik yeniden değerlendirme (bayatlama için); en son satırları tekrar iter.
  final ticker = Timer.periodic(
    kPresenceHeartbeatInterval,
    (_) => controller.add(latest),
  );
  ref.onDispose(() {
    sub.cancel();
    ticker.cancel();
    controller.close();
  });

  return controller.stream
      .map((rows) => applyPresenceStaleness(rows, now: DateTime.now()));
});
