import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animals/camp_animal.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/second_ticker.dart';
import '../../../data/models/presence.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/presence_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../profile/widgets/social_profile_dialog.dart';
import 'camp_critter.dart';

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Kamp ateşi canlı sahnesi (§2G — ormanda taşlı kamp ateşi).
///
/// Gece ormanında taş halkalı bir kamp ateşi; **tüm** grup üyeleri ateş çevresinde
/// eşit açıyla kendi **kütüğünde** oturur ve seçtiği **tombul hayvanla** temsil
/// edilir (elle çizim, tam vücut). **Çalışan** üye gerçekçi bir **dalda marşmelov**
/// kızartır — marşmelov çalışma süresine göre kademe kademe pişer; adı üstünde,
/// süresi altında yeşille yazar. **Mola/çevrimdışı** üye soluklaşır ve uyur (💤).
class CampfireScene extends ConsumerWidget {
  const CampfireScene({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider);
    final presenceList = ref.watch(groupPresenceProvider).value ?? const [];
    final todayByUser = ref.watch(groupTodaySecondsProvider);

    return membersAsync.when(
      loading: () => const _SceneFrame(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _SceneFrame(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Üyeler yüklenemedi: $e', textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (members) {
        final presenceByUser = {for (final p in presenceList) p.userId: p};

        final campers = [
          for (final m in members)
            _Camper(
              member: m,
              presence: presenceByUser[m.id],
              recordedToday: todayByUser[m.id] ?? 0,
              animal: campAnimalFor(userId: m.id, animalId: m.animal),
            ),
        ];
        campers.sort((a, b) => a.member.displayName
            .toLowerCase()
            .compareTo(b.member.displayName.toLowerCase()));

        final studyingCount = campers.where((c) => c.studying).length;

        return _SceneFrame(
          child: _SceneLayout(campers: campers, studyingCount: studyingCount),
        );
      },
    );
  }
}

/// Sahnedeki tek üyenin türetilmiş verisi.
class _Camper {
  _Camper({
    required this.member,
    required this.presence,
    required this.recordedToday,
    required this.animal,
  });

  final Profile member;
  final Presence? presence;
  final int recordedToday;
  final CampAnimal animal;

  PresenceStatus get status => presence?.status ?? PresenceStatus.offline;
  bool get studying => status == PresenceStatus.studying;
  DateTime? get startedAt =>
      studying ? presence?.startedAt : null;

  int liveExtra(DateTime now) {
    final s = startedAt;
    if (s == null) return 0;
    final diff = now.difference(s).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Üyenin o andaki duruşu. Çevrimdışı → uyur, molada → boşta; çalışan üye
  /// çoğunlukla laptopla çalışır ama her döngünün sonunda kısa süre ateşte
  /// marşmelov kızartır (üyeden üyeye kayık, sahne canlansın diye).
  CritterPose poseAt(DateTime now) {
    switch (status) {
      case PresenceStatus.offline:
        return CritterPose.sleepy;
      case PresenceStatus.onBreak:
        return CritterPose.idle;
      case PresenceStatus.studying:
        final inCycle = liveExtra(now) % _kPoseCycleSeconds;
        return inCycle >= _kRoastStartSeconds
            ? CritterPose.roasting
            : CritterPose.working;
    }
  }

  bool roastingAt(DateTime now) => poseAt(now) == CritterPose.roasting;
}

/// Poz döngüsü: çalışan üye her [_kPoseCycleSeconds] sn'de bir, son
/// (döngü − [_kRoastStartSeconds]) sn boyunca marşmelov kızartır; gerisinde laptop.
const int _kPoseCycleSeconds = 170;
const int _kRoastStartSeconds = 135;

/// Sahnenin gece atmosferli dış çerçevesi (koyu gökyüzü gradyanı + yuvarlak köşe).
class _SceneFrame extends StatelessWidget {
  const _SceneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Derin gece mavisi gökyüzü (temaya hafif bağlı, ormana uygun koyu).
    final top = Color.lerp(const Color(0xFF0B1020), scheme.surface, 0.12)!;
    final bottom = Color.lerp(const Color(0xFF161C12), scheme.surface, 0.10)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        // Sahne, tüm painter'lar (ateş/halka/ağaç/zemin) yükseklik oranlıdır;
        // yükseklik küçülünce kompozisyon orantılı sıkışır ve üst/alttaki boş
        // gökyüzü/zemin bandı birlikte azalır. 480 çok uzundu (cihaz geri
        // bildirimi) → gereksiz boşluk kırpıldı.
        height: 360,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}

/// Sahnenin asıl yerleşimi. Tek animasyon denetleyicisi hem alevi, hem hayvanların
/// nefesini, hem marşmelov kızarmasını besler.
class _SceneLayout extends StatefulWidget {
  const _SceneLayout({required this.campers, required this.studyingCount});

  final List<_Camper> campers;
  final int studyingCount;

  @override
  State<_SceneLayout> createState() => _SceneLayoutState();
}

class _SceneLayoutState extends State<_SceneLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Ember> _embers;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    // Döngü reduce-motion'a göre didChangeDependencies'te başlatılır/durdurulur.
    final rnd = math.Random(7);
    _embers = List.generate(
      18,
      (_) => Ember(
        phase: rnd.nextDouble(),
        xOffset: rnd.nextDouble() * 2 - 1,
        sway: 0.4 + rnd.nextDouble() * 0.9,
        size: 1.4 + rnd.nextDouble() * 2.4,
        speed: 0.7 + rnd.nextDouble() * 0.6,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // reduce-motion (sistem "animasyonları azalt"): sonsuz/dekoratif alev, ember
    // ve nefes döngüsünü durdur (batarya) ve sabit sıcak bir karede dondur; aksi
    // halde döngüyü sürdür. Yerleşim (AnimatedPositioned) süresi build'de ayrıca
    // 0'a çekilir, böylece sahne beklemeden yerleşir.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 0.55;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = widget.campers.length;

    // Yerleşim süresi: normalde kısa ve snappy (≤ 700 ms tam yerleşim hedefi),
    // reduce-motion'da anında.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final settle =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 420);

    final intensity = widget.studyingCount == 0
        ? 0.24
        : (0.55 + widget.studyingCount * 0.09).clamp(0.55, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = w / 2;
        final fireY = h * 0.44;
        final ringCy = fireY + 18; // hayvanların oturduğu halka merkezi

        // 45° bakış: yatayda geniş, dikeyde basık elips (foreshortening).
        final rx = math.min(w * 0.40, 232).clamp(140, 260).toDouble();
        final ry = rx * 0.46;

        final placements = <_Placement>[];
        for (var i = 0; i < n; i++) {
          final angle = math.pi / 2 + (n == 0 ? 0 : 2 * math.pi * i / n);
          final sin = math.sin(angle);
          final mx = cx + rx * math.cos(angle);
          final my = ringCy + ry * sin;
          final depth = (sin + 1) / 2; // 0 arka, 1 ön
          placements.add(_Placement(
            camper: widget.campers[i],
            x: mx,
            y: my,
            depth: depth,
            scale: _lerp(0.6, 1.16, depth),
            back: sin < -0.2, // üst yay → ateşin arkasında
            phase: i / (n == 0 ? 1 : n),
          ));
        }

        List<_Placement> layer(bool back) =>
            [...placements.where((p) => p.back == back)]
              ..sort((a, b) => a.y.compareTo(b.y));

        Widget body(_Placement p) => AnimatedPositioned(
              key: ValueKey('b-${p.camper.member.id}'),
              duration: settle,
              curve: Curves.easeOutCubic,
              left: p.x - _CritterBody.boxFor(p.scale) / 2,
              top: p.y - _CritterBody.boxFor(p.scale) * _CritterBody.anchor,
              child: GestureDetector(
                onTap: () => SocialProfileDialog.show(context, p.camper.member),
                child: _CritterBody(
                  camper: p.camper,
                  depth: p.depth,
                  scale: p.scale,
                  back: p.back,
                  phase: p.phase,
                  controller: _controller,
                ),
              ),
            );

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // — Orman arka plan (statik) —
              const Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: ForestBackdropPainter()),
                  ),
                ),
              ),

              // — Toprak açıklık —
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: ClearingPainter(
                          cx: cx, cy: ringCy + ry * 0.35, rx: rx, ry: ry),
                    ),
                  ),
                ),
              ),

              // — Arka üyeler (ateşin ARKASINDA) —
              for (final p in layer(true)) body(p),

              // — Ateş + taş halka (animasyonlu) —
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: StoneFirePainter(
                          t: _controller.value,
                          intensity: intensity,
                          embers: _embers,
                          cx: cx,
                          fireY: fireY,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // — Dal + kademeli pişen marşmelov (yalnız çalışanlar) —
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: MarshmallowPainter(
                          t: _controller.value,
                          fireX: cx,
                          fireY: fireY,
                          sticks: [
                            for (final p in placements)
                              if (p.camper.roastingAt(DateTime.now()))
                                MarshStick(
                                  x: p.x,
                                  y: p.y -
                                      _CritterBody.boxFor(p.scale) * 0.42,
                                  phase: p.phase,
                                  startedAt: p.camper.startedAt,
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // — Ön üyeler (ateşin ÖNÜNDE) —
              for (final p in layer(false)) body(p),

              // — İsim + süre etiketleri (her zaman en üstte, okunur) —
              for (final p in placements)
                AnimatedPositioned(
                  key: ValueKey('l-${p.camper.member.id}'),
                  duration: settle,
                  curve: Curves.easeOutCubic,
                  left: p.x - 55,
                  top: p.y -
                      _CritterBody.boxFor(p.scale) * _CritterBody.anchor -
                      (p.camper.studying ? 34 : 18),
                  width: 110,
                  child: _MemberLabel(camper: p.camper, back: p.back),
                ),

              Positioned(
                left: 14,
                top: 12,
                child: _StudyingBadge(count: widget.studyingCount),
              ),

              if (widget.studyingCount == 0)
                Positioned(
                  left: 0,
                  right: 0,
                  top: fireY - 8,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Ateş sönük — çalışmaya başla, herkes ısınsın',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Placement {
  const _Placement({
    required this.camper,
    required this.x,
    required this.y,
    required this.depth,
    required this.scale,
    required this.back,
    required this.phase,
  });

  final _Camper camper;
  final double x;
  final double y;
  final double depth;
  final double scale;
  final bool back;
  final double phase;
}

/// Kaç kişinin çalıştığını gösteren küçük rozet.
class _StudyingBadge extends StatelessWidget {
  const _StudyingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final amber = subjectColor('chart-3');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: 13, color: amber)),
          const SizedBox(width: 6),
          Text(
            count > 0 ? '$count çalışıyor' : 'kimse yok',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kütüğünde oturan tombul hayvan (gövde). İsim/süre ayrı katmanda ([_MemberLabel])
/// üstte çizilir ki ateşin arkasındaki üyede bile okunur kalsın. Nefes alma
/// animasyonu; çalışan kolunu kaldırır (marşmelov overlay'de), dinlenen uyur.
class _CritterBody extends StatelessWidget {
  const _CritterBody({
    required this.camper,
    required this.depth,
    required this.scale,
    required this.back,
    required this.phase,
    required this.controller,
  });

  final _Camper camper;
  final double depth;
  final double scale;
  final bool back;
  final double phase;
  final Animation<double> controller;

  static const double _base = 72;

  /// Ölçeğe göre çizim kutusu kenarı.
  static double boxFor(double scale) => _base * scale;

  /// Kutunun üstünden "oturma noktası"na (kütük) oran — halka noktasına oturtmak
  /// için.
  static const double anchor = 0.82;

  @override
  Widget build(BuildContext context) {
    final studying = camper.studying;
    final offline = camper.status == PresenceStatus.offline;
    final box = boxFor(scale);
    final species = speciesFor(camper.animal.id);

    final baseOpacity = studying
        ? (back ? 0.86 : 1.0)
        : (offline ? (back ? 0.34 : 0.42) : (back ? 0.46 : 0.6));

    return SizedBox(
      width: box,
      height: box,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showCamperDetails(context, camper),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            // Duruş zamana göre hesaplanır (laptop ↔ marşmelov dönüşümü);
            // painter yalnız duruş değişince yeniden çizer.
            final pose = camper.poseAt(DateTime.now());
            final breath =
                math.sin((t * (studying ? 1.6 : 1.0) + phase) * 2 * math.pi);
            final sy = 1 + breath * (studying ? 0.035 : 0.02);
            final dy = -breath.abs() * (studying ? 2.0 : 0.8);
            return Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scaleY: sy,
                scaleX: 2 - sy,
                child: Opacity(
                  opacity: baseOpacity,
                  child: CustomPaint(
                    size: Size(box, box),
                    painter: CritterPainter(species: species, pose: pose),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bir üyenin adı + (çalışıyorsa) yeşil canlı süresi. Sahnenin en üst katmanında
/// çizilir; ateşin arkasındaki üyede bile okunur.
class _MemberLabel extends StatelessWidget {
  const _MemberLabel({required this.camper, required this.back});

  final _Camper camper;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final studying = camper.studying;
    final green = subjectColor('chart-2');
    final name = camper.member.displayName.isEmpty
        ? 'İsimsiz'
        : camper.member.displayName;

    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: studying ? 0.96 : 0.62),
              fontSize: back ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
            ),
          ),
          if (studying)
            SecondTicker(
              builder: (_, now) => Text(
                formatHms(camper.liveExtra(now)),
                style: TextStyle(
                  color: green,
                  fontSize: back ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showCamperDetails(BuildContext context, _Camper camper) {
    final status = camper.status;
    final (Color dot, String label) = switch (status) {
      PresenceStatus.studying => (subjectColor('chart-2'), 'Çalışıyor'),
      PresenceStatus.onBreak => (subjectColor('chart-3'), 'Molada'),
      PresenceStatus.offline => (
          Theme.of(context).colorScheme.outline,
          'Çevrimdışı'
        ),
    };
    final live = camper.liveExtra(DateTime.now());
    final name = camper.member.displayName.isEmpty
        ? 'İsimsiz'
        : camper.member.displayName;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(72, 72),
                  painter: CritterPainter(
                    species: speciesFor(camper.animal.id),
                    pose: CritterPose.idle,
                  ),
                ),
                const SizedBox(height: 8),
                Text(name, style: theme.textTheme.titleLarge),
                Text('${camper.animal.label} 🏕️',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(label, style: theme.textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 16),
                _StatRow(
                  label: 'Bugünkü toplam',
                  value: formatHumanSeconds(camper.recordedToday + live),
                ),
                if (status == PresenceStatus.studying)
                  _StatRow(label: 'Şu anki oturum', value: formatHms(live)),
              ],
            ),
          ),
        );
      },
    );
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
