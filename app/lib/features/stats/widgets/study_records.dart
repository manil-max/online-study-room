import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/session_window.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/animated_stat_number.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';

List<String> _months(BuildContext context) => [
  AppLocalizations.of(context).statsOca,
  AppLocalizations.of(context).statsSub,
  AppLocalizations.of(context).statsMar,
  AppLocalizations.of(context).statsNis,
  AppLocalizations.of(context).statsMay,
  AppLocalizations.of(context).statsHaz,
  AppLocalizations.of(context).statsTem,
  AppLocalizations.of(context).statsAgu,
  AppLocalizations.of(context).statsEyl,
  AppLocalizations.of(context).statsEki,
  AppLocalizations.of(context).statsKas,
  AppLocalizations.of(context).statsAra,
];

/// Kişisel rekorlar: toplam, rekor seri, en verimli gün, aktif gün, en çok ders.
/// Renkli stat döşemeleri (§3.11). Card'sız içerik — çağıran sarmalar.
class StudyRecords extends ConsumerWidget {
  const StudyRecords({
    super.key,
    required this.sessions,
    this.columns = 2,
    this.totals,
    this.lifetimeSeconds,
    this.windowLimited = false,
    this.dense = false,
    this.maxTiles,
  });

  final List<StudySession> sessions;
  final int columns;

  /// Çağıran zaten `dailyTotals(sessions)` hesapladıysa buradan geçirir; böylece
  /// bu widget (ve `longestStudyStreak`) haritayı yeniden kurmaz.
  final Map<DateTime, int>? totals;

  /// 🔴 WP-612: "Toplam" döşemesi için **ömür boyu** saniye
  /// (`UserStudySummary.lifetimeSeconds`). [sessions] her zaman SICAK
  /// PENCEREdir (son [kUserSessionsHotWindowDays] gün); ondan hesaplanan
  /// toplamı "Toplam" diye sunmak, 400 günlük geçmişi olan kullanıcıya kendi
  /// süresinin dörtte birini göstermekti. `null` ise (özet henüz gelmedi ya da
  /// hata verdi) pencere toplamına düşülür ve bu [windowLimited] ile SÖYLENİR.
  final int? lifetimeSeconds;

  /// 🔴 WP-612: veri gerçekten sıcak pencerenin gerisine uzanıyor mu. Doğruysa
  /// pencereye bağlı döşemelerin etiketine kapsam eklenir ("· 90 gün") —
  /// İstatistik ekranının WP-573'te kurduğu desenin aynısı.
  ///
  /// Yanlış yere asılan uyarı da bir yalandır (WP-585 dersi): çağıran bunu
  /// ancak ÖLÇTÜĞÜNDE `true` geçmelidir, "belki" diye değil.
  final bool windowLimited;

  /// WP-858: sıkıştırılmış döşeme. Ana Sayfa'nın rekor kartı dar telefonda
  /// varsayılan hücresinde (32×26, ~189 px gövde) 211 px KART İÇİ kaydırma
  /// üretiyordu; parmak kartın üstündeyken ana ekran takılıyordu.
  ///
  /// Yoğun modda: dolgu 12 → 8, ikon 22 → 18, etiket en çok İKİ satır,
  /// değer TEK satır (sığmazsa "…"); "En verimli gün" değeri `süre · gün ay`
  /// olarak tek satıra iner ve döşemeler ÖNEM sırasıyla dizilir (bkz.
  /// [maxTiles]). Döşeme boyu böylece metinden bağımsız bir TAVANA oturur:
  /// [denseTileHeight]. (Ölçüldü, tam modda dar telefonda tek döşeme —
  /// "En verimli gün" — 172 px'e uzuyordu.)
  ///
  /// Varsayılan `false`: mevcut çağıranlar birebir aynı ağacı alır.
  final bool dense;

  /// WP-858: en fazla kaç döşeme çizilecek (`null` = hepsi). Döşemeler önem
  /// sırasıyla kırpılır: Toplam → Rekor seri → Aktif gün → En verimli gün →
  /// En çok ders. Yalnız [dense] ile anlamlıdır (tam mod eski sırasını
  /// korur); kaçının sığdığına gövde yüksekliğini bilen çağıran karar verir.
  final int? maxTiles;

  /// Yoğun döşemenin (bkz. [dense]) piksel boy TAVANI: dolgu + çerçeve +
  /// max(ikon, 2 etiket satırı + 2 + değer satırı). Satır sayıları kilitli
  /// olduğu için döşeme bu sayıyı AŞAMAZ (tek satırlık etiketle altında
  /// kalır); kullanıcının yazı ölçeğini içerir. Çağıran kaç döşeme sığdığını
  /// içsel ölçüm ya da satır içinde `LayoutBuilder` kurmadan hesaplar
  /// (WP-857 dersi).
  static double denseTileHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final h = painter.height;
      painter.dispose();
      return h;
    }

    final text =
        _kDenseLabelLines * line(Theme.of(context).textTheme.labelSmall) +
        2 +
        line(_tileValueStyle(context));
    // İki yan dolgu + 1 px'lik üst/alt çerçeve.
    return 2 * _kDensePadding + 2 + (text > _kDenseIcon ? text : _kDenseIcon);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = _months(context);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    // WP-804: döşeme ikonları kart yüzeyinin üstünde çiziliyor; renk o zeminin
    // fonksiyonu (zorunlu parametre).
    final surface = Theme.of(context).colorScheme.surface;

    // 🔴 WP-612: "Toplam" ömür boyu özetten gelir; yalnız özet yoksa pencere
    // toplamına düşülür — ve o durumda kapsam etiketi bu döşemeye de asılır.
    final total = lifetimeSeconds ?? totalSeconds(sessions);
    final daily = totals ?? dailyTotals(sessions);
    // Rekor seri / en verimli gün / aktif gün / en çok ders SICAK PENCEREdir
    // ve pencerenin dışına çıkamaz (rekor seri 90'ı hiçbir zaman aşamaz).
    final windowScope = windowLimited
        ? ' · ${AppLocalizations.of(context).statsStreakGun(kUserSessionsHotWindowDays.toString())}'
        : '';
    final totalScope = lifetimeSeconds == null ? windowScope : '';
    // 🔴 WP-637: "Rekor seri" GÜNLÜK HEDEF serisidir. Eskiden "o gün en az 1
    // saniye kayıt var mı" ile sayılıyordu — yani hemen altındaki "Aktif gün"
    // döşemesiyle aynı gün tanımı, iki farklı isimle. Sahip kararı: seri
    // ürünün kendi günlük seri kuralına (`currentStreak` eşiği) bağlanır,
    // "Aktif gün" ayrı ölçü olarak AYNEN kalır.
    final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
    final longest = longestStudyStreak(
      sessions,
      totals: daily,
      goalSeconds: goalSeconds,
    );
    // 🔴 WP-636: `daily.length` gün SAYISIydı, çalışılan gün sayısı değil —
    // 0 saniyelik (sıfırlanmış/silinmiş) bir gün de haritada anahtar açar ve
    // "Aktif gün" döşemesini şişirirdi. WP-561 bu `> 0` kuralını rekor seri
    // için koymuş, komşu döşemede uygulanmamıştı; iki döşeme farklı gün
    // tanımıyla yan yana duruyordu. Grup kartı (`class_stats_view`) zaten
    // [activeDayCount] kullanıyor — tek kural, tek yardımcı.
    final activeDays = activeDayCount(daily);

    // En verimli gün.
    DateTime? bestDay;
    var bestSeconds = 0;
    daily.forEach((day, sec) {
      if (sec > bestSeconds) {
        bestSeconds = sec;
        bestDay = day;
      }
    });

    // En çok çalışılan ders.
    final breakdown = subjectBreakdown(sessions);
    String topSubject = '—';
    if (breakdown.isNotEmpty) {
      final id = breakdown.first.key;
      if (id == null) {
        topSubject = AppLocalizations.of(context).statsGenel;
      } else {
        topSubject = subjects
            .where((s) => s.id == id)
            .map((s) => s.name)
            .firstWhere(
              (_) => true,
              orElse: () => AppLocalizations.of(context).statsGenel,
            );
      }
    }

    // WP-858: yoğun modda her değer TEK satırdır (döşeme boyu hesaplanabilir
    // kalsın, bkz. [denseTileHeight]); "En verimli gün" bu yüzden iki satır
    // yerine `süre · gün ay` olarak yazılır.
    final valueMaxLines = dense ? 1 : null;
    final valueOverflow = dense ? TextOverflow.ellipsis : null;
    final bestDayText = bestDay == null
        ? '—'
        : '${formatHuman(bestSeconds)}${dense ? ' · ' : '\n'}'
              '${bestDay!.day} ${months[bestDay!.month - 1]}';

    final totalTile = _RecordTile(
      dense: dense,
      icon: Icons.timelapse,
      color: subjectColor('chart-1', on: surface),
      label: '${AppLocalizations.of(context).statsToplam}$totalScope',
      // WP-808: oturum kaydedilince toplam tek karede zıplıyordu.
      value: AnimatedStatNumber(
        value: total,
        format: formatHuman,
        style: _tileValueStyle(context),
        maxLines: valueMaxLines,
      ),
    );
    final streakTile = _RecordTile(
      dense: dense,
      icon: Icons.local_fire_department,
      color: subjectColor('chart-5', on: surface),
      label: '${AppLocalizations.of(context).statsRekorSeri}$windowScope',
      value: Text(
        AppLocalizations.of(context).statsStreakGun(longest.toString()),
        style: _tileValueStyle(context),
        maxLines: valueMaxLines,
        overflow: valueOverflow,
      ),
    );
    final bestDayTile = _RecordTile(
      dense: dense,
      icon: Icons.emoji_events_outlined,
      color: subjectColor('chart-3', on: surface),
      label: '${AppLocalizations.of(context).statsEnVerimliGun}$windowScope',
      value: Text(
        bestDayText,
        style: _tileValueStyle(context),
        maxLines: valueMaxLines,
        overflow: valueOverflow,
      ),
    );
    final activeTile = _RecordTile(
      dense: dense,
      icon: Icons.calendar_month_outlined,
      color: subjectColor('chart-2', on: surface),
      label: '${AppLocalizations.of(context).statsAktifGun}$windowScope',
      value: Text(
        AppLocalizations.of(context).statsStreakGun(activeDays.toString()),
        style: _tileValueStyle(context),
        maxLines: valueMaxLines,
        overflow: valueOverflow,
      ),
    );
    final subjectTile = _RecordTile(
      dense: dense,
      icon: Icons.menu_book_outlined,
      color: subjectColor('chart-4', on: surface),
      label: '${AppLocalizations.of(context).statsEnCokDers}$windowScope',
      value: Text(
        topSubject,
        style: _tileValueStyle(context),
        maxLines: valueMaxLines,
        overflow: valueOverflow,
      ),
    );

    // WP-858: yoğun modda döşemeler ÖNEM sırasıyla dizilir ki [maxTiles]
    // kırptığında düşen, en az kritik olan olsun. Tam mod eski sırasını
    // birebir korur (mevcut çağıranlar ve testler aynı ağacı görür).
    final ordered = dense
        ? [totalTile, streakTile, activeTile, bestDayTile, subjectTile]
        : [totalTile, streakTile, bestDayTile, activeTile, subjectTile];
    final limit = maxTiles;
    final tiles = limit == null || limit >= ordered.length
        ? ordered
        : ordered.sublist(0, limit < 1 ? 1 : limit);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final cols = columns.clamp(1, 4);
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

/// Döşeme değerinin ortak yazı biçimi. WP-808'de değer `String`ten `Widget`e
/// döndü (biri artık [AnimatedStatNumber]); biçim burada TEK yerde durur ki
/// beş döşeme birbirinden ayrışmasın.
/// WP-858: yoğun döşemenin sabit ölçüleri; [StudyRecords.denseTileHeight]
/// ile [_RecordTile] aynı sayıyı okusun diye tek yerde.
const double _kDensePadding = 8;
const double _kDenseIcon = 18;

/// Yoğun etiketin satır tavanı. BİR değil İKİ: dar telefonda döşeme ~94 px
/// metin genişliği bırakır ve "Rekor seri · 90 gün" tek satıra sığmaz; tek
/// satırda kırpılsaydı WP-612'nin SÖYLEMEK zorunda olduğu kapsam ("· 90 gün")
/// "…" altında kaybolurdu.
const int _kDenseLabelLines = 2;

TextStyle? _tileValueStyle(BuildContext context) => Theme.of(
  context,
).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    this.dense = false,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final bool dense;
  final IconData icon;
  final Color color;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(dense ? _kDensePadding : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: dense ? _kDenseIcon : 22),
          SizedBox(width: dense ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: dense ? _kDenseLabelLines : null,
                  overflow: dense ? TextOverflow.ellipsis : null,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                value,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
