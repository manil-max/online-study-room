import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animals/camp_animal.dart';
import '../../core/notifications/notification_preferences.dart';
import '../../core/notifications/nudge_notification_service.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../home/dashboard_providers.dart';
import 'appearance_screen.dart';
import 'widgets/camp_animal_picker.dart';

/// Ayarlar: görünüm, Ana Sayfa davranışı ve gelecek özelleştirme alanları.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Seçim anında (realtime beklemeden) tile'ı güncellemek için optimistik id.
  String? _animalOverride;

  Future<void> _pickAnimal() async {
    final profile = ref.read(authStateProvider).value;
    if (profile == null) return;
    final currentId = _animalOverride ?? profile.animal;
    final shownId = campAnimalFor(userId: profile.id, animalId: currentId).id;

    final picked = await showCampAnimalPicker(context, currentId: shownId);
    if (picked == null || picked == currentId) return;

    await ref.read(authRepositoryProvider).updateAnimal(picked);
    // Sahnenin (grup üyeleri akışının) yeni hayvanı hemen çekmesi için yenile.
    ref.invalidate(groupMembersProvider);
    if (mounted) setState(() => _animalOverride = picked);
  }

  @override
  Widget build(BuildContext context) {
    final showTimerInClass = ref.watch(classroomShowTimerProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final profile = ref.watch(authStateProvider).value;
    final animal = profile == null
        ? null
        : campAnimalFor(
            userId: profile.id,
            animalId: _animalOverride ?? profile.animal,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SettingsGroup(
            icon: Icons.palette_outlined,
            title: 'Görünüm',
            subtitle: 'Tema modu ve renk paleti',
            children: [
              ListTile(
                leading: const Icon(Icons.color_lens_outlined),
                title: const Text('Renk paleti ve tema'),
                subtitle: const Text('Açık, koyu, sistem ve palet seçimi'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppearanceScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            icon: Icons.local_fire_department_outlined,
            title: 'Kamp ateşi',
            subtitle: 'Canlı çalışma ekranındaki görünümün',
            children: [
              ListTile(
                leading: Text(
                  animal?.emoji ?? '🦊',
                  style: const TextStyle(fontSize: 26),
                ),
                title: const Text('Kamp hayvanın'),
                subtitle: Text(
                  animal == null
                      ? 'Seni temsil eden hayvanı seç'
                      : '${animal.label} — dokunup değiştir',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: profile == null ? null : _pickAnimal,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            icon: Icons.dashboard_customize_outlined,
            title: 'Ana Sayfa',
            subtitle: 'Kart görünürlüğü ve düzenleme davranışı',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.timer_outlined),
                title: const Text('Gruplar ekranında da sayaç göster'),
                subtitle: const Text('Sayaç varsayılan Ana Sayfa’dadır.'),
                value: showTimerInClass,
                onChanged: ref.read(classroomShowTimerProvider.notifier).set,
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.restart_alt),
                title: Text('Ana Sayfa düzenini sıfırlama'),
                subtitle: Text(
                  'Kart düzenleme modundaki Sıfırla butonundan yapılır.',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          _SettingsGroup(
            icon: Icons.notifications_outlined,
            title: 'Bildirimler',
            subtitle: 'Dürtme ve hatırlatma tercihleri',
            initiallyExpanded: false,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Dürtme bildirimleri'),
                subtitle: const Text(
                  'Sınıf arkadaşların seni dürttüğünde bildir.',
                ),
                value: notificationPrefs.nudgeNotificationsEnabled,
                onChanged: (value) async {
                  if (value) {
                    await ref
                        .read(nudgeNotificationServiceProvider)
                        .requestPermissionIfNeeded();
                  }
                  await ref
                      .read(notificationPreferencesProvider.notifier)
                      .setNudgeNotificationsEnabled(value);
                },
              ),
              const Divider(height: 1),
              const _DisabledTile(
                icon: Icons.alarm_outlined,
                title: 'Çalışma hatırlatıcıları',
                subtitle: 'Planlanmış hatırlatıcılar sonraki sürümde',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.initiallyExpanded = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        children: children,
      ),
    );
  }
}

class _DisabledTile extends StatelessWidget {
  const _DisabledTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Chip(
        visualDensity: VisualDensity.compact,
        label: Text('Yakında'),
      ),
    );
  }
}
