// WP-455: seri ve bütün ilerleme kabul matrisi.
//
// WP-453 seri motorunu, WP-454 alevi tek tek doğrulamıştı. Burada ölçülen şey
// **aralarındaki** davranış: aynı olay akışının modelde, projeksiyonda ve
// ekranda aynı sayıyı üretmesi; kişisel/grup kapsamlarının birbirini
// beslememesi; ve seri dışı kavramların (görev, oturum türü, uygulama açılışı)
// seriye sızmaması.
//
// Sunucu eşi: `supabase/tests/038_progression_matrix.test.sql`. Sözleşmenin iki
// ucu ayrı ayrı yaşamamalı — WP-373'te tam olarak bu yüzden bir özellik aylarca
// ölü kaldı.
//
// 🔴 Bu dosyanın en önemli bölümü en sonda: `seri kelimesinin üç farklı
// tanımı`. Kartın kabul kriteri "UI/server state farkı 0" ve şu an bu kriter
// SAĞLANMIYOR. Test bunu gizlemek yerine ölçüp sabitliyor.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/gamification.dart';
import 'package:online_study_room/core/stats/goal_streak_projection.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/goal_streak_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_goal_streak_repository.dart';
import 'package:online_study_room/features/stats/widgets/goal_streak_flame.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _alpha = GoalStreakScope.personal('user-alpha');
const _group = GoalStreakScope.group(
  groupId: 'group-1',
  timeZone: 'Europe/Istanbul',
);

String _wireDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Sunucunun yazdığı kanonik olayın istemci eşi.
///
/// `eventKey` biçimi bilerek `0112`deki `v_key` ile birebir aynı üretiliyor;
/// aşağıdaki `olay anahtarı biçimi sunucuyla aynı` testi bunu migration'ın
/// kendisine karşı doğruluyor.
GoalProgressEvent _event(
  DateTime day, {
  GoalStreakScope scope = _alpha,
  GoalProgressEventKind kind = GoalProgressEventKind.goalCompleted,
  String? key,
}) => GoalProgressEvent(
  eventKey: key ?? '${scope.ledgerKey}:${kind.wireValue}:${_wireDay(day)}',
  scope: scope,
  kind: kind,
  goalDay: day,
  occurredAt: DateTime.utc(day.year, day.month, day.day, 12),
);

DateTime _july(int day) => DateTime.utc(2026, 7, day);

GoalStreakProjection _project(
  List<DateTime> completedDays, {
  GoalStreakScope scope = _alpha,
  required DateTime asOf,
}) => projectGoalStreak(
  scope: scope,
  events: [for (final day in completedDays) _event(day, scope: scope)],
  asOfDay: asOf,
);

StudySession _session({
  required DateTime start,
  required int seconds,
  StudySource source = StudySource.live,
  String id = 's',
}) => StudySession(
  id: id,
  userId: 'user-alpha',
  start: start,
  end: start.add(Duration(seconds: seconds)),
  durationSeconds: seconds,
  source: source,
);

/// Projeksiyonu provider zinciri üzerinden okur.
///
/// 🔴 Abonelik şart. Riverpod 3'te dinleyicisi olmayan family provider okuma
/// sırasında dispose edilir; `.future` o zaman "disposed during loading state"
/// ile hiç tamamlanmaz ve test 30 saniye asılı kalır. Bu tam olarak burada
/// yaşandı — doğrudan `container.read(...future)` çağıran ilk sürüm asıldı.
Future<GoalStreakProjection> _readProjection(
  ProviderContainer container,
  GoalStreakScope scope,
) async {
  final sub = container.listen(goalStreakProjectionProvider(scope), (_, _) {});
  try {
    return await container.read(goalStreakProjectionProvider(scope).future);
  } finally {
    sub.close();
  }
}

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  // ==========================================================================
  // 1. Yanlış artış 0 — hangi olay seriyi ilerletir
  // ==========================================================================
  group('yanlış artış 0', () {
    test('tamamlandı ilerletir; açıldı/sayaç/kısmi ilerletmez', () {
      // Kartın birincil şikâyeti: "uygulamayı açmakla seri ilerliyor".
      final helpers = [
        GoalProgressEventKind.appOpened,
        GoalProgressEventKind.timerStarted,
        GoalProgressEventKind.partialProgress,
      ];

      final onlyHelpers = projectGoalStreak(
        scope: _alpha,
        events: [
          for (final kind in helpers) _event(_july(3), kind: kind),
        ],
        asOfDay: _july(3),
      );
      expect(onlyHelpers.currentStreak, 0);
      expect(onlyHelpers.completionCount, 0);
      expect(onlyHelpers.state, GoalStreakState.empty);

      // Aynı gün gerçek tamamlama gelince 1 olur: yukarıdaki 0 iddiası
      // "her zaman 0" değil, yardımcı olayların elendiğini gösteriyor.
      final withCompletion = projectGoalStreak(
        scope: _alpha,
        events: [
          for (final kind in helpers) _event(_july(3), kind: kind),
          _event(_july(3)),
        ],
        asOfDay: _july(3),
      );
      expect(withCompletion.currentStreak, 1);
      expect(withCompletion.completionCount, 1);
    });

    test('gelecek günün tamamlaması bugünkü seriye girmez', () {
      // Cihaz saatini ileri alan biri seriyi uzatamamalı.
      final projection = _project(
        [_july(3), _july(4), _july(5)],
        asOf: _july(3),
      );
      expect(projection.currentStreak, 1);
      expect(projection.completionCount, 1);
      expect(projection.lastCompletedDay, _july(3));
    });

    test('repository arayüzünde seri yazma yolu yok', () {
      // İstemci tarafında "kısmi süre seriyi ilerletmez" güvencesinin yapısal
      // hâli budur: arayüzde yazacak bir metot YOKTUR, tek yazıcı sunucudaki
      // `record_goal_completion`dur.
      //
      // İsim aramak yerine (`contains('record')` gibi) DÖNÜŞ TÜRÜ ölçülüyor:
      // `Future<bool> markCompleted(...)` gibi başka adlı bir yazma metodu
      // isim taramasından kaçardı, bu iddiadan kaçamaz.
      final source = File(
        'lib/data/repositories/goal_streak_repository.dart',
      ).readAsStringSync();
      final body = source.substring(
        source.indexOf('abstract class GoalStreakRepository'),
      );
      final returnTypes = RegExp(r'^ {2}([\w<>, ?]+?)\s+\w+\(', multiLine: true)
          .allMatches(body)
          .map((match) => match.group(1)!.trim())
          .toList();

      expect(
        returnTypes,
        isNotEmpty,
        reason: 'imza çıkarılamadıysa bu test sessizce boşa düşer',
      );
      for (final type in returnTypes) {
        expect(
          type,
          contains('GoalStreakProjection'),
          reason: '$type döndüren üye bir okuma değil: seri istemciden '
              'yazılabilir hâle gelmiş',
        );
      }
    });
  });

  // ==========================================================================
  // 2. Tek kaçırma / iki kaçırma / tekrar grace
  // ==========================================================================
  group('kaçırma ve grace', () {
    test('tek kaçırma seriyi korur', () {
      final projection = _project([_july(1), _july(3)], asOf: _july(3));
      expect(projection.currentStreak, 2);
      expect(projection.state, GoalStreakState.completedToday);
    });

    test('iki ardışık kaçırma sıfırlar ama tamamlama sayısını silmez', () {
      final projection = _project([_july(1), _july(3)], asOf: _july(6));
      expect(projection.currentStreak, 0);
      expect(projection.state, GoalStreakState.expired);
      expect(
        projection.completionCount,
        2,
        reason: 'seri sıfırlansa da geçmiş tamamlamalar kaybolmaz',
      );
    });

    test('grace tek seferlik joker DEĞİL, her tek kaçırmada tekrar uygulanır', () {
      // Kart bunu açıkça istiyor: tamamla-boş-tamamla-boş-tamamla = 3.
      // Tek seferlik joker olsaydı ikinci boşlukta seri kırılır, 1 çıkardı.
      final projection = _project(
        [_july(1), _july(3), _july(5)],
        asOf: _july(5),
      );
      expect(projection.currentStreak, 3);

      // Beş boşluklu gün: joker sayısı tükenmiyor.
      final longer = _project(
        [_july(1), _july(3), _july(5), _july(7), _july(9), _july(11)],
        asOf: _july(11),
      );
      expect(
        longer.currentStreak,
        6,
        reason: 'grace tüketilen bir bakiye olsaydı burada seri kırılırdı',
      );
    });

    test('durum geçişleri gün mesafesine bağlı: 0/1/2/3', () {
      const expected = {
        0: GoalStreakState.completedToday,
        1: GoalStreakState.pendingToday,
        2: GoalStreakState.atRisk,
        3: GoalStreakState.expired,
      };
      for (final entry in expected.entries) {
        final projection = _project(
          [_july(5)],
          asOf: _july(5 + entry.key),
        );
        expect(
          projection.state,
          entry.value,
          reason: '${entry.key} gün sonra durum ${entry.value} olmalı',
        );
      }
    });

    test('at_risk otomatik grace ile korunuyor olarak işaretlenir', () {
      final projection = _project([_july(3), _july(5)], asOf: _july(7));
      expect(projection.isProtectedByAutomaticGrace, isTrue);
      expect(projection.currentStreak, 2);
    });
  });

  // ==========================================================================
  // 3. Kişisel–grup sızıntısı 0
  // ==========================================================================
  group('kişisel-grup sızıntısı 0', () {
    test('aynı gün iki kapsam birbirini beslemez', () {
      final events = [
        _event(_july(1), scope: _alpha),
        _event(_july(2), scope: _alpha),
        _event(_july(1), scope: _group),
      ];

      final personal = projectGoalStreak(
        scope: _alpha,
        events: events,
        asOfDay: _july(2),
      );
      final group = projectGoalStreak(
        scope: _group,
        events: events,
        asOfDay: _july(2),
      );

      expect(personal.currentStreak, 2);
      expect(group.currentStreak, 1, reason: 'grup yalnız kendi olayını görür');
      expect(personal.completionCount, 2);
      expect(group.completionCount, 1);
      // Sızıntı olsaydı ikisi de 3 görürdü.
      expect(personal.completionCount + group.completionCount, 3);
    });

    test('kapsam anahtarı tür + kimlik; aynı kimlik iki ledger demektir', () {
      const sameIdPersonal = GoalStreakScope.personal('shared-id');
      const sameIdGroup = GoalStreakScope.group(
        groupId: 'shared-id',
        timeZone: 'Europe/Istanbul',
      );
      expect(sameIdPersonal.ledgerKey, isNot(sameIdGroup.ledgerKey));
      expect(sameIdPersonal, isNot(sameIdGroup));

      final events = [
        _event(_july(1), scope: sameIdGroup),
        _event(_july(2), scope: sameIdGroup),
      ];
      expect(
        projectGoalStreak(
          scope: sameIdPersonal,
          events: events,
          asOfDay: _july(2),
        ).completionCount,
        0,
        reason: 'aynı kimlik farklı tür: kişisel ledger grubunkini görmemeli',
      );
    });

    test('grup kendi saat dilimini taşır, kişisel Europe/Istanbul', () {
      const tokyo = GoalStreakScope.group(
        groupId: 'group-tokyo',
        timeZone: 'Asia/Tokyo',
      );
      expect(_alpha.timeZone, 'Europe/Istanbul');
      expect(tokyo.timeZone, 'Asia/Tokyo');
      // Saat dilimi kapsam kimliğinin parçası: farklı bölge farklı ledger.
      expect(
        tokyo,
        isNot(
          const GoalStreakScope.group(
            groupId: 'group-tokyo',
            timeZone: 'Europe/Istanbul',
          ),
        ),
      );
    });
  });

  // ==========================================================================
  // 4. Çift artış / çift ödül 0
  // ==========================================================================
  group('çift artış ve çift ödül 0', () {
    test('aynı olay iki kez gelirse tek sayılır', () {
      final duplicated = [
        _event(_july(1)),
        _event(_july(1)),
        _event(_july(2)),
      ];
      final projection = projectGoalStreak(
        scope: _alpha,
        events: duplicated,
        asOfDay: _july(2),
      );
      expect(projection.currentStreak, 2);
      expect(projection.completionCount, 2, reason: 'üç olay ama iki gün');
    });

    test('aynı anahtar çelişkili içerikle gelirse sessizce kabul edilmez', () {
      // Aktarım katmanı bir anahtarı yeniden kullanırsa bu bir veri hatasıdır;
      // sessiz kabul, serinin sebebini gözden kaybetmek olurdu.
      expect(
        () => projectGoalStreak(
          scope: _alpha,
          events: [
            _event(_july(1), key: 'collide'),
            _event(_july(2), key: 'collide'),
          ],
          asOfDay: _july(2),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('bellek-içi ledger aynı olayı iki kez yutmaz', () async {
      final repo = InMemoryGoalStreakRepository(now: () => _july(2));
      addTearDown(repo.dispose);

      repo.ingestCanonicalEvent(_event(_july(1)));
      repo.ingestCanonicalEvent(_event(_july(1)));
      repo.ingestCanonicalEvent(_event(_july(2)));

      final projection = await repo.readProjection(_alpha, asOfDay: _july(2));
      expect(projection.completionCount, 2);
      expect(projection.currentStreak, 2);
    });

    test('olay anahtarı biçimi sunucuyla aynı', () {
      // 🔴 Çift artışın gerçek savunması şemadaki unique kısıt ve anahtar
      // biçimidir. İstemci başka bir biçim üretirse iki uç aynı olayı iki
      // farklı olay sanar ve seri iki kat artar.
      final migration = File(
        '../supabase/migrations/0112_goal_streak_projection.sql',
      ).readAsStringSync();
      expect(
        migration,
        contains(
          "v_key := p_scope_type || ':' || p_scope_id::text || "
          "':goal_completed:' || p_day::text;",
        ),
        reason: 'sunucu anahtar biçimi değişti; istemci eşi de güncellenmeli',
      );
      expect(
        _event(_july(1)).eventKey,
        'personal:user-alpha:goal_completed:2026-07-01',
      );
      expect(
        migration,
        contains('unique (scope_type, scope_id, event_kind, goal_day)'),
        reason: 'çift artış savunması şemada durmalı',
      );
    });
  });

  // ==========================================================================
  // 5. Gün sınırı: 23:59 / 00:01
  // ==========================================================================
  group('gün sınırı', () {
    test('23:59 ve 00:01 farklı hedef günlerine düşer', () {
      // Europe/Istanbul kalıcı UTC+3.
      final before = DateTime.utc(2026, 7, 5, 20, 59, 59);
      final after = DateTime.utc(2026, 7, 5, 21, 0, 1);
      expect(istanbulDay(before), DateTime(2026, 7, 5));
      expect(istanbulDay(after), DateTime(2026, 7, 6));

      // Gece yarısını saran iki oturum iki ayrı hedef günü besler; tek gün
      // sayılsaydı seri bir gün eksik kalırdı.
      final projection = _project([_july(5), _july(6)], asOf: _july(6));
      expect(projection.currentStreak, 2);
      expect(projection.completionCount, 2);
    });

    test('gün sınırı UTC değil İstanbul gününe göre kesilir', () {
      // 21:00Z–23:59Z aralığı UTC'de hâlâ 5 Temmuz, İstanbul'da 6 Temmuz.
      // Motor UTC gününe baksaydı bu oturum yanlış güne yazılırdı.
      final session = _session(
        start: DateTime.utc(2026, 7, 5, 22, 30),
        seconds: 3600,
      );
      expect(session.start.toUtc().day, 5);
      expect(istanbulDay(session.start), DateTime(2026, 7, 6));
      expect(dailyTotals([session]).keys.single, DateTime(2026, 7, 6));
    });
  });

  // ==========================================================================
  // 6. Oturum türü ayrımcılığı yok
  // ==========================================================================
  group('oturum türü', () {
    test('manual/native/pomodoro/countdown aynı günü aynı besler', () {
      // Kodda ayrım iki kaynağa iner: kronometre/geri sayım/pomodoro üçü de
      // `StudySource.live` yazar (study_providers.dart), elle giriş `manual`.
      // Hedef hesabı kaynağa bakmamalı.
      final day = DateTime.utc(2026, 7, 5, 9);
      final liveOnly = dailyTotals([
        _session(start: day, seconds: 1800, id: 'a'),
        _session(start: day.add(const Duration(hours: 2)), seconds: 1800, id: 'b'),
      ]);
      final manualOnly = dailyTotals([
        _session(start: day, seconds: 1800, source: StudySource.manual, id: 'c'),
        _session(
          start: day.add(const Duration(hours: 2)),
          seconds: 1800,
          source: StudySource.manual,
          id: 'd',
        ),
      ]);
      final mixed = dailyTotals([
        _session(start: day, seconds: 1800, id: 'e'),
        _session(
          start: day.add(const Duration(hours: 2)),
          seconds: 1800,
          source: StudySource.manual,
          id: 'f',
        ),
      ]);

      expect(liveOnly[DateTime(2026, 7, 5)], 3600);
      expect(manualOnly[DateTime(2026, 7, 5)], 3600);
      expect(mixed[DateTime(2026, 7, 5)], 3600);
    });

    test('sıfır/negatif süreli oturum güne katkı vermez', () {
      final zero = _session(start: DateTime.utc(2026, 7, 5, 9), seconds: 0);
      expect(dailyTotals([zero])[DateTime(2026, 7, 5)], 0);
    });
  });

  // ==========================================================================
  // 7. Görev tamamlama / geri alma seriye sızmaz
  // ==========================================================================
  group('görev tamamlama seriye sızmaz', () {
    test('görev olayı hedef olayı değildir', () {
      // WP-451 görev tamamlamanın çalışma süresi üretmediğini ölçtü; burada
      // ölçülen bir sonraki halka: süre üretmediği için hedef olayı da
      // üretemez, dolayısıyla seri ilerlemez.
      final before = _project([_july(1)], asOf: _july(1));
      expect(before.currentStreak, 1);

      // Görev tarafında ne olursa olsun kanonik olay listesi değişmiyor.
      final after = projectGoalStreak(
        scope: _alpha,
        events: [
          _event(_july(1)),
          // Görev tamamlama en fazla "kısmi ilerleme" sinyali olabilir.
          _event(_july(2), kind: GoalProgressEventKind.partialProgress),
        ],
        asOfDay: _july(2),
      );
      expect(
        after.currentStreak,
        1,
        reason: 'görev tamamlama seriyi 2 yapamaz',
      );
      expect(after.state, GoalStreakState.pendingToday);
    });

    test('geri alma geçmiş tamamlamayı silmez', () {
      // Undo görev tarafında bir satırı geri alır; hedef ledgerine dokunmaz.
      final projection = _project([_july(1), _july(2)], asOf: _july(2));
      expect(projection.completionCount, 2);
      expect(projection.lastCompletedDay, _july(2));
    });
  });

  // ==========================================================================
  // 8. İki cihaz
  // ==========================================================================
  group('iki cihaz', () {
    test('iki cihaz aynı ledgerden aynı sayıyı okur', () async {
      final repo = InMemoryGoalStreakRepository(now: () => _july(2));
      addTearDown(repo.dispose);
      repo.ingestCanonicalEvent(_event(_july(1)));

      ProviderContainer device() {
        final container = ProviderContainer(
          overrides: [goalStreakRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        return container;
      }

      final deviceA = device();
      final deviceB = device();

      final a = await _readProjection(deviceA, _alpha);
      final b = await _readProjection(deviceB, _alpha);
      expect(a.currentStreak, b.currentStreak);
      expect(a.state, b.state);
      expect(a.completionCount, 1);
    });

    test('iki cihaz aynı günü iki kez bildirse de seri bir artar', () async {
      final repo = InMemoryGoalStreakRepository(now: () => _july(2));
      addTearDown(repo.dispose);

      // A ve B aynı günü ayrı ayrı bildiriyor; anahtar aynı olduğu için
      // ledger tek satır tutar.
      repo.ingestCanonicalEvent(_event(_july(1)));
      repo.ingestCanonicalEvent(_event(_july(2)));
      repo.ingestCanonicalEvent(_event(_july(2)));

      final projection = await repo.readProjection(_alpha, asOfDay: _july(2));
      expect(projection.currentStreak, 2);
      expect(projection.completionCount, 2);
    });
  });

  // ==========================================================================
  // 9. UI/server state farkı 0 (alev ↔ projeksiyon)
  // ==========================================================================
  group('UI ve projeksiyon aynı gerçeği gösterir', () {
    for (final entry in {
      GoalStreakState.completedToday: 0,
      GoalStreakState.pendingToday: 1,
      GoalStreakState.atRisk: 2,
      GoalStreakState.expired: 3,
    }.entries) {
      testWidgets('${entry.value} gün sonra alev ${entry.key.wireValue}', (
        tester,
      ) async {
        final repo = InMemoryGoalStreakRepository(
          now: () => _july(5 + entry.value),
        );
        addTearDown(repo.dispose);
        repo.ingestCanonicalEvent(_event(_july(3)));
        repo.ingestCanonicalEvent(_event(_july(5)));

        final container = ProviderContainer(
          overrides: [goalStreakRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        final projection = await _readProjection(container, _alpha);
        expect(projection.state, entry.key);

        await tester.pumpWidget(
          _wrap(GoalStreakFlame(projection: projection)),
        );

        // Ekrandaki sayı projeksiyonun sayısıdır; widget kendi çıkarımını
        // yapmaz. Bu iddia WP-454'ün "durum yalnız server projection'dan"
        // kabulünü uçtan uca bağlar.
        expect(
          find.text('${projection.currentStreak}'),
          findsOneWidget,
          reason: 'ekranda projeksiyondan başka bir sayı görünüyor',
        );
        final icon = tester.widget<Icon>(find.byType(Icon)).icon;
        expect(
          icon,
          goalStreakFlameVisual(
            entry.key,
            ThemeData(useMaterial3: true).colorScheme,
          ).icon,
        );
      });
    }

    test('ledger değişince projeksiyon yeni durumu yayınlar', () async {
      final repo = InMemoryGoalStreakRepository(now: () => _july(5));
      addTearDown(repo.dispose);
      repo.ingestCanonicalEvent(_event(_july(3)));

      final container = ProviderContainer(
        overrides: [goalStreakRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      // Dinleyici olmadan family provider her read'de yeniden kurulur ve
      // akış aboneliği kaybolur (Riverpod 3 auto-dispose tuzağı).
      final sub = container.listen(
        goalStreakProjectionProvider(_alpha),
        (_, _) {},
      );
      addTearDown(sub.close);

      final first = await container.read(
        goalStreakProjectionProvider(_alpha).future,
      );
      expect(first.sourceVersion, goalStreakProjectionSourceVersion);
      expect(first.state, GoalStreakState.atRisk);
      expect(first.currentStreak, 1);

      // 🔴 Bu bekleme kozmetik değil. `watchProjection` bir `async*`: ilk
      // değeri yield ettikten SONRA `_changes` akışına abone oluyor. Broadcast
      // controller abonelikten önceki olayları DÜŞÜRÜR, yani hemen ingest
      // edersek değişiklik sessizce kaybolur (ilk sürüm tam olarak burada
      // kırmızı düştü ve 20 tur beklemek de kurtarmadı — olay hiç yayılmamıştı).
      for (var turn = 0; turn < 5; turn++) {
        await Future<void>.delayed(Duration.zero);
      }

      repo.ingestCanonicalEvent(_event(_july(5)));

      // Yayılma tek tur değil: broadcast controller → `async*` gövdesi →
      // StreamProvider durumu. Sınırlı döngü hem yayılmayı bekliyor hem de
      // yayılma hiç olmazsa testi asmadan düşürüyor.
      GoalStreakProjection? next;
      for (var turn = 0; turn < 20; turn++) {
        await Future<void>.delayed(Duration.zero);
        next = container.read(goalStreakProjectionProvider(_alpha)).value;
        if (next != null && next.state == GoalStreakState.completedToday) break;
      }

      expect(next, isNotNull, reason: 'projeksiyon hiç yayınlanmadı');
      expect(next!.state, GoalStreakState.completedToday);
      expect(next.currentStreak, 2);
    });

    testWidgets('yayınlanan yeni durum ekrana aynen düşer', (tester) async {
      final projection = _project([_july(3), _july(5)], asOf: _july(5));
      expect(projection.currentStreak, 2);

      await tester.pumpWidget(_wrap(GoalStreakFlame(projection: projection)));
      expect(find.text('2'), findsOneWidget);
    });
  });

  // ==========================================================================
  // 10. 🔴 Açık bulgu: "seri" kelimesinin üç farklı tanımı
  // ==========================================================================
  group('seri kelimesinin üç farklı tanımı', () {
    // Aynı geçmiş: 1, 3 ve 5 Temmuz hedefe ulaşıldı; 2 ve 4 kaçırıldı.
    final completedDays = [_july(1), _july(3), _july(5)];
    const goalSeconds = 3600;

    Map<DateTime, int> totals() => {
      for (final day in completedDays)
        DateTime(day.year, day.month, day.day): goalSeconds,
    };

    test('sunucu projeksiyonu (0112) bu geçmişi 3 sayar', () {
      expect(
        _project(completedDays, asOf: _july(5)).currentStreak,
        3,
        reason: 'otomatik grace: tek kaçırma seriyi kırmaz',
      );
    });

    test('istemci freeze-aware serisi bakiye 0 iken aynı geçmişi 1 sayar', () {
      // `gamification_providers.dart` bugün ekranda bu sayıyı gösteriyor.
      final streak = currentStreakWithFreezes(
        totals: totals(),
        goalSeconds: goalSeconds,
        availableFreezes: 0,
        today: DateTime(2026, 7, 5),
      );
      expect(streak.streak, 1);
      expect(streak.freezesUsed, 0);
    });

    test('istemci freeze-aware serisi bakiye 2 iken 3 sayar ve bakiye TÜKETİR', () {
      final streak = currentStreakWithFreezes(
        totals: totals(),
        goalSeconds: goalSeconds,
        availableFreezes: 2,
        today: DateTime(2026, 7, 5),
      );
      expect(streak.streak, 3);
      expect(
        streak.freezesUsed,
        2,
        reason: 'WP-453 kartı: otomatik grace tüketilen bakiyeyle '
            'KARIŞTIRILMAMALI; burada karışıyor',
      );
    });

    test('başarım metriği (0025 streak_days) grace tanımıyor', () {
      // Sunucudaki `fire_streak` XP eşiği bu sayıdan besleniyor. Algoritma
      // `0025`te gün gün geriye yürüyor ve hedefin altındaki ilk günde
      // duruyor — yani `availableFreezes: 0` ile birebir aynı davranış.
      final ledgerEquivalent = currentStreakWithFreezes(
        totals: totals(),
        goalSeconds: goalSeconds,
        availableFreezes: 0,
        today: DateTime(2026, 7, 5),
      );
      expect(ledgerEquivalent.streak, 1);

      final migration = File(
        '../supabase/migrations/0025_achievements_social_metrics.sql',
      ).readAsStringSync();
      expect(
        migration,
        contains('exit when day_secs < goal_secs;'),
        reason: 'streak_days hâlâ ilk eksik günde duruyorsa ayrışma sürüyor',
      );
    });

    test('🔴 üç tanım aynı geçmişte aynı sayıyı vermiyor', () {
      final server = _project(completedDays, asOf: _july(5)).currentStreak;
      final ledger = currentStreakWithFreezes(
        totals: totals(),
        goalSeconds: goalSeconds,
        availableFreezes: 0,
        today: DateTime(2026, 7, 5),
      ).streak;

      // Kartın kabul kriteri "UI/server state farkı 0" idi. Bu iddia o farkın
      // BUGÜN sıfır olmadığını sabitliyor: alev 3, başarım ekranı 1 diyor.
      // Fark kapandığında bu test kırmızıya döner ve kasten güncellenir —
      // sessizce doğru hâle gelmesini istemiyoruz, çünkü XP eşiklerini
      // değiştirmek sahibin kararı (docs/qa/V57-PROGRESSION-EVIDENCE.md §4).
      expect(server, 3);
      expect(ledger, 1);
      expect(
        server,
        isNot(ledger),
        reason: 'ayrışma kapandıysa bu testi ve evidence dosyasını güncelle',
      );
    });
  });
}
