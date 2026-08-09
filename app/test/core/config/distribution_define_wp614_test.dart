import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';

/// WP-614 — **derleme öncesi dağıtım kanalı kapısı.**
///
/// 🔴 `distribution_channel.dart` yıllardır şunu yazıyordu: *"Windows'ta
/// Android'in `--flavor` zorlaması yoktur, yani `microsoftStore` kanalını
/// yalnız define seçer... Bu yüzden Faz H'de build öncesi bir kapı testi
/// şarttır."* **O kapı hiç yazılmamıştı.** Sonuç ölçüldü: `windows-release.yml`
/// her koşumda `DISTRIBUTION_CHANNEL='windows'` yazıyordu, `--store` yalnız
/// paketlemeyi değiştiriyordu; yani Microsoft Store'dan kuran kullanıcı
/// "yeni sürüm var, ZIP indir" diyaloğu görecekti. Bu hem mağaza kuralına
/// aykırı hem de çalışmayan bir yol: mağaza paketi kendini o ZIP'le
/// güncelleyemez.
///
/// Bu dosya iki iş yapar:
///
/// 1. **Her koşumda** (define olmadan da): enum'daki her kanalın adı geçerli
///    bir define değeridir. Yeni bir kanal eklenip `_parseDefine`'a
///    yazılmazsa, o define sessizce platform varsayımına düşerdi.
/// 2. **Release derlemesinde** (`ENFORCE_CURRENT_BUILD_MANIFEST=true` ile,
///    `windows-release.yml` guard adımı): derlemeye giren define BİLİNEN bir
///    değer mi ve mağaza kanalıysa sideload updater gerçekten kapalı mı.
void main() {
  const enforce = bool.fromEnvironment(
    'ENFORCE_CURRENT_BUILD_MANIFEST',
    defaultValue: false,
  );
  const define = String.fromEnvironment(
    'DISTRIBUTION_CHANNEL',
    defaultValue: '',
  );

  group('kanal adı ↔ define sözleşmesi (her koşumda)', () {
    test('her kanalın adı geçerli bir define değeridir', () {
      // 🔴 Aşağıdaki release iddiası `channel.name == define` karşılaştırmasına
      // dayanıyor. O karşılaştırmanın anlamlı olması için enum adı ile
      // çözümleyicinin tanıdığı dize aynı olmalı. Yeni bir kanal eklenip
      // `_parseDefine`'a yazılmazsa burası kırmızıya düşer.
      for (final channel in DistributionChannel.values) {
        expect(
          DistributionConfig.resolve(
            distributionDefine: channel.name,
            legacyChannel: 'stable',
            flutterAppFlavor: null,
            isWeb: false,
            platform: TargetPlatform.windows,
          ),
          channel,
          reason:
              '`${channel.name}` define olarak verildiğinde çözümleyici bu '
              'kanala varmıyor; CI o değeri yazsa bile derleme sessizce başka '
              'bir kanala düşer.',
        );
      }
    });

    test('tanınmayan define Windows varsayımına düşer (kapının varlık sebebi)', () {
      // Bu davranış BELGELENİYOR, savunulmuyor: yanlış yazılmış bir define
      // (`microsoft-store`, `MicrosoftStore`, ...) hata vermez, `windows`
      // olur ve sideload updater AÇIK kalır. Tam bu yüzden aşağıdaki release
      // kapısı zorunludur.
      final fallback = DistributionConfig.resolve(
        distributionDefine: 'microsoft-store',
        legacyChannel: 'stable',
        flutterAppFlavor: null,
        isWeb: false,
        platform: TargetPlatform.windows,
      );
      expect(fallback, DistributionChannel.windows);
      expect(DistributionConfig.allowsSideloadUpdatesFor(fallback), isTrue);
    });
  });

  group('release derlemesi (ENFORCE_CURRENT_BUILD_MANIFEST=true)', () {
    test('DISTRIBUTION_CHANNEL define edilmiş olmalı', () {
      if (!enforce) return;
      expect(
        define.trim(),
        isNotEmpty,
        reason:
            'Release derlemesine kanal define\'ı verilmemiş. Windows\'ta '
            'flavor zorlaması yoktur; define yoksa kanal `windows` olur ve '
            'mağaza paketi bile sideload updater ile çıkar.',
      );
    });

    test('define BİLİNEN bir kanal (sessiz geri düşüş yok)', () {
      if (!enforce) return;
      expect(
        DistributionConfig.current.name,
        define.trim(),
        reason:
            'Verilen define (`$define`) kod tarafından tanınmadı; derleme '
            'sessizce `${DistributionConfig.current.name}` kanalına düştü. '
            'Yazım hatası bir sürümü mağaza kuralına aykırı hâle getirir.',
      );
    });

    test('mağaza kanalında sideload updater KAPALI', () {
      if (!enforce) return;
      const storeChannels = {
        DistributionChannel.play,
        DistributionChannel.microsoftStore,
      };
      if (!storeChannels.contains(DistributionConfig.current)) return;
      expect(
        DistributionConfig.allowsSideloadUpdates,
        isFalse,
        reason:
            'Mağaza paketi mağaza dışı güncelleme yolunu AÇIK taşıyor. '
            'Kullanıcı "yeni sürüm var, ZIP indir" diyaloğu görür; mağaza '
            'kuralına aykırıdır ve indirdiği paketi kuramaz.',
      );
      expect(
        DistributionConfig.expectsInstallPackagesPermission,
        isFalse,
        reason: 'Mağaza paketi harici kurulum izni beklememeli.',
      );
    });
  });
}
