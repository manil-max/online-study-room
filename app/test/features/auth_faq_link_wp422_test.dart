// WP-422: giriş ekranındaki SSS bağlantısının yeri ve etiketi.
//
// Sahip: bağlantı yanlış yerde ve etiket Türkçe kullanıcı için tanıdık değil.
// Kodda doğrulandı: bağlantı üç yardımcı bağlantının **başındaydı** ve yalnız
// giriş modunda çiziliyordu — kayıt olmaya çalışan kullanıcı yardıma hiç
// ulaşamıyordu.
//
// Oturum açmadan SSS erişimi v55 kazanımıdır; bu testler onun regresyonunu da
// tutar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/support/faq_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences _prefs;

Widget _app(Locale locale) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(_prefs)],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AuthScreen(),
  ),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpAuth(WidgetTester tester, [Locale locale = const Locale('tr')]) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(_app(locale));
    await tester.pumpAndSettle();
  }

  testWidgets('SSS bağlantısı kayıt geçişinin altında, en altta durur', (
    tester,
  ) async {
    await pumpAuth(tester);

    final faq = find.byKey(const Key('auth-faq-link'));
    final signUp = find.text('Hesabın yok mu? Kayıt ol');
    final forgot = find.text('Şifremi unuttum');
    expect(faq, findsOneWidget);
    expect(signUp, findsOneWidget);

    // Kayıt geçişinin **altında**.
    expect(
      tester.getTopLeft(faq).dy,
      greaterThan(tester.getTopLeft(signUp).dy),
      reason: 'SSS bağlantısı kayıt geçişinin üstünde kalmış',
    );
    // Ve yardımcı bağlantıların en sonunda.
    expect(
      tester.getTopLeft(faq).dy,
      greaterThan(tester.getTopLeft(forgot).dy),
    );
  });

  testWidgets('etiket kısaltmayı taşır', (tester) async {
    await pumpAuth(tester);
    expect(find.text('Sıkça sorulan sorular (SSS)'), findsOneWidget);
  });

  testWidgets('kayıt modunda da SSS bağlantısı kalır', (tester) async {
    await pumpAuth(tester);

    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await tester.pumpAndSettle();

    // Kayıt moduna geçildi (şifremi unuttum kayboldu) ama yardım kaldı.
    expect(find.text('Şifremi unuttum'), findsNothing);
    expect(find.byKey(const Key('auth-faq-link')), findsOneWidget);
  });

  testWidgets('oturum açmadan SSS ekranı açılabilir', (tester) async {
    await pumpAuth(tester);

    await tester.tap(find.byKey(const Key('auth-faq-link')));
    await tester.pumpAndSettle();

    expect(find.byType(FaqScreen), findsOneWidget);
  });

  testWidgets('etiket her release dilinde çevrilidir', (tester) async {
    // WP-457 runtime'ı EN/TR ile sınırladı; DE/AR katalogları dormant
    // arşivde ve generator girdisi değil. Etiketi orada aramak, dilin
    // yayımlanmadığını çeviri eksiği gibi gösterirdi.
    const expected = {
      'tr': 'Sıkça sorulan sorular (SSS)',
      'en': 'Frequently asked questions (FAQ)',
    };
    for (final entry in expected.entries) {
      await pumpAuth(tester, Locale(entry.key));
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: '${entry.key} kataloğunda SSS etiketi eksik',
      );
    }
  });

  testWidgets('yayımlanmayan dil İngilizceye düşer, bağlantı kaybolmaz', (
    tester,
  ) async {
    // Regresyon kapısı: SSS bağlantısı v55'te oturum açmadan yardıma erişim
    // için eklendi. Desteklenmeyen bir sistem yereli (örn. Almanca cihaz)
    // bağlantıyı boş etiketli bırakmamalı ya da hiç çizmemeli.
    await pumpAuth(tester, const Locale('de'));

    expect(find.byKey(const Key('auth-faq-link')), findsOneWidget);
    expect(find.text('Frequently asked questions (FAQ)'), findsOneWidget);
  });
}
