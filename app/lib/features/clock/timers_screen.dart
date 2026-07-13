import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_engine/lap_analysis.dart';
import '../../data/models/timer_preset.dart';
import '../../data/providers/alarm_providers.dart';

class TimersScreen extends ConsumerWidget {
  const TimersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instances = ref.watch(timerInstancesProvider);
    final presets = ref.watch(timerPresetsProvider);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hızlı başlat',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Biten veya durdurulan timer (≥30 sn) çalışma süresine eklenir.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: presets.when(
            data: (list) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == list.length) {
                  return ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Özel'),
                    onPressed: () => _customDialog(context, ref),
                  );
                }
                final p = list[i];
                return ActionChip(
                  label: Text(p.label),
                  onPressed: () {
                    ref.read(timerInstancesProvider.notifier).addFromPreset(p);
                  },
                );
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: instances.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'Henüz çalışan bir timer yok.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: list.length,
                itemBuilder: (context, index) =>
                    _TimerCard(instance: list[index]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Çoklu Timer')),
      body: body,
    );
  }

  Future<void> _customDialog(BuildContext context, WidgetRef ref) async {
    final labelCtrl = TextEditingController(text: 'Özel Zamanlayıcı');
    var minutes = 5;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Özel timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Etiket'),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setLocal) {
                return Row(
                  children: [
                    const Text('Dakika:'),
                    Expanded(
                      child: Slider(
                        value: minutes.toDouble(),
                        min: 1,
                        max: 180,
                        divisions: 179,
                        label: '$minutes dk',
                        onChanged: (v) => setLocal(() => minutes = v.round()),
                      ),
                    ),
                    Text('$minutes'),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Başlat'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(timerInstancesProvider.notifier).addCustom(
            label: labelCtrl.text.trim().isEmpty
                ? 'Özel Zamanlayıcı'
                : labelCtrl.text.trim(),
            durationSeconds: minutes * 60,
          );
    }
    labelCtrl.dispose();
  }
}

class _TimerCard extends ConsumerWidget {
  const _TimerCard({required this.instance});

  final TimerInstance instance;

  Color _color(BuildContext context) {
    final hex = instance.colorHex;
    if (hex != null && hex.startsWith('#') && hex.length >= 7) {
      final v = int.tryParse(hex.substring(1, 7), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _color(context);
    final rem = Duration(seconds: instance.remainingSeconds);
    final progress = instance.durationSeconds <= 0
        ? 1.0
        : 1.0 - (instance.remainingSeconds / instance.durationSeconds);
    final done = instance.status == TimerStateStatus.done;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    instance.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (done)
                  Chip(
                    label: const Text('Bitti'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatCountdown(rem),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w300,
                    color: done ? color : null,
                  ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                if (instance.status == TimerStateStatus.running) ...[
                  IconButton(
                    tooltip: 'Duraklat',
                    onPressed: () => ref
                        .read(timerInstancesProvider.notifier)
                        .pauseInstance(instance.id),
                    icon: const Icon(Icons.pause),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(timerInstancesProvider.notifier)
                        .addMinute(instance.id),
                    child: const Text('+1 dk'),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(timerInstancesProvider.notifier)
                        .addMinute(instance.id, minutes: 5),
                    child: const Text('+5 dk'),
                  ),
                ] else if (instance.status == TimerStateStatus.paused ||
                    instance.status == TimerStateStatus.initial) ...[
                  IconButton(
                    tooltip: 'Başlat',
                    onPressed: () => ref
                        .read(timerInstancesProvider.notifier)
                        .resumeInstance(instance.id),
                    icon: const Icon(Icons.play_arrow),
                  ),
                ],
                if (instance.status == TimerStateStatus.done)
                  IconButton(
                    tooltip: 'Yeniden',
                    onPressed: () async {
                      await ref
                          .read(timerInstancesProvider.notifier)
                          .stopInstance(instance.id);
                      await ref
                          .read(timerInstancesProvider.notifier)
                          .resumeInstance(instance.id);
                    },
                    icon: const Icon(Icons.replay),
                  ),
                IconButton(
                  tooltip: 'Sıfırla',
                  onPressed: () => ref
                      .read(timerInstancesProvider.notifier)
                      .stopInstance(instance.id),
                  icon: const Icon(Icons.stop),
                ),
                IconButton(
                  tooltip: 'Sil',
                  onPressed: () => ref
                      .read(timerInstancesProvider.notifier)
                      .deleteInstance(instance.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
