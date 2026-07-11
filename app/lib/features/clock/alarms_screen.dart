import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/providers/alarm_providers.dart';

class AlarmsScreen extends ConsumerWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmsState = ref.watch(alarmsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişisel Alarmlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAlarmDialog(context, ref),
          ),
        ],
      ),
      body: alarmsState.when(
        data: (alarms) {
          if (alarms.isEmpty) {
            return const Center(
              child: Text('Henüz bir alarm oluşturmadınız.'),
            );
          }
          return ListView.builder(
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              final timeStr =
                  '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}';
              return ListTile(
                title: Text(
                  timeStr,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                subtitle: Text(alarm.label.isNotEmpty ? alarm.label : 'Alarm'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: alarm.isActive,
                      onChanged: (val) {
                        ref
                            .read(alarmsProvider.notifier)
                            .toggleAlarm(alarm.id, val);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        ref.read(alarmsProvider.notifier).deleteAlarm(alarm.id);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }

  Future<void> _showAddAlarmDialog(BuildContext context, WidgetRef ref) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      final newAlarm = AlarmRule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        hour: time.hour,
        minute: time.minute,
        label: 'Yeni Alarm', // Basit MVP
      );
      ref.read(alarmsProvider.notifier).saveAlarm(newAlarm);
    }
  }
}
