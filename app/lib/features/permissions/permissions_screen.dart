import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/reminder_notification_service.dart';
import '../../core/time_engine/clock_permissions.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/push_notification_providers.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notification_center_screen.dart';

/// WP-848 (sahip): izinlerin **kendi** ekranı.
///
/// Önceden izin kartı Bildirim Merkezi'nin içindeydi; sayaç ve alarmın
/// çalışması için gereken dört izni arayan kullanıcı onları bildirim
/// ayarlarının arasında buluyordu. Burada her izin tek satırdır: canlı durum,
/// tek eylem ve "yoksa ne bozulur" cümlesi.
///
/// Durum uygulama öne her döndüğünde yeniden okunur — kullanıcı sistem
/// sayfasından geri geldiğinde satır kendiliğinden güncellenir.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  ClockPermissionSnapshot? _snapshot;

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
    final next = await ClockPermissions.instance.snapshot();
    if (mounted) setState(() => _snapshot = next);
  }

  /// Bildirim: izin yoksa önce sistem penceresi. Pencere artık açılmıyorsa
  /// (kullanıcı kalıcı reddetti) izin hâlâ yoktur; o zaman uygulamanın
  /// bildirim ayarı açılır. İzin varsa satır aynı ayara götürür (kapatmak
  /// isteyen için — Android izni uygulama geri alamaz).
  Future<void> _manageNotifications(bool granted) async {
    final permissions = ClockPermissions.instance;
    if (!granted) {
      await ref
          .read(reminderNotificationServiceProvider)
          .requestPermissionIfNeeded();
      final after = await permissions.snapshot();
      if (!after.notifications) await permissions.openNotificationSettings();
      await ref.read(pushHealthProvider.notifier).synchronize(force: true);
    } else {
      await permissions.openNotificationSettings();
    }
    await _refresh();
  }

  Future<void> _run(Future<void> Function() action) async {
    await action();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snapshot = _snapshot;
    final permissions = ClockPermissions.instance;

    final List<Widget> children;
    if (snapshot == null) {
      children = const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (snapshot.availability ==
        ClockPermissionAvailability.unsupported) {
      // Windows/web: sorulacak bir izin yok. Dört gri satır yerine tek cümle.
      children = [
        Text(
          key: const Key('permissions-not-needed'),
          l10n.permissionsNotNeeded,
          style: theme.textTheme.bodyLarge,
        ),
      ];
    } else if (snapshot.availability == ClockPermissionAvailability.unknown) {
      // Kanal okunamadı: "hepsi eksik" demek yalan olurdu.
      children = [
        Text(
          key: const Key('permissions-unknown'),
          l10n.permissionsUnknown,
          style: theme.textTheme.bodyLarge,
        ),
      ];
    } else {
      children = [
        Text(
          l10n.permissionsIntro,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _PermissionRow(
          key: const Key('permission-row-notifications'),
          icon: Icons.notifications_outlined,
          title: l10n.permissionsNotificationsTitle,
          impact: l10n.permissionsNotificationsImpact,
          granted: snapshot.notifications,
          onTap: () => _manageNotifications(snapshot.notifications),
        ),
        // 🔴 WP-901: iOS'ta kesin alarm, pil ve tam ekran izni diye bir şey
        // yok; üç satır da dokununca hiçbir şey yapmayan bozuk düğme olurdu.
        // Geri alma ipucu da "Android ayarı" dediği için iOS'ta çizilmez.
        if (!snapshot.notificationsOnly) ...[
          _PermissionRow(
            key: const Key('permission-row-exact-alarm'),
            icon: Icons.alarm_on_outlined,
            title: l10n.permissionsExactAlarmTitle,
            impact: l10n.permissionsExactAlarmImpact,
            granted: snapshot.exactAlarm,
            onTap: () => _run(permissions.openExactAlarmSettings),
          ),
          _PermissionRow(
            key: const Key('permission-row-battery'),
            icon: Icons.battery_charging_full_outlined,
            title: l10n.permissionsBatteryTitle,
            impact: l10n.permissionsBatteryImpact,
            granted: snapshot.batteryUnrestricted,
            // Eksikken doğrudan "arka planda çalışsın mı?" sistem sorusu;
            // verilmişken kaldırmak için sistemin listesi.
            onTap: () => _run(
              snapshot.batteryUnrestricted
                  ? permissions.openBatteryOptimizationManagementSettings
                  : permissions.openBatterySettings,
            ),
          ),
          _PermissionRow(
            key: const Key('permission-row-full-screen'),
            icon: Icons.fullscreen,
            title: l10n.permissionsFullScreenTitle,
            impact: l10n.permissionsFullScreenImpact,
            granted: snapshot.fullScreenIntent,
            onTap: () => _run(permissions.openFullScreenSettings),
          ),
          // WP-852: Widget sekmesindeki "İzni geri almak ister misin?"
          // rehberinin özü buraya taşındı. O rehber dört ayrı adımda aynı
          // cümleyi ("Kapat düğmesi ilgili Android ayarını açar") tekrarlıyor ve
          // artık var olmayan bir "Kapat" düğmesini anlatıyordu. Buradaki satır
          // izin verilmişken de dokunulabilir ve aynı sistem ayarını açar; tek
          // cümle bunu söylemeye yeter.
          const SizedBox(height: 4),
          Text(
            key: const Key('permissions-revoke-hint'),
            l10n.permissionsRevokeHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.permissionsTitle)),
      // Masaüstü panelinde satır Bildirim Merkezi ile aynı tavanda durur;
      // mobilde bant çocuğu olduğu gibi geçirir.
      body: NotificationDesktopBand(
        child: ListView(
          padding: getSafePadding(
            context,
            const EdgeInsets.fromLTRB(16, 12, 16, 28),
          ),
          children: children,
        ),
      ),
    );
  }
}

/// Tek izin satırı: ne olduğu, yoksa ne bozulduğu, durumu. Dokununca eylem.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.impact,
    required this.granted,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// "Yoksa ne bozulur" cümlesi.
  final String impact;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = granted
        ? l10n.permissionsStatusGranted
        : l10n.permissionsStatusMissing;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: granted ? scheme.primary : scheme.error),
        title: Text(title),
        subtitle: Text(impact),
        // Durum hem ikonla hem kelimeyle — yalnız renk değil (WP-141).
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              granted ? Icons.check_circle : Icons.error_outline,
              size: 18,
              color: granted ? scheme.primary : scheme.error,
            ),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(color: granted ? scheme.primary : scheme.error),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
