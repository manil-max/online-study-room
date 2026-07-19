import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/navigation/nav_index.dart';
import 'package:online_study_room/data/providers/device_integration_listener.dart';

void main() {
  test('aynı sekmeye basınca index değişmez, reselect tick artar', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(navIndexProvider), 0);
    expect(container.read(navReselectProvider).tick, 0);

    container.read(navIndexProvider.notifier).setIndex(0);
    expect(container.read(navIndexProvider), 0);
    expect(container.read(navReselectProvider).tabIndex, kHomeTabIndex);
    expect(container.read(navReselectProvider).tick, 1);

    container.read(navIndexProvider.notifier).setIndex(2);
    expect(container.read(navIndexProvider), 2);
    expect(container.read(navReselectProvider).tick, 1);

    container.read(navIndexProvider.notifier).setIndex(2);
    expect(container.read(navIndexProvider), 2);
    expect(container.read(navReselectProvider).tabIndex, 2);
    expect(container.read(navReselectProvider).tick, 2);
  });

  test('beş ana sekmenin kanonik sırası enum ile sabittir', () {
    expect(AppTab.values, [
      AppTab.home,
      AppTab.tools,
      AppTab.groups,
      AppTab.stats,
      AppTab.profile,
    ]);
    expect(AppTab.home.index, 0);
    expect(AppTab.profile.index, AppTab.values.length - 1);
  });

  test('geçersiz tab indeksi shell stateine yazılamaz', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(navIndexProvider.notifier).setIndex(99),
      throwsRangeError,
    );
    expect(container.read(navIndexProvider), AppTab.home.index);
  });

  test('cihaz kısayolları kanonik tab enumuna gider', () {
    expect(
      appTabForDeviceAction('com.manilmax.online_study_room.OPEN_STATS'),
      AppTab.stats,
    );
    expect(
      appTabForDeviceAction('com.manilmax.online_study_room.OPEN_CHAT'),
      AppTab.groups,
    );
    expect(
      appTabForDeviceAction('com.manilmax.online_study_room.OPEN_LEADERBOARD'),
      AppTab.home,
    );
  });
}
