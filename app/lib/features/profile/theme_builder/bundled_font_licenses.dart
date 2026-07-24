import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// WP-297 (ADR-4): uygulamayla paketlenen fontların lisans kaydı.
///
/// SIL OFL 1.1, font yazılımı dağıtıldığında **lisans metninin de** birlikte
/// dağıtılmasını şart koşar. Metinler `assets/fonts/LICENSES/` altında ve
/// buradan Flutter'ın `LicenseRegistry`'sine eklenir; böylece `showLicensePage`
/// (ya da ileride eklenecek "Açık kaynak lisansları" ekranı) onları gösterir.
///
/// ⚠️ Uygulamada bugün lisans sayfasına giden bir giriş **yok** — yani metinler
/// APK'da ve kayıtta duruyor ama kullanıcı arayüzünden erişilemiyor. Bu, OFL'nin
/// "birlikte dağıt" şartını karşılar; görünür bir lisans ekranı ayrı iş.
const Map<String, String> kBundledFontLicenseAssets = <String, String>{
  'Inter': 'assets/fonts/LICENSES/Inter-OFL.txt',
  'Literata': 'assets/fonts/LICENSES/Literata-OFL.txt',
  'JetBrains Mono': 'assets/fonts/LICENSES/JetBrainsMono-OFL.txt',
};

/// Kayıt tembeldir: `Stream` yalnız lisans sayfası açıldığında tüketilir.
void registerBundledFontLicenses({AssetBundle? bundle}) {
  final assets = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() async* {
    for (final entry in kBundledFontLicenseAssets.entries) {
      try {
        final text = await assets.loadString(entry.value);
        yield LicenseEntryWithLineBreaks(<String>[entry.key], text);
      } catch (error) {
        // Lisans metni okunamazsa uygulama çökmemeli; yalnız o giriş atlanır.
        debugPrint('WP-297: ${entry.key} lisans metni okunamadı: $error');
      }
    }
  });
}
