import 'package:flutter/material.dart';

/// Yanlış kanal/backend eşleşmesinde hiçbir veri servisini başlatmadan görünen
/// minimal hata yüzeyi. Hata kodu secret veya URL içermez.
///
/// 🔴 WP-594: metinler **bilerek gömülü ve iki dilli**. WP-294 bu ekranı
/// `AppLocalizations`e bağlamıştı; ölçüm o kararın iki ayrı hatası olduğunu
/// gösterdi (Windows sürümü bilerek bozuk `--dart-define` ile derlenip
/// çalıştırıldı, çizilen kare `RenderRepaintBoundary.toImage()` ile alındı):
///
/// 1. Türkçe Windows'ta ekran **İngilizce** çıkıyordu. Uygulamanın geri kalanı
///    dili `resolvePreferredAppLocale` ile seçer; bu ekran kendi
///    `MaterialApp`'ini kurduğu için o sözleşmenin dışında kalıyor ve
///    `basicLocaleListResolution` ile `en`e düşüyordu. Yani ekranın tek işi
///    olan "kullanıcıya derdini anlatmak" tam da Türk kullanıcıda yarım
///    kalıyordu.
/// 2. Bu ekran **derlemenin bozuk olduğu** durumda çalışır. O anda katalog ve
///    delegate zincirinin sağlam olduğunu varsaymak, hata yüzeyini korumaya
///    çalıştığı arızaya bağımlı yapar. `Localizations` çözülemezse alt ağaç
///    boş kutuya döner ve kullanıcı gerçekten hiçbir şey görmez.
///
/// Bu yüzden burada `AppLocalizations`, `MaterialApp` ve `Scaffold` **yok**:
/// ekran yalnız `Directionality` + `ColoredBox` ile çizilir, hiçbir delegate
/// yüklenmesini beklemez. Metin iki dilde birden basılır (TR üstte, EN altta)
/// — dil seçimi hiç yapılmadığı için yanlış seçilemez.
///
/// `scripts/l10n_audit.py` içindeki `LITERAL_EXEMPTIONS` kaydı bu dosyanın
/// gömülü Türkçe metnini kasıtlı kılar; kayıt silinirse kapı kırmızıya döner.
class BuildConfigurationErrorApp extends StatelessWidget {
  const BuildConfigurationErrorApp({super.key, required this.errorCode});

  final String errorCode;

  /// Türkçe başlık — `app_tr.arb: buildYapilandirmaHatasiBasligi` ile aynı.
  static const String titleTr = 'Güvenli yapılandırma doğrulanamadı';

  /// İngilizce başlık — `app_en.arb: buildYapilandirmaHatasiBasligi` ile aynı.
  static const String titleEn = 'Secure configuration could not be verified';

  static const String bodyTr =
      'Yanlış ortama veri yazmamak için bağlantı kapatıldı. Uygulamayı doğru '
      'kanal ve backend ayarlarıyla yeniden derleyin.';

  static const String bodyEn =
      'The connection was closed to avoid writing data to the wrong '
      'environment. Rebuild the app with the correct channel and backend '
      'settings.';

  /// Tanı satırı: kod dilden bağımsızdır, etiket iki dilde birden verilir.
  static String diagnosticLine(String errorCode) =>
      'Tanı kodu · Diagnostic code: $errorCode';

  static const Color _background = Color(0xFF160E16);
  static const Color _accent = Color(0xFFFFB4AB);
  static const Color _primaryText = Color(0xFFFFFFFF);
  static const Color _secondaryText = Color(0xB3FFFFFF);
  static const Color _mutedText = Color(0x8AFFFFFF);

  @override
  Widget build(BuildContext context) {
    // Directionality elle veriliyor: `MaterialApp` yok, bu ekran hiçbir
    // yerelleştirme yüklenmesini beklemeden ilk karede çizilmek zorunda.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: _secondaryText,
          fontSize: 14,
          height: 1.4,
          decoration: TextDecoration.none,
        ),
        child: ColoredBox(
          color: _background,
          child: SafeArea(
            child: Center(
              // Küçük/ölçeklenmiş pencerede taşma yerine kaydırma: masaüstü
              // penceresi kullanıcının bıraktığı boyutta açılır, bu ekranın
              // okunurluğu o boyuta bağlı olamaz.
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.gpp_bad_outlined,
                        color: _accent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const _Message(
                        title: titleTr,
                        body: bodyTr,
                        titleSize: 20,
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 96,
                        child: Divider(color: _mutedText, height: 1),
                      ),
                      const SizedBox(height: 20),
                      const _Message(
                        title: titleEn,
                        body: bodyEn,
                        titleSize: 17,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        diagnosticLine(errorCode),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _mutedText,
                          fontFamily: 'monospace',
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.titleSize,
  });

  final String title;
  final String body;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: BuildConfigurationErrorApp._primaryText,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: BuildConfigurationErrorApp._secondaryText,
            fontSize: 14,
            height: 1.4,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
