import 'package:online_study_room/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/timer_notification_service.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/anchored_menu.dart';
import '../../../data/models/goal_streak.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../../home/dashboard_card.dart';
import '../../home/widgets/card_scaffold.dart';
import '../../profile/session_history_screen.dart';
import '../../profile/subjects_screen.dart';
import '../../profile/widgets/goal_editor_dialog.dart';
import '../../profile/widgets/manual_session_dialog.dart';
import '../../stats/widgets/goal_streak_flame.dart';
import 'clock_style.dart';
import 'focus_timer_screen.dart';
import 'timer_mode_controls.dart';

/// Material'in asgari dokunma hedefi. **Alt sınır, hedef değil.**
///
/// 🔴 WP-662: bu sabit, WP-659'da konan `clamp(32, 48)`in yerine geçti. O clamp
/// dar hücrede düğmeyi 36.7 px'e indiriyordu; ölçülen bir erişilebilirlik
/// kusurudur, "biraz küçük" değil. Sığmayan aksiyon **küçültülmez**, taşma
/// menüsüne alınır.
const double kMinTouchTarget = 48.0;

/// Bu yüksekliğin altındaki hücrede yalnız kartın **çekirdeği** çizilir:
/// geçen süre + birincil eylem (Başlat/Durdur).
///
/// Ölçüldü (`timer_card_density_wp662_test.dart`): çekirdek düzen 160 px'lik
/// hücreye ~0 px kaydırma payıyla oturur; ikincil satırlar eklendiğinde aynı
/// hücrede 433 px kart-içi kaydırma çıkıyordu.
const double kTimerCoreMaxHeight = 240.0;

/// Bu yüksekliğin altında ikincil satırlar (mod seçici, günlük hedef çubuğu,
/// ders seçici hapı, manuel süre ekle) gizlenir; üstünde tam kart çizilir.
const double kTimerFullMinHeight = 400.0;

/// Çalışma sayacı kartı: bugünkü toplam + canlı süre + başlat/durdur.
/// Her saniye yeniden çizmek için kendi periyodik zamanlayıcısı vardır.
/// [size] dar alana (küçük kart) uyum için: küçükken saat/yazılar küçülür.
class StudyTimerCard extends ConsumerStatefulWidget {
  const StudyTimerCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  ConsumerState<StudyTimerCard> createState() => _StudyTimerCardState();
}

class _StudyTimerCardState extends ConsumerState<StudyTimerCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Idle'da saniyelik setState yok (Windows IndexedStack + ölçek altında jank).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTicker(ref.read(studyTimerProvider).isRunning);
    });
  }

  void _syncTicker(bool isRunning) {
    if (isRunning) {
      if (_ticker != null) return;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      return;
    }
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Faz geçişi/bitişinde geri bildirim: ses + titreşim + (ekran öndeyse) uyarı.
  /// Kalıcı bildirim §5'e ait; burada yalnız uygulama-içi tetik (state machine
  /// olayı dışarı veriyor, UI tepki veriyor).
  void _onTimerEvent(TimerEvent event) {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
    final l10n = AppLocalizations.of(context);
    final msg = switch (event) {
      TimerEvent.workDone => l10n.classroomMola,
      TimerEvent.breakDone => l10n.classroomCalismayaBasla,
      TimerEvent.countdownDone => l10n.homeBitti,
      TimerEvent.allDone => l10n.homeBitti,
    };
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _editGoal(BuildContext context, int currentMinutes) async {
    final result = await showGoalEditorDialog(
      context,
      initialMinutes: currentMinutes,
    );
    if (result == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    // 🔴 WP-715 (ek) — WP-710 günlük hedef ayarını Ayarlar'dan kaldırdı; o
    // yolda kayıt başarılı olunca `profileGunlukHedefGuncellendi` onayı
    // çıkıyordu. Tek düzenleme yüzeyi bu karta indi ve onay birlikte kayboldu:
    // kullanıcı yalnız hata görüyor, başarıyı görmüyordu. Anahtar zaten
    // katalogda vardı ve `lib/` içinde ölü duruyordu.
    final savedMessage = AppLocalizations.of(
      context,
    ).profileGunlukHedefGuncellendi;
    // 🔴 WP-619: yakalama dalı `on AuthException` idi ve `updateDailyGoal` bu
    // türü HİÇ atmaz — ağ/sunucu hatası `PostgrestException` /
    // `ClientException` / `SocketException` olarak gelir, dalın yanından geçip
    // global yutucuya giderdi. Kullanıcı hedefini değiştiriyor, hiçbir şey
    // olmuyor, eski hedef sessizce duruyordu.
    //
    // WP-610 aynı hatayı Ayarlar ve Profil'de kapattı ama burayı kapatamadı
    // (o turda bu dosya başka bir ajandaydı) ve **kullanıcı hedefini en çok
    // buradan değiştiriyor** — sayaç kartı ana yüzey.
    //
    // Günlük hedef seriyi (streak) ve ilerleme halkasını besliyor: sessizce
    // eski hedefte kalan kullanıcı hedefi tutup tutmadığını da yanlış görür.
    try {
      await ref.read(authRepositoryProvider).updateDailyGoal(result);
      ref.invalidate(authStateProvider);
      messenger.showSnackBar(SnackBar(content: Text(savedMessage)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  // WP-613: Durdur kuralı (ayna onayı + hata şeridi) artık
  // `stopTimerFromSurface` içinde, tam ekran odak ekranıyla ORTAK. Burada
  // kopyası durduğu sürece birini düzeltip diğerini unutmak serbestti; odak
  // ekranı tam olarak öyle geride kalmıştı.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timer = ref.watch(studyTimerProvider);
    // Çalışıyorsa saniyelik UI tick; durunca ticker kapalı (Windows perf).
    _syncTicker(timer.isRunning);
    final recorded = ref.watch(todayRecordedSecondsProvider);
    final todayKey = dayOf(DateTime.now());

    // Faz geçişinde ses/titreşim/uyarı (§2H).
    // WP-250: "durdurmada ekranı dondur" bloğu KALDIRILDI. Dondurulan değer
    // ekranın kendi gösterdiği sayıydı ve `stop()` sırasındaki kare çiziminde
    // zaten şişmiş olabiliyordu → hata kalıcılaşıyordu. Artık toplam, notifier'ın
    // bildirdiği settling* alanlarından türetilir (bkz. resolveTodayDisplayTotal).
    ref.listen<StudyTimerState>(studyTimerProvider, (prev, next) {
      if (prev == null) return;
      if (next.eventSeq != prev.eventSeq && next.lastEvent != null) {
        _onTimerEvent(next.lastEvent!);
      }
      final stoppedAt = next.globalTimerStoppedRemotelyAt;
      if (stoppedAt != null && stoppedAt != prev.globalTimerStoppedRemotelyAt) {
        final time = MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(TimeOfDay.fromDateTime(stoppedAt));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).classroomStoppedOnOtherDevice(time),
            ),
          ),
        );
      }
    });
    ref.listen<bool>(selectedStudySubjectFallbackNoticeProvider, (
      previous,
      pending,
    ) {
      if (!pending) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).studySelectedSubjectUnavailable,
          ),
        ),
      );
      ref.read(selectedStudySubjectFallbackNoticeProvider.notifier).clear();
    });
    // WP-598: kaza korkuluğu + arka plan açıklaması. Kural odak ekranıyla ortak
    // (`listenTimerNotices`), yüzeyler arasında sürüklenemez.
    listenTimerNotices(context, ref);

    final now = DateTime.now();
    final elapsed = (timer.isRunning && timer.startedAt != null)
        ? now.difference(timer.startedAt!).inSeconds
        : 0;
    final target = timer.phaseTargetSeconds;
    final inWork = timer.phase == TimerPhase.work;
    // Büyük saat: kronometre yukarı sayar; geri sayım/pomodoro kalanı geri sayar
    // (dururken hedefin tamamını gösterir).
    final displaySeconds = target == null
        ? elapsed
        : (timer.isRunning ? (target - elapsed).clamp(0, target) : target);
    // Bugünün toplamına yalnız ÇALIŞMA fazının canlı süresi eklenir (mola hariç).
    // WP-250: durdurma başladığı an (isStopping) canlı akış kesilir; aradaki
    // saniyeler settling* alanlarıyla taşınır → ne zıplama ne düşme.
    final liveWork = (timer.isRunning && !timer.isStopping && inWork)
        ? elapsed
        : 0;
    final todayTotal = resolveTodayDisplayTotal(
      recordedToday: recorded,
      liveWorkSeconds: liveWork,
      settlingSeconds: timer.settlingSeconds,
      settlingBaseline: timer.settlingBaseline,
      settlingDay: timer.settlingDay,
      // WP-561: gece yarısını aşan koşuda canlı terim bugüne düşen kısma
      // kırpılır — yoksa 23:00'da başlayan koşu 01:30'da "Bugün 2 sa 30 dk"
      // gösterip Durdur'da 0'a düşüyordu.
      liveStartedAt: timer.startedAt,
      nowInstant: now,
      today: todayKey,
    );
    final notifier = ref.read(studyTimerProvider.notifier);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    final generalSubjectVisible = ref.watch(generalSubjectVisibleProvider);

    final goalMinutes = ref.watch(dailyGoalMinutesProvider);
    final goalSeconds = goalMinutes * 60;
    // WP-481: kişisel seri kapsamı. `currentStreakProvider` bu yüzeyden
    // çıkarıldı; iki seri motoru aynı ekranda yaşamamalı.
    final userId = ref.watch(authStateProvider).value?.id;
    final personalStreakScope = userId == null
        ? null
        : GoalStreakScope.personal(userId);
    final pct = goalSeconds > 0
        ? (todayTotal / goalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final reached = goalSeconds > 0 && todayTotal >= goalSeconds;
    // Saat halkası/renk geçişi: timer modunda FAZ ilerlemesi, kronometrede hedef.
    final clockPct = target == null
        ? pct
        : (target > 0 ? (elapsed / target).clamp(0.0, 1.0) : 0.0);
    final clockStyle = ref.watch(clockStyleProvider);
    // 🔴 WP-715 — sahip: "minimal var, seçiyorum kart hâlâ çok büyük".
    // Ölçüldü (`timer_card_compact_wp715_test.dart`, 360 dp): beş `ClockStyle`
    // yalnız saatin ÇİZİMİNİ değiştiriyordu, kartın yüksekliği hepsinde aynı
    // banda düşüyordu. `compact` kartın DÜZENİNİ değiştiren tek seçenektir.
    final compact = clockStyle == ClockStyle.compact;

    // 🔴 WP-715 — kartin KAPLADIGI yukseklik hucreden gelir, icerikten degil.
    // Ana Sayfa izgarasi karti `SizedBox(height: hucre)` icine koyar
    // (`home_screen.dart` `heightOf` -> `dashboard_card.dart`
    // `dashboardCardFor`) ve `Card` o kutuyu doldurur. Yani tek satirlik
    // icerik tek basina hicbir sey kucultmez: kullanici Kompakti secip
    // ayni buyuklukte, artik BOS bir kart gorurdu.
    //
    // `Align` kartin kendisini icerigi kadar boyar ve hucrenin ustune
    // yaslar; kalan yer kart degil arka plan olur. Hucreyi (satir sayisini)
    // kullanici kendi kucultur — izgara koordinatlari bu WP'nin disinda.
    final card = Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final small = constraints.maxWidth < 280;
          final isLarge = constraints.maxWidth >= 400;

          // 🔴 WP-659 — ÜST ŞERİT DAR HÜCREDE KIRPILIYORDU.
          //
          // Ölçüldü (160×160 hücre, `card_scroll_inventory_test.dart`
          // `_knownRenderFlex` kaydı): `Card` kendi 4 px kenar boşluğunu
          // düştükten sonra `LayoutBuilder`a 152 px kalıyor, şeridin yatay
          // padding'i (14 + 4) düşünce **134 px**. Üç `IconButton` ise
          // Material'in 48 px'lik varsayılan dokunma kutusuyla 3 × 48 = 144 px
          // istiyor → `RenderFlex overflowed by 10.0 pixels on the right`:
          // tam ekran düğmesinin sağı **kesiliyor**, kaydırıcı bile yok, yani
          // kullanıcı o pikselleri hiçbir şekilde göremiyor.
          //
          // 🔴 WP-662 — o düzeltme kırpmayı bitirdi ama yerine bir
          // ERİŞİLEBİLİRLİK kusuru koydu: `clamp(32, 48)` 160×160 hücrede
          // düğmeyi **36.7 px**'e indiriyordu. 48 px altı bir dokunma hedefi
          // "biraz küçük" değil, Material'in asgari hedefinin altıdır: parmak
          // ucu 48 px'lik alanı bulacak şekilde tasarlanmıştır, 36.7 px'te
          // yanlış düğmeye basmak kural olur.
          //
          // Yeni kural: **düğme küçülmez, sayısı azalır.** Şeride kaç tane
          // 48 px'lik yuva sığdığı ölçülür; sığmayan aksiyonlar taşma menüsüne
          // (`showAnchoredMenu`) girer. Menü düğmesi de bir yuva harcar, yani
          // 2 yuvada 1 aksiyon + menü görünür.
          const badgeReserve = 24.0;
          final stripWidth = constraints.maxWidth - 18;
          final slots = ((stripWidth - badgeReserve) / kMinTouchTarget)
              .floor()
              .clamp(1, 3);

          // 🔴 WP-662 — KÜÇÜK HÜCREDE İÇERİK GİZLENİR, KAYDIRILMAZ.
          //
          // WP-646 jesti doğru yere yolladı ama kalan borcu kendi notunda
          // yazdı: "küçük hücrelerde içerik GERÇEKTEN taştığı için orada hâlâ
          // kaydırma kalır". Ölçüldü (`card_scroll_inventory_test.dart`):
          // 160×160 hücrede sayaç kartı **433 px** kart-içi kaydırma payı
          // üretiyordu (yazı ölçeği 1.6'da 686 px) — yani kullanıcının gördüğü
          // şey kartın dörtte biri.
          //
          // Sahip kararı: küçük hücrede kartın **çekirdeği** kalır — geçen süre
          // + birincil eylem (Başlat/Durdur). Ders seçici hapı, günlük hedef
          // çubuğu, mod seçici ve "manuel süre ekle" ikincil satırlardır; onlar
          // için kart büyütülür ya da tam ekran odak açılır.
          //
          // İki eşik de hücrenin GERÇEK yüksekliğinden okunur, genişlik
          // tahmininden değil: eski `small = maxWidth < 280` kuralı 328×160
          // hücreyi "geniş" sayıp aynı yoğunluğu çiziyordu, sonuç 358 px taşma.
          // Başlat/Durdur iki düzende de AYNI düğmedir: tam kartta tam
          // genişlik, kompakt satırda doğal genişlik. Tek tanım = biri
          // düzeltilip diğeri unutulamaz (WP-613 dersi).
          final primaryAction = timer.isRunning
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  onPressed: timer.isStopping
                      ? null
                      : () => stopTimerFromSurface(context, ref),
                  // WP-507: durdurma zinciri (native uzlaşma + sunucu finalize)
                  // bazen saniyeler sürüyor. Buton yalnız griye düşünce
                  // kullanıcı "tuş öldü" sanıyordu; ilerleme görünür olmalı.
                  icon: timer.isStopping
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop),
                  label: Text(
                    timer.isStopping
                        ? AppLocalizations.of(context).classroomDurduruluyor
                        : AppLocalizations.of(context).classroomDurdur,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : FilledButton.icon(
                  onPressed: notifier.start,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    AppLocalizations.of(context).classroomCalismayaBasla,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );

          final availableHeight = constraints.maxHeight;
          final heightBounded = availableHeight.isFinite;
          final core = heightBounded && availableHeight < kTimerCoreMaxHeight;
          final showSecondary =
              !heightBounded || availableHeight >= kTimerFullMinHeight;

          // WP-496: kart artık `Stack` değil **akış**.
          //
          // 🔴 Kök neden buydu: rozet ve üst ikonlar `Positioned` ile içeriğin
          // ÜSTÜNE biniyordu, çakışmayı yalnız `fromLTRB(16, 48, ...)` sabiti
          // önlüyordu. 48 px yazı ölçeğiyle büyümez; ölçek 1.3/1.6'ya çıkınca
          // rozet "Bugün" yazısının üstüne oturuyordu (sahip şikâyeti V58-N10).
          // Akışta üst şerit kendi yüksekliğini ölçekle birlikte büyütür, yani
          // çakışma yapısal olarak imkânsız — sayıyı büyütmekle çözülmedi,
          // sayının kendisi kaldırıldı.
          // 🔴 WP-646 — KART İÇİ KAYDIRMA ANA EKRANI TAKIYORDU.
          //
          // Proje sahibi cihazda bildirdi: *"bazi kartlarda hala gereksiz kart
          // icinde asagi yukari kaydirma var; parmagim onlarin ustundeyse
          // takiliyor. Weekly rhythm ve sayac karti mesela."*
          //
          // Buradaki `SingleChildScrollView` ciplakti: ne `physics` ne
          // `primary` verilmisti. Iki ayri kusur uretiyordu:
          //
          //  1. Varsayilan `AlwaysScrollableScrollPhysics`e dusuyordu — yani
          //     icerik SIGSA BILE dikey suruklemeyi yutuyordu. Pano kartlari
          //     icin ortak kural (`CardOverflowScrollPhysics`, WP-508) tam da
          //     bunu engellemek icin yazilmisti; bu kart o kurali hic
          //     kullanmiyordu. `cardScrollIfOverflows` cagirmak yetmiyor,
          //     cagirmamak ise kurali bastan bosa cikariyor.
          //  2. `primary` varsayilani `true` oldugu icin DIS SAYFANIN
          //     `PrimaryScrollController`’ina baglaniyordu: kart, uzerinde
          //     olmayan bir kaydiriciyi surukluyordu.
          //
          // Olculdu (hunter Lane B envanteri, 18 kart x 3 genislik x 3 hucre):
          // sayac karti envanterin EN KOTU kartiydi — 840x416 tablet
          // hucresinde bile 132 px tasiyordu, telefonda 232-444 px. Baska
          // hicbir kart tablet olcusunde kaymiyordu.
          //
          // Not (kalan borç): bu duzeltme JESTI dogru yere yollar; kucuk
          // hucrelerde icerik GERCEKTEN tastigi icin orada hala kaydirma
          // kalir. Yogunlugu azaltmak ayri bir urun karari (sahibe onizleme
          // ile sorulmali), bu yuzden burada yapilmadi.
          return SingleChildScrollView(
            // Dis sayfanin denetleyicisini CALMA.
            primary: false,
            // Icerik sigiyorsa jest dis sayfaya gider.
            physics: kCardOverflowScrollPhysics,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🔴 WP-592: bildirim izni reddedilince sayaç GÖRÜNMEZ çalışıyordu
                // ve kullanıcıya hiçbir yerde tek kelime söylenmiyordu.
                // `notificationsEnabled` `lib/` içinde yalnız Profil → Ayarlar →
                // Bildirim Merkezi'nde okunuyordu; sayacı başlatan kişi oraya
                // hiç uğramaz. Karşılığı: kalıcı bildirim yok, bildirimden
                // durdurma yok, kullanıcı "sayaç bozuk" der.
                //
                // İzin İSTENMEZ, yalnız OKUNUR: `requestPermissionIfNeeded`in
                // "hiçbir koşulda hata fırlatmaz" sözleşmesi (WP-520) ve sayaç
                // başlatmanın izinden bağımsız olması aynen korunur.
                if (ref
                        .watch(timerNotificationPermissionStatusProvider)
                        .value ==
                    false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 8, 0),
                    child: ErrorRetryView(
                      key: const Key('timer-notification-denied'),
                      dense: true,
                      message: AppLocalizations.of(
                        context,
                      ).clockSayacBildirimiIzniKapali,
                      retryLabel: AppLocalizations.of(
                        context,
                      ).clockEksikIzinleriAc,
                      onRetry: () => ref
                          .read(timerNotificationPermissionProvider)
                          .openSystemNotificationSettings(),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    (core || compact) ? 2 : 6,
                    4,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // WP-481: seri rozeti **daima** görünür (sahip kararı) ve
                      // kanonik projeksiyondan okunur. Eski `if (streak > 0)`
                      // kapısı ile grace'siz `currentStreakProvider` birlikte
                      // kalktı. Dar kartta ikonlara yer kalsın diye küçülür,
                      // kırpılmaz.
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: GoalStreakBadge(
                              scope: personalStreakScope,
                              size: small
                                  ? GoalStreakFlameSize.compact
                                  : GoalStreakFlameSize.regular,
                            ),
                          ),
                        ),
                      ),
                      // Saat görünümü + tam ekran odak modu (§3.12).
                      _StripActions(slots: slots, ref: ref),
                    ],
                  ),
                ),
                // 🔴 WP-715 — KOMPAKT: kartı gerçekten kısaltan tek düzen.
                // Tek satır = SÜRE + Başlat/Durdur. Gizlenenler: "Bugün"
                // toplamı, faz göstergesi/mod seçici, günlük hedef çubuğu,
                // ders seçici hapı, "manuel süre ekle".
                //
                // Üst şerit KALIR: saat görünümü menüsü orada: gizlenirse
                // kompaktı seçen kullanıcı geri dönemez (tek yönlü kapı).
                if (compact)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: StudyClock(
                                seconds: displaySeconds,
                                pctToGoal: clockPct,
                                running: timer.isRunning,
                                style: clockStyle,
                                fontSize: 32,
                                // WP-554: yalnız ekran okuyucu etiketi için.
                                phase: timer.phase,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 🔴 Dar kartta küçülen şey SÜREdir (FittedBox), dokunma
                        // hedefi değil (WP-662 dersi: düğme küçültülmez).
                        // Tavan olmadan düğme doğal genişliğine yayılıp satırı
                        // taşırırdı: `Row` esnek olmayan çocuğa ana eksende
                        // SINIRSIZ kısıt verir.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: (constraints.maxWidth - 44) * 0.68,
                          ),
                          child: primaryAction,
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, core ? 4 : 20),
                    child: Column(
                      children: [
                        // "Bugün" toplamı ÇEKİRDEK değil: çekirdek, geçen süre +
                        // birincil eylemdir. 160 px'lik hücrede bu iki satır
                        // (etiket + headlineMedium) tek başına ~60 px yiyor.
                        if (!core) ...[
                          Text(
                            AppLocalizations.of(context).classroomBugun,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Dar kartta taşmasın diye ölçekle.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatHumanSeconds(todayTotal),
                              maxLines: 1,
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StudyClock(
                            seconds: displaySeconds,
                            pctToGoal: clockPct,
                            running: timer.isRunning,
                            style: clockStyle,
                            fontSize: core
                                ? 28
                                : (small ? 34 : (isLarge ? 56 : 40)),
                            // 🔴 Halka/dilim stillerinde saatin boyu `diameter`
                            // ile SABİTTİR; `FittedBox` yalnız GENİŞLİĞE göre
                            // küçültür, dikeyde sınır yok. Çekirdek hücrede 130 px
                            // tek başına kutunun tamamını yer.
                            diameter: core
                                ? 88
                                : (small ? 130 : (isLarge ? 220 : 160)),
                            // WP-554: yalnız ekran okuyucu etiketi için.
                            phase: timer.phase,
                          ),
                        ),
                        SizedBox(height: core ? 8 : 16),
                        // Çalışırken faz göstergesi; dururken mod seçici + ayarlar.
                        // Faz göstergesi bir DURUM satırıdır (mola mı, çalışma mı),
                        // mod seçici ise bir kontrol — ilki orta hücrede kalır,
                        // ikincisi ikincil satırlarla birlikte gizlenir.
                        if (!core) ...[
                          if (timer.isRunning) ...[
                            TimerPhaseIndicator(timer: timer),
                            const SizedBox(height: 8),
                            TimerVerificationNotice(timer: timer),
                            if (timer.mode != TimerMode.stopwatch)
                              const SizedBox(height: 16),
                          ] else if (showSecondary) ...[
                            const TimerModeControls(),
                            const SizedBox(height: 16),
                          ],
                        ],
                        if (showSecondary) ...[
                          _GoalProgress(
                            todaySeconds: todayTotal,
                            goalSeconds: goalSeconds,
                            pct: pct,
                            reached: reached,
                            onEdit: () => _editGoal(context, goalMinutes),
                          ),
                          const SizedBox(height: 16),
                          _SubjectSelector(
                            subjects: subjects,
                            selectedId: timer.subjectId,
                            running: timer.isRunning,
                            generalVisible: generalSubjectVisible,
                            onSelect: notifier.selectSubject,
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(width: double.infinity, child: primaryAction),
                        if (showSecondary) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () => addManualSessionFlow(context, ref),
                            icon: const Icon(Icons.edit_calendar, size: 18),
                            label: Text(
                              AppLocalizations.of(
                                context,
                              ).classroomManuelSureEkle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    return compact ? Align(alignment: Alignment.topCenter, child: card) : card;
  }
}

/// Sayaç kartının üst şeridindeki aksiyon düğmesi (§3.12).
///
/// Boyut **sabit** [kMinTouchTarget]'tır. WP-659'daki `size` parametresi ve
/// `clamp(32, 48)` kaldırıldı: hücre daraldığında küçülen şey düğme değil,
/// görünen düğme SAYISIDIR (bkz. [_StripActions]).
Widget _stripAction({
  required IconData icon,
  required String tooltip,
  required VoidCallback onPressed,
}) => IconButton(
  tooltip: tooltip,
  icon: Icon(icon),
  iconSize: 24,
  padding: EdgeInsets.zero,
  constraints: const BoxConstraints.tightFor(
    width: kMinTouchTarget,
    height: kMinTouchTarget,
  ),
  onPressed: onPressed,
);

/// Üst şeritteki bir aksiyonun tanımı — hem düğme hem menü satırı olarak
/// çizilebilsin diye ayrıldı (aynı etiket, aynı ikon, aynı iş).
class _StripActionSpec {
  const _StripActionSpec({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;

  /// Tetikleyicinin kendi context'i geçilir: `showClockStyleMenu` ve taşma
  /// menüsü konumu buna göre bağlanır.
  final void Function(BuildContext context) onPressed;
}

/// Üst şerit: [slots] kadar 48 px'lik yuvaya sığan aksiyonlar düğme, kalanlar
/// taşma menüsü satırı olur.
///
/// 🔴 Menü düğmesi de bir yuva harcar — bu yüzden 2 yuvada 1 aksiyon + menü
/// görünür, 3'te hepsi görünür ve menü hiç çizilmez.
class _StripActions extends StatelessWidget {
  const _StripActions({required this.slots, required this.ref});

  final int slots;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Sıra = önem sırası TERSİ: en sondaki en çok korunur. Yuva azaldıkça
    // baştan menüye düşer, yani en son "Tam ekran odak" kalır.
    final actions = <_StripActionSpec>[
      _StripActionSpec(
        icon: Icons.history,
        label: l10n.classroomGecmisOturumlar,
        onPressed: (ctx) => Navigator.of(
          ctx,
        ).push(MaterialPageRoute(builder: (_) => const SessionHistoryScreen())),
      ),
      _StripActionSpec(
        icon: Icons.tune,
        label: l10n.classroomSaatGorunumu,
        onPressed: (ctx) => showClockStyleMenu(ctx, ref),
      ),
      _StripActionSpec(
        icon: Icons.fullscreen,
        label: l10n.classroomTamEkranOdak,
        onPressed: (ctx) => openFocusTimer(ctx),
      ),
    ];

    final visibleCount = slots >= actions.length ? actions.length : slots - 1;
    final hidden = actions.sublist(0, actions.length - visibleCount);
    final visible = actions.sublist(actions.length - visibleCount);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hidden.isNotEmpty)
          Builder(
            builder: (menuContext) => _stripAction(
              icon: Icons.more_vert,
              tooltip: l10n.classroomDigerSecenekler,
              onPressed: () async {
                final picked = await showAnchoredMenu<int>(
                  context: menuContext,
                  items: [
                    for (var i = 0; i < hidden.length; i++)
                      PopupMenuItem<int>(
                        value: i,
                        child: Row(
                          children: [
                            Icon(hidden[i].icon, size: 20),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                hidden[i].label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
                if (picked == null || !menuContext.mounted) return;
                hidden[picked].onPressed(menuContext);
              },
            ),
          ),
        for (final action in visible)
          Builder(
            builder: (actionContext) => _stripAction(
              icon: action.icon,
              tooltip: action.label,
              onPressed: () => action.onPressed(actionContext),
            ),
          ),
      ],
    );
  }
}

/// Sayaç için ders seçici — kapalıyken seçili dersi (veya "Genel"i) gösteren
/// bir "dropdown" hap; dururken dokununca ders listesi alt sayfası açılır
/// (Claude Code model seçici mantığı). Çalışırken kilitlidir (yalnız etiket).
/// Ders seçimi opsiyoneldir (§3.7).
class _SubjectSelector extends StatelessWidget {
  const _SubjectSelector({
    required this.subjects,
    required this.selectedId,
    required this.running,
    required this.generalVisible,
    required this.onSelect,
  });

  final List<Subject> subjects;
  final String? selectedId;
  final bool running;
  final bool generalVisible;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Subject? selected;
    for (final s in subjects) {
      if (s.id == selectedId) selected = s;
    }

    final dotColor = selected != null
        ? subjectColor(selected.color)
        : theme.colorScheme.onSurfaceVariant;
    final label =
        selected?.name ??
        (generalVisible
            ? AppLocalizations.of(context).classroomGenel
            : AppLocalizations.of(context).classroomDers);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 5, backgroundColor: dotColor),
        const SizedBox(width: 8),
        // 🔴 WP-659: çıplak `Text` idi. Hapın iç genişliği 160 px hücrede
        // 92 px; uzun bir ders adı (ya da büyük yazı ölçeği) satırı taşırıyor
        // ve `RenderFlex overflowed by 17 pixels on the right` ile ders adının
        // sağı KIRPILIYORDU. Hap zaten `mainAxisSize.min`, `Flexible` yalnız
        // sığmadığında devreye girer — dar olmayan kartta hiçbir şey değişmez.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
        ),
        if (!running) ...[
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );

    // Çalışırken: kilitli etiket (değiştirilemez).
    if (running) {
      return Center(child: content);
    }

    // Dururken: dokununca seçim alt sayfası.
    return Center(
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openPicker(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: content,
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final theme = Theme.of(context);
    final result = await showAnchoredMenu<_SubjectMenuResult>(
      context: context,
      items: [
        PopupMenuItem<_SubjectMenuResult>(
          enabled: false,
          height: 32,
          child: Text(
            AppLocalizations.of(context).classroomDers,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (generalVisible)
          PopupMenuItem<_SubjectMenuResult>(
            value: const _SubjectMenuResult.pick(null),
            child: _subjectMenuRow(
              theme,
              AppLocalizations.of(context).classroomGenelDersYok,
              theme.colorScheme.onSurfaceVariant,
              selectedId == null,
            ),
          ),
        for (final s in subjects)
          PopupMenuItem<_SubjectMenuResult>(
            value: _SubjectMenuResult.pick(s.id),
            child: _subjectMenuRow(
              theme,
              s.name,
              subjectColor(s.color),
              selectedId == s.id,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<_SubjectMenuResult>(
          value: const _SubjectMenuResult.edit(),
          child: Row(
            children: [
              Icon(Icons.tune, size: 20),
              SizedBox(width: 12),
              Text(AppLocalizations.of(context).classroomDersleriDuzenle),
            ],
          ),
        ),
      ],
    );
    if (result == null) return;
    if (result.isEdit) {
      if (context.mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SubjectsScreen()));
      }
      return;
    }
    onSelect(result.subjectId);
  }
}

/// Ders menüsü sonucu: bir ders seç (null = Genel) veya dersleri düzenle.
class _SubjectMenuResult {
  const _SubjectMenuResult.pick(this.subjectId) : isEdit = false;
  const _SubjectMenuResult.edit() : subjectId = null, isEdit = true;

  final String? subjectId;
  final bool isEdit;
}

Widget _subjectMenuRow(
  ThemeData theme,
  String label,
  Color dot,
  bool selected,
) {
  return Row(
    children: [
      CircleAvatar(radius: 6, backgroundColor: dot),
      const SizedBox(width: 12),
      Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      if (selected)
        Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
    ],
  );
}

/// Günlük hedef ilerleme çubuğu — bugünkü süre / hedef + yüzde; hedefe ulaşınca
/// yeşile döner. Dokununca hedef düzenlenir (§3.7).
class _GoalProgress extends StatelessWidget {
  const _GoalProgress({
    required this.todaySeconds,
    required this.goalSeconds,
    required this.pct,
    required this.reached,
    required this.onEdit,
  });

  final int todaySeconds;
  final int goalSeconds;
  final double pct;
  final bool reached;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Hedefe ulaşınca yeşil (chart-2), yoksa birincil renk.
    final barColor = reached
        ? subjectColor('chart-2')
        : theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 16, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).classroomGunlukHedef,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '%${(pct * 100).round()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: reached ? barColor : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 14, color: muted),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${formatHumanSeconds(todaySeconds)} / ${formatHumanSeconds(goalSeconds)}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hedef serisi rozeti: ateş ikonu + üst üste günlük hedef tutturulan gün sayısı.
/// [compact] (dar kart) modunda yalnız ikon + sayı gösterir.
