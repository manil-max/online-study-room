import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/analytics_query_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/notification_providers.dart';
import '../../data/providers/presence_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';
import '../../data/providers/achievement_provider.dart';
import '../../data/providers/achievement_reward_provider.dart';
import '../../data/providers/gamification_providers.dart';

/// Kritik kaynak için üst bekleme. Spinner kullanıcıyı kilitlemesin (WP-102 A).
@visibleForTesting
const Duration kPullToRefreshPerSourceTimeout = Duration(milliseconds: 1500);

/// Tüm kritik refresh işinin üst sınırı. Hedef: indicator ≤ ~2 sn.
@visibleForTesting
const Duration kPullToRefreshGlobalTimeout = Duration(seconds: 2);

/// Tüm route'ları saran klasik mobil aşağı çekerek yenileme davranışı.
///
/// Spinner **kısa** kalır: yalnız oturum / özet / grup / presence gibi kritik
/// StreamProvider'lar kısa timeout ile beklenir. Bildirim, başarım, ders listesi
/// arka planda invalidate edilir (profil/sekme zaten tazeler).
///
/// WP-100 local emit yazmaları anında yansıttığı için pull artık "her şeyi
/// 12 sn sunucudan çek" değil; sıkışık cache/realtime için hafif jest.
class AppPullToRefresh extends ConsumerWidget {
  const AppPullToRefresh({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScrollConfiguration(
      behavior: const _PullToRefreshScrollBehavior(),
      child: RefreshIndicator.adaptive(
        onRefresh: () => refreshAppData(ref),
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        child: child,
      ),
    );
  }
}

/// Kısa (viewport'a sığan) boş / yükleme / hata gövdelerini kaydırılabilir kılar.
///
/// 🔴 WP-550: `RefreshIndicator` jesti bir `Scrollable`ın **overscroll**
/// bildirimiyle çalışır. Bu dallar `Center(...)` döndüğünde ağaçta hiç kaydırıcı
/// olmaz, yani aşağı çekme tam da kullanıcının ona en çok ihtiyaç duyduğu anda
/// (boş ekran, ağ hatası) ölü kalır. `AlwaysScrollableScrollPhysics` burada
/// açıkça verilir: gövde [AppPullToRefresh] dışında kullanılsa da jest yaşar.
///
/// `minHeight` viewport kadar olduğu için `Center` kısa içerikte hâlâ dikey
/// ortalar — görünüm değişmez, yalnız jest kazanılır (aynı takas WP-541).
class RefreshableBody extends StatelessWidget {
  const RefreshableBody({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final insets =
        padding?.resolve(Directionality.of(context)) ?? EdgeInsets.zero;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? (constraints.maxHeight - insets.vertical).clamp(
                    0.0,
                    double.infinity,
                  )
                : 0.0,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PullToRefreshScrollBehavior extends MaterialScrollBehavior {
  const _PullToRefreshScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      AlwaysScrollableScrollPhysics(parent: super.getScrollPhysics(context));
}

/// Uygulama verisini yeniden çeker. **Yenilemenin tek kaynağı budur**: mobil
/// aşağı-çekme jesti ([AppPullToRefresh]) ve masaüstü kabuğunun yenile düğmesi
/// (`home_shell.dart`) aynı bu fonksiyonu çağırır.
///
/// 🔴 WP-550: masaüstü kolu eskiden kendi elle yazılmış `invalidate` listesini
/// tutuyordu ve liste **eksikti** — `userStudySummary`, `groupPresence` ve
/// duyurular hiç tazelenmiyordu. İki ayrı liste = iki ayrı yenileme gerçeği.
/// Buraya provider eklerken ikinci bir liste açma; her iki kol da burayı çağırır.
Future<void> refreshAppData(WidgetRef ref) async {
  final user = ref.read(authStateProvider).value;
  if (user == null) return;

  // İkincil: arka planda taze iste; spinner beklemez (desktop invalidate deseni).
  ref.invalidate(userSubjectsProvider);
  ref.invalidate(myAnnouncementsProvider);
  ref.invalidate(readAnnouncementIdsProvider);
  ref.invalidate(achievementDictionaryProvider);
  ref.invalidate(gamificationProfileProvider(user.id));
  ref.invalidate(userAchievementsProvider(user.id));
  // Masaüstü listesinden gelen tek fazlalık; kaybolmasın diye tek kaynağa taşındı.
  ref.invalidate(pendingAchievementRewardSummaryProvider);

  // 🔴 WP-585: analitik yolu bu listede YOKTU. WP-573'ten beri uzun dönem
  // ("Yıl" / "Tümü") istatistiği ve grup katkı/alfa kartları **sunucudan**
  // gelir; burada olmadıkları için yalnız DOLAYLI olarak (aşağıdaki
  // `userSessionsProvider` bir dönem sıcak pencereye sığdığında) tazeleniyor,
  // sunucu tarafı hiç yeniden okunmuyordu. Aşağı çekme jesti veri değişmemiş
  // gibi görünüyordu. Family'nin kendisi invalidate edilir: canlı olan her
  // dönem örneği yeniden çekilir.
  ref.invalidate(analyticsUserDayTotalsProvider);
  ref.invalidate(analyticsUserSessionsInRangeProvider);
  ref.invalidate(analyticsGroupContributionProvider);
  ref.invalidate(groupAlphaScoresProvider);

  // Kritik: kısa timeout ile bekle — ana istatistik / bugün / kamp ateşi.
  final critical = <Future<void>>[
    _settle(ref.refresh(userSessionsProvider.future)),
    _settle(ref.refresh(userStudySummaryProvider.future)),
    _settle(ref.refresh(userGroupsProvider.future)),
    _settle(ref.refresh(groupMembersProvider.future)),
    _settle(ref.refresh(groupDailyStatsProvider.future)),
    _settle(ref.refresh(groupPresenceProvider.future)),
  ];

  try {
    await Future.wait<void>(critical).timeout(kPullToRefreshGlobalTimeout);
  } catch (_) {
    // Timeout veya hata: indicator biter; ekran AsyncValue ile devam eder.
  }
}

/// Tek kaynağı timeout + hata yutarak tamamlar. Asla rethrow etmez.
@visibleForTesting
Future<void> settleRefreshSource(
  Future<void> Function() run, {
  Duration timeout = kPullToRefreshPerSourceTimeout,
}) => _settle(run(), timeout: timeout);

Future<void> _settle(
  Future<dynamic> future, {
  Duration timeout = kPullToRefreshPerSourceTimeout,
}) async {
  try {
    await future.timeout(timeout);
  } catch (_) {
    // Tek kaynak spinner'ı kilitlemez.
  }
}
