import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../profile/settings_screen.dart';
import 'desktop_navigation_pane.dart';
import 'desktop_surface.dart';

/// Windows ana kabuğu — özel sol NavigationView pane (mobil NavigationBar değil).
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

  static const destinations = <DesktopNavItem>[
    DesktopNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Ana Sayfa',
    ),
    DesktopNavItem(
      icon: Icons.access_time_outlined,
      selectedIcon: Icons.access_time_filled,
      label: 'Saat',
    ),
    DesktopNavItem(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'Gruplar',
    ),
    DesktopNavItem(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'İstatistik',
    ),
    DesktopNavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profil',
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
    // Masaüstü: ortalanmış panel (tam ekran mobil sayfa değil).
    showDesktopPanel<void>(
      context: context,
      builder: (pageContext) => Scaffold(
        appBar: AppBar(
          title: const Text('Ayarlar'),
          leading: IconButton(
            tooltip: 'Kapat',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(pageContext, rootNavigator: true)
                .maybePop(),
          ),
        ),
        body: const SettingsScreen(embedded: true),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(BuildContext context) => {
    for (var index = 0; index < destinations.length; index++)
      SingleActivator(_numberKeys[index], control: true): () =>
          onDestinationSelected(index),
    const SingleActivator(
      LogicalKeyboardKey.keyM,
      control: true,
      shift: true,
    ): toggleDesktopCompactMode,
    const SingleActivator(
      LogicalKeyboardKey.keyP,
      control: true,
      shift: true,
    ): toggleDesktopAlwaysOnTop,
    const SingleActivator(LogicalKeyboardKey.f5): onRefresh,
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
            final scheme = Theme.of(context).colorScheme;

            return Scaffold(
              backgroundColor: scheme.surface,
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DesktopNavigationPane(
                    items: destinations,
                    selectedIndex: selectedIndex,
                    onSelected: onDestinationSelected,
                    footer: _PaneFooter(
                      expanded: expanded,
                      onSettings: () => openSettings(context),
                      onRefresh: onRefresh,
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: scheme.surface,
                      child: IndexedStack(
                        index: selectedIndex,
                        children: screens,
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

class _PaneFooter extends StatelessWidget {
  const _PaneFooter({
    required this.expanded,
    required this.onSettings,
    required this.onRefresh,
  });

  final bool expanded;
  final VoidCallback onSettings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesktopNavFooterAction(
          key: const ValueKey('desktop-rail-settings'),
          icon: Icons.settings_outlined,
          label: 'Ayarlar',
          tooltip: 'Ayarlar (Ctrl+,)',
          expanded: expanded,
          onPressed: onSettings,
        ),
        DesktopNavFooterAction(
          icon: Icons.refresh,
          label: 'Yenile',
          tooltip: 'Yenile (F5)',
          expanded: expanded,
          onPressed: onRefresh,
        ),
        DesktopNavFooterAction(
          icon: Icons.push_pin_outlined,
          label: 'Üstte tut',
          tooltip: 'Her zaman üstte tut (Ctrl+Shift+P)',
          expanded: expanded,
          onPressed: toggleDesktopAlwaysOnTop,
        ),
        DesktopNavFooterAction(
          icon: Icons.picture_in_picture_alt_outlined,
          label: 'Compact Focus',
          tooltip: 'Compact Focus (Ctrl+Shift+M)',
          expanded: expanded,
          onPressed: toggleDesktopCompactMode,
        ),
      ],
    );
  }
}
