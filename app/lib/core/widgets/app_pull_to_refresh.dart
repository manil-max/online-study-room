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

/// Tüm route'ları saran klasik mobil aşağı çekerek yenileme davranışı.
///
/// Veri ekranı birden fazla provider kullansa bile tek hareket, oturumları,
/// grup/presence verisini, dersleri, bildirimleri ve başarım projeksiyonunu
/// yeniden ister. Böylece uygulamayı kapatıp açmak yerine mevcut ekranda
/// güncel sunucu sonucuna dönülür.
class AppPullToRefresh extends ConsumerWidget {
  const AppPullToRefresh({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScrollConfiguration(
      behavior: const _PullToRefreshScrollBehavior(),
      child: RefreshIndicator.adaptive(
        onRefresh: () => _refreshAppData(ref),
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

Future<void> _refreshAppData(WidgetRef ref) async {
  final user = ref.read(authStateProvider).value;
  if (user == null) return;

  await Future.wait<void>([
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
  ]);
}

Future<void> _settle<T>(Future<T> future) async {
  try {
    await future;
  } catch (_) {
    // Mevcut ekran kendi hata durumunu göstermeye devam eder. Yenileme hareketi
    // tek bir veri kaynağının geçici ağ hatasıyla kilitlenmemelidir.
  }
}
