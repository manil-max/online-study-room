import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/presence_lifecycle.dart';
import '../../features/classroom/classroom_screen.dart';
import '../../features/classroom/widgets/class_switcher.dart';
import '../../features/home/home_screen.dart';
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

/// Uygulamanın ana kabuğu: alt menüde 4 sekme (Ana Sayfa / Sınıflar / İstatistik
/// / Profil). Ekranlar IndexedStack ile tutulur, böylece sekme değişince durum korunur.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    ClassroomScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    const classesTabIndex = 1; // "Sınıflar" sekmesinin indeksi

    // Presence heartbeat/yaşam-döngüsünü oturum boyunca diri tut (§WP-5): çalışma
    // sürerken satırı düzenli tazeler, uygulama öldürülünce karşı taraf çevrimdışı
    // görür. Kabuk her zaman monte olduğu için burada izlenir.
    ref.watch(presenceLifecycleProvider);

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
            // Menü basılan konumda açılır (§3.12).
            showClassSwitcher(context, ref, at: details.globalPosition);
          }
        },
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: ref.read(navIndexProvider.notifier).setIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Gruplar',
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
