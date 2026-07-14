import 'package:flutter/material.dart';

import '../../core/desktop/desktop_layout.dart';

/// Windows 11 yoğunluğu — tema tokenlarından türetilir (ikinci tema yok).
class DesktopDensity {
  const DesktopDensity({
    required this.pagePadding,
    required this.panelRadius,
    required this.sectionGap,
    required this.commandHeight,
  });

  final EdgeInsets pagePadding;
  final double panelRadius;
  final double sectionGap;
  final double commandHeight;

  factory DesktopDensity.of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1440) {
      return const DesktopDensity(
        pagePadding: EdgeInsets.fromLTRB(28, 20, 28, 24),
        panelRadius: 16,
        sectionGap: 20,
        commandHeight: 52,
      );
    }
    if (width >= DesktopBreakpoints.expanded) {
      return const DesktopDensity(
        pagePadding: EdgeInsets.fromLTRB(24, 18, 24, 20),
        panelRadius: 16,
        sectionGap: 16,
        commandHeight: 48,
      );
    }
    return const DesktopDensity(
      pagePadding: EdgeInsets.fromLTRB(16, 14, 16, 16),
      panelRadius: 14,
      sectionGap: 12,
      commandHeight: 44,
    );
  }
}

/// Windows 11 masaüstü sayfalarının ortak başlık, komut ve içerik yüzeyi.
/// Mobil ekranların AppBar'ını büyütmek yerine desktop'a tutarlı bir bilgi
/// hiyerarşisi verir.
class DesktopPageScaffold extends StatelessWidget {
  const DesktopPageScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final density = DesktopDensity.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final identity = Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                return Semantics(
                  container: true,
                  label: '$title komut çubuğu',
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 20 : density.pagePadding.left,
                      18,
                      compact ? 20 : density.pagePadding.right,
                      18,
                    ),
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              identity,
                              if (actions.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: actions,
                                ),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: identity),
                              if (actions.isNotEmpty) ...[
                                const SizedBox(width: 20),
                                Wrap(spacing: 8, children: actions),
                              ],
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Sol bölüm listesi + sağ detay (Profil/Ayarlar tarzı kategori+detay).
class DesktopMasterDetail extends StatelessWidget {
  const DesktopMasterDetail({
    required this.master,
    required this.detail,
    this.masterWidth = 280,
    this.breakpoint = DesktopBreakpoints.expanded,
    this.spacing = 16,
    super.key,
  });

  final Widget master;
  final Widget detail;
  final double masterWidth;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return detail;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: masterWidth,
              child: master,
            ),
            SizedBox(width: spacing),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}

class DesktopSectionItem {
  const DesktopSectionItem({
    required this.id,
    required this.icon,
    required this.label,
    this.subtitle,
  });

  final String id;
  final IconData icon;
  final String label;
  final String? subtitle;
}

/// Klavye odaklı bölüm navigasyonu (görünür focus, Enter/Space).
class DesktopSectionList extends StatelessWidget {
  const DesktopSectionList({
    required this.items,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<DesktopSectionItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final density = DesktopDensity.of(context);
    return DesktopPanel(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item.id == selectedId;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Material(
              color: selected
                  ? theme.colorScheme.secondaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                focusColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                onTap: () => onSelected(item.id),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: density.commandHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: selected
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? theme.colorScheme.onSecondaryContainer
                                      : null,
                                ),
                              ),
                              if (item.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bağlamsal ipucu / özet paneli (ikincil kolon).
class DesktopContextPanel extends StatelessWidget {
  const DesktopContextPanel({
    required this.title,
    required this.child,
    this.icon = Icons.info_outline,
    super.key,
  });

  final String title;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DesktopPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class DesktopContent extends StatelessWidget {
  const DesktopContent({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.maxWidth = DesktopBreakpoints.maxContentWidth,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class DesktopPanel extends StatelessWidget {
  const DesktopPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = DesktopDensity.of(context).panelRadius;
    return Material(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class DesktopResponsiveColumns extends StatelessWidget {
  const DesktopResponsiveColumns({
    required this.primary,
    required this.secondary,
    this.secondaryWidth = 360,
    this.breakpoint = 1080,
    this.spacing = 20,
    super.key,
  });

  final Widget primary;
  final Widget secondary;
  final double secondaryWidth;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              SizedBox(height: spacing),
              secondary,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: primary),
            SizedBox(width: spacing),
            SizedBox(width: secondaryWidth, child: secondary),
          ],
        );
      },
    );
  }
}
