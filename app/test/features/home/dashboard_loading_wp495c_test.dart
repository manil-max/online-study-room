// WP-495C: pano kartlarının ilk yüklemede "veri yok" iddia etmesi.
//
// `docs/qa/V58-ASYNC-EMPTY-AUDIT.md` §5'te kalan sınıf buydu: 13 kart oturum /
// grup istatistiği akışını `.value ?? const []` ile okuyordu. Yenilemeye
// dayanıklı ama **ilk yüklemede** boş liste = "hiç kaydın yok" demek. Kaydı olan
// kullanıcı açılışta "Kayıt yok", boş ısı haritası ve "0 dk" görüyordu.
//
// Ölçüt "daha az titriyor" değil: yükleme karesinde kartın **hangi metni
// yazdığı**. Bu yüzden testler boş-durum metinlerini ve "0 dk"yı arıyor.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/widgets/card_data_gate.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/istanbul_fixture.dart';

final _me = Profile(
  id: 'me-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g-1',
  name: 'Odak Grubu',
  inviteCode: 'ABC123',
  createdBy: _me.id,
  createdAt: DateTime(2026, 1, 1),
);

/// Gerçek veri: kart "kayıt yok" derse bu **yanlış** olsun diye dolu.
///
/// WP-817: başlangıç `agoWithinIstanbulToday` ile kuruluyor. Çıplak
/// `now - 2sa`, koşum 00:00–02:00 İstanbul arasına denk gelirse oturumu
/// **düne** düşürür; "bugünün toplamı" 0 çıkar ve test hatasız kodu suçlar
/// (v49 koşumunda tam olarak bu oldu). Gün toplamı `dayOf(start)` +
/// `durationSeconds` üzerinden geldiği için toplam yine tam 3600'dür.
final _sessions = <StudySession>[
  StudySession(
    id: 's-1',
    userId: _me.id,
    start: agoWithinIstanbulToday(const Duration(hours: 2)),
    end: DateTime.now(),
    durationSeconds: 3600,
    source: StudySource.live,
  ),
];

const _subjects = <Subject>[
  Subject(id: 'sub-1', userId: 'me-1', name: 'Matematik', color: 'chart-1'),
];

final _stats = <DailyStat>[
  DailyStat(userId: _me.id, day: DateTime.now(), seconds: 3600),
];

/// Kişisel kartlar yalnız oturum akışını bekler.
const _personalCards = <DashboardCardType>[
  // 🔴 WP-817: `goal` bu listede YOKTU. Kart oturum akışını
  // `todayRecordedSecondsProvider` üzerinden okuyup yükleme karesinde
  // "0sn / 4sa", "%0" ve 0 seri yazıyordu — üstelik aynı sahte 0, sıçrama
  // anında hedef kutlamasını da tetikliyordu (bkz.
  // `goal_celebration_wp817_test.dart`).
  DashboardCardType.goal,
  DashboardCardType.heatmap,
  DashboardCardType.hours,
  DashboardCardType.line,
  DashboardCardType.monthly,
  DashboardCardType.records,
  DashboardCardType.rhythm,
  DashboardCardType.scatter,
  DashboardCardType.today,
  DashboardCardType.weekdayWeekend,
  DashboardCardType.weekly,
];

const _groupCards = <DashboardCardType>[
  DashboardCardType.leaderboard,
  DashboardCardType.groupGoal,
  DashboardCardType.groupTrend,
];

/// 🔴 WP-817 — TAM kart kapısı UYGULANMAYAN kartlar, her biri GEREKÇESİYLE.
///
/// Bu harita bir muafiyet listesi değil, bir **fren**dir: aşağıdaki
/// `DashboardCardType` fren testi, her kart türünün ya yukarıdaki iki listede
/// ya da burada — adıyla ve gerekçesiyle — bulunmasını şart koşar. Kusurun asıl
/// sebebi buydu: `_personalCards` elle yazılmıştı, kodu taramıyordu, `goal` ve
/// `timer` sessizce dışarıda kalmıştı ve kimse kırmızı görmedi.
const _gateExemptCards = <DashboardCardType, String>{
  // Kart sayacın BAŞLAT/DURDUR kontrollerini taşır. Tüm kartı iskelete
  // çevirmek, oturumlar yüklenirken (hata hâlinde KALICI olarak) kullanıcının
  // sayacı başlatmasını engellerdi — çare hastalığından kötü olurdu. Bunun
  // yerine yalnız "Bugün" değeri dürüst yapıldı; bu dosyadaki üç `timer`
  // testi kontrolün canlı kaldığını ve sayının iddia edilmediğini ölçer.
  DashboardCardType.timer:
      'Sayaç kontrolleri her durumda canlı kalmalı; yalnız "Bugün" değeri '
          'bilinmiyor gösterir (bu dosyadaki timer testleri).',
  // Grup gerektiren kart: kendi kapısı `groupCardGate` + presence/üye akışları
  // için ayrı `ready`/`failed` dalları (`active_members_card.dart`).
  DashboardCardType.activeMembers:
      'Farklı kapı kullanır: groupCardGate + kendi ready/failed dalları.',
  // Cihaz içi görev listesi; oturum/grup akışına hiç bağlı değil.
  // ⚠️ Rozet sayısı `maybeWhen(orElse: () => 0)` ile çiziliyor — aynı sınıf bir
  // iddia. WP-817 kapsamı dışı, ayrı WP'ye not edildi.
  DashboardCardType.tasks:
      'Oturum/grup akışına bağlı değil; kendi userTasksProvider dalını çizer.',
  // Seçilen sınav tarihi cihazda tutulur; beklenen bir ağ turu yok. Tarih
  // seçilmemiş hâli boş kutu değil, `cardDataGate` ile aynı sözleşmede bir
  // boş durum gövdesidir (`dday_card.dart`).
  DashboardCardType.dday:
      'Cihaz içi veri; async kaynak yok, boş durumu kendi gövdesinde anlatır.',
};

/// Hiç emisyon yapmayan akış: cihazda ağ turunun beklendiği kare.
Stream<T> _pending<T>() => StreamController<T>().stream;

Future<void> _pumpCard(
  WidgetTester tester,
  DashboardCardType type, {
  required bool sessionsReady,
  required bool statsReady,
  bool sessionsFailed = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        userGroupProvider.overrideWithValue(AsyncData<StudyGroup?>(_group)),
        dailyGoalMinutesProvider.overrideWithValue(240),
        userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
        groupMembersProvider.overrideWith((ref) => Stream.value([_me])),
        groupAlphaScoresProvider.overrideWith(
          (ref) async => const <String, int>{},
        ),
        userSessionsProvider.overrideWith((ref) {
          if (sessionsFailed) {
            return Stream<List<StudySession>>.error('ağ yok');
          }
          return sessionsReady
              ? Stream.value(_sessions)
              : _pending<List<StudySession>>();
        }),
        groupDailyStatsProvider.overrideWith(
          (ref) =>
              statsReady ? Stream.value(_stats) : _pending<List<DailyStat>>(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: dashboardCardFor(
                type,
                DashboardCardSize.medium,
                height: 260,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Kartların yükleme karesinde **asla** yazmaması gereken iddialar.
List<String> _emptyClaims(AppLocalizations l10n) => [
  l10n.homeKayitYok,
  l10n.homeBugunHenuzCalismaKaydin,
];

/// Sayaç kartı için durağan bir notifier: gerçek [StudyTimerNotifier.build]
/// native kanala/prefs'e uzanır ve bu testin ölçtüğü şeyle ilgisi yoktur.
class _IdleTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

/// 🔴 WP-817 — sayaç kartı için AYRI harness.
///
/// Kart `cardDataGate` kullanmaz (kullanamaz, bkz. [_gateExemptCards]), bu
/// yüzden `_pumpCard`ın iskelet iddiası burada geçerli değil. Ölçülen şey
/// başka: kontrol duruyor mu, sayı iddia ediliyor mu.
///
/// Yükseklik 260 bilinçli: `kTimerCoreMaxHeight` (240) üstünde olduğu için
/// "Bugün" satırı ÇİZİLİR — yani ölçülen dal gerçekten uyarılır.
Future<void> _pumpTimerCard(
  WidgetTester tester, {
  required bool sessionsReady,
  bool sessionsFailed = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        userGroupProvider.overrideWithValue(AsyncData<StudyGroup?>(_group)),
        dailyGoalMinutesProvider.overrideWithValue(240),
        userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
        studyTimerProvider.overrideWith(_IdleTimerNotifier.new),
        userSessionsProvider.overrideWith((ref) {
          if (sessionsFailed) {
            return Stream<List<StudySession>>.error('ağ yok');
          }
          return sessionsReady
              ? Stream.value(_sessions)
              : _pending<List<StudySession>>();
        }),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: dashboardCardFor(
                DashboardCardType.timer,
                DashboardCardSize.medium,
                height: 260,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Başlat düğmesi ÇİZİLİ **ve** ölü değil. "Ağaçta var" yetmez: kapı yanlış
/// uygulanırsa düğme `onPressed: null` ile de duruyor olabilirdi.
void _expectStartControlAlive(WidgetTester tester, AppLocalizations l10n) {
  final start = find.widgetWithText(
    FilledButton,
    l10n.classroomCalismayaBasla,
  );
  expect(
    start,
    findsOneWidget,
    reason:
        'Sayaç kartı veri beklerken BAŞLAT kontrolünü kaybetmemeli; çare '
        'hastalıktan kötü olur.',
  );
  expect(
    tester.widget<FilledButton>(start).onPressed,
    isNotNull,
    reason: 'BAŞLAT çizili ama ölü — kullanıcı için farkı yok.',
  );
}

void main() {
  setUp(() {
    // `formatHumanSeconds` bağlamsız çalışır ve etkin dile bakar; koşum
    // makinesinin dili "0sn" iddiasını "0s"a çevirmesin.
    setActiveAppLocale(const Locale('tr'));
  });

  for (final type in _personalCards) {
    testWidgets('${type.name}: oturumlar gelmeden boş durum iddia etmiyor', (
      tester,
    ) async {
      await _pumpCard(tester, type, sessionsReady: false, statsReady: true);
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

      // Önce kullanıcıya görünen iddia ölçülür: kırık kodda hata mesajı
      // "iskelet yok" değil, ekranda duran yanlış cümleyi göstersin.
      for (final claim in _emptyClaims(l10n)) {
        expect(
          find.text(claim),
          findsNothing,
          reason: 'yanlış boş durum: $claim',
        );
      }
      // "0 dk" / "0 sa" gibi sıfır özetler de bir iddiadır.
      expect(find.textContaining(RegExp(r'^0\s*(dk|sa)')), findsNothing);
      expect(
        find.byKey(kCardSkeletonKey),
        findsOneWidget,
        reason: 'yükleniyorken yer tutucu çizilmeli',
      );
    });

    testWidgets('${type.name}: oturumlar gelince normal çiziliyor', (
      tester,
    ) async {
      await _pumpCard(tester, type, sessionsReady: true, statsReady: true);
      await tester.pump();

      expect(find.byKey(kCardSkeletonKey), findsNothing);
    });
  }

  for (final type in _groupCards) {
    testWidgets('${type.name}: grup istatistiği gelmeden boş çizilmiyor', (
      tester,
    ) async {
      await _pumpCard(tester, type, sessionsReady: true, statsReady: false);

      expect(find.byKey(kCardSkeletonKey), findsOneWidget);
      // Grup kartı davet kartına da düşmemeli: grup hazır, eksik olan veri.
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.homeGrupOlustur), findsNothing);
    });

    testWidgets('${type.name}: istatistik gelince normal çiziliyor', (
      tester,
    ) async {
      await _pumpCard(tester, type, sessionsReady: true, statsReady: true);
      await tester.pump();

      expect(find.byKey(kCardSkeletonKey), findsNothing);
    });
  }

  testWidgets('akış hata verirse sonsuz iskelet değil hata metni çizilir', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      DashboardCardType.records,
      sessionsReady: false,
      statsReady: true,
      sessionsFailed: true,
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.homeVerilerYuklenemedi), findsOneWidget);
    // Kart tuzağı: hatayı "yükleniyor" sayıp sonsuza kadar iskelet döndürmek.
    expect(find.byKey(kCardSkeletonKey), findsNothing);
  });

  // ── WP-817: sayaç kartı — kapı DEĞİL, dürüst sayı ───────────────────────
  //
  // Kart `dashboardCardFor` üzerinden çizilir, yani ana ekranın gerçek
  // yolundan. Ölçülen üç şey: kontrol yaşıyor mu, sayı iddia ediliyor mu,
  // hata söyleniyor mu.

  testWidgets('timer: oturumlar gelmeden BAŞLAT durur, sayı iddia edilmez', (
    tester,
  ) async {
    await _pumpTimerCard(tester, sessionsReady: false);
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

    _expectStartControlAlive(tester, l10n);
    expect(
      find.byKey(kCardSkeletonKey),
      findsNothing,
      reason:
          'Bu kart TAM kart kapısı KULLANMAZ; iskelete düşerse kontroller de '
          'kaybolur.',
    );
    expect(
      find.text(l10n.classroomBugun),
      findsOneWidget,
      reason: '"Bugün" etiketi kalmalı; kaybolan şey yalnız sahte sayı.',
    );
    expect(
      find.text(formatHumanSeconds(0)),
      findsNothing,
      reason:
          'Veri yokken "0sn" KESİN bir iddiadır: kaydı olan kullanıcı bugün '
          'hiç çalışmamış görünür.',
    );
    expect(
      find.text(kUnknownMetric),
      findsOneWidget,
      reason: 'Sayının yerine bilinmiyor göstergesi çizilmeli.',
    );
  });

  testWidgets('timer: akış hata verirse ölçülemediğini SÖYLER, 0 demez', (
    tester,
  ) async {
    await _pumpTimerCard(tester, sessionsReady: false, sessionsFailed: true);
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

    _expectStartControlAlive(tester, l10n);
    expect(find.text(formatHumanSeconds(0)), findsNothing);
    expect(find.text(kUnknownMetric), findsOneWidget);
    // 🔴 Hata KALICIDIR. Yalnız "—" çizmek "yükleniyor" gibi okunur ve
    // kullanıcı sonsuza kadar bekler; yanındaki "Bugünün özeti" kartı aynı
    // akış için zaten bu cümleyi çiziyor.
    expect(
      find.text(l10n.homeVerilerYuklenemedi),
      findsOneWidget,
      reason: 'Hata hâlinde ölçülemediği söylenmeli.',
    );
  });

  testWidgets('timer: oturumlar gelince gerçek sayı yazılır', (tester) async {
    await _pumpTimerCard(tester, sessionsReady: true);
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

    _expectStartControlAlive(tester, l10n);
    expect(
      find.text(kUnknownMetric),
      findsNothing,
      reason: 'Veri geldi; "—" kalıcı olamaz.',
    );
    expect(find.text(l10n.homeVerilerYuklenemedi), findsNothing);
    expect(
      find.text(formatHumanSeconds(3600)),
      findsOneWidget,
      reason: 'Düzeltme gerçek sayıyı da öldürmemeli.',
    );
  });

  // ── WP-817 freni: listeler koddan değil ELLE yazılıyor ──────────────────

  test('her DashboardCardType ya kapı testinde ya gerekçeli muafiyette', () {
    final covered = <DashboardCardType>{
      ..._personalCards,
      ..._groupCards,
      ..._gateExemptCards.keys,
    };
    final missing = DashboardCardType.values
        .where((type) => !covered.contains(type))
        .toList();
    expect(
      missing,
      isEmpty,
      reason:
          'Bu dosyadaki kart listeleri ELLE yazılmıştır, kodu taramaz. '
          'Listeye girmeyen kart sessizce kapısız kalır — WP-817 kusuru tam '
          'olarak buydu (goal ve timer 13 kartlık listenin dışındaydı). '
          'Yeni kartı ya bir kapı listesine ekle ya da _gateExemptCards\'a '
          'GEREKÇESİYLE yaz: $missing',
    );
  });

  test('bir kart hem kapı listesinde hem muafiyette olamaz', () {
    final gated = <DashboardCardType>{..._personalCards, ..._groupCards};
    final both = _gateExemptCards.keys.where(gated.contains).toList();
    expect(
      both,
      isEmpty,
      reason:
          'Çelişki: kart hem kapıya sokuluyor hem muaf sayılıyor — biri '
          'ölü iddiadır: $both',
    );
  });

  test('her muafiyetin boş olmayan bir gerekçesi var', () {
    for (final entry in _gateExemptCards.entries) {
      expect(
        entry.value.trim(),
        isNotEmpty,
        reason:
            '${entry.key.name} gerekçesiz muaf tutulmuş; gerekçesiz muafiyet '
            'listeyi tekrar sessiz bir kaçak yoluna çevirir.',
      );
    }
  });
}
