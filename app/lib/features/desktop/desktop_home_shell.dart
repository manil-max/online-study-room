import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../profile/settings_screen.dart';
import 'desktop_navigation_pane.dart';
import 'desktop_proportional_scale.dart';
import 'desktop_surface.dart';

/// Windows ana kabuğu — özel sol NavigationView pane (mobil NavigationBar değil).
///
/// [DesktopProportionalScale] ile tek oranlı esnek ölçek; sekmeler tembel
/// yüklenir (IndexedStack 5 ekranı aynı anda tutmaz → RAM/CPU).
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

  static List<DesktopNavItem> destinations(BuildContext context) => [
    DesktopNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: AppLocalizations.of(context).homeAnaSayfa,
    ),
    DesktopNavItem(
      icon: Icons.access_time_outlined,
      selectedIcon: Icons.access_time_filled,
      label: AppLocalizations.of(context).desktopSaat,
    ),
    DesktopNavItem(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: AppLocalizations.of(context).desktopGruplar,
    ),
    DesktopNavItem(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: AppLocalizations.of(context).statsIstatistik,
    ),
    DesktopNavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: AppLocalizations.of(context).profileProfil,
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
          title: Text(AppLocalizations.of(context).profileAyarlar),
          leading: IconButton(
            tooltip: AppLocalizations.of(context).homeKapat,
            icon: const Icon(Icons.close),
            onPressed: () =>
                Navigator.of(pageContext, rootNavigator: true).maybePop(),
          ),
        ),
        body: const SettingsScreen(embedded: true),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(BuildContext context) => {
    for (var index = 0; index < destinations(context).length; index++)
      SingleActivator(_numberKeys[index], control: true): () =>
          onDestinationSelected(index),
    const SingleActivator(LogicalKeyboardKey.keyM, control: true, shift: true):
        toggleDesktopCompactMode,
    const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true):
        toggleDesktopAlwaysOnTop,
    const SingleActivator(LogicalKeyboardKey.f5): onRefresh,
    SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
        openSettings(context),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: _shortcuts(context),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          body: DesktopProportionalScale(
            child: Builder(
              builder: (context) {
                // Ölçek içi MediaQuery = tasarım boyutu → pane her zaman expanded.
                final mode = DesktopBreakpoints.navigationMode(
                  MediaQuery.sizeOf(context).width,
                );
                final expanded = mode == DesktopNavigationMode.expanded;
                return ColoredBox(
                  color: scheme.surface,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DesktopNavigationPane(
                        items: destinations(context),
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
                          child: _DesktopLazyTabHost(
                            selectedIndex: selectedIndex,
                            screens: screens,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Ziyaret edilen sekmeleri tutar; diğerlerini hiç kurmaz.
/// IndexedStack gibi durum korur ama 5 ağır ağacı baştan monte etmez.
class _DesktopLazyTabHost extends StatefulWidget {
  const _DesktopLazyTabHost({
    required this.selectedIndex,
    required this.screens,
  });

  final int selectedIndex;
  final List<Widget> screens;

  @override
  State<_DesktopLazyTabHost> createState() => _DesktopLazyTabHostState();
}

class _DesktopLazyTabHostState extends State<_DesktopLazyTabHost> {
  late final Set<int> _activated = {widget.selectedIndex};

  @override
  void didUpdateWidget(covariant _DesktopLazyTabHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activated.contains(widget.selectedIndex)) {
      _activated.add(widget.selectedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.screens.length; i++)
          if (_activated.contains(i))
            Offstage(
              offstage: i != widget.selectedIndex,
              child: TickerMode(
                enabled: i == widget.selectedIndex,
                child: widget.screens[i],
              ),
            ),
      ],
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
    return ListenableBuilder(
      listenable: desktopWindowListenable,
      builder: (context, _) {
        final pinned = isDesktopAlwaysOnTop;
        final compact = isDesktopCompactMode;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopNavFooterAction(
              key: const ValueKey('desktop-rail-settings'),
              icon: Icons.settings_outlined,
              label: AppLocalizations.of(context).profileAyarlar,
              tooltip:
                  '${AppLocalizations.of(context).profileAyarlar} (Ctrl+,)',
              expanded: expanded,
              onPressed: onSettings,
            ),
            DesktopNavFooterAction(
              icon: Icons.refresh,
              label: AppLocalizations.of(context).desktopYenile,
              tooltip: '${AppLocalizations.of(context).desktopYenile} (F5)',
              expanded: expanded,
              onPressed: onRefresh,
            ),
            DesktopNavFooterAction(
              key: const ValueKey('desktop-rail-pin'),
              icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: pinned
                  ? '${AppLocalizations.of(context).desktopUstteTut} · '
                        '${AppLocalizations.of(context).profileAcik}'
                  : AppLocalizations.of(context).desktopUstteTut,
              tooltip: pinned
                  ? '${AppLocalizations.of(context).desktopKapat} (Ctrl+Shift+P)'
                  : '${AppLocalizations.of(context).desktopHerZamanUstteTut} '
                        '(Ctrl+Shift+P)',
              expanded: expanded,
              selected: pinned,
              onPressed: toggleDesktopAlwaysOnTop,
            ),
            DesktopNavFooterAction(
              icon: compact
                  ? Icons.picture_in_picture_alt
                  : Icons.picture_in_picture_alt_outlined,
              label: AppLocalizations.of(context).desktopCompactFocus,
              tooltip:
                  '${AppLocalizations.of(context).desktopCompactFocus} '
                  '(Ctrl+Shift+M)',
              expanded: expanded,
              selected: compact,
              onPressed: toggleDesktopCompactMode,
            ),
          ],
        );
      },
    );
  }
}
