import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ana Sayfa sekmesi (IndexedStack indeksi 0).
const kHomeTabIndex = 0;

/// Alt navigasyonda seçili sekme indeksini tutar.
///
/// Aynı sekmeye tekrar basılınca [navReselectProvider] artar (ör. Ana Sayfa
/// en üste kaydır — birçok uygulamadaki “tap to top” davranışı).
class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (state == index) {
      ref.read(navReselectProvider.notifier).notifyReselect(index);
      return;
    }
    state = index;
  }
}

final navIndexProvider = NotifierProvider<NavIndexNotifier, int>(
  NavIndexNotifier.new,
);

/// Aynı alt sekmeye yeniden basıldığında `(tabIndex, tick)` — dinleyiciler
/// tick değişince tepki verir.
class NavReselect {
  const NavReselect({required this.tabIndex, required this.tick});

  final int tabIndex;
  final int tick;
}

class NavReselectNotifier extends Notifier<NavReselect> {
  @override
  NavReselect build() => const NavReselect(tabIndex: -1, tick: 0);

  void notifyReselect(int tabIndex) {
    state = NavReselect(tabIndex: tabIndex, tick: state.tick + 1);
  }
}

final navReselectProvider =
    NotifierProvider<NavReselectNotifier, NavReselect>(NavReselectNotifier.new);
