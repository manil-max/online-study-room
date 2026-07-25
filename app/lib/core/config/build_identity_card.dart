import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'app_build_manifest.dart';

class BuildIdentityCard extends StatelessWidget {
  const BuildIdentityCard({super.key, required this.manifest});

  final AppBuildManifest? manifest;

  @override
  Widget build(BuildContext context) {
    // WP-294: burada da elle `languageCode == 'tr'` üçlemesi vardı; DE/AR
    // kullanıcısı İngilizce görüyordu. Metinler artık katalogdan geliyor.
    final l10n = AppLocalizations.of(context);
    final value = manifest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fingerprint),
                const SizedBox(width: 10),
                Text(
                  l10n.buildTaniBasligi,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (value == null)
              Text(l10n.buildTaniTanimsiz)
            else ...[
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
                value: '${value.environmentName} · ${value.redactedBackendRef}',
              ),
              _IdentityRow(label: 'Commit', value: value.shortCommit),
              _IdentityRow(
                label: l10n.buildTaniMigrationBasi,
                value: value.migrationHead,
              ),
            ],
          ],
        ),
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
