/// WP-365: V3 (çoklu grup presence + çoklu cihaz sayaç senkronu) rollout
/// anahtarları.
///
/// 🔴 Önceki durum: anahtarlar **sabit koddu** — `presenceProjectionMode` hep
/// `legacy`, `globalTimerMode` hep `disabled`. Ne `--dart-define` ne ortam
/// dosyası; yalnız testler `overrideWith` ile açabiliyordu. Yani "çoklu cihaz
/// senkronu çalışmıyor" bir hata değil, **hiç açılmamış bir özellikti** ve
/// denemek için bile kod değiştirip yeni bir build çıkarmak gerekiyordu.
///
/// Artık tek okuma noktası burasıdır ve üç kademe **birbirinden bağımsız**
/// açılır: biri sorun çıkarırsa diğerleri kapanmak zorunda kalmaz.
///
/// ⚠️ Uzaktan kapatma yolu **yoktur** (sunucu tarafı flag altyapısı kurulmadı).
/// Geri dönüş = değeri kapatan yeni bir sürüm. Bu, stable'da açık yayınlamanın
/// bilinen bedelidir.
library;

import '../../data/providers/global_timer_providers.dart';
import '../../data/repositories/presence_repository.dart';

/// Build zamanı override:
/// `--dart-define=ROLLOUT_PRESENCE_MODE=legacy|shadow|projection`
const String _presenceModeName = String.fromEnvironment(
  'ROLLOUT_PRESENCE_MODE',
  defaultValue: 'shadow',
);

/// Build zamanı override:
/// `--dart-define=ROLLOUT_GLOBAL_TIMER_MODE=disabled|shadow|foregroundMirror`
const String _globalTimerModeName = String.fromEnvironment(
  'ROLLOUT_GLOBAL_TIMER_MODE',
  defaultValue: 'foregroundMirror',
);

/// Tanınmayan bir değer geldiğinde düşülecek **güvenli** kademeler.
const PresenceProjectionMode kSafePresenceMode = PresenceProjectionMode.legacy;
const GlobalTimerMode kSafeGlobalTimerMode = GlobalTimerMode.disabled;

abstract final class RolloutConfig {
  /// Presence okuma/yazma kademesi.
  ///
  /// Varsayılan **`shadow`**, bilerek `projection` değil: shadow hem legacy
  /// `presence` tablosuna hem server-derived projeksiyona yazar ve ikisini
  /// birleştirerek okur. Doğrudan `projection`'a geçmek, **eski sürümde kalan
  /// kullanıcıların** (yalnız legacy tabloyu okurlar) yeni sürümdekileri
  /// görememesine yol açardı. Filo tek sürüme geçtiğinde `projection`'a
  /// yükseltilebilir.
  static PresenceProjectionMode get presenceMode =>
      _parsePresenceMode(_presenceModeName);

  /// Çoklu cihaz sayaç senkronu kademesi.
  ///
  /// `foregroundMirror` gerçek aynalamayı açar: aynı hesapta bir cihazda
  /// başlatılan çalışma diğerinde görünür ve oradan durdurulabilir. `shadow`
  /// yalnız ölçer, kullanıcıya bir şey kazandırmaz.
  static GlobalTimerMode get globalTimerMode =>
      _parseGlobalTimerMode(_globalTimerModeName);

  static PresenceProjectionMode _parsePresenceMode(String name) {
    for (final mode in PresenceProjectionMode.values) {
      if (mode.name == name) return mode;
    }
    return kSafePresenceMode;
  }

  static GlobalTimerMode _parseGlobalTimerMode(String name) {
    for (final mode in GlobalTimerMode.values) {
      if (mode.name == name) return mode;
    }
    return kSafeGlobalTimerMode;
  }

  /// Test/denetim için: verilen adların gerçekten tanınıp tanınmadığı.
  static bool isKnownPresenceMode(String name) =>
      PresenceProjectionMode.values.any((mode) => mode.name == name);

  static bool isKnownGlobalTimerMode(String name) =>
      GlobalTimerMode.values.any((mode) => mode.name == name);

  /// Yapılandırılmış ham adlar — yanlış yazılmış bir `--dart-define` sessizce
  /// güvenli kademeye düşmesin diye testte kontrol edilir.
  static const String configuredPresenceModeName = _presenceModeName;
  static const String configuredGlobalTimerModeName = _globalTimerModeName;
}
