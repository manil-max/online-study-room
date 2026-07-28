import 'package:flutter/material.dart';

import '../../core/config/app_build_manifest.dart';
import '../../core/config/build_identity_card.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../l10n/app_localizations.dart';
import '../desktop/desktop_surface.dart';

/// Ayarlar → Hakkında.
///
/// WP-419: Derleme kimliği (kanal / backend project-ref / commit / migration
/// başı) daha önce sürüm notları ekranının en üstünde son kullanıcıya açıktı.
/// Kart silinmedi, buraya taşındı: varsayılan yalnız sürüm adı görünür, teknik
/// satırlar dokununca açılır. Destek yazışmasında "sürümün ne?" sorusu
/// cevaplanabilir kalır.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.buildManifest});

  final AppBuildManifest? buildManifest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: getSafePadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 24),
        ),
        children: [
          DesktopReadingBody(
            maxWidth: DesktopSurface.readingWidth,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                BuildIdentityCard(
                  manifest: buildManifest ?? AppBuildManifest.currentOrNull,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
