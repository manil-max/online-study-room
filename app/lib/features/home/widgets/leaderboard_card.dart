import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../data/models/goal_streak.dart';
import '../../../data/models/profile.dart';
import '../../classroom/widgets/class_switcher.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/analytics_query_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../profile/widgets/profile_tap.dart';
import '../../stats/widgets/goal_streak_flame.dart';
import '../dashboard_card.dart';
import 'card_data_gate.dart';
import 'card_scaffold.dart';
import 'group_card_shell.dart';

/// Bir sıralama satırının **dayatılan** yüksekliği.
///
/// 🔴 WP-659 varlık sebebi. Kart eskiden `const rowHeight = 36.0` ile "kaç kişi
/// sığar"ı hesaplıyordu; 36 px bir zamanlar doğruydu (taçsız avatar r = 14 →
/// 28 px + 2×4 px padding = tam 36 px), taç geldiğinde sabit güncellenmedi.
/// Ölçüldü (`leaderboard_row_fit_wp659_test.dart`): taçlı avatar kutusu
/// 45.44 px, satır **53.44 px** — yani tahmin %48 küçüktü ve kart her hücrede
/// sığmayacak kadar çok satır paketleyip kalanı kart-içi kaydırıcıya
/// düşürüyordu (sahip: *"parmağım takılıyor"*).
///
/// Bu sayı hem `itemExtent` olarak dayatılır hem de "kaç satır sığar"
/// aritmetiğinde kullanılır: iki yer AYNI sayıyı okuduğu için hesap yapı gereği
/// doğrudur, tahmin kalmaz. Taçlı/taçsız üye karışımında satırlar da tek tip
/// olur.
///
/// ⚠️ Küçültülemez: satırın doğal boyunun altına inerse içerik sessizce
/// kırpılır (yatay `Row` dikey taşmayı **raporlamaz**). Sözleşme testi doğal
/// boyu 1.0 / 1.3 / 1.6 yazı ölçeğinde ölçüp bu sayıyla karşılaştırır.
const double kLeaderboardRowExtent = 54.0;

/// **Sıkıştırılmış** satırın dayatılan yüksekliği (kısa hücre).
///
/// 🔴 WP-662 varlık sebebi. WP-659 aritmetiği doğrulttu ama sonuç şuydu:
/// 160×160 hücrede gövdeye ~83 px kalıyor, satır 54 px, yani kart **tek kişi**
/// gösteriyordu. Tek kişilik bir "sıralama" tablosu bilgi taşımaz — sıralama en
/// az bir karşılaştırma demektir.
///
/// Bu varyantta satırın boyunu belirleyen şey taçlı avatar kutusudur: taç
/// merkezin **1.74 katı** yukarı çıktığı için r = 14'lük avatar 45.44 px'lik bir
/// kutuya oturur. r = 8'de aynı silüet 29.00 px'e iner; dikey padding de 4 → 2
/// düşürülür. Ölçülen doğal boy (yazı ölçeği 1.0 / 1.3 / 1.6) bu sabitin
/// altındadır — bkz. `leaderboard_dense_row_wp662_test.dart`.
///
/// ⚠️ [kLeaderboardRowExtent] ile aynı tuzak: küçültülürse içerik **sessizce**
/// kırpılır (yatay `Row` dikey taşmayı raporlamaz). Sözleşme testi satırın
/// gerçek intrinsic boyunu ölçüp bu sayıyla karşılaştırır.
const double kLeaderboardDenseRowExtent = 34.0;

/// Aktif grubun bugünkü sıralaması (§3.9 kart). "sen" vurgulu. Kaç kişi
/// görüneceği kartın kutusundan **ölçülerek** çıkar (bkz.
/// [kLeaderboardRowExtent]).
class LeaderboardCard extends ConsumerWidget {
  const LeaderboardCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupAsync = ref.watch(userGroupProvider);

    // WP-495B: yükleniyorken davet değil iskelet (bkz. `groupCardGate`).
    final gate = groupCardGate(
      context,
      groupAsync,
      title: AppLocalizations.of(context).homeGrupSiralamasi,
      onCreateGroup: () => createGroupFlow(context, ref),
      onJoinGroup: () => joinGroupFlow(context, ref),
    );
    if (gate != null) return gate;
    final group = groupAsync.value!;

    final statsAsync = ref.watch(groupDailyStatsProvider);
    final membersAsync = ref.watch(groupMembersProvider);
    final alphaAsync = ref.watch(groupAlphaScoresProvider);
    // WP-495C: grup hazır ama istatistik/üye gelmeden sıralama boş çizilirdi.
    final dataGate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeGrupSiralamasi,
      sources: [statsAsync, membersAsync, alphaAsync],
    );
    if (dataGate != null) return dataGate;
    final stats = statsAsync.value!;
    final members = membersAsync.value!;
    final meId = ref.watch(authStateProvider).value?.id;
    final alphaWins = alphaAsync.value!;

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 220;
          final availableHeight = constraints.maxHeight;
          final isHeightBounded = availableHeight.isFinite;

          const cardPadding = EdgeInsets.all(16);
          final innerHeight = availableHeight - cardPadding.vertical;

          // 🔴 WP-659 — burada eskiden başlık yüksekliği de TAHMİN ediliyordu
          // (`32 + 24 + 12 (+48)`) ve o tahmin **kaç kişi görüneceğini**
          // belirliyordu. Ölçüldü: başlık dar kartta 44 px, grup hedefi
          // bloğuyla 91 px; yazı ölçeği 1.6'da 58 / 115 px. Yani tahmin hem
          // yanlıştı hem de yazı ölçeğiyle hiç büyümüyordu.
          //
          // Artık bu sayı satır sayısını **belirlemiyor**: satır sayısı aşağıda
          // gövdenin GERÇEK kalan yüksekliğinden çıkar. Buradaki tek işi,
          // başlığın kesinlikle sığacağı hücrelerde doldurma düzenini seçmek —
          // yani yalnız kırpmaya karşı korkuluk. Yanılırsa sonuç "yanlış sayıda
          // kişi" değil, "tüm kart kayar" (WP-497 güvenlik ağı) olur.
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          // Ölçülen iki parça (WP-659): yalnız başlık satırı 44 px, grup hedefi
          // bloğu (etiket + rozet + yüzde + çubuk) 47 px; yazı ölçeğiyle
          // sırasıyla 24 ve 16 px büyürler. 44 + 47 = eski 91 px sabiti.
          final titleReserve = 44.0 + 24.0 * (textScale - 1.0);
          final goalReserve = 47.0 + 16.0 * (textScale - 1.0);

          // 🔴 WP-662 — "geniş ama KISA" hücrede grup hedefi bloğu kartı yiyor.
          //
          // Ölçüldü: 328×160 hücrede kart `isCompact` DEĞİL (genişlik 320 ≥ 220),
          // yani grup hedefi bloğu çiziliyor ve başlık tek başına 120 px'lik
          // gövdenin 91'ini alıyor; listeye 37 px kalıyor, tek satır ise 54 px.
          // Sonuç: kart tek satır paketliyor ve o satırın 17 px'i (yazı ölçeği
          // 1.3'te 29, 1.6'da 41 px) kart-içi kaydırma payına düşüyordu.
          //
          // Görünürlük kararı yalnız GENİŞLİĞE bakıyordu; sorun YÜKSEKLİKTİ.
          // Kural: blok, kendisinden sonra en az iki normal satır kalıyorsa
          // çizilir. Sınırsız yükseklikte (Gruplar `ListView`i) hep çizilir —
          // orada kartın boyu içeriğe göre uzar.
          final showGroupGoal =
              !isCompact &&
              (!isHeightBounded ||
                  innerHeight >=
                      titleReserve + goalReserve + 2 * kLeaderboardRowExtent);

          final headerReserve =
              titleReserve + (showGroupGoal ? goalReserve : 0.0);

          // Sınırsız yükseklikte (Gruplar `ListView`i) `Expanded` kullanılamaz.
          final fill = isHeightBounded && innerHeight >= headerReserve;

          // Bugünün sıralaması (userId → saniye), büyükten küçüğe.
          final todayByUser = todaySecondsByUser(stats);

          // Grup günlük hedefi: grubun bugünkü TOPLAM çalışması / hedef + grup serisi.
          final goalSeconds = group.dailyGoalMinutes * 60;
          final groupTodayTotal = todayByUser.values.fold<int>(
            0,
            (a, v) => a + v,
          );
          final groupGoalPct = goalSeconds > 0
              ? (groupTodayTotal / goalSeconds).clamp(0.0, 1.0)
              : 0.0;
          // 🔴 WP-612: buradaki seri `currentStreak()` ile hesaplanıyordu —
          // grace'siz ESKİ motor, üstelik `today` verilmediği için cihazın ham
          // `DateTime.now()`u ile. "Grup hedefi" kartı (`group_goal_card.dart`)
          // ise kanonik sunucu projeksiyonunu çiziyordu. İkisi de aynı ana
          // ekranda alev + sayı gösterip FARKLI SAYI verebiliyordu; kullanıcının
          // hangisinin doğru olduğunu ayırt etmesi imkânsızdı.
          //
          // `goal_streak_flame.dart` (GoalStreakBadge) zaten tam bu iş için
          // yazılmıştı: "Bu sarmalayıcı iki motorun aynı ekranda yaşamasını
          // engeller." Kart bunu iddia ediyordu, kodda engellenmemişti.
          final streakScope = GoalStreakScope.group(
            groupId: group.id,
            timeZone: group.timeZone,
          );

          Profile? memberFor(String id) {
            for (final m in members) {
              if (m.id == id) return m;
            }
            return null;
          }

          final ranked =
              todayByUser.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

          // WP-253: üye başına seri rozeti kaldırıldı — bkz. class_stats_view.
          // Bu karttaki ateş ikonu artık YALNIZ grup hedef serisini
          // (`groupStreak`) anlatıyor; iki anlam çakışması bitti.

          // 🔴 WP-676: masaüstünde bu satır 722 px'e ("Sıralama" → grup adı),
          // aşağıdaki hedef satırı 873 px'e ("Grup hedefi" → "%0") uzuyordu.
          // SPEC KURAL 2.2 → [cardLabelValueRow] 496 px'te bırakır, sola hizalar.
          final headerChildren = <Widget>[
            cardLabelValueRow(
              context,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).homeSiralama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Spacer(),
                  if (!isCompact)
                    Flexible(
                      child: Text(
                        group.name,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 🔴 WP-662: koşul `!isCompact` idi — yani yalnız GENİŞLİK
            // bakılıyordu. Kısa hücrede blok başlığı şişirip listeyi
            // kaydırıcıya düşürüyordu; bkz. yukarıdaki [showGroupGoal] notu.
            if (showGroupGoal) ...[
              const SizedBox(height: 10),
              cardLabelValueRow(
                context,
                child: Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  // 🔴 WP-659 — bu etiket çıplak `Text` idi ve `Spacer` ile
                  // birlikte satırı taşırıyordu: yazı ölçeği 1.3'te
                  // `RenderFlex overflowed by 70–78 pixels on the right`.
                  // Yani "Grup hedefi" yazısının sağı, rozet ve yüzde
                  // KIRPILIYORDU — kaydırıcı yok, kullanıcı hiç göremiyor.
                  // Kusuru bu turda liderlik kartının satır aritmetiğini
                  // ölçerken yeni test yakaladı (1.0 ölçeğinde görünmüyor).
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).homeGrupHedefi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Rozet koşulsuz çizilir (WP-481 sahip kararı): seri 0 iken
                  // kaybolan gösterge "veri yok" ile "seri yok"u karıştırıyordu.
                  GoalStreakBadge(
                    scope: streakScope,
                    size: GoalStreakFlameSize.compact,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '%${(groupGoalPct * 100).round()}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: groupGoalPct,
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: groupGoalPct >= 1.0
                      ? subjectColor('chart-2')
                      : theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ];

          Widget rowFor(
            List<MapEntry<String, int>> board,
            int i, {
            bool dense = false,
          }) => _Row(
            rank: i + 1,
            member: memberFor(board[i].key),
            seconds: board[i].value,
            alphaWins: alphaWins[board[i].key] ?? 0,
            isMe: board[i].key == meId,
            isCompact: isCompact,
            dense: dense,
          );

          final emptyText = Text(
            AppLocalizations.of(context).homeBugunHenuzKimseCalismamis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );

          // Kısa kart / ListView (Gruplar): nested scroll yok (WP-172).
          // Home sonlu kısa hücrede kart içi kaydırma korunur.
          if (!fill) {
            // Sınırsız yükseklikte en fazla 10 kişi; başlığın sığmadığı çok
            // kısa hücrede 3 (tümü kart-içi kaydırıcıya girer).
            final board = ranked.take(isHeightBounded ? 3 : 10).toList();
            final column = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...headerChildren,
                if (board.isEmpty)
                  emptyText
                else
                  for (var i = 0; i < board.length; i++) rowFor(board, i),
              ],
            );
            return Padding(
              padding: cardPadding,
              // WP-508: yalnız taşarsa kayar; sığdığında dış sayfa akar.
              child: isHeightBounded
                  ? cardScrollIfOverflows(child: column)
                  : column,
            );
          }

          return Padding(
            padding: cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...headerChildren,
                Expanded(
                  // 🔴 WP-659: satır sayısı burada, başlık çizildikten SONRA
                  // kalan GERÇEK yükseklikten çıkar. Başlık büyüdüğünde (yazı
                  // ölçeği, grup adı, rozet) hesap kendiliğinden düzelir.
                  child: LayoutBuilder(
                    builder: (context, bodyConstraints) {
                      // 🔴 WP-662 — tek kişilik "sıralama" tablosu bilgi
                      // taşımaz. Gövde iki NORMAL satır almıyorsa satırlar
                      // sıkıştırılmış varyanta geçer (küçük avatar, dar
                      // padding) ve karşılaştırma geri gelir. Karar yükseklikten
                      // ÖLÇÜLEREK çıkar; "dar ekran" gibi bir tahmin değil.
                      final bodyHeight = bodyConstraints.maxHeight;
                      final dense = bodyHeight < 2 * kLeaderboardRowExtent;
                      final extent = dense
                          ? kLeaderboardDenseRowExtent
                          : kLeaderboardRowExtent;
                      final count = (bodyHeight / extent).floor().clamp(1, 15);
                      final board = ranked.take(count).toList();
                      if (board.isEmpty) return emptyText;
                      return ListView.builder(
                        // WP-508: `NeverScrollable` idi — sıralama listeye
                        // sığmadığında alttaki üyeler kırpılıyor ve hiçbir
                        // şekilde görülemiyordu (WP-497'nin aynı sınıfı).
                        physics: kCardOverflowScrollPhysics,
                        primary: false,
                        // Yukarıdaki bölme ile AYNI sayı: paketlenen satır
                        // sayısı kutuya sığar, artık kaydırıcı kalmaz.
                        itemExtent: extent,
                        itemCount: board.length,
                        itemBuilder: (context, i) =>
                            rowFor(board, i, dense: dense),
                      );
                    },
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

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.member,
    required this.seconds,
    required this.alphaWins,
    required this.isMe,
    this.isCompact = false,
    this.dense = false,
  });

  final int rank;
  final Profile? member;
  final int seconds;
  final int alphaWins;
  final bool isMe;
  final bool isCompact;

  /// WP-662 — kısa hücrede en az iki kişiyi göstermek için sıkıştırılmış
  /// varyant: avatar r = 14 → 8, dikey padding 4 → 2, sıra numarası küçülür.
  /// Taç KALDIRILMADI (kademe rozeti listenin anlamının parçası), yalnız
  /// küçüldü; satırın boyunu belirleyen şey zaten tacın uzantısıdır.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (member != null && !member!.isActive)
        ? AppLocalizations.of(context).homeEskiGrupUyesi
        : (member?.displayName.isNotEmpty == true
              ? member!.displayName
              : AppLocalizations.of(context).homeIsimsiz);
    // Üzerine gelince özet; tıklayınca sosyal profil (isim/PP her yerde).
    final brief = StringBuffer(
      '$rank. · ${AppLocalizations.of(context).homeBugun} '
      '${formatHuman(seconds)}',
    );
    if (alphaWins > 0) {
      brief.write(' · 🐺$alphaWins');
    }
    final canOpenProfile = member != null && member!.isActive;
    return Tooltip(
      message: brief.toString(),
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: canOpenProfile
            ? () => openMemberProfile(context, member!)
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: dense ? 2 : 4,
            horizontal: 4,
          ),
          // WP-676 / SPEC KURAL 2.2: ad ↔ süre bir etiket–değer satırıdır.
          // Masaüstünde 496'da durur; tıklama/hover hedefi ([InkWell]) tam
          // genişlikte kalır, yani hiçbir etkileşim daralmaz.
          child: cardLabelValueRow(
            context,
            child: Row(
            children: [
              SizedBox(
                width: dense ? 16 : 22,
                child: Text(
                  '$rank',
                  maxLines: 1,
                  style:
                      (dense
                              ? theme.textTheme.labelMedium
                              : theme.textTheme.titleSmall)
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              if (member != null)
                LiveCrownedAvatar(
                  userId: member!.id,
                  displayName: name,
                  avatarUrl: member!.avatarUrl,
                  radius: dense ? 8 : 14,
                )
              else
                CrownedAvatar(displayName: name, radius: dense ? 8 : 14),
              SizedBox(width: dense ? 6 : 8),
              if (!isCompact) ...[
                Expanded(
                  child: Text(
                    isMe
                        ? AppLocalizations.of(context).commonSenEtiketi(name)
                        : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // WP-662: sıkıştırılmış satırda ad da küçülür; yoksa yazı
                    // ölçeği 1.6'da tek başına satırı 34 px'in üstüne çıkarır.
                    style:
                        (dense
                                ? theme.textTheme.bodySmall
                                : theme.textTheme.bodyMedium)
                            ?.copyWith(
                              fontWeight: isMe ? FontWeight.w600 : null,
                              color: isMe ? theme.colorScheme.primary : null,
                            ),
                  ),
                ),
                if (alphaWins > 0) ...[
                  const Text('🐺', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 2),
                  Text(
                    '$alphaWins',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  formatHuman(seconds),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else
                // Dar hücrede ad gizli; süre kalan alana yaslanır ve gerekiyorsa
                // küçülerek taşmayı önler.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (alphaWins > 0) ...[
                            const Text('🐺', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 2),
                            Text(
                              '$alphaWins',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            formatHuman(seconds),
                            maxLines: 1,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
