// 🔴 WP-620 — aylik rapor anahtari hatayi YUTUYORDU.
//
// `notification_permissions_screen.dart:31`
//   } catch (_) {
//     if (mounted) setState(() => _monthlyReportOptInOverride = previousValue);
//   }
//
// Yarim dogru: deger geri aliniyordu ama kullaniciya HICBIR SEY soylenmiyordu.
// Ekranda gorunen tek sey anahtarin kendiliginden eski yerine donmesiydi;
// kullanici bunu "kaydolmadi" degil "arayuz takildi" diye okuyup tekrar tekrar
// deniyordu.
//
// 🔴 Sahte depo bilerek **alan disi** hata firlatir (`SocketException`).
// `updateMonthlyReportOptIn` gercekte PostgREST/soket hatasi verir,
// `AuthException` degil; `AuthException` atan bir test bu kusuru olcemez.
//
// Iki yonlu: hata varken uyari CIKAR ve anahtar geri doner; basaride uyari
// CIKMAZ ve anahtar yeni degerde kalir.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/notifications/notification_permissions_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _socketFailure = SocketException('Failed host lookup: db.supabase.co');

class _ReportAuthRepository extends InMemoryAuthRepository {
  Object? error;
  int calls = 0;
  bool? lastValue;

  @override
  Future<void> updateMonthlyReportOptIn(bool value) async {
    calls++;
    lastValue = value;
    final failure = error;
    if (failure != null) throw failure;
    return super.updateMonthlyReportOptIn(value);
  }
}

void main() {
  Future<_ReportAuthRepository> pump(
    WidgetTester tester, {
    Object? error,
  }) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _ReportAuthRepository();
    addTearDown(repo.dispose);
    await repo.signUp(
      email: 'ali@ornek.com',
      password: 'guvenli123',
      displayName: 'Ali',
    );
    repo.error = error;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationPermissionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
    tester.element(find.byType(NotificationPermissionsScreen)),
  );

  Future<void> toggle(WidgetTester tester) async {
    final sw = find.byKey(const Key('monthly-report-opt-in'));
    await tester.ensureVisible(sw);
    await tester.pumpAndSettle();
    await tester.tap(sw);
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(const Key('monthly-report-opt-in')))
      .value;

  test('on kosul: sahte depo AuthException DISI hata firlatir', () async {
    final repo = _ReportAuthRepository();
    addTearDown(repo.dispose);
    await repo.signUp(
      email: 'ali@ornek.com',
      password: 'guvenli123',
      displayName: 'Ali',
    );
    repo.error = _socketFailure;
    await expectLater(
      repo.updateMonthlyReportOptIn(false),
      throwsA(allOf(isA<SocketException>(), isNot(isA<AuthException>()))),
    );
  });

  testWidgets('ag hatasinda anahtar geri doner VE kullaniciya soylenir', (
    tester,
  ) async {
    final repo = await pump(tester, error: _socketFailure);
    final l10n = l10nOf(tester);
    expect(switchValue(tester), isTrue);

    await toggle(tester);

    expect(repo.calls, 1);
    expect(repo.lastValue, isFalse);
    expect(
      switchValue(tester),
      isTrue,
      reason: 'kaydedilemeyen deger uygulanmis gibi durmamali',
    );
    expect(
      find.byKey(const Key('monthly-report-save-failed')),
      findsOneWidget,
      reason:
          'olcum: eskiden 0 - anahtar sessizce geri donuyor, kullanici '
          'arayuzun takildigini saniyordu',
    );
    expect(
      find.text(l10n.notificationsAylikRaporKaydedilemedi),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('basarida uyari CIKMAZ ve yeni deger kalir', (tester) async {
    final repo = await pump(tester);
    final l10n = l10nOf(tester);

    await toggle(tester);

    expect(repo.calls, 1);
    expect(switchValue(tester), isFalse);
    expect(
      find.byKey(const Key('monthly-report-save-failed')),
      findsNothing,
      reason: 'her kaydetmede uyari cikarsa uyari anlamini yitirir',
    );
    expect(find.text(l10n.notificationsAylikRaporKaydedilemedi), findsNothing);
  });
}
