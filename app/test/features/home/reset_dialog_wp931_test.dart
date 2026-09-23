// WP-931 — "Ana Sayfa'yı sıfırla" penceresi neyin sıfırlanacağını söyler.
//
// 🔴 Kusur: pencerenin başlığı da gövdesi de aynı anahtardı
// (`homeAnaSayfayiSifirla`); kullanıcı neyin gideceğini okuyamıyordu.
// `DashboardLayoutNotifier.reset` yalnız kart DÜZENİNİ varsayılana döndürür
// (hangi kartlar, yerleri, boyları); oturum, hedef, görev ve kart ayarları
// silinmez — gövde bunu söylemeli.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openResetDialog(WidgetTester tester, Locale locale) async {
  SharedPreferences.setMockInitialValues({
    'dashboard_layout_v2_32': <String>['timer:0:0:32:49', 'tasks:0:49:32:18'],
    'dashboard_grid_last_columns': 32,
  });
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.longPress(find.byType(Card).first);
  await tester.pump(const Duration(milliseconds: 600));

  final l10n = await AppLocalizations.delegate.load(locale);
  await tester.tap(find.byTooltip(l10n.homeAnaSayfayiSifirla));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets('govde basligi tekrar etmez, neyin sifirlandigini soyler '
        '(${locale.languageCode})', (tester) async {
      await _openResetDialog(tester, locale);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final title = (dialog.title! as Text).data;
      final body = (dialog.content! as Text).data;
      expect(
        body,
        isNot(title),
        reason:
            'Baslik ve govde ayni metin; kullanici neyin gidecegini '
            'okuyamiyor.',
      );
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(body, l10n.homeAnaSayfayiSifirlaAciklama);
    });
  }
}
