import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/nav_index.dart';
import '../../core/time_engine/clock_permissions.dart';
import '../../data/providers/alarm_providers.dart';
import '../android_widgets/published_home_widgets.dart';
import '../android_widgets/widget_deep_link.dart';
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

/// WP-705: bir katalog kartının kullanıcıya söylediği her şey.
///
/// 🔴 Kartlar eskiden **elle sayılıyordu**: gövdede beş ayrı
/// `if (isHomeWidgetPublished(...))` bloğu vardı ve yayın listesi büyüdüğünde
/// kimse onları güncellemedi. WP-695 (geri sayım) ve WP-701 (görev) yayına
/// girdiği hâlde kullanıcı bu katalogda ikisini de hiç görmedi; yalnız
/// Android'in kendi widget seçicisinde bulunabiliyorlardı. Ayrışmayı test
/// etmek yetmez, ayrışmayı **imkânsız** kılmak gerekir: kartlar artık
/// [publishedHomeWidgets] üzerinde dönülerek çizilir ve [homeWidgetCardSpec]
/// enum üzerinde tüketici bir `switch`tir — kataloğa yeni bir sağlayıcı
/// eklendiğinde metin yazılmadan **derleme kırılır**.
@immutable
class HomeWidgetCardSpec {
  const HomeWidgetCardSpec({
    required this.icon,
    required this.title,
    required this.summary,
    required this.route,
    required this.cellWidth,
    required this.cellHeight,
    this.minimumCellWidth,
    this.minimumCellHeight,
    this.directTap = HomeWidgetDirectTap.opensApp,
  });

  final IconData icon;
  final String title;

  /// Widget'ın ne gösterdiği.
  final String summary;

  /// Dokunulduğunda açılan bölüm; `null` ise widget yalnız uygulamayı açar
  /// (belirli bir bölüme gitmez). Vaadin doğruluğu Kotlin sağlayıcısındaki
  /// gerçek `PendingIntent`e karşı ölçülür.
  final WidgetRoute? route;

  /// Route açmayan sağlayıcının gerçek doğrudan dokunma davranışı.
  ///
  /// Mevcut route'lu sağlayıcıların sözleşmesini değiştirmez. Minimal sayaçta
  /// kökün tamamı native broadcast ile başlat/durdur olduğu için `opensApp`
  /// varsayımı doğru değildir.
  final HomeWidgetDirectTap directTap;

  /// `res/xml/odak_*_widget_info.xml` içindeki `targetCellWidth/Height`.
  /// `null` ise o tanımda varsayılan hücre boyutu beyan edilmemiştir ve kart
  /// boyut vaadi etmez.
  final int? cellWidth;
  final int? cellHeight;

  /// `minResizeWidth/Height` ile gerçekten erişilebilen en küçük hücre boyutu.
  /// Null ise katalog alt sınır vaadi üretmez.
  final int? minimumCellWidth;
  final int? minimumCellHeight;
}

enum HomeWidgetDirectTap { opensApp, togglesTimer }

/// Kataloğun **tek** metin kaynağı. `switch` ifadesi enum üzerinde tüketicidir.
@visibleForTesting
HomeWidgetCardSpec homeWidgetCardSpec(
  HomeWidgetProvider provider,
  AppLocalizations l10n,
) => switch (provider) {
  HomeWidgetProvider.timer => HomeWidgetCardSpec(
    icon: Icons.timer,
    title: l10n.clockCalismaSayaci,
    summary: l10n.clockAkanSureBaslatdurdurApp,
    route: WidgetRoute.timer,
    cellWidth: 2,
    cellHeight: 2,
  ),
  HomeWidgetProvider.minimalTimer => HomeWidgetCardSpec(
    icon: Icons.timer_outlined,
    title: l10n.clockMinimalSayac,
    summary: l10n.clockMinimalSayacOzeti,
    route: null,
    directTap: HomeWidgetDirectTap.togglesTimer,
    cellWidth: 2,
    cellHeight: 1,
    minimumCellWidth: 1,
    minimumCellHeight: 1,
  ),
  HomeWidgetProvider.countdown => HomeWidgetCardSpec(
    icon: Icons.event,
    title: l10n.homeSinavGeriSayimi,
    summary: l10n.clockWidgetGeriSayimOzeti,
    route: WidgetRoute.countdown,
    cellWidth: 2,
    cellHeight: 2,
  ),
  // 🔴 `route: null` bilinçli: `TaskWidget.kt` başlığa paketin launcher
  // intent'ini bağlar (`getLaunchIntentForPackage`), `WidgetDeepLink`i
  // kullanmaz. Kart "görev bölümü açılır" deseydi vaat edip yapmamış olurdu.
  HomeWidgetProvider.task => HomeWidgetCardSpec(
    icon: Icons.checklist,
    title: l10n.taskListTitle,
    summary: l10n.clockWidgetGorevOzeti,
    // WP-706: bu satir `null` idi. WP-701 `ROUTE_TASKS` sabitini
    // tanimlamis ama `TaskWidget.kt` icinde hic kullanmamisti; iki ajan
    // da 'bu dosya digerinin SAHIP yolu' diye dokunmayinca is dikiste
    // kaldi. Satirlar toggle olarak KALIR (sahibin birincil istegi:
    // 'yaptiklarini oradan isaretleseler'); gezinme baslik, bos durum
    // metni ve kok dolgu alanindan.
    route: WidgetRoute.tasks,
    cellWidth: 3,
    cellHeight: 2,
  ),
  // 🔴 Kart metni sağlayıcının GERÇEKTE çizdiğini anlatır. Eski kart
  // "İstatistik / Bugün / hafta / seri özeti" diyordu; `StudyStatsWidgetProvider`
  // ise başlığı native `widget_daily_goal` dizesinden alır ve gövdesinde
  // `daily_goal_percent` + `daily_goal_detail` gösterir
  // (`StudyWidgetProviders.kt:495-520`). Seri satırı yalnız TALL boyutta
  // açılır ve hiçbir yerden yazılmaz (`goalsGroup` `statsStreak`i dışarıda
  // bırakır, `AndroidWidgetSnapshot.stats` çağrısı `lib/` içinde yok).
  HomeWidgetProvider.studyStats => HomeWidgetCardSpec(
    icon: Icons.bar_chart,
    title: l10n.profileGunlukHedef,
    summary: l10n.clockWidgetGunlukHedefOzeti,
    route: WidgetRoute.stats,
    cellWidth: 2,
    cellHeight: 2,
  ),
  HomeWidgetProvider.groupGoal => HomeWidgetCardSpec(
    icon: Icons.flag_outlined,
    title: l10n.homeGrupHedefi,
    summary: l10n.clockWidgetGrupHedefiOzeti,
    route: WidgetRoute.group,
    cellWidth: 2,
    cellHeight: 2,
  ),
  HomeWidgetProvider.groupLeaderboard => HomeWidgetCardSpec(
    icon: Icons.emoji_events_outlined,
    title: l10n.homeGrupSiralamasi,
    summary: l10n.clockKampLeaderboardOzeti,
    route: WidgetRoute.group,
    cellWidth: 3,
    cellHeight: 2,
  ),
  HomeWidgetProvider.clock => HomeWidgetCardSpec(
    icon: Icons.schedule,
    title: l10n.clockDijitalSaat,
    summary: l10n.clockCanliSaatTextclockPil,
    route: WidgetRoute.clock,
    cellWidth: 2,
    cellHeight: 2,
  ),
  // Alarm tanımı WP-699 kapsamı dışında bırakıldı: `odak_alarm_widget_info.xml`
  // `targetCell*` beyan etmez, `AlarmWidgetProvider` da hiçbir derin bağlantı
  // kurmaz. İkisi de burada `null` — kart olmayan bir şeyi vaat etmez.
  HomeWidgetProvider.alarm => HomeWidgetCardSpec(
    icon: Icons.alarm,
    title: l10n.clockSiradakiAlarm,
    summary: l10n.clockBirSonrakiAlarmSaati,
    route: null,
    cellWidth: null,
    cellHeight: null,
  ),
};

/// Kartın "dokununca ne olur" satırı.
///
/// Tek yer: kartın çizdiği dize ile testin ölçtüğü dize aynı fonksiyondan
/// gelir; bölümün DOĞRU bölüm olduğunu Kotlin sözleşmesi ölçer
/// (`widget_catalog_wp705_test.dart` → `WidgetDeepLink.ROUTE_*`).
@visibleForTesting
String homeWidgetCardTapLine(HomeWidgetCardSpec spec, AppLocalizations l10n) {
  final route = spec.route;
  if (route != null) {
    return l10n.clockWidgetDokununcaBolum(_routeSectionLabel(route, l10n));
  }
  return switch (spec.directTap) {
    HomeWidgetDirectTap.opensApp => l10n.clockWidgetDokununcaUygulama,
    HomeWidgetDirectTap.togglesTimer =>
      l10n.clockWidgetDokununcaSayaciBaslatDurdur,
  };
}

/// Derin bağlantının açtığı sekmenin kullanıcıya görünen adı.
String _routeSectionLabel(WidgetRoute route, AppLocalizations l10n) =>
    switch (route.tab) {
      AppTab.home => l10n.coreAnaSayfa,
      AppTab.tools => l10n.navTools,
      AppTab.groups => l10n.coreGruplar,
      AppTab.stats => l10n.profileStatsBaslik,
      AppTab.profile => l10n.coreProfil,
    };

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
        //
        // 🔴 WP-705: liste artık `publishedHomeWidgets`ten TÜRETİLİR. Eskiden
        // beş sağlayıcı elle sayılıyordu ve yayın listesi büyüdüğünde iki
        // widget (WP-695 geri sayımı, WP-701 görevleri) katalogda hiç
        // görünmedi. Elle sayım, ayrışmayı zamanla kaçınılmaz kılar.
        if (androidSurfaces)
          for (final provider in publishedHomeWidgets)
            _WidgetCard(
              key: ValueKey<String>('home_widget_card_${provider.name}'),
              spec: homeWidgetCardSpec(provider, AppLocalizations.of(context)),
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
  const _WidgetCard({super.key, required this.spec});

  final HomeWidgetCardSpec spec;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        isThreeLine: true,
        leading: Icon(spec.icon),
        title: Text(
          spec.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(spec.summary),
            const SizedBox(height: 2),
            // Boyut satırı yalnız tanımda `targetCell*` beyan edilmişse
            // çizilir; alarm tanımında yoktur ve olmayan bir varsayılan
            // boyut vaat edilemez.
            if (spec.cellWidth != null && spec.cellHeight != null)
              Text(
                l10n.clockWidgetVarsayilanBoyut(
                  spec.cellWidth!,
                  spec.cellHeight!,
                ),
                style: detailStyle,
              ),
            if (spec.minimumCellWidth != null && spec.minimumCellHeight != null)
              Text(
                l10n.clockWidgetEnKucukBoyut(
                  spec.minimumCellWidth!,
                  spec.minimumCellHeight!,
                ),
                style: detailStyle,
              ),
            Text(homeWidgetCardTapLine(spec, l10n), style: detailStyle),
          ],
        ),
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
