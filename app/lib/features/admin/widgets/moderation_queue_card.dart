import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:online_study_room/core/widgets/user_avatar.dart';
import 'package:online_study_room/features/admin/models/moderation_queue_report.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

class ModerationQueueCard extends StatelessWidget {
  const ModerationQueueCard({
    super.key,
    required this.report,
    required this.onStatusSelected,
    this.onTap,
  });

  final ModerationQueueReport report;
  final ValueChanged<String> onStatusSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      onTap: onTap,
      title: Text('${report.targetType} · ${report.reason}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _IdentityLine(
            label: l10n.adminUgcReporter,
            identity: report.reporter,
          ),
          const SizedBox(height: 4),
          _IdentityLine(label: l10n.adminUgcTarget, identity: report.target),
          const SizedBox(height: 6),
          Text(
            '${report.status} · ${report.contentSnapshot ?? ''}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: onStatusSelected,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'in_review',
            child: Text(l10n.adminUgcStatusInReview),
          ),
          PopupMenuItem(
            value: 'resolved',
            child: Text(l10n.adminUgcStatusResolved),
          ),
          PopupMenuItem(
            value: 'rejected',
            child: Text(l10n.adminUgcStatusRejected),
          ),
        ],
      ),
    );
  }
}

class _IdentityLine extends StatelessWidget {
  const _IdentityLine({required this.label, required this.identity});

  final String label;
  final ModerationQueueIdentity identity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        UserAvatar(
          displayName: identity.displayName,
          avatarUrl: identity.avatarUrl,
          radius: 16,
          enableZoom: false,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: ${identity.isDeleted ? l10n.adminUgcDeletedUser : identity.displayName}',
              ),
              InkWell(
                key: Key('ugc-copy-id-${identity.id}'),
                borderRadius: BorderRadius.circular(4),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: identity.id));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.adminUgcIdCopied)),
                  );
                },
                child: Text(
                  identity.id,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
