// WP-643 — Ana Sayfa kart envanteri: hangi kart, hangi hücrede, kaç piksel
// kart-içi kaydırma payı üretiyor?
//
// Sahibin cihaz raporu (2026-08-10): *"bazı kartlarda hâlâ gereksiz kart içinde
// aşağı yukarı kaydırma var; parmağım onların üstündeyse ana ekran takılıyor.
// Weekly rhythm ve sayaç kartı mesela. Kartı ne kadar büyütürsem büyüteyim gene
// var. başkaları da olabilir, her kartı kontrol et."*
//
// WP-508 bu sınıfı kapattığını söylüyordu; kapatmamış. Kapının ölçmediği şey:
// `card_scroll_gesture_wp508_test.dart` **altı** kartı, **tek** hücre boyutunda
// ve elle seçilmiş verilerle sınıyor. Burada `DashboardCardType`in **tamamı**
// üç ekran genişliği × üç hücre kutusunda ve dolu veriyle çizilir; kartın
// içindeki HER `Scrollable`ın `position.maxScrollExtent`i ölçülür.
//
// 🔴 Ölçünün seçimi (WP-632'den devralındı): dikey taşma istisna ATMAZ —
// kaydırıcı onu yutar. `takeException()` yeşil geçerken kullanıcı hâlâ kart
// içinde kaydırmak zorundadır. Tek dürüst ölçü `maxScrollExtent`tir:
// 0 = içerik sığıyor, jest dış sayfaya gider; > 0 = kart dikey jesti kendine
// alır ve ana ekran parmağın altında takılır.
//
// ⚠️ Boş veri taşmayı gizler (boş liste `ListView`i bile kurmaz). Bu yüzden
// sabitler DOLU: 5 ders, 90 günlük oturum geçmişi, grup + üyeler + günlük
// istatistikler, görevler, sınav kayıtları.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette değil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Ana Sayfa ızgarasının GERÇEK geometrisi (`home_screen.dart` → `_MatrixGrid`).
// Hücre karedir: `cell = (içerikGenişliği - 31*gap) / 32`; bir kart `w × h`
// hücre kaplar. Testin uydurduğu piksel değil, ürünün kendi formülü.
// ---------------------------------------------------------------------------
const double _kGap = 8.0;
const int _kColumns = 32;

double _cell(double contentWidth) =>
    (contentWidth - (_kColumns - 1) * _kGap) / _kColumns;

double _span(double contentWidth, int units) =>
    units * _cell(contentWidth) + (units - 1) * _kGap;

typedef _Screen = ({String name, double content});
typedef _Box = ({String name, int w, int h});

/// Dar telefon / geniş telefon / tablet-masaüstü okuma genişliği.
const List<_Screen> _screens = [
  (name: 'dar telefon', content: 328),
  (name: 'geniş telefon', content: 396),
  (name: 'tablet/masaüstü', content: 840),
];

/// Yarım genişlik (varsayılan yerleşimin `today`/`leaderboard` kutusu), tam
/// genişlik ve sahibin "ne kadar büyütürsem" dediği büyütülmüş kutu.
const List<_Box> _boxes = [
  (name: 'yarım 16×16', w: 16, h: 16),
  (name: 'tam 32×16', w: 32, h: 16),
  (name: 'büyütülmüş 32×26', w: 32, h: 26),
];

/// WP-643'ün düzelttiği kart: içeriği **sabit ölçülü bir görsel** olan 7×24
/// ritim ızgarası. Bu bir desendir — parça parça kaydırılarak değil bütün
/// hâlinde okunur; kaydırıcı yerine ölçekleme kullanır ve hiçbir hücrede dikey
/// jest yutmaz.
const _fixedByWp643 = {DashboardCardType.rhythm};

// ---------------------------------------------------------------------------
// Dolu veri
// ---------------------------------------------------------------------------
final DateTime _now = DateTime.now();

final _me = Profile(
  id: 'u1',
  displayName: 'Ben',
  createdAt: DateTime(2026, 1, 1),
  dailyGoalMinutes: 240,
);

Profile _member(int i) =>
    Profile(id: 'u$i', displayName: 'Üye $i', createdAt: DateTime(2026, 1, 1));

const _subjects = <Subject>[
  Subject(id: 's1', userId: 'u1', name: 'Matematik', color: 'chart-1'),
  Subject(id: 's2', userId: 'u1', name: 'Fizik', color: 'chart-2'),
  Subject(id: 's3', userId: 'u1', name: 'Kimya', color: 'chart-3'),
  Subject(id: 's4', userId: 'u1', name: 'Biyoloji', color: 'chart-4'),
  Subject(id: 's5', userId: 'u1', name: 'Türkçe', color: 'chart-5'),
];

/// 90 gün × günde 2 oturum, farklı saatlerde ve farklı derslerde: ısı haritası,
/// ritim, dağılım, eğilim ve rekor kartlarının hepsi gerçek veriyle dolar.
List<StudySession> _sessions() {
  final out = <StudySession>[];
  for (var d = 0; d < 90; d++) {
    for (var k = 0; k < 2; k++) {
      final day = DateTime(
        _now.year,
        _now.month,
        _now.day,
      ).subtract(Duration(days: d));
      final start = day.add(Duration(hours: 9 + (d + k * 7) % 12));
      out.add(
        StudySession(
          id: 'ses-$d-$k',
          userId: 'u1',
          subjectId: _subjects[(d + k) % _subjects.length].id,
          start: start,
          end: start.add(const Duration(minutes: 55)),
          durationSeconds: 55 * 60,
          source: StudySource.live,
        ),
      );
    }
  }
  return out;
}

final _group = StudyGroup(
  id: 'g1',
  name: 'Odak Grubu',
  inviteCode: 'ABC123',
  createdBy: 'u1',
  createdAt: DateTime(2026, 1, 1),
);

/// Kasten **mütevazı** üye sayısı: 12 üyelik bir liste 160 px hücreye zaten
/// sığmaz ve orada kaydırmak DOĞRUdur (WP-497). Ölçülmek istenen şey, makul
/// bir listenin bile kartı kaydırıcıya düşürüp düşürmediği.
const int _memberCount = 3;

List<Profile> _members() => [for (var i = 1; i <= _memberCount; i++) _member(i)];

List<Presence> _presences() => [
  for (var i = 1; i <= _memberCount; i++)
    Presence(
      userId: 'u$i',
      groupId: _group.id,
      status: PresenceStatus.studying,
      todaySeconds: 3600 * i,
      startedAt: DateTime(2026, 1, 1, 9).add(Duration(minutes: i)),
    ),
];

List<DailyStat> _groupStats() {
  final today = DateTime(_now.year, _now.month, _now.day);
  return [
    for (var d = 0; d < 30; d++)
      for (var i = 1; i <= _memberCount; i++)
        DailyStat(
          userId: 'u$i',
          day: today.subtract(Duration(days: d)),
          seconds: 1800 * (i + 1),
        ),
  ];
}

List<UserTask> _tasks() => [
  for (var i = 1; i <= 3; i++)
    UserTask(
      id: 't$i',
      title: 'Görev $i',
      completed: false,
      createdAt: DateTime(2026, 1, 1),
      sortOrder: i,
    ),
];

/// Gerçek notifier kanal/dinleyici kurar; sahne hiç durulmaz
/// (`goal_streak_badge_wp496_test.dart` ile aynı desen).
class _IdleTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

List<Override> _overrides(
  SharedPreferences prefs,
  InMemoryUserTaskRepository repo,
) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  authStateProvider.overrideWith((ref) => Stream.value(_me)),
  userSessionsProvider.overrideWith((ref) => Stream.value(_sessions())),
  userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
  userStudySummaryProvider.overrideWith(
    (ref) async => const UserStudySummary(
      lifetimeSeconds: 900000,
      yearSeconds: 800000,
      hotWindowSeconds: 594000,
    ),
  ),
  todayRecordedSecondsProvider.overrideWithValue(7200),
  dailyGoalMinutesProvider.overrideWithValue(240),
  userGroupProvider.overrideWithValue(AsyncValue.data(_group)),
  groupMembersProvider.overrideWith((ref) => Stream.value(_members())),
  groupPresenceProvider.overrideWith((ref) => Stream.value(_presences())),
  groupDailyStatsProvider.overrideWith((ref) => Stream.value(_groupStats())),
  groupAlphaScoresProvider.overrideWith(
    (ref) async => {for (var i = 1; i <= _memberCount; i++) 'u$i': 100 * i},
  ),
  userTaskRepositoryProvider.overrideWithValue(repo),
  studyTimerProvider.overrideWith(_IdleTimerNotifier.new),
];

final _cardKey = GlobalKey();

Future<void> _pumpCell(
  WidgetTester tester, {
  required DashboardCardType type,
  required _Screen screen,
  required _Box box,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    kExamListKey: encodeExamList(
      ExamListState(
        entries: [
          ExamEntry(id: 'e1', name: 'YKS', day: DateTime(2027, 6, 20)),
          ExamEntry(id: 'e2', name: 'AYT', day: DateTime(2027, 6, 21)),
          ExamEntry(id: 'e3', name: 'Deneme', day: DateTime(2027, 3, 1)),
        ],
        priorityId: 'e1',
      ),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  final repo = InMemoryUserTaskRepository();
  await repo.saveAll(userKey: _me.id, tasks: _tasks());

  final width = _span(screen.content, box.w);
  final height = _span(screen.content, box.h);
  final outer = ScrollController();
  addTearDown(outer.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(prefs, repo),
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          // Ana Sayfa'nın gerçek kabuğu: dış sayfa kaydırıcısı + hücre.
          // Kabuğu taklit etmeyen kurulum bu hatayı göremez (WP-508 dersi).
          body: SingleChildScrollView(
            controller: outer,
            child: Column(
              children: [
                SizedBox(
                  width: width,
                  height: height,
                  child: KeyedSubtree(
                    key: _cardKey,
                    child: dashboardCardFor(
                      type,
                      DashboardCardConfig(
                        type,
                        w: box.w,
                        h: box.h,
                      ).sizeForColumns(_kColumns),
                      height: height,
                    ),
                  ),
                ),
                // Dış sayfanın gerçekten kayacak yeri olsun.
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  // `pumpAndSettle` kullanılmıyor: saniyelik ticker'lar sahneyi hiç durdurmaz.
  await tester.pump();
  await tester.pump();
}

/// Karttaki her `Scrollable` için (eksen, kaydırma payı).
List<({Axis axis, double extent})> _extents(WidgetTester tester) {
  final out = <({Axis axis, double extent})>[];
  final found = find.descendant(
    of: find.byKey(_cardKey),
    matching: find.byType(Scrollable),
  );
  for (final element in found.evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    if (!state.position.hasContentDimensions) continue;
    out.add((
      // AxisDirection: up=0, right=1, down=2, left=3.
      axis: state.axisDirection.index.isEven ? Axis.vertical : Axis.horizontal,
      extent: state.position.maxScrollExtent,
    ));
  }
  return out;
}

/// Dikey kaydırma payının en büyüğü — sahibin şikâyeti tam olarak bu eksen.
double _verticalOverflow(WidgetTester tester) {
  var worst = 0.0;
  for (final e in _extents(tester)) {
    if (e.axis != Axis.vertical) continue;
    if (e.extent > worst) worst = e.extent;
  }
  return worst;
}

// ---------------------------------------------------------------------------
// ÇITA (ratchet) — WP-643'te ÖLÇÜLEN durum.
//
// Buradaki sayılar bir hedef değil, **fotoğraftır**: kartın o hücrede kaç
// piksel kart-içi kaydırma payı ürettiği. Listelenmeyen her (kart, ekran,
// kutu) üçlüsünün payı 0 olmak ZORUNDADIR. Bir kart yoğunlaşır ya da yeni bir
// kart kaydırıcıyla gelirse bu kapı kırmızı döner.
//
// Sıfırdan büyük her satır bir borçtur; gerekçesi teslim raporunda ve ilgili
// WP kartındadır. Hedef hepsinin 0'a inmesi.
// ---------------------------------------------------------------------------
String _k(DashboardCardType t, _Screen s, _Box b) =>
    '${t.name}|${s.name}|${b.name}';

const Map<String, double> _budget = {
  // 🔴 `study_timer_card.dart` — jest kusuru WP-646'da kapandı, YOĞUNLUK ise
  // WP-662'de: küçük hücrede kartın yalnız ÇEKİRDEĞİ (geçen süre + Başlat/
  // Durdur) çizilir; ders seçici hapı, günlük hedef çubuğu, mod seçici ve
  // "manuel süre ekle" gizlenir. Geniş telefonun ÜÇ hücresi tamamen 0'a indi
  // (345.7 / 359.0 / 232.8 → 0, yani satırları buradan silindi); dar telefonun
  // üçü ise 432.9 → 34.7, 358.0 → 2.0, 253.0 → 11.0.
  //
  // 🔴 Kalan borç (tablet 416 px yüksek hücreler): orası "küçük hücre" değil,
  // TAM kartın çizildiği yerdir ve tam kart 416 px genişlikte ~543 px istiyor.
  // Orada hangi satırın gizleneceği ayrı bir ÜRÜN kararıdır (sahibe önizlemeyle
  // sorulur); WP-662'ye verilen dört kararın içinde değildi, düşürülmedi.
  'timer|dar telefon|yarım 16×16': 34.7,
  'timer|dar telefon|tam 32×16': 2.0,
  'timer|dar telefon|büyütülmüş 32×26': 11.0,
  'timer|tablet/masaüstü|yarım 16×16': 126.0,
  'timer|tablet/masaüstü|tam 32×16': 132.0,

  // Aşağıdakiler GERÇEK taşmadır: içerik o hücreye sığmıyor ve kaydırıcı
  // WP-497 güvenlik ağıdır (sığmayan satır tamamen kaybolmasın). Hepsi
  // hücre büyütülünce 0'a iner — sahibin "büyütünce de var" şikâyeti bu
  // kartlar için geçerli değil.
  'goal|dar telefon|yarım 16×16': 34.0,
  'goal|dar telefon|tam 32×16': 50.0,
  'goal|geniş telefon|tam 32×16': 16.0,
  'today|dar telefon|tam 32×16': 8.0,
  'monthly|dar telefon|yarım 16×16': 84.0,
  'monthly|dar telefon|tam 32×16': 56.0,
  'groupGoal|dar telefon|yarım 16×16': 31.5,
  'groupGoal|geniş telefon|yarım 16×16': 1.9,
  'activeMembers|dar telefon|yarım 16×16': 98.8,
  'activeMembers|dar telefon|tam 32×16': 98.8,
  'activeMembers|geniş telefon|yarım 16×16': 64.8,
  'activeMembers|geniş telefon|tam 32×16': 64.8,
  'tasks|dar telefon|tam 32×16': 4.0,

  // 🔴 `heatmap` — içerik boyu SABİT (~154 px), kart uzasa da kısalsa da
  // değişmiyor; düzeltmesi `study_heatmap.dart`ı gerektiriyor (bu lane'in
  // SAHİP yolu değil). Bkz. `heatmap_card.dart` içindeki WP-643 notu.
  'heatmap|dar telefon|yarım 16×16': 70.0,
  'heatmap|dar telefon|tam 32×16': 70.0,
  'heatmap|geniş telefon|yarım 16×16': 36.0,
  'heatmap|geniş telefon|tam 32×16': 36.0,

  // 🔴 `records_card.dart` hücre BÜYÜTÜLDÜĞÜNDE de kaydırıcıda kalıyor;
  // düzeltmesi yoğunluk (kaç döşeme) kararı gerektiriyor, yani sahibin
  // önizleme göreceği bir iş. Ölçüler teslim raporunda; lider ayrı WP açacak.
  'records|dar telefon|yarım 16×16': 648.0,
  'records|dar telefon|tam 32×16': 316.0,
  'records|dar telefon|büyütülmüş 32×26': 211.0,
  'records|geniş telefon|yarım 16×16': 418.0,
  'records|geniş telefon|tam 32×16': 210.0,
  'records|geniş telefon|büyütülmüş 32×26': 83.8,

  // ✅ `leaderboard` — artık HİÇBİR hücrede kart-içi kaydırma yok. WP-659 dört
  // satırdan üçünü (22.9 / 18.3 / 42.3) düşürdü, WP-662 kalanı (17.0) kapattı:
  // "geniş ama kısa" hücrede grup hedefi bloğu artık çizilmiyor (görünürlük
  // kararı yalnız GENİŞLİĞE bakıyordu, sorun YÜKSEKLİKTİ) ve kısa hücrede satır
  // sıkıştırılmış varyanta geçiyor (54 → 34 px), böylece 160×160 hücre tek kişi
  // yerine iki kişi gösteriyor. Bkz. `leaderboard_dense_row_wp662_test.dart`.
};

/// Kart-içi kaydırma DEĞİL, düpedüz kırpma: gövde `RenderFlex` taşması veriyor
/// (içerik kesiliyor, kaydırıcı bile yok). Ayrı bir kusur sınıfı.
///
/// ✅ WP-659'da **boşaldı**. Üç kayıt vardı, üçü de 160×160 hücrede:
///   `timer`          10 px — üst şeritteki 3 × 48 px düğme 134 px'e sığmıyor
///                    (+ 17 px, ders seçici hapındaki çıplak `Text`)
///   `hours`           8 px — başlık `Text` sınırsız satırlı, 72 px'e (3 satır)
///                    sarıp gövdeyi yiyordu
///   `weekdayWeekend` 22 px — aynı kusur, başlık 96 px (4 satır)
///
/// 🔴 Liste **büyümemeli** ve yeniden doldurulmamalı: buraya bir kart eklemek
/// "kullanıcının göremediği içerik" eklemek demektir.
const Set<String> _knownRenderFlex = <String>{};

void main() {
  // 840 px içerik genişliği varsayılan 800×600 test penceresine sığmaz;
  // görünüm alanı yetmezse kart kırpılır ve ölçüm yalan söyler.
  void widen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('WP-643 sözleşme — sabit ölçülü görsel kartlar hiç jest yutmaz', () {
    // Ritim ve takvim kartlarının içeriği kartın boyuna göre büyüyüp
    // küçülmüyordu: `WeekHourHeatmap` yatay kaydırıcıdan SINIRSIZ genişlik
    // alıp 320 px'lik sabit yedeğine düşüyor, `StudyHeatmap` ise 13 px sabit
    // hücreyle hep ~154 px boyunda çiziliyordu. Kart ne kadar büyütülürse
    // büyütülsün dikey kaydırıcı ayakta kalıyordu (sahip: "gene var").
    for (final type in _fixedByWp643) {
      for (final screen in _screens) {
        for (final box in _boxes) {
          testWidgets('${type.name} · ${screen.name} · ${box.name}', (
            tester,
          ) async {
            widen(tester);
            await _pumpCell(tester, type: type, screen: screen, box: box);
            expect(tester.takeException(), isNull);
            expect(
              _verticalOverflow(tester),
              0,
              reason:
                  '${type.name}: içerik ${screen.name} / ${box.name} hücresine '
                  'sığmadığı için kart dikey sürüklemeyi kendine alıyor; '
                  'parmak kartın üstündeyken ana ekran kaymaz.',
            );
          });
        }
      }
    }
  });

  group('envanter çıtası — her kart × her hücre', () {
    for (final type in DashboardCardType.values) {
      for (final screen in _screens) {
        for (final box in _boxes) {
          final key = _k(type, screen, box);
          testWidgets('${type.name} · ${screen.name} · ${box.name}', (
            tester,
          ) async {
            widen(tester);
            await _pumpCell(tester, type: type, screen: screen, box: box);

            if (!_knownRenderFlex.contains(key)) {
              expect(
                tester.takeException(),
                isNull,
                reason: '$key: gövde kırpılıyor (RenderFlex taşması).',
              );
            } else {
              // Bilinen kırpma; ayrı kusur sınıfı, ayrı WP.
              tester.takeException();
            }

            // +0.5 px yalnız kayan nokta payı (hücre genişliği 32'ye
            // bölünüyor); bir kartın yoğunlaşmasını gizleyecek kadar değil.
            final allowed = (_budget[key] ?? 0.0) + 0.5;
            expect(
              _verticalOverflow(tester),
              lessThanOrEqualTo(allowed),
              reason:
                  '$key: kart-içi dikey kaydırma payı ölçülen çıtayı aştı '
                  '(izin $allowed px). Kart yoğunlaştıysa düzeni sıkıştır; '
                  'kaydırıcı gereksizse kaldır — çıtayı yükseltme.',
            );
          });
        }
      }
    }
  });
}
