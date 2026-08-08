import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';

/// WP-534: doğrulama hatası ekranda **kesilmemeli**.
///
/// Sahip sahada şunu gördü: şifre değiştirme kutusunda hata
/// "The new password cannot be th..." diye kesiliyordu. Cümlenin yarısı yok,
/// kullanıcı ne yapması gerektiğini anlamıyor.
///
/// Kök neden Flutter'ın varsayılanı: `InputDecoration.errorMaxLines` = 1.
/// Uzun hata metni tek satıra sığmayınca `…` ile kesilir. Türkçe ve İngilizce
/// doğrulama cümleleri dar telefonda kolayca bir satırı aşıyor.
///
/// 🔴 Doğru düzeltme tek tek alanlara `errorMaxLines` vermek DEĞİL, temada bir
/// kez açmaktır; aksi halde eklenen her yeni alan aynı hatayı yeniden üretir.
/// Bu test o sözleşmeyi tema düzeyinde ölçer.
void main() {
  test('tema hata ve yardim metnine birden fazla satir verir', () {
    final palette = kAppPalettes.first;
    for (final theme in [AppTheme.light(palette), AppTheme.dark(palette)]) {
      final decoration = theme.inputDecorationTheme;
      expect(
        decoration.errorMaxLines ?? 1,
        greaterThan(1),
        reason: 'Hata metni tek satira sigdirilirsa uzun cumle kesilir.',
      );
      expect(decoration.helperMaxLines ?? 1, greaterThan(1));
    }
  });

  testWidgets('uzun hata metni dar ekranda gercekten sarilir', (tester) async {
    // 🔴 Ilk yazdigim surum `Text.maxLines` alanina bakiyordu ve mutasyonda
    // YESIL kaldi (deger null oldugunda da gecti) -- yani bir sey olcmuyordu.
    // Bu surum CIZILEN YUKSEKLIGI olcuyor: sarilan metin tek satirdan
    // belirgin sekilde uzundur.
    const longError =
        'Yeni sifre eskisiyle ayni olamaz, lutfen farkli bir sifre secin.';
    const shortError = 'Kisa';
    final theme = AppTheme.light(kAppPalettes.first);

    Future<double> heightOf(String message) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280, // dar telefonda AlertDialog genisligi
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Yeni sifre',
                    errorText: message,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.text(message)).height;
    }

    final single = await heightOf(shortError);
    final wrapped = await heightOf(longError);

    expect(
      wrapped,
      greaterThan(single * 1.5),
      reason:
          'Uzun hata tek satira sikismis (kisa: $single, uzun: $wrapped) -- '
          'ekranda "..." ile kesilir.',
    );
    expect(tester.takeException(), isNull);
  });
}
