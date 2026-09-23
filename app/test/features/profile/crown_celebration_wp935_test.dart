// WP-935 — yeni kullanıcıya ilk oturumdan sonra sahte "Bronz Taç" kutlaması.
//
// 🔴 Kusur (kodda doğrulandı): kabuk tacı `gamificationProfileProvider`dan
// okur. Satır YOKKEN depo `GamificationProfile.initial` döndürür ve modelin
// varsayılanı `'bronze'`dur (eski ad). İlk oturumdan sonra sunucu satırı
// `'bronze_beginner'` ile yazar. `RewardToast` ham metinleri karşılaştırıyordu
// (`'bronze' != 'bronze_beginner'`) → zaten en alt rütbe olan "Bronz Taç" için
// kutlama çıkıyordu. Aynı rütbenin iki adı yükseliş değildir; düşüş de
// kutlanmaz. Kutlama yalnız kademe GERÇEKTEN yükselince çıkar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/profile/widgets/reward_toast.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

Widget _app(String? rank) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Scaffold(
      body: RewardToast(
        pendingCount: 0,
        pendingXp: 0,
        crownRank: rank,
        onOpenProfile: () {},
      ),
    ),
  ),
);

void main() {
  late AppLocalizations tr;

  setUpAll(() async {
    tr = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  Future<void> change(WidgetTester tester, String from, String to) async {
    await tester.pumpWidget(_app(from));
    await tester.pumpWidget(_app(to));
    await tester.pump();
  }

  testWidgets("'bronze' -> 'bronze_beginner' kutlanmaz (ayni rutbe)", (
    tester,
  ) async {
    await change(tester, 'bronze', 'bronze_beginner');
    expect(
      find.text(tr.coreBronzTac),
      findsNothing,
      reason:
          'Yeni kullanici ilk oturumdan sonra en alt rutbe icin kutlama '
          'goruyor: istemci varsayilani eski ad, sunucu yeni ad.',
    );
  });

  testWidgets('dusus kutlanmaz', (tester) async {
    await change(tester, 'gold_achiever', 'silver_learner');
    expect(find.text(tr.coreGumusTac), findsNothing);
  });

  testWidgets('gercek yukselis hala kutlanir (eski addan da)', (tester) async {
    await change(tester, 'bronze', 'silver_learner');
    expect(find.text(tr.coreGumusTac), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
  });
}
