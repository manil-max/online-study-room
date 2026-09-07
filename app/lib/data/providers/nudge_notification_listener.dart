import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_preferences.dart';
import '../../core/notifications/nudge_notification_service.dart';
import '../../core/prefs/app_prefs.dart';
import '../models/nudge.dart';
import 'auth_providers.dart';
import 'nudge_providers.dart';

/// Bildirimi gösterilmiş dürtme id'lerinin kalıcı anahtarı.
const _kNotifiedNudgeIdsKey = 'notified_nudge_ids';

/// WP-811 — dürtmeyi sunucuda "işlendi" olarak işaretler.
///
/// 🔴 `read_at`'in bu uygulamadaki GERÇEK anlamı: **bir istemci bu dürtmeyi
/// teslim alıp işledi.** "Kullanıcı gözüyle okudu" DEĞİL — ortada bir dürtme
/// gelen kutusu ekranı yok; `receivedNudgesProvider`'ın tek tüketicisi bu
/// dinleyicidir. Bu farkı gizlemiyoruz: sütun adı "read" ama semantiği
/// "delivered & processed by a client".
///
/// Neden gerekli: `markRead` bugüne kadar `lib/` içinde hiç çağrılmıyordu,
/// yani her dürtme satırı sunucuda ömür boyu `read_at = null` kalıyordu. Üç
/// somut sonucu vardı — (1) dinleyicideki `readAt == null` süzgeci etkisizdi,
/// (2) `notified_nudge_ids` seti `SharedPreferences`'te yani CİHAZ BAŞINA
/// olduğu için aynı hesabın ikinci cihazı (Windows + Android) aynı dürtmeyi
/// bir daha bildiriyordu, (3) `SupabaseNudgeRepository.kNudgeWindow` bu
/// eksiğin telafisi olarak konmuştu.
///
/// Ateş-et-unut: UI hiçbir zaman bunu beklemez. Hata **yutulmaz ama
/// kullanıcıya patlamaz** — bu bir hijyen işlemidir, başarısızlığı için
/// snackbar göstermek anlamsız olurdu (kullanıcı zaten bildirimi aldı);
/// yine de sessizce kaybolmasın diye depodaki mevcut desenle
/// (`SupabaseAdminRepository._debugLogFeedback`) günlüğe yazılır.
/// `async` gövde sayesinde senkron fırlatan bir implementasyon da yakalanır.
///
/// 🔴 WP-816 — DEPO **İÇERİDE** ÇÖZÜLÜR, dışarıda değil. WP-811 bunu
/// `_markProcessedOnServer(ref.read(nudgeRepositoryProvider), nudge.id)` diye
/// çağırıyordu; yani depo, `try` bloğunun **dışında**, çağrı ifadesinin içinde
/// çözülüyordu. `nudgeRepositoryProvider` yapılandırılmış ortamda
/// `Supabase.instance.client` okur ve bu **fırlatabilir**. Fırlattığında hata
/// bu fonksiyonun `try`ına hiç ulaşmıyor, `ref.listen` geri çağrımını
/// düşürüyor ve döngü o noktada kesiliyordu — yani **bildirim hiç
/// gösterilmiyordu**.
///
/// Zararı test artefaktı değil: bir hijyen yazması, kullanıcının GÖRDÜĞÜ
/// bildirimin önüne geçmiş oluyordu. Kural artık yapıyla korunuyor: bu
/// fonksiyona giren hiçbir şey, dışarıda çözülmüş olamaz.
Future<void> _markProcessedOnServer(Ref ref, String nudgeId) async {
  try {
    await ref.read(nudgeRepositoryProvider).markRead(nudgeId);
  } catch (error, stackTrace) {
    // NudgeException(NudgeErrorCode.markReadFailed) dahil her hata buraya
    // düşer — depo ÇÖZÜLÜRKEN atılanlar da (bkz. WP-816).
    if (!kDebugMode) return;
    debugPrint('WP-811: nudge markRead basarisiz ($nudgeId): $error');
    debugPrint('$stackTrace');
  }
}

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
/// okunmamış olan (ve o gün `markRead` hiç çağrılmadığı için hep okunmamış
/// kalan) dürtme "yeni" sanılıp tekrar tekrar bildirilirdi ("kimse dürtmese bile
/// sürekli dürtme"). Artık bildirilen id'ler `SharedPreferences`'te tutulur;
/// stream tazelense veya uygulama yeniden açılsa da aynı dürtme yeniden
/// bildirilmez. WP-811'den beri ayrıca sunucuya da `markRead` gönderilir —
/// cihaz başına tutulan set, ikinci cihazı tek başına koruyamıyordu.
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
      final isHistory = !nudge.createdAt.toUtc().isAfter(listeningStartedAt);
      if (!notified.add(nudge.id)) continue; // zaten işlendi
      addedThisSession.add(nudge.id);
      changed = true;
      // 🔴 WP-811 — `markRead` TAM BURADA çağrılır: kalıcı `notified` setinin
      // BÜYÜDÜĞÜ an. Set zaten "bu id işlendi" demektir, dolayısıyla aynı
      // dürtme için ikinci bir sunucu çağrısı asla çıkmaz. Her karede çağırmak
      // (set büyümese de) akış her tazelendiğinde gereksiz RPC üretirdi.
      //
      // Çağrı sessiz saatten, susturma süzgecinden ve `isHistory` dalından
      // ÖNCEDİR; üçü de bilinçli kararlardır:
      //  • Sessiz saat: bildirim gösterilmez ama dürtme işlenmiştir. Aksi
      //    halde sessiz saati biten kullanıcının İKİNCİ cihazı aynı dürtmeyi
      //    patlatırdı.
      //  • Susturma: bildirim üretilmez ama satırın sonsuza dek okunmamış
      //    kalmasının hiçbir faydası yok.
      //  • Geçmiş (dinleyici kurulmadan önce oluşmuş): kullanıcı onları zaten
      //    kaçırdı, bir daha bildirim üretmeyecekler; sunucuda okunmamış
      //    durmaları yalnızca pencereyi kirletir.
      // `readAt != null` gelen dürtmeler bu döngüye zaten girmez (`unread`).
      unawaited(_markProcessedOnServer(ref, nudge.id));
      if (isHistory) continue;
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
    // tasir, her degisimde bastan yazilirdi. O gun `markRead` hicbir yerden
    // cagrilmadigi icin sunucu tarafi da hic kuculmuyordu; WP-811'den beri
    // cagriliyor (yukaridaki `_markProcessedOnServer`).
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
