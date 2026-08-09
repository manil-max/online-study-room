import 'package:online_study_room/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import 'clock_style.dart';
import 'timer_mode_controls.dart';

/// WP-598: iki sayaç yüzeyinin (kart + tam ekran odak) ortak, "bir kez göster"
/// açıklamaları.
///
/// Kural ve metin seçimi TEK yerde durur; yüzeyler yalnız bu satırı çağırır.
/// WP-560 dersi: aynı kuralı iki yüzeye kopyalamak, yarısını düzeltip diğerini
/// unutmak demektir. (Fonksiyon bu dosyada duruyor çünkü `study_timer_card`
/// zaten burayı import ediyor; ters yön iki dosya arasında döngü açardı.)
///
/// Kart ile odak ekranı aynı anda takılı olabilir — odak, kartın üstüne
/// itilir. Bu yüzden açıklamayı yalnız **öndeki** rota gösterir; aksi hâlde
/// aynı cümle iki kez kuyruğa girer.
void listenTimerNotices(BuildContext context, WidgetRef ref) {
  /// Sinyali **kareden sonra** gösterir ve orada tüketir.
  ///
  /// Neden kare sonrası: sinyal build sırasında okunuyor olabilir; o an
  /// `showSnackBar` çağırmak "build sırasında setState" hatasıdır.
  ///
  /// Neden geri okuma (`ref.read(notice)`): kart ile odak ekranı aynı anda
  /// takılı olabilir ve kart saniyede bir yeniden çizilir. İlk geri çağırım
  /// sinyali tüketir, sonrakiler `false` görüp döner — aynı cümle iki kez
  /// kuyruğa girmez.
  void present({
    required bool pending,
    required NotifierProvider<TimerOneShotNoticeNotifier, bool> notice,
    required String Function(AppLocalizations l10n) text,
    required VoidCallback consume,
    required Duration duration,
  }) {
    if (!pending) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (!ref.read(notice)) return;
      // Yalnız öndeki rota gösterir; arkadaki kart sinyali tüketmez.
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      consume();
      messenger.showSnackBar(
        SnackBar(
          content: Text(text(AppLocalizations.of(context))),
          duration: duration,
        ),
      );
    });
  }

  // 🔴 WP-598 (H1): reddedilen Başlat dokunuşu SESSİZ kalamaz; sessiz kalırsa
  // kullanıcı "düğme bozuk" der. Ne olduğu ve ne yapması gerektiği söylenir.
  void presentRestartNotice(bool pending) => present(
    pending: pending,
    notice: accidentalRestartNoticeProvider,
    text: (l10n) => l10n.classroomSayacYenidenBaslatilmadi,
    consume: () => ref.read(accidentalRestartNoticeProvider.notifier).clear(),
    duration: const Duration(seconds: 5),
  );

  // WP-598 (H2): "uygulamayı kapatmak sayacı durdurmaz" — ömürde bir kez.
  // Ömürlük bayrak burada, GÖSTERİLDİKTEN sonra yazılır: sayacı widget'tan
  // başlatıp uygulamayı hemen açmayan kullanıcı açıklamayı kaybetmesin.
  void presentBackgroundHint(bool pending) => present(
    pending: pending,
    notice: timerBackgroundHintNoticeProvider,
    text: (l10n) => l10n.classroomSayacArkaPlandaCalisir,
    consume: () =>
        ref.read(studyTimerProvider.notifier).acknowledgeBackgroundHint(),
    duration: const Duration(seconds: 6),
  );

  ref.listen<bool>(
    accidentalRestartNoticeProvider,
    (previous, pending) => presentRestartNotice(pending),
  );
  ref.listen<bool>(
    timerBackgroundHintNoticeProvider,
    (previous, pending) => presentBackgroundHint(pending),
  );

  // Riverpod'un `listen`i yalnız DEĞİŞİMİ taşır; sinyal biz takılmadan önce
  // yakılmış olabilir (örn. sayaç widget'tan başlatıldı, uygulama sonra açıldı).
  // Mount anındaki bekleyen sinyal bu yüzden ayrıca okunur.
  presentRestartNotice(ref.read(accidentalRestartNoticeProvider));
  presentBackgroundHint(ref.read(timerBackgroundHintNoticeProvider));
}

/// 🔴 WP-613: iki sayaç yüzeyinin ORTAK "Durdur" davranışı.
///
/// Kural üç maddedir ve tek yerde durur:
///   1. Kendi koşumuz → doğrudan durdur.
///   2. **Ayna** koşusu (başka cihazda başlamış) → önce onay sor; başka
///      cihazdaki sayacı kapatmak kazara verilecek bir karar değildir.
///   3. `stopMirroredRun()` fırlatabilir (kimlik yoksa `StateError`, sunucu
///      reddi/ağ kopması `coordinator.stopMirroredRun`'dan) → yakala ve
///      kullanıcıya söyle.
///
/// Kural neden buraya taşındı: tam ekran odak ekranı düğmeyi ham tear-off ile
/// bağlıyordu (`onPressed: notifier.stop`). `VoidCallback` bağlamında fırlayan
/// hata hiçbir yere ulaşmıyor; kullanıcı Durdur'a basıyor, sayaç akmaya devam
/// ediyor ve tek kelime edilmiyordu — çıkmaz sokak. Kart aynı kuralı doğru
/// uyguluyordu; aynı kuralın iki yüzeyde ayrık yaşaması WP-560'ın dersiydi
/// ([listenTimerNotices] de bu yüzden burada duruyor).
Future<void> stopTimerFromSurface(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(studyTimerProvider.notifier);
  if (!ref.read(studyTimerProvider).isGlobalTimerMirror) {
    await notifier.stop();
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppLocalizations.of(dialogContext).classroomStopTimerTitle),
      content: Text(
        AppLocalizations.of(dialogContext).classroomStopTimerMirrorBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            MaterialLocalizations.of(dialogContext).cancelButtonLabel,
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(AppLocalizations.of(dialogContext).classroomDurdur),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await notifier.stopMirroredRun();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).classroomStopTimerMirrorFailed,
        ),
      ),
    );
  }
}

/// Tam ekran odak modunu açar (§3.12). Sistem çubukları gizlenir; çıkışta
/// (ekran kapanınca) geri yüklenir.
Future<void> openFocusTimer(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const FocusTimerScreen(),
    ),
  );
}

/// Dikkat dağıtmayan tam ekran sayaç: yalnız büyük canlı süre + ders etiketi +
/// büyük başlat/durdur. "Başka kronometre gerekmesin" hedefi için sade odak modu.
class FocusTimerScreen extends ConsumerStatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  ConsumerState<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends ConsumerState<FocusTimerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Tam ekran: sistem çubuklarını gizle (web'de etkisiz, sorun değil).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    listenTimerNotices(context, ref);
    final timer = ref.watch(studyTimerProvider);
    final notifier = ref.read(studyTimerProvider.notifier);
    final recorded = ref.watch(todayRecordedSecondsProvider);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];

    Subject? selected;
    for (final s in subjects) {
      if (s.id == timer.subjectId) selected = s;
    }

    final now = DateTime.now();
    final elapsed = (timer.isRunning && timer.startedAt != null)
        ? now.difference(timer.startedAt!).inSeconds
        : 0;
    final target = timer.phaseTargetSeconds;
    final inWork = timer.phase == TimerPhase.work;
    // Geri sayım/pomodoro kalanı geri sayar; kronometre yukarı.
    final displaySeconds = target == null
        ? elapsed
        : (timer.isRunning ? (target - elapsed).clamp(0, target) : target);
    // WP-250: kart ile birebir aynı kural (iki ekranın farklı sayı göstermesi
    // bug'dı). Durdurma başlayınca canlı akış kesilir; bekleyen kayıt settling*
    // alanlarıyla taşınır.
    final liveWork = (timer.isRunning && !timer.isStopping && inWork)
        ? elapsed
        : 0;
    final todayTotal = resolveTodayDisplayTotal(
      recordedToday: recorded,
      liveWorkSeconds: liveWork,
      settlingSeconds: timer.settlingSeconds,
      settlingBaseline: timer.settlingBaseline,
      settlingDay: timer.settlingDay,
      // 🔴 WP-613 — WP-561'in bu yüzeye uygulanmamış yarısı. Kırpma tam olarak
      // bu iki argümana bağlıdır (`study_stats.dart`: `live > 0 &&
      // liveStartedAt != null && nowInstant != null`). Argümansız çağrıda
      // 23:00'da başlayan koşuda kart "Bugün 1 sa 30 dk" derken odak ekranı
      // 01:30'da "2 sa 30 dk" diyor, Durdur'da ise sayı çöküyordu — çünkü
      // oturum `dayOf(start)` ile DÜNE yazılır.
      liveStartedAt: timer.startedAt,
      nowInstant: now,
      today: dayOf(now),
    );
    final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
    final goalPct = goalSeconds > 0 ? todayTotal / goalSeconds : 0.0;
    final clockPct = target == null
        ? goalPct
        : (target > 0 ? (elapsed / target).clamp(0.0, 1.0) : 0.0);
    final clockStyle = ref.watch(clockStyleProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (iconContext) => IconButton(
                  tooltip: AppLocalizations.of(context).classroomSaatGorunumu,
                  icon: const Icon(Icons.tune),
                  onPressed: () => showClockStyleMenu(iconContext, ref),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: AppLocalizations.of(context).classroomKucult,
                icon: const Icon(Icons.fullscreen_exit),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;

                final subjectWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 5,
                      backgroundColor: selected != null
                          ? subjectColor(selected.color)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      selected?.name ??
                          AppLocalizations.of(context).classroomGenel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );

                final clockWidget = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: StudyClock(
                      seconds: displaySeconds,
                      pctToGoal: clockPct,
                      running: timer.isRunning,
                      style: clockStyle,
                      fontSize: 72,
                      diameter: 300,
                      // WP-554: yalnız ekran okuyucu etiketi için; çizim aynı.
                      phase: timer.phase,
                    ),
                  ),
                );

                final todayTextWidget = Text(
                  '${AppLocalizations.of(context).classroomBugun} '
                  '${formatHumanSeconds(todayTotal)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );

                final startStopButton = SizedBox(
                  width: 96,
                  height: 96,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: timer.isRunning
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    // WP-613: ham tear-off DEĞİL — ayna koşusunda onay ve
                    // hata şeridi bu yüzeyde de çalışmalı.
                    onPressed: timer.isRunning
                        ? () => stopTimerFromSurface(context, ref)
                        : notifier.start,
                    child: Icon(
                      timer.isRunning ? Icons.stop : Icons.play_arrow,
                      size: 44,
                    ),
                  ),
                );

                if (isLandscape) {
                  return Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: clockWidget),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              subjectWidget,
                              if (timer.isRunning) ...[
                                const SizedBox(height: 12),
                                TimerVerificationNotice(timer: timer),
                              ],
                              if (timer.isRunning &&
                                  timer.mode != TimerMode.stopwatch) ...[
                                const SizedBox(height: 12),
                                TimerPhaseIndicator(timer: timer),
                              ],
                              const SizedBox(height: 24),
                              todayTextWidget,
                              const SizedBox(height: 32),
                              startStopButton,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      subjectWidget,
                      if (timer.isRunning) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: TimerVerificationNotice(timer: timer),
                        ),
                      ],
                      if (timer.isRunning &&
                          timer.mode != TimerMode.stopwatch) ...[
                        const SizedBox(height: 12),
                        TimerPhaseIndicator(timer: timer),
                      ],
                      const SizedBox(height: 24),
                      clockWidget,
                      const SizedBox(height: 8),
                      todayTextWidget,
                      const SizedBox(height: 40),
                      startStopButton,
                    ],
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
