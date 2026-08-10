import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/navigation/nav_index.dart';
import '../../core/tour/tour_controller.dart';
import '../../core/tour/tour_host.dart';
import '../../core/widgets/app_pull_to_refresh.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/study_group.dart';
import '../../data/providers/group_providers.dart';
import '../desktop/desktop_page_scaffold.dart';
import '../home/dashboard_providers.dart';
import '../home/widgets/group_goal_card.dart';
import '../home/widgets/group_trend_card.dart';
import '../home/widgets/leaderboard_card.dart';
import '../tours/app_tours.dart';
import 'widgets/campfire_scene.dart';
import 'widgets/class_chat_screen.dart';
import 'widgets/class_detail_screen.dart';
import 'widgets/group_discovery_screen.dart';
import 'widgets/group_avatar.dart';
import 'widgets/class_switcher.dart';
import 'widgets/study_timer_card.dart';

/// Sınıflar sekmesi: aktif sınıfın canlı ekranı + çoklu sınıf değiştirici.
/// Bkz. project.md §3.0/§3.5/§3.8. Sınıf yoksa oluştur/katıl; varsa sayaç +
/// canlı üye listesi. Başlığa (sınıf adına) dokununca sınıf değiştirici açılır.
class ClassroomScreen extends ConsumerStatefulWidget {
  const ClassroomScreen({super.key});

  @override
  ConsumerState<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends ConsumerState<ClassroomScreen> {
  final _scrollController = ScrollController();
  final _groupsTourAnchor = GlobalKey();
  final _groupSwitcherTourAnchor = GlobalKey();
  final _campfireTourAnchor = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _withIntroductionTours(
    BuildContext context,
    AsyncValue<StudyGroup?> groupAsync,
    Widget child,
  ) {
    if (ref.watch(navIndexProvider) != AppTab.groups.index ||
        groupAsync.asData == null) {
      return child;
    }

    ref.watch(tourControllerProvider);
    final group = groupAsync.asData?.value;
    final l10n = AppLocalizations.of(context);
    final groups = AppTours.groups(
      l10n,
      contentAnchor: _groupsTourAnchor,
      switcherAnchor: _groupSwitcherTourAnchor,
      hasGroup: group != null,
    );
    final definition = groups;

    return TourHost(
      key: ValueKey(definition.storageId),
      definition: definition,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navReselectProvider, (previous, next) {
      if (next.tabIndex != AppTab.groups.index ||
          next.tick <= (previous?.tick ?? 0) ||
          !_scrollController.hasClients ||
          _scrollController.offset <= 0) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
    final groupAsync = ref.watch(userGroupProvider);
    final l10n = AppLocalizations.of(context);
    // 🔴 WP-550: sekme gövdesi `AppPullToRefresh` ile sarıldı. Yükleme ve hata
    // dalları düz `Center`dı — ağaçta kaydırıcı yoktu, jest ölüydü.
    final body = AppPullToRefresh(
      child: groupAsync.when(
        data: (group) => group == null
            ? const _NoGroupView()
            : _GroupView(
                group: group,
                controller: _scrollController,
                campfireKey: _campfireTourAnchor,
                switcherKey: _groupSwitcherTourAnchor,
              ),
        loading: () => const RefreshableBody(
          child: Center(child: CircularProgressIndicator()),
        ),
        // 🔴 WP-550: burası çıkışsız bir duvardı — geçici bir ağ hatasından
        // sonra kullanıcının tek çaresi uygulamayı öldürüp yeniden açmaktı.
        // Kaynak `userGroupsProvider`; `userGroupProvider` ondan türeyen sade
        // bir `Provider` olduğu için onu geçersiz kılmak yeni istek doğurmaz.
        error: (_, _) => RefreshableBody(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.authBeklenmeyenBirHataOlustu,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('classroom-error-retry'),
                    onPressed: () => ref.invalidate(userGroupsProvider),
                    child: Text(l10n.classroomYenile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Windows: sol rail yeter; büyük başlık/sağ panel yok.
    // WP-509: tek eylem olan "grup değiştir" grup adının yanına indi, bu
    // yüzden şeritte gösterilecek gerçek eylem kalmadı ve üst şerit hiç
    // kurulmuyor (`tab_action_bar.dart` sözleşmesi: eylem yoksa çubuk yok).
    //
    // 🔴 Şerit yokken durum çubuğu payını **gövde** devralmak zorunda; aksi
    // hâlde kamp ateşi saat/pil simgelerinin altına girer. Aynı yarım iş ana
    // ekranda WP-493'te hataya dönüşmüştü.
    final page = Scaffold(
      body: SafeArea(
        bottom: false,
        child: KeyedSubtree(key: _groupsTourAnchor, child: body),
      ),
    );
    return _withIntroductionTours(context, groupAsync, page);
  }
}

/// Henüz sınıfı olmayan kullanıcı: oluştur veya koda katıl.
class _NoGroupView extends ConsumerWidget {
  const _NoGroupView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final padding = getSafeVerticalPadding(
      context,
      horizontal: 24,
      vertical: 24,
    );
    // 🔴 WP-541 (yayın engeli): burada eskiden `Center` + `Column` vardı, yani
    // ekranda **hiç kaydırıcı yoktu**. Sistem yazı boyutunu büyütmüş kullanıcıda
    // içerik viewport'u aşıyor, "Koda katıl" ve "Grupları keşfet" ekran dışında
    // kalıyor ve kaydırılamıyordu. Ölçüm (360x720, textScale 2.0): Create
    // [324..570] görünür, Join [682..762] ekran dışı, Discover [770..850] ekran
    // dışı, `Scrollable` sayısı 0. Davet kodu almış yeni kullanıcı bu yüzden
    // uygulamaya hiç giremiyordu.
    //
    // Çözüm: sığdığında ortalanır (görünüm aynı kalır), sığmadığında kayar.
    // `minHeight` viewport kadar olduğu için `MainAxisAlignment.center` kısa
    // içerikte hâlâ dikey ortalar.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? (constraints.maxHeight - padding.vertical).clamp(
                    0.0,
                    double.infinity,
                  )
                : 0.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).classroomHenuzBirGruptaDegilsin,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).classroomYeniBirGrupOlustur,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => createGroupFlow(context, ref),
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context).classroomGrupOlustur),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => joinGroupFlow(context, ref),
                icon: const Icon(Icons.login),
                label: Text(AppLocalizations.of(context).classroomKodaKatil),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GroupDiscoveryScreen(),
                  ),
                ),
                icon: const Icon(Icons.travel_explore),
                label: Text(AppLocalizations.of(context).groupDiscoveryAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kullanıcının sınıfı: ad, davet kodu ve üyeler.
/// WP-172: sabit ListView — kartlar nested scroll kullanmaz (unbounded yükseklik);
/// Home dashboard sürükle-bırak burada YOK.
class _GroupView extends ConsumerWidget {
  const _GroupView({
    required this.group,
    required this.controller,
    required this.campfireKey,
    required this.switcherKey,
  });

  final StudyGroup group;
  final ScrollController controller;
  final Key campfireKey;

  /// Gruplar tanıtım turunun "grup değiştir" adımının hedefi (`AppTours.groups`).
  /// Çapa düğmeyle birlikte taşınır; taşınmazsa balon hedefsiz açılır.
  final Key switcherKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sayaç varsayılan olarak Ana Sayfa'dadır; isteyen Sınıflar'a ekler (§3.9).
    final showTimer = ref.watch(classroomShowTimerProvider);

    // Sıra (KALITE-PROGRAMI §8.3 Gruplar): kamp ateşi → hedef → sıralama → trend.
    //
    // 🔴 WP-675: masaüstü kolu AYRI bir ağaç. Mobil dal aşağıda birebir korunur
    // (SPEC §7: "mobil branch değişmez"); masaüstü kolu SPEC §3 A4 + A2'yi
    // uygular. Aynı ağacı `isDesktopWindow` bayraklarıyla delik deşik etmek
    // yerine iki kol ayrıldı: mobil regresyon iddiası böylece tek bir "bu dal hiç
    // çalışmadı" kontrolüne iner.
    if (isDesktopWindow) {
      return _DesktopGroupView(
        group: group,
        controller: controller,
        campfireKey: campfireKey,
        switcherKey: switcherKey,
        showTimer: showTimer,
      );
    }

    return ListView(
      controller: controller,
      // Kartlar üzerindeki jestler de dikey kaydırmaya gitsin.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: getSafeVerticalPadding(context, horizontal: 16, vertical: 16),
      children: [
        if (showTimer) ...[const StudyTimerCard(), const SizedBox(height: 8)],
        _CompactGroupHeader(group: group, switcherKey: switcherKey),
        const SizedBox(height: 8),
        CampfireScene(key: campfireKey),
        const SizedBox(height: 16),
        const GroupGoalCard(),
        const SizedBox(height: 16),
        const LeaderboardCard(),
        const SizedBox(height: 16),
        const GroupTrendCard(),
        // Alt menü için nefes payı
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Masaüstünde tek bir grup bloğunun (kartının) genişlik tavanı.
///
/// 🔴 Uydurma değil, türetildi. SPEC KURAL 2.2 bir etiket–değer satırının
/// **sert tavanını 600 px** koyar (80 karakter × 7.5 px; WCAG 2.1 SC 1.4.8).
/// Bu üç kartın iç dolgusu 16 + 16 = 32 px (`group_goal_card.dart`,
/// `leaderboard_card.dart`), yani 600 px'lik bir satırın sığdığı en geniş kart
/// 632 px'tir. 632, 4'ün katıdır (WinUI ölçek platosu kuralı, SPEC §1.2).
///
/// Ölçülen kusur (WP-671 kapısı, 2560×1440): kart **2352 px**, içindeki en
/// geniş metin **178 px** → 2174 px ölü alan.
const double kGroupBlockMaxWidth = 632;

/// Izgara oluğu. SPEC §4: 640 px üstü pencerelerde **24 epx** (Fluent 2 Layout).
const double kGroupGridGutter = 24;

/// 🔴 WP-675 — gruplar / kamp ateşi sekmesinin masaüstü düzeni.
///
/// Sahip v64 Windows sürümünü reddetti: *"dikey mobil uygulama için tasarlanan
/// arayüzler yatay pc ekranında çok kötü duruyor."* Bu ekranda ölçüldü
/// (WP-671 kapısı): 1920'de 12 ihlal / içerik 1706 px, 2560'ta 12 ihlal /
/// içerik 2346 px ve en geniş etiket–değer satırı **2328 px**
/// ("Grup günlük trendi" → "0sn", arası 1989 px boşluk).
///
/// Düzen `docs/design/DESKTOP-UI-SPEC.md`'den:
///   * **kamp ateşi = A4 (görsel sahne)** — içerik bandının tamamını kaplar,
///     daraltılmaz. Sahip sahneyi zaten beğeniyor; kart tavanları buraya
///     UYGULANMAZ.
///   * **sahnenin altındaki bloklar = A2 (pano)** — akıcı ızgara
///     ([_GroupBlockGrid]), blok genişliği [kGroupBlockMaxWidth] ile tavanlanır.
///   * bant = [DesktopBreakpoints.maxContentWidth] (1440), SPEC §2.3.
///
/// **İşlev değişmedi** (SPEC §7): aynı bloklar, aynı sırada, aynı sağlayıcılar
/// — grup değiştir / sohbet / ayarlar kısayolları, kamp ateşi varlık göstergesi
/// ve dürtme dahil hiçbir şey kaldırılmadı; yalnız `build()` ağacının şekli
/// değişti.
class _DesktopGroupView extends StatelessWidget {
  const _DesktopGroupView({
    required this.group,
    required this.controller,
    required this.campfireKey,
    required this.switcherKey,
    required this.showTimer,
  });

  final StudyGroup group;
  final ScrollController controller;
  final Key campfireKey;
  final Key switcherKey;
  final bool showTimer;

  @override
  Widget build(BuildContext context) {
    final density = DesktopDensity.of(context);
    return ListView(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // Kenar boşluğu artık `DesktopContent`in İÇİNDE: bant ortalanır, dolgu
      // bandın içinde kalır. Dolgu dışarıda kalsaydı 2560 px'lik pencerede
      // 24 px'lik kenar boşluğunun hiçbir anlamı olmazdı.
      padding: EdgeInsets.zero,
      children: [
        // SPEC §6 "BAĞLA, ATMA": `DesktopContent` yazılmıştı ama `lib/` içinde
        // tek bir çağrı yeri yoktu. Bant sınırı artık buradan geliyor.
        DesktopContent(
          maxWidth: DesktopBreakpoints.maxContentWidth,
          padding: density.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTimer) ...[
                // Sayaç kartı da bir A2 bloğudur: 1392 px'lik banda yayılırsa
                // aynı "dev kutu, tek sayı" kusuru geri gelir.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kGroupBlockMaxWidth,
                    ),
                    child: const StudyTimerCard(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _CompactGroupHeader(group: group, switcherKey: switcherKey),
              const SizedBox(height: 8),
              // A4 — sahne bandın tamamını alır (SPEC §3 A4: "genişledikçe
              // bozulmaz"). Sahne geometrisi ellenmez.
              CampfireScene(key: campfireKey),
              const SizedBox(height: 16),
              const _GroupBlockGrid(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sahnenin altındaki A2 panosu: hedef + sıralama + trend.
///
/// Sütun sayısı SPEC §1.2 merdiveninden, ama **gerçekte kalan banda** göre
/// (pencere genişliğine göre değil): pencere 1920 olsa da sol şerit ve kenar
/// boşluğu düştükten sonra karar verilecek genişlik 1392 px'tir.
class _GroupBlockGrid extends StatelessWidget {
  const _GroupBlockGrid();

  /// SPEC §1.2: `large` (1200+) iki pane, `xlarge` üç. Bloklar tek sayılık
  /// döşeme değil dolu kartlar olduğu için tavan 3 sütundur.
  static int columnsFor(double band) {
    if (band >= DesktopBreakpoints.large) return 3;
    if (band >= DesktopBreakpoints.expanded) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final band = constraints.maxWidth;
        final columns = columnsFor(band);
        final even = (band - kGroupGridGutter * (columns - 1)) / columns;
        final width = even < kGroupBlockMaxWidth ? even : kGroupBlockMaxWidth;
        // 🔴 `Row` DEĞİL `Wrap`. İki sebep, ikisi de ölçülmüş:
        //   1. `Row` yatay bir `RenderFlex` yaratır ve KOMŞU kartların kendi
        //      içlerinde bir satıra bağlı olmayan metinleri o Flex'in altında
        //      **aynı görsel satır** sayılır — WP-671 sondası etiket–değer
        //      çiftlerini tam olarak böyle bulur. Kartlar yan yana dizilirken
        //      bir kartın etiketiyle ötekinin değeri 1392 px'lik sahte bir
        //      satır üretirdi. `RenderWrap` bir `RenderFlex` DEĞİLDİR; bu sahte
        //      eşleşme yapısal olarak olamaz.
        //   2. Sütuna sığmayan blok alt sıraya akar; sabit sütun sayısı
        //      taşırmaz (`personal_stats_view` 2×2 hatası tekrarlanmaz).
        return Wrap(
          spacing: kGroupGridGutter,
          runSpacing: kGroupGridGutter,
          children: [
            for (final block in const <Widget>[
              GroupGoalCard(),
              LeaderboardCard(),
              GroupTrendCard(),
            ])
              SizedBox(width: width, child: block),
          ],
        );
      },
    );
  }
}

/// Kamp ateşinin üstünde yalnız tek satır kaplayan kompakt başlık: grup adı +
/// sohbet/ayarlar kısayolları. Davet kodu bu ekranda hiç görünmez.
///
/// WP-446: kod eskiden hem burada (`_GroupManagementTile`) hem de
/// `ClassDetailScreen` → Bilgiler kartında duruyordu. İki kopya aynı değildi:
/// alttaki yalnız kopyalayabiliyor, detaydaki ayrıca **kodu yenileyebiliyordu**.
/// Tek kanonik yer artık detay ekranı; ayarlar simgesi zaten oraya götürüyor.
class _CompactGroupHeader extends ConsumerWidget {
  const _CompactGroupHeader({required this.group, required this.switcherKey});

  final StudyGroup group;
  final Key switcherKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      children: [
        GroupAvatar(
          name: group.name,
          avatarPath: group.avatarPath,
          avatarUpdatedAt: group.avatarUpdatedAt,
          radius: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            group.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Menü basılan düğmeye göre konumlanır, bu yüzden `showClassSwitcher`
        // düğmenin **kendi** context'ini almalı (`class_switcher.dart`).
        Builder(
          builder: (iconContext) => _HeaderAction(
            key: switcherKey,
            tooltip: AppLocalizations.of(context).classroomGrupDegistir,
            icon: Icons.swap_horiz,
            onPressed: () => showClassSwitcher(iconContext, ref),
          ),
        ),
        _HeaderAction(
          tooltip: AppLocalizations.of(context).classroomSohbet,
          icon: Icons.forum_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClassChatScreen(group: group)),
          ),
        ),
        _HeaderAction(
          tooltip: AppLocalizations.of(context).classroomAyarlar,
          icon: Icons.settings_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClassDetailScreen(group: group)),
          ),
        ),
      ],
    );
  }
}

/// Grup başlığındaki tek eylem düğmesi.
///
/// 🔴 WP-509: varsayılan `IconButton` yatayda 48 dp ister; üçü birden
/// ~144 dp yiyor ve 360 dp'lik telefonda grup adına avatar/boşluk düşdükten
/// sonra ~130 dp kalıyor — uzun ad tek kelimeye iniyordu. Yuva yatayda
/// [kHeaderActionWidth] dp'ye çekildi (üçü 120 dp).
///
/// Dokunma hedefinin **dikey** boyutu 48 dp olarak korunur (erişilebilirlik
/// alt sınırı); daralan yalnız yatay ayak izidir. Aynı takas üye satırında
/// WP-498'de yapıldı (`class_detail_screen.dart` `_MemberActionSlot`).
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    // 🔴 Ölçüldü, tahmin değil: `IconButton`ın ButtonStyle'ı 48×48 dp
    // `minimumSize` taşır ve **`constraints` tek başına onu küçültmez** (48 dp
    // kaldı). `visualDensity: VisualDensity.compact` küçültüyor ama iki eksende
    // birden — dokunma hedefi 40 dp'ye düşüyordu, erişilebilirlik alt sınırı
    // kırılır. Yalnız **yatay** daralma için dış kutu daraltılır; aynı çözüm
    // üye satırında WP-498'de kullanıldı (`_MemberActionSlot`).
    width: kHeaderActionWidth,
    child: IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minHeight: kHeaderActionHeight),
      onPressed: onPressed,
    ),
  );
}

/// Başlık eylem düğmesinin yatay ayak izi (WP-509). Testler bu sabiti okur.
const double kHeaderActionWidth = 40;

/// Dokunma hedefinin dikey alt sınırı; erişilebilirlik gereği küçültülmez.
const double kHeaderActionHeight = 48;
