// WP-681 — ödül/taç kutlaması altındaki dokunuşları yutuyordu.
//
// 🔴 KAYNAKTA `IgnorePointer` GEÇMESİ KANIT DEĞİLDİR. Bu dosyadaki her iddia
// kullanıcının GÖRDÜĞÜ kutunun koordinatı ve DOKUNDUĞU noktanın gerçekten
// tetiklediği geri çağırma ile ölçülür (`tester.tap` → sayaç arttı mı).
//
// Ölçümün kaynağı (WP-678 ajanı, 1920 px pencere, masaüstü Araçlar sekmesi):
//   kutlama kutusu    : (862.5, 8) – (1057.5, 56)
//   "Timer" şerit ögesi merkezi: (1048, 39)  → kutlamanın TAM altında
//   `tester.tap`      : "would not hit test", sekme hiç değişmedi
// Kutlama 1800 ms görünür; o sürede o şeride yapılan her dokunuş sessizce
// yutuluyordu (kullanıcı "uygulama takıldı" diye algılar).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/profile/widgets/reward_toast.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  // Kutlamanın altında duran GERÇEK bir dokunma hedefi: üç eşit ögeli üst
  // şerit (Araçlar sekmesinin alarm/zamanlayıcı/görev şeridinin geometrisi).
  Widget strip(void Function(String) onTap) => Align(
    alignment: Alignment.topCenter,
    child: Material(
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: Row(
          children: [
            for (final id in const ['alarm', 'timer', 'tasks'])
              Expanded(
                child: InkWell(
                  key: ValueKey('strip-$id'),
                  onTap: () => onTap(id),
                  child: Center(child: Text(id)),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget harness({
    required void Function(String) onStripTap,
    String? rank,
    int count = 0,
    int xp = 0,
    VoidCallback? onOpenProfile,
  }) => MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        // Animasyon kapalı: ölçüm ara karede değil, oturmuş düzende alınır.
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Scaffold(
          // `home_shell.dart:123` (masaüstü) ve `:149` (mobil) ile aynı yapı:
          // içerik altta, RewardToast üstte, ikisi de aynı Stack'te.
          body: Stack(
            fit: StackFit.expand,
            children: [
              strip(onStripTap),
              RewardToast(
                pendingCount: count,
                pendingXp: xp,
                crownRank: rank,
                onOpenProfile: onOpenProfile ?? () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void sizedWindow(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  /// Kutlamayı gerçekten ekrana getirir: rütbe DEĞİŞİMİ gerekir, ilk yükleme
  /// kutlamaz (`didUpdateWidget`, `_lastRank`).
  Future<void> raiseCrown(
    WidgetTester tester, {
    required void Function(String) onStripTap,
  }) async {
    await tester.pumpWidget(
      harness(onStripTap: onStripTap, rank: 'bronze_beginner'),
    );
    await tester.pumpWidget(
      harness(onStripTap: onStripTap, rank: 'silver_learner'),
    );
    await tester.pump();
  }

  Rect celebrationRect(WidgetTester tester) => tester.getRect(
    find
        .ancestor(
          of: find.text('Gümüş Taç'),
          matching: find.byType(Material),
        )
        .first,
  );

  testWidgets(
    'masaüstü 1920: taç kutlaması görünürken altındaki şerit ögesi tıklanır',
    (tester) async {
      sizedWindow(tester, const Size(1920, 1080));
      final taps = <String>[];
      await raiseCrown(tester, onStripTap: taps.add);

      // 1) Kullanıcının GÖRDÜĞÜ kutu — kutlama gerçekten boyandı mı?
      expect(find.text('Gümüş Taç'), findsOneWidget);
      final crown = celebrationRect(tester);
      final target = tester.getCenter(find.byKey(const ValueKey('strip-timer')));

      // 2) Ölçümün ön koşulu: kutlama gerçekten hedefin ÜSTÜNDE. Örtüşme
      //    yoksa bu test hiçbir şey kanıtlamaz — o yüzden sert iddia.
      expect(
        crown.contains(target),
        isTrue,
        reason:
            'Kutlama $crown, şerit ögesi merkezi $target — örtüşme yok, test '
            'geçersiz. Kutlamanın konumu değiştiyse bu testi yeniden ölç.',
      );

      // 3) 🔴 ASIL ÖLÇÜM: dokunuş gerçekten geçti mi?
      await tester.tap(
        find.byKey(const ValueKey('strip-timer')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(
        taps,
        ['timer'],
        reason:
            'Kutlama ($crown) şerit ögesinin ($target) dokunuşunu yuttu. '
            'Kutlama bir BİLDİRİM, bir engel değil.',
      );
    },
  );

  testWidgets('mobil 393: aynı ölçüm — kutlama mobil kolda da yutmaz', (
    tester,
  ) async {
    sizedWindow(tester, const Size(393, 852));
    final taps = <String>[];
    await raiseCrown(tester, onStripTap: taps.add);

    final crown = celebrationRect(tester);
    final target = tester.getCenter(find.byKey(const ValueKey('strip-timer')));
    expect(
      crown.contains(target),
      isTrue,
      reason: 'Kutlama $crown, hedef $target — mobilde örtüşme yok.',
    );

    await tester.tap(
      find.byKey(const ValueKey('strip-timer')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(taps, ['timer'], reason: 'Mobil kolda kutlama dokunuşu yuttu.');
  });

  testWidgets('kutlama kalkınca da şerit çalışır (kalıntı engel yok)', (
    tester,
  ) async {
    sizedWindow(tester, const Size(1920, 1080));
    final taps = <String>[];
    await raiseCrown(tester, onStripTap: taps.add);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    expect(find.text('Gümüş Taç'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('strip-timer')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(taps, ['timer']);
  });

  // 🔴 İŞLEV KAYBI KORUMASI: düzeltme "her şeyi IgnorePointer yap"a
  // kayarsa ödül bannerının Topla/Kapat düğmeleri ölür. Banner bir engel
  // değil, kullanıcının BASTIĞI bir kart — dokunma işlevi KORUNMALI.
  testWidgets('ödül bannerının kendi dokunma işlevi korunur', (tester) async {
    sizedWindow(tester, const Size(1920, 1080));
    var opened = 0;
    await tester.pumpWidget(
      harness(
        onStripTap: (_) {},
        count: 3,
        xp: 900,
        onOpenProfile: () => opened++,
      ),
    );
    await tester.pump();

    expect(find.text('3 ödül hazır · 900 XP'), findsOneWidget);
    await tester.tap(find.text('Topla'));
    await tester.pump();
    expect(opened, 1, reason: 'Banner "Topla" düğmesi tıklanamaz oldu.');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('3 ödül hazır · 900 XP'),
      findsNothing,
      reason: 'Banner "Kapat" düğmesi tıklanamaz oldu.',
    );
  });
}
