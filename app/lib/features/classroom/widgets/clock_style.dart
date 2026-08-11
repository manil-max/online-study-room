import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/app_prefs.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/anchored_menu.dart';
import '../../../data/providers/study_providers.dart' show TimerPhase;

/// Saat (sayaç) görünüm stilleri (§3.12). Varsayılan sade; isteyen değiştirir.
/// Şimdilik seçim bellek-içi (uygulama yenilenince sıfırlanır) — kalıcılık sonra.
enum ClockStyle {
  /// Sade rakam (varsayılan).
  digits,

  /// Günlük hedefe göre dolan halka + ortada süre.
  ring,

  /// Hedefe yaklaştıkça rakam rengi zıt→yeşil döner.
  colorShift,

  /// Pasta dilimi gibi dolan yarış stili.
  slice,

  /// Saç teli inceliğinde halka. **Çizgi kalınlığı** stilidir; kartın
  /// boyutuyla ilgisi yoktur (WP-715: eski adı "Minimal"di ve küçüklük vaat
  /// ediyordu — etiket `classroomMinimal` "İnce halka"ya çevrildi).
  minimal,

  /// 🔴 WP-715 — kartı GERÇEKTEN küçülten tek görünüm.
  ///
  /// Yukarıdaki beş stil yalnız saatin ÇİZİMİNİ değiştirir; sayaç kartının
  /// yüksekliğine hiçbiri dokunmaz. `compact` kartı tek satıra indirir:
  /// **süre + Başlat/Durdur** kalır, "Bugün" toplamı, mod seçici, günlük hedef
  /// çubuğu, ders seçici hapı ve "manuel süre ekle" gizlenir.
  /// Ölçüm: `timer_card_compact_wp715_test.dart`.
  compact,
}

extension ClockStyleInfo on ClockStyle {
  String label(BuildContext context) => switch (this) {
    ClockStyle.digits => AppLocalizations.of(context).classroomSadeRakam,
    ClockStyle.ring => AppLocalizations.of(context).classroomHedefHalkasi,
    ClockStyle.colorShift => AppLocalizations.of(context).classroomRenkGecisi,
    ClockStyle.slice => AppLocalizations.of(context).classroomYarisDilimi,
    ClockStyle.minimal => AppLocalizations.of(context).classroomMinimal,
    ClockStyle.compact => AppLocalizations.of(context).classroomSaatKompakt,
  };

  /// Seçenek ne yapar? 🔴 WP-715: sahip "seçenekler var ama tam farklarını
  /// anlayamadım" dedi. Menüde ad tek başına yetmiyor — özellikle "Minimal"
  /// adı boyut vaat edip çizgi inceltiyordu.
  String description(BuildContext context) => switch (this) {
    ClockStyle.digits => AppLocalizations.of(
      context,
    ).classroomSaatSadeRakamAciklama,
    ClockStyle.ring => AppLocalizations.of(
      context,
    ).classroomSaatHedefHalkasiAciklama,
    ClockStyle.colorShift => AppLocalizations.of(
      context,
    ).classroomSaatRenkGecisiAciklama,
    ClockStyle.slice => AppLocalizations.of(
      context,
    ).classroomSaatYarisDilimiAciklama,
    ClockStyle.minimal => AppLocalizations.of(
      context,
    ).classroomSaatIncehalkaAciklama,
    ClockStyle.compact => AppLocalizations.of(
      context,
    ).classroomSaatKompaktAciklama,
  };

  IconData get icon => switch (this) {
    ClockStyle.digits => Icons.schedule,
    ClockStyle.ring => Icons.donut_large,
    ClockStyle.colorShift => Icons.gradient,
    ClockStyle.slice => Icons.pie_chart,
    ClockStyle.minimal => Icons.trip_origin,
    ClockStyle.compact => Icons.density_small,
  };
}

class ClockStyleNotifier extends Notifier<ClockStyle> {
  static const _key = 'clock_style';

  @override
  ClockStyle build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return ClockStyle.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ClockStyle.digits,
    );
  }

  void set(ClockStyle style) {
    state = style;
    ref.read(sharedPreferencesProvider).setString(_key, style.name);
  }
}

/// Seçili saat stili (kişiye özel, cihazda kalıcı).
final clockStyleProvider = NotifierProvider<ClockStyleNotifier, ClockStyle>(
  ClockStyleNotifier.new,
);

/// Hedefe göre renk: 0 → kırmızı (chart-5), 0.5 → amber (chart-3),
/// 1.0 → yeşil (chart-2). Aradaki değerler yumuşak geçişli.
Color goalColor(double pct) {
  final p = pct.clamp(0.0, 1.0);
  final red = subjectColor('chart-5');
  final amber = subjectColor('chart-3');
  final green = subjectColor('chart-2');
  if (p <= 0.5) return Color.lerp(red, amber, p / 0.5)!;
  return Color.lerp(amber, green, (p - 0.5) / 0.5)!;
}

/// WP-554 (a11y): `formatHms` "01:23:45" üretir ve TalkBack bunu **rakam
/// rakam** okur ("sıfır bir iki üç dört beş"). Ekran okuyucu için süre insan
/// dilinde söylenmeli. Katalog anahtarları dil başına doğru biçimi taşır
/// (EN'de tekil/çoğul, TR'de tek biçim).
///
/// Sıfır saniye de sessiz kalmamalı → en az "0 saniye" döner.
String spokenDuration(AppLocalizations l10n, int totalSeconds) {
  final total = totalSeconds < 0 ? 0 : totalSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final parts = <String>[
    if (h > 0) l10n.a11yDurationHours(h),
    if (m > 0) l10n.a11yDurationMinutes(m),
    if (s > 0 || (h == 0 && m == 0)) l10n.a11yDurationSeconds(s),
  ];
  return parts.join(' ');
}

/// Sayacın ekran okuyucuya okunan tam etiketi: **faz + insan okunur süre +
/// durum**. Ekrana bakmadan "mola mı çalışma mı, akıyor mu" anlaşılmalı.
///
/// Durum saf türetim: akıyorsa `çalışıyor`; akmıyor ama ekranda süre varsa
/// `duraklatıldı`; hiç başlamadıysa `durduruldu`.
String studyClockSemanticsLabel({
  required AppLocalizations l10n,
  required int seconds,
  required bool running,
  required TimerPhase phase,
}) {
  final status = running
      ? l10n.a11yTimerRunning
      : (seconds > 0 ? l10n.a11yTimerPaused : l10n.a11yTimerStopped);
  return l10n.a11yStudyClock(
    phase == TimerPhase.rest
        ? l10n.a11yTimerPhaseBreak
        : l10n.a11yTimerPhaseWork,
    spokenDuration(l10n, seconds),
    status,
  );
}

/// Seçili stile göre canlı süreyi gösteren saat. [seconds] gösterilecek süre
/// (genelde mevcut oturum), [pctToGoal] bugünkü toplamın günlük hedefe oranı.
class StudyClock extends StatelessWidget {
  const StudyClock({
    super.key,
    required this.seconds,
    required this.pctToGoal,
    required this.running,
    required this.style,
    required this.fontSize,
    this.diameter = 220,
    this.phase = TimerPhase.work,
  });

  final int seconds;
  final double pctToGoal;
  final bool running;
  final ClockStyle style;
  final double fontSize;
  final double diameter;

  /// Pomodoro fazı — yalnız erişilebilirlik etiketini etkiler, çizimi değil.
  /// Kronometre/geri sayımda her zaman [TimerPhase.work].
  final TimerPhase phase;

  @override
  Widget build(BuildContext context) {
    // 🔴 WP-554: etiket + `excludeSemantics`. Alttaki `Text` "01:23:45"i
    // rakam rakam okutuyordu; iç düğümler elenmezse TalkBack iki kez konuşur.
    // Semantics yerleşimi etkilemez → tek piksel bile oynamaz (golden yeşil).
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: studyClockSemanticsLabel(
        l10n: AppLocalizations.of(context),
        seconds: seconds,
        running: running,
        phase: phase,
      ),
      child: _clock(context),
    );
  }

  Widget _clock(BuildContext context) {
    final theme = Theme.of(context);
    final text = formatHms(seconds);

    switch (style) {
      // `compact` saati SADE RAKAM olarak çizer; kartı küçülten şey çizim
      // değil `StudyTimerCard`'ın tek satırlık düzenidir.
      case ClockStyle.digits:
      case ClockStyle.compact:
        return _digits(
          text,
          fontSize,
          running
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        );
      case ClockStyle.colorShift:
        return _digits(text, fontSize, goalColor(pctToGoal));
      case ClockStyle.ring:
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: pctToGoal.clamp(0.0, 1.0),
                  strokeWidth: 9,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goalColor(pctToGoal),
                  ),
                ),
              ),
              _digits(
                text,
                fontSize * 0.72,
                running
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ],
          ),
        );
      case ClockStyle.slice:
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CustomPaint(
                  painter: ClockPainter(
                    pctToGoal: pctToGoal.clamp(0.0, 1.0),
                    color: goalColor(pctToGoal),
                    bgColor: theme.colorScheme.surfaceContainerHighest,
                    isSlice: true,
                  ),
                ),
              ),
              // Dilim dolu olduğundan yazının arkasında daha belirgin görünmesi için gölge veya zıt renk gerekebilir,
              // şimdilik primary veya onSurface kullanıyoruz.
              _digits(
                text,
                fontSize * 0.72,
                running
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        );
      case ClockStyle.minimal:
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CustomPaint(
                  painter: ClockPainter(
                    pctToGoal: pctToGoal.clamp(0.0, 1.0),
                    color: goalColor(pctToGoal),
                    bgColor: theme.colorScheme.surfaceContainerHighest,
                    isSlice: false,
                  ),
                ),
              ),
              _digits(
                text,
                fontSize * 0.72,
                running
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ],
          ),
        );
    }
  }

  Widget _digits(String text, double size, Color color) {
    return Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1,
        // Sabit genişlikli rakamlar: süre değişirken sayılar zıplamasın/oynamasın.
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Saat stili seçici (anchored menü — §3.12 "basılan yerde" kalıbı).
Future<void> showClockStyleMenu(BuildContext context, WidgetRef ref) async {
  final theme = Theme.of(context);
  final current = ref.read(clockStyleProvider);
  final result = await showAnchoredMenu<ClockStyle>(
    context: context,
    items: [
      PopupMenuItem<ClockStyle>(
        enabled: false,
        height: 32,
        child: Text(
          AppLocalizations.of(context).classroomSaatGorunumu,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      for (final s in ClockStyle.values)
        PopupMenuItem<ClockStyle>(
          value: s,
          // İki satır: ad + ne yaptığı. Yükseklik `PopupMenuItem`ın asgarisi
          // değil içeriğidir, o yüzden açıklama kırpılmaz.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(s.icon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.label(context)),
                    const SizedBox(height: 2),
                    Text(
                      s.description(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (s == current)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 8),
                  child: Icon(
                    Icons.check,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
    ],
  );
  if (result != null) ref.read(clockStyleProvider.notifier).set(result);
}

class ClockPainter extends CustomPainter {
  ClockPainter({
    required this.pctToGoal,
    required this.color,
    required this.bgColor,
    required this.isSlice,
  });

  final double pctToGoal;
  final Color color;
  final Color bgColor;
  final bool isSlice;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width < size.height ? size.width / 2 : size.height / 2;

    if (isSlice) {
      // Pasta dilimi / yarış stili
      final bgPaint = Paint()
        ..color = bgColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, bgPaint);

      final slicePaint = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      // -pi/2'den (saat 12) başla, 2*pi * pctToGoal kadar dön
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.57079632679, // -math.pi / 2
        6.28318530718 * pctToGoal, // 2 * math.pi * pctToGoal
        true,
        slicePaint,
      );
    } else {
      // Minimal stil - ekstra ince çizgi
      final bgPaint = Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, bgPaint);

      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.57079632679,
        6.28318530718 * pctToGoal,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ClockPainter oldDelegate) {
    return pctToGoal != oldDelegate.pctToGoal ||
        color != oldDelegate.color ||
        bgColor != oldDelegate.bgColor ||
        isSlice != oldDelegate.isSlice;
  }
}
