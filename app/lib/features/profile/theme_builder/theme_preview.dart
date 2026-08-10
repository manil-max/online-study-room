import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/desktop/desktop_layout.dart';
import '../../../core/theme/theme_tokens.dart';
import 'feel_overlay.dart';

/// Canlı önizleme — eski `theme_studio_screen.dart` `_LivePreview`'ünden
/// taşındı ve genişletildi (plan: "sıfırdan yazılmaz").
///
/// Fark: artık sahte renklerle değil, **gerçek `ThemeData`** ile çiziliyor.
/// Böylece tipografi, kart yarıçapı/kenarlığı, buton biçimi ve `FeelOverlay`
/// (atmosfer + his) uygulamada görüneceği gibi görünür.
/// WP-311: önizlemenin **o adımda değişen şeyi** öne çıkarması için odak.
///
/// Sahip: "fontlarda bazı ayarı değiştiriyoruz neye etki ediyor görünmüyor."
/// Yazı adımında iki mini kart yerine etiketli yazı örnekleri gösterilir;
/// hangi seçimin başlığa, gövdeye ve sayaca dokunduğu doğrudan okunur.
enum ThemePreviewFocus { none, typography }

class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({
    super.key,
    required this.theme,
    this.label,
    this.focus = ThemePreviewFocus.none,
  });

  final ThemeData theme;

  /// Üst köşede gösterilen bağlam etiketi (ör. "Koyu").
  final String? label;

  /// O anki sihirbaz adımının vurgusu.
  final ThemePreviewFocus focus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = context.appColors;
          final text = Theme.of(context).textTheme;
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FeelOverlay(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.scaffold,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔴 WP-684 — SPEC KURAL 2.2. Bu satır `Expanded` ile
                    // SINIRSIZDI: "Canlı önizleme" solda, mod etiketi ("Koyu")
                    // kabın en sağında. Panel sabit 920 px iken görünmüyordu
                    // (önizleme 388 px); panel pencereyle büyüyünce ölçüldü —
                    // 1472 px'lik bantta önizleme 664 px, satır **634 px**,
                    // yani SPEC'in 600 px'lik SERT tavanının (80 karakter,
                    // WCAG 2.1 SC 1.4.8) üstü. Kural: satır kabı doldurmaz,
                    // 496 px'te (Bringhurst 66ch hedefi) bırakılır ve sola
                    // yaslanır. Mobilde kart zaten 496'dan dar — dal etkisiz.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: DesktopBreakpoints.labelValueTargetWidth,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.profileCanliOnizleme,
                                style: text.labelMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            if (label != null)
                              Text(
                                label!,
                                style: text.labelSmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(l10n.profileOnizlemeBaslikOrnegi, style: text.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      l10n.profileOnizlemeGovdeOrnegi,
                      style: text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (focus == ThemePreviewFocus.typography)
                      _TypographySpecimen(colors: colors)
                    else
                      // Yükseklik ListView içinde sınırsız; iki kartı eşitlemek
                      // için içsel yükseklik gerekiyor.
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _TodayCard(colors: colors)),
                            const SizedBox(width: 10),
                            Expanded(child: _TimerCard(colors: colors)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// WP-311: yazı adımının örnekliği — hangi seçim nereye dokunuyor?
///
/// Üç satır, üç font seçicisinin birebir karşılığı: başlık, gövde, sayaç.
/// Kalınlık/ölçek/harf aralığı kaydırıcıları da aynı üç örnekte görünür.
class _TypographySpecimen extends StatelessWidget {
  const _TypographySpecimen({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final typography = context.appTypography;

    Widget row(String caption, Widget sample) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: text.labelSmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          sample,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        row(
          l10n.profileYaziBaslikFontu,
          Text(
            l10n.profileOnizlemeBaslikOrnegi,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleLarge,
          ),
        ),
        row(
          l10n.profileYaziGovdeFontu,
          Text(
            l10n.profileOnizlemeGovdeOrnegi,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium,
          ),
        ),
        row(
          l10n.profileYaziSayacFontu,
          Text(
            '00:42:18',
            style: typography.displayClock.copyWith(
              fontSize: 26,
              color: colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.profileBugun,
              style: text.labelSmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text('2:14', style: text.titleMedium),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.62,
                minHeight: 6,
                color: colors.primary,
                backgroundColor: colors.surface2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final typography = context.appTypography;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.profileSayac,
              style: text.labelSmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '00:42:18',
              style: typography.displayClock.copyWith(
                fontSize: 22,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                minimumSize: const Size.fromHeight(36),
                padding: EdgeInsets.zero,
              ),
              onPressed: () {},
              child: Text(l10n.profileDurdur, style: text.labelMedium),
            ),
          ],
        ),
      ),
    );
  }
}
