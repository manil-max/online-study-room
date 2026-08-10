import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_engine/clock_permissions.dart';
import '../../data/providers/alarm_providers.dart';
import '../android_widgets/published_home_widgets.dart';
import 'platform_limit_banner.dart';

/// 🔴 WP-687: bu ekranın **iki yarısı da** Android'e özgüdür, ama ekran
/// Windows'ta da açılıyor — Bildirim Merkezi'nin ikinci sekmesi
/// (`notification_permissions_screen.dart:122`).
///
///  * Ana ekran widget kataloğu: Windows'ta ana ekran widget'ı diye bir şey
///    yok; `androidWidgetServiceProvider` bu platformda `_Noop` döner
///    (`android_widget_service.dart:23-28`). Kart kullanıcıya kurulamayacak
///    bir widget vaat ediyordu — WP-461'in dormant widget'lar için verdiği
///    kararın aynısı burada platform için geçerli.
///  * Dört izin satırı: `ClockPermissions`ın her `open*Settings()` metodu
///    `if (!_android) return;` ile erkenden dönüyor
///    (`clock_permissions.dart:152-188`). "Aç" düğmesi basılıyor, hiçbir şey
///    olmuyor, sebebi de söylenmiyordu — WP-611'in adını koyduğu **bozuk
///    düğme**. Düğmeler artık devre dışı, sınır da şeritte yazılı.
///
/// Platform `defaultTargetPlatform` üzerinden okunur (`dart:io Platform`
/// değil): testte `debugDefaultTargetPlatformOverride` ile enjekte edilebilir.
bool get _androidSurfacesAvailable =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
    final androidSurfaces = _androidSurfacesAvailable;
    // 🔴 WP-688: masaüstünde katalog hiç çizilmiyor (WP-687), yani Android
    // başlığı "Widget ve izinler" var olmayan bir yüzeyi vaat ediyordu.
    // Masaüstü başlığı ekranda gerçekten duran şeyi adlandırır: Android
    // izinlerinin BİLGİsi. Aynı dize hem AppBar'da hem gövdenin ilk
    // satırında kullanılır — biri düzeltilip diğeri unutulmasın diye tek yer.
    final screenTitle = androidSurfaces
        ? AppLocalizations.of(context).clockWidgetVeIzinler
        : AppLocalizations.of(context).clockMasaustuAndroidIzinBilgisi;
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // `severe: false`: masaüstünde kullanıcı bir şey kurup boşuna
        // beklemiyor (alarmda öyleydi) — sunulan hiçbir şey yok. Bilgi tonu
        // doğru ton; kırmızı şerit burada yanlış alarm olurdu.
        //
        // 🔴 WP-688: metin artık ödünç değil. WP-687 en yakın dizeyi
        // (`notificationsIzinMasaustundeGecersiz`) kullanmıştı çünkü `.arb`
        // onun SAHİP yollarında değildi; o cümle yalnız bildirim izninden söz
        // ediyor, ekranın **öteki yarısı** olan ana ekran widget kataloğunu
        // hiç anmıyordu. Yeni anahtar ikisini birden söyler.
        if (!androidSurfaces) ...[
          PlatformLimitBanner(
            key: const Key('clock_widgets_desktop_limit_banner'),
            message: AppLocalizations.of(context).clockMasaustuWidgetVeIzinYok,
          ),
          const SizedBox(height: 12),
        ],
        Text(
          screenTitle,
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
        // WP-461: Katalog yalnız **yayındaki** widget'ı gösterir. Dormant
        // olanların kartı çizilmez; aksi hâlde kullanıcıya picker'da
        // bulunmayan bir widget vaat edilirdi.
        if (androidSurfaces && isHomeWidgetPublished(HomeWidgetProvider.timer))
          _WidgetCard(
            icon: Icons.timer,
            title: AppLocalizations.of(context).clockCalismaSayaci,
            subtitle: AppLocalizations.of(context).clockAkanSureBaslatdurdurApp,
          ),
        if (androidSurfaces && isHomeWidgetPublished(HomeWidgetProvider.clock))
          _WidgetCard(
            icon: Icons.schedule,
            title: AppLocalizations.of(context).clockDijitalSaat,
            subtitle: AppLocalizations.of(context).clockCanliSaatTextclockPil,
          ),
        if (androidSurfaces && isHomeWidgetPublished(HomeWidgetProvider.alarm))
          _WidgetCard(
            icon: Icons.alarm,
            title: AppLocalizations.of(context).clockSiradakiAlarm,
            subtitle: AppLocalizations.of(context).clockBirSonrakiAlarmSaati,
          ),
        if (androidSurfaces &&
            isHomeWidgetPublished(HomeWidgetProvider.studyStats))
          _WidgetCard(
            icon: Icons.bar_chart,
            title: AppLocalizations.of(context).statsIstatistik,
            subtitle: AppLocalizations.of(context).clockBugunHaftaSeriOzeti,
          ),
        if (androidSurfaces &&
            isHomeWidgetPublished(HomeWidgetProvider.groupLeaderboard))
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
          _PermissionStatusSummary(snapshot: _perms),
          const SizedBox(height: 8),
          _PermTile(
            enabled: androidSurfaces,
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
            enabled: androidSurfaces,
            title: AppLocalizations.of(context).clockKesinAlarmExact,
            ok: _perms.exactAlarm,
            detail: AppLocalizations.of(context).clockKesinAlarmIzniKapali,
            onManage: () async {
              await ClockPermissions.instance.openExactAlarmSettings();
              await _refresh();
            },
          ),
          _PermTile(
            enabled: androidSurfaces,
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
            enabled: androidSurfaces,
            title: AppLocalizations.of(context).coreTamEkranAlarm,
            ok: _perms.fullScreenIntent,
            detail: AppLocalizations.of(context).clockKilitEkranindaAlarmYuzeyi,
            onManage: () async {
              await ClockPermissions.instance.openFullScreenSettings();
              await _refresh();
            },
          ),
          const _PermissionRevocationGuide(),
          if (_perms.availability == ClockPermissionAvailability.available &&
              !_perms.allOk) ...[
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
          ] else if (_perms.allOk)
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
        // 🔴 WP-688: masaüstünde bu düğme **kaldırılır**, devre dışı
        // bırakılmaz. Dört izin satırı bilgi taşır (Android'de hangi izin
        // gerekiyor), o yüzden onlar gri düğmeyle yerinde durur — ama bu
        // düğme yalnız EYLEMDEN ibarettir ve eylemi bu platformda hiçbir
        // zaman bir şey değiştiremez: `snapshot()` `Platform.isAndroid ==
        // false` iken kanala hiç gitmeden `unsupported` döner
        // (`clock_permissions.dart:127`). Devre dışı gri bir düğme
        // "şimdilik olmuyor" der; doğrusu "bu platformda böyle bir şey yok"
        // ve o cümle zaten şeritte yazılı.
        if (androidSurfaces) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).clockIzinleriYenile),
          ),
        ],
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      body: body,
    );
  }
}

class _PermissionStatusSummary extends StatelessWidget {
  const _PermissionStatusSummary({required this.snapshot});

  final ClockPermissionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isAvailable =
        snapshot.availability == ClockPermissionAvailability.available;
    final isUnknown =
        snapshot.availability == ClockPermissionAvailability.unknown;
    // WP-296: `unsupported` (masaüstü/web) kendi dalını alır. Öncesinde bu durum
    // "eksik izin" dalına düşüyordu: Windows'ta kart kırmızı görünüp "4 Eksik
    // izinleri aç" diyordu — o platformda var olmayan izinler için yanlış bir
    // iddia. Alt satır da ekranın başlığındaki cümleyi (`:107`) aynen tekrar
    // ediyordu. Aynı dosyadaki "eksikleri aç" düğmesi (`:161`) zaten yalnız
    // `available` durumunda çiziliyor; kart artık onunla tutarlı.
    final isUnsupported =
        snapshot.availability == ClockPermissionAvailability.unsupported;
    final allOk = snapshot.allOk;
    final color = allOk
        ? theme.colorScheme.primaryContainer
        : isUnsupported
        ? theme.colorScheme.surfaceContainerHighest
        : isUnknown
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.errorContainer;
    final title = allOk
        ? l10n.clockTumIzinlerTamam
        : isUnsupported
        ? l10n.clockIzinlerYalnizAndroid
        : isUnknown
        ? l10n.clockIzinleriYenile
        : '${snapshot.missingCount} ${l10n.clockEksikIzinleriAc}';
    final String? subtitle = allOk
        ? l10n.clockAppKapaliAlarmIcin
        : isUnsupported
        ? null
        : isAvailable
        ? l10n.clockEksikIzinleriAc
        : l10n.clockIzinlerGuvenlikNedeniyleYalniz;
    return Card(
      color: color,
      child: ListTile(
        leading: Icon(
          allOk
              ? Icons.check_circle
              : isUnsupported
              ? Icons.info_outline
              : isUnknown
              ? Icons.help_outline
              : Icons.warning_amber_rounded,
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
      ),
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
    required this.enabled,
  });

  final String title;
  final bool ok;
  final String detail;
  final VoidCallback onManage;

  /// 🔴 WP-687: `false` → bu platformda [ClockPermissions] hiçbir sistem
  /// ekranı açamaz (`clock_permissions.dart:152-188` erkenden döner). Satır
  /// bilgi olarak durur, düğme **basılamaz**; sebebi ekranın başındaki
  /// `PlatformLimitBanner`da yazılıdır.
  final bool enabled;

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
          onPressed: enabled ? onManage : null,
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
