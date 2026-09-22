import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import '../../core/config/distribution_channel.dart';

/// WP-913: Play sürümünde Google'ın kendi "güncelleme var" akışı (flexible).
///
/// Sorun: Play'e yeni sürüm yüklendiğinde kullanıcı Play uygulamasını kendisi
/// açmadan güncellemeyi görmüyordu. Android'in "Play In-App Updates" API'si tam
/// bunun içindir: uygulama açılırken Play'e sorar, güncelleme varsa Google'ın
/// kendi sayfasını gösterir, indirmeyi Play yapar.
///
/// **Yalnız Play + Android.** GitHub sideload (`githubStable` / `githubBeta`),
/// Windows, Microsoft Store ve App Store kanallarında bu dosyadaki hiçbir
/// satır eklentiye dokunmaz — kapı [PlayInAppUpdate.appliesTo]'dur ve
/// `play_migration.dart` ile aynı biçimi kullanır. Mevcut GitHub güncelleyicisi
/// (`updater_service.dart`) ve App Store yolu olduğu gibi kalır.
///
/// **Asla düşürmez:** sideload APK'da, Play Services olmayan cihazda veya
/// emülatörde eklenti `PlatformException` atar. Buradaki her çağrı try/catch
/// içindedir, hiçbir hata yeniden fırlatılmaz ve ilk kare beklemez
/// (`unawaited`).
class PlayInAppUpdate {
  const PlayInAppUpdate._();

  /// Kontrol bu derleme/platformda çalışır mı?
  static bool appliesTo({
    required DistributionChannel channel,
    bool isWeb = false,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    return !isWeb &&
        platform == TargetPlatform.android &&
        channel == DistributionChannel.play;
  }
}

/// [PlayInAppUpdateGateway.checkForUpdate] sonucunun kullandığımız kadarı.
class PlayUpdateSnapshot {
  const PlayUpdateSnapshot({
    required this.updateAvailable,
    required this.flexibleAllowed,
  });

  /// Play'de kurulu sürümden yeni bir sürüm var mı?
  final bool updateAvailable;

  /// Esnek (arka planda indiren) akış bu güncelleme için serbest mi?
  final bool flexibleAllowed;
}

/// Eklenti sınırı — testler gerçek `InAppUpdate`'e hiç dokunmasın diye.
abstract class PlayInAppUpdateGateway {
  Future<PlayUpdateSnapshot> checkForUpdate();

  /// İndirmeyi başlatır. `true` ⇒ indirme **bitti** (Play `DOWNLOADED` dedi);
  /// `false` ⇒ kullanıcı vazgeçti veya indirme tamamlanmadı.
  Future<bool> startFlexibleUpdate();

  /// İndirileni kurar; Play bu sırada uygulamayı yeniden başlatır.
  Future<void> completeFlexibleUpdate();
}

/// Gerçek eklenti. Yalnız Play + Android derlemesinde çağrılır.
class PlayStoreInAppUpdateGateway implements PlayInAppUpdateGateway {
  const PlayStoreInAppUpdateGateway();

  @override
  Future<PlayUpdateSnapshot> checkForUpdate() async {
    final info = await InAppUpdate.checkForUpdate();
    return PlayUpdateSnapshot(
      updateAvailable:
          info.updateAvailability == UpdateAvailability.updateAvailable,
      flexibleAllowed: info.flexibleUpdateAllowed,
    );
  }

  @override
  Future<bool> startFlexibleUpdate() async {
    // Eklenti indirme bitene (`InstallStatus.DOWNLOADED`) kadar beklemeyi
    // kendi tarafında yapar; `success` = indirilen paket kuruluma hazır.
    return await InAppUpdate.startFlexibleUpdate() == AppUpdateResult.success;
  }

  @override
  Future<void> completeFlexibleUpdate() => InAppUpdate.completeFlexibleUpdate();
}

/// Tek turun sonucu — hepsi sessizdir, hiçbiri kullanıcıya hata göstermez.
enum PlayUpdateOutcome {
  /// Play kanalı / Android değil: eklentiye **hiç** dokunulmadı.
  notApplicable,

  /// Play "güncelleme yok" dedi.
  noUpdate,

  /// Güncelleme var ama esnek akış serbest değil (ör. yalnız zorunlu akış).
  notAllowed,

  /// Kullanıcı Google'ın sayfasında vazgeçti ya da indirme tamamlanmadı.
  declined,

  /// İndirme bitti; kurulum KULLANICI onayını bekler.
  ///
  /// 🔴 WP-914: kurulum indirme biter bitmez çağrılmıyor. Play kurarken
  /// uygulamayı yeniden başlatır; bu bir çalışma sayacı ve yeniden başlatma
  /// koşan seansın ortasına denk gelebilir. Karar kullanıcının: şerit çıkar,
  /// "Kur"a basınca [completePlayUpdate] çağrılır.
  downloaded,

  /// Eklenti hata attı (sideload APK, Play Services yok…) — yutuldu.
  failed,
}

/// Saf akış: kapı → kontrol → esnek indirme → kurulum. Hiç `throw` etmez.
Future<PlayUpdateOutcome> runPlayInAppUpdate({
  required PlayInAppUpdateGateway gateway,
  required DistributionChannel channel,
  bool isWeb = false,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  if (!PlayInAppUpdate.appliesTo(
    channel: channel,
    isWeb: isWeb,
    platform: platform,
  )) {
    return PlayUpdateOutcome.notApplicable;
  }
  try {
    final info = await gateway.checkForUpdate();
    if (!info.updateAvailable) return PlayUpdateOutcome.noUpdate;
    if (!info.flexibleAllowed) return PlayUpdateOutcome.notAllowed;
    // İndirme bitmeden kurulum çağrılmaz: `completeFlexibleUpdate` indirilmiş
    // paket yokken hata atar ve kullanıcıyı boş yere yeniden başlatır.
    if (!await gateway.startFlexibleUpdate()) return PlayUpdateOutcome.declined;
    return PlayUpdateOutcome.downloaded;
  } catch (_) {
    return PlayUpdateOutcome.failed;
  }
}

/// Testte sahte geçit verilebilsin diye; varsayılan gerçek eklentidir.
final playInAppUpdateGatewayProvider = Provider<PlayInAppUpdateGateway>(
  (ref) => const PlayStoreInAppUpdateGateway(),
);

/// WP-914: kullanıcı şeritteki "Kur"a bastı — indirilen paket şimdi kurulur.
/// Play uygulamayı yeniden başlatır. Hiç `throw` etmez.
Future<void> completePlayUpdate(PlayInAppUpdateGateway gateway) async {
  try {
    await gateway.completeFlexibleUpdate();
  } catch (_) {
    // Kurulum başarısızsa kullanıcı Play'den güncelleyebilir; hata gösterilmez.
  }
}

/// Kurulum kullanıcı onayı bekliyor mu? (`true` ⇒ kabuk küçük bir şerit gösterir)
class PlayUpdateRestartHint extends Notifier<bool> {
  @override
  bool build() => false;

  void markReady() => state = true;
}

final playUpdateRestartHintProvider =
    NotifierProvider<PlayUpdateRestartHint, bool>(PlayUpdateRestartHint.new);

/// Süreç başına tek kontrol. Kabuk yeniden kurulsa (tema/dil değişimi, geri
/// dönüş) bile Play'e ikinci kez sorulmaz.
bool _checkedThisProcess = false;

/// Yalnız test: süreç bayrağını sıfırlar.
@visibleForTesting
void debugResetPlayInAppUpdateCheck() => _checkedThisProcess = false;

/// Yalnız test: kanal derleme zamanında sabittir, testte ezilir. `null` →
/// gerçek derleme kanalı.
@visibleForTesting
DistributionChannel? debugPlayInAppUpdateChannel;

/// Yalnız test: platform kararını ezmek için. `null` → gerçek platform.
/// (`debugDefaultTargetPlatformOverride` kullanılmaz: widget testi gövde
/// bitiminde o değişkenin sıfırlanmasını şart koşar.)
@visibleForTesting
TargetPlatform? debugPlayInAppUpdatePlatform;

/// WP-913: ana kabuk (`HomeShell`) kurulduğunda izlenir — `notificationAutoAsk`
/// ile aynı yer ve aynı söz: ilk kareyi bekletmez, hata kabuğu düşürmez.
final playInAppUpdateProvider = Provider<void>((ref) {
  // 🔴 Kanal kararı eklenti okunmadan ÖNCE: Play dışı derlemede tek satır bile
  // çalışmamalı (WP-614 dersi: kapı kodun kendi çözümleyicisinden geçmeli).
  final channel = debugPlayInAppUpdateChannel ?? DistributionConfig.current;
  final platform = debugPlayInAppUpdatePlatform ?? defaultTargetPlatform;
  if (!PlayInAppUpdate.appliesTo(
    channel: channel,
    isWeb: kIsWeb,
    platform: platform,
  )) {
    return;
  }
  if (_checkedThisProcess) return;
  _checkedThisProcess = true;
  final gateway = ref.read(playInAppUpdateGatewayProvider);
  unawaited(() async {
    final outcome = await runPlayInAppUpdate(
      gateway: gateway,
      channel: channel,
      isWeb: kIsWeb,
      platform: platform,
    );
    // İndirme bitti; kurulumu kullanıcı başlatır (WP-914).
    if (outcome == PlayUpdateOutcome.downloaded && ref.mounted) {
      ref.read(playUpdateRestartHintProvider.notifier).markReady();
    }
  }());
});
