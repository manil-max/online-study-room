import 'package:flutter/material.dart';

import '../../core/desktop/desktop_layout.dart';

/// Sol navigasyon öğesi (WinUI NavigationViewItem karşılığı).
class DesktopNavItem {
  const DesktopNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// WinUI NavigationView + macOS sidebar sentezi.
///
/// - Expanded (≥1008): ikon + etiket, ~248px
/// - Compact (641–1007): yalnız ikon, ~52px
/// - Minimal (≤640): yine compact ikon şeridi (her zaman görünür menü)
///
/// Seçim göstergesi sol kenarda 3px accent bar (mobil pill yok).
class DesktopNavigationPane extends StatelessWidget {
  const DesktopNavigationPane({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.footer,
    super.key,
  });

  final List<DesktopNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget footer;

  static const double expandedWidth = 248;
  static const double compactWidth = 52;
  static const double itemHeight = 40;
  static const double itemRadius = 4;
  static const double indicatorWidth = 3;
  static const double contentMargin = 4;

  @override
  Widget build(BuildContext context) {
    final mode = DesktopBreakpoints.navigationMode(
      MediaQuery.sizeOf(context).width,
    );
    final expanded = mode == DesktopNavigationMode.expanded;
    final width = expanded ? expandedWidth : compactWidth;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      key: const ValueKey('desktop-navigation-pane'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PaneHeader(expanded: expanded),
          // Header ile ilk sekme (Ana Sayfa) çakışmasın — WinUI menü boşluğu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                contentMargin,
                2,
                contentMargin,
                8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _NavItemTile(
                  item: item,
                  selected: index == selectedIndex,
                  expanded: expanded,
                  onTap: () => onSelected(index),
                  semanticsLabel: '${item.label}, sekme ${index + 1}',
                );
              },
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              contentMargin,
              8,
              contentMargin,
              8,
            ),
            child: footer,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                'Ctrl+1…5 · Ctrl+, Ayarlar',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: 'Odak Kampı ana navigasyonu',
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          expanded ? 12 : 8,
          12,
          expanded ? 12 : 8,
          12,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(
                  DesktopNavigationPane.itemRadius,
                ),
              ),
              child: Icon(
                Icons.local_fire_department,
                size: 16,
                color: scheme.onPrimaryContainer,
              ),
            ),
            if (expanded) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Odak Kampı',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItemTile extends StatefulWidget {
  const _NavItemTile({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
    required this.semanticsLabel,
  });

  final DesktopNavItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  State<_NavItemTile> createState() => _NavItemTileState();
}

class _NavItemTileState extends State<_NavItemTile> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = widget.selected;

    Color background;
    if (selected) {
      background = scheme.secondaryContainer;
    } else if (_hovered || _focused) {
      background = scheme.onSurface.withValues(alpha: 0.06);
    } else {
      background = Colors.transparent;
    }

    final iconColor = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final labelColor = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;

    final tile = Material(
      color: background,
      borderRadius: BorderRadius.circular(DesktopNavigationPane.itemRadius),
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hovered = h),
        onFocusChange: (f) => setState(() => _focused = f),
        borderRadius: BorderRadius.circular(DesktopNavigationPane.itemRadius),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        splashColor: scheme.primary.withValues(alpha: 0.08),
        child: SizedBox(
          height: DesktopNavigationPane.itemHeight,
          child: Stack(
            children: [
              // WinUI sol kenar selection indicator
              if (selected)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: DesktopNavigationPane.indicatorWidth,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: widget.expanded ? 12 : 0,
                  right: widget.expanded ? 10 : 0,
                ),
                child: widget.expanded
                    ? Row(
                        children: [
                          Icon(
                            selected
                                ? widget.item.selectedIcon
                                : widget.item.icon,
                            size: 20,
                            color: iconColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.item.label,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelLarge?.copyWith(
                                color: labelColor,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Icon(
                          selected
                              ? widget.item.selectedIcon
                              : widget.item.icon,
                          size: 22,
                          color: iconColor,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: tile,
    );

    if (!widget.expanded) {
      return Tooltip(
        message: widget.item.label,
        waitDuration: const Duration(milliseconds: 400),
        child: Semantics(
          button: true,
          selected: selected,
          label: widget.semanticsLabel,
          child: body,
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: widget.semanticsLabel,
      child: body,
    );
  }
}

/// Pane footer satırı — Settings / araçlar.
class DesktopNavFooterAction extends StatefulWidget {
  const DesktopNavFooterAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.expanded = true,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool expanded;
  final String? tooltip;

  @override
  State<DesktopNavFooterAction> createState() => _DesktopNavFooterActionState();
}

class _DesktopNavFooterActionState extends State<DesktopNavFooterAction> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bg = (_hovered || _focused)
        ? scheme.onSurface.withValues(alpha: 0.06)
        : Colors.transparent;

    final tile = Material(
      color: bg,
      borderRadius: BorderRadius.circular(DesktopNavigationPane.itemRadius),
      child: InkWell(
        onTap: widget.onPressed,
        onHover: (h) => setState(() => _hovered = h),
        onFocusChange: (f) => setState(() => _focused = f),
        borderRadius: BorderRadius.circular(DesktopNavigationPane.itemRadius),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: SizedBox(
          height: DesktopNavigationPane.itemHeight,
          child: widget.expanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: tile,
    );

    if (!widget.expanded) {
      return Tooltip(
        message: widget.tooltip ?? widget.label,
        waitDuration: const Duration(milliseconds: 400),
        child: padded,
      );
    }
    return padded;
  }
}
