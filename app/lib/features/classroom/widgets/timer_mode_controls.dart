import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/warning_tokens.dart';
import '../../../core/time_engine/implausible_run_guard.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/number_stepper.dart';
import '../../../data/providers/study_providers.dart';

/// Sayaç modu seçimi + moda özel ayarlar (§2H). Yalnız sayaç **dururken**
/// gösterilir/etkilidir: Kronometre / Geri sayım / Pomodoro seçilir, geri sayım
/// dakikası veya pomodoro çalışma-mola-döngü ayarlanır. Ayarlar cihazda kalıcıdır.
class TimerModeControls extends ConsumerWidget {
  const TimerModeControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(studyTimerProvider);
    final notifier = ref.read(studyTimerProvider.notifier);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Dar kartta yalnız ikon (etiket taşmasın); genişte ikon+metin.
            final compact = constraints.maxWidth < 320;
            return SegmentedButton<TimerMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: TimerMode.stopwatch,
                  icon: const Icon(Icons.timer_outlined),
                  label: compact
                      ? null
                      : Text(AppLocalizations.of(context).classroomKronometre),
                  tooltip: AppLocalizations.of(context).classroomKronometre,
                ),
                ButtonSegment(
                  value: TimerMode.countdown,
                  icon: const Icon(Icons.hourglass_empty),
                  label: compact
                      ? null
                      : Text(AppLocalizations.of(context).classroomGeriSayim),
                  tooltip: AppLocalizations.of(context).classroomGeriSayim,
                ),
                ButtonSegment(
                  value: TimerMode.pomodoro,
                  icon: const Icon(Icons.av_timer),
                  label: compact
                      ? null
                      : Text(AppLocalizations.of(context).classroomPomodoro),
                  tooltip: AppLocalizations.of(context).classroomPomodoro,
                ),
              ],
              selected: {timer.mode},
              onSelectionChanged: (s) => notifier.setMode(s.first),
            );
          },
        ),
        if (timer.mode != TimerMode.stopwatch) ...[
          const SizedBox(height: 12),
          _ConfigForMode(timer: timer, notifier: notifier),
        ],
      ],
    );
  }
}

/// Uyarı bloğunun kimliği; iki yönlü iddiayı testler bu anahtarla ölçer.
const Key kImplausibleRunNoticeKey = Key('timer-implausible-run');

/// 🔴 WP-595 — makul olmayan süre uyarısı.
///
/// Bu sınıf WP-430'dan beri **ölü bir `SizedBox.shrink()`** idi: sayaç
/// çalışırken hem kartta hem tam ekran odakta çiziliyor ama hiçbir şey
/// söylemiyordu. Yani iki sayaç yüzeyinde de hazır bir yuva vardı ve boştu.
///
/// Gerçek olay (2026-08-08 gecesi, sahibin kardeşi): sayaç 22:40'ta başladı,
/// sabah 10:02'de durduruldu, **11 sa 22 dk** çalışma kaydedildi, XP ve
/// başarım verildi. Kullanıcı çalışma kaydını sildi; XP ve başarım GİTMEDİ
/// (`xp_ledger` append-only, `gamification_profiles.xp` biriken sayaç —
/// `supabase/migrations/0024_achievements_ledger.sql`). Yani "Durdur"a basmak
/// **geri alınamaz** bir işlemdi ve hiçbir yerde öyle yazmıyordu.
///
/// Burada yapılan tek şey doğruyu söylemek: koşu eşiği aştıysa süre ve sonuç
/// açıkça yazılır. Uyarı **engellemez** — sayacı durdurmaz, kaydı iptal
/// etmez, düğmeyi kilitlemez. Otomatik durdurma/iptal kararı ürün sahibinin,
/// ve `study_providers.dart` sahipliği bu WP'de bu ajanda değildi.
class TimerVerificationNotice extends StatelessWidget {
  const TimerVerificationNotice({required this.timer, this.now, super.key});

  final StudyTimerState timer;

  /// Yalnız test enjeksiyonu için. Üretimde `null` → duvar saati.
  /// Kural saf fonksiyonda ([implausibleRunElapsed]) yaşar; widget yalnız
  /// çizer.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final elapsed = implausibleRunElapsed(
      isRunning: timer.isRunning,
      startedAt: timer.startedAt,
      now: now ?? DateTime.now(),
    );
    if (elapsed == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // 🔴 Renk paletten DEĞİL zeminden türetilir (WP-358). `colorScheme.error`
    // kullanmak kırmızı ağırlıklı temada uyarıyı görünmez yapıyordu — tam da
    // "kullanıcı hiçbir işaret görmedi" hatasını tekrarlardı.
    final warn = warningColorsOn(theme.colorScheme.surface);
    final duration = formatHumanForLocale(
      elapsed.inSeconds,
      Localizations.localeOf(context).languageCode,
    );

    return Container(
      key: kImplausibleRunNoticeKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warn.container,
        border: Border.all(color: warn.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: warn.onContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              ).classroomSayacCokUzunSuredirAcik(duration),
              style: theme.textTheme.bodySmall?.copyWith(
                color: warn.onContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigForMode extends StatelessWidget {
  const _ConfigForMode({required this.timer, required this.notifier});

  final StudyTimerState timer;
  final StudyTimerNotifier notifier;

  @override
  Widget build(BuildContext context) {
    switch (timer.mode) {
      case TimerMode.stopwatch:
        return const SizedBox.shrink();
      case TimerMode.countdown:
        return SizedBox(
          width: 160,
          child: NumberStepper(
            label: AppLocalizations.of(context).classroomSureDakika,
            value: timer.countdownMinutes,
            min: kMinTimerMinutes,
            max: kMaxTimerMinutes,
            onChanged: notifier.setCountdownMinutes,
          ),
        );
      case TimerMode.pomodoro:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 144,
              child: NumberStepper(
                label: AppLocalizations.of(context).classroomCalismaDk,
                value: timer.workMinutes,
                min: kMinTimerMinutes,
                max: kMaxTimerMinutes,
                onChanged: (v) => notifier.setPomodoro(workMinutes: v),
              ),
            ),
            SizedBox(
              width: 144,
              child: NumberStepper(
                label: AppLocalizations.of(context).classroomMolaDk,
                value: timer.breakMinutes,
                min: kMinTimerMinutes,
                max: kMaxTimerMinutes,
                onChanged: (v) => notifier.setPomodoro(breakMinutes: v),
              ),
            ),
            SizedBox(
              width: 144,
              child: NumberStepper(
                label: AppLocalizations.of(context).classroomDongu,
                value: timer.cycles,
                min: kMinPomodoroCycles,
                max: kMaxPomodoroCycles,
                onChanged: (v) => notifier.setPomodoro(cycles: v),
              ),
            ),
          ],
        );
    }
  }
}

/// Sayaç çalışırken mevcut faz + ilerlemeyi gösteren küçük gösterge (§2H).
/// Kronometrede gizli; geri sayımda "Geri Sayım"; pomodoro'da "Çalışma n/N" veya
/// "Mola". Kamp ateşi (2G) ile tutarlı: mola vurgusu amber.
class TimerPhaseIndicator extends StatelessWidget {
  const TimerPhaseIndicator({super.key, required this.timer});

  final StudyTimerState timer;

  @override
  Widget build(BuildContext context) {
    if (!timer.isRunning || timer.mode == TimerMode.stopwatch) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    final (IconData icon, String label, Color color) = switch (timer.mode) {
      TimerMode.countdown => (
        Icons.hourglass_bottom,
        AppLocalizations.of(context).classroomGeriSayim,
        theme.colorScheme.primary,
      ),
      TimerMode.pomodoro =>
        timer.phase == TimerPhase.work
            ? (
                Icons.menu_book_outlined,
                '${AppLocalizations.of(context).classroomCalisiyor} '
                    '${timer.cycle}/${timer.cycles}',
                theme.colorScheme.primary,
              )
            : (
                Icons.free_breakfast_outlined,
                AppLocalizations.of(context).classroomMola,
                const Color(0xFFE69825), // amber (chart-3) — mola vurgusu
              ),
      TimerMode.stopwatch => (
        Icons.timer_outlined,
        '',
        theme.colorScheme.primary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
