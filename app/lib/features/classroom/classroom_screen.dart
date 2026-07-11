import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/study_group.dart';
import '../../data/providers/group_providers.dart';
import '../home/dashboard_providers.dart';
import '../home/widgets/group_goal_card.dart';
import '../home/widgets/group_trend_card.dart';
import 'widgets/campfire_scene.dart';
import 'widgets/class_chat_screen.dart';
import 'widgets/class_detail_screen.dart';
import 'widgets/class_switcher.dart';
import 'widgets/study_timer_card.dart';

/// Sınıflar sekmesi: aktif sınıfın canlı ekranı + çoklu sınıf değiştirici.
/// Bkz. project.md §3.0/§3.5/§3.8. Sınıf yoksa oluştur/katıl; varsa sayaç +
/// canlı üye listesi. Başlığa (sınıf adına) dokununca sınıf değiştirici açılır.
class ClassroomScreen extends ConsumerWidget {
  const ClassroomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(userGroupProvider);

    return Scaffold(
      appBar: AppBar(
        // Başlık şimdilik boş (kullanıcı isteği). Sağ üstte sınıf değiştirici kalır.
        // Builder: menü tam bu ikonun konumunda açılsın (§3.12 — basılan yerde).
        actions: [
          Builder(
            builder: (iconContext) => IconButton(
              tooltip: 'Grup değiştir',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => showClassSwitcher(iconContext, ref),
            ),
          ),
        ],
      ),
      body: groupAsync.when(
        data: (group) =>
            group == null ? const _NoGroupView() : _GroupView(group: group),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Bir hata oluştu: $e')),
      ),
    );
  }
}

/// Henüz sınıfı olmayan kullanıcı: oluştur veya koda katıl.
class _NoGroupView extends ConsumerWidget {
  const _NoGroupView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: getSafeVerticalPadding(context, horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Henüz bir grupta değilsin',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni bir grup oluştur ya da davet koduyla bir gruba katıl.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => createGroupFlow(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Grup oluştur'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => joinGroupFlow(context, ref),
              icon: const Icon(Icons.login),
              label: const Text('Koda katıl'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kullanıcının sınıfı: ad, davet kodu ve üyeler.
class _GroupView extends ConsumerWidget {
  const _GroupView({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Sayaç varsayılan olarak Ana Sayfa'dadır; isteyen Sınıflar'a ekler (§3.9).
    final showTimer = ref.watch(classroomShowTimerProvider);

    return ListView(
      padding: getSafeVerticalPadding(context, horizontal: 16, vertical: 16),
      children: [
        if (showTimer) ...[const StudyTimerCard(), const SizedBox(height: 8)],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      group.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Sohbet',
                        icon: const Icon(Icons.forum_outlined),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClassChatScreen(group: group),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ayarlar',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClassDetailScreen(group: group),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Kod: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SelectableText(
                    group.inviteCode,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kopyala',
                    icon: const Icon(Icons.copy, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: group.inviteCode),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Davet kodu kopyalandı'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const GroupGoalCard(),
        const SizedBox(height: 16),
        const CampfireScene(),
        const SizedBox(height: 16),
        const GroupTrendCard(),
      ],
    );
  }
}
