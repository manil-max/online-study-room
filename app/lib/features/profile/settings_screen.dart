import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/dashboard_providers.dart';
import 'appearance_screen.dart';

/// Ayarlar: görünüm, Ana Sayfa davranışı ve gelecek özelleştirme alanları.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTimerInClass = ref.watch(classroomShowTimerProvider);

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
          const _SettingsGroup(
            icon: Icons.timer_outlined,
            title: 'Sayaç',
            subtitle: 'Zamanlayıcı modları ve odak ayarları',
            initiallyExpanded: false,
            children: [
              _DisabledTile(
                icon: Icons.hourglass_empty_outlined,
                title: 'Geri sayım ve pomodoro',
                subtitle: 'Yakında',
              ),
              Divider(height: 1),
              _DisabledTile(
                icon: Icons.tune_outlined,
                title: 'Sayaç varsayılanları',
                subtitle: 'Yakında',
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _SettingsGroup(
            icon: Icons.notifications_outlined,
            title: 'Bildirimler',
            subtitle: 'Hatırlatıcılar ve zamanlayıcı uyarıları',
            initiallyExpanded: false,
            children: [
              _DisabledTile(
                icon: Icons.notification_important_outlined,
                title: 'Çalışma hatırlatıcıları',
                subtitle: 'Yakında',
              ),
              Divider(height: 1),
              _DisabledTile(
                icon: Icons.alarm_outlined,
                title: 'Zamanlayıcı uyarıları',
                subtitle: 'Yakında',
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
