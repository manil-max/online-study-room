import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ana kabuktaki tek kanonik sekme sırası. Ekran, destination, kısayol ve
/// tap-to-top sözleşmeleri çıplak sayı yerine bu enum'u kullanır.
enum AppTab { home, tools, groups, stats, profile }

/// Eski tap-to-top tüketicisi için geçiş alias'ı; sayı burada da yazılmaz.
final int kHomeTabIndex = AppTab.home.index;

/// Alt navigasyonda seçili sekme indeksini tutar.
///
/// Aynı sekmeye tekrar basılınca [navReselectProvider] artar (ör. Ana Sayfa
/// en üste kaydır — birçok uygulamadaki “tap to top” davranışı).
class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => AppTab.home.index;

  void setIndex(int index) {
    if (index < 0 || index >= AppTab.values.length) {
      throw RangeError.range(index, 0, AppTab.values.length - 1, 'index');
    }
    if (state == index) {
      ref.read(navReselectProvider.notifier).notifyReselect(index);
      return;
    }
    state = index;
  }

  void setTab(AppTab tab) => setIndex(tab.index);
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

final navReselectProvider = NotifierProvider<NavReselectNotifier, NavReselect>(
  NavReselectNotifier.new,
);
