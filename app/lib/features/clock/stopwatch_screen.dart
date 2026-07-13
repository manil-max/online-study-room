import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_engine/lap_analysis.dart';
import '../../data/providers/alarm_providers.dart';

/// Profesyonel kronometre + tur analizi (WP-60).
class StopwatchScreen extends ConsumerStatefulWidget {
  const StopwatchScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends ConsumerState<StopwatchScreen> {
  Timer? _uiTick;

  @override
  void initState() {
    super.initState();
    // 50ms UI yenileme; süre epoch'tan türetilir.
    _uiTick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && ref.read(stopwatchProvider).running) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = ref.watch(stopwatchProvider);
    final nowMs = ref.read(epochClockProvider).nowMs();
    final elapsed = Duration(milliseconds: sw.elapsedMs(nowMs));
    final analysis = LapAnalysis.fromTotals(sw.laps);
    final theme = Theme.of(context);

    final body = Column(
      children: [
        const SizedBox(height: 24),
        Text(
          formatStopwatch(elapsed),
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w200,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sw.running
              ? 'Çalışıyor'
              : (elapsed.inMilliseconds > 0 ? 'Duraklatıldı' : 'Hazır'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundBtn(
              icon: Icons.refresh,
              label: 'Sıfırla',
              onPressed: elapsed.inMilliseconds == 0 && sw.laps.isEmpty
                  ? null
                  : () => ref.read(stopwatchProvider.notifier).reset(),
            ),
            const SizedBox(width: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 88),
                shape: const CircleBorder(),
              ),
              onPressed: () => ref.read(stopwatchProvider.notifier).toggle(),
              child: Icon(
                sw.running ? Icons.pause : Icons.play_arrow,
                size: 40,
              ),
            ),
            const SizedBox(width: 20),
            _RoundBtn(
              icon: Icons.flag_outlined,
              label: 'Tur',
              onPressed: sw.running || elapsed.inMilliseconds > 0
                  ? () => ref.read(stopwatchProvider.notifier).lap()
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (sw.laps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Turlar',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Kopyala',
                  onPressed: () {
                    final buf = StringBuffer();
                    for (var i = 0; i < analysis.splitsMs.length; i++) {
                      final split =
                          Duration(milliseconds: analysis.splitsMs[i]);
                      buf.writeln(
                        'Tur ${i + 1}: ${formatStopwatch(split)}',
                      );
                    }
                    Clipboard.setData(ClipboardData(text: buf.toString()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Turlar kopyalandı')),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined, size: 20),
                ),
              ],
            ),
          ),
        Expanded(
          child: analysis.isEmpty
              ? Center(
                  child: Text(
                    'Tur kaydı yok',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: analysis.splitsMs.length,
                  itemBuilder: (context, index) {
                    // En yeni üstte
                    final i = analysis.splitsMs.length - 1 - index;
                    final split =
                        Duration(milliseconds: analysis.splitsMs[i]);
                    final total = Duration(milliseconds: sw.laps[i]);
                    final delta = analysis.deltaVsPrevious(i);
                    final isFast = i == analysis.fastestIndex;
                    final isSlow = i == analysis.slowestIndex;

                    Color? bg;
                    if (isFast) {
                      bg = const Color(0xFF22C55E).withValues(alpha: 0.15);
                    } else if (isSlow) {
                      bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          'Tur ${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isFast
                                ? const Color(0xFF16A34A)
                                : isSlow
                                    ? const Color(0xFFDC2626)
                                    : null,
                          ),
                        ),
                        subtitle: Text(
                          'Toplam ${formatStopwatch(total)}'
                          '${isFast ? ' · En hızlı' : ''}'
                          '${isSlow ? ' · En yavaş' : ''}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatStopwatch(split),
                              style: const TextStyle(
                                fontFeatures: [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (delta != null)
                              Text(
                                delta >= 0
                                    ? '+${formatStopwatch(Duration(milliseconds: delta))}'
                                    : '−${formatStopwatch(Duration(milliseconds: -delta))}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: delta >= 0
                                      ? theme.colorScheme.error
                                      : const Color(0xFF16A34A),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Kronometre')),
      body: body,
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 28,
          style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
