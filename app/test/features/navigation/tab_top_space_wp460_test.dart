// WP-460: Alt sekmelerde tekrar eden üst başlık ve ölü boşluk.
//
// Sahip bulgusu: her sekmenin tepesinde, alt menüde zaten yazan adı ikinci kez
// yazan bir başlık çubuğu vardı. Durum çubuğu payıyla birlikte bu, ilk anlamlı
// içeriği ~100 px aşağı itiyordu.
//
// Kural: **başlık tekrar etmez, eylem kaybolmaz, güvenli alan korunur.**
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/navigation/tab_action_bar.dart';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('kompakt eylem şeridi', () {
    test('eylem yoksa çubuk hiç kurulmaz', () {
      expect(buildTabActionBar(), isNull);
    });

    test('eylem varsa yüksekliği 48 dp kompakt şerittir', () {
      final bar = buildTabActionBar(
        actions: const [Icon(Icons.add)],
      );
      expect(bar, isNotNull);
      expect(bar!.preferredSize.height, kTabActionBarHeight);
      expect(kTabActionBarHeight, lessThan(kToolbarHeight));
    });

    test('yalnız TabBar taşıyan sekmede araç çubuğu payı sıfırdır', () {
      final bar = buildTabActionBar(
        bottom: const TabBar(tabs: [Tab(text: 'a'), Tab(text: 'b')]),
      );
      expect(bar, isNotNull);
      expect((bar! as AppBar).toolbarHeight, 0);
    });

    testWidgets('şerit eylemi çizer ve başlık taşımaz', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: buildTabActionBar(
              actions: [
                IconButton(
                  key: const Key('tab-action'),
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () {},
                ),
              ],
            ),
            body: const SizedBox(key: Key('body')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tab-action')), findsOneWidget);
      expect(find.byType(Text), findsNothing, reason: 'başlık metni kalmamalı');
    });
  });

  group('sekme yüzeyi sözleşmesi', () {
    test('hiçbir sekme kendi adını tepede tekrar yazmıyor', () {
      final titles = {
        'lib/features/home/home_screen.dart': 'title: Text(\n'
            '            _editing',
        'lib/features/clock/clock_screen.dart': 'navTools',
        'lib/features/stats/stats_screen.dart': 'statsIstatistik',
        'lib/features/profile/profile_screen.dart': '.profileProfil)',
      };
      titles.forEach((path, needle) {
        expect(
          _read(path).contains(needle),
          isFalse,
          reason: '$path sekme adını tepede tekrar yazıyor',
        );
      });
    });

    test('gerçek eylemler ve güvenli alan yerinde', () {
      expect(
        _read('lib/features/home/home_screen.dart').contains('showCardPicker'),
        isTrue,
        reason: 'kart ekle eylemi kayboldu',
      );
      expect(
        _read(
          'lib/features/classroom/classroom_screen.dart',
        ).contains('showClassSwitcher'),
        isTrue,
        reason: 'grup değiştir eylemi kayboldu',
      );
      expect(
        _read('lib/features/clock/clock_screen.dart').contains('SafeArea'),
        isTrue,
        reason: 'AppBar kalkınca üst güvenli alan gövdeye geçmeli',
      );
      expect(
        _read(
          'lib/features/profile/profile_screen.dart',
        ).contains('MediaQuery.paddingOf(context).top'),
        isTrue,
        reason: 'profil listesi durum çubuğu payını taşımalı',
      );
    });

    test('beş sekme de kompakt şeridi ya da başlıksız gövdeyi kullanıyor', () {
      const screens = [
        'lib/features/home/home_screen.dart',
        'lib/features/clock/clock_screen.dart',
        'lib/features/classroom/classroom_screen.dart',
        'lib/features/stats/stats_screen.dart',
        'lib/features/profile/profile_screen.dart',
      ];
      for (final path in screens) {
        final source = _read(path);
        expect(
          source.contains('appBar: AppBar('),
          isFalse,
          reason: '$path hâlâ kendi başlık çubuğunu kuruyor',
        );
      }
    });
  });
}
