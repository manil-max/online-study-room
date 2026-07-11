import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/providers/alarm_providers.dart';

class TimersScreen extends ConsumerWidget {
  const TimersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instancesState = ref.watch(timerInstancesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çoklu Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTimerDialog(context, ref),
          ),
        ],
      ),
      body: instancesState.when(
        data: (instances) {
          if (instances.isEmpty) {
            return const Center(
              child: Text('Henüz çalışan bir timer yok.'),
            );
          }
          return ListView.builder(
            itemCount: instances.length,
            itemBuilder: (context, index) {
              final inst = instances[index];
              return _TimerCard(instance: inst);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }

  Future<void> _showAddTimerDialog(BuildContext context, WidgetRef ref) async {
    // Basit bir eklenti (örneğin sabit 5 dk)
    final newInst = TimerInstance(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: 'Özel Zamanlayıcı',
      durationSeconds: 300, // 5 dakika
      remainingSeconds: 300,
      status: TimerStateStatus.running,
      lastUpdatedAt: DateTime.now(),
    );
    ref.read(timerInstancesProvider.notifier).addInstance(newInst);
  }
}

class _TimerCard extends ConsumerWidget {
  const _TimerCard({required this.instance});
  
  final TimerInstance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mins = instance.remainingSeconds ~/ 60;
    final secs = instance.remainingSeconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instance.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(timeStr, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            Row(
              children: [
                if (instance.status == TimerStateStatus.running)
                  IconButton(
                    icon: const Icon(Icons.pause),
                    onPressed: () {
                      ref.read(timerInstancesProvider.notifier).pauseInstance(instance.id);
                    },
                  )
                else if (instance.status == TimerStateStatus.paused || instance.status == TimerStateStatus.initial)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {
                      ref.read(timerInstancesProvider.notifier).resumeInstance(instance.id);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () {
                    ref.read(timerInstancesProvider.notifier).stopInstance(instance.id);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    ref.read(timerInstancesProvider.notifier).deleteInstance(instance.id);
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
