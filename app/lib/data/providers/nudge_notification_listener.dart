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

  /// Bu oturumda bildirilen id'ler — budama bunlara dokunmaz.
  final addedThisSession = <String>{};

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
        if (notified.add(nudge.id)) {
          addedThisSession.add(nudge.id);
          changed = true;
        }
        continue;
      }
      if (!notified.add(nudge.id)) continue; // zaten bildirildi
      addedThisSession.add(nudge.id);
      changed = true;
      if (quiet) continue;
      // WP-444: susturulan kişinin dürtmesi bildirim üretmez. Sohbet, profil ve
      // grup erişimi etkilenmez — bu yalnız dürtme kanalıdır.
      if (mutedSenderIds.contains(nudge.senderId)) continue;
      unawaited(ref.read(nudgeNotificationServiceProvider).showNudge(nudge));
    }
    // 🔴 WP-653 — KALICI SET BUDANIR.
    //
    // Eski hali her bildirilen id'yi ekleyip TAMAMINI diske yaziyordu ve hic
    // silmiyordu: yillar sonra bu liste kullanicinin aldigi her durtmeyi
    // tasir, her degisimde bastan yazilirdi. `markRead` hicbir yerden
    // cagrilmadigi icin de sunucu tarafi hic kuculmuyor.
    //
    // Budama kurali guvenli: akis artik en yeni N durtmeyi tasiyor
    // (`SupabaseNudgeRepository.kNudgeWindow`). Pencereden dusen bir durtme
    // bir daha ASLA geri gelemez, cunku ondan daha yenileri var; o yuzden
    // id'sini unutmak tekrar bildirime yol acmaz.
    //
    // ⚠️ Asil emniyet: budama YALNIZ `changed` iken kosar, yani ancak yeni bir
    // id eklendiginde. Set zaten sadece o an buyudugu icin dogru an budur ve
    // bos bir kare bu bloga hic girmez.
    //
    // 🔴 DURUST NOT: asagidaki `snapshotIds.isNotEmpty` kontrolu bu haliyle
    // ULASILAMAZ — sabotajla olculdu, kaldirildiginda hicbir test kirmizi
    // dusmedi. Yine de duruyor: budamayi `changed` disina tasiyan biri, bos
    // kareyle butun seti silip ayni durtmeleri TEKRAR bildirtirdi (bu depoda
    // yasanmis "kimse durtmese bile surekli durtme" hatasi). O tehlike
    // olculuyor: budama kosulsuz yapilinca sozlesme testi KIRMIZI duser.
    //
    // Ikinci emniyet: bu oturumda eklenen id'ler her halukarda korunur.
    if (changed) {
      final snapshotIds = (next.value ?? const <Nudge>[])
          .map((n) => n.id)
          .toSet();
      if (snapshotIds.isNotEmpty) {
        notified.removeWhere(
          (id) => !snapshotIds.contains(id) && !addedThisSession.contains(id),
        );
      }
      unawaited(prefs.setStringList(_kNotifiedNudgeIdsKey, notified.toList()));
    }
  }, fireImmediately: true);
});
