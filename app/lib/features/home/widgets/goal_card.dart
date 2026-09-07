import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion_tokens.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/goal_streak.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/goal_streak_flame.dart';
import '../dashboard_card.dart';
import 'card_data_gate.dart';
import 'card_scaffold.dart';

/// Günlük hedef ilerlemesi + güncel seri (§3.11 kart). Hedefe ulaşılan oran bir
/// halka göstergede; seri büyük "🔥 N gün" rozetinde gösterilir.
class GoalCard extends ConsumerStatefulWidget {
  const GoalCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  ConsumerState<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<GoalCard>
    with SingleTickerProviderStateMixin {
  // WP-808: günlük hedef bu uygulamanın TEK kutlama anı. Kart durumsuzken
  // kutlama her rebuild'de yeniden oynardı (pano kartları sık rebuild olur),
  // o yüzden animasyon kartın kendi state'inde durur.
  //
  // 🔴 WP-817 — denetleyici [initState]'te kurulur, alan başlatıcısında DEĞİL.
  // `late final ... = AnimationController(...)` yazımında denetleyici İLK
  // KULLANIMDA doğar; veri kapısı eklendikten sonra kart gövdesini hiç
  // çizmeden (yalnız yer tutucu göstererek) kapatılabiliyor ve ilk kullanım
  // `dispose()` oluyordu. `AnimationController` orada `TickerMode`u aramak için
  // context'e uzanır ve element artık ölü olduğu için
  // *"Looking up a deactivated widget's ancestor is unsafe"* ile patlıyordu.
  // Ömür build'e değil state'e bağlı.
  late final AnimationController _celebration;

  /// ✓ işaretinin kısa ölçek darbesi: büyür, yerine oturur.
  late final Animation<double> _pulse = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.35,
      ).chain(CurveTween(curve: MotionTokens.enter)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.35,
        end: 1,
      ).chain(CurveTween(curve: MotionTokens.enter)),
      weight: 60,
    ),
  ]).animate(_celebration);

  @override
  void initState() {
    super.initState();
    _celebration = AnimationController(
      vsync: this,
      duration: MotionTokens.celebration,
    );
  }

  @override
  void dispose() {
    _celebration.dispose();
    super.dispose();
  }

  /// Hedef **az önce** tutturuldu: bir kez oynat.
  ///
  /// 🔴 Tetik `ref.listen` ile kaydedilen süre DEĞİŞTİĞİNDE gelir, `build`
  /// içinden değil: build sırasında `forward()` çağırmak çizim sırasında
  /// `markNeedsBuild` demektir.
  ///
  /// 🔴 WP-817 — "uygulama hedef zaten tutmuşken açıldığında kutlama oynamaz"
  /// cümlesi buraya WP-808'de yazılmıştı ama **yalandı.** Kaydedilen süre
  /// yükleme karesinde sahte bir 0'dan başlıyor, oturumlar gelince 0 → gerçek
  /// değere sıçrıyordu; dinleyici bunu "eşik az önce geçildi" sayıyordu.
  /// `previous == null` koruması ölüdür: `Provider<int>` non-nullable, yani
  /// değişim anında önceki değer daima vardır. Sonuç: hedefini tutmuş kullanıcı
  /// HER SOĞUK AÇILIŞTA titreşim + halo + ✓ darbesi alıyordu; uygulamadaki tek
  /// kutlama anı böylece anlamını yitiriyordu.
  ///
  /// Cümleyi doğru kılan şey [build] başındaki veri kapısıdır (ayrı bir bayrak
  /// değil): veri gelmeden dinleyici hiç kurulmaz.
  void _celebrate() {
    // Titreşim ayrı bir ayardır; "animasyonları azalt"a bağlanmaz.
    HapticFeedback.mediumImpact();
    if (MotionTokens.reduced(context)) return;
    _celebration.forward(from: 0);
  }

  /// Kutlama parçalarını hareket kapalıyken de doğru çizen sarmalayıcı:
  /// denetleyici hiç ilerlemediği için ölçek 1.0'da kalır.
  Widget _pulsed(Widget child) => ScaleTransition(scale: _pulse, child: child);

  /// Halkanın dışına doğru açılıp sönen vurgu halkası.
  Widget _ringHalo(Color color) => AnimatedBuilder(
    animation: _celebration,
    builder: (context, _) {
      final t = _celebration.value;
      if (t == 0) return const SizedBox.shrink();
      return Transform.scale(
        scale: 1 + 0.18 * t,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: (1 - t) * 0.7),
              width: 3,
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 🔴 WP-817 — KAPI, `ref.listen`DEN **ÖNCE** VE ERKEN DÖNÜŞLE.
    //
    // Kart bugünkü süreyi `todayRecordedSecondsProvider` üzerinden okur; o
    // sağlayıcı oturumları `.value ?? const []` ile okuduğu için yükleme ve
    // hata karelerinde **0** döner — "henüz bilmiyorum" ile "hiç çalışmamış"
    // aynı sayıya düşer. Bunun iki ayrı sonucu vardı:
    //
    //  1. Kart "0sn / 4sa", "%0" ve 0 seri diye KESİN konuşuyordu. Hata
    //     hâlinde bu kalıcıydı: yanındaki "Bugünün özeti" kartı aynı akış için
    //     "Veriler yüklenemedi" çizerken bu kart sonsuza kadar 0 iddia ediyordu.
    //  2. Oturumlar gelince değer 0 → gerçek toplama sıçrıyor, aşağıdaki
    //     dinleyici bunu "hedef az önce tutuldu" sanıyordu (bkz. [_celebrate]).
    //
    // Kapının `ref.listen`den önce gelmesi bir düzen tercihi değil, (2)'nin
    // çaresidir: yükleme karesinde dinleyici hiç KAYDEDİLMEZ, veri gelince
    // build tekrar koşar ve dinleyici temel değerini GERÇEK değerden alır.
    // Sıra bozulursa kutlama geri gelir — ölçülüyor:
    // `test/features/home/goal_celebration_wp817_test.dart`.
    //
    // Tam kart kapısı burada güvenlidir: kart tamamen bilgilendiricidir, tek
    // etkileşimi yoktur. (Sayaç kartı aynı çareyi ALAMAZ; oradaki gerekçe
    // `study_timer_card.dart` içinde yazılı.)
    final sessionsAsync = ref.watch(userSessionsProvider);
    final gate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeGunlukHedef,
      sources: [sessionsAsync],
    );
    if (gate != null) return gate;

    final recorded = ref.watch(todayRecordedSecondsProvider);
    final goalMinutes = ref.watch(dailyGoalMinutesProvider);
    final goalSeconds = goalMinutes * 60;
    // WP-481: kişisel seri kanonik projeksiyondan okunur.
    // `currentStreakProvider` grace'siz eski motordu ve aynı geçmişte
    // projeksiyondan farklı sayı veriyordu.
    final userId = ref.watch(authStateProvider).value?.id;
    final streakScope = userId == null
        ? null
        : GoalStreakScope.personal(userId);
    final pct = goalSeconds <= 0
        ? 0.0
        : (recorded / goalSeconds).clamp(0.0, 1.0);
    final reached = recorded >= goalSeconds && goalSeconds > 0;
    // Yalnız eşiğin ALTINDAN ÜSTÜNE geçişte kutlanır; hedef tutmuşken gelen
    // her yeni kayıt kutlamayı tekrar oynatmaz. Yükleme karesindeki sahte 0'a
    // karşı koruma burada DEĞİL, yukarıdaki kapıdadır (WP-817).
    ref.listen<int>(todayRecordedSecondsProvider, (previous, next) {
      if (goalSeconds <= 0 || previous == null) return;
      if (previous < goalSeconds && next >= goalSeconds) _celebrate();
    });
    // WP-797: yeşil ton zeminden bağımsız sabitti; açık temalarda (soft_cream,
    // pastel_day) halka ve ✓ işareti 2.2–2.4 ile eşiğin altındaydı. Hedefin
    // tamamlandığını söyleyen TEK görsel sinyal buydu.
    final doneGreen = subjectColor('chart-2', on: theme.colorScheme.surface);
    final ringColor = reached ? doneGreen : theme.colorScheme.primary;
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 220;
          final isLarge = constraints.maxWidth >= 400;
          final ringSize = isCompact ? 64.0 : (isLarge ? 116.0 : 84.0);

          final ring = SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              // Vurgu halkası halkanın DIŞINA taşar; kırpılırsa kutlama
              // görünmez olur. Taşma payı kartın 16 px iç boşluğunun altında.
              clipBehavior: Clip.none,
              children: [
                SizedBox.expand(child: _ringHalo(doneGreen)),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: isCompact ? 6 : (isLarge ? 11 : 8),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  ),
                ),
                Text(
                  '%${(pct * 100).round()}',
                  style:
                      (isLarge
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.titleMedium)
                          ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );

          // WP-508: sığan içerikte kaydırıcı kurulmaz (dış sayfa akar), taşarsa
          // kart içinde kayar. Sınırsız yükseklikte (Gruplar listesi) hiç
          // kaydırıcı olmaz — bu kart komşularındaki kontrolü hiç yapmıyordu.
          final unbounded = !constraints.maxHeight.isFinite;
          Widget maybeScroll(Widget child) =>
              unbounded ? child : cardScrollIfOverflows(child: child);

          if (isCompact) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: maybeScroll(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            AppLocalizations.of(context).homeGunlukHedef,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        const Spacer(),
                        if (reached)
                          _pulsed(
                            Icon(
                              Icons.check_circle,
                              color: doneGreen,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(child: ring),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${formatHuman(recorded)} / ${formatHuman(goalSeconds)}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Minik kartta rozet tam sığmıyor; içerik kırpılmak yerine
                    // ölçekleniyor. (WP-496'dan sonra rozette yazı yok; kapsam
                    // bilgisi `Semantics` etiketinde duruyor.)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: GoalStreakBadge(
                        scope: streakScope,
                        size: GoalStreakFlameSize.compact,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: maybeScroll(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context).homeGunlukHedef,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const Spacer(),
                      if (reached)
                        _pulsed(Icon(Icons.check_circle, color: doneGreen)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ring,
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatHuman(recorded)} / ${formatHuman(goalSeconds)}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reached
                                  ? AppLocalizations.of(context).homeBitti
                                  : '${AppLocalizations.of(context).homeGunlukHedef}: '
                                        '${formatHuman((goalSeconds - recorded).clamp(0, 1 << 30))}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GoalStreakBadge(scope: streakScope),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
