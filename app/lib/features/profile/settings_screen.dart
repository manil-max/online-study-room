import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animals/camp_animal.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/group_providers.dart';
import '../admin/admin_screen.dart';
import '../clock/clock_widgets_screen.dart';
import '../home/dashboard_providers.dart';
import '../notifications/notification_center_screen.dart';
import '../updater/release_notes_screen.dart';
import 'account_settings_screen.dart';
import 'achievements_screen.dart';
import 'appearance_screen.dart';
import 'widgets/camp_animal_picker.dart';
import 'widgets/report_issue_dialog.dart';

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

  Future<void> _openReportDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => const ReportIssueDialog(),
    );
    if (!mounted || sent != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Geri bildirimin gönderildi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gridDensity = ref.watch(dashboardGridDensityProvider);
    final gridColumns = ref.watch(dashboardGridColumnsProvider);
    final profile = ref.watch(authStateProvider).value;
    final isAdmin = ref.watch(adminIsSuperAdminProvider).value ?? false;
    final animal = profile == null
        ? null
        : campAnimalFor(
            userId: profile.id,
            animalId: _animalOverride ?? profile.animal,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: getSafePadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 24),
        ),
        children: [
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Başarı Yolculuğum 🏆'),
              subtitle: const Text('Rozetlerin, serilerin ve ilerlemen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AchievementsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Hesabımı Yönet'),
              subtitle: const Text('E-posta, şifre ve güvenli çıkış'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.color_lens_outlined),
              title: const Text('Görünüm ve atmosfer temaları'),
              subtitle: const Text(
                'Buzul, ateş, neon, yumuşak… tüm arayüz havası',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppearanceScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: DropdownButtonFormField<DashboardGridDensity>(
                key: ValueKey(gridDensity),
                initialValue: gridDensity,
                decoration: InputDecoration(
                  labelText: 'Izgara yoğunluğu',
                  helperText: 'Bu cihazda $gridColumns sütun kullanılıyor',
                  prefixIcon: const Icon(Icons.grid_view_outlined),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final density in DashboardGridDensity.values)
                    DropdownMenuItem(
                      value: density,
                      child: Text(density.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(dashboardGridDensityProvider.notifier).set(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
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
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Bildirim Merkezi'),
              subtitle: const Text(
                'Dürtme, hatırlatıcı, duyuru ve sessiz saatleri yönet',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationCenterScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Widget ve alarm izinleri'),
              subtitle: const Text(
                'Ana ekran widget’ları · bildirim, kesin alarm, pil, tam ekran',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ClockWidgetsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.new_releases_outlined),
              title: const Text('Sürüm ve güncellemeler'),
              subtitle: const Text('Yenilikleri ve geçmiş sürüm notlarını oku'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReleaseNotesScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _SettingsCard(
            child: ListTile(
              leading: Icon(Icons.shortcut_outlined),
              title: Text('Uygulama Kısayolları (Rutinler)'),
              subtitle: Text(
                'Samsung Modes & Routines veya Tasker ile Odak Başlat, Mola Ver ve Sohbet eylemlerini kullan',
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Geri bildirim gönder'),
              subtitle: const Text('Hata veya önerini bize ilet'),
              trailing: const Icon(Icons.chevron_right),
              onTap: profile == null ? null : _openReportDialog,
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 10),
            _SettingsCard(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Yönetim'),
                subtitle: const Text('Özetler ve kullanıcı raporları'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Card(clipBehavior: Clip.antiAlias, child: child);
}
