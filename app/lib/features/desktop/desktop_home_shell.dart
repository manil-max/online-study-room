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
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    key: const ValueKey('desktop-navigation-rail'),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLow,
                    extended: expanded,
                    minExtendedWidth: 208,
                    groupAlignment: -0.72,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    labelType: expanded
                        ? NavigationRailLabelType.none
                        : mode == DesktopNavigationMode.minimal
                        ? NavigationRailLabelType.selected
                        : NavigationRailLabelType.none,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Semantics(
                        label: 'Odak Kampı ana navigasyonu',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 26,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              if (expanded) ...[
                                const SizedBox(width: 10),
                                Text(
                                  'Odak Kampı',
                                  style: Theme.of(context).textTheme.titleMedium
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
                        const SizedBox(width: 40, child: Divider(height: 18)),
                        // Ayarlar — profil dışında, sol rail (dar/geniş hep görünür)
                        IconButton(
                          key: const ValueKey('desktop-rail-settings'),
                          tooltip: 'Ayarlar (Ctrl+,)',
                          onPressed: () => openSettings(context),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                        if (expanded)
                          Text(
                            'Ayarlar',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        IconButton(
                          tooltip: 'Yenile (F5)',
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          tooltip: 'Her zaman üstte tut (Ctrl+Shift+P)',
                          onPressed: toggleDesktopAlwaysOnTop,
                          icon: const Icon(Icons.push_pin_outlined),
                        ),
                        IconButton(
                          tooltip: 'Compact Focus (Ctrl+Shift+M)',
                          onPressed: toggleDesktopCompactMode,
                          icon: const Icon(
                            Icons.picture_in_picture_alt_outlined,
                          ),
                        ),
                      ],
                    ),
                    destinations: _destinations,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: DesktopBreakpoints.maxContentWidth,
                        ),
                        child: IndexedStack(
                          index: selectedIndex,
                          children: screens,
                        ),
                      ),
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
