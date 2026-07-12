import 'package:flutter/material.dart';

import '../../core/desktop/desktop_layout.dart';

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
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 20 : 28,
                    18,
                    compact ? 20 : 24,
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
    return Material(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
