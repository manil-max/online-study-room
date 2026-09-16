// WP-831: giriş ekranındaki "Google ile devam et" düğmesi.
//
// Ölçülenler:
//  1. Fail-closed: yapılandırma yoksa (kimlik boş / Android değil / bellek-içi
//     depo) düğme HİÇ çizilmez.
//  2. Açıkken iki modda da (giriş + kayıt) çizilir.
//  3. Dokunuş depoyu çağırır; başarıda hata metni yoktur.
//  4. Kullanıcı vazgeçerse ekran HİÇBİR ŞEY göstermez.
//  5. Gerçek hata katalog cümlesine döner (kod → metin, WP-539 sözleşmesi).
//  6. İstek sürerken düğme kilitlidir (çift dokunuş iki akış açmaz).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/supabase_config.dart';
import 'package:online_study_room/core/config/google_sign_in_config.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/auth/google_sign_in_availability.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../support/supabase_wire_harness.dart';

const _googleButton = Key('auth-google-sign-in');

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthScreen(),
    ),
  );
}

class _GoogleAuthRepository extends InMemoryAuthRepository {
  _GoogleAuthRepository({this.error, this.gate});

  final AuthException? error;
  final Completer<void>? gate;
  int googleCalls = 0;

  @override
  Future<Profile> signInWithGoogle() async {
    googleCalls++;
    final g = gate;
    if (g != null) await g.future;
    final e = error;
    if (e != null) throw e;
    return Profile(
      id: 'google-user',
      displayName: 'Ali Veli',
      createdAt: DateTime(2026, 9, 16),
    );
  }
}

/// `OutlinedButton.icon` alt sınıf döndürür; anahtar o widget'ın üstündedir.
OutlinedButton _button(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.byKey(_googleButton));

void main() {
  group('WP-831 fail-closed gorunurluk', () {
    testWidgets(
      'bellek-ici depoda dugme cizilmez',
      (tester) async {
        _useTallPhone(tester);
        await tester.pumpWidget(
          _app([
            authRepositoryProvider.overrideWithValue(_GoogleAuthRepository()),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_googleButton), findsNothing);
        expect(find.text('Google ile devam et'), findsNothing);
        expect(find.text('veya'), findsNothing);
      },
      // Arka uç kararı derleme bayrağından okunur (SupabaseConfig). Release
      // koşumu Supabase + Google define'larını doldurur; orada bellek-içi
      // durum kurulamaz.
      skip: SupabaseConfig.isConfigured,
    );

    // Widget testi değil: gotrue istemcisinin tazeleme zamanlayıcısı sahte
    // saatte kapanmıyor (ölçüldü: `client.dispose()` 10 dk askıda kaldı).
    // Karar sağlayıcıdan okunur; ekran aynı sağlayıcıyı izler.
    test(
      'Android + Supabase deposu ama kimlik bos -> saglayici false',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final client = SupabaseWireHarness().client();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              SupabaseAuthRepository(client),
            ),
          ],
        );
        try {
          expect(container.read(googleSignInEnabledProvider), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          container.dispose();
          await client.dispose();
        }
      },
      // Test koşusu `GOOGLE_WEB_CLIENT_ID` taşırsa bu ölçüm anlamsızlaşır.
      skip: GoogleSignInConfig.webClientId.isNotEmpty,
    );

    testWidgets('kimlik dolu + Supabase deposu ama Windows -> dugme cizilmez', (
      tester,
    ) async {
      _useTallPhone(tester);
      final enabled = GoogleSignInConfig.resolveEnabled(
        webClientId: 'web-client.apps.googleusercontent.com',
        isWeb: false,
        platform: TargetPlatform.windows,
        supabaseBackend: true,
      );
      await tester.pumpWidget(
        _app([
          authRepositoryProvider.overrideWithValue(_GoogleAuthRepository()),
          googleSignInEnabledProvider.overrideWithValue(enabled),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_googleButton), findsNothing);
    });
  });

  group('WP-831 dugme acikken', () {
    List<Override> overrides(_GoogleAuthRepository repo) => [
      authRepositoryProvider.overrideWithValue(repo),
      googleSignInEnabledProvider.overrideWithValue(true),
    ];

    testWidgets('giris ve kayit modunda cizilir', (tester) async {
      _useTallPhone(tester);
      await tester.pumpWidget(_app(overrides(_GoogleAuthRepository())));
      await tester.pumpAndSettle();

      expect(find.byKey(_googleButton), findsOneWidget);
      expect(find.text('Google ile devam et'), findsOneWidget);
      expect(find.text('veya'), findsOneWidget);

      await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
      await tester.pumpAndSettle();

      expect(find.byKey(_googleButton), findsOneWidget);
    });

    testWidgets('basari: depo cagrilir, hata metni yok', (tester) async {
      _useTallPhone(tester);
      final repo = _GoogleAuthRepository();
      await tester.pumpWidget(_app(overrides(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_googleButton));
      await tester.pumpAndSettle();

      expect(repo.googleCalls, 1);
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
      // Form doğrulaması bu yolda çalışmaz: boş alan uyarısı çıkmamalı.
      expect(find.text('Geçerli bir e-posta girin'), findsNothing);
    });

    testWidgets('vazgecme: ekranda HICBIR sey gorunmez', (tester) async {
      _useTallPhone(tester);
      final repo = _GoogleAuthRepository(
        error: const AuthException(
          'google_sign_in_cancelled',
          code: AuthErrorCode.cancelled,
        ),
      );
      await tester.pumpWidget(_app(overrides(repo)));
      await tester.pumpAndSettle();
      final textsBefore = find.byType(Text).evaluate().length;

      await tester.tap(find.byKey(_googleButton));
      await tester.pumpAndSettle();

      expect(repo.googleCalls, 1);
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
      expect(find.textContaining('google_sign_in'), findsNothing);
      expect(find.byType(Text).evaluate().length, textsBefore);
      expect(_button(tester).onPressed, isNotNull);
    });

    testWidgets('gercek hata katalog cumlesine doner', (tester) async {
      _useTallPhone(tester);
      final repo = _GoogleAuthRepository(
        error: const AuthException('offline', code: AuthErrorCode.network),
      );
      await tester.pumpWidget(_app(overrides(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_googleButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.'),
        findsOneWidget,
      );
      expect(find.text('offline'), findsNothing);
    });

    testWidgets('kodsuz hata generic mesaja duser', (tester) async {
      _useTallPhone(tester);
      final repo = _GoogleAuthRepository(
        error: const AuthException('google_sign_in_failed_unknownError'),
      );
      await tester.pumpWidget(_app(overrides(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_googleButton));
      await tester.pumpAndSettle();

      expect(find.text('Beklenmeyen bir hata oluştu.'), findsOneWidget);
    });

    testWidgets('istek surerken dugme kilitli', (tester) async {
      _useTallPhone(tester);
      final gate = Completer<void>();
      final repo = _GoogleAuthRepository(gate: gate);
      await tester.pumpWidget(_app(overrides(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_googleButton));
      await tester.pump();

      expect(_button(tester).onPressed, isNull);
      await tester.tap(find.byKey(_googleButton), warnIfMissed: false);
      await tester.pump();
      expect(repo.googleCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(_button(tester).onPressed, isNotNull);
    });
  });
}
