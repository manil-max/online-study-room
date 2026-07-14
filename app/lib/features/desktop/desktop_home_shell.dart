import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../profile/settings_screen.dart';

class DesktopHomeShell extends StatelessWidget {
  const DesktopHomeShell({
    required this.selectedIndex,
    required this.screens,
    required this.onDestinationSelected,
    required this.onRefresh,
    super.key,
  });

  final int selectedIndex;
  final List<Widget> screens;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onRefresh;

  static const _destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Ana Sayfa'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.access_time_outlined),
      selectedIcon: Icon(Icons.access_time_filled),
      label: Text('Saat'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups),
      label: Text('Gruplar'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: Text('İstatistik'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Profil'),
    ),
  ];

  static const _numberKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];

  static void openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => Scaffold(
          appBar: AppBar(
            title: const Text('Ayarlar'),
            leading: IconButton(
              tooltip: 'Geri',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(pageContext).maybePop(),
            ),
          ),
          body: const SettingsScreen(embedded: true),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(BuildContext context) => {
    for (var index = 0; index < _destinations.length; index++)
      SingleActivator(_numberKeys[index], control: true): () =>
          onDestinationSelected(index),
    const SingleActivator(
      LogicalKeyboardKey.keyM,
      control: true,
      shift: true,
    ): () =>
        toggleDesktopCompactMode(),
    const SingleActivator(
      LogicalKeyboardKey.keyP,
      control: true,
      shift: true,
    ): () =>
        toggleDesktopAlwaysOnTop(),
    const SingleActivator(LogicalKeyboardKey.f5): onRefresh,
    // Virgül = ayarlar (masaüstü alışkanlığı)
    SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
        openSettings(context),
  };

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _shortcuts(context),
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mode = DesktopBreakpoints.navigationMode(
              constraints.maxWidth,
            );
            final expanded = mode == DesktopNavigationMode.expanded;
            // WP-71: Fluent/WinUI + macOS sidebar sentezi — keskin köşe,
            // mobil “yuvarlak tatlı pill” indicator yok; küçük pencere OK.
            final scheme = Theme.of(context).colorScheme;
            const railRadius = 4.0;
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    key: const ValueKey('desktop-navigation-rail'),
                    backgroundColor: scheme.surfaceContainerLowest,
                    extended: expanded,
                    minWidth: 64,
                    minExtendedWidth: 200,
                    groupAlignment: -1.0,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    // WinUI-benzeri seçim: az yuvarlatılmış dikdörtgen
                    indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(railRadius),
                    ),
                    indicatorColor: scheme.secondaryContainer,
                    selectedIconTheme: IconThemeData(
                      color: scheme.onSecondaryContainer,
                      size: 22,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: scheme.onSurfaceVariant,
                      size: 22,
                    ),
                    selectedLabelTextStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                    unselectedLabelTextStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    labelType: expanded
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                      child: Semantics(
                        label: 'Odak Kampı ana navigasyonu',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(railRadius),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 22,
                                color: scheme.primary,
                              ),
                              if (expanded) ...[
                                const SizedBox(width: 10),
                                Text(
                                  'Odak Kampı',
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          key: const ValueKey('desktop-rail-settings'),
                          tooltip: 'Ayarlar (Ctrl+,)',
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(railRadius),
                            ),
                          ),
                          onPressed: () => openSettings(context),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                        if (expanded)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Ayarlar',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Yenile (F5)',
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(railRadius),
                            ),
                          ),
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          tooltip: 'Her zaman üstte tut (Ctrl+Shift+P)',
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(railRadius),
                            ),
                          ),
                          onPressed: toggleDesktopAlwaysOnTop,
                          icon: const Icon(Icons.push_pin_outlined),
                        ),
                        IconButton(
                          tooltip: 'Compact Focus (Ctrl+Shift+M)',
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(railRadius),
                            ),
                          ),
                          onPressed: toggleDesktopCompactMode,
                          icon: const Icon(
                            Icons.picture_in_picture_alt_outlined,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    destinations: _destinations,
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: scheme.outlineVariant,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: selectedIndex,
                      children: screens,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
