import 'package:flutter/material.dart';

/// Yanlış kanal/backend eşleşmesinde hiçbir veri servisini başlatmadan görünen
/// minimal hata yüzeyi. Hata kodu secret veya URL içermez.
class BuildConfigurationErrorApp extends StatelessWidget {
  const BuildConfigurationErrorApp({super.key, required this.errorCode});

  final String errorCode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
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
                    const Text(
                      'Güvenli yapılandırma doğrulanamadı',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Yanlış ortama veri yazmamak için bağlantı kapatıldı. '
                      'Uygulamayı doğru kanal ve backend ayarlarıyla yeniden derleyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'Tanı kodu: $errorCode',
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
      ),
    );
  }
}
