import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// WP-921 — hazır temanın **gerçek küçük önizlemesi**.
///
/// Eski kapak (WP-349) bir renk şeridi ve iki küçük kareydi; sahip: "tema
/// ayarlamayı da geliştir birazcık" — kart, uygulamanın o temada nasıl
/// göründüğünü söylemiyordu (yazı, kart, buton, zemin havası).
///
/// Burada o temanın kendi token'larıyla minyatür bir ekran çizilir:
/// atmosfer degradesi + parıltı, mini uygulama çubuğu (başlık yazı ailesiyle
/// "Aa"), içinde sayaç (`25:00`, temanın sayaç fontuyla) olan bir kart, birincil
/// buton hapı ve vurgu çipi. Yarıçaplar temanın `AppShapes`'inden gelir.
///
/// 🔴 Ucuz kalmalı: ızgarada 16 kart var. Kart başına `ThemeData` KURULMAZ
/// (`ThemePreviewCard` tam tema kurar; burada gereksiz) — yalnız düz
/// kutu/degrade/metin çizilir. Metinler ekran yazı ölçeğiyle BÜYÜMEZ: bu bir
/// resimdir, okunacak içerik değil (erişilebilirlik adı kartın kendisindedir).
class AppearancePresetPreview extends StatelessWidget {
  const AppearancePresetPreview({super.key, required this.preset});

  final ThemePreset preset;

  /// Minyatür, gerçek ekranın ~yarı ölçeği; yarıçaplar da yarıya iner.
  static const double _scale = 0.5;

  @override
  Widget build(BuildContext context) {
    final colors = preset.colors;
    final shapes = preset.shapes;
    final atmosphere = preset.atmosphere;
    final id = preset.id;

    // Yazı AİLESİ temadan: 'serif'/'monospace' cihazda sistem fontuna
    // çözülür; ikisi de değilse platformun varsayılanı (Android'de Roboto).
    // O anki temanın ailesi KULLANILMAZ — seçili tema serif ya da özel bir
    // font ise 16 kartın hepsi onunla çizilirdi. Yedek aileler ekranın gövde
    // stilinden gelir (mağaza karesinde yüklenmemiş aile boş kutu çizmez).
    final theme = Theme.of(context);
    final platformFamily = theme.typography.black.bodyMedium?.fontFamily;
    final fallback = theme.textTheme.bodyMedium?.fontFamilyFallback;
    final titleFamily = preset.serifTitles ? 'serif' : platformFamily;
    final clockFamily = preset.monospaceClock ? 'monospace' : titleFamily;
    final titleStyle = TextStyle(
      fontFamily: titleFamily,
      fontFamilyFallback: fallback,
      fontSize: 11,
      height: 1.1,
      fontWeight: FontWeight.w700,
      color: colors.textPrimary,
    );
    final clockStyle = TextStyle(
      fontFamily: clockFamily,
      fontFamilyFallback: fallback,
      fontSize: 20,
      height: 1.1,
      fontWeight: FontWeight.w600,
      letterSpacing: preset.monospaceClock ? 0.6 : 0,
      color: colors.textPrimary,
    );

    double r(double radius) => radius * _scale;
    final cardRadius = BorderRadius.circular(r(shapes.radiusMd));
    final glass = atmosphere.glassOpacity > 0;

    return Semantics(
      excludeSemantics: true,
      child: MediaQuery.withNoTextScaling(
        child: ClipRRect(
          key: ValueKey('theme-preset-preview-$id'),
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            key: ValueKey('theme-preset-scaffold-$id'),
            decoration: BoxDecoration(
              color: colors.scaffold,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [atmosphere.gradientStart, atmosphere.gradientEnd],
              ),
            ),
            child: DecoratedBox(
              // Atmosfer parıltısı: sağ üstten sönen tek radyal degrade.
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -0.9),
                  radius: 1.1,
                  colors: [
                    atmosphere.glowColor.withValues(
                      alpha: (atmosphere.glowStrength * 0.45).clamp(0.0, 1.0),
                    ),
                    atmosphere.glowColor.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mini uygulama çubuğu.
                    Row(
                      children: [
                        Text('Aa', style: titleStyle, maxLines: 1),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FractionallySizedBox(
                              widthFactor: 0.6,
                              child: _Bar(
                                color: colors.textSecondary.withValues(
                                  alpha: 0.55,
                                ),
                                height: 4,
                              ),
                            ),
                          ),
                        ),
                        _Dot(color: colors.textSecondary, size: 6),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        key: ValueKey('theme-preset-surface-$id'),
                        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                        decoration: BoxDecoration(
                          color: glass
                              ? colors.surface1.withValues(
                                  alpha: 1 - atmosphere.glassOpacity * 0.5,
                                )
                              : colors.surface1,
                          borderRadius: cardRadius,
                          border: shapes.borderWidth > 0 || glass
                              ? Border.all(color: colors.border)
                              : null,
                          boxShadow: shapes.cardElevation > 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.10),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  '25:00',
                                  key: ValueKey('theme-preset-clock-$id'),
                                  style: clockStyle,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    key: ValueKey('theme-preset-primary-$id'),
                                    height: 13,
                                    constraints: const BoxConstraints(
                                      maxWidth: 46,
                                    ),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      borderRadius: BorderRadius.circular(
                                        r(shapes.radiusLg).clamp(0.0, 6.5),
                                      ),
                                    ),
                                    child: _Bar(
                                      color: colors.onPrimary.withValues(
                                        alpha: 0.85,
                                      ),
                                      height: 3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  key: ValueKey('theme-preset-accent-$id'),
                                  width: 18,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    borderRadius: BorderRadius.circular(
                                      r(shapes.radiusSm).clamp(0.0, 4.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
