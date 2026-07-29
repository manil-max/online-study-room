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

/// Dinleyicinin kurulduğu an.
///
/// Ayrı bir provider'da tutulur: dinleyici (ör. susturma listesi yüklenince)
/// yeniden kurulduğunda bu an **sıfırlanmaz**, yoksa o sırada gelen gerçek bir
/// dürtme "geçmiş" sayılıp sessizce bildirilmiş işaretlenirdi.
final _nudgeListeningStartedAtProvider = Provider<DateTime>(
  (ref) => DateTime.now().toUtc(),
);

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
  // Her uygulama oturumunun ilk gerçek stream anlık görüntüsü geçmişi temsil
  // eder. Kalıcı set, aynı dürtmeyi tekrar göstermeyi önler; fakat yalnız ona
  // güvenmek, uygulama kapalıyken gelen dürtmelerin bir sonraki açılışta topluca
  // bildirim olarak düşmesine yol açar. İlk anlık görüntüyü her zaman sessizce
  // temel al; yalnız bu dinleyici kurulduktan sonra canlı gelen dürtmeleri göster.
  // Stream yeniden bağlansa veya listener sonradan kurulduğunda bile bu an,
  // geçmiş bildirimler ile gerçek zamanlı yeni dürtmeleri ayırır.
  final listeningStartedAt = ref.watch(_nudgeListeningStartedAtProvider);

  // WP-444: susturma yaptırımı sunucudadır (satır hiç oluşmaz). Bu set ikinci
  // katmandır: susturmadan hemen önce yazılmış ya da çevrimdışı kuyrukta bekleyip
  // sonra düşen bir satır bildirime dönüşmesin. Liste henüz yükleniyorsa hiçbir
  // dürtme düşürülmez — filtre yalnız daraltır, uydurmaz.
  final mutedSenderIds =
      ref.watch(mutedNudgeSenderIdsProvider).value ?? const <String>{};

  ref.listen(receivedNudgesProvider(user.id), (previous, next) {
    if (!next.hasValue) return;
    final unread = (next.value ?? const <Nudge>[])
        .where((n) => n.readAt == null)
        .toList();

    // Sessiz saatlerde bildirim gösterme; yine de "bildirildi" olarak işaretle
    // ki sessiz saat bitince eski dürtmeler topluca patlamasın (§WP-36).
    final quiet = preferences.isWithinQuietHours(DateTime.now());
    var changed = false;
    for (final nudge in unread) {
      // Uygulama açılmadan önce oluşmuş eski bir dürtme asla açılış bildirimi
      // üretmez; yalnızca gelecekteki tekrarları önlemek için tanınır.
      if (!nudge.createdAt.toUtc().isAfter(listeningStartedAt)) {
        changed = notified.add(nudge.id) || changed;
        continue;
      }
      if (!notified.add(nudge.id)) continue; // zaten bildirildi
      changed = true;
      if (quiet) continue;
      // WP-444: susturulan kişinin dürtmesi bildirim üretmez. Sohbet, profil ve
      // grup erişimi etkilenmez — bu yalnız dürtme kanalıdır.
      if (mutedSenderIds.contains(nudge.senderId)) continue;
      unawaited(ref.read(nudgeNotificationServiceProvider).showNudge(nudge));
    }
    if (changed) {
      unawaited(prefs.setStringList(_kNotifiedNudgeIdsKey, notified.toList()));
    }
  }, fireImmediately: true);
});
