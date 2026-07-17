import 'package:online_study_room/l10n/app_localizations.dart';
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
          AppLocalizations.of(context).clockWidgetVeIzinler,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context).desktopOdakKampi,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _WidgetCard(
          icon: Icons.timer,
          title: AppLocalizations.of(context).clockCalismaSayaci,
          subtitle: AppLocalizations.of(context).clockAkanSureBaslatdurdurApp,
        ),
        _WidgetCard(
          icon: Icons.schedule,
          title: AppLocalizations.of(context).clockDijitalSaat,
          subtitle: AppLocalizations.of(context).clockCanliSaatTextclockPil,
        ),
        _WidgetCard(
          icon: Icons.alarm,
          title: AppLocalizations.of(context).clockSiradakiAlarm,
          subtitle: AppLocalizations.of(context).clockBirSonrakiAlarmSaati,
        ),
        _WidgetCard(
          icon: Icons.bar_chart,
          title: AppLocalizations.of(context).statsIstatistik,
          subtitle: AppLocalizations.of(context).clockBugunHaftaSeriOzeti,
        ),
        _WidgetCard(
          icon: Icons.emoji_events_outlined,
          title: AppLocalizations.of(context).homeGrupSiralamasi,
          subtitle: AppLocalizations.of(context).clockKampLeaderboardOzeti,
        ),
        const SizedBox(height: 20),
        Text(
          AppLocalizations.of(context).clockAlarmIcinGerekliIzinler,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${AppLocalizations.of(context).clockAppKapaliykenAlarmCalmasi} '
          '${AppLocalizations.of(context).clockIzinlerGuvenlikNedeniyleYalniz}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          _PermTile(
            title: AppLocalizations.of(context).clockBildirimler,
            ok: _perms.notifications,
            detail: AppLocalizations.of(
              context,
            ).clockSaatUygulamasiKalitesiIcin,
            onManage: () async {
              if (!_perms.notifications) {
                await ClockPermissions.instance.requestNotifications();
              }
              await ClockPermissions.instance.openNotificationSettings();
              await _refresh();
            },
          ),
          _PermTile(
            title: AppLocalizations.of(context).clockKesinAlarmExact,
            ok: _perms.exactAlarm,
            detail: AppLocalizations.of(context).clockKesinAlarmIzniKapali,
            onManage: () async {
              await ClockPermissions.instance.openExactAlarmSettings();
              await _refresh();
            },
          ),
          _PermTile(
            title: AppLocalizations.of(context).clockPilKisitlamasiYok,
            ok: _perms.batteryUnrestricted,
            detail: AppLocalizations.of(context).clockPilKisitlamasiYok,
            onManage: () async {
              await ClockPermissions.instance
                  .openBatteryOptimizationManagementSettings();
              await _refresh();
            },
          ),
          _PermTile(
            title: AppLocalizations.of(context).coreTamEkranAlarm,
            ok: _perms.fullScreenIntent,
            detail: AppLocalizations.of(context).clockKilitEkranindaAlarmYuzeyi,
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
              label: Text(AppLocalizations.of(context).clockEksikIzinleriAc),
            ),
          ] else
            Card(
              color: theme.colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(AppLocalizations.of(context).clockTumIzinlerTamam),
                subtitle: Text(
                  AppLocalizations.of(context).clockAppKapaliAlarmIcin,
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: Text(AppLocalizations.of(context).clockIzinleriYenile),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).clockWidgetVeIzinler),
      ),
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
          // WP-141: palette bağlama; durum hem ikon hem renk ile (yalnız renk değil).
          color: ok
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.tertiary,
          semanticLabel: title,
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(detail, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: TextButton(
          onPressed: onManage,
          // Android izinleri uygulama tarafından geri alınamaz. İzin zaten
          // verildiyse bu düğme doğrudan ilgili sistem ekranını açar; kullanıcı
          // oradan kapatır. Verilmemişse aynı ekran/istem açma akışına gider.
          child: Text(
            ok
                ? AppLocalizations.of(context).homeKapat
                : AppLocalizations.of(context).clockAc,
          ),
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
        title: Text(AppLocalizations.of(context).clockIzniGeriAlmakIster),
        subtitle: Text(
          AppLocalizations.of(context).clockKapatDugmesiIlgiliAndroid,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            AppLocalizations.of(context).clockIzinlerGuvenlikNedeniyleYalniz,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _PermissionGuideStep(
            title: AppLocalizations.of(context).clockBildirimleriKapat,
            body: AppLocalizations.of(context).clockKapatDugmesiIlgiliAndroid,
          ),
          _PermissionGuideStep(
            title: AppLocalizations.of(context).clockKesinAlarmiKapat,
            body: AppLocalizations.of(context).clockKapatDugmesiIlgiliAndroid,
          ),
          _PermissionGuideStep(
            title: AppLocalizations.of(context).clockPilIstisnasiniKaldir,
            body: AppLocalizations.of(context).clockKapatDugmesiIlgiliAndroid,
          ),
          _PermissionGuideStep(
            title: AppLocalizations.of(context).clockTamEkranAlarmiKapat,
            body: AppLocalizations.of(context).clockAcilanTamEkranBildirimler,
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
