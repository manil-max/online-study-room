import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/study_group.dart';
import '../../data/providers/group_providers.dart';
import '../home/dashboard_providers.dart';
import '../home/widgets/group_goal_card.dart';
import '../home/widgets/group_trend_card.dart';
import '../desktop/desktop_page_scaffold.dart';
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
    final body = groupAsync.when(
      data: (group) =>
          group == null ? const _NoGroupView() : _GroupView(group: group),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Bir hata oluştu: $e')),
    );

    if (isDesktopWindow) {
      return DesktopPageScaffold(
        title: 'Gruplar',
        subtitle:
            'Kamp arkadaşlarınla ilerlemeyi, hedefleri ve ortak ritmi izle.',
        icon: Icons.groups_outlined,
        actions: [
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              onPressed: () => showClassSwitcher(buttonContext, ref),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Grup değiştir'),
            ),
          ),
        ],
        child: body,
      );
    }

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
      body: body,
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
    // Sayaç varsayılan olarak Ana Sayfa'dadır; isteyen Sınıflar'a ekler (§3.9).
    final showTimer = ref.watch(classroomShowTimerProvider);

    // Sıra (KALITE-PROGRAMI §8.3 Gruplar): kamp ateşi → grup hedefi → trend →
    // yönetim. Kamp ateşi en üstte; davet kodu gibi operasyonel bilgiler artık
    // ateşin üstünde büyük alan kaplamaz, alttaki açılır yönetim paneline taşındı.
    // (Grup sıralaması kartı bu sekmede yok — sıralama İstatistikler sekmesinde;
    // buraya ayrı bir sıralama kartı eklemek WP-45 kapsamı dışı, `Ürün kararı`.)
    if (isDesktopWindow) {
      return SingleChildScrollView(
        child: DesktopContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CompactGroupHeader(group: group),
              const SizedBox(height: 16),
              DesktopResponsiveColumns(
                breakpoint: 1100,
                secondaryWidth: 390,
                primary: const DesktopPanel(
                  padding: EdgeInsets.all(12),
                  child: CampfireScene(),
                ),
                secondary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showTimer) ...[
                      const StudyTimerCard(),
                      const SizedBox(height: 12),
                    ],
                    const GroupGoalCard(),
                    const SizedBox(height: 12),
                    const GroupTrendCard(),
                    const SizedBox(height: 12),
                    _GroupManagementTile(group: group),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: getSafeVerticalPadding(context, horizontal: 16, vertical: 16),
      children: [
        if (showTimer) ...[const StudyTimerCard(), const SizedBox(height: 8)],
        _CompactGroupHeader(group: group),
        const SizedBox(height: 8),
        const CampfireScene(),
        const SizedBox(height: 16),
        const GroupGoalCard(),
        const SizedBox(height: 16),
        const GroupTrendCard(),
        const SizedBox(height: 16),
        _GroupManagementTile(group: group),
      ],
    );
  }
}

/// Kamp ateşinin üstünde yalnız tek satır kaplayan kompakt başlık: grup adı +
/// sohbet/ayarlar kısayolları. Davet kodu buraya değil, alttaki açılır panele
/// (`_GroupManagementTile`) taşındı ki ateş sahnesi üstte kalsın (§8.3).
class _CompactGroupHeader extends StatelessWidget {
  const _CompactGroupHeader({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            group.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Sohbet',
          icon: const Icon(Icons.forum_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClassChatScreen(group: group)),
          ),
        ),
        IconButton(
          tooltip: 'Ayarlar',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClassDetailScreen(group: group)),
          ),
        ),
      ],
    );
  }
}

/// Alttaki açılır "Grup bilgileri" paneli: davet kodu + kopyala. Varsayılan
/// kapalıdır; operasyonel bilgi kamp ateşi sahnesinin üstünden alınıp buraya
/// taşındı (§8.3 — davet kodu büyük alan kaplamamalı).
class _GroupManagementTile extends StatelessWidget {
  const _GroupManagementTile({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Grup bilgileri'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
        children: [
          Row(
            children: [
              Text(
                'Davet kodu: ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Flexible(
                child: SelectableText(
                  group.inviteCode,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kopyala',
                icon: const Icon(Icons.copy, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: group.inviteCode),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Davet kodu kopyalandı')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
