// WP-623: ternary içine gömülü Türkçe metin — İngilizce arayüzde Türkçe çıkıyordu.
//
// 🔴 Kök neden **kod değil kapıydı.** `scripts/l10n_audit.py` gömülü metni
// ararken literal'in yuvanın hemen ardında gelmesini şart koşuyordu:
//
//     Text('...')            -> görülüyordu
//     Text(cond ? '...' : x) -> HİÇ görülmüyordu
//
// Kapı "no hardcoded user-facing literal" deyip yeşil veriyordu; İngilizce
// arayüzde "Ali (sen)" ve "3 ders" yazıyordu (DENETIM-istatistik R7). Taramanın
// kendisi düzeltildi (`slot_literals` yürüyüşü) ve kapı bunu her koşumda
// `--self-test` ile kanıtlıyor.
//
// ⚠️ Bu dosya kapının kopyası DEĞİL. Kapı kaynak metnini okur — "literal artık
// dosyada yok" der. Burada ölçülen şey ürünün kendisi: kart İngilizce yerelde
// **çizildiğinde** ekrana ne yazıyor. Katalog anahtarı eklenip çağrılmazsa
// (v57'nin "bitmiş backend, bağlanmamış UI" tuzağı) kapı yeşil kalır ama bu
// test kırmızıya düşer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette değil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/home/widgets/card_data_gate.dart';
import 'package:online_study_room/features/home/widgets/today_summary_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../support/istanbul_fixture.dart';

List<Override> _overrides() => [
  authStateProvider.overrideWith(
    (ref) => Stream.value(
      Profile(id: 'u1', displayName: 'Ali', createdAt: DateTime(2026, 1, 1)),
    ),
  ),
  userSessionsProvider.overrideWith(
    (ref) => Stream.value(<StudySession>[
      // Gece yarısı tuzağı: geriye gidiş `istanbul_fixture` ile bugüne kilitli.
      StudySession(
        id: 's1',
        userId: 'u1',
        subjectId: 'sub-1',
        start: agoWithinIstanbulToday(const Duration(hours: 1)),
        end: DateTime.now(),
        durationSeconds: 3600,
        source: StudySource.live,
      ),
      StudySession(
        id: 's2',
        userId: 'u1',
        subjectId: 'sub-2',
        start: agoWithinIstanbulToday(const Duration(minutes: 30)),
        end: DateTime.now(),
        durationSeconds: 1800,
        source: StudySource.live,
      ),
    ]),
  ),
  userSubjectsProvider.overrideWith(
    (ref) => Stream.value(<Subject>[
      const Subject(
        id: 'sub-1',
        userId: 'u1',
        name: 'Matematik',
        color: 'chart-1',
      ),
      const Subject(id: 'sub-2', userId: 'u1', name: 'Fizik', color: 'chart-2'),
    ]),
  ),
];

/// Kartı **compact** dalda çizer: ders sayısı satırı yalnız orada yaşıyor
/// (`maxWidth < 180`).
Future<void> _pumpCompact(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 220,
              child: TodaySummaryCard(),
            ),
          ),
        ),
      ),
    ),
  );
  // Akışlar otursun; `pumpAndSettle` yok (kart periyodik timer taşır).
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('İngilizce yerelde ders sayısı İngilizce çıkar', (tester) async {
    await _pumpCompact(tester, const Locale('en'));

    // 🔴 Bu iddia olmadan test sahte yeşil verirdi: akışlar oturmasaydı ekranda
    // yalnız iskelet olurdu ve "2 ders" de doğal olarak bulunamazdı.
    expect(
      find.byKey(kCardSkeletonKey),
      findsNothing,
      reason: 'Veri kapısı hâlâ açık — test kartın gövdesini ölçmüyor.',
    );

    expect(find.text('2 subjects'), findsOneWidget);
    expect(
      find.text('2 ders'),
      findsNothing,
      reason:
          'İngilizce arayüzde Türkçe metin çıkıyor: ders sayısı hâlâ '
          "ternary içine gömülü ('\${breakdown.length} ders').",
    );
  });

  testWidgets('Türkçe yerelde ders sayısı Türkçe kalır', (tester) async {
    await _pumpCompact(tester, const Locale('tr'));

    expect(find.byKey(kCardSkeletonKey), findsNothing);
    expect(find.text('2 ders'), findsOneWidget);
  });

  testWidgets('sıralama satırındaki "sen" etiketi kataloğa bağlı', (
    tester,
  ) async {
    // `leaderboard_card` / `class_stats_view` satırı bir grup + üyelik yığını
    // istiyor; ölçülmesi gereken sözleşme ise etiketin **iki dilde ayrışması**.
    // Aynı metnin iki yerelde de "(sen)" dönmesi, gömülü literal'in geri
    // gelmesinin tek gözlenebilir belirtisidir.
    late AppLocalizations en;
    late AppLocalizations tr;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            en = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('tr'),
        home: Builder(
          builder: (context) {
            tr = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(en.commonSenEtiketi('Ali'), 'Ali (you)');
    expect(tr.commonSenEtiketi('Ali'), 'Ali (sen)');
    // XP birimi iki dilde de "XP" ama katalogda duruyor (bkz. commonXpMiktari
    // gerekçesi): ileride bir yerel çevirmek isterse tek yerden çevirir.
    expect(en.commonXpIlerlemesi(120, 500), '120 / 500 XP');
    expect(tr.commonXpIlerlemesi(120, 500), '120 / 500 XP');
  });
}
