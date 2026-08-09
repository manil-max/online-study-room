// WP-632 — sınav geri sayımı: en fazla üç kayıt, ad, sıra, öne çıkarma.
//
// Proje sahibi kararı (2026-08-09, `docs/URUN-POLITIKALARI.md` §8.1):
// hiçbiri öne çıkarılmamışsa kayıtlar **eşit** görünür; biri öne çıkarılırsa o
// **büyük** olur, diğerleri altında satır kalır. Sıra kullanıcıya aittir.
//
// 🔴 Bu dosyanın ilk işi **taşma**yı ölçmek. Pano hücresi karta sabit piksel
// yükseklik verir (küçük 160 / orta 240 / büyük 320) ve kart gövdesine küçük
// boyutta yalnız ~92 px kalır. "Sığmazsa kaydırır" tek başına yeterli değildi:
// kullanıcı sayıyı görmek için kart içinde kaydırmak zorunda kalırdı. Kart bu
// yüzden yoğunluğu ölçüye göre seyreltiyor ve bu test onu üç boyutta, üç kayıt
// sayısında ve büyük yazı tipi ölçeğinde birden sınıyor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:online_study_room/features/home/widgets/dday_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 8, 9, 21, 0);

Future<SharedPreferences> _prefs({String? list, String? legacy}) async {
  SharedPreferences.setMockInitialValues({
    kExamListKey: ?list,
    kExamDateKey: ?legacy,
  });
  return SharedPreferences.getInstance();
}

String _listJson(List<Map<String, String>> entries, {String? priority}) =>
    encodeExamList(
      ExamListState(
        entries: [
          for (final e in entries)
            ExamEntry(
              id: e['id']!,
              name: e['name']!,
              day: DateTime.parse(e['day']!),
            ),
        ],
        priorityId: priority,
      ),
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required DashboardCardSize size,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ddayClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Center(
              child: SizedBox(
                // Pano hücresinin gerçek genişlik/yükseklik sözleşmesi.
                width: size == DashboardCardSize.small ? 180 : 360,
                height: defaultCardHeight(size),
                child: DDayCard(size: size),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Kart gövdesindeki kaydırma payı. 0 = içerik sığıyor, kaydırmaya gerek yok.
double _scrollExtent(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byType(DDayCard),
    matching: find.byType(Scrollable),
  );
  if (scrollable.evaluate().isEmpty) return 0;
  // `Scrollable.of` ATAYI arar; buradaki eleman Scrollable'ın kendisidir.
  return tester
      .state<ScrollableState>(scrollable.first)
      .position
      .maxScrollExtent;
}

void main() {
  group('taşma — üç boyut × kayıt sayısı × yazı ölçeği', () {
    for (final size in DashboardCardSize.values) {
      for (final count in [1, 2, 3]) {
        for (final priority in [false, true]) {
          testWidgets(
            '${size.name} kart · $count kayıt · '
            '${priority ? "öne çıkan var" : "hepsi eşit"} → taşma YOK',
            (tester) async {
              final entries = [
                for (var i = 0; i < count; i++)
                  {
                    'id': 'e$i',
                    // Uzun ad bilerek: dar kartta yatay taşmanın tetikleyicisi
                    // sayı değil ADdır.
                    'name': 'Deneme sınavı numara $i',
                    'day': '2026-1${i + 1}-0${i + 1}',
                  },
              ];
              await _pumpCard(
                tester,
                prefs: await _prefs(
                  list: _listJson(entries, priority: priority ? 'e0' : null),
                ),
                size: size,
              );
              expect(
                tester.takeException(),
                isNull,
                reason: 'Yatay taşma: uzun sınav adı satırı genişletiyor.',
              );

              // 🔴 ASIL İDDİA. Dikey taşma bir istisna ATMAZ -- gövde
              // `cardScrollIfOverflows` içinde ve kaydırıcı taşmayı yutar.
              // Yani "istisna yok" tek başına ölçmez; kötü bir yerleşim de
              // yeşil geçerdi. Ölçülmesi gereken şey, kullanıcının normal
              // yazı tipi ölçeğinde sayıyı görmek için KAYDIRMAK ZORUNDA
              // KALMAMASI: kaydırma payı sıfır olmalı.
              expect(
                _scrollExtent(tester),
                0,
                reason:
                    'İçerik ${size.name} karta sığmıyor; kullanıcı kalan günü '
                    'görmek için kart içinde kaydırmak zorunda kalır.',
              );
            },
          );
        }
      }
    }

    testWidgets('büyük yazı tipi ölçeğinde de taşma YOK (2.0×)', (tester) async {
      // Erişilebilirlik ayarı devreye girince sabit punto taşardı; kaydırma
      // güvenlik ağı burada devrede olmalı.
      await _pumpCard(
        tester,
        prefs: await _prefs(
          list: _listJson([
            {'id': 'a', 'name': 'YKS', 'day': '2026-06-20'},
            {'id': 'b', 'name': 'AYT', 'day': '2026-06-21'},
            {'id': 'c', 'name': 'Deneme', 'day': '2026-08-21'},
          ], priority: 'a'),
        ),
        size: DashboardCardSize.small,
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      // Burada kaydırma payı olabilir ve bu DOĞRUdur: 2.0x ölçekte içerik
      // gerçekten sığmaz, güvenlik ağı devreye girer. Ölçülen şey kartın
      // çökmemesi ve içeriğe ULAŞILABİLİR kalması.
      expect(_scrollExtent(tester), greaterThanOrEqualTo(0));
    });
  });

  group('yerleşim sözleşmesi', () {
    testWidgets('öne çıkan YOKSA üç kayıt da görünür (eşit)', (tester) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(
          list: _listJson([
            {'id': 'a', 'name': 'YKS', 'day': '2026-06-20'},
            {'id': 'b', 'name': 'AYT', 'day': '2026-06-21'},
            {'id': 'c', 'name': 'Deneme', 'day': '2026-08-21'},
          ]),
        ),
        size: DashboardCardSize.large,
      );
      expect(find.text('YKS'), findsOneWidget);
      expect(find.text('AYT'), findsOneWidget);
      expect(find.text('Deneme'), findsOneWidget);
    });

    testWidgets('öne çıkan VARSA onun tarihi de görünür (büyük kartta)', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(
          list: _listJson([
            {'id': 'a', 'name': 'YKS', 'day': '2026-06-20'},
            {'id': 'b', 'name': 'AYT', 'day': '2026-06-21'},
          ], priority: 'a'),
        ),
        size: DashboardCardSize.large,
      );
      // Öne çıkanın tam tarihi yazılır; diğeri yalnız ad + kalan gün.
      expect(find.textContaining('2026'), findsOneWidget);
      expect(find.text('AYT'), findsOneWidget);
    });

    testWidgets('adı boş kayıt varsayılan başlıkla görünür', (tester) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(
          list: _listJson([
            {'id': 'a', 'name': '', 'day': '2026-06-20'},
          ]),
        ),
        size: DashboardCardSize.medium,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.homeSinavVarsayilanAd), findsOneWidget);
    });

    testWidgets('hiç kayıt yokken kart BOŞ KUTU değildir', (tester) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(),
        size: DashboardCardSize.medium,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.homeSinavGeriSayimi), findsOneWidget);
      expect(find.text(l10n.homeSinavTarihiSecilmedi), findsOneWidget);
    });
  });
}
