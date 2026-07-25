import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Yanlış kanal/backend eşleşmesinde hiçbir veri servisini başlatmadan görünen
/// minimal hata yüzeyi. Hata kodu secret veya URL içermez.
///
/// WP-294: metinler artık gömülü değil. Bu ekran kendi `MaterialApp`'ini
/// kurduğu için l10n delegate'lerini **kendisi** bağlar; uygulamanın normal
/// `MaterialApp`'i hiç kurulmadan gösterildiği için delegate'leri devralamıyor.
/// Delegate yalnız paketteki katalogları okur — hiçbir servis/ağ başlatmaz,
/// yani ekranın "hiçbir şey başlatma" sözü bozulmaz.
class BuildConfigurationErrorApp extends StatelessWidget {
  const BuildConfigurationErrorApp({super.key, required this.errorCode});

  final String errorCode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            backgroundColor: const Color(0xFF160E16),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.gpp_bad_outlined,
                          color: Color(0xFFFFB4AB),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.buildYapilandirmaHatasiBasligi,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.buildYapilandirmaHatasiGovdesi,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          l10n.buildYapilandirmaHatasiKodu(errorCode),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
