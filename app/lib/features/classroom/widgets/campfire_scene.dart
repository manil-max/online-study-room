import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/animals/camp_animal.dart';
import '../../../core/desktop/desktop_layout.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/time_engine/sky_phase.dart';
import '../../../core/time_engine/solar_anchors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/second_ticker.dart';
import '../../../data/models/daily_stat.dart';
import '../../../data/models/goal_streak.dart';
import '../../../data/models/presence.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/report_target.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/moderation_providers.dart';
import '../../../data/providers/presence_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../profile/social_profile_screen.dart';
import '../../safety/block_user_action.dart';
import '../../safety/peer_safety_actions.dart';
import '../../safety/report_sheet.dart';
import '../../stats/widgets/goal_streak_flame.dart';
import 'camp_critter.dart';
import 'campfire/layered_campfire_fire.dart';
import 'campfire_layout.dart';
import 'nudge_action.dart';

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Kamp ateşi canlı sahnesi (§2G — ormanda taşlı kamp ateşi).
///
/// Yerel saate göre yumuşakça aydınlanan ormanda taş halkalı bir kamp ateşi.
///
/// [anchors], WP-300'ün gerçek güneş saatlerini tek noktadan bağlayacağı seam'dir.
/// [clock] testlerde deterministik sahne üretir; üretimde cihazın yerel saatidir.
class CampfireScene extends ConsumerStatefulWidget {
  const CampfireScene({
    super.key,
    this.anchors,
    this.clock,
    this.tuning = const CampfireTuning(),
  });

  /// `null` ise çıpalar **mevsime göre** hesaplanır (WP-377). Testler ve
  /// golden'lar sabit bir set vererek kareyi deterministik tutabilir.
  final SkyAnchors? anchors;
  final DateTime Function()? clock;

  /// WP-416 önizleme seam'i: sahnenin ayarlanabilir tüm kolları tek nesnede.
  /// Üretim çağrıları varsayılanı kullanır (sahibin onayladığı sayılar);
  /// `lib/campfire_preview.dart` ve golden varyantları kolları tek tek ezer.
  final CampfireTuning tuning;

  @override
  ConsumerState<CampfireScene> createState() => _CampfireSceneState();
}

class _CampfireSceneState extends ConsumerState<CampfireScene> {
  Timer? _skyTimer;

  @override
  void initState() {
    super.initState();
    if (widget.clock == null) {
      _skyTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _skyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock?.call() ?? DateTime.now();
    // WP-377: sabit çıpalar yıl boyu aynıydı ve gerçek güneşten ±2,5 saat
    // sapıyordu; artık gün gün kayıyor.
    final sky = skyPhase(now, widget.anchors ?? solarSkyAnchors(now));
    final membersAsync = ref.watch(groupMembersProvider);
    final presenceList = ref.watch(groupPresenceProvider).value ?? const [];
    final todayByUser = ref.watch(groupTodaySecondsProvider);
    // WP-389/F2: engellenen üye sayıda kalır; kimliği ve etkileşimi gizlenir.
    // WP-495B notu: küme gelmeden `?? const {}` okunuyor. Bu, roster
    // yüzeylerinde **gizlilik açığı değildir**: sunucu `group_member_directory`
    // satırı döndürürken engellenen üyenin adını/avatarını/hayvanını zaten
    // boşaltır (`0095`/`0115`), istemci kümesi ikinci kattır. Sahneyi bu ek ağ
    // çağrısına bağlamak ana ekranın kritik yoluna spinner ekler.
    final blocked = ref.watch(blockedUserIdsProvider).value ?? const <String>{};

    return membersAsync.when(
      loading: () => _SceneFrame(
        sky: sky,
        height: widget.tuning.sceneHeight,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _SceneFrame(
        sky: sky,
        height: widget.tuning.sceneHeight,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppLocalizations.of(context).authBeklenmeyenBirHataOlustu,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (members) {
        final presenceByUser = {
          for (final p in presenceList)
            if (!blocked.contains(p.userId)) p.userId: p,
        };

        final campers = [
          for (final m in members)
            _Camper(
              member: blocked.contains(m.id)
                  ? m.copyWith(
                      displayName: AppLocalizations.of(
                        context,
                      ).safetyBlockedUserFallbackName,
                    )
                  : m,
              presence: presenceByUser[m.id],
              recordedToday: todayByUser[m.id] ?? 0,
              animal: campAnimalFor(
                userId: blocked.contains(m.id) ? 'blocked-camper' : m.id,
                animalId: blocked.contains(m.id) ? null : m.animal,
              ),
              isBlocked: blocked.contains(m.id),
            ),
        ];
        campers.sort(
          (a, b) => a.member.displayName.toLowerCase().compareTo(
            b.member.displayName.toLowerCase(),
          ),
        );

        final studyingCount = campers.where((c) => c.studying).length;

        return _SceneFrame(
          sky: sky,
          height: widget.tuning.sceneHeight,
          child: _SceneLayout(
            campers: campers,
            studyingCount: studyingCount,
            sky: sky,
            now: now,
            tuning: widget.tuning,
            clock: widget.clock,
          ),
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
    required this.isBlocked,
  });

  final Profile member;
  final Presence? presence;
  final int recordedToday;
  final CampAnimal animal;
  final bool isBlocked;

  PresenceStatus get status => presence?.status ?? PresenceStatus.offline;
  bool get studying => status == PresenceStatus.studying;
  DateTime? get startedAt => studying ? presence?.startedAt : null;

  /// Süregelen oturumun toplam uzunluğu ("Şu anki oturum" sayacı).
  int liveExtra(DateTime now) {
    final s = startedAt;
    if (s == null) return 0;
    final diff = now.difference(s).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// WP-561: **bugünkü toplama** eklenecek canlı süre — yalnız bugüne düşen
  /// kısım. Gece yarısını aşan oturumda `recordedToday + liveExtra` dünkü
  /// saatleri bugüne sayıyordu ve oturum bittiğinde sayı sıfıra düşüyordu.
  int liveTodayExtra(DateTime now) =>
      liveSecondsToday(startedAt: startedAt, now: now);

  /// Çalışan her fazda kızartır; molada olan gündüz gerinir, çevrimdışı olan
  /// boşta oturur; gece çalışmayan herkes uyur.
  ///
  /// 🔴 WP-574: burada yalnız `studying` ve gece sorulurdu. Sonuç: **molada
  /// olan üye gündüz çevrimdışı biriyle birebir aynı** çiziliyordu
  /// (`PresenceStatus.onBreak` presence katmanında üretiliyor ama sahneye hiç
  /// ulaşmıyordu). Sahnenin tek işi "şu an kim ne yapıyor"u göstermek; üç
  /// durumun ikisini aynı çizmek sahnenin yalan söylemesiydi.
  ///
  /// Gece dalı üç durumu **bilerek** ayırmaz: karanlıkta çalışmayan herkes uyur
  /// (mevcut davranış korundu, regresyon yok).
  CritterPose poseAt({required bool isNight}) {
    if (studying) return CritterPose.roasting;
    if (isNight) return CritterPose.sleepy;
    return status == PresenceStatus.onBreak
        ? CritterPose.resting
        : CritterPose.idle;
  }

  bool get roasting => studying;
}

/// Sahnenin sivil gökyüzü fazına göre renklenen dış çerçevesi.
class _SceneFrame extends StatelessWidget {
  const _SceneFrame({
    required this.sky,
    required this.child,
    this.height = kCampfireSceneHeight,
  });

  final SkyPhaseResult sky;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daylight = sky.value;
    var top = Color.lerp(
      const Color(0xFF07111F),
      const Color(0xFF70B9E7),
      daylight,
    )!;
    var bottom = Color.lerp(
      const Color(0xFF17231B),
      const Color(0xFFD7E7C1),
      daylight,
    )!;
    top = Color.lerp(top, const Color(0xFF706A9A), sky.warmth * 0.26)!;
    bottom = Color.lerp(bottom, const Color(0xFFFFA45B), sky.warmth * 0.72)!;
    top = Color.lerp(top, scheme.surface, sky.isNight ? 0.06 : 0.015)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        // Sahne, tüm painter'lar (ateş/halka/ağaç/zemin) yükseklik oranlıdır;
        // yükseklik küçülünce kompozisyon orantılı sıkışır ve üst/alttaki boş
        // gökyüzü/zemin bandı birlikte azalır. 480 çok uzundu (cihaz geri
        // bildirimi) → gereksiz boşluk kırpıldı.
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
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
  const _SceneLayout({
    required this.campers,
    required this.studyingCount,
    required this.sky,
    required this.now,
    required this.tuning,
    this.clock,
  });

  final List<_Camper> campers;
  final int studyingCount;
  final SkyPhaseResult sky;

  /// `CampfireScene.clock` olduğu gibi aktarılır. [now] "şu an hangi an"
  /// sorusunu cevaplar; bu alan "bu an dışarıdan sabitlendi mi" sorusunu.
  /// Canlı akan süre metni ikincisine bakar (bkz. [_MemberLabel.clock]).
  final DateTime Function()? clock;

  /// Sahnenin ayarlanabilir kolları; zemin çıpası viewport profiliyle birlikte
  /// burada çözülür ([CampfireTuning.resolvedGroundYFactor]).
  final CampfireTuning tuning;

  /// Sahnenin tek zaman kaynağı. Testlerde `CampfireScene.clock` ile sabitlenir;
  /// alt painter'lar `DateTime.now()` okumaz.
  final DateTime now;

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
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
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
    final n = widget.campers.length;

    // Yerleşim süresi: normalde kısa ve snappy (≤ 700 ms tam yerleşim hedefi),
    // reduce-motion'da anında.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final settle = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 420);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = w / 2;
        final profile = CampfireViewportProfile.fromConstraints(
          constraints: constraints,
          platform: Theme.of(context).platform,
        );
        final tuning = widget.tuning;
        final groundYFactor = tuning.resolvedGroundYFactor(profile);
        final layout = CampfireCountLayout.saved(n.clamp(1, 8));
        // 🔴 v56: ufuk artık ateşin türevi DEĞİL. Yeşil alanı büyütmek ufku
        // yukarı taşır; `ringDropPixels` ise ateşi ve halkayı ufka göre aşağı
        // iter. Sahibin isteği tam bu ayrımdı: "yeşili üste uzat, hayvanları
        // yukarı kaldırma".
        final horizonY = campfireHorizonY(
          sceneHeight: h,
          groundYFactor: groundYFactor,
          fireYOffset: profile.fireYOffset,
          fireYPixelOffset: tuning.fireYPixelOffset,
        );
        final ringFireY = campfireFireY(
          sceneHeight: h,
          groundYFactor: groundYFactor,
          fireYOffset: profile.fireYOffset,
          fireYPixelOffset: tuning.fireYPixelOffset,
          ringDropPixels: tuning.resolvedRingDropPixels(profile),
        );
        // WP-462: ateş varlığı ayrı iner; hayvan halkası bu ince ayardan
        // etkilenmez. Böylece dört kişilik üst sıra yukarı alınırken bütün
        // kompozisyonu aşağı sürüklemeyiz.
        final fireY = ringFireY + tuning.fireOnlyYOffset;
        final ringCy = ringFireY + kCampfireRingCenterOffset;

        final ringScale = tuning.ringWidthScale ?? profile.ringWidthMultiplier;
        final rx = w * layout.ringWidthFactor * ringScale;
        // Halka genişledikçe marşmelov ateşten uzaklaşmasın (WP-377).
        final stickReach = campfireStickReach(
          layout.stickReachFactor,
          ringScale,
        );
        final ry = h * kCampfireRingRyFactor;
        final seats = n == 0 ? const <CampfireSeat>[] : campfireSeats(layout);
        // Sunucu grubu 8 kişiyle sınırlıyor (`0071`), ama 0071 öncesinden kalma
        // kalabalık bir grup hâlâ daha fazla üye taşıyabilir. O durumda koltuk
        // dizisinin sonunu aşıp çökmektense fazlalığı çizmeyiz.
        final drawnCount = math.min(n, seats.length);

        final placements = <_Placement>[];
        for (var i = 0; i < drawnCount; i++) {
          final seat = seats[i];
          final mx = cx + rx * seat.x;
          final my = ringCy + ry * seat.y * tuning.seatVerticalSpread;
          final depth = seat.depth;
          final scale =
              _lerp(0.72, 1.06, depth) *
              profile.critterScaleMultiplier *
              tuning.critterScale;
          final box = _CritterBody.boxFor(scale);
          placements.add(
            _Placement(
              camper: widget.campers[i],
              x: mx.clamp(8 + box / 2, w - 8 - box / 2).toDouble(),
              // Kelepçenin üstü ile altı aynı sözleşmeyi tutmalı: `y` gövdenin
              // ÇIPASI, üst kenarı değil. Üst sınırda `box * anchor` düşülüyordu
              // ama alt sınırda kutunun çıpa altında kalan `box * (1 - anchor)`
              // parçası hiç düşülmemişti; bu yüzden en öndeki hayvanın ayakları
              // sahnenin dışına taşıp `ClipRRect` tarafından kesilebiliyordu.
              // WP-382 ateşi aşağı aldığında (telefon, 4+ kişi) tam bu oldu.
              y: my
                  .clamp(
                    8 + box * _CritterBody.anchor,
                    h - 8 - box * (1 - _CritterBody.anchor),
                  )
                  .toDouble(),
              depth: depth,
              scale: scale,
              back: seat.y < 0,
              phase: i / (n == 0 ? 1 : n),
            ),
          );
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
          // 🔴 WP-511 / E1: burada ikinci bir `GestureDetector` vardı ve
          // `SocialProfileDialog` açıyordu — ama **hiç çalışmıyordu**: çocuğu
          // `_CritterBody` kendi handler'ını `HitTestBehavior.opaque` ile
          // kuruyor ve jest arenasında en içteki kazanıyor. Kodda iki farklı
          // "üyeye tıklayınca ne olsun" tasarımı duruyordu, biri tümüyle ölü.
          // Kanonik olan çalışanıdır: kampçı alt sayfası (`_showCamperDetails`),
          // çünkü dürtme de oraya eklendi.
          child: _CritterBody(
            camper: p.camper,
            depth: p.depth,
            scale: p.scale,
            back: p.back,
            phase: p.phase,
            isNight: widget.sky.isNight,
            controller: _controller,
          ),
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // — Orman arka plan (statik) —
              Positioned.fill(
                child: ExcludeSemantics(
                  // WP-554: dekoratif katman — semantik ağaçta yer almaz.
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: GroundedForestPainter(
                          horizonY: horizonY,
                          daylight: widget.sky.value,
                          sunProgress: widget.sky.sunProgress,
                          warmth: widget.sky.warmth,
                          showTrees: profile.showTrees,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // WP-356: "Toprak açıklık" katmanı kaldırıldı (V49-7). Yeşil
              // zeminin üstüne çizilen koyu kahve radyal elips, sahibin cihazda
              // "ateşin altındaki gri efekt" diye bildirdiği lekenin kaynağıydı.
              // Ateş artık doğrudan çimenin üstünde duruyor; taşların zemine
              // oturması taş halkası + sıcak glow ile sağlanıyor.

              // — Arka üyeler (ateşin ARKASINDA) —
              for (final p in layer(true)) body(p),

              // — Ateş R2: PNG katmanları (WP-62); asset fail → StoneFirePainter —
              Positioned.fill(
                child: ExcludeSemantics(
                  // WP-554: dekoratif katman — semantik ağaçta yer almaz.
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => Transform(
                          alignment: FractionalOffset(cx / w, fireY / h),
                          transform: Matrix4.diagonal3Values(
                            layout.fireScale,
                            layout.fireScale,
                            1,
                          ),
                          child: LayeredCampfireFire(
                            t: _controller.value,
                            studyingCount: widget.studyingCount,
                            embers: _embers,
                            cx: cx,
                            fireY: fireY,
                            reduceMotion: reduceMotion,
                            visualScale: profile.fireVisualScale,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // — Dal + kademeli pişen marşmelov (yalnız çalışanlar) —
              Positioned.fill(
                child: ExcludeSemantics(
                  // WP-554: dekoratif katman — semantik ağaçta yer almaz.
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(
                          painter: MarshmallowPainter(
                            t: _controller.value,
                            // Sahnenin enjekte edilebilir anı; painter duvar
                            // saatini okumaz (WP-365 determinizm düzeltmesi).
                            now: widget.now,
                            fireX: cx,
                            fireY: fireY,
                            reachFactor: stickReach,
                            cycleMinutes: layout.roastCycleMinutes.round(),
                            sticks: [
                              for (final p
                                  in placements
                                      .where(
                                        (placement) =>
                                            placement.camper.roasting,
                                      )
                                      .take(6))
                                MarshStick(
                                  x: p.x,
                                  y: p.y - _CritterBody.boxFor(p.scale) * 0.42,
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
              ),

              // — Ön üyeler (ateşin ÖNÜNDE) —
              for (final p in layer(false)) body(p),

              // — İsim + süre etiketleri (her zaman en üstte, okunur) —
              for (final p in placements)
                AnimatedPositioned(
                  key: ValueKey('l-${p.camper.member.id}'),
                  duration: settle,
                  curve: Curves.easeOutCubic,
                  left: (p.x - 55).clamp(8, w - 118).toDouble(),
                  top:
                      (p.y -
                              _CritterBody.boxFor(p.scale) *
                                  _CritterBody.anchor -
                              // Büyük erişilebilirlik metninde de isim gövdeye
                              // değmesin; önceki 18 px pay uzun isimlerde
                              // sınırdaydı.
                              (p.camper.studying ? 40 : 24))
                          .clamp(8, h - 32)
                          .toDouble(),
                  width: 110,
                  child: _MemberLabel(
                    camper: p.camper,
                    back: p.back,
                    fontSize: tuning.labelFontSize,
                    clock: widget.clock,
                  ),
                ),

              Positioned(
                left: 14,
                top: 12,
                child: _StudyingBadge(count: widget.studyingCount),
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
            count > 0
                ? '$count · ${AppLocalizations.of(context).classroomCalisiyor}'
                : AppLocalizations.of(context).classroomHenuzGrupYok,
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
/// üstte çizilir ki ateşin arkasındaki üyede bile okunur kalsın. Çalışan
/// marşmelov pozunda, diğer üyeler sakin oturuştadır.
class _CritterBody extends ConsumerWidget {
  const _CritterBody({
    required this.camper,
    required this.depth,
    required this.scale,
    required this.back,
    required this.phase,
    required this.isNight,
    required this.controller,
  });

  final _Camper camper;
  final double depth;
  final double scale;
  final bool back;
  final double phase;
  final bool isNight;
  final Animation<double> controller;

  static const double _base = 72;

  /// Ölçeğe göre çizim kutusu kenarı.
  static double boxFor(double scale) => _base * scale;

  /// Kutunun üstünden "oturma noktası"na (kütük) oran — halka noktasına oturtmak
  /// için.
  static const double anchor = 0.82;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studying = camper.studying;
    final offline = camper.status == PresenceStatus.offline;
    final box = boxFor(scale);
    final species = speciesFor(camper.animal.id);
    // 🔴 WP-617 / Riverpod 3 tuzagi: bu deger alt sayfanin icinde `ref.read`
    // ile okunuyordu ve HEP null geliyordu — dinleyicisi olmayan bir
    // `StreamProvider` her `read`de yeniden kurulur, `.value` bos kalir.
    // Sonuc: "kendi kartimda gosterme" kapisi HERKESI eliyordu, yani
    // bildir/engelle hic cizilmiyordu. `watch` burada, yani gercekten
    // dinleyicisi olan `build` icinde durur.
    final viewerId = ref.watch(authStateProvider).value?.id;

    final baseOpacity = studying ? 1.0 : (offline ? 0.36 : 0.58);

    // 🔴 WP-554 (a11y): kamp ateşi uygulamanın iki imza yüzeyinden biri ve
    // ekran okuyucuya tamamen görünmezdi — dokunulabilir hayvan gövdesi hiçbir
    // etiket taşımıyordu (`CustomPaint` semantik üretmez). Etiket burada, yani
    // **dokunulan** düğümde durur; dekoratif katmanlar `ExcludeSemantics` ile
    // elenir ki okuyucu gürültüye boğulmasın. Yerleşim değişmez.
    return SizedBox(
      width: box,
      height: box,
      child: Semantics(
        container: true,
        button: !camper.isBlocked,
        enabled: !camper.isBlocked,
        label: _camperSemanticsLabel(AppLocalizations.of(context), camper),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: camper.isBlocked
              ? null
              : () => _showCamperDetails(context, ref, camper, viewerId),
          child: ExcludeSemantics(
            child: Stack(
              children: [
                Positioned(
                  left: box * 0.16,
                  right: box * 0.16,
                  bottom: box * 0.015,
                  height: box * 0.12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(box),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      final t = controller.value;
                      final pose = camper.poseAt(isNight: isNight);
                      final breath = math.sin(
                        (t * (studying ? 1.6 : 1.0) + phase) * 2 * math.pi,
                      );
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
                              painter: CritterPainter(
                                species: species,
                                pose: pose,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bir üyenin adı + (çalışıyorsa) yeşil canlı süresi. Sahnenin en üst katmanında
/// çizilir; ateşin arkasındaki üyede bile okunur.
class _MemberLabel extends StatelessWidget {
  const _MemberLabel({
    required this.camper,
    required this.back,
    required this.fontSize,
    this.clock,
  });

  final _Camper camper;
  final bool back;

  /// Sahnenin enjekte edilebilir saati (`CampfireScene.clock`).
  ///
  /// 🔴 WP-471 determinizm düzeltmesi: canlı süre metni [SecondTicker] üzerinden
  /// **duvar saatini** okuyordu. Sahne çıpaları ve alev painter'ı WP-365/WP-377
  /// ile enjekte edilebilir ana bağlanmıştı, bu yaprak atlanmıştı. Sonuç: golden
  /// kareleri her gün biraz daha kayıyordu (fixture `startedAt` sabit, `now`
  /// gerçek), kimse kompozisyonu değiştirmese bile golden'lar kırmızıya
  /// dönüyordu. Sahne zaten `clock != null` durumunda gökyüzü tikini de
  /// kapatıyor — yani "saat enjekte edildi" demek "sahne durağan" demektir;
  /// etiket artık aynı sözleşmeye uyuyor. Üretimde (`clock == null`) süre
  /// eskisi gibi saniyede bir canlı akar.
  final DateTime Function()? clock;

  /// Ön sıra boyu. Arka sıra ve canlı süre bundan türetilir; sahip önizlemede
  /// tek sayı sürer, üçü birlikte kayar.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final studying = camper.studying;
    final green = subjectColor('chart-2');
    final name = _camperName(AppLocalizations.of(context), camper);

    // 🔴 WP-554: bu katman dokunulamaz bir **tekrar**dır — ad zaten gövdenin
    // `Semantics` etiketinde, canlı süre ise `formatHms` ("00:12:34") ham
    // biçiminde; ekran okuyucu onu rakam rakam okur. İkisi de gürültü, elenir.
    return ExcludeSemantics(
      child: IgnorePointer(
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
                fontSize: back ? fontSize - 1.5 : fontSize,
                fontWeight: FontWeight.w700,
                shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
              ),
            ),
            if (studying)
              Builder(
                builder: (context) {
                  Widget elapsed(DateTime now) => Text(
                    formatHms(camper.liveExtra(now)),
                    style: TextStyle(
                      color: green,
                      fontSize: back ? fontSize - 2 : fontSize - 1,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 5),
                      ],
                    ),
                  );
                  final injected = clock;
                  if (injected != null) return elapsed(injected());
                  return SecondTicker(builder: (_, now) => elapsed(now));
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Üyenin görünen adı (boşsa katalogdaki "İsimsiz").
String _camperName(AppLocalizations l10n, _Camper camper) =>
    camper.member.displayName.isEmpty
    ? l10n.classroomIsimsiz
    : camper.member.displayName;

/// WP-554: dokunulabilir kamp ateşi üyesinin ekran okuyucu etiketi —
/// "Ada, Çalışıyor". Sahnede **kim** var ve **ne yapıyor** sorusunun cevabı
/// yalnız çizimde duruyordu; ekran okuyucu için hiçbir düğüm yoktu.
String _camperSemanticsLabel(AppLocalizations l10n, _Camper camper) {
  final status = switch (camper.status) {
    PresenceStatus.studying => l10n.classroomCalisiyor,
    PresenceStatus.onBreak => l10n.classroomMolada,
    PresenceStatus.offline => l10n.classroomCevrimdisi,
  };
  return l10n.a11yCampfireMember(_camperName(l10n, camper), status);
}

void _showCamperDetails(
  BuildContext context,
  WidgetRef ref,
  _Camper camper,
  String? viewerId,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Geniş pencerede sayfa kenardan kenara uzamaz: içerik etiket–değer
    // satırlarından oluşuyor ve SPEC §2.3 bu satıra 600 px sert tavan koyuyor
    // (80 karakter, WCAG 2.1 SC 1.4.8). Tavansızken sayfa 720 px'lik bir
    // pencerede %80 boş ölçülüyordu.
    constraints: const BoxConstraints(
      maxWidth: DesktopBreakpoints.maxLabelValueWidth,
    ),
    // 🔴 `ctx` alt sayfanın kendi bağlamıdır ve `pop`tan sonra ölür. Rapor
    // sayfası, engelleme onayı ve profil rotası **dıştaki** `context` üzerinden
    // açılır; SnackBar'ı çizen `Scaffold` de orada durur.
    builder: (ctx) => _CamperSheet(
      camper: camper,
      viewerId: viewerId,
      onOpenProfile: () {
        Navigator.pop(ctx);
        SocialProfileScreen.open(context, camper.member);
      },
      onNudgeBeforeAction: () => Navigator.pop(ctx),
      onReport: () {
        Navigator.pop(ctx);
        showReportSheet(
          context,
          ref,
          target: ReportTarget.profile(
            userId: camper.member.id,
            hint: camper.member.displayName,
          ),
        );
      },
      onBlock: () {
        Navigator.pop(ctx);
        confirmAndBlockUser(context, ref, userId: camper.member.id);
      },
    ),
  );
}

/// Kamp ateşindeki bir hayvana dokununca açılan kişi sayfası (WP-711).
///
/// Sahip (2026-08-11): *"açılan yerden profile gidilebilsin … sağı solu boş
/// mesela offline kısmı sol üste alınabilir, today kısmı da küçük bir stats
/// kısmı olabilir sağda (stats yazmasın yer kaplamasın)."*
///
/// Ölçüldü (`campfire_camper_sheet_wp711_test.dart`, boyanan glif + yaprak
/// çizim kutuları 4 px ızgaraya basılarak): revizyondan önce yüzeyin
/// **%79,5'i boştu** (360 dp) ve **%81,2'si boştu** (720 dp). Sebep tek bir
/// dikey sütundu: her satır kabın tamamını alıyor, içine tek bir kısa metin
/// koyuyordu.
///
/// Yerleşim artık **iki kolonlu**: solda kimlik (durum rozeti sol üstte, altında
/// hayvan + ad), sağda sayı rayı. Ray'ın **başlığı yoktur** — sahip açıkça
/// "stats yazmasın" dedi; sayılar kendi etiketlerini taşır.
///
/// 🔴 Sayıların hiçbiri uydurulmaz. Kaynak matrisi:
///
/// | alan | kendi kartın | başkasının kartı |
/// |---|---|---|
/// | bugünkü toplam | `groupTodaySecondsProvider` + canlı oturum | aynı |
/// | şu anki oturum | `presence.startedAt` | aynı |
/// | günlük seri | `goalStreakProjectionProvider` (sunucu) | **YOK** — projeksiyon self-only |
/// | rekor seri | `dailyTotalsProvider` + kendi hedefin | `group_daily_totals` + o üyenin hedefi |
/// | toplam | aynı harita | aynı harita |
///
/// Başkasında görünür kayıt yoksa toplam/seri döşemeleri **hiç çizilmez**:
/// `0` yazmak "bu kişi hiç çalışmadı" demek olurdu, oysa doğrusu
/// "göremiyoruz" (`can_see_user_sessions` kapısının istemcideki yansıması —
/// `profile_stats_panel.dart` ile aynı kural).
class _CamperSheet extends ConsumerWidget {
  const _CamperSheet({
    required this.camper,
    required this.viewerId,
    required this.onOpenProfile,
    required this.onNudgeBeforeAction,
    required this.onReport,
    required this.onBlock,
  });

  final _Camper camper;
  final String? viewerId;
  final VoidCallback onOpenProfile;
  final VoidCallback onNudgeBeforeAction;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sheetNow = DateTime.now();
    final live = camper.liveExtra(sheetNow);
    final liveToday = camper.liveTodayExtra(sheetNow);
    final isSelf = viewerId != null && camper.member.id == viewerId;

    // Gün → saniye haritası. Kendi kartında kendi oturumların, başkasında
    // RLS'ten geçmiş grup günlük toplamları (`profile_stats_panel.dart` ile
    // AYNI kaynak; iki yüzeyin farklı sayı göstermemesi için).
    final Map<DateTime, int> dayTotals;
    final int goalSeconds;
    if (isSelf) {
      dayTotals = ref.watch(dailyTotalsProvider);
      goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
    } else {
      final stats =
          ref.watch(groupDailyStatsProvider).value ?? const <DailyStat>[];
      dayTotals = userDayTotals(stats, camper.member.id);
      goalSeconds = camper.member.dailyGoalMinutes * 60;
    }
    final hasHistory = dayTotals.isNotEmpty;
    final recordStreak = longestStudyStreak(
      const [],
      totals: dayTotals,
      goalSeconds: goalSeconds,
    );

    final groupId = ref.watch(userGroupProvider).value?.id;
    final showNudge = groupId != null && !isSelf;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        // 🔴 WP-511: alt sayfa varsayılan olarak ekranın 9/16'sını geçemez;
        // kaydırıcı olmadan taşan kısım **hiç görülemez** olurdu.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // — Sahip maddesi: durum bilgisi SOL ÜST —
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _CamperStatusChip(camper: camper),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _CamperIdentity(camper: camper)),
                  const SizedBox(width: 12),
                  // — Sahip maddesi: sağda küçük sayı rayı, BAŞLIKSIZ —
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _CamperStat(
                          slotKey: const Key('camper-stat-today'),
                          label: l10n.classroomBugunkuToplam,
                          value: formatHumanSeconds(
                            camper.recordedToday + liveToday,
                          ),
                        ),
                        if (camper.studying) ...[
                          const SizedBox(height: 10),
                          _CamperStat(
                            slotKey: const Key('camper-stat-session'),
                            label: l10n.classroomSuAnkiOturum,
                            value: formatHms(live),
                          ),
                        ],
                        if (isSelf) ...[
                          const SizedBox(height: 10),
                          _CamperStat(
                            slotKey: const Key('camper-stat-streak'),
                            label: l10n.profileStatsGunlukSeri,
                            trailing: GoalStreakBadge(
                              scope: GoalStreakScope.personal(
                                camper.member.id,
                              ),
                              size: GoalStreakFlameSize.compact,
                            ),
                          ),
                        ] else if (hasHistory) ...[
                          const SizedBox(height: 10),
                          _CamperStat(
                            slotKey: const Key('camper-stat-streak'),
                            label: l10n.statsRekorSeri,
                            value: recordStreak > 0
                                ? l10n.statsStreakGun('$recordStreak')
                                : '—',
                          ),
                        ],
                        if (hasHistory) ...[
                          const SizedBox(height: 10),
                          _CamperStat(
                            slotKey: const Key('camper-stat-total'),
                            label: l10n.statsToplam,
                            value: formatHuman(totalOfDayTotals(dayTotals)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // — Eylemler: yan yana, satırı doldururlar —
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('camper-sheet-profile'),
                      onPressed: onOpenProfile,
                      icon: const Icon(Icons.account_circle_outlined, size: 20),
                      label: Text(
                        l10n.profileTamProfil,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // WP-511: dürtme mantığı **kopyalanmadı**; üye satırıyla aynı
                  // bileşen. `onBeforeAction` boşuna değil: SnackBar'ı çizen
                  // `Scaffold` bu modal sayfanın **altında** kalır.
                  if (showNudge) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: NudgeAction(
                        groupId: groupId,
                        recipient: camper.member,
                        isRecipientStudying: camper.studying,
                        style: NudgeActionStyle.labeled,
                        onBeforeAction: onNudgeBeforeAction,
                      ),
                    ),
                  ],
                ],
              ),
              // 🔴 WP-617: kamp atesinde bildir/engelle yolu HIC yoktu. Google
              // Play kullanici uretimi icerik barindiran uygulamalarda
              // bildirme/engelleme yolu ister — bu bir kolaylik degil, kapi.
              //
              // Kendi satirinda gosterilmez; `showActions` karsiligi.
              if (viewerId != null && camper.member.id != viewerId) ...[
                const Divider(height: 24),
                // Satırın kendi 16 px iç payı, sayfanın 20 px payına EKLENİYOR
                // ve solda 36 px ölü şerit bırakıyordu; sayfa payı zaten var.
                ListTileTheme.merge(
                  contentPadding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: peerSafetyTiles(
                      context,
                      onReport: onReport,
                      onBlock: onBlock,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kişinin o anki durumu — sayfanın **sol üst** köşesindeki rozet.
///
/// Renk tek kanal değildir: nokta rengiyle birlikte durum **yazısı** da durur
/// (renk körü kullanıcı için), metin rengi ise zeminden değil temanın
/// `onSurface`ından gelir — bu depoda "kırmızı rozet kırmızı temada kayboluyor"
/// hatası bir kez yaşandı.
class _CamperStatusChip extends StatelessWidget {
  const _CamperStatusChip({required this.camper});

  final _Camper camper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final (Color dot, String label) = switch (camper.status) {
      PresenceStatus.studying => (
        subjectColor('chart-2'),
        l10n.classroomCalisiyor,
      ),
      PresenceStatus.onBreak => (subjectColor('chart-3'), l10n.classroomMolada),
      PresenceStatus.offline => (
        theme.colorScheme.outline,
        l10n.classroomCevrimdisi,
      ),
    };
    return Container(
      key: const Key('camper-sheet-status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dot.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dot.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sol kolon: hayvan + ad + tür etiketi.
class _CamperIdentity extends StatelessWidget {
  const _CamperIdentity({required this.camper});

  final _Camper camper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          size: const Size(56, 56),
          painter: CritterPainter(
            species: speciesFor(camper.animal.id),
            pose: CritterPose.idle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _camperName(l10n, camper),
                style: theme.textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${camper.animal.label(l10n)} 🏕️',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sağ raydaki tek sayı: üstte etiket, altında değer.
///
/// Değer `maxLines: 1` + kısaltmalıdır: rayın genişliği kabın oranından gelir,
/// yani çok büyük yazı ölçeğinde bile satır **taşamaz** (bu depoda taşmalar iki
/// kez yalnız geniş ekranda test edildiği için kaçtı).
class _CamperStat extends StatelessWidget {
  const _CamperStat({
    required this.slotKey,
    required this.label,
    this.value,
    this.trailing,
  });

  final Key slotKey;
  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailing = this.trailing;
    return KeyedSubtree(
      key: slotKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          if (trailing != null)
            trailing
          else
            Text(
              value ?? '—',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
