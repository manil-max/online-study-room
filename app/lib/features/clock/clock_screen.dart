import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../android_widgets/widget_deep_link.dart';
import '../desktop/desktop_page_scaffold.dart';
import 'alarms_screen.dart';
import 'clock_desktop_layout.dart';
import 'tasks_screen.dart';
import 'timers_screen.dart';

/// Araçlar sekmeleri — Alarm · Timer · Görevler.
/// Yön değişimi ürün yüzeyini değiştirmez; yatayda da aynı Araçlar akışı kalır.
enum ClockTab { alarm, multiTimer, tasks }

/// WP-700: rotanin IKINCI seviyesi. Ana kabuk yalniz "Araclar" sekmesini
/// secebilir; hangi arac oldugunu bilen tek yer burasi oldugu icin esleme de
/// burada durur (`widget_deep_link.dart` `ClockTab`i tanimaz — enum'u oraya
/// kopyalamak iki gercek uretirdi).
ClockTab? clockTabForWidgetRoute(WidgetRoute? route) => switch (route) {
  WidgetRoute.clock => ClockTab.alarm,
  WidgetRoute.tasks => ClockTab.tasks,
  _ => null,
};

class ClockScreen extends ConsumerStatefulWidget {
  const ClockScreen({super.key});

  @override
  ConsumerState<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ConsumerState<ClockScreen> {
  ClockTab _tab = ClockTab.alarm;
  int _appliedRouteTick = 0;

  /// 🔴 SOGUK YOL. Bu ekran `IndexedStack` icinde uygulama acilisinda kurulur;
  /// widget rotasi ise kanal cevabi geldiginde, yani cogu zaman DAHA SONRA
  /// duser. Yine de ilk kurulum okunur: kanal cevabi bu ekran monte
  /// olmadan once gelirse `ref.listen` o degisimi kaciracakti.
  @override
  void initState() {
    super.initState();
    _applyRoute(ref.read(widgetRouteProvider), initial: true);
  }

  void _applyRoute(WidgetRouteRequest request, {bool initial = false}) {
    if (request.tick == _appliedRouteTick) return;
    _appliedRouteTick = request.tick;
    final tab = clockTabForWidgetRoute(request.route);
    if (tab == null || tab == _tab) return;
    if (initial) {
      _tab = tab;
    } else {
      setState(() => _tab = tab);
    }
  }

  void _onTabChanged(ClockTab tab) => setState(() => _tab = tab);

  /// Eşit genişlikte ikon+kısa etiket — kaydırma yok, tek ekrana sığar.
  Widget _buildIconStrip() {
    final items = <(ClockTab, IconData, String, Key)>[
      (
        ClockTab.alarm,
        Icons.alarm,
        AppLocalizations.of(context).coreAlarm,
        Key('clock_tab_alarm'),
      ),
      (
        ClockTab.multiTimer,
        Icons.hourglass_empty,
        AppLocalizations.of(context).clockTimer,
        Key('clock_tab_timer'),
      ),
      (
        ClockTab.tasks,
        Icons.checklist_outlined,
        AppLocalizations.of(context).clockTasks,
        Key('clock_tab_tasks'),
      ),
    ];

    return Material(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: _StripItem(
                  key: item.$4,
                  icon: item.$2,
                  label: item.$3,
                  selected: _tab == item.$1,
                  onTap: () => _onTabChanged(item.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    return switch (_tab) {
      ClockTab.alarm => const AlarmsScreen(embedded: true),
      ClockTab.multiTimer => const TimersScreen(embedded: true),
      ClockTab.tasks => const TasksScreen(embedded: true),
    };
  }

  /// 🔴 WP-678 — masaüstü kolu AYRI bir ağaç.
  ///
  /// Mobil dal aşağıda birebir korunur (SPEC §7: "mobil branch değişmez");
  /// masaüstü kolu SPEC §3 A2'yi uygular. Aynı ağacı `isDesktopWindow`
  /// bayraklarıyla delik deşik etmek yerine iki kol ayrıldı — kardeş ekran
  /// Gruplar'da (WP-675) da bu yapıldı.
  ///
  /// İki karar, ikisi de ölçüme dayanıyor:
  ///   * **bant** = [DesktopBreakpoints.maxContentWidth] (1440, SPEC §2.3).
  ///     Ölçümde içerik 2560 px'lik pencerede 2320 px yayılıyordu. Bant
  ///     [DesktopContent] ile kurulur — SPEC §6 "BAĞLA, ATMA": bu widget
  ///     yazılmıştı ama `lib/` içinde çağrı yeri yoktu.
  ///   * **şerit** = [ClockCommandStrip] ile [kClockStripMaxWidth] (600).
  ///     Üç eşit `Expanded` bütün pencereyi yiyordu; "Alarm" → "Timer"
  ///     mesafesi 2560 px'te 839 px'ti (SPEC KURAL 2.2 sert tavanı 600).
  ///
  /// Kenar boşluğu bilinçli olarak bandın **içinde**: dışarıda kalsaydı 2560
  /// px'lik pencerede 24 px'lik kenar boşluğunun hiçbir anlamı olmazdı.
  Widget _buildDesktop(Widget content) {
    final density = DesktopDensity.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: DesktopContent(
          maxWidth: DesktopBreakpoints.maxContentWidth,
          padding: density.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClockCommandStrip(child: _buildIconStrip()),
              const SizedBox(height: 12),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // SICAK YOL: uygulama zaten acikken gelen rota.
    ref.listen(widgetRouteProvider, (_, next) => _applyRoute(next));
    final content = _buildTabBody();

    if (isDesktopWindow) return _buildDesktop(content);

    // Windows: AppBar/sağ panel yok — sol rail + şerit + içerik.
    // WP-460: "Araçlar" başlığı alt menüde zaten yazılı; ikon şeridi bu
    // sekmenin gerçek araç çubuğudur. Üst güvenli alan SafeArea ile korunur.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: _buildIconStrip(),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
