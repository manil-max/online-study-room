import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/notification_providers.dart';
import '../../data/providers/presence_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';
import '../../data/providers/achievement_provider.dart';
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

class _PullToRefreshScrollBehavior extends MaterialScrollBehavior {
  const _PullToRefreshScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      AlwaysScrollableScrollPhysics(parent: super.getScrollPhysics(context));
}

/// Uygulama verisini yeniden çeker. Test ve masaüstü yenileme için public.
Future<void> refreshAppData(WidgetRef ref) async {
  final user = ref.read(authStateProvider).value;
  if (user == null) return;

  // İkincil: arka planda taze iste; spinner beklemez (desktop invalidate deseni).
  ref.invalidate(userSubjectsProvider);
  ref.invalidate(myRemindersProvider);
  ref.invalidate(myAnnouncementsProvider);
  ref.invalidate(readAnnouncementIdsProvider);
  ref.invalidate(achievementDictionaryProvider);
  ref.invalidate(gamificationProfileProvider(user.id));
  ref.invalidate(userAchievementsProvider(user.id));

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
}) =>
    _settle(run(), timeout: timeout);

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
