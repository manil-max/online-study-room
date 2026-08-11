import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../tabs/admin_announcements_tab.dart';
import '../tabs/admin_audit_log_tab.dart';
import '../tabs/admin_dashboard_tab.dart';
import '../tabs/admin_groups_tab.dart';
import '../tabs/admin_moderation_tab.dart';
import '../tabs/admin_reports_tab.dart';
import '../tabs/admin_users_tab.dart';

/// WP-A (`docs/design/ADMIN-PANEL-PLAN.md` §4.1 / §4.5) — yonetim panelinin
/// kabugu.
///
/// Neyi degistirdi: yedi sekmelik `isScrollable: true` `TabBar` **kalkti**.
/// Yerine uc yuzey geldi (Kuyruk · Kisiler & Gruplar · Kayit & Yayin) ve her
/// yuzey kendi bolumlerini tasiyor. **Hicbir eylem silinmedi** — yedi sekmenin
/// yedisi de bir yuzeyin bir bolumu olarak duruyor
/// (`admin_shell_layout_test.dart` haritayi tek tek olcuyor).
///
/// Sayilar `docs/design/DESKTOP-UI-SPEC.md`ten alindi, turetilmedi:
/// merdiven 640/1008/1200/1600, master 280, bolme araligi 16, ucuncu bolme
/// 320, detay tavani 760.
///
/// 🔴 Bolme karari **KABIN** genisligine gore verilir, `MediaQuery`ye gore
/// degil (`settings_screen.dart` WP-686 dersi). Serit genisligi (52 / 248)
/// karardan sonra dusuldugu icin `DesktopMasterDetail`in kendi esigi burada
/// `0`a alinir: widget kendi kabini yeniden olcerse 1280 px pencerede kalan
/// ~990 pxi gorur, 1200luk varsayilan esigin altinda kalir ve ikinci bolme
/// yazilir ama HIC cizilmezdi.
const Key kAdminShellKey = Key('admin-shell');

/// Yuzey gezinmesi — genis pencerede [NavigationRail], telefonda
/// [NavigationBar]. Ikisi de ayni anahtari tasir ki test "gezinme var mi"
/// sorusunu tek yerden sorabilsin.
const Key kAdminSurfaceNavKey = Key('admin-surface-nav');

/// 1. bolme: yuzeyin bolum listesi (yalniz `large`+).
const Key kAdminMasterPaneKey = Key('admin-master-pane');

/// 2. bolme: secili bolumun govdesi (her genislikte var).
const Key kAdminDetailPaneKey = Key('admin-detail-pane');

/// 3. bolme: baglam sutunu (yalniz `xlarge`). WP-B/C burayi hedefin dosyasi
/// ile dolduracak; WP-A yalniz **yeri ayirir**.
const Key kAdminContextPaneKey = Key('admin-context-pane');

/// Dar penceredeki bolum secici (master bolmesi yokken).
const Key kAdminSectionSelectorKey = Key('admin-section-selector');

const IconData kAdminQueueIcon = Icons.inbox_outlined;
const IconData kAdminDirectoryIcon = Icons.badge_outlined;
const IconData kAdminRecordsIcon = Icons.receipt_long_outlined;

/// SPEC §3 A1.
const double kAdminMasterWidth = 280;
const double kAdminPaneSpacing = 16;
const double kAdminContextPaneWidth = 320;

/// SPEC §1.2 — daraltilmis serit 52, acik serit 248.
const double kAdminRailWidth = 52;
const double kAdminRailExtendedWidth = 248;

/// Bir yuzeyin icindeki tek bolum. [child] eski sekme govdesidir; WP-A
/// govdelere **dokunmaz**, yalnizca yeni kabuktan cagirir.
@immutable
class AdminSection {
  const AdminSection({
    required this.id,
    required this.icon,
    required this.label,
    required this.child,
  });

  final String id;
  final IconData icon;
  final String label;
  final Widget child;
}

/// Uc yuzeyden biri.
@immutable
class AdminSurface {
  const AdminSurface({
    required this.id,
    required this.icon,
    required this.label,
    required this.sections,
  });

  final String id;
  final IconData icon;
  final String label;
  final List<AdminSection> sections;
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _surfaceIndex = 0;

  /// Yuzey basina son secilen bolum. Yuzey degisip geri donunce kullanicinin
  /// birakti yer korunur.
  final Map<String, String> _sectionBySurface = {};

  List<AdminSurface> _surfaces(AppLocalizations l10n) => [
    AdminSurface(
      id: 'queue',
      icon: kAdminQueueIcon,
      label: l10n.adminYuzeyKuyruk,
      sections: [
        // Eski 4. sekme.
        AdminSection(
          id: 'reports',
          icon: Icons.report_outlined,
          label: l10n.adminRaporlar,
          child: const AdminReportsTab(),
        ),
        // Eski 5. sekme. Adi kodda ham `'UGC'` dizesiydi (admin_screen.dart:56)
        // — yerellestirilmemis bir kisaltma. Artik katalogdan geliyor.
        AdminSection(
          id: 'moderation',
          icon: Icons.flag_outlined,
          label: l10n.adminIcerikSikayetleri,
          child: const AdminModerationTab(),
        ),
      ],
    ),
    AdminSurface(
      id: 'directory',
      icon: kAdminDirectoryIcon,
      label: l10n.adminYuzeyKisilerGruplar,
      sections: [
        // Eski 2. sekme.
        AdminSection(
          id: 'users',
          icon: Icons.people_outline,
          label: l10n.adminKullanicilar,
          child: const AdminUsersTab(),
        ),
        // Eski 3. sekme.
        AdminSection(
          id: 'groups',
          icon: Icons.groups_outlined,
          label: l10n.adminGruplar,
          child: const AdminGroupsTab(),
        ),
      ],
    ),
    AdminSurface(
      id: 'records',
      icon: kAdminRecordsIcon,
      label: l10n.adminYuzeyKayitYayin,
      sections: [
        // Eski 1. sekme.
        AdminSection(
          id: 'overview',
          icon: Icons.dashboard_outlined,
          label: l10n.adminOzet,
          child: const AdminDashboardTab(),
        ),
        // Eski 6. sekme — sahip karari: kendi sekmesini kaybetti, yayin
        // yuzeyinin icine girdi (PLAN §6 S2).
        AdminSection(
          id: 'announcements',
          icon: Icons.campaign_outlined,
          label: l10n.adminDuyurular,
          child: const AdminAnnouncementsTab(),
        ),
        // Eski 7. sekme.
        AdminSection(
          id: 'audit',
          icon: Icons.admin_panel_settings_outlined,
          label: l10n.adminDenetim,
          child: const AdminAuditLogTab(),
        ),
      ],
    ),
  ];

  void _selectSurface(int index, int count) {
    if (index < 0 || index >= count) return;
    setState(() => _surfaceIndex = index);
  }

  AdminSection _selectedSection(AdminSurface surface) {
    final id = _sectionBySurface[surface.id];
    return surface.sections.firstWhere(
      (section) => section.id == id,
      orElse: () => surface.sections.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final surfaces = _surfaces(l10n);
    final index = _surfaceIndex.clamp(0, surfaces.length - 1);
    final surface = surfaces[index];

    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < surfaces.length; i++)
          SingleActivator(_digitKeys[i], control: true): () =>
              _selectSurface(i, surfaces.length),
      },
      child: Focus(
        key: kAdminShellKey,
        autofocus: true,
        skipTraversal: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Kap sonsuzsa (kaydirilabilir bir ata) pencereye duseriz; aksi
            // halde olculen sey kaptir.
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final windowClass = DesktopBreakpoints.windowClass(width);
            final railed = width >= DesktopBreakpoints.compact;

            final body = _surfaceBody(context, surface, windowClass);
            return Scaffold(
              appBar: AppBar(title: Text(l10n.adminYonetimPaneli)),
              body: railed
                  ? Row(
                      children: [
                        _rail(
                          context,
                          surfaces,
                          index,
                          extended: width >= DesktopBreakpoints.expanded,
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        Expanded(child: body),
                      ],
                    )
                  : body,
              bottomNavigationBar: railed
                  ? null
                  : _bar(context, surfaces, index),
            );
          },
        ),
      ),
    );
  }

  /// Masaustu gezinmesi. SPEC §1.2: 640–1007 daraltilmis (52), 1008+ acik
  /// (248). Yalniz-ikon hedeflerde `NavigationRail` etiketi kendisi tooltip
  /// olarak verir (SPEC §4 "yalniz-ikon her dugmede Tooltip").
  Widget _rail(
    BuildContext context,
    List<AdminSurface> surfaces,
    int index, {
    required bool extended,
  }) {
    return NavigationRail(
      key: kAdminSurfaceNavKey,
      selectedIndex: index,
      onDestinationSelected: (i) => _selectSurface(i, surfaces.length),
      extended: extended,
      minWidth: kAdminRailWidth,
      minExtendedWidth: kAdminRailExtendedWidth,
      labelType: extended ? null : NavigationRailLabelType.none,
      destinations: [
        for (final surface in surfaces)
          NavigationRailDestination(
            icon: Icon(surface.icon),
            label: Text(surface.label, maxLines: 1),
          ),
      ],
    );
  }

  /// Telefon gezinmesi (<640). PLAN §4.5: uc yuzey alt gezinme cubugunda.
  Widget _bar(BuildContext context, List<AdminSurface> surfaces, int index) {
    return NavigationBar(
      key: kAdminSurfaceNavKey,
      selectedIndex: index,
      onDestinationSelected: (i) => _selectSurface(i, surfaces.length),
      destinations: [
        for (final surface in surfaces)
          NavigationDestination(
            icon: Icon(surface.icon),
            label: surface.label,
            tooltip: surface.label,
          ),
      ],
    );
  }

  Widget _surfaceBody(
    BuildContext context,
    AdminSurface surface,
    DesktopNavigationMode windowClass,
  ) {
    final density = DesktopDensity.of(context);
    final section = _selectedSection(surface);
    final detail = KeyedSubtree(key: kAdminDetailPaneKey, child: section.child);

    final twoPane =
        windowClass == DesktopNavigationMode.large ||
        windowClass == DesktopNavigationMode.xlarge;

    if (!twoPane) {
      // Tek bolme: bolum secici ustte, govde altta. Kaydirmayla kaybolmaz —
      // `Column` + `Expanded` (PLAN §4.6, `Scaffold.bottomSheet` tuzagi).
      return Padding(
        padding: density.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionSelector(context, surface, section),
            SizedBox(height: density.sectionGap),
            Expanded(child: detail),
          ],
        ),
      );
    }

    final cappedDetail = Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        // SPEC §3 A1: detay sutunu "kalan, maks. 760".
        constraints: const BoxConstraints(
          maxWidth: DesktopBreakpoints.maxFormWidth,
        ),
        child: detail,
      ),
    );

    return Padding(
      padding: density.pagePadding,
      child: DesktopMasterDetail(
        masterWidth: kAdminMasterWidth,
        spacing: kAdminPaneSpacing,
        // Karar YUKARIDA verildi; widget kendi kabini yeniden olcmemeli.
        breakpoint: 0,
        master: DesktopSectionList(
          key: kAdminMasterPaneKey,
          items: [
            for (final item in surface.sections)
              DesktopSectionItem(
                id: item.id,
                icon: item.icon,
                label: item.label,
              ),
          ],
          selectedId: section.id,
          onSelected: (id) =>
              setState(() => _sectionBySurface[surface.id] = id),
        ),
        detail: windowClass == DesktopNavigationMode.xlarge
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cappedDetail),
                  const SizedBox(width: kAdminPaneSpacing),
                  SizedBox(
                    key: kAdminContextPaneKey,
                    width: kAdminContextPaneWidth,
                    child: _contextPane(context),
                  ),
                ],
              )
            : cappedDetail,
      ),
    );
  }

  /// 3. bolme — WP-A yalniz **yer ayirir**.
  ///
  /// PLAN §4.2: burasi hedefin dosyasidir (aktif kisit, ceza gecmisi, onceki
  /// sikayetler). Dolduran WP-C; hesap silme kuyrugu WP-E. WP-A'nin isi
  /// sutunun **var oldugunu ve 320 pxi asmadigini** garanti etmek.
  Widget _contextPane(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DesktopContextPanel(
      title: l10n.adminBaglamPaneli,
      child: Text(
        l10n.adminBaglamBosDurum,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _sectionSelector(
    BuildContext context,
    AdminSurface surface,
    AdminSection selected,
  ) {
    return SingleChildScrollView(
      key: kAdminSectionSelectorKey,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final section in surface.sections)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(section.icon, size: 20),
                label: Text(section.label, maxLines: 1),
                selected: section.id == selected.id,
                onSelected: (_) =>
                    setState(() => _sectionBySurface[surface.id] = section.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// `Ctrl+1..3` — PLAN §4.5.
const List<LogicalKeyboardKey> _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
];
