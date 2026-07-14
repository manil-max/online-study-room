import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_settings.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../desktop/desktop_surface.dart';

/// WP-55: Katmanlı Tema Stüdyosu — atmosfer aileleri + mood + canlı önizleme.
///
/// Masaüstü: sol kontroller + sağ sabit önizleme (full-bleed kaydırma yok).
/// Mobil: dikey adım akışı.
class ThemeStudioScreen extends ConsumerStatefulWidget {
  const ThemeStudioScreen({super.key});

  @override
  ConsumerState<ThemeStudioScreen> createState() => _ThemeStudioScreenState();
}

class _ThemeStudioScreenState extends ConsumerState<ThemeStudioScreen> {
  /// 0 = aile, 1 = mood, 2 = şekil hissi (bilgi), 3 = önizleme özeti
  var _step = 0;

  /// Önizleme için geçici seçim (Uygula deyince kalıcı).
  String? _draftFamilyId;
  ThemeMode? _draftMode;
  _ShapeFeel _draftShape = _ShapeFeel.soft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(themeSettingsProvider);
      setState(() {
        _draftFamilyId = s.familyId;
        _draftMode = s.mode;
      });
    });
  }

  void _apply() {
    final notifier = ref.read(themeSettingsProvider.notifier);
    final familyId = _draftFamilyId;
    final mode = _draftMode;
    if (familyId != null) notifier.setFamily(familyId);
    if (mode != null) notifier.setMode(mode);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tema uygulandı — yeniden başlatma gerekmez.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(themeSettingsProvider);
    final familyId = _draftFamilyId ?? settings.familyId;
    final mode = _draftMode ?? settings.mode;
    final preset = themePresetById(familyId);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final desktop = isDesktopWindow;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tema Stüdyosu'),
        actions: [
          TextButton(onPressed: _apply, child: const Text('Uygula')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _StepHeader(
              step: _step,
              onStep: (s) => setState(() => _step = s),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sideBySide = desktop && constraints.maxWidth >= 720;
                final controls = _buildStepContent(
                  theme: theme,
                  colors: colors,
                  familyId: familyId,
                  mode: mode,
                  preset: preset,
                  gridColumns: desktopGridColumns(
                    sideBySide
                        ? constraints.maxWidth * 0.58
                        : constraints.maxWidth,
                    compact: 1,
                    medium: 2,
                    expanded: 2,
                  ),
                );

                if (!sideBySide) {
                  return ListView(
                    padding: getSafeVerticalPadding(
                      context,
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: [
                      _LivePreview(preset: preset, shape: _draftShape),
                      const SizedBox(height: 20),
                      ...controls,
                    ],
                  );
                }

                // Masaüstü: sol kaydırılabilir kontroller, sağ sabit önizleme
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: ListView(
                          children: controls,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _LivePreview(
                            preset: preset,
                            shape: _draftShape,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Geri'),
                    ),
                  const Spacer(),
                  if (_step < 3)
                    FilledButton(
                      onPressed: () => setState(() => _step++),
                      child: const Text('İleri'),
                    )
                  else
                    FilledButton(
                      onPressed: _apply,
                      child: const Text('Bitir'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStepContent({
    required ThemeData theme,
    required AppColors colors,
    required String familyId,
    required ThemeMode mode,
    required ThemePreset preset,
    required int gridColumns,
  }) {
    if (_step == 0) {
      return [
        Text('1 · Atmosfer seç', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Buzul, ateş, neon, yumuşak… tüm arayüz havası değişir. '
          'Anında önizlenir.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (gridColumns <= 1)
          ...kThemePresets.map((p) {
            final selected = p.id == familyId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ThemeTile(
                preset: p,
                selected: selected,
                onTap: () => setState(() => _draftFamilyId = p.id),
              ),
            );
          })
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kThemePresets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
            ),
            itemBuilder: (context, i) {
              final p = kThemePresets[i];
              return _ThemeTile(
                preset: p,
                selected: p.id == familyId,
                onTap: () => setState(() => _draftFamilyId = p.id),
              );
            },
          ),
      ];
    }
    if (_step == 1) {
      return [
        Text('2 · Mood', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Koyu'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Açık'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Sistem'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => setState(() => _draftMode = s.first),
              showSelectedIcon: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Açık/koyu aile eşlemesi: açık temalar Nordic/Paper/Pastel; '
          'koyu temalar Campfire ve diğer gece aileleri.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ];
    }
    if (_step == 2) {
      return [
        Text(
          '3 · Kart şekli (önizleme)',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _ShapeFeel.values.map((feel) {
            final selected = _draftShape == feel;
            return ChoiceChip(
              label: Text(feel.label),
              selected: selected,
              onSelected: (_) => setState(() => _draftShape = feel),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          'Şekil seçimi önizlemede yansır. Kalıcı şekil motoru WP-55 gelişmiş '
          'stüdyoda genişletilebilir; şu an aile varsayılanı korunur.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ];
    }
    return [
      Text('4 · Özet ve uygula', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: _Swatch(colors: preset.colors),
          title: Text(preset.name),
          subtitle: Text(
            '${preset.description}\n'
            'Mood: ${_modeLabel(mode)} · Şekil: ${_draftShape.label}',
          ),
          isThreeLine: true,
        ),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _apply,
          icon: const Icon(Icons.check),
          label: const Text('Temayı uygula'),
        ),
      ),
    ];
  }

  String _modeLabel(ThemeMode m) => switch (m) {
        ThemeMode.dark => 'Koyu',
        ThemeMode.light => 'Açık',
        ThemeMode.system => 'Sistem',
      };
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: selected
          ? preset.colors.primary.withValues(alpha: 0.12)
          : colors.surface1,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              _Swatch(colors: preset.colors),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      preset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      preset.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: preset.colors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ShapeFeel { sharp, soft, bubble }

extension on _ShapeFeel {
  String get label => switch (this) {
        _ShapeFeel.sharp => 'Keskin',
        _ShapeFeel.soft => 'Yuvarlak',
        _ShapeFeel.bubble => 'Balon',
      };

  double get radius => switch (this) {
        _ShapeFeel.sharp => 0,
        _ShapeFeel.soft => 16,
        _ShapeFeel.bubble => 28,
      };
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.onStep});
  final int step;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Tema', 'Mood', 'Şekil', 'Uygula'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const Expanded(child: Divider()),
          InkWell(
            onTap: () => onStep(i),
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: i == step
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              foregroundColor: i == step
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Expanded(child: Container(color: colors.scaffold)),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: Container(color: colors.primary)),
                  Expanded(child: Container(color: colors.accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sahte dashboard kartı + sayaç — seçilen preset renkleriyle.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.preset, required this.shape});

  final ThemePreset preset;
  final _ShapeFeel shape;

  @override
  Widget build(BuildContext context) {
    final c = preset.colors;
    final r = BorderRadius.circular(shape.radius);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.scaffold, c.surface1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Canlı önizleme',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surface1,
                    borderRadius: r,
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bugün',
                        style: TextStyle(color: c.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '2s 14dk',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.62,
                          minHeight: 6,
                          color: c.primary,
                          backgroundColor: c.surface2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: r,
                    border: Border.all(color: c.primary.withValues(alpha: 0.5)),
                    boxShadow: preset.atmosphere.glowStrength > 0
                        ? [
                            BoxShadow(
                              color: c.primary.withValues(
                                alpha: preset.atmosphere.glowStrength * 0.35,
                              ),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Sayaç',
                        style: TextStyle(color: c.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '00:42:18',
                        style: TextStyle(
                          color: c.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          fontFamily: preset.monospaceClock ? 'monospace' : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: c.onPrimary,
                          minimumSize: const Size.fromHeight(32),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () {},
                        child: const Text('Durdur', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
