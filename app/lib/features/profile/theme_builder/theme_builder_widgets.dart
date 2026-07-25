import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'theme_contrast.dart';

/// Sihirbazın ortak küçük parçaları. Hepsi ≥ 48 dp dokunma hedefi kullanır.

/// Renk seçimi: etiket + mevcut renk + dokununca palet ızgarası.
class ColorField extends StatelessWidget {
  const ColorField({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
    this.warning,
    this.onFixWarning,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  /// Kontrast uyarısı (null = sorun yok).
  final String? warning;
  final VoidCallback? onFixWarning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              final picked = await showModalBottomSheet<Color>(
                context: context,
                showDragHandle: true,
                builder: (_) => _ColorPickerSheet(title: label, selected: color),
              );
              if (picked != null) onChanged(picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _Swatch(color: color),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  if (onFixWarning != null)
                    TextButton(
                      onPressed: onFixWarning,
                      child: Text(l10n.profileKontrastDuzelt),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}

class _ColorPickerSheet extends StatelessWidget {
  const _ColorPickerSheet({required this.title, required this.selected});

  final String title;
  final Color selected;

  /// Seçim hedefi sabit renkler (tema token'ı değil) — eski
  /// `custom_palette_editor.dart` ızgarasından taşındı ve nötr tonlarla
  /// genişletildi (zemin/metin renkleri de buradan seçiliyor).
  static const _options = <Color>[
    Color(0xFF000000), Color(0xFF0C0F16), Color(0xFF141821), Color(0xFF1E2430),
    Color(0xFF2A3240), Color(0xFF475569), Color(0xFF64748B), Color(0xFF94A3B8),
    Color(0xFFCBD5E1), Color(0xFFE9ECF3), Color(0xFFF7F8FB), Color(0xFFFFFFFF),
    Color(0xFFEF4444), Color(0xFFF43F5E), Color(0xFFEC4899), Color(0xFFA855F7),
    Color(0xFF8B5CF6), Color(0xFF6366F1), Color(0xFF3186E9), Color(0xFF0EA5E9),
    Color(0xFF22B8CF), Color(0xFF14B8A6), Color(0xFF12C281), Color(0xFF22C55E),
    Color(0xFF84CC16), Color(0xFFEAB308), Color(0xFFF59E0B), Color(0xFFF97316),
    Color(0xFFD4A373), Color(0xFF8B5E34), Color(0xFF00E5FF), Color(0xFFFF007F),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _options.length,
              itemBuilder: (context, index) {
                final option = _options[index];
                final isSelected = option.toARGB32() == selected.toARGB32();
                return InkWell(
                  key: ValueKey('themeColor_${option.toARGB32()}'),
                  onTap: () => Navigator.of(context).pop(option),
                  customBorder: const CircleBorder(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: option,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 18, color: readableOn(option))
                        : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiketli kaydırıcı — değer sağda okunur biçimde gösterilir.
class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.valueLabel,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              valueLabel ?? value.toStringAsFixed(1),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Adım göstergesi — dokunarak da geçilebilir (≥ 48 dp hedef).
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.count,
    required this.current,
    required this.onSelect,
  });

  final int count;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // WP-306: 8 adım × 48 dp = 384 dp; 360 dp'lik telefonda satır taşıyordu.
    // Yer varken 48 dp dokunma hedefi korunur, dar ekranda eşit bölüşülür.
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth.isFinite
            ? (constraints.maxWidth / count).clamp(0.0, 48.0)
            : 48.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              InkWell(
                onTap: () => onSelect(i),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: slot,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: i == current ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == current
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
