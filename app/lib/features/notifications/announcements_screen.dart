import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_preferences.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/announcement.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/notification_providers.dart';
import '../profile/feedback_tickets_screen.dart';
import '../../l10n/app_localizations.dart';

/// Duyurular — WP-304'te Bildirim Merkezi'nden çıkarılıp Ayarlar'a taşındı.
///
/// Gerekçe: Bildirim Merkezi bir **ayar** ekranı (neyi ne zaman alacağım);
/// duyurular ise **içerik**. İkisi aynı listede durunca duyurunun geldiği
/// fark edilmiyordu. Ayarlar satırında artık başarımlardaki gibi bir nokta
/// çıkar, kullanıcı bakınca yeni bir şey olduğunu görür.
class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(notificationPreferencesProvider);
    final announcementsAsync = ref.watch(myAnnouncementsProvider);
    final read = ref.watch(readAnnouncementIdsProvider).value ?? const {};

    final Widget body;
    if (!prefs.announcementsEnabled) {
      body = _Message(text: l10n.notificationsUygulamaVeGrupDuyurularini);
    } else {
      body = announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // 🔴 WP-591: eski metin "Beklenmeyen bir hata olustu." idi -- neyin
        // yuklenemedigini soylemiyor ve cikis vermiyordu.
        error: (_, _) => Center(
          child: ErrorRetryView(
            message: l10n.homeVerilerYuklenemedi,
            onRetry: () => ref.invalidate(myAnnouncementsProvider),
          ),
        ),
        data: (announcements) {
          if (announcements.isEmpty) {
            return _Message(text: l10n.notificationsSimdilikDuyuruYok);
          }
          return ListView.separated(
            padding: getSafePadding(
              context,
              const EdgeInsets.fromLTRB(16, 12, 16, 28),
            ),
            itemCount: announcements.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Card(
                child: _AnnouncementTile(
                  announcement: announcement,
                  unread: !read.contains(announcement.id),
                ),
              );
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsDuyurular)),
      body: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium ?? const TextStyle(),
        child: body,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AnnouncementTile extends ConsumerWidget {
  const _AnnouncementTile({required this.announcement, required this.unread});

  final Announcement announcement;
  final bool unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: unread
          ? Icon(Icons.circle, size: 12, color: theme.colorScheme.primary)
          : const Icon(Icons.circle_outlined, size: 12),
      title: Text(
        announcement.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: Text(announcement.message),
      isThreeLine: true,
      onTap: unread || announcement.relatedFeedbackTicketId != null
          ? () async {
              final user = ref.read(authStateProvider).value;
              if (user == null) return;
              if (unread) {
                await ref
                    .read(notificationRepositoryProvider)
                    .markAnnouncementRead(
                      userId: user.id,
                      announcementId: announcement.id,
                    );
                ref.invalidate(readAnnouncementIdsProvider);
              }
              if (announcement.relatedFeedbackTicketId != null &&
                  context.mounted) {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const FeedbackTicketsScreen(),
                  ),
                );
              }
            }
          : null,
    );
  }
}
