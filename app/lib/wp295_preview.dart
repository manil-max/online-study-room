import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'features/classroom/widgets/camp_critter.dart';
import 'features/classroom/widgets/campfire_layout.dart';

void main() => runApp(buildWp295PreviewApp());

/// Test ve geliştirici önizlemesi için yerel seçimi açık uygulama kabuğu.
Widget buildWp295PreviewApp({Locale? locale}) =>
    _Wp295PreviewApp(locale: locale);

class _Wp295PreviewApp extends StatelessWidget {
  const _Wp295PreviewApp({this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _PreviewScreen(),
    );
  }
}

class _PreviewScreen extends StatefulWidget {
  const _PreviewScreen();

  @override
  State<_PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<_PreviewScreen>
    with SingleTickerProviderStateMixin {
  var _memberCount = 6;
  var _workingCount = 4;
  late Map<int, CampfireCountLayout> _layouts;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _layouts = {
      for (var count = 1; count <= 8; count++)
        count: CampfireCountLayout.saved(count),
    };
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedLayout = _layouts[_memberCount]!;
    final controls = _Controls(
      layout: selectedLayout,
      memberCount: _memberCount,
      workingCount: _workingCount,
      onMemberCount: (value) => setState(() {
        _memberCount = value;
        _workingCount = math.min(_workingCount, value);
      }),
      onWorkingCount: (value) => setState(() => _workingCount = value),
      onLayout: (value) => setState(() {
        _layouts = {..._layouts, value.memberCount: value};
      }),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wp295PreviewTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final preview = Padding(
            padding: const EdgeInsets.all(16),
            child: _PreviewScene(
              layout: selectedLayout,
              workingCount: _workingCount,
              animation: _controller,
            ),
          );
          if (constraints.maxWidth < 850) {
            final previewHeight = math.min(430.0, constraints.maxHeight * 0.55);
            return Column(
              children: [
                SizedBox(height: previewHeight, child: preview),
                Expanded(child: controls),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: preview),
              SizedBox(width: 340, child: controls),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewScene extends StatelessWidget {
  const _PreviewScene({
    required this.layout,
    required this.workingCount,
    required this.animation,
  });

  final CampfireCountLayout layout;
  final int workingCount;
  final Animation<double> animation;

  static const _species = [
    'fox',
    'rabbit',
    'bear',
    'cat',
    'panda',
    'owl',
    'penguin',
    'turtle',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seats = campfireSeats(layout);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = w / 2;
        final fireY = h * layout.groundYFactor;
        final rx = w * layout.ringWidthFactor;
        final ry = h * 0.15;
        final ringCy = fireY + 18;

        final placements = [
          for (final seat in seats)
            (
              seat: seat,
              x: cx + rx * seat.x,
              y: ringCy + ry * seat.y,
              scale: 0.72 + seat.depth * 0.34,
            ),
        ]..sort((a, b) => a.y.compareTo(b.y));

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B1020), Color(0xFF182014)],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GroundedForestPainter(
                        horizonY: ringCy - ry * 0.82,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: ClearingPainter(
                        cx: cx,
                        cy: ringCy + ry * 0.35,
                        rx: w * 0.30,
                        ry: ry,
                      ),
                    ),
                  ),
                ),
                for (final placement in placements.where(
                  (item) => item.seat.y < 0,
                ))
                  _critter(placement),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) => CustomPaint(
                      painter: _ScaledFirePainter(
                        t: animation.value,
                        cx: cx,
                        fireY: fireY,
                        scale: layout.fireScale,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) => CustomPaint(
                      painter: _PreviewStickPainter(
                        t: animation.value,
                        fire: Offset(cx, fireY - 12),
                        reachFactor: layout.stickReachFactor,
                        starts: [
                          for (final placement in placements)
                            if (placement.seat.index < workingCount)
                              Offset(
                                placement.x,
                                placement.y - 24 * placement.scale,
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                for (final placement in placements.where(
                  (item) => item.seat.y >= 0,
                ))
                  _critter(placement),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Chip(
                    label: Text(
                      l10n.wp295PreviewStatus(
                        layout.memberCount,
                        workingCount,
                        layout.roastCycleMinutes.round(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _critter(
    ({CampfireSeat seat, double x, double y, double scale}) placement,
  ) {
    final size = 66 * placement.scale;
    final working = placement.seat.index < workingCount;
    return Positioned(
      left: placement.x - size / 2,
      top: placement.y - size * 0.72,
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: size * 0.16,
            right: size * 0.16,
            bottom: size * 0.015,
            height: size * 0.12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                color: Colors.black.withValues(alpha: working ? 0.30 : 0.20),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: working ? 1 : 0.58,
              child: CustomPaint(
                painter: CritterPainter(
                  species: speciesFor(
                    _species[placement.seat.index % _species.length],
                  ),
                  pose: working ? CritterPose.roasting : CritterPose.idle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroundedForestPainter extends CustomPainter {
  const _GroundedForestPainter({required this.horizonY});

  final double horizonY;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(295);
    final skyPaint = Paint()..color = const Color(0xFFBFD4C8);

    for (var i = 0; i < 34; i++) {
      final radius = 0.35 + random.nextDouble() * 0.85;
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * horizonY * 0.78,
        ),
        radius,
        skyPaint
          ..color = skyPaint.color.withValues(
            alpha: 0.18 + random.nextDouble() * 0.38,
          ),
      );
    }

    final distantRidge = Path()
      ..moveTo(0, horizonY + 18)
      ..quadraticBezierTo(
        size.width * 0.22,
        horizonY - 26,
        size.width * 0.43,
        horizonY + 4,
      )
      ..quadraticBezierTo(
        size.width * 0.68,
        horizonY - 34,
        size.width,
        horizonY + 14,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(distantRidge, Paint()..color = const Color(0xFF132419));

    final ground = Path()
      ..moveTo(0, horizonY)
      ..quadraticBezierTo(size.width * 0.5, horizonY - 12, size.width, horizonY)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      ground,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF16251A), Color(0xFF101910), Color(0xFF0A100A)],
            ).createShader(
              Rect.fromLTRB(0, horizonY - 12, size.width, size.height),
            ),
    );

    for (var i = 0; i < 18; i++) {
      final x = i * size.width / 17;
      final normalizedX = x / size.width;
      if (normalizedX > 0.20 && normalizedX < 0.80) continue;
      final treeHeight = 32 + random.nextDouble() * 34;
      _pine(
        canvas,
        Offset(x, horizonY + 7 + random.nextDouble() * 8),
        treeHeight,
        const Color(0xFF183322),
      );
    }

    const sidePositions = [0.01, 0.07, 0.14, 0.86, 0.93, 0.99];
    for (var i = 0; i < sidePositions.length; i++) {
      final edgeDistance = i % 3;
      final treeHeight = 72.0 - edgeDistance * 10;
      _pine(
        canvas,
        Offset(size.width * sidePositions[i], horizonY + 50 + edgeDistance * 9),
        treeHeight,
        const Color(0xFF0B1A10),
      );
    }
  }

  void _pine(Canvas canvas, Offset base, double height, Color color) {
    canvas.drawRect(
      Rect.fromLTWH(
        base.dx - height * 0.035,
        base.dy - height * 0.25,
        height * 0.07,
        height * 0.28,
      ),
      Paint()..color = const Color(0xFF11130C),
    );
    final foliage = Paint()..color = color;
    for (var layer = 0; layer < 3; layer++) {
      final layerTop = base.dy - height * (0.48 + layer * 0.19);
      final layerBottom = base.dy - height * (0.10 + layer * 0.16);
      final halfWidth = height * (0.28 - layer * 0.045);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, layerTop)
          ..lineTo(base.dx - halfWidth, layerBottom)
          ..lineTo(base.dx + halfWidth, layerBottom)
          ..close(),
        foliage,
      );
    }
  }

  @override
  bool shouldRepaint(_GroundedForestPainter oldDelegate) =>
      oldDelegate.horizonY != horizonY;
}

class _ScaledFirePainter extends CustomPainter {
  const _ScaledFirePainter({
    required this.t,
    required this.cx,
    required this.fireY,
    required this.scale,
  });

  final double t;
  final double cx;
  final double fireY;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(cx, fireY);
    canvas.scale(scale);
    canvas.translate(-cx, -fireY);
    StoneFirePainter(
      t: t,
      intensity: 1,
      embers: const [],
      cx: cx,
      fireY: fireY,
    ).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScaledFirePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.cx != cx ||
      oldDelegate.fireY != fireY ||
      oldDelegate.scale != scale;
}

class _PreviewStickPainter extends CustomPainter {
  const _PreviewStickPainter({
    required this.t,
    required this.fire,
    required this.reachFactor,
    required this.starts,
  });

  final double t;
  final Offset fire;
  final double reachFactor;
  final List<Offset> starts;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final phase = (t + i / math.max(1, starts.length)) % 1;
      final restingTarget = Offset.lerp(start, fire, reachFactor)!;
      final target = Offset(
        restingTarget.dx + math.sin(phase * math.pi * 2) * 6,
        restingTarget.dy + math.cos(phase * math.pi * 2) * 2,
      );
      canvas.drawLine(
        start,
        target,
        Paint()
          ..color = const Color(0xFF7A5634)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawOval(
        Rect.fromCenter(center: target, width: 9, height: 13),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFF7EC),
            const Color(0xFFB4783E),
            phase,
          )!,
      );
    }
  }

  @override
  bool shouldRepaint(_PreviewStickPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.fire != fire ||
      oldDelegate.reachFactor != reachFactor ||
      oldDelegate.starts.length != starts.length;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.layout,
    required this.memberCount,
    required this.workingCount,
    required this.onLayout,
    required this.onMemberCount,
    required this.onWorkingCount,
  });

  final CampfireCountLayout layout;
  final int memberCount;
  final int workingCount;
  final ValueChanged<CampfireCountLayout> onLayout;
  final ValueChanged<int> onMemberCount;
  final ValueChanged<int> onWorkingCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 24, 24),
      children: [
        Text(l10n.wp295PreviewMemberCount),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var count = 1; count <= 8; count++)
                ChoiceChip(
                  key: ValueKey('member-count-$count'),
                  label: Text('$count'),
                  selected: memberCount == count,
                  onSelected: (_) => onMemberCount(count),
                ),
            ],
          ),
        ),
        _slider(
          l10n.wp295PreviewWorkingMember,
          workingCount.toDouble(),
          0,
          memberCount.toDouble(),
          (value) => onWorkingCount(value.round()),
          divisions: memberCount,
        ),
        _stepper(
          l10n,
          l10n.wp295PreviewRingWidth,
          layout.ringWidthFactor,
          0.20,
          0.38,
          (value) => onLayout(layout.copyWith(ringWidthFactor: value)),
          keyPrefix: 'ring',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(l10n.wp295PreviewRingHelp),
        ),
        for (var pairIndex = 0; pairIndex < layout.pairs.length; pairIndex++)
          _pairCard(context, pairIndex),
        for (
          var singleIndex = 0;
          singleIndex < layout.singles.length;
          singleIndex++
        )
          _singleCard(context, singleIndex),
        const Divider(height: 32),
        _slider(
          l10n.wp295PreviewGroundY,
          layout.groundYFactor,
          0.46,
          0.66,
          (value) => onLayout(layout.copyWith(groundYFactor: value)),
        ),
        _slider(
          l10n.wp295PreviewFireScale,
          layout.fireScale,
          0.80,
          1.25,
          (value) => onLayout(layout.copyWith(fireScale: value)),
        ),
        _slider(
          l10n.wp295PreviewMarshmallowReach,
          layout.stickReachFactor,
          0.40,
          0.78,
          (value) => onLayout(layout.copyWith(stickReachFactor: value)),
        ),
        _slider(
          l10n.wp295PreviewRoastCycle,
          layout.roastCycleMinutes,
          8,
          12,
          (value) => onLayout(layout.copyWith(roastCycleMinutes: value)),
          suffix: l10n.wp295PreviewMinutesSuffix,
          divisions: 4,
        ),
        const Divider(height: 32),
        SelectableText(
          'count=${layout.memberCount} · '
          'ring=${layout.ringWidthFactor.toStringAsFixed(2)} · '
          'pairs=${layout.pairs.map((pair) => '(${pair.horizontalFactor.toStringAsFixed(2)},'
              '${pair.verticalFactor.toStringAsFixed(2)})').join('|')} · '
          'singles=${layout.singles.map((single) => '(${single.horizontalFactor.toStringAsFixed(2)},'
              '${single.verticalFactor.toStringAsFixed(2)})').join('|')} · '
          'groundY=${layout.groundYFactor.toStringAsFixed(2)} · '
          'fireScale=${layout.fireScale.toStringAsFixed(2)} · '
          'stickReach=${layout.stickReachFactor.toStringAsFixed(2)} · '
          'roast=${layout.roastCycleMinutes.toStringAsFixed(0)}dk',
        ),
      ],
    );
  }

  Widget _pairCard(BuildContext context, int pairIndex) {
    final l10n = AppLocalizations.of(context);
    final pair = layout.pairs[pairIndex];
    final lastIndex = layout.pairs.length - 1;
    final label = layout.pairs.length == 1
        ? l10n.wp295PreviewSinglePair
        : pairIndex == 0
        ? l10n.wp295PreviewBackPair
        : pairIndex == lastIndex
        ? l10n.wp295PreviewFrontPair(pairIndex + 1)
        : l10n.wp295PreviewPair(pairIndex + 1);
    final minVertical = pairIndex == 0
        ? -1.0
        : layout.pairs[pairIndex - 1].verticalFactor + 0.08;
    final maxVertical = pairIndex == lastIndex
        ? 1.0
        : layout.pairs[pairIndex + 1].verticalFactor - 0.08;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            _stepper(
              l10n,
              l10n.wp295PreviewHorizontalSpread,
              pair.horizontalFactor,
              0.25,
              1.15,
              (value) => _updatePair(
                pairIndex,
                pair.copyWith(horizontalFactor: value),
              ),
              keyPrefix: 'pair-$pairIndex-horizontal',
            ),
            _stepper(
              l10n,
              l10n.wp295PreviewVerticalPosition,
              pair.verticalFactor,
              minVertical,
              maxVertical,
              (value) =>
                  _updatePair(pairIndex, pair.copyWith(verticalFactor: value)),
              keyPrefix: 'pair-$pairIndex-vertical',
            ),
          ],
        ),
      ),
    );
  }

  Widget _singleCard(BuildContext context, int singleIndex) {
    final l10n = AppLocalizations.of(context);
    final single = layout.singles[singleIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.wp295PreviewAnimal(singleIndex + 1),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _stepper(
              l10n,
              l10n.wp295PreviewHorizontalPosition,
              single.horizontalFactor,
              -1.15,
              1.15,
              (value) => _updateSingle(
                singleIndex,
                single.copyWith(horizontalFactor: value),
              ),
              keyPrefix: 'single-$singleIndex-horizontal',
            ),
            _stepper(
              l10n,
              l10n.wp295PreviewVerticalDepth,
              single.verticalFactor,
              -1,
              1,
              (value) => _updateSingle(
                singleIndex,
                single.copyWith(verticalFactor: value),
              ),
              keyPrefix: 'single-$singleIndex-vertical',
            ),
          ],
        ),
      ),
    );
  }

  void _updatePair(int pairIndex, CampfirePairPlacement value) {
    final pairs = [...layout.pairs];
    pairs[pairIndex] = value;
    onLayout(layout.copyWith(pairs: pairs));
  }

  void _updateSingle(int singleIndex, CampfireSinglePlacement value) {
    final singles = [...layout.singles];
    singles[singleIndex] = value;
    onLayout(layout.copyWith(singles: singles));
  }

  Widget _stepper(
    AppLocalizations l10n,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    required String keyPrefix,
  }) {
    final normalizedValue = value.clamp(min, max);

    void change(double delta) {
      final next = (normalizedValue + delta).clamp(min, max);
      onChanged(double.parse(next.toStringAsFixed(2)));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Row(
            children: [
              IconButton(
                key: ValueKey('$keyPrefix-decrease-large'),
                tooltip: l10n.wp295PreviewDecrease(label, '0.05'),
                onPressed: normalizedValue <= min ? null : () => change(-0.05),
                icon: const Text('−.05'),
              ),
              IconButton(
                key: ValueKey('$keyPrefix-decrease'),
                tooltip: l10n.wp295PreviewDecrease(label, '0.01'),
                onPressed: normalizedValue <= min ? null : () => change(-0.01),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  normalizedValue.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                key: ValueKey('$keyPrefix-increase'),
                tooltip: l10n.wp295PreviewIncrease(label, '0.01'),
                onPressed: normalizedValue >= max ? null : () => change(0.01),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                key: ValueKey('$keyPrefix-increase-large'),
                tooltip: l10n.wp295PreviewIncrease(label, '0.05'),
                onPressed: normalizedValue >= max ? null : () => change(0.05),
                icon: const Text('+.05'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String suffix = '',
    int? divisions,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(2)}$suffix'),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
