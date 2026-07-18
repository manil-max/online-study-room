import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Grup kartları için "henüz grupta değilsin" yer tutucusu.
class GroupCardShell extends StatelessWidget {
  const GroupCardShell({
    super.key,
    required this.title,
    this.onCreateGroup,
    this.onJoinGroup,
  });

  final String title;
  final VoidCallback? onCreateGroup;
  final VoidCallback? onJoinGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // WP-172: iç SingleChildScrollView yok — Gruplar ListView kaydırmasını yutmasın.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).homeBirGrubaKatilincaBurada,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (onCreateGroup != null || onJoinGroup != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onCreateGroup != null)
                    FilledButton.tonalIcon(
                      onPressed: onCreateGroup,
                      icon: const Icon(Icons.add),
                      label: Text(
                        AppLocalizations.of(context).homeGrupOlustur,
                      ),
                    ),
                  if (onJoinGroup != null)
                    OutlinedButton.icon(
                      onPressed: onJoinGroup,
                      icon: const Icon(Icons.login),
                      label: Text(AppLocalizations.of(context).homeKodaKatil),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
