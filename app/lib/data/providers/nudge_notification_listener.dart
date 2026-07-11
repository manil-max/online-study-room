import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_preferences.dart';
import '../../core/notifications/nudge_notification_service.dart';
import '../../core/prefs/app_prefs.dart';
import '../models/nudge.dart';
import 'auth_providers.dart';
import 'nudge_providers.dart';

/// Bildirimi gösterilmiş dürtme id'lerinin kalıcı anahtarı.
const _kNotifiedNudgeIdsKey = 'notified_nudge_ids';

/// Gelen dürtmeler için yerel bildirim gösterir.
///
/// Her dürtme **yalnızca bir kez** bildirilir. Daha önce bu iş geçici stream
/// snapshot'ına (`previous.value`) dayanıyordu; Supabase realtime yeniden
/// bağlanınca ya da provider yeniden kurulunca `previous` boş gelir, o an
/// okunmamış olan (ve `markRead` hiç çağrılmadığı için hep okunmamış kalan)
/// dürtme "yeni" sanılıp tekrar tekrar bildirilirdi ("kimse dürtmese bile sürekli
/// dürtme"). Artık bildirilen id'ler `SharedPreferences`'te tutulur; stream
/// tazelense veya uygulama yeniden açılsa da aynı dürtme yeniden bildirilmez.
final nudgeNotificationListenerProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).value;
  final preferences = ref.watch(notificationPreferencesProvider);
  if (user == null || !preferences.nudgeNotificationsEnabled) return;

  final prefs = ref.read(sharedPreferencesProvider);
  final notified =
      (prefs.getStringList(_kNotifiedNudgeIdsKey) ?? const <String>[]).toSet();
  // İlk kez çalışıyorsak (anahtar yok), mevcut okunmamış yığını sessizce işaretle
  // ki güncelleme sonrası eski dürtmeler topluca patlamasın; sonraki her dürtme
  // bir kez bildirilir.
  var seeded = prefs.containsKey(_kNotifiedNudgeIdsKey);

  ref.listen(receivedNudgesProvider(user.id), (previous, next) {
    final unread = (next.value ?? const <Nudge>[])
        .where((n) => n.readAt == null)
        .toList();
    if (unread.isEmpty) return;

    if (!seeded) {
      notified.addAll(unread.map((n) => n.id));
      seeded = true;
      unawaited(prefs.setStringList(_kNotifiedNudgeIdsKey, notified.toList()));
      return;
    }

    // Sessiz saatlerde bildirim gösterme; yine de "bildirildi" olarak işaretle
    // ki sessiz saat bitince eski dürtmeler topluca patlamasın (§WP-36).
    final quiet = preferences.isWithinQuietHours(DateTime.now());
    var changed = false;
    for (final nudge in unread) {
      if (!notified.add(nudge.id)) continue; // zaten bildirildi
      changed = true;
      if (quiet) continue;
      unawaited(ref.read(nudgeNotificationServiceProvider).showNudge(nudge));
    }
    if (changed) {
      unawaited(prefs.setStringList(_kNotifiedNudgeIdsKey, notified.toList()));
    }
  });
});
