import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/classroom/classroom_screen.dart';
import '../../features/classroom/widgets/class_switcher.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/stats/stats_screen.dart';

/// Alt navigasyonda seçili sekme indeksini tutar.
class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final navIndexProvider =
    NotifierProvider<NavIndexNotifier, int>(NavIndexNotifier.new);

/// Uygulamanın ana kabuğu: alt menüde 3 sekme (Sınıf / İstatistik / Profil).
/// Ekranlar IndexedStack ile tutulur, böylece sekme değişince durum korunur.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const List<Widget> _screens = [
    ClassroomScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    const classesTabIndex = 0; // "Sınıflar" sekmesinin indeksi

    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      // "Sınıflar" ikonuna basılı tutunca sınıf değiştirici açılır (§3.8).
      // NavigationBar tek tek destination'a long-press vermediği için basışın
      // x konumundan hangi sekme olduğunu hesaplıyoruz.
      bottomNavigationBar: GestureDetector(
        onLongPressStart: (details) {
          final width = MediaQuery.of(context).size.width;
          final tab = (details.globalPosition.dx / (width / _screens.length))
              .floor();
          if (tab == classesTabIndex) {
            ref.read(navIndexProvider.notifier).setIndex(classesTabIndex);
            showClassSwitcher(context, ref);
          }
        },
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: ref.read(navIndexProvider.notifier).setIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Sınıflar',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'İstatistik',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
