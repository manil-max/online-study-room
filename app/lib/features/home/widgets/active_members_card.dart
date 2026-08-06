import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/second_ticker.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../data/models/presence.dart';
import '../../../data/models/profile.dart';
import '../../classroom/widgets/class_switcher.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/presence_providers.dart';
import '../../profile/widgets/profile_tap.dart';
import '../dashboard_card.dart';
import 'group_card_shell.dart';

/// Veri gelmeden çizilen yer tutucunun test kancası (WP-495).
@visibleForTesting
const Key kActiveMembersSkeletonKey = Key('activeMembersSkeleton');

/// "Şu an çalışanlar" kartı (§3.11): grupta o an **çalışıyor** durumundaki üyeler,
/// canlı geçen süreyle. Geçen süre her satırda kendi `SecondTicker`'ı ile
/// güncellenir; kart yalnızca presence/üye verisi değişince yeniden çizilir.
class ActiveMembersCard extends ConsumerWidget {
  const ActiveMembersCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupAsync = ref.watch(userGroupProvider);
    final group = groupAsync.value;
    if (group == null) {
      // WP-495: "henüz yüklenmedi" ile "grubu yok" aynı şey değil. Davet kartı
      // yalnız veri gerçekten gelip `null` dediğinde çizilir; aksi hâlde açılışta
      // bir kare "Grup Oluştur" flaşı görünüyordu (V58-N02).
      if (groupAsync.hasValue) {
        return GroupCardShell(
          title: AppLocalizations.of(context).homeSuAnCalisanlar,
          onCreateGroup: () => createGroupFlow(context, ref),
          onJoinGroup: () => joinGroupFlow(context, ref),
        );
      }
      return _StatusCard(
        title: AppLocalizations.of(context).homeSuAnCalisanlar,
        child: groupAsync.hasError
            ? _errorText(context)
            : const _RowsSkeleton(key: kActiveMembersSkeletonKey),
      );
    }

    final presenceAsync = ref.watch(groupPresenceProvider);
    final membersAsync = ref.watch(groupMembersProvider);
    final presence = presenceAsync.value ?? const <Presence>[];
    final members = membersAsync.value ?? const <Profile>[];
    // İki akış da ilk verisini vermeden kart "kimse yok" diyemez: presence boş
    // sayılırsa yanlış boş durum, üye listesi boş sayılırsa satırlar "İsimsiz"
    // görünür (V58-N07). Hata ayrı ele alınır — yoksa iskelet sonsuza kadar döner.
    final ready = presenceAsync.hasValue && membersAsync.hasValue;
    final failed = presenceAsync.hasError || membersAsync.hasError;
    final active =
        presence.where((p) => p.status == PresenceStatus.studying).toList()
          // En uzun süredir çalışan üstte (startedAt'e göre; saniyeden bağımsız).
          ..sort(
            (a, b) => (a.startedAt ?? DateTime.now()).compareTo(
              b.startedAt ?? DateTime.now(),
            ),
          );

    final memberById = {for (final m in members) m.id: m};

    final green = subjectColor('chart-2');

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 220;
          final availableHeight = constraints.maxHeight;
          final isHeightBounded = availableHeight.isFinite;

          // Sabit başlık (dikey padding dahil) ~68px, her satır ~42px.
          const rowHeight = 42.0;
          const headerHeight = 32 + 24 + 12;

          // Başlık + en az bir satır sığmıyorsa TÜM içerik kaydırılır (Expanded
          // yerine düz Column) → çok kısa hücrede taşma (RenderFlex) olmaz.
          final fill =
              !isHeightBounded || availableHeight >= headerHeight + rowHeight;

          final int maxItems;
          if (fill && isHeightBounded) {
            maxItems = ((availableHeight - headerHeight) / rowHeight)
                .floor()
                .clamp(1, 20);
          } else if (isHeightBounded) {
            maxItems = 3;
          } else {
            maxItems = active.length;
          }

          final visibleActive = active.take(maxItems).toList();

          Widget rowFor(int i) {
            final p = visibleActive[i];
            final member = memberById[p.userId];
            final name = (member != null && !member.isActive)
                ? AppLocalizations.of(context).homeEskiGrupUyesi
                : (member?.displayName.isNotEmpty == true
                      ? member!.displayName
                      : AppLocalizations.of(context).homeIsimsiz);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: _ActiveRow(
                name: name,
                avatarUrl: member?.avatarUrl,
                startedAt: p.startedAt,
                green: green,
                isCompact: isCompact,
                profile: member != null && member.isActive ? member : null,
              ),
            );
          }

          final header = Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).homeSuAnCalisanlar,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              // Sayaç yalnız gerçek veriyle çizilir: yükleniyorken "0 aktif"
              // de bir yanlış boş durumdur (WP-495).
              if (ready) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${active.length} aktif',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          );

          final emptyText = Text(
            AppLocalizations.of(context).homeSuAnCalisanKimse,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );

          // Veri gelmeden çizilen gövde: hata varsa metin, yoksa iskelet.
          final statusChild = failed
              ? _errorText(context)
              : const _RowsSkeleton(key: kActiveMembersSkeletonKey);

          if (!fill) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 12),
                    if (!ready)
                      statusChild
                    else if (active.isEmpty)
                      emptyText
                    else
                      for (var i = 0; i < visibleActive.length; i++) rowFor(i),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 12),
                if (!ready)
                  // Kısa hücrede taşmasın: iskelet/hata metni kırpılır.
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: statusChild,
                    ),
                  )
                else if (active.isEmpty)
                  emptyText
                else
                  Expanded(
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleActive.length,
                      itemBuilder: (context, i) => rowFor(i),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Yükleme/hata gövdesi için kart çerçevesi: yalnız başlık + verilen içerik.
///
/// [GroupCardShell] gibi bounded hücrede iç kaydırma yapar (WP-176), fakat
/// "gruba katıl" davetini **taşımaz** — bu kart veri henüz yokken çizilir.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              child,
            ],
          );
          return Padding(
            padding: const EdgeInsets.all(16),
            child: constraints.maxHeight.isFinite
                ? SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: column,
                  )
                : column,
          );
        },
      ),
    );
  }
}

/// Veri gelene kadar çizilen yer tutucu satırlar.
///
/// Animasyonsuz: kart ana ekranda onlarca kopya hâlinde bulunabilir ve sürekli
/// dönen bir shimmer kare bütçesini yer.
class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: base,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(6),
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

/// Hata durumu boş durumdan ayrı görünür; aksi hâlde ağ hatası "kimse
/// çalışmıyor" ya da "grubun yok" gibi okunur.
Widget _errorText(BuildContext context) {
  final theme = Theme.of(context);
  return Text(
    AppLocalizations.of(context).homeCalisanlarYuklenemedi,
    style: theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({
    required this.name,
    required this.avatarUrl,
    required this.startedAt,
    required this.green,
    this.isCompact = false,
    this.profile,
  });

  final String name;
  final String? avatarUrl;
  final DateTime? startedAt;
  final Color green;
  final bool isCompact;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Yalnızca bu metin saniyede bir kendini yeniler.
    final time = SecondTicker(
      builder: (_, now) {
        final elapsed = startedAt == null
            ? 0
            : now.difference(startedAt!).inSeconds;
        return Text(
          formatHms(elapsed),
          maxLines: 1,
          style: theme.textTheme.titleSmall?.copyWith(
            color: green,
            fontFeatures: const [],
          ),
        );
      },
    );
    final row = Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (profile != null)
              LiveCrownedAvatar(
                userId: profile!.id,
                displayName: name,
                avatarUrl: avatarUrl,
                radius: 16,
              )
            else
              CrownedAvatar(
                displayName: name,
                avatarUrl: avatarUrl,
                radius: 16,
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        if (!isCompact) ...[
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          time,
        ] else
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(fit: BoxFit.scaleDown, child: time),
            ),
          ),
      ],
    );
    if (profile == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openMemberProfile(context, profile!),
      child: row,
    );
  }
}
