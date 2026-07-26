import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../l10n/app_localizations.dart';

/// The only mutation surface for the account-wide primary group preference.
/// The server owns both the cooldown and the compare-and-swap revision.
class PrimaryGroupSelectorCard extends ConsumerStatefulWidget {
  const PrimaryGroupSelectorCard({super.key});

  @override
  ConsumerState<PrimaryGroupSelectorCard> createState() =>
      _PrimaryGroupSelectorCardState();
}

class _PrimaryGroupSelectorCardState
    extends ConsumerState<PrimaryGroupSelectorCard> {
  String? _savingGroupId;

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(userGroupsProvider);
    final preference = ref.watch(primaryGroupPreferenceProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.primaryGroupTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.primaryGroupHelp,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 8),
            groups.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => _RetryState(
                message: l10n.primaryGroupLoadFailed,
                onRetry: _retry,
              ),
              data: (items) => preference.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _RetryState(
                  message: l10n.primaryGroupLoadFailed,
                  onRetry: _retry,
                ),
                data: (value) => _buildGroups(context, items, value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroups(
    BuildContext context,
    List<StudyGroup> groups,
    PrimaryGroupPreference preference,
  ) {
    final l10n = AppLocalizations.of(context);
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(l10n.primaryGroupEmpty),
      );
    }

    final now = DateTime.now();
    final nextAllowed = preference.nextChangeAllowedAt?.toLocal();
    final locked = nextAllowed != null && now.isBefore(nextAllowed);
    return Column(
      children: [
        if (locked)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l10n.primaryGroupLockedUntil(
                _formatDateTime(context, nextAllowed),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final group in groups)
          _PrimaryGroupTile(
            group: group,
            selected: group.id == preference.primaryGroupId,
            enabled: !locked || group.id == preference.primaryGroupId,
            saving: _savingGroupId == group.id,
            onTap: () => _select(group, preference),
          ),
      ],
    );
  }

  String _formatDateTime(BuildContext context, DateTime value) {
    final material = MaterialLocalizations.of(context);
    return '${material.formatFullDate(value)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  Future<void> _select(
    StudyGroup group,
    PrimaryGroupPreference preference,
  ) async {
    if (_savingGroupId != null || group.id == preference.primaryGroupId) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.primaryGroupConfirmTitle),
        content: Text(l10n.primaryGroupConfirmBody(group.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.classroomVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.primaryGroupConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _savingGroupId = group.id);
    try {
      await ref
          .read(groupRepositoryProvider)
          .setPrimaryGroup(
            userId: user.id,
            groupId: group.id,
            expectedRevision: preference.selectionRevision,
          );
      ref.invalidate(primaryGroupPreferenceProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.primaryGroupUpdated)));
      }
    } on GroupException {
      if (mounted) {
        ref.invalidate(primaryGroupPreferenceProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.primaryGroupChangeFailed)));
      }
    } finally {
      if (mounted) setState(() => _savingGroupId = null);
    }
  }

  void _retry() {
    ref.invalidate(userGroupsProvider);
    ref.invalidate(primaryGroupPreferenceProvider);
  }
}

class _PrimaryGroupTile extends ConsumerWidget {
  const _PrimaryGroupTile({
    required this.group,
    required this.selected,
    required this.enabled,
    required this.saving,
    required this.onTap,
  });

  final StudyGroup group;
  final bool selected;
  final bool enabled;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = group.avatarPath == null
        ? null
        : ref
              .watch(
                groupAvatarUrlProvider(
                  GroupAvatarRequest(
                    path: group.avatarPath!,
                    updatedAt: group.avatarUpdatedAt,
                  ),
                ),
              )
              .value;
    return Semantics(
      selected: selected,
      child: ListTile(
        enabled: enabled && !saving,
        minVerticalPadding: 10,
        leading: CircleAvatar(
          foregroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
          child: Text(group.name.characters.first.toUpperCase()),
        ),
        title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(group.timeZone),
        trailing: saving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
        onTap: enabled && !saving ? onTap : null,
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Icon(Icons.refresh)),
      ],
    ),
  );
}
