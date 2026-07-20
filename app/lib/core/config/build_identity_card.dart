import 'package:flutter/material.dart';

import 'app_build_manifest.dart';

class BuildIdentityCard extends StatelessWidget {
  const BuildIdentityCard({super.key, required this.manifest});

  final AppBuildManifest? manifest;

  @override
  Widget build(BuildContext context) {
    final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
    final value = manifest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 10),
                Text(
                  isTurkish ? 'Derleme tanısı' : 'Build diagnostics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (value == null)
              Text(
                isTurkish
                    ? 'Kanal/backend kimliği bu test derlemesinde tanımlı değil.'
                    : 'Channel/backend identity is not defined in this test build.',
              )
            else ...[
              _IdentityRow(
                label: isTurkish ? 'Kanal' : 'Channel',
                value: value.channelName,
              ),
              _IdentityRow(
                label: 'Backend',
                value: '${value.environmentName} · ${value.redactedBackendRef}',
              ),
              _IdentityRow(label: 'Commit', value: value.shortCommit),
              _IdentityRow(
                label: isTurkish ? 'Migration başı' : 'Migration head',
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
