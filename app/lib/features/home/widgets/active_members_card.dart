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
import 'card_scaffold.dart';
import 'group_card_shell.dart';

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
    // WP-495: yükleniyorken davet değil iskelet. WP-495B'de kapı ortak hâle
    // geldi; aynı hata grup gerektiren diğer kartlarda da vardı.
    final gate = groupCardGate(
      context,
      groupAsync,
      title: AppLocalizations.of(context).homeSuAnCalisanlar,
      onCreateGroup: () => createGroupFlow(context, ref),
      onJoinGroup: () => joinGroupFlow(context, ref),
    );
    if (gate != null) return gate;

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
          final isHeightBounded = constraints.maxHeight.isFinite;

          // 🔴 WP-497: burada **sabit `rowHeight = 42` ve `headerHeight = 68`**
          // vardı ve kaç satırın sığdığı o aritmetikten çıkıyordu. Varsayım
          // yanlıştı: taçlı avatar kendi kutusunu büyütür
          // (`crowned_avatar.dart` `top + base + outlineW`), `radius 16` için
          // satır dikey dolguyla ~61 px eder — bütçe %45 aşılır. Sonuç, son
          // satırın alttan kırpılması ve listenin aşağı kaymış görünmesiydi.
          // Ayrıca `maxItems` bütçeye sığmayan üyeleri **tamamen düşürüyordu**;
          // kullanıcı onlara hiçbir şekilde ulaşamıyordu.
          //
          // Sayıyı büyütmek çözüm değil (kart tuzağı): yazı ölçeği, taç kademesi
          // ve avatar boyutu değiştikçe aynı hata geri gelir. Varsayım tümüyle
          // kaldırıldı — sınırlı yükseklikte gerçek kaydırılabilir liste,
          // sınırsız yükseklikte içeriğe göre uzayan sütun.

          Widget rowFor(int i) {
            final p = active[i];
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
                    // 🔴 WP-500: burada `'${active.length} aktif'` yazıyordu —
                    // İngilizce arayüzde de "2 aktif" çıkıyordu. l10n kapısı
                    // bunu iki kör noktanın kesişiminde kaçırdı, ikisi de
                    // `scripts/l10n_audit.py` içinde düzeltildi.
                    AppLocalizations.of(context).homeAktifSayisi(active.length),
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
              ? groupCardMessage(
                  context,
                  AppLocalizations.of(context).homeCalisanlarYuklenemedi,
                )
              : const GroupCardSkeleton(key: kGroupCardSkeletonKey);

          // Gövde tek bir sıralı akış: veri yoksa iskelet/hata, kimse yoksa
          // metin, varsa üye satırları. Üçü de aynı listeden beslendiği için
          // dallara ayrı yükseklik hesabı gerekmiyor.
          final bodyCount = (!ready || active.isEmpty) ? 1 : active.length;
          Widget bodyAt(int i) {
            if (!ready) return statusChild;
            if (active.isEmpty) return emptyText;
            return rowFor(i);
          }

          if (!isHeightBounded) {
            // Dış kaydırıcının içindeyiz (ana ekran listesi): kart içeriği
            // kadar uzar, iç içe kaydırma jesti yutulmaz.
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 12),
                  for (var i = 0; i < bodyCount; i++) bodyAt(i),
                ],
              ),
            );
          }

          // Sınırlı yükseklik (pano hücresi): başlık da listenin ilk öğesi.
          // Böylece hücre başlıktan bile kısa olsa `RenderFlex` taşması olmaz
          // ve sığmayan üyeler düşmek yerine **kaydırılarak** görülebilir.
          // `builder` kullanılıyor: her satırda saniyede bir çalışan
          // `SecondTicker` var, görünmeyen satırlar hiç kurulmamalı.
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              // WP-508: sığan içerikte jest dış sayfaya bırakılır. Bayrak
              // verilmezse dikey `ListView` `AlwaysScrollableScrollPhysics`e
              // düşer ve sürükleme burada yutulur — sahibin bildirdiği belirti.
              physics: kCardOverflowScrollPhysics,
              primary: false,
              padding: EdgeInsets.zero,
              itemCount: bodyCount + 1,
              itemBuilder: (context, i) => i == 0
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: header,
                    )
                  : bodyAt(i - 1),
            ),
          );
        },
      ),
    );
  }
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
