// WP-867: giriş ekranında Windows tarayıcı Google girişi beklerken "Vazgeç".
//
// Ölçülenler:
//  1. Vazgeç + ipucu yalnız Windows tarayıcı akışı BEKLERKEN çizilir;
//     boşta ve Android akışında (hesap seçici) hiç çizilmez.
//  2. Vazgeç'e basınca depo iptal edilir, form sessizce açılır (hata yok),
//     Google düğmesi yeniden basılabilir ve yeniden deneme çalışır.
//  3. İptalden sonra geç düşen eski denemenin hatası ekrana yazılmaz.
//  4. EN katalog metni.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/auth/google_sign_in_availability.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _googleButton = Key('auth-google-sign-in');
const _cancelButton = Key('auth-google-cancel');
const _hint = Key('auth-google-browser-hint');

void _useTallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(List<Override> overrides, {Locale locale = const Locale('tr')}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthScreen(),
    ),
  );
}

/// Google girişi tarayıcıda "bekler": [cancelGoogleSignIn] gelene kadar
/// dönmez. [lateError] verilirse iptal çağrısı eski denemeyi o hatayla
/// düşürür (geç gelen hata ekrana yazılmamalı).
class _PendingRepo extends InMemoryAuthRepository {
  _PendingRepo({this.lateError});

  final AuthException? lateError;
  int googleCalls = 0;
  int cancelCalls = 0;
  Completer<Profile>? _pending;

  @override
  Future<Profile> signInWithGoogle() {
    googleCalls++;
    return (_pending = Completer<Profile>()).future;
  }

  @override
  Future<void> cancelGoogleSignIn() async {
    cancelCalls++;
    final pending = _pending;
    _pending = null;
    pending?.completeError(
      lateError ??
          const AuthException(
            'google_sign_in_cancelled',
            code: AuthErrorCode.cancelled,
          ),
    );
  }
}

List<Override> _overrides(_PendingRepo repo, {required bool inBrowser}) => [
  authRepositoryProvider.overrideWithValue(repo),
  googleSignInEnabledProvider.overrideWithValue(true),
  googleSignInInBrowserProvider.overrideWithValue(inBrowser),
];

bool _googleEnabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(find.byKey(_googleButton)).enabled;

void main() {
  testWidgets('Vazgec yalniz Windows tarayici akisi beklerken cizilir', (
    tester,
  ) async {
    _useTallWindow(tester);
    final repo = _PendingRepo();
    await tester.pumpWidget(_app(_overrides(repo, inBrowser: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(_cancelButton), findsNothing);
    expect(find.byKey(_hint), findsNothing);

    await tester.tap(find.byKey(_googleButton));
    await tester.pump();

    expect(repo.googleCalls, 1);
    expect(find.byKey(_cancelButton), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
    expect(find.text('Tarayıcıda Google ile girişi tamamla.'), findsOneWidget);
    expect(_googleEnabled(tester), isFalse);

    await tester.tap(find.byKey(_cancelButton));
    await tester.pumpAndSettle();

    expect(repo.cancelCalls, 1);
    expect(find.byKey(_cancelButton), findsNothing);
    expect(find.byKey(_hint), findsNothing);
    expect(_googleEnabled(tester), isTrue);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
    expect(find.textContaining('google_sign_in'), findsNothing);

    // Yeniden deneme hemen başlar.
    await tester.tap(find.byKey(_googleButton));
    await tester.pump();
    expect(repo.googleCalls, 2);
    expect(find.byKey(_cancelButton), findsOneWidget);
    await tester.tap(find.byKey(_cancelButton));
    await tester.pumpAndSettle();
  });

  testWidgets('Android akisi (hesap secici): Vazgec hic cizilmez', (
    tester,
  ) async {
    _useTallWindow(tester);
    final repo = _PendingRepo();
    await tester.pumpWidget(_app(_overrides(repo, inBrowser: false)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_googleButton));
    await tester.pump();

    expect(repo.googleCalls, 1);
    expect(_googleEnabled(tester), isFalse);
    expect(find.byKey(_cancelButton), findsNothing);
    expect(find.byKey(_hint), findsNothing);

    // Hesap seçici kapandı: eski sessiz yol değişmedi.
    await repo.cancelGoogleSignIn();
    await tester.pumpAndSettle();
    expect(_googleEnabled(tester), isTrue);
    expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
  });

  testWidgets('iptalden sonra gec dusen hata ekrana yazilmaz', (tester) async {
    _useTallWindow(tester);
    final repo = _PendingRepo(
      lateError: const AuthException('google_browser_open_failed'),
    );
    await tester.pumpWidget(_app(_overrides(repo, inBrowser: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_googleButton));
    await tester.pump();
    await tester.tap(find.byKey(_cancelButton));
    await tester.pumpAndSettle();

    expect(repo.cancelCalls, 1);
    expect(_googleEnabled(tester), isTrue);
    expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
    expect(find.textContaining('google_browser'), findsNothing);
  });

  testWidgets('EN: ipucu ve Cancel katalogdan', (tester) async {
    _useTallWindow(tester);
    final repo = _PendingRepo();
    await tester.pumpWidget(
      _app(_overrides(repo, inBrowser: true), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_googleButton));
    await tester.pump();

    expect(
      find.text('Finish signing in with Google in your browser.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

    await tester.tap(find.byKey(_cancelButton));
    await tester.pumpAndSettle();
  });
}
