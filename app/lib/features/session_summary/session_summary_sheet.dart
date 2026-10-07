/// WP-939 — seans bitince kısa özet.
///
/// Kullanıcı sayacı uygulama içinden durdurduğunda hiçbir şey görünmüyordu.
/// Bu dosya, oturum kaydedildikten hemen sonra küçük bir özet açar: kaydedilen
/// süre + ders, bugünün hedefe oranı ve güncel seri.
///
/// Kural kaynakları (sayılar ana sayfa kartlarıyla AYNI yerden okunur):
///   * bugün toplamı: [todayDisplayTotalFor] (sayaç kartı + hedef kartı),
///   * hedef: [dailyGoalMinutesProvider], yüzde `GoalCard` ile aynı yuvarlama,
///   * seri: `goalStreakProjectionProvider` (kanonik projeksiyon, WP-481).
///
/// XP gösterilmez: XP sunucuda, oturumdan bağımsız ve gecikmeli hesaplanır
/// (`runAchievementSessionCompletedSync` debounce'lu); istemcide "bu oturumun
/// XP'si" diye kesin bir sayı yok, uydurulmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/navigation/nav_index.dart';
import '../../core/stats/study_stats.dart';
import '../../core/theme/motion_tokens.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/goal_streak.dart';
import '../../data/models/subject.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/goal_streak_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';
import '../../l10n/app_localizations.dart';
import 'session_summary_preference.dart';

/// Saf karar: bu uygulama içi durdurma bir oturum KAYDETTİ mi?
///
/// Kaydettiyse kaydedilen saniyeyi, kaydetmediyse `null` döner. Kaynak,
/// sayacın durdurma anında yayınladığı WP-250 `settling*` alanlarıdır: sayaç
/// yalnız gerçekten yazdığı aralık için `settlingSeconds > 0` bırakır.
///
/// Özet AÇILMAZ:
///   * mola fazında durdurma (mola kaydedilmez),
///   * süre 0 (sayacın kuralı: `duration <= 0` düşürülür; bunun dışında
///     asgari süre yok — saniyelik bir oturum da kaydedilir ve özetlenir),
///   * başka cihazdaki ayna koşusu (bu cihazda oturum yazılmaz),
///   * durdurma reddedildi / hâlâ sürüyor (`after.isRunning`).
int? sessionSummarySeconds({
  required StudyTimerState before,
  required StudyTimerState after,
}) {
  final startedAt = before.startedAt;
  if (!before.isRunning || before.isGlobalTimerMirror) return null;
  if (before.phase != TimerPhase.work || startedAt == null) return null;
  if (after.isRunning) return null;
  if (after.settlingSeconds <= 0) return null;
  if (after.settlingDay != dayOf(startedAt)) return null;
  return after.settlingSeconds;
}

enum _SummaryAction { ok, stats }

/// Durdurmadan SONRA çağrılır; özet gerekiyorsa gösterir.
///
/// Hedef kutlamasıyla sıra (WP-817/808): kutlama `GoalCard`'da eşiğin geçildiği
/// anda oynar. Bu oturum hedefi geçirdiyse özet, kutlamanın süresi
/// ([MotionTokens.celebration]) kadar bekleyip SONRA açılır; özet kendisi
/// ikinci bir kutlama (titreşim/animasyon) oynatmaz, yalnız "Hedef tamam"
/// yazar. Böylece iki an üst üste binmez.
Future<void> presentSessionSummary(
  BuildContext context,
  WidgetRef ref, {
  required StudyTimerState before,
}) async {
  if (!ref.read(sessionSummaryEnabledProvider)) return;
  final after = ref.read(studyTimerProvider);
  final seconds = sessionSummarySeconds(before: before, after: after);
  if (seconds == null) return;

  final goalSeconds = ref.read(dailyGoalMinutesProvider) * 60;
  final total = todayDisplayTotalFor(
    recordedToday: ref.read(todayRecordedSecondsProvider),
    timer: after,
    now: DateTime.now(),
  );
  final crossedGoal =
      goalSeconds > 0 && total >= goalSeconds && total - seconds < goalSeconds;
  if (crossedGoal) {
    await Future<void>.delayed(MotionTokens.celebration);
    if (!context.mounted) return;
  }

  final view = SessionSummaryView(
    seconds: seconds,
    subjectId: before.subjectId,
    onOk: (ctx) => Navigator.of(ctx).pop(_SummaryAction.ok),
    onStats: (ctx) => Navigator.of(ctx).pop(_SummaryAction.stats),
  );
  final action = isDesktopWindow
      ? await showDialog<_SummaryAction>(
          context: context,
          builder: (_) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: view,
            ),
          ),
        )
      : await showModalBottomSheet<_SummaryAction>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => view,
        );
  if (action != _SummaryAction.stats || !context.mounted) return;
  // Sekme önce seçilir: aşağıdaki geri alma odak ekranını kapatırsa bu
  // yüzeyin `ref`i artık kullanılamaz.
  ref.read(navIndexProvider.notifier).setTab(AppTab.stats);
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Özetin içeriği (alt sayfa ve masaüstü diyaloğu ortak).
class SessionSummaryView extends ConsumerWidget {
  const SessionSummaryView({
    super.key,
    required this.seconds,
    required this.subjectId,
    required this.onOk,
    required this.onStats,
  });

  /// Bu oturumda kaydedilen süre.
  final int seconds;
  final String? subjectId;
  final void Function(BuildContext context) onOk;
  final void Function(BuildContext context) onStats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    String human(int s) => formatHumanForLocale(s, lang);

    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    String? subjectName;
    for (final s in subjects) {
      if (s.id == subjectId) subjectName = s.name;
    }
    if (subjectId == null && ref.watch(generalSubjectVisibleProvider)) {
      subjectName = l10n.classroomGenel;
    }
    final savedLine = subjectName == null
        ? l10n.sessionSummarySavedNoSubject(human(seconds))
        : l10n.sessionSummarySaved(human(seconds), subjectName);

    // Sayaç kartı ve hedef kartıyla aynı kural (WP-856).
    final total = todayDisplayTotalFor(
      recordedToday: ref.watch(todayRecordedSecondsProvider),
      timer: ref.watch(studyTimerProvider),
      now: DateTime.now(),
    );
    final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
    final reached = goalSeconds > 0 && total >= goalSeconds;
    final pct = goalSeconds <= 0 ? 0.0 : (total / goalSeconds).clamp(0.0, 1.0);
    final goalLine = reached
        ? l10n.sessionSummaryGoalReached(human(total), human(goalSeconds))
        : l10n.sessionSummaryGoalProgress(
            (pct * 100).round(),
            human(total),
            human(goalSeconds),
          );

    final userId = ref.watch(authStateProvider).value?.id;
    final streak = userId == null
        ? null
        : ref
              .watch(
                goalStreakProjectionProvider(GoalStreakScope.personal(userId)),
              )
              .value
              ?.currentStreak;

    return SingleChildScrollView(
      key: const Key('session-summary'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(savedLine, style: theme.textTheme.titleMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (goalSeconds > 0)
            _SummaryLine(
              icon: reached ? Icons.flag : Icons.flag_outlined,
              text: goalLine,
            ),
          if (streak != null && streak > 0) ...[
            const SizedBox(height: 8),
            _SummaryLine(
              icon: Icons.local_fire_department_outlined,
              text: l10n.sessionSummaryStreak(streak),
            ),
          ],
          const SizedBox(height: 20),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              TextButton(
                key: const Key('session-summary-stats'),
                onPressed: () => onStats(context),
                child: Text(l10n.sessionSummaryGoToStats),
              ),
              FilledButton(
                key: const Key('session-summary-ok'),
                onPressed: () => onOk(context),
                child: Text(l10n.sessionSummaryOk),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık ikonuyla (24) aynı sütun: metinler aynı hizadan başlar.
        SizedBox(
          width: 24,
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
