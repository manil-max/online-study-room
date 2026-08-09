import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/navigation/profile_tab_badge.dart';
import '../../core/theme/container_roles.dart';
import '../../core/theme/focus_ring_tokens.dart';

/// Sol navigasyon öğesi (WinUI NavigationViewItem karşılığı).
class DesktopNavItem {
  const DesktopNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// WP-594: mobil alt çubukla **aynı** rozet nesnesi. Verilmezse rozet
  /// çizilmez — masaüstünde eskiden durum buydu ve Windows kullanıcısı
  /// bekleyen ödülünü, okunmamış duyurusunu, eksik birincil grup uyarısını
  /// hiç görmüyordu.
  final ProfileTabBadge? badge;
}

/// WinUI NavigationView + macOS sidebar sentezi.
///
/// - Expanded (≥1008): ikon + etiket, ~176px
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

  static const double expandedWidth = 176;
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
                  semanticsLabel: AppLocalizations.of(
                    context,
                  ).desktopItemlabelSekmeIndex1(item.label, '${index + 1}'),
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
                'Ctrl+1…5 · Ctrl+, ${AppLocalizations.of(context).desktopAyarlar}',
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

/// WinUI odak dikdörtgeni.
///
/// Odak göstergesi **hover ile aynı olamaz**: ölçümde odaklanmış sekme yalnız
/// `onSurface` %6 zeminle işaretleniyordu, yani koyu temada hem görünmüyor hem
/// de fareyle gezinmeden ayırt edilemiyordu (WP-569 cihaz ölçümü). Halka ön
/// planda çizilir; yerleşimi kaydırmaz, seçili/hover zeminini de ezmez.
///
/// 🔴 WP-594: renk artık `colorScheme.primary` DEĞİL. Primary'ye bağlıyken
/// Tema Stüdyosu'nda panel zeminine yakın palet seçen kullanıcıda halka eriyip
/// kayboluyordu — "uyarı rozeti tema çakışması"nın (WP-358) aynısı. Renk
/// [focusRingColorOn] ile **zeminden** türetilir; bkz.
/// `core/theme/focus_ring_tokens.dart`.
class DesktopNavFocusRing extends StatelessWidget {
  const DesktopNavFocusRing({
    required this.focused,
    required this.child,
    this.background,
    super.key,
  });

  final bool focused;
  final Widget child;

  /// Halkanın üstünde durduğu zemin. Verilmezse panel zemini kullanılır.
  final Color? background;

  static const double thickness = 2;

  @override
  Widget build(BuildContext context) {
    final surface =
        background ?? Theme.of(context).colorScheme.surfaceContainerLowest;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesktopNavigationPane.itemRadius),
        border: Border.all(
          color: focused ? focusRingColorOn(surface) : Colors.transparent,
          width: thickness,
        ),
      ),
      child: child,
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
      label: AppLocalizations.of(context).desktopOdakKampiAnaNavigasyonu,
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
                  AppLocalizations.of(context).desktopOdakKampi,
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

  /// WP-594: rozet mantığı burada **tekrarlanmaz** — mobil alt çubukla aynı
  /// [ProfileTabBadge] nesnesi çizdirir. Uyarı noktasının rengi sol panelin
  /// kendi zemininden türer, alt çubuğunkinden değil.
  Widget _badged(Widget icon, ColorScheme scheme) {
    final badge = widget.item.badge;
    if (badge == null || !badge.isVisible) return icon;
    return badge.wrap(
      icon,
      surface: scheme.surfaceContainerLowest,
      announcementColor: scheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = widget.selected;

    Color background;
    if (selected) {
      background = scheme.secondaryContainer;
    } else if (_hovered) {
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
          // Stack varsayılanı topStart → ikon/metin yukarı kayıyordu;
          // buton dikdörtgeni doğru, içerik dikey ortada olmalı.
          child: Stack(
            alignment: Alignment.centerLeft,
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
                      // 🔴 WP-627: çubuk paletten **ham** alınamaz. Zemini
                      // seçili döşemedir (`secondaryContainer`), panel değil;
                      // ölçüldü: ham `primary` 15 temanın 13'ünde 3.0 altında,
                      // ikisinde 1.01 — yani çubuk hiç görünmüyordu.
                      color: accentOn(background, preferred: scheme.primary),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: widget.expanded ? 10 : 0,
                  right: widget.expanded ? 8 : 0,
                ),
                child: widget.expanded
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _badged(
                            Icon(
                              selected
                                  ? widget.item.selectedIcon
                                  : widget.item.icon,
                              size: 20,
                              color: iconColor,
                            ),
                            scheme,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.item.label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                              style: textTheme.labelLarge?.copyWith(
                                color: labelColor,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        // Daraltılmış şeritte etiket yok; rozet burada da
                        // çizilmezse sinyal masaüstünde tamamen kaybolur.
                        child: _badged(
                          Icon(
                            selected
                                ? widget.item.selectedIcon
                                : widget.item.icon,
                            size: 22,
                            color: iconColor,
                          ),
                          scheme,
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
      child: DesktopNavFocusRing(
        focused: _focused,
        // Halka döşemenin üstünde durur; seçili döşemenin zemini panelinkinden
        // farklıdır. Şeffaf zeminde (hover %6 dâhil) panel zemini geçerlidir.
        background: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLowest,
        child: tile,
      ),
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
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool expanded;
  final String? tooltip;

  /// Açık/kapalı durum (örn. Üstte tut pin).
  final bool selected;

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
    final selected = widget.selected;
    final Color bg;
    if (selected) {
      bg = scheme.secondaryContainer;
    } else if (_hovered) {
      bg = scheme.onSurface.withValues(alpha: 0.06);
    } else {
      bg = Colors.transparent;
    }
    final iconColor = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final labelColor = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;

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
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(widget.icon, size: 20, color: iconColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style: textTheme.labelLarge?.copyWith(
                            color: labelColor,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (selected)
                        // WP-627: onay ikonu da seçili döşemenin zemininde
                        // durur; ham `primary` orada eriyordu.
                        Icon(
                          Icons.check,
                          size: 16,
                          color: accentOn(bg, preferred: scheme.primary),
                        ),
                    ],
                  ),
                )
              : Center(child: Icon(widget.icon, size: 22, color: iconColor)),
        ),
      ),
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: DesktopNavFocusRing(
        focused: _focused,
        background: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLowest,
        child: tile,
      ),
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
