// WP-517: görünen ad 24, grup adı 30 karakter.
//
// Sayılar sahip tarafından seçildi (2026-08-08, parametrik önizlemeden).
//
// 🔴 Bu dosyanın en önemli iddiası davranış değil **sözleşme**: istemci sabiti
// ile `0122_name_length_limits.sql` içindeki sunucu kısıtı aynı sayıyı
// söylemek zorunda. Ayrışırlarsa hata sessizdir ve yalnız gerçek kullanıcıda
// görünür — ekranda yazılabilen ad kaydedilemez ya da tersine, istemci
// engellemediği için sunucu 23514 fırlatır. Sunucu tarafının kendi kanıtı
// `supabase/tests/047_name_length_limits.test.sql`'dedir.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/validation/name_limits.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kaynak dosyayı satır sonundan bağımsız okur.
///
/// Repoda karışık satır sonu var; ham `\n` arayan bir iddia CRLF'e çevrilmiş
/// bir dosyada alakasız yerden kırmızı düşer.
String _read(String relativePath) =>
    File(relativePath).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('Dart ↔ SQL sözleşmesi', () {
    test('migration istemciyle aynı sayıları zorluyor', () {
      final sql = _read('../supabase/migrations/0122_name_length_limits.sql');

      expect(
        sql,
        contains('char_length(btrim(display_name)) <= $kDisplayNameMaxLength'),
        reason:
            'Sunucu kısıtı istemci sabitinden farklı. Kullanıcı ekranda '
            'yazabildiği adı kaydedemez (WP-517).',
      );
      expect(
        sql,
        contains('char_length(btrim(name)) <= $kGroupNameMaxLength'),
        reason: 'groups.name kısıtı istemci sabitinden farklı.',
      );
      expect(
        sql,
        contains('char_length(normalized_name) > $kGroupNameMaxLength'),
        reason:
            'create_group_with_access hâlâ eski sayıyı zorluyor. 0032\'nin 64 '
            'değeri kalırsa "oluşturulabiliyor ama keşifte görünmüyor" '
            'tutarsızlığı geri gelir.',
      );
    });

    test('eski 64 sınırı hiçbir yerde kalmadı', () {
      final sql = _read('../supabase/migrations/0122_name_length_limits.sql');
      expect(
        sql.contains('1 ile 64 karakter'),
        isFalse,
        reason: '0032 metni kopyalanıp sayısı güncellenmemiş.',
      );
    });
  });

  group('istemci giriş noktaları', () {
    // Ad yazan dört yüzey. Üçü diyalog içinde ve gerçek veri/oturum ister;
    // burada yapısal olarak ölçülüyorlar. Dördüncüsü (kayıt ekranı) tam
    // davranışıyla sınanıyor — en az bir uçta gerçek yazma kanıtı olmalı.
    const structural = {
      'lib/features/profile/profile_screen.dart':
          'maxLength: kDisplayNameMaxLength',
      'lib/features/classroom/widgets/class_detail_screen.dart':
          'maxLength: kGroupNameMaxLength',
      'lib/features/classroom/widgets/class_switcher.dart':
          'maxLength: kGroupNameMaxLength',
    };

    for (final entry in structural.entries) {
      test('${entry.key} sınırı bildiriyor', () {
        expect(
          _read(entry.key),
          contains(entry.value),
          reason:
              '${entry.key} içindeki ad alanında maxLength yok — sunucu '
              'kısıtı kullanıcıya hata olarak döner.',
        );
      });
    }

    testWidgets('kayıt ekranı görünen adı 24 karakterde kesiyor', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            locale: Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ad alanı yalnız kayıt modunda çizilir.
      await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextFormField, 'Görünen ad');
      expect(nameField, findsOneWidget);

      const tooLong = 'Muhammed Emin Karaoğlanoğlu Şahinbeyoğlu';
      expect(tooLong.length, greaterThan(kDisplayNameMaxLength));

      await tester.enterText(nameField, tooLong);
      await tester.pump();

      final field = tester.widget<TextField>(
        find.descendant(of: nameField, matching: find.byType(TextField)),
      );
      expect(
        field.controller?.text.length ?? tooLong.length,
        kDisplayNameMaxLength,
        reason: 'maxLength yazılan adı kesmedi.',
      );
    });
  });
}
