import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_engine/clock_permissions.dart';
import '../../data/providers/alarm_providers.dart';

/// En sol sekme: ana ekran widget'ları + alarm izin durumu.
class ClockWidgetsScreen extends ConsumerStatefulWidget {
  const ClockWidgetsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<ClockWidgetsScreen> createState() => _ClockWidgetsScreenState();
}

class _ClockWidgetsScreenState extends ConsumerState<ClockWidgetsScreen>
    with WidgetsBindingObserver {
  ClockPermissionSnapshot _perms = ClockPermissionSnapshot.ok;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await ClockPermissions.instance.snapshot();
    if (mounted) {
      setState(() {
        _perms = s;
        _loading = false;
      });
    }
    ref.invalidate(exactAlarmStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Ana ekran widget’ları',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Uzun bas → Widget’lar → “Odak Kampı” / “Odak Kampı Beta”',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _WidgetCard(
          icon: Icons.timer,
          title: 'Çalışma sayacı',
          subtitle: 'Akan süre + Başlat/Durdur (app kapalı çalışır)',
        ),
        _WidgetCard(
          icon: Icons.schedule,
          title: 'Dijital saat',
          subtitle: 'Canlı saat (TextClock) — pil dostu',
        ),
        _WidgetCard(
          icon: Icons.alarm,
          title: 'Sıradaki alarm',
          subtitle: 'Bir sonraki alarm saati ve etiketi',
        ),
        _WidgetCard(
          icon: Icons.bar_chart,
          title: 'İstatistik',
          subtitle: 'Bugün / hafta / seri özeti',
        ),
        _WidgetCard(
          icon: Icons.emoji_events_outlined,
          title: 'Grup sıralaması',
          subtitle: 'Kamp leaderboard özeti',
        ),
        const SizedBox(height: 20),
        Text(
          'Alarm için gerekli izinler',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'App kapalıyken alarm çalması için hepsi yeşil olmalı. Android '
          'izinleri güvenlik nedeniyle sistem ayarlarından açılıp kapatılır.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          _PermTile(
            title: 'Bildirimler',
            ok: _perms.notifications,
            detail: 'Android 13+ zorunlu; alarm bildirimi + ses',
            onManage: () async {
              if (!_perms.notifications) {
                await ClockPermissions.instance.requestNotifications();
              }
              await ClockPermissions.instance.openNotificationSettings();
              await _refresh();
            },
          ),
          _PermTile(
            title: 'Kesin alarm (Exact)',
            ok: _perms.exactAlarm,
            detail: 'Android 12+ — saatinde çalsın',
            onManage: () async {
              await ClockPermissions.instance.openExactAlarmSettings();
              await _refresh();
            },
          ),
          _PermTile(
            title: 'Pil kısıtlaması yok',
            ok: _perms.batteryUnrestricted,
            detail: 'OEM arka plan öldürmesin (HyperOS/Samsung önemli)',
            onManage: () async {
              await ClockPermissions.instance
                  .openBatteryOptimizationManagementSettings();
              await _refresh();
            },
          ),
          _PermTile(
            title: 'Tam ekran alarm',
            ok: _perms.fullScreenIntent,
            detail: 'Kilit ekranında alarm yüzeyi',
            onManage: () async {
              await ClockPermissions.instance.openFullScreenSettings();
              await _refresh();
            },
          ),
          const _PermissionRevocationGuide(),
          if (!_perms.allOk) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await ClockPermissions.instance.requestNotifications();
                if (!_perms.exactAlarm) {
                  await ClockPermissions.instance.openExactAlarmSettings();
                }
                if (!_perms.batteryUnrestricted) {
                  await ClockPermissions.instance.openBatterySettings();
                }
                if (!_perms.fullScreenIntent) {
                  await ClockPermissions.instance.openFullScreenSettings();
                }
                await _refresh();
              },
              icon: const Icon(Icons.security),
              label: const Text('Eksik izinleri aç'),
            ),
          ] else
            Card(
              color: theme.colorScheme.primaryContainer,
              child: const ListTile(
                leading: Icon(Icons.check_circle),
                title: Text('Tüm izinler tamam'),
                subtitle: Text('App kapalı alarm için hazır'),
              ),
            ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('İzinleri yenile'),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Widget ve izinler')),
      body: body,
    );
  }
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  const _PermTile({
    required this.title,
    required this.ok,
    required this.detail,
    required this.onManage,
  });

  final String title;
  final bool ok;
  final String detail;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle : Icons.warning_amber_rounded,
          color: ok ? Colors.green : Colors.orange,
        ),
        title: Text(title),
        subtitle: Text(detail),
        trailing: TextButton(
          onPressed: onManage,
          // Android izinleri uygulama tarafından geri alınamaz. İzin zaten
          // verildiyse bu düğme doğrudan ilgili sistem ekranını açar; kullanıcı
          // oradan kapatır. Verilmemişse aynı ekran/istem açma akışına gider.
          child: Text(ok ? 'Kapat' : 'Aç'),
        ),
      ),
    );
  }
}

/// OEM isimleri değişse de kullanıcıyı uygulamadan doğrudan doğru ayara
/// götüren dört izin için kısa geri alma rehberi.
class _PermissionRevocationGuide extends StatelessWidget {
  const _PermissionRevocationGuide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.manage_accounts_outlined),
        title: const Text('İzni geri almak ister misin?'),
        subtitle: const Text('Kapat düğmesi ilgili Android ayarını açar'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            'İzinler güvenlik nedeniyle yalnız Android sistem ayarlarından '
            'kapatılır. Cihaz markasına göre başlıklar biraz değişebilir.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const _PermissionGuideStep(
            title: 'Bildirimleri kapat:',
            body:
                'Açılan uygulama bildirimleri ekranında “Bildirimlere izin ver” anahtarını kapat.',
          ),
          const _PermissionGuideStep(
            title: 'Kesin alarmı kapat:',
            body:
                'Açılan “Alarmlar ve hatırlatıcılar” ekranında Odak Kampı için anahtarı kapat.',
          ),
          const _PermissionGuideStep(
            title: 'Pil istisnasını kaldır:',
            body:
                'Pil optimizasyonu listesinde Odak Kampı’nı bulup “Optimize edilmiş” seçeneğine geri al.',
          ),
          const _PermissionGuideStep(
            title: 'Tam ekran alarmı kapat:',
            body:
                'Açılan tam ekran bildirimler sayfasında Odak Kampı anahtarını kapat. Android 14 öncesinde bu ayar olmayabilir.',
          ),
        ],
      ),
    );
  }
}

class _PermissionGuideStep extends StatelessWidget {
  const _PermissionGuideStep({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(body, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
