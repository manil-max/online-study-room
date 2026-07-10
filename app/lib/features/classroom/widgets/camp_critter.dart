import 'dart:math' as math;

import 'package:flutter/material.dart';

Color _darken(Color c, double amount) =>
    Color.lerp(c, Colors.black, amount)!;
Color _lighten(Color c, double amount) =>
    Color.lerp(c, Colors.white, amount)!;

// ————————————————————————— Orman arka plan —————————————————————————

/// Gece ormanı: ay + yıldızlar + katmanlı çam silüetleri (kenarlarda daha yoğun)
/// + zemin. Statik ve ucuz (deterministik konumlar).
class ForestBackdropPainter extends CustomPainter {
  const ForestBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rnd = math.Random(42);

    // — Ay + halesi —
    final moon = Offset(w * 0.84, h * 0.2);
    canvas.drawCircle(
      moon,
      42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFDF6D8).withValues(alpha: 0.28),
            const Color(0xFFFDF6D8).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: 42)),
    );
    canvas.drawCircle(moon, 16, Paint()..color = const Color(0xFFF3ECCB));
    canvas.drawCircle(Offset(moon.dx - 5, moon.dy - 4), 3.5,
        Paint()..color = const Color(0xFFE4DCB4));
    canvas.drawCircle(Offset(moon.dx + 4, moon.dy + 5), 2.4,
        Paint()..color = const Color(0xFFE4DCB4));

    // — Yıldızlar (üst yarı) —
    for (var i = 0; i < 54; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h * 0.5;
      canvas.drawCircle(
        Offset(x, y),
        rnd.nextDouble() * 0.9 + 0.3,
        Paint()
          ..color = Colors.white.withValues(alpha: rnd.nextDouble() * 0.5 + 0.15),
      );
    }

    // — Uzak ağaç sırası (soluk, alçak) —
    _treeRow(canvas, w, h,
        baseY: h * 0.66,
        color: const Color(0xFF14251C).withValues(alpha: 0.85),
        count: 22,
        minH: 26,
        maxH: 46,
        rnd: rnd);

    // — Yakın ağaç sırası (koyu, uzun; kenarlarda daha yoğun) —
    _nearTrees(canvas, w, h, rnd);

    // — Zemin tümseği —
    final ground = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.74, w, h * 0.82)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(ground, Paint()..color = const Color(0xFF10160E));
  }

  void _treeRow(Canvas canvas, double w, double h,
      {required double baseY,
      required Color color,
      required int count,
      required double minH,
      required double maxH,
      required math.Random rnd}) {
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      final x = (i / (count - 1)) * w + (rnd.nextDouble() * 12 - 6);
      final th = minH + rnd.nextDouble() * (maxH - minH);
      _pine(canvas, Offset(x, baseY), th, th * 0.5, paint);
    }
  }

  void _nearTrees(Canvas canvas, double w, double h, math.Random rnd) {
    final paint = Paint()..color = const Color(0xFF0C1710);
    final baseY = h * 0.86;
    // Kenarlarda yoğun, ortada seyrek: ağırlıklı x örnekleme.
    final xs = <double>[];
    for (var i = 0; i < 16; i++) {
      final u = rnd.nextDouble();
      // Kenarlara it (u'yu uçlara yaklaştır).
      final edge = u < 0.5 ? (u * u) * 0.5 : 1 - ((1 - u) * (1 - u)) * 0.5;
      xs.add(edge * w);
    }
    xs.sort();
    for (final x in xs) {
      final th = 54 + rnd.nextDouble() * 46;
      _pine(canvas, Offset(x, baseY), th, th * 0.52, paint);
    }
  }

  /// Üst üste 3 üçgenli köknar silüeti + kısa gövde.
  void _pine(Canvas canvas, Offset base, double height, double width,
      Paint paint) {
    final trunk = Paint()..color = const Color(0xFF0A120C);
    canvas.drawRect(
      Rect.fromLTWH(base.dx - 1.5, base.dy - 3, 3, 5),
      trunk,
    );
    for (var layer = 0; layer < 3; layer++) {
      final ly = base.dy - 2 - layer * (height * 0.28);
      final lw = width * (1 - layer * 0.22);
      final lh = height * 0.5;
      final path = Path()
        ..moveTo(base.dx, ly - lh)
        ..lineTo(base.dx - lw / 2, ly)
        ..lineTo(base.dx + lw / 2, ly)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ForestBackdropPainter oldDelegate) => false;
}

/// Ateş etrafındaki toprak açıklık (hayvanların oturduğu zemin). Elips; ortası
/// ateş ışığıyla sıcak, kenarları koyu — 45° bakış hissini pekiştirir.
class ClearingPainter extends CustomPainter {
  const ClearingPainter({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
  });

  final double cx;
  final double cy;
  final double rx;
  final double ry;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: rx * 2.5, height: ry * 2.5);
    // Toprak zemin (sıcak merkez → koyu kenar).
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFF3A2E22),
            Color(0xFF241C15),
            Color(0x00120D0A),
          ],
          stops: const [0, 0.6, 1],
        ).createShader(rect),
    );
    // Çok hafif aşınma halkası (patika izi — göze batmasın).
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy), width: rx * 1.7, height: ry * 1.7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..color = const Color(0xFF4A3B2A).withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(ClearingPainter old) =>
      old.cx != cx || old.cy != cy || old.rx != rx || old.ry != ry;
}

// ————————————————————————— Taşlı kamp ateşi —————————————————————————

class Ember {
  const Ember({
    required this.phase,
    required this.xOffset,
    required this.sway,
    required this.size,
    required this.speed,
  });

  final double phase;
  final double xOffset;
  final double sway;
  final double size;
  final double speed;
}

/// Taş halkalı canlı kamp ateşi: taşlar + odun + kor yatağı + gradyanlı alev
/// katmanları + yükselen kıvılcımlar + sıcak parıltı. [intensity] çalışan sayısı.
class StoneFirePainter extends CustomPainter {
  StoneFirePainter({
    required this.t,
    required this.intensity,
    required this.embers,
    required this.cx,
    required this.fireY,
  });

  final double t;
  final double intensity;
  final List<Ember> embers;
  final double cx;
  final double fireY;

  static const _outer = Color(0xFFE0431C);
  static const _mid = Color(0xFFF3862B);
  static const _inner = Color(0xFFFFD24A);
  static const _core = Color(0xFFFFF6C8);

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = fireY + 30;
    final flick = math.sin(t * 2 * math.pi);
    final flick2 = math.sin(t * 2 * math.pi * 1.7 + 1.1);
    final flick3 = math.sin(t * 2 * math.pi * 2.3 + 0.5);

    // — Sıcak parıltı —
    final glowR = (92 + intensity * 62) + flick * 6;
    canvas.drawCircle(
      Offset(cx, baseY - 26),
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _inner.withValues(alpha: 0.30 * intensity),
            _mid.withValues(alpha: 0.18 * intensity),
            _outer.withValues(alpha: 0.08 * intensity),
            _outer.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 0.65, 1],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, baseY - 26), radius: glowR)),
    );

    // — Taş halka (arka taşlar) —
    _stones(canvas, cx, baseY, back: true);
    // — Odun —
    _logs(canvas, cx, baseY);
    // — Kor yatağı —
    _coals(canvas, cx, baseY, flick3);
    // — Alevler —
    final scale = 0.66 + intensity * 0.5;
    _flame(canvas, cx + flick * 3, baseY, 78 * scale, 104 * scale, flick,
        [_outer.withValues(alpha: 0), _outer, const Color(0xFFC7361A)]);
    _flame(canvas, cx - flick2 * 3, baseY - 2, 56 * scale, 84 * scale, flick2,
        [_mid.withValues(alpha: 0.1), _mid, _outer]);
    _flame(canvas, cx + flick2 * 2, baseY - 4, 36 * scale, 60 * scale, flick,
        [_inner.withValues(alpha: 0.2), _inner, _mid]);
    _flame(canvas, cx, baseY - 6, 18 * scale, 38 * scale, flick2,
        [_core.withValues(alpha: 0.4), _core, _inner]);
    // — Ön taşlar (alevin önünde) —
    _stones(canvas, cx, baseY, back: false);
    // — Kıvılcımlar —
    _embers(canvas, cx, baseY);
  }

  void _stones(Canvas canvas, double cx, double baseY, {required bool back}) {
    // Taşlar elips halka üzerinde; arka olanlar üstte (küçük y), ön olanlar altta.
    const count = 11;
    for (var i = 0; i < count; i++) {
      final a = math.pi * 2 * i / count;
      final sy = math.sin(a);
      final isBack = sy < 0;
      if (isBack != back) continue;
      final x = cx + math.cos(a) * 46;
      final y = baseY + 8 + sy * 15;
      final rw = 11.0 - sy.abs() * 2;
      final rh = 8.0 - sy.abs() * 1.5;
      final base = HSVColor.fromColor(const Color(0xFF6E6A66));
      final shade =
          base.withValue((0.42 + ((i * 37) % 100) / 100 * 0.18)).toColor();
      // Gövde
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: rw * 2, height: rh * 2),
        Paint()..color = shade,
      );
      // Üst highlight (ateşten sıcak yansıma)
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y - rh * 0.4), width: rw * 1.2, height: rh * 0.8),
        Paint()
          ..color = _lighten(shade, 0.18)
              .withValues(alpha: back ? 0.5 : 0.7 * intensity + 0.3),
      );
    }
  }

  void _logs(Canvas canvas, double cx, double baseY) {
    void log(double angle, Color c) {
      canvas.save();
      canvas.translate(cx, baseY + 6);
      canvas.rotate(angle);
      final rect = const Rect.fromLTWH(-34, -5.5, 68, 11);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5.5)),
          Paint()..color = c);
      // Uç halka (kesik odun).
      canvas.drawCircle(const Offset(-34, 0), 5.5,
          Paint()..color = _lighten(c, 0.12));
      canvas.drawCircle(const Offset(-34, 0), 2.4,
          Paint()..color = _darken(c, 0.2));
      canvas.restore();
    }

    log(0.26, const Color(0xFF3E281A));
    log(-0.26, const Color(0xFF5A3B27));
  }

  void _coals(Canvas canvas, double cx, double baseY, double pulse) {
    final glow = 0.6 + 0.4 * (pulse * 0.5 + 0.5);
    for (var i = -2; i <= 2; i++) {
      final r = 4.6 - i.abs() * 0.5;
      canvas.drawCircle(
        Offset(cx + i * 9.0, baseY + 2),
        r,
        Paint()
          ..color = Color.lerp(_outer, _inner, glow)!
              .withValues(alpha: (0.65 * intensity + 0.2).clamp(0.0, 1.0)),
      );
    }
  }

  void _flame(Canvas canvas, double cx, double baseY, double w, double hh,
      double flick, List<Color> colors) {
    final fh = hh * (0.92 + flick * 0.12);
    final sway = flick * w * 0.18;
    final tipX = cx + sway;
    final path = Path()
      ..moveTo(cx, baseY)
      ..quadraticBezierTo(
          cx - w / 2, baseY - fh * 0.42, cx - w * 0.16, baseY - fh * 0.72)
      ..quadraticBezierTo(tipX - w * 0.08, baseY - fh, tipX, baseY - fh)
      ..quadraticBezierTo(
          tipX + w * 0.08, baseY - fh, cx + w * 0.16, baseY - fh * 0.72)
      ..quadraticBezierTo(cx + w / 2, baseY - fh * 0.42, cx, baseY)
      ..close();
    final rect = Rect.fromLTRB(cx - w / 2, baseY - fh, cx + w / 2, baseY);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  void _embers(Canvas canvas, double cx, double baseY) {
    final riseTop = fireY - 128;
    final riseSpan = baseY - riseTop;
    for (final e in embers) {
      final prog = (t * e.speed + e.phase) % 1.0;
      final y = baseY - prog * riseSpan;
      final swayX = math.sin(prog * math.pi * 3 + e.phase * 6) * 14 * e.sway;
      final x = cx + e.xOffset * 22 + swayX;
      final alpha = ((1 - prog) * intensity).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(x, y), e.size * (1 - prog * 0.5),
          Paint()..color = _inner.withValues(alpha: alpha * 0.9));
    }
  }

  @override
  bool shouldRepaint(StoneFirePainter old) =>
      old.t != t || old.intensity != intensity;
}

// ————————————————————— Dal + kademeli marşmelov —————————————————————

class MarshStick {
  const MarshStick({
    required this.x,
    required this.y,
    required this.phase,
    required this.startedAt,
  });

  final double x;
  final double y;
  final double phase;
  final DateTime? startedAt;
}

/// Çalışan üyenin elinden ateşe uzanan gerçekçi bir dal + ucunda marşmelov.
/// Marşmelov, oturum süresine göre kademe kademe pişer (çiğ → altın → kızarmış →
/// koyu → yer yer kömürleşmiş) ve nazikçe salınır; piştikçe buhar/kor belirir.
class MarshmallowPainter extends CustomPainter {
  MarshmallowPainter({
    required this.t,
    required this.fireX,
    required this.fireY,
    required this.sticks,
  });

  final double t;
  final double fireX;
  final double fireY;
  final List<MarshStick> sticks;

  /// Oturum saniyesi → pişme oranı (0..1). ~40 dk'da tam kızarır.
  static double doneness(int seconds) => (seconds / (40 * 60)).clamp(0.0, 1.0);

  static Color _cookColor(double d) {
    const raw = Color(0xFFFFF7EC);
    const golden = Color(0xFFF1D48C);
    const toasted = Color(0xFFB4783E);
    const deep = Color(0xFF5B3316);
    if (d < 0.34) return Color.lerp(raw, golden, d / 0.34)!;
    if (d < 0.67) return Color.lerp(golden, toasted, (d - 0.34) / 0.33)!;
    return Color.lerp(toasted, deep, (d - 0.67) / 0.33)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final fireTip = Offset(fireX, fireY - 16);

    for (final s in sticks) {
      final from = Offset(s.x, s.y);
      final dir = fireTip - from;
      final dist = dir.distance;
      if (dist < 4) continue;
      final unit = dir / dist;
      final perp = Offset(-unit.dy, unit.dx);
      final wobble = math.sin((t + s.phase) * 2 * math.pi) * 3;

      // Marşmelov ucu ateşe ~%64 mesafede; hafif salınır.
      final tip = from + unit * (dist * 0.64) + perp * wobble;
      final handStart = from + unit * 6;

      // — Gerçekçi dal: hafif kırıklı, ucu inceleyen + küçük sürgünler —
      _branch(canvas, handStart, tip, perp);

      // — Marşmelov —
      final elapsed = s.startedAt == null
          ? 0
          : now.difference(s.startedAt!).inSeconds;
      final d = doneness(elapsed);
      _marshmallow(canvas, tip, unit, perp, d);
    }
  }

  void _branch(Canvas canvas, Offset a, Offset b, Offset perp) {
    final mid = Offset.lerp(a, b, 0.55)! + perp * 4; // hafif kavis
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF6B4A2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8A6440)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    // Küçük yan sürgün.
    final nub = Offset.lerp(a, b, 0.4)!;
    canvas.drawLine(
      nub,
      nub + perp * 5 + (b - a) / (b - a).distance * 3,
      Paint()
        ..color = const Color(0xFF6B4A2C)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _marshmallow(
      Canvas canvas, Offset c, Offset unit, Offset perp, double d) {
    final color = _cookColor(d);
    // Silindirik marşmelov: dala dik, yumuşak köşeli.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.atan2(unit.dy, unit.dx));

    const w = 13.0;
    const hgt = 10.0;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: hgt);
    // Gölge
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0.5, 1.2)),
          const Radius.circular(4.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    // Gövde (hacim için dikey gradyan)
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4.5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lighten(color, 0.18), color, _darken(color, 0.22)],
        ).createShader(rect),
    );
    // Üst highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-w / 2 + 1.5, -hgt / 2 + 1.2, w - 3, 3),
          const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.35 * (1 - d)),
    );
    // Kömürleşme lekeleri (ileri pişmede)
    if (d > 0.7) {
      final spot = Paint()
        ..color = const Color(0xFF241206).withValues(alpha: (d - 0.7) / 0.3);
      canvas.drawCircle(const Offset(-3, 1.5), 1.6, spot);
      canvas.drawCircle(const Offset(3.5, -1), 1.2, spot);
    }
    canvas.restore();

    // Buhar (orta pişmede) — ateşten yukarı süzülen soluk çizgi.
    if (d > 0.15 && d < 0.92) {
      final steamA = ((0.5 - (d - 0.5).abs()) * 0.5).clamp(0.0, 0.28);
      final sway = math.sin(t * 2 * math.pi * 1.3 + c.dx) * 3;
      final p = Path()
        ..moveTo(c.dx, c.dy - 7)
        ..quadraticBezierTo(c.dx + sway, c.dy - 14, c.dx - sway * 0.6, c.dy - 22);
      canvas.drawPath(
        p,
        Paint()
          ..color = Colors.white.withValues(alpha: steamA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(MarshmallowPainter old) =>
      old.t != t || old.sticks.length != sticks.length;
}

// ————————————————————————— Tombul hayvan —————————————————————————

enum EarType { pointy, long, round, tiny, none }

/// Bir hayvan türünün çizim parametreleri (ortak tombul gövde + türe özel öğeler).
class CritterSpecies {
  const CritterSpecies({
    required this.body,
    required this.belly,
    required this.ear,
    required this.earInner,
    required this.nose,
    this.beak = false,
    this.tail = false,
    this.tailTip,
    this.eyePatch = false,
    this.patch = const Color(0xFF1E1E1E),
    this.feet,
  });

  final Color body;
  final Color belly;
  final EarType ear;
  final Color earInner;
  final Color nose;
  final bool beak;
  final bool tail;
  final Color? tailTip;
  final bool eyePatch;
  final Color patch;
  final Color? feet;
}

CritterSpecies speciesFor(String id) {
  switch (id) {
    case 'fox':
      return const CritterSpecies(
        body: Color(0xFFE1863C),
        belly: Color(0xFFF3E4CE),
        ear: EarType.pointy,
        earInner: Color(0xFF3A2A22),
        nose: Color(0xFF33241C),
        tail: true,
        tailTip: Color(0xFFF3E4CE),
      );
    case 'rabbit':
      return const CritterSpecies(
        body: Color(0xFFD9D6DE),
        belly: Color(0xFFF6F4F8),
        ear: EarType.long,
        earInner: Color(0xFFE9B9C4),
        nose: Color(0xFFC97B8A),
        tail: true,
        tailTip: Color(0xFFFFFFFF),
      );
    case 'bear':
      return const CritterSpecies(
        body: Color(0xFF8A5A34),
        belly: Color(0xFFC79A6E),
        ear: EarType.round,
        earInner: Color(0xFF5E3E24),
        nose: Color(0xFF2A1D14),
      );
    case 'cat':
      return const CritterSpecies(
        body: Color(0xFF9AA0A6),
        belly: Color(0xFFE8EAED),
        ear: EarType.pointy,
        earInner: Color(0xFFE9B9C4),
        nose: Color(0xFFE48A9A),
        tail: true,
        tailTip: Color(0xFF7C8288),
      );
    case 'dog':
      return const CritterSpecies(
        body: Color(0xFFC6975E),
        belly: Color(0xFFEBD9BE),
        ear: EarType.round,
        earInner: Color(0xFF8A6640),
        nose: Color(0xFF2A1D14),
        tail: true,
        tailTip: Color(0xFFC6975E),
      );
    case 'panda':
      return const CritterSpecies(
        body: Color(0xFFF0EFEF),
        belly: Color(0xFFF8F8F8),
        ear: EarType.round,
        earInner: Color(0xFF1E1E1E),
        nose: Color(0xFF1E1E1E),
        eyePatch: true,
      );
    case 'owl':
      return const CritterSpecies(
        body: Color(0xFF7C5A38),
        belly: Color(0xFFD9C09A),
        ear: EarType.tiny,
        earInner: Color(0xFF5E432A),
        nose: Color(0xFFE8A23A),
        beak: true,
      );
    case 'frog':
      return const CritterSpecies(
        body: Color(0xFF6BBE45),
        belly: Color(0xFFCDE9AE),
        ear: EarType.none,
        earInner: Color(0xFF57A036),
        nose: Color(0xFF2A3A1E),
      );
    case 'penguin':
      return const CritterSpecies(
        body: Color(0xFF2C2E36),
        belly: Color(0xFFF2F2F2),
        ear: EarType.none,
        earInner: Color(0xFF2C2E36),
        nose: Color(0xFFE8A23A),
        beak: true,
        feet: Color(0xFFE8A23A),
      );
    case 'koala':
      return const CritterSpecies(
        body: Color(0xFFA9ABB1),
        belly: Color(0xFFCACCD1),
        ear: EarType.round,
        earInner: Color(0xFFCACCD1),
        nose: Color(0xFF2A2A2A),
      );
    case 'tiger':
      return const CritterSpecies(
        body: Color(0xFFEDA23C),
        belly: Color(0xFFF3E4CE),
        ear: EarType.round,
        earInner: Color(0xFFF3E4CE),
        nose: Color(0xFFE48A9A),
      );
    case 'hedgehog':
      return const CritterSpecies(
        body: Color(0xFFC6975E),
        belly: Color(0xFFEBD9BE),
        ear: EarType.tiny,
        earInner: Color(0xFF8A6640),
        nose: Color(0xFF2A1D14),
      );
    default:
      return const CritterSpecies(
        body: Color(0xFFC6975E),
        belly: Color(0xFFEBD9BE),
        ear: EarType.round,
        earInner: Color(0xFF8A6640),
        nose: Color(0xFF2A1D14),
      );
  }
}

/// Bir hayvanın sahnedeki duruşu (§2G, referans katalog pozları).
/// - [working]: kütüğünde **laptopla** çalışır (çalışan üye — asıl poz).
/// - [roasting]: ateşe **dala geçmiş marşmelov** uzatır (kol kalkık; marşmelov
///   overlay'de çizilir). Çalışan üye ara sıra bu poza geçer.
/// - [idle]: uyanık ama boşta oturur (molada).
/// - [sleepy]: uyur — gözler kapalı, baş yana eğik (çevrimdışı).
enum CritterPose { working, roasting, idle, sleepy }

/// Kütüğünde oturan tombul hayvan (Party Animals ruhu, elle çizim). Duruş
/// [pose] ile belirlenir; ateş yönünden gelen sıcak kenar-ışığı hacim katar.
class CritterPainter extends CustomPainter {
  CritterPainter({
    required this.species,
    required this.pose,
  });

  final CritterSpecies species;
  final CritterPose pose;

  bool get _asleep => pose == CritterPose.sleepy;
  bool get _roasting => pose == CritterPose.roasting;
  bool get _working => pose == CritterPose.working;

  @override
  void paint(Canvas canvas, Size size) {
    // Ölçek 66px referansına göre; oran korunur.
    canvas.save();
    canvas.scale(size.width / 66);
    _draw(canvas);
    canvas.restore();
  }

  void _draw(Canvas canvas) {
    const bodyTop = 20.0;
    const bodyCx = 33.0;
    final bodyCy = 40.0;
    final bodyW = 40.0;
    final bodyH = 42.0;
    final logY = 58.0;

    // — Zemin gölgesi —
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCx, logY + 4), width: 44, height: 9),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    // — Kütük (hayvanın oturduğu) —
    _log(canvas, bodyCx, logY);

    // — Kuyruk (gövdenin arkasında) —
    if (species.tail) _tail(canvas, bodyCx, bodyCy);

    // — Gövde —
    final bodyRect = Rect.fromCenter(
        center: Offset(bodyCx, bodyCy), width: bodyW, height: bodyH);
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        bodyRect,
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
      ));
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [_lighten(species.body, 0.16), species.body, _darken(species.body, 0.26)],
          stops: const [0, 0.55, 1],
        ).createShader(bodyRect),
    );

    // — Ayaklar —
    final feetColor = species.feet ?? _darken(species.body, 0.05);
    for (final dx in [-11.0, 11.0]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(bodyCx + dx, bodyCy + bodyH / 2 - 3),
            width: 12,
            height: 9),
        Paint()..color = feetColor,
      );
    }

    // — Göbek —
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCx, bodyCy + 6), width: 24, height: 26),
      Paint()..color = species.belly,
    );

    // — Ateşten sıcak kenar-ışığı (gövdeye hacim; alt-öne düşer) —
    _rimLight(canvas, bodyPath, bodyRect);

    // — Laptop (yalnız çalışırken; kollar üstünde durur) —
    if (_working) _laptop(canvas, bodyCx, bodyCy + 9);

    // — Kollar —
    _arms(canvas, bodyCx, bodyCy, bodyW);

    // — Kulaklar (yüzden önce, başın arkasında) —
    _ears(canvas, bodyCx, bodyTop);

    // — Yüz —
    _face(canvas, bodyCx, bodyCy - 4);
  }

  /// Ateş yönünden (alt-ön) gelen sıcak parıltı — gövdeye yumuşak hacim katar.
  /// Gövde yoluna kırpılır ki arka plana taşmasın.
  void _rimLight(Canvas canvas, Path bodyPath, Rect bodyRect) {
    canvas.save();
    canvas.clipPath(bodyPath);
    final glow = Rect.fromCenter(
      center: Offset(bodyRect.center.dx, bodyRect.bottom - 4),
      width: bodyRect.width * 1.2,
      height: bodyRect.height * 1.05,
    );
    canvas.drawOval(
      glow,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB25A).withValues(alpha: 0.26),
            const Color(0xFFFF8A3A).withValues(alpha: 0.10),
            const Color(0x00FF8A3A),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(glow),
    );
    canvas.restore();
  }

  /// Açık laptop: klavye tabanı + ekran; ekranda soluk mavi parıltı ("çalışıyor").
  void _laptop(Canvas canvas, double cx, double cy) {
    canvas.save();
    canvas.translate(cx, cy);

    // Ekranın öne vuran parıltısı (yumuşak).
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -3), width: 30, height: 22),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9AD6FF).withValues(alpha: 0.28),
            const Color(0x009AD6FF),
          ],
        ).createShader(
            Rect.fromCenter(center: const Offset(0, -3), width: 30, height: 22)),
    );

    // Taban (klavye) — hafif perspektif yamuk.
    final base = Path()
      ..moveTo(-10, 4)
      ..lineTo(10, 4)
      ..lineTo(13, 9)
      ..lineTo(-13, 9)
      ..close();
    canvas.drawPath(base, Paint()..color = const Color(0xFF3B4048));
    canvas.drawPath(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFF20242A),
    );

    // Ekran gövdesi + cam.
    final shell = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -9.5, 22, 14.5), const Radius.circular(2.4));
    canvas.drawRRect(shell, Paint()..color = const Color(0xFF23272E));
    final glassRect = const Rect.fromLTWH(-9, -8, 18, 11.5);
    final glass =
        RRect.fromRectAndRadius(glassRect, const Radius.circular(1.6));
    canvas.drawRRect(
      glass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA9DCFF), Color(0xFF5C9FE0)],
        ).createShader(glassRect),
    );
    // Ekran satır izleri.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-6, -5), const Offset(4, -5), line);
    canvas.drawLine(const Offset(-6, -2), const Offset(2, -2), line);
    canvas.drawLine(const Offset(-6, 1), const Offset(5, 1), line);
    canvas.restore();
  }

  void _log(Canvas canvas, double cx, double y) {
    final rect = Rect.fromCenter(center: Offset(cx, y), width: 50, height: 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF7A5230), Color(0xFF5A3B22)],
        ).createShader(rect),
    );
    // Uç halkaları (kesik odun).
    for (final ex in [cx - 25.0, cx + 25.0]) {
      canvas.drawCircle(Offset(ex, y), 7, Paint()..color = const Color(0xFF8A6440));
      canvas.drawCircle(Offset(ex, y), 4, Paint()..color = const Color(0xFF6B4A2C));
      canvas.drawCircle(Offset(ex, y), 1.6, Paint()..color = const Color(0xFF553A22));
    }
  }

  void _tail(Canvas canvas, double cx, double cy) {
    final base = Offset(cx + 16, cy + 6);
    canvas.drawOval(
      Rect.fromCenter(center: base, width: 18, height: 22),
      Paint()..color = species.body,
    );
    if (species.tailTip != null) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(base.dx + 3, base.dy - 6), width: 11, height: 12),
        Paint()..color = species.tailTip!,
      );
    }
  }

  void _arms(Canvas canvas, double cx, double cy, double bodyW) {
    final armColor = _darken(species.body, 0.06);
    final pawColor = _lighten(armColor, 0.05);

    // Çalışırken iki kol öne, patiler laptobun üstünde (klavyede).
    if (_working) {
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(cx + side * (bodyW / 2 - 5), cy + 2);
        canvas.rotate(side * 0.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -2, 8, 16), const Radius.circular(4)),
          Paint()..color = armColor,
        );
        canvas.restore();
      }
      // Patiler laptop tabanının üstünde.
      for (final dx in [-6.0, 6.0]) {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + dx, cy + 13), width: 7, height: 5),
          Paint()..color = pawColor,
        );
      }
      return;
    }

    // Sol kol (aşağı; gövdeye yaslı).
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - bodyW / 2 + 3, cy + 4), width: 9, height: 15),
      Paint()..color = armColor,
    );
    if (_roasting) {
      // Sağ kol kalkık (marşmelov çubuğunu tutar — overlay).
      canvas.save();
      canvas.translate(cx + bodyW / 2 - 4, cy - 2);
      canvas.rotate(-0.9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4.5, -14, 9, 18), const Radius.circular(4.5)),
        Paint()..color = armColor,
      );
      canvas.drawCircle(const Offset(0, -13), 4, Paint()..color = pawColor);
      canvas.restore();
    } else {
      // Boşta/uyurken sağ kol da aşağı.
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + bodyW / 2 - 3, cy + 4), width: 9, height: 15),
        Paint()..color = armColor,
      );
    }
  }

  void _ears(Canvas canvas, double cx, double top) {
    final c = species.body;
    final inner = species.earInner;
    void ear(double dx, {double rot = 0}) {
      canvas.save();
      canvas.translate(cx + dx, top);
      canvas.rotate(rot);
      switch (species.ear) {
        case EarType.pointy:
          final p = Path()
            ..moveTo(0, 8)
            ..lineTo(-6, -10)
            ..lineTo(6, -8)
            ..close();
          canvas.drawPath(p, Paint()..color = c);
          final pi = Path()
            ..moveTo(0, 5)
            ..lineTo(-3, -6)
            ..lineTo(3, -5)
            ..close();
          canvas.drawPath(pi, Paint()..color = inner);
          break;
        case EarType.long:
          canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 9, height: 24),
              Paint()..color = c);
          canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 4, height: 16),
              Paint()..color = inner);
          break;
        case EarType.round:
          canvas.drawCircle(Offset.zero, 8, Paint()..color = c);
          canvas.drawCircle(Offset.zero, 4.5, Paint()..color = inner);
          break;
        case EarType.tiny:
          canvas.drawCircle(Offset.zero, 4, Paint()..color = c);
          break;
        case EarType.none:
          break;
      }
      canvas.restore();
    }

    switch (species.ear) {
      case EarType.long:
        ear(-7, rot: -0.15);
        ear(7, rot: 0.15);
        break;
      case EarType.round:
        ear(-13);
        ear(13);
        break;
      case EarType.pointy:
        ear(-11, rot: -0.2);
        ear(11, rot: 0.2);
        break;
      case EarType.tiny:
        ear(-9);
        ear(9);
        break;
      case EarType.none:
        break;
    }
  }

  void _face(Canvas canvas, double cx, double cy) {
    // Göz yamaları (panda).
    if (species.eyePatch) {
      for (final dx in [-7.0, 7.0]) {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + dx, cy - 2), width: 10, height: 12),
          Paint()..color = species.patch,
        );
      }
    }

    final eyeY = cy - 2;
    if (_asleep) {
      // Kapalı gözler (kavis).
      final p = Paint()
        ..color = const Color(0xFF2A2A2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (final dx in [-6.0, 6.0]) {
        final path = Path()
          ..moveTo(cx + dx - 3, eyeY)
          ..quadraticBezierTo(cx + dx, eyeY + 3, cx + dx + 3, eyeY);
        canvas.drawPath(path, p);
      }
      // Küçük "z z z" (uyku).
      final zPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      var zx = cx + 12.0;
      var zy = cy - 10.0;
      for (final s in [3.2, 2.4, 1.7]) {
        final z = Path()
          ..moveTo(zx, zy)
          ..lineTo(zx + s, zy)
          ..lineTo(zx, zy + s)
          ..lineTo(zx + s, zy + s);
        canvas.drawPath(z, zPaint);
        zx += s + 1.5;
        zy -= s + 1.0;
      }
    } else {
      for (final dx in [-6.0, 6.0]) {
        canvas.drawCircle(Offset(cx + dx, eyeY), 3.2,
            Paint()..color = const Color(0xFF241C18));
        canvas.drawCircle(Offset(cx + dx - 1, eyeY - 1), 1.1,
            Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }

    // Yanak (hafif pembe).
    for (final dx in [-10.0, 10.0]) {
      canvas.drawCircle(Offset(cx + dx, cy + 4), 2.6,
          Paint()..color = const Color(0xFFE79AA4).withValues(alpha: 0.35));
    }

    // Burun / gaga.
    if (species.beak) {
      final p = Path()
        ..moveTo(cx - 3.5, cy + 3)
        ..lineTo(cx + 3.5, cy + 3)
        ..lineTo(cx, cy + 8)
        ..close();
      canvas.drawPath(p, Paint()..color = species.nose);
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 4), width: 5.5, height: 4),
        Paint()..color = species.nose,
      );
      // Ağız.
      final m = Paint()
        ..color = const Color(0xFF3A2A22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(cx, cy + 6)
        ..quadraticBezierTo(cx - 3, cy + 9, cx - 5, cy + 7)
        ..moveTo(cx, cy + 6)
        ..quadraticBezierTo(cx + 3, cy + 9, cx + 5, cy + 7);
      canvas.drawPath(path, m);
    }
  }

  @override
  bool shouldRepaint(CritterPainter old) =>
      old.species != species || old.pose != pose;
}
