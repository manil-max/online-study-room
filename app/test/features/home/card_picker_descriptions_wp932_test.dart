// WP-932 — kart seçicide açıklama başlığın AYNISI olamaz.
//
// 🔴 Kusur: "Dönem özeti / Dönem özeti", "Eğilim grafiği / Eğilim grafiği",
// "Oturum dağılımı / Oturum dağılımı", "Haftalık ritim / Haftalık ritim"...
// Açıklama satırı kullanıcıya kartın NE gösterdiğini söylemiyordu, başlığı
// ikinci kez yazıyordu. Her kartın açıklaması başlıktan farklı bir cümle
// olmalı (içerikleri kartların kendi widget'larında doğrulandı).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets('her kartin aciklamasi basligindan farkli '
        '(${locale.languageCode})', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\W'), '');
      final same = <String>[
        for (final type in DashboardCardType.values)
          if (norm(type.description(ctx)) == norm(type.title(ctx)) ||
              // "Haftalik grafik" / "Calisma grafigi" gibi yalniz ismi
              // degistiren iki kelimelik aciklama da bilgi tasimaz.
              type.description(ctx).split(' ').length < 3)
            '${type.name}: "${type.title(ctx)}" / "${type.description(ctx)}"',
      ];
      expect(
        same,
        isEmpty,
        reason:
            'Aciklama basligi tekrar ediyor; kartin ne gosterdigini '
            'soylemiyor.',
      );
    });
  }
}
