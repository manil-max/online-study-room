import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/second_ticker.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/presence.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/presence_providers.dart';
import '../../../data/providers/study_providers.dart';

/// Kamp ateşi canlı sahnesi (FAZ 2G).
///
/// Düz üye listesinin yerini alan dinamik gece sahnesi: ortada yanan bir kamp
/// ateşi (canlı animasyon + yükselen kıvılcımlar), çevresinde **çalışan** üyeler
/// aydınlık halkada; **mola/çevrimdışı** üyeler sahnenin altındaki karanlığa
/// çekilir. Ateşin canlılığı çalışan üye sayısıyla büyür. Durum değişince avatar
/// halkadan karanlığa (veya tersi) yumuşak geçişle akar (`AnimatedPositioned`).
///
/// Anlık süreler her üyenin kendi `SecondTicker`'ıyla saniyede bir yenilenir;
/// sahne yerleşimi yalnız presence/üye verisi değişince yeniden kurulur.
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

        final studying = <Profile>[];
        final resting = <Profile>[];
        for (final m in members) {
          final status = presenceByUser[m.id]?.status ?? PresenceStatus.offline;
          if (status == PresenceStatus.studying) {
            studying.add(m);
          } else {
            resting.add(m);
          }
        }
        // Halkada tutarlı sıra için isme göre sırala (index'ler stabil kalsın).
        int byName(Profile a, Profile b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        studying.sort(byName);
        resting.sort(byName);

        return _SceneFrame(
          child: _SceneLayout(
            studying: studying,
            resting: resting,
            presenceByUser: presenceByUser,
            todayByUser: todayByUser,
          ),
        );
      },
    );
  }
}

/// Sahnenin gece atmosferli dış çerçevesi (koyu gradyan + yuvarlak köşe).
class _SceneFrame extends StatelessWidget {
  const _SceneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Yüzeyden türetilmiş, biraz daha koyu bir gece tonu (temaya uyumlu).
    final top = Color.lerp(scheme.surface, Colors.black, 0.28)!;
    final bottom = Color.lerp(scheme.surface, Colors.black, 0.55)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 360,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}

/// Sahnenin asıl yerleşimi: ateş + üye avatarları mutlak konumlu bir `Stack`'te.
class _SceneLayout extends StatelessWidget {
  const _SceneLayout({
    required this.studying,
    required this.resting,
    required this.presenceByUser,
    required this.todayByUser,
  });

  final List<Profile> studying;
  final List<Profile> resting;
  final Map<String, Presence> presenceByUser;
  final Map<String, int> todayByUser;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = w / 2;
        final fireY = h * 0.44; // ateşin merkez yüksekliği

        // Ateş çalışan sayısıyla büyür (0 → sönük).
        final intensity = studying.isEmpty
            ? 0.25
            : (0.55 + studying.length * 0.09).clamp(0.55, 1.0);

        // Halka yarıçapı ve avatar boyutu ekran genişliğine/kalabalığa göre.
        final ringR = math.min(w * 0.34, 132).clamp(76, 140).toDouble();
        final studyR = (26 - math.max(0, studying.length - 6) * 1.6)
            .clamp(16, 26)
            .toDouble();
        const restR = 17.0;

        final children = <Widget>[];

        // — Kıvılcım + ateş (sahnenin kalbi) —
        children.add(Positioned(
          left: cx - 90,
          top: fireY - 150,
          width: 180,
          height: 210,
          child: RepaintBoundary(
            child: _Campfire(intensity: intensity),
          ),
        ));

        // — Çalışan üyeler: ateş çevresinde üst yayda —
        for (var i = 0; i < studying.length; i++) {
          final theta = _ringAngle(i, studying.length);
          final left = cx + ringR * math.cos(theta) - studyR;
          final top = fireY + ringR * math.sin(theta) - studyR;
          final m = studying[i];
          children.add(_positioned(
            key: ValueKey(m.id),
            left: left,
            top: top,
            child: _CampMember(
              member: m,
              presence: presenceByUser[m.id],
              recordedToday: todayByUser[m.id] ?? 0,
              radius: studyR,
              studying: true,
            ),
          ));
        }

        // — Mola/çevrimdışı üyeler: altta karanlık şeritte —
        final restY = h - restR * 2 - 34;
        final restSpacing = resting.length <= 1
            ? 0.0
            : math
                .min(restR * 2 + 16, (w - 48) / (resting.length - 1))
                .toDouble();
        final restTotal = (resting.length - 1).clamp(0, 999) * restSpacing;
        final restStartX = cx - restTotal / 2;
        for (var j = 0; j < resting.length; j++) {
          final m = resting[j];
          final left = restStartX + j * restSpacing - restR;
          children.add(_positioned(
            key: ValueKey(m.id),
            left: left,
            top: restY,
            child: _CampMember(
              member: m,
              presence: presenceByUser[m.id],
              recordedToday: todayByUser[m.id] ?? 0,
              radius: restR,
              studying: false,
            ),
          ));
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Alt karanlık vinyet (mola/çevrimdışı bölge).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 96,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Sol üst köşe rozeti: kaç kişi çalışıyor.
            Positioned(
              left: 14,
              top: 12,
              child: _StudyingBadge(count: studying.length),
            ),
            // Kimse çalışmıyorsa nazik ipucu.
            if (studying.isEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: fireY + 24,
                child: Center(
                  child: Text(
                    'Ateş sönük — çalışmaya başla, herkes ısınsın',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ...children,
          ],
        );
      },
    );
  }

  /// Çalışan üyenin ateş çevresindeki açısı. Üst yayda simetrik dağılır; alt-orta
  /// ~60°'lik boşluk mola/çevrimdışı şeridine bırakılır.
  double _ringAngle(int i, int count) {
    const top = -math.pi / 2;
    if (count <= 1) return top;
    final span = math.min(2 * math.pi * 0.82, (count - 1) * 0.9);
    return top - span / 2 + span * (i / (count - 1));
  }

  Widget _positioned({
    required Key key,
    required double left,
    required double top,
    required Widget child,
  }) {
    return AnimatedPositioned(
      key: key,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      child: child,
    );
  }
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
        color: Colors.black.withValues(alpha: 0.28),
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

/// Ateş etrafındaki tek bir üye: avatar + ad + (çalışıyorsa) anlık süre.
/// Çalışan üye aydınlık ve sıcak halka ışığıyla; dinlenen üye soluk/karanlık.
class _CampMember extends StatelessWidget {
  const _CampMember({
    required this.member,
    required this.presence,
    required this.recordedToday,
    required this.radius,
    required this.studying,
  });

  final Profile member;
  final Presence? presence;
  final int recordedToday;
  final double radius;
  final bool studying;

  int _liveExtra(DateTime now) {
    final startedAt = presence?.startedAt;
    if (presence?.status != PresenceStatus.studying || startedAt == null) {
      return 0;
    }
    final diff = now.difference(startedAt).inSeconds;
    return diff > 0 ? diff : 0;
  }

  @override
  Widget build(BuildContext context) {
    final amber = subjectColor('chart-3');
    final width = radius * 2 + 48;

    final avatar = AnimatedOpacity(
      duration: const Duration(milliseconds: 520),
      opacity: studying ? 1 : 0.42,
      child: Container(
        decoration: studying
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: amber.withValues(alpha: 0.55),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              )
            : null,
        child: UserAvatar(
          displayName: member.displayName,
          avatarUrl: member.avatarUrl,
          radius: radius,
        ),
      ),
    );

    final nameStyle = TextStyle(
      color: studying ? Colors.white : Colors.white.withValues(alpha: 0.6),
      fontSize: studying ? 12 : 11,
      fontWeight: FontWeight.w500,
    );

    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showDetails(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            const SizedBox(height: 4),
            Text(
              member.displayName.isEmpty ? 'İsimsiz' : member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: nameStyle,
            ),
            if (studying)
              SecondTicker(
                builder: (_, now) => Text(
                  formatHms(_liveExtra(now)),
                  style: TextStyle(
                    color: subjectColor('chart-3'),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final status = presence?.status ?? PresenceStatus.offline;
    final (Color dot, String label) = switch (status) {
      PresenceStatus.studying => (subjectColor('chart-2'), 'Çalışıyor'),
      PresenceStatus.onBreak => (subjectColor('chart-3'), 'Molada'),
      PresenceStatus.offline => (Theme.of(context).colorScheme.outline,
          'Çevrimdışı'),
    };
    final live = _liveExtra(DateTime.now());

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
                UserAvatar(
                  displayName: member.displayName,
                  avatarUrl: member.avatarUrl,
                  radius: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  member.displayName.isEmpty ? 'İsimsiz' : member.displayName,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
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
                  value: formatHumanSeconds(recordedToday + live),
                ),
                if (status == PresenceStatus.studying)
                  _StatRow(
                    label: 'Şu anki oturum',
                    value: formatHms(live),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
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

/// Canlı kamp ateşi: yükselen kıvılcımlar + titreşen alevler + sıcak parıltı.
/// `intensity` (0..1) çalışan sayısıyla büyür; alev boyu ve parıltı ona bağlı.
class _Campfire extends StatefulWidget {
  const _Campfire({required this.intensity});

  final double intensity;

  @override
  State<_Campfire> createState() => _CampfireState();
}

class _CampfireState extends State<_Campfire>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Ember> _embers;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    final rnd = math.Random(7);
    _embers = List.generate(
      14,
      (_) => _Ember(
        phase: rnd.nextDouble(),
        xOffset: rnd.nextDouble() * 2 - 1,
        sway: 0.4 + rnd.nextDouble() * 0.9,
        size: 1.4 + rnd.nextDouble() * 2.2,
        speed: 0.7 + rnd.nextDouble() * 0.6,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _FirePainter(
          t: _controller.value,
          intensity: widget.intensity,
          embers: _embers,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Ember {
  const _Ember({
    required this.phase,
    required this.xOffset,
    required this.sway,
    required this.size,
    required this.speed,
  });

  final double phase; // 0..1 başlangıç fazı
  final double xOffset; // -1..1 yatay başlangıç
  final double sway; // yatay salınım genliği çarpanı
  final double size;
  final double speed;
}

class _FirePainter extends CustomPainter {
  _FirePainter({
    required this.t,
    required this.intensity,
    required this.embers,
  });

  final double t;
  final double intensity;
  final List<_Ember> embers;

  // Sıcak ateş paleti.
  static const _outer = Color(0xFFE04A1F); // koyu turuncu-kırmızı
  static const _mid = Color(0xFFF3862B); // turuncu
  static const _inner = Color(0xFFFFD24A); // sarı
  static const _core = Color(0xFFFFF3B0); // sıcak beyaz

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height * 0.82; // ateşin oturduğu zemin
    final flick = math.sin(t * 2 * math.pi);
    final flick2 = math.sin(t * 2 * math.pi * 1.7 + 1.1);

    // — Sıcak parıltı (radial glow) —
    final glowR = (70 + intensity * 46) + flick * 5;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _mid.withValues(alpha: 0.42 * intensity),
          _outer.withValues(alpha: 0.16 * intensity),
          _outer.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(
          Rect.fromCircle(center: Offset(cx, baseY - 24), radius: glowR));
    canvas.drawCircle(Offset(cx, baseY - 24), glowR, glowPaint);

    // — Odun kütükleri (basit çapraz) —
    _drawLogs(canvas, cx, baseY);

    // — Alev katmanları (dıştan içe) —
    final scale = 0.62 + intensity * 0.55; // çalışan çok → alev boyu artar
    _drawFlame(canvas, cx + flick * 3, baseY, 62 * scale, 118 * scale,
        _outer.withValues(alpha: 0.92), flick);
    _drawFlame(canvas, cx - flick2 * 3, baseY - 2, 44 * scale, 92 * scale,
        _mid.withValues(alpha: 0.95), flick2);
    _drawFlame(canvas, cx + flick2 * 2, baseY - 4, 27 * scale, 64 * scale,
        _inner, flick);
    _drawFlame(canvas, cx, baseY - 6, 14 * scale, 40 * scale, _core, flick2);

    // — Kıvılcımlar (yükselen parçacıklar) —
    _drawEmbers(canvas, size, cx, baseY);
  }

  void _drawLogs(Canvas canvas, double cx, double baseY) {
    final paint = Paint()..color = const Color(0xFF5A3B27);
    final darker = Paint()..color = const Color(0xFF3E281A);
    void log(double angle, Paint p) {
      canvas.save();
      canvas.translate(cx, baseY + 4);
      canvas.rotate(angle);
      final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-34, -6, 68, 12),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, p);
      canvas.restore();
    }

    log(0.28, darker);
    log(-0.28, paint);
  }

  void _drawFlame(Canvas canvas, double cx, double baseY, double w, double h,
      Color color, double flick) {
    final fh = h * (0.92 + flick * 0.12);
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
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawEmbers(Canvas canvas, Size size, double cx, double baseY) {
    final riseTop = size.height * 0.06;
    final riseSpan = baseY - riseTop;
    for (final e in embers) {
      final prog = (t * e.speed + e.phase) % 1.0;
      final y = baseY - prog * riseSpan;
      final swayX = math.sin(prog * math.pi * 3 + e.phase * 6) * 14 * e.sway;
      final x = cx + e.xOffset * 20 + swayX;
      // Yükseldikçe sön.
      final alpha = ((1 - prog) * intensity).clamp(0.0, 1.0);
      final r = e.size * (1 - prog * 0.5);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = _inner.withValues(alpha: alpha * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_FirePainter old) =>
      old.t != t || old.intensity != intensity;
}
