// WP-504 (WP-500'ün açtığı borç): l10n kapısının kör noktası kapanınca çıkan
// gömülü metinler.
//
// 🔴 WP-500 kapıyı düzeltti ve 10 bulgu üretti; biri orada çevrildi, kalanlar
// `scripts/l10n_audit.py` içindeki `UI_PROSE_DEBT` siciline yazıldı. Bu WP
// borcu ödedi: sicil **beşten bire** indi.
//
// Bu dosya kapının değil **ürünün** ucunu ölçer: sayı taşıyan üç yüzey artık
// katalogdan besleniyor ve dil değişince gerçekten değişiyor. Kapı yeşil
// olabilir ama metin yanlış dilde çizilebilir — o yüzden ayrı iddia.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

Future<AppLocalizations> _l10n(WidgetTester tester, Locale locale) async {
  late AppLocalizations captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  group('kart sayısı katalogdan', () {
    testWidgets('İngilizce', (tester) async {
      final l10n = await _l10n(tester, const Locale('en'));
      // Eskiden `'${available.length} kart'` idi: İngilizce arayüzde de Türkçe.
      expect(l10n.homeKartSayisi(3), '3 cards');
      expect(l10n.homeKartSayisi(1), '1 card');
    });

    testWidgets('Türkçe', (tester) async {
      final l10n = await _l10n(tester, const Locale('tr'));
      expect(l10n.homeKartSayisi(3), '3 kart');
      expect(l10n.homeKartSayisi(1), '1 kart');
    });
  });

  group('oturum sayısı katalogdan', () {
    testWidgets('İngilizce', (tester) async {
      final l10n = await _l10n(tester, const Locale('en'));
      expect(l10n.profileOturumSayisi(12), '12 sessions');
      expect(l10n.profileOturumSayisi(1), '1 session');
    });

    testWidgets('Türkçe', (tester) async {
      final l10n = await _l10n(tester, const Locale('tr'));
      expect(l10n.profileOturumSayisi(12), '12 oturum');
      expect(l10n.profileOturumSayisi(1), '1 oturum');
    });
  });

  testWidgets('XP birimi iki dilde de aynı ama katalogda', (tester) async {
    // 🔴 Bu iddia bilerek "iki dilde aynı" diyor. Değeri çeviride değil
    // **yerde**: literal kodda kalsaydı yarın başka bir dil eklendiğinde
    // (ya da "XP" yerine "PD" isteyen bir yerelleştirmede) çevrilecek nokta
    // hiç görünmezdi. Sicilden düşmesinin sebebi de bu.
    final en = await _l10n(tester, const Locale('en'));
    final tr = await _l10n(tester, const Locale('tr'));
    expect(en.commonXpMiktari(250), '250 XP');
    expect(tr.commonXpMiktari(250), '250 XP');
  });
}
