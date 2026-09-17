import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../desktop/desktop_surface.dart';
import '../dashboard_card.dart';
import '../dashboard_providers.dart';

/// Kart ekleme seçici.
/// Mobil: alt sayfa · Masaüstü: ortalanmış dialog + çok sütun.
Future<void> showCardPicker(BuildContext context) {
  return showDesktopPicker<void>(
    context: context,
    builder: (ctx) {
      // Mobil bottom sheet: sınırlı yükseklik için draggable sheet.
      if (MediaQuery.sizeOf(ctx).shortestSide < 600 &&
          MediaQuery.sizeOf(ctx).width < 700) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (context, scrollController) => const _CardPickerSheet(),
        );
      }
      return const _CardPickerSheet();
    },
  );
}

class _CardPickerSheet extends ConsumerWidget {
  const _CardPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layout = ref.watch(dashboardLayoutProvider);
    final notifier = ref.read(dashboardLayoutProvider.notifier);
    final used = layout.map((c) => c.type).toSet();
    final available = DashboardCardType.values
        .where((t) => !used.contains(t))
        .toList();
    final categoryOrder = <String>[
      '${AppLocalizations.of(context).homeSayac} & '
          '${AppLocalizations.of(context).homeGunlukHedef}',
      AppLocalizations.of(context).homeOzetler,
      AppLocalizations.of(context).homeGrafikler,
      AppLocalizations.of(context).homeIsiHaritalari,
      AppLocalizations.of(context).homeGrup,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).homeKartEkle,
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              Text(
                // WP-504: gömülü "kart" İngilizce arayüzde de Türkçe çıkıyordu
                // (WP-500 ile aynı sınıf; l10n kapısının kör noktası kapanınca
                // görünür oldu).
                AppLocalizations.of(context).homeKartSayisi(available.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).homeKapat,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        if (available.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).homeBitti,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 10.0;
                final cols = desktopGridColumns(
                  constraints.maxWidth,
                  compact: 2,
                  medium: 3,
                  expanded: 3,
                );
                final w = (constraints.maxWidth - 40 - gap * (cols - 1)) / cols;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    for (final cat in categoryOrder)
                      if (available.any((t) => t.category(context) == cat)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                          child: Text(
                            cat,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final t in available.where(
                              (t) => t.category(context) == cat,
                            ))
                              SizedBox(
                                width: w,
                                child: _CardTile(
                                  type: t,
                                  onAdd: () {
                                    notifier.toggle(t);
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).homeTtitleEklendi(
                                              t.title(context),
                                            ),
                                          ),
                                          duration: const Duration(
                                            milliseconds: 900,
                                          ),
                                        ),
                                      );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.type, required this.onAdd});

  final DashboardCardType type;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(type.icon, color: theme.colorScheme.primary, size: 20),
                const Spacer(),
                Icon(
                  Icons.add_circle,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // WP-836: kullanıcı ne eklediğini simgeden değil, kartın
            // minyatüründen görür. Anahtar testin "her tür için bir önizleme
            // var mı" sorusunu tür tür sorabilmesi için.
            DashboardCardPreview(key: cardPreviewKey(type), type: type),
            const SizedBox(height: 8),
            Text(
              type.title(context),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              type.description(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçicideki bir türün önizleme kutusunun anahtarı (WP-836).
Key cardPreviewKey(DashboardCardType type) =>
    ValueKey('card-preview-${type.name}');

/// 🔴 WP-836 — kart ekleme ekranındaki minyatür önizleme.
///
/// Sahip (gerçek cihaz, v85): *"yeni kart eklemek için olan yerde kartların
/// nasıl bir şey olduğunu önizleme gibi görse iyi olur"*. Seçicide o güne
/// kadar yalnız tür simgesi (`DashboardCardInfo.icon`) vardı: 18 kartın 9'u
/// aynı sınıfa (grafik/özet) düştüğü için simge "bu kart neye benziyor"
/// sorusunu cevaplamıyordu.
///
/// **VERİ OKUMAZ — ve bu bir söz değil, yapısal bir sınırdır.** Önizleme
/// kartın gerçek widget'ını çizmez; kartın *biçimini* anlatan **statik bir
/// örnek** çizer. Sınıf `StatelessWidget`tır, `WidgetRef` almaz ve hiçbir
/// provider'a dokunmaz; `ProviderScope` olmayan bir ağaçta bile çizilir
/// (`card_default_size_wp836_test.dart` önizlemeyi tam olarak öyle pompalar).
/// Dolayısıyla seçici açıldığında 18 kart için 18 yeni abonelik ve onların
/// ağ/veritabanı isteği doğamaz.
///
/// ⚠️ Gerçek kart (`dashboardCardFor`) bilerek kullanılmadı: o widget'lar
/// `ref.watch` ile grup, oturum, görev ve yoklama akışlarını dinler —
/// seçicide çizilseler panoda olmayan kartlar için yeni sorgular açardı.
/// Ortak iskelet yolu (`CardBlockSkeleton`) ise her tür için AYNI gri bloğu
/// verir, yani soruyu yine cevaplamazdı.
class DashboardCardPreview extends StatelessWidget {
  const DashboardCardPreview({super.key, required this.type, this.height = 72});

  final DashboardCardType type;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      // Dekoratif: ekran okuyucu zaten hemen altındaki başlık + açıklamayı
      // okuyor; şekli ayrıca anlatmak gürültüdür.
      child: Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: _sketch(type, scheme),
      ),
    );
  }
}

/// Önizleme desenleri. Sayısı kart türünden azdır: aynı biçimi paylaşan
/// kartlar (iki çizgi grafiği, iki liste) aynı deseni kullanır, ayrımı başlık
/// ve açıklama yapar.
enum _Sketch {
  clock,
  ring,
  bars,
  line,
  dots,
  grid,
  rows,
  stats,
  checklist,
  big,
}

_Sketch _sketchOf(DashboardCardType type) => switch (type) {
  DashboardCardType.timer => _Sketch.clock,
  DashboardCardType.goal => _Sketch.ring,
  DashboardCardType.today => _Sketch.stats,
  DashboardCardType.weekly => _Sketch.bars,
  DashboardCardType.line => _Sketch.line,
  DashboardCardType.monthly => _Sketch.stats,
  DashboardCardType.weekdayWeekend => _Sketch.bars,
  DashboardCardType.hours => _Sketch.bars,
  DashboardCardType.rhythm => _Sketch.grid,
  DashboardCardType.scatter => _Sketch.dots,
  DashboardCardType.records => _Sketch.stats,
  DashboardCardType.heatmap => _Sketch.grid,
  DashboardCardType.leaderboard => _Sketch.rows,
  DashboardCardType.groupGoal => _Sketch.ring,
  DashboardCardType.groupTrend => _Sketch.line,
  DashboardCardType.activeMembers => _Sketch.rows,
  DashboardCardType.tasks => _Sketch.checklist,
  DashboardCardType.dday => _Sketch.big,
};

/// Çubuk desenini kullanan üç kart aynı görünmesin diye örnek seri türden
/// okunur: haftalık 7 gün, hafta içi/sonu 2 sütun, saatler yoğunluk eğrisi.
const Map<DashboardCardType, List<double>> _barSamples = {
  DashboardCardType.weekly: [0.45, 0.8, 0.6, 1, 0.35, 0.7, 0.55],
  DashboardCardType.weekdayWeekend: [0.85, 0.45],
  DashboardCardType.hours: [
    0.2,
    0.35,
    0.5,
    0.75,
    1,
    0.8,
    0.55,
    0.4,
    0.6,
    0.85,
    0.5,
    0.25,
  ],
};

Widget _sketch(DashboardCardType type, ColorScheme scheme) {
  final strong = scheme.primary;
  final soft = scheme.primary.withValues(alpha: 0.28);
  return switch (_sketchOf(type)) {
    _Sketch.clock => Column(
      children: [
        Expanded(child: Center(child: _ring(scheme, 34))),
        const SizedBox(height: 6),
        _bar(strong, height: 10, radius: 5),
      ],
    ),
    _Sketch.ring => Row(
      children: [
        _ring(scheme, 40),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(soft, height: 7, radius: 4, widthFactor: 0.9),
              const SizedBox(height: 6),
              _bar(strong, height: 7, radius: 4, widthFactor: 0.55),
            ],
          ),
        ),
      ],
    ),
    _Sketch.bars => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in _barSamples[type] ?? const [0.5, 0.8, 0.6])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: FractionallySizedBox(
                heightFactor: f,
                alignment: Alignment.bottomCenter,
                child: _bar(f > 0.75 ? strong : soft, radius: 2),
              ),
            ),
          ),
      ],
    ),
    _Sketch.line => CustomPaint(
      size: Size.infinite,
      painter: _LineSketch(color: strong, fill: soft),
    ),
    _Sketch.dots => CustomPaint(
      size: Size.infinite,
      painter: _DotSketch(color: strong),
    ),
    _Sketch.grid => Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 3),
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 9; col++) ...[
                  if (col > 0) const SizedBox(width: 3),
                  Expanded(
                    child: _bar(
                      // Sabit ama düzensiz bir yoğunluk: ısı haritası
                      // "bazı kareler koyu" diye okunmalı.
                      scheme.primary.withValues(
                        alpha: 0.10 + ((row * 5 + col * 3) % 7) * 0.12,
                      ),
                      radius: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    ),
    _Sketch.rows => Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final f in const [0.9, 0.7, 0.5])
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _bar(
                  f > 0.8 ? strong : soft,
                  height: 7,
                  radius: 4,
                  widthFactor: f,
                ),
              ),
            ],
          ),
      ],
    ),
    _Sketch.stats => Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: (row + col).isEven ? soft : strong,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    ),
    _Sketch.checklist => Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final done in const [true, false, false])
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: done ? strong : Colors.transparent,
                  border: Border.all(color: done ? strong : soft, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _bar(soft, height: 6, radius: 3, widthFactor: 0.8),
              ),
            ],
          ),
      ],
    ),
    _Sketch.big => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _bar(strong, height: 20, radius: 4, widthFactor: 0.55),
        const SizedBox(height: 6),
        _bar(soft, height: 6, radius: 3, widthFactor: 0.35),
      ],
    ),
  };
}

Widget _ring(ColorScheme scheme, double diameter) => SizedBox.square(
  dimension: diameter,
  child: CircularProgressIndicator(
    value: 0.68,
    strokeWidth: 4,
    color: scheme.primary,
    backgroundColor: scheme.primary.withValues(alpha: 0.20),
  ),
);

Widget _bar(
  Color color, {
  double? height,
  double radius = 3,
  double widthFactor = 1,
}) => Align(
  alignment: AlignmentDirectional.centerStart,
  child: FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  ),
);

class _LineSketch extends CustomPainter {
  const _LineSketch({required this.color, required this.fill});

  final Color color;
  final Color fill;

  static const List<double> _points = [0.75, 0.45, 0.6, 0.25, 0.4, 0.1];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < _points.length; i++) {
      final x = size.width * i / (_points.length - 1);
      final y = size.height * _points[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_LineSketch old) => old.color != color || old.fill != fill;
}

class _DotSketch extends CustomPainter {
  const _DotSketch({required this.color});

  final Color color;

  /// Sabit örnek dağılım (x, y oranları) — rastgele değil, yoksa her karede
  /// başka bir resim çizilirdi.
  static const List<List<double>> _dots = [
    [0.1, 0.7],
    [0.25, 0.35],
    [0.35, 0.8],
    [0.5, 0.5],
    [0.6, 0.2],
    [0.72, 0.65],
    [0.85, 0.4],
    [0.95, 0.75],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.75);
    for (final d in _dots) {
      canvas.drawCircle(
        Offset(size.width * d[0], size.height * d[1]),
        3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotSketch old) => old.color != color;
}
