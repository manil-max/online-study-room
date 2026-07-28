import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'app_build_manifest.dart';

/// Derleme kimliği kartı.
///
/// WP-419: Bu kart daha önce **sürüm notları** ekranının en üstünde, son
/// kullanıcıya açık duruyordu — kanal/backend project-ref/commit/migration başı
/// normal kullanıcının ilk gördüğü şeydi. Kart silinmedi, **Ayarlar → Hakkında**
/// altına taşındı: varsayılan yalnız sürüm adı (`1.0.55`) görünür, teknik
/// satırlar dokununca açılır. Destekte "sürümün ne?" sorusu cevaplanabilir
/// kalır, ama proje kimliği kullanıcı yüzeyine sızmaz.
class BuildIdentityCard extends StatefulWidget {
  const BuildIdentityCard({
    super.key,
    required this.manifest,
    this.initiallyExpanded = false,
  });

  final AppBuildManifest? manifest;

  /// Yalnız test/hata ayıklama için; üretimde varsayılan kapalıdır.
  final bool initiallyExpanded;

  @override
  State<BuildIdentityCard> createState() => _BuildIdentityCardState();
}

class _BuildIdentityCardState extends State<BuildIdentityCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    // WP-294: burada da elle `languageCode == 'tr'` üçlemesi vardı; DE/AR
    // kullanıcısı İngilizce görüyordu. Metinler artık katalogdan geliyor.
    final l10n = AppLocalizations.of(context);
    final value = widget.manifest;

    if (value == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.fingerprint),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.buildTaniTanimsiz)),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: const Key('build-identity-toggle'),
            leading: const Icon(Icons.fingerprint),
            title: Text(l10n.buildTaniSurum),
            subtitle: Text(
              value.versionName,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              semanticLabel: l10n.buildTaniBasligi,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.buildTaniBasligi,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  _IdentityRow(
                    label: l10n.buildTaniKanal,
                    value: value.channelName,
                  ),
                  _IdentityRow(
                    label: l10n.buildTaniSurum,
                    value: '${value.versionName}+${value.buildNumber}',
                  ),
                  _IdentityRow(
                    label: 'Backend',
                    value:
                        '${value.environmentName} · ${value.redactedBackendRef}',
                  ),
                  _IdentityRow(label: 'Commit', value: value.shortCommit),
                  _IdentityRow(
                    label: l10n.buildTaniMigrationBasi,
                    value: value.migrationHead,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
