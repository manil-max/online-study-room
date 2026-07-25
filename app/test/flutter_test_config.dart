import 'dart:async';

// `Uint8List` ve `FlutterError` ikisi de foundation'dan geliyor; ayrıca
// `dart:typed_data` almak `unnecessary_import` uyarısı üretir.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden karşılaştırmasına **platformlar arası raster payı** tanır.
///
/// 🔴 Neden gerekiyor: goldenlar Windows'ta üretiliyor, CI ve release job'ı
/// **ubuntu** runner'da koşuyor. Aynı `CustomPaint` çıktısı iki platformda
/// bit-bit aynı değil — kenar yumuşatma ve gradyan yuvarlaması farklı.
/// İlk ubuntu koşumunda 13 goldenın 12'si **%0.12–%0.14** farkla düştü
/// (run 30162826092), görüntüler doğru olduğu hâlde. Bu sınır olmasa release
/// job'ı APK'ya hiç gelemez; `beta-v4304`/`beta-v4305` de tam bu noktada,
/// test paketinde düşmüştü (`docs/BETA-YAYIN-ARIZA-NIHAI-RAPORU-2026-07-23.md`).
///
/// Sınır **ölçülen sapmanın ~3.5 katı**, gerçek bir görsel regresyonun çok
/// altında: bu goldenlar tam ekran tema anlık görüntüleri ve taç ızgaraları,
/// yani anlamlı bir değişiklik yüzdelerce fark üretir. Kırmızı-yeşil kanıtı
/// `progress.md` WP-294/beta-v4309 kaydında.
///
/// ⚠️ Bu değeri **yükselterek** bir goldenı yeşile almak yasak: sınır
/// platform payı içindir, ürün değişikliğini gizlemek için değil. Golden
/// kırmızıysa doğru yol görüntüye bakmaktır (`failures/` klasörü).
const double _kMaxPlatformRasterDiff = 0.005; // 0.5%

class _PlatformTolerantComparator extends LocalFileComparator {
  _PlatformTolerantComparator(super.testFile, this.maxDiff);

  final double maxDiff;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= maxDiff) {
      // Geçen karşılaştırmanın geçici görüntülerini tutma.
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // `goldenFileComparator` her test dosyası için o dosyanın dizinine bağlı
  // kurulur; `basedir`'i ondan devralmak goldenların `goldens/` alt klasörüne
  // doğru çözülmesini korur (test dosyaları farklı dizinlerde).
  final existing = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _PlatformTolerantComparator(
    Uri.parse('${existing.basedir}test.dart'),
    _kMaxPlatformRasterDiff,
  );
  await testMain();
}
