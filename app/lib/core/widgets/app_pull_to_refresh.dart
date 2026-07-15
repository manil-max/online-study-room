import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/achievement_provider.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/gamification_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/notification_providers.dart';
import '../../data/providers/presence_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';

/// Tek bir provider refresh için üst süre. Aşıldığında o kaynak atlanır;
/// spinner kilitlenmez (H2).
@visibleForTesting
const Duration kPullToRefreshPerSourceTimeout = Duration(seconds: 8);

/// Tüm refresh işinin üst sınırı. En yavaş kaynak bile bunu aşamaz.
@visibleForTesting
const Duration kPullToRefreshGlobalTimeout = Duration(seconds: 12);

/// Tüm route'ları saran klasik mobil aşağı çekerek yenileme davranışı.
///
/// Veri ekranı birden fazla provider kullansa bile tek hareket, oturumları,
/// grup/presence verisini, dersleri, bildirimleri ve başarım projeksiyonunu
/// yeniden ister. Böylece uygulamayı kapatıp açmak yerine mevcut ekranda
/// güncel sunucu sonucuna dönülür.
///
/// Hiçbir kaynak (StreamProvider.future hang, yavaş ağ) sonsuz bekleyemez:
/// per-source ve global timeout spinner'ı her zaman bitirir.
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

  // Kritik yüzeyler önce; gamification/dictionary ikincil (yavaş ağda asıl
  // istatistik/oturum yenilemesini engellemesin diye aynı wait içinde ama
  // timeout ile korunuyor).
  final jobs = <Future<void>>[
    _settle(ref.refresh(userSessionsProvider.future)),
    _settle(ref.refresh(userStudySummaryProvider.future)),
    _settle(ref.refresh(userGroupsProvider.future)),
    _settle(ref.refresh(groupMembersProvider.future)),
    _settle(ref.refresh(groupDailyStatsProvider.future)),
    _settle(ref.refresh(groupPresenceProvider.future)),
    _settle(ref.refresh(userSubjectsProvider.future)),
    _settle(ref.refresh(myRemindersProvider.future)),
    _settle(ref.refresh(myAnnouncementsProvider.future)),
    _settle(ref.refresh(readAnnouncementIdsProvider.future)),
    _settle(ref.refresh(achievementDictionaryProvider.future)),
    _settle(ref.refresh(gamificationProfileProvider(user.id).future)),
    _settle(ref.refresh(userAchievementsProvider(user.id).future)),
  ];

  try {
    await Future.wait<void>(jobs).timeout(kPullToRefreshGlobalTimeout);
  } catch (_) {
    // Global timeout veya beklenmeyen hata: spinner yine biter; ekranlar
    // kendi AsyncValue hata/yükleme durumunu gösterir.
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
    // Mevcut ekran kendi hata durumunu göstermeye devam eder. Yenileme hareketi
    // tek bir veri kaynağının geçici ağ hatası veya hang'i ile kilitlenmemelidir.
  }
}
