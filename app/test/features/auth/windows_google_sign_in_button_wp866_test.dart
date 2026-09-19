// WP-866: giriş ekranında Windows "Google ile devam et".
//
// Ölçülenler:
//  1. Windows + Supabase + dolu kimlik → düğme çizilir; kimlik boşsa (beta /
//     staging derlemesi) veya bellek-içi arka uçta çizilmez.
//  2. Sağlayıcı Windows'ta aynı saf kararı okur (define'lar neyse o).
//  3. Port meşgul hatası portu adıyla söyleyen katalog cümlesine döner.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/google_sign_in_config.dart';
import 'package:online_study_room/core/config/supabase_config.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/auth/google_sign_in_availability.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _googleButton = Key('auth-google-sign-in');

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

class _Repo extends InMemoryAuthRepository {
  _Repo({this.error});

  final AuthException? error;
  int googleCalls = 0;

  @override
  Future<Profile> signInWithGoogle() async {
    googleCalls++;
    final e = error;
    if (e != null) throw e;
    return Profile(
      id: 'google-user',
      displayName: 'Ali Veli',
      createdAt: DateTime(2026, 9, 19),
    );
  }
}

bool _windows({
  String id = 'web-client.apps.googleusercontent.com',
  bool supabase = true,
}) => GoogleSignInConfig.resolveEnabled(
  webClientId: id,
  isWeb: false,
  platform: TargetPlatform.windows,
  supabaseBackend: supabase,
);

void main() {
  group('WP-866 Windows gorunurluk', () {
    for (final (label, enabled, visible) in [
      ('Supabase + dolu kimlik -> cizilir', _windows(), true),
      ('kimlik bos (beta/staging) -> cizilmez', _windows(id: ''), false),
      ('bellek-ici arka uc -> cizilmez', _windows(supabase: false), false),
    ]) {
      testWidgets(label, (tester) async {
        _useTallWindow(tester);
        await tester.pumpWidget(
          _app([
            authRepositoryProvider.overrideWithValue(_Repo()),
            googleSignInEnabledProvider.overrideWithValue(enabled),
          ]),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(_googleButton),
          visible ? findsOneWidget : findsNothing,
        );
      });
    }

    test('saglayici Windows\'ta ayni saf karari okur', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final container = ProviderContainer();
      try {
        expect(
          container.read(googleSignInEnabledProvider),
          GoogleSignInConfig.webClientId.trim().isNotEmpty &&
              SupabaseConfig.isConfigured,
        );
        expect(
          GoogleSignInConfig.flow,
          GoogleSignInConfig.webClientId.trim().isEmpty
              ? isNull
              : GoogleSignInFlow.browserLoopback,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
        container.dispose();
      }
    });
  });

  group('WP-866 port mesgul cumlesi', () {
    testWidgets('TR: portu adiyla soyler, teknik mesaj gorunmez', (
      tester,
    ) async {
      _useTallWindow(tester);
      final repo = _Repo(
        error: const AuthException(
          'google_loopback_port_busy',
          code: AuthErrorCode.loopbackPortBusy,
        ),
      );
      await tester.pumpWidget(
        _app([
          authRepositoryProvider.overrideWithValue(repo),
          googleSignInEnabledProvider.overrideWithValue(true),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_googleButton));
      await tester.pumpAndSettle();

      expect(repo.googleCalls, 1);
      expect(
        find.text(
          'Google girişi başlatılamadı: 53682 numaralı bağlantı noktası '
          'başka bir uygulama tarafından kullanılıyor. O uygulamayı kapatıp '
          'tekrar dene.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('google_loopback'), findsNothing);
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
    });

    testWidgets('EN: ayni cumle Ingilizce katalogdan', (tester) async {
      _useTallWindow(tester);
      await tester.pumpWidget(
        _app([
          authRepositoryProvider.overrideWithValue(
            _Repo(
              error: const AuthException(
                'google_loopback_port_busy',
                code: AuthErrorCode.loopbackPortBusy,
              ),
            ),
          ),
          googleSignInEnabledProvider.overrideWithValue(true),
        ], locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_googleButton));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Couldn't start Google sign-in: port 53682 is in use by another "
          'app. Close that app and try again.',
        ),
        findsOneWidget,
      );
    });
  });
}
