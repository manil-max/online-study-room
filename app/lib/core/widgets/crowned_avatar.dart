import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/gamification_providers.dart';
import '../stats/progression_visuals.dart';
import 'avatar_aura.dart';
import 'user_avatar.dart';

/// Bu boyutun altındaki avatarlar tacın **tok** varyantını kullanır.
///
/// Ürün gerçeği: taçlı avatar r = 12 (ısı tablosu), 14 (liderlik, sohbet),
/// 16 (aktif üyeler), 18, 20, 28, 44, 48 boyutlarında çiziliyor. En küçük
/// üçünde ince uçlar ve inciler piksel altına düşüyor.
const double kCrownCompactRadius = 18.0;

/// Taç halkasının kalınlığı.
///
/// Eskiden sabit `3` px'ti: r = 12'de 24 piksellik avatarın çeyreğini yiyor,
/// r = 48'de ise ince kalıyordu. Artık yarıçapla ölçekleniyor, alt sınır
/// görünürlük içindir.
double crownRingWidth(double radius) => math.max(2.0, radius * 0.075);

double _rad(double deg) => deg * math.pi / 180.0;

/// Merkezden **açı (tepe = 0°) + yarıçap çarpanı** ile bir nokta.
Offset _polar(Offset center, double base, double angleDeg, double radiusMul) {
  final a = _rad(angleDeg);
  final r = base * radiusMul;
  return Offset(center.dx + r * math.sin(a), center.dy - r * math.cos(a));
}

/// Taç siluetinin bir köşesi (uç ya da vadi).
@immutable
class CrownVertex {
  const CrownVertex(this.angle, this.radius);
  final double angle;
  final double radius;
}

/// Taç geometrisinin **kutupsal** tanımı (WP-292).
///
/// Eski taç düz bir `RRect` bant + zikzak üçgenlerdi. Bandın alt kenarı doğru
/// parçası olduğu için daire biçimli avatarın yalnız tepe noktasına değiyor,
/// iki ucu havada kalıyordu — proje sahibi "doğal durmuyor" derken gördüğü
/// şey buydu. Burada her nokta avatar merkezine göre **açı + yarıçap** ile
/// tanımlanır; bandın alt kenarı avatarla **eş merkezli bir yay** olduğundan
/// taç her boyutta kafaya teğet oturur ve uçları kafanın yanlarından sarkar.
@immutable
class CrownGeometry {
  const CrownGeometry({
    required this.halfSpanDeg,
    required this.tipRadius,
    required this.pearlRadius,
    required this.bow,
  });

  /// Bandın merkezden görülen yarım açısı (derece).
  final double halfSpanDeg;

  /// En uzun ucun yarıçap çarpanı (`1.0` = halkanın dış kenarı).
  final double tipRadius;

  /// Uçlardaki incinin yarıçap çarpanı; `0` → inci çizilmez.
  final double pearlRadius;

  /// Kenar içbükeyliği: `0` düz üçgen, `1` ince gotik iğne.
  final double bow;

  /// Bandın kalınlığı ve uçlar arasındaki vadinin derinliği tasarımın
  /// sabitleri — sahip önizlemede bunları değiştirmedi.
  static const double bandThickness = 0.17;
  static const double valleyRadius = 1.20;

  /// Sahip onayı (2026-07-25, canlı önizleme üzerinden):
  /// `5 uç · span 50° · tip 1.63 · inci 0.10 · kavis 0.50`.
  static const CrownGeometry standard = CrownGeometry(
    halfSpanDeg: 50,
    tipRadius: 1.63,
    pearlRadius: 0.10,
    bow: 0.50,
  );

  /// Küçük avatarlarda aynı 5 uçlu siluetin tok ve **oransal olarak daha
  /// büyük** hâli.
  ///
  /// İlk denemede tam tersi yapıldı (daha kısa taç) ve golden'da r = 12'de taç
  /// okunaksız bir tümseğe indi: 24 piksellik avatarda taca ~7 piksel kalıyor.
  /// Doğru çözüm tacı **büyütmek**: uçlar uzar, inci kapanır (çapı ~2 piksele
  /// düşüp lekeye dönüşüyordu), kavis azalır (uçlar 2 piksellik tarak olmasın).
  /// **Uç sayısı değişmez** — kullanıcı listede ve profilde aynı tacı görmeli.
  static const CrownGeometry compact = CrownGeometry(
    halfSpanDeg: 50,
    tipRadius: 1.74,
    pearlRadius: 0,
    bow: 0.28,
  );

  static CrownGeometry forRadius(double radius) =>
      radius < kCrownCompactRadius ? compact : standard;

  /// Beş uç: uzun · kısa · en uzun · kısa · uzun.
  List<CrownVertex> tips() {
    final s = halfSpanDeg;
    return <CrownVertex>[
      CrownVertex(-0.82 * s, tipRadius - 0.14),
      CrownVertex(-0.42 * s, tipRadius - 0.32),
      CrownVertex(0, tipRadius),
      CrownVertex(0.42 * s, tipRadius - 0.32),
      CrownVertex(0.82 * s, tipRadius - 0.14),
    ];
  }

  /// Uç incilerinin merkezleri.
  List<Offset> pearlCenters({required Offset center, required double base}) {
    if (pearlRadius <= 0.005) return const <Offset>[];
    return <Offset>[
      for (final v in tips()) _polar(center, base, v.angle, v.radius),
    ];
  }

  /// Tacın merkezden **yukarı** doğru kapladığı yer.
  double topExtent(double base) => base * (tipRadius + pearlRadius);

  /// Tacın merkezden **yana** doğru kapladığı yer.
  double halfWidth(double base) {
    var m = (1.0 + bandThickness) * math.sin(_rad(halfSpanDeg));
    for (final v in tips()) {
      final x = (v.radius + pearlRadius) * math.sin(_rad(v.angle)).abs();
      if (x > m) m = x;
    }
    return base * m;
  }

  /// Taç silueti: eş merkezli bant yayı + beş uç.
  Path pathFor({required Offset center, required double base}) {
    const inner = 1.0;
    final outer = inner + bandThickness;
    final t = tips();
    final path = Path();

    final start = _polar(center, base, -halfSpanDeg, inner);
    path.moveTo(start.dx, start.dy);
    // 🔴 Tasarımın kalbi: bandın alt kenarı avatarla eş merkezli yay. Bunu
    // düz `lineTo` yapmak eski "havada duran dikdörtgen" hatasını geri getirir.
    path.arcToPoint(
      _polar(center, base, halfSpanDeg, inner),
      radius: Radius.circular(base * inner),
      clockwise: true,
    );
    final rightBand = _polar(center, base, halfSpanDeg, outer);
    path.lineTo(rightBand.dx, rightBand.dy);

    _edge(path, center, base, CrownVertex(halfSpanDeg, outer), t.last);
    for (var i = t.length - 1; i > 0; i--) {
      final valley = CrownVertex(
        (t[i].angle + t[i - 1].angle) / 2,
        valleyRadius,
      );
      _edge(path, center, base, t[i], valley);
      _edge(path, center, base, valley, t[i - 1]);
    }
    _edge(path, center, base, t.first, CrownVertex(-halfSpanDeg, outer));

    path.close();
    return path;
  }

  /// Bandın kendisi (iç ve dış yaylar arasındaki halka dilimi).
  Path bandPathFor({required Offset center, required double base}) {
    const inner = 1.0;
    final outer = inner + bandThickness;
    final start = _polar(center, base, -halfSpanDeg, inner);
    final rightOuter = _polar(center, base, halfSpanDeg, outer);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..arcToPoint(
        _polar(center, base, halfSpanDeg, inner),
        radius: Radius.circular(base * inner),
        clockwise: true,
      )
      ..lineTo(rightOuter.dx, rightOuter.dy)
      ..arcToPoint(
        _polar(center, base, -halfSpanDeg, outer),
        radius: Radius.circular(base * outer),
        clockwise: false,
      )
      ..close();
  }

  void _edge(
    Path path,
    Offset c,
    double base,
    CrownVertex from,
    CrownVertex to,
  ) {
    // Kontrol noktası **alçak** uca çekilir: eğri vadide yatıp uca doğru
    // dikleşir, yani kenar içbükey olur. `bow = 0`'da nokta tam ortadadır →
    // düz kenar. Yön bağımsızdır, kontrol noktası geometrik olarak aynıdır.
    final low = from.radius <= to.radius ? from : to;
    final high = from.radius <= to.radius ? to : from;
    final ca = low.angle + (0.5 + 0.22 * bow) * (high.angle - low.angle);
    final cr = low.radius + (0.5 - 0.40 * bow) * (high.radius - low.radius);
    final ctrl = _polar(c, base, ca, cr);
    final end = _polar(c, base, to.angle, to.radius);
    path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
  }

  @override
  bool operator ==(Object other) =>
      other is CrownGeometry &&
      other.halfSpanDeg == halfSpanDeg &&
      other.tipRadius == tipRadius &&
      other.pearlRadius == pearlRadius &&
      other.bow == bow;

  @override
  int get hashCode => Object.hash(halfSpanDeg, tipRadius, pearlRadius, bow);
}

/// Profil fotoğrafı + kademe halkası + kafaya oturan taç (WP-292).
///
/// [crownRank] null/boş ise düz [UserAvatar] (taçsız).
class CrownedAvatar extends StatelessWidget {
  const CrownedAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.radius = 20,
    this.crownRank,
    this.onTap,
    this.showAura = false,
  });

  final String displayName;
  final String? avatarUrl;
  final double radius;
  final String? crownRank;
  final VoidCallback? onTap;

  /// Arkada dönen kademe renginde aura (WP-298).
  ///
  /// **Varsayılan kapalı ve öyle kalmalı.** Sahip kararı: yalnız profil ve
  /// sosyal profil ekranı açar. Bir listeye açılırsa ekranda onlarca ticker
  /// oluşur ve kare bütçesi gider.
  final bool showAura;

  @override
  Widget build(BuildContext context) {
    final rank = crownRank;
    final hasCrown = rank != null && rank.isNotEmpty;
    // 🔴 Kademe → renk eşlemesi WP-292'de DEĞİŞMEDİ: renk hâlâ yalnız
    // `crownColorFor` üzerinden, o da `crownRankForXp` eşiklerinden türer.
    final color = hasCrown ? crownColorFor(rank) : null;

    Widget avatar = UserAvatar(
      displayName: displayName,
      avatarUrl: avatarUrl,
      radius: radius,
    );

    if (hasCrown && color != null) {
      // Aura yoğunluğu kademeden türer; altın altındaki kademelerde 0 olduğu
      // için `showAura` açık olsa da hiçbir şey çizilmez.
      final auraIntensity = auraIntensityForTier(crownTierNumber(rank));
      final geometry = CrownGeometry.forRadius(radius);
      final ring = crownRingWidth(radius);
      final base = radius + ring;
      final outlineW = math.max(0.8, radius * 0.045);

      // Kutu tam tacın kapladığı yer kadar: eski simetrik kare kutu altta boş
      // yer bırakıyordu (satırları gereksiz yükseltiyordu).
      final top = geometry.topExtent(base) + outlineW;
      final half = math.max(base, geometry.halfWidth(base) + outlineW);
      final center = Offset(half, top);
      final ringBox = base * 2;

      avatar = SizedBox(
        width: half * 2,
        height: top + base + outlineW,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Aura en altta: avatarın ve tacın arkasından taşar. Kutu bilerek
            // büyütülmedi — profil ekranındaki fotoğraf değiştir düğmesi bu
            // kutunun köşesine `Positioned` ile bağlı, kutu büyürse düğme
            // avatardan kopar. Aura dikeyde kutunun içinde kalıyor, yalnız
            // yanlara taşıyor (bkz. `kAuraOuterRadius`).
            if (showAura && auraIntensity > 0)
              Positioned.fill(
                child: AvatarAuraLayer(
                  color: color,
                  intensity: auraIntensity,
                  base: base,
                  center: center,
                ),
              ),
            Positioned(
              left: center.dx - base,
              top: center.dy - base,
              child: Container(
                width: ringBox,
                height: ringBox,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: ring),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: radius * 0.30,
                      spreadRadius: radius * 0.03,
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: radius * 0.1,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: UserAvatar(
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                  radius: radius,
                ),
              ),
            ),
            // Taç halkanın üstünde çizilir; `CustomPainter.hitTest` varsayılan
            // olarak dokunmayı yakalamaz, altındaki avatar tıklanabilir kalır.
            Positioned.fill(
              child: CustomPaint(
                painter: CrownPainter(
                  color: color,
                  base: base,
                  center: center,
                  geometry: geometry,
                  outline: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: avatar,
    );
  }
}

/// Tacı [center] merkezli, [base] yarıçap tabanlı çizer.
///
/// Boyut bilgisi `size`'dan değil [base]/[center]'dan gelir: aynı painter hem
/// avatar üstünde (kutu avatarın kapladığı yer) hem [CrownGlyph] içinde
/// (kutu yalnız tacın kendisi) kullanılıyor.
class CrownPainter extends CustomPainter {
  CrownPainter({
    required this.color,
    required this.base,
    required this.center,
    this.geometry = CrownGeometry.standard,
    this.outline,
  });

  final Color color;
  final double base;
  final Offset center;
  final CrownGeometry geometry;
  final Color? outline;

  @override
  void paint(Canvas canvas, Size size) {
    final path = geometry.pathFor(center: center, base: base);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Bant, uçlardan bir tık koyu: derinlik gradyan olmadan çıkar (uygulamanın
    // geri kalanında da gradyan yok).
    final bandColor = Color.lerp(color, Colors.black, 0.20) ?? color;
    canvas.drawPath(
      geometry.bandPathFor(center: center, base: base),
      Paint()
        ..color = bandColor
        ..style = PaintingStyle.fill,
    );

    final strokeW = math.max(0.7, base * 0.042);
    if (outline != null) {
      final stroke = Paint()
        ..color = outline!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, stroke);
    }

    final pearls = geometry.pearlCenters(center: center, base: base);
    if (pearls.isEmpty) return;
    final pearlR = math.max(1.1, base * geometry.pearlRadius);
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final p in pearls) {
      canvas.drawCircle(p, pearlR, fill);
      if (outline != null) {
        canvas.drawCircle(
          p,
          pearlR,
          Paint()
            ..color = outline!
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CrownPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.base != base ||
      oldDelegate.center != center ||
      oldDelegate.geometry != geometry ||
      oldDelegate.outline != outline;
}

/// [userId] ile `gamification_profiles.crown_rank` canlı izler.
class LiveCrownedAvatar extends ConsumerWidget {
  const LiveCrownedAvatar({
    super.key,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.radius = 20,
    this.onTap,
    this.showAura = false,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double radius;
  final VoidCallback? onTap;

  /// Bkz. [CrownedAvatar.showAura] — listelerde açılmaz.
  final bool showAura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref
        .watch(gamificationProfileProvider(userId))
        .asData
        ?.value
        .crownRank;
    return CrownedAvatar(
      displayName: displayName,
      avatarUrl: avatarUrl,
      radius: radius,
      crownRank: rank,
      onTap: onTap,
      showAura: showAura,
    );
  }
}
