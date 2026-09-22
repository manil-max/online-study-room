// WP-902: giriş ekranındaki "Apple ile devam et" düğmesi + şifresiz hesabın
// uygulama içi silinmesi (App Store 4.8 + 5.1.1(v)).
//
// Ölçülenler:
//  1. Düğme yalnız iOS'ta (Supabase arka ucuyla) çizilir; Android/Windows'ta
//     hiç çizilmez.
//  2. iOS'ta Google'ın ÜSTÜNDE durur.
//  3. Dokunuş depoyu çağırır; vazgeçme sessizdir; gerçek hata katalog
//     cümlesine döner.
//  4. Bir akış sürerken (Google veya Apple) öteki başlatılamaz.
//  5. Yalnız Apple/Google ile açılmış (şifresiz) hesap, hesabını şifre
//     sorulmadan silme için planlayabilir.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/supabase_config.dart';
import 'package:online_study_room/data/models/account_deletion_status.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/auth/apple_sign_in_availability.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/auth/google_sign_in_availability.dart';
import 'package:online_study_room/features/profile/account_settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const _appleButton = Key('auth-apple-sign-in');
const _googleButton = Key('auth-google-sign-in');

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(List<Override> overrides, {Widget home = const AuthScreen()}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class _Repo extends InMemoryAuthRepository {
  _Repo({this.appleError, this.appleGate, this.googleGate});

  final AuthException? appleError;
  final Completer<void>? appleGate;
  final Completer<void>? googleGate;
  int appleCalls = 0;
  int googleCalls = 0;

  Profile get _profile => Profile(
    id: 'apple-user',
    displayName: 'Ayşe',
    createdAt: DateTime(2026, 9, 22),
  );

  @override
  Future<Profile> signInWithApple() async {
    appleCalls++;
    final g = appleGate;
    if (g != null) await g.future;
    final e = appleError;
    if (e != null) throw e;
    return _profile;
  }

  @override
  Future<Profile> signInWithGoogle() async {
    googleCalls++;
    final g = googleGate;
    if (g != null) await g.future;
    return _profile;
  }
}

/// Ekranın gerçekte gördüğü karar: o anki platform + Supabase arka ucu.
bool _appleForCurrentPlatform() => resolveAppleSignInEnabled(
  isWeb: false,
  platform: defaultTargetPlatform,
  supabaseBackend: true,
);

SignInWithAppleButton _apple(WidgetTester tester) =>
    tester.widget<SignInWithAppleButton>(find.byKey(_appleButton));

OutlinedButton _google(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.byKey(_googleButton));

void main() {
  group('WP-902 gorunurluk', () {
    testWidgets(
      'iOS: Apple dugmesi cizilir, Google\'in USTUNDE',
      (tester) async {
        _useTallPhone(tester);
        await tester.pumpWidget(
          _app([
            authRepositoryProvider.overrideWithValue(_Repo()),
            appleSignInEnabledProvider.overrideWithValue(
              _appleForCurrentPlatform(),
            ),
            googleSignInEnabledProvider.overrideWithValue(true),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_appleButton), findsOneWidget);
        expect(find.text('Apple ile devam et'), findsOneWidget);
        expect(find.text('veya'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(_appleButton)).dy,
          lessThan(tester.getTopLeft(find.byKey(_googleButton)).dy),
        );
        // HIG: en az 44 dp yükseklik; form sütununu taşmaz.
        final size = tester.getSize(find.byKey(_appleButton));
        expect(size.height, 44);
        expect(size.width, lessThanOrEqualTo(380));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'iOS: Google kapaliyken de Apple ve ayirici cizilir',
      (tester) async {
        _useTallPhone(tester);
        await tester.pumpWidget(
          _app([
            authRepositoryProvider.overrideWithValue(_Repo()),
            appleSignInEnabledProvider.overrideWithValue(
              _appleForCurrentPlatform(),
            ),
            googleSignInEnabledProvider.overrideWithValue(false),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_appleButton), findsOneWidget);
        expect(find.byKey(_googleButton), findsNothing);
        expect(find.text('veya'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'Android: Apple dugmesi cizilmez',
      (tester) async {
        _useTallPhone(tester);
        await tester.pumpWidget(
          _app([
            authRepositoryProvider.overrideWithValue(_Repo()),
            appleSignInEnabledProvider.overrideWithValue(
              _appleForCurrentPlatform(),
            ),
            googleSignInEnabledProvider.overrideWithValue(true),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_appleButton), findsNothing);
        expect(find.text('Apple ile devam et'), findsNothing);
        expect(find.byKey(_googleButton), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'Windows: Apple dugmesi cizilmez',
      (tester) async {
        _useTallPhone(tester);
        await tester.pumpWidget(
          _app([
            authRepositoryProvider.overrideWithValue(_Repo()),
            appleSignInEnabledProvider.overrideWithValue(
              _appleForCurrentPlatform(),
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_appleButton), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    test('saglayici: iOS\'ta Supabase bayragini, digerlerinde false', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        final container = ProviderContainer();
        try {
          expect(
            container.read(appleSignInEnabledProvider),
            platform == TargetPlatform.iOS && SupabaseConfig.isConfigured,
            reason: '$platform',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
          container.dispose();
        }
      }
    });
  });

  group('WP-902 dokunus', () {
    List<Override> overrides(_Repo repo) => [
      authRepositoryProvider.overrideWithValue(repo),
      appleSignInEnabledProvider.overrideWithValue(true),
      googleSignInEnabledProvider.overrideWithValue(true),
    ];

    testWidgets('basari: depo cagrilir, hata ve form uyarisi yok', (
      tester,
    ) async {
      _useTallPhone(tester);
      final repo = _Repo();
      await tester.pumpWidget(_app(overrides(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_appleButton));
      await tester.pumpAndSettle();

      expect(repo.appleCalls, 1);
      expect(repo.googleCalls, 0);
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
      expect(find.text('Geçerli bir e-posta girin'), findsNothing);
    });

    testWidgets('vazgecme: ekranda HICBIR sey gorunmez', (tester) async {
      _useTallPhone(tester);
      final repo = _Repo(
        appleError: const AuthException(
          'apple_sign_in_cancelled',
          code: AuthErrorCode.cancelled,
        ),
      );
      await tester.pumpWidget(_app(overrides(repo)));
      await tester.pumpAndSettle();
      final textsBefore = find.byType(Text).evaluate().length;

      await tester.tap(find.byKey(_appleButton));
      await tester.pumpAndSettle();

      expect(repo.appleCalls, 1);
      expect(find.textContaining('apple_sign_in'), findsNothing);
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
      expect(find.byType(Text).evaluate().length, textsBefore);
      expect(_apple(tester).onPressed, isNotNull);
    });

    testWidgets('kodsuz hata generic, kodlu hata katalog cumlesi', (
      tester,
    ) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(
          overrides(
            _Repo(appleError: const AuthException('apple_id_token_missing')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_appleButton));
      await tester.pumpAndSettle();
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsOneWidget);
      expect(find.text('apple_id_token_missing'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(
          overrides(
            _Repo(
              appleError: const AuthException(
                'offline',
                code: AuthErrorCode.network,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_appleButton));
      await tester.pumpAndSettle();
      expect(
        find.text('Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.'),
        findsOneWidget,
      );
    });

    testWidgets('Google akisi surerken Apple baslatilamaz', (tester) async {
      _useTallPhone(tester);
      final gate = Completer<void>();
      final repo = _Repo(googleGate: gate);
      await tester.pumpWidget(_app(overrides(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_googleButton));
      await tester.pump();

      expect(_apple(tester).onPressed, isNull);
      await tester.tap(find.byKey(_appleButton), warnIfMissed: false);
      await tester.pump();
      expect(repo.appleCalls, 0);
      expect(repo.googleCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(_apple(tester).onPressed, isNotNull);
    });

    testWidgets('Apple akisi surerken ikinci Apple / Google baslatilamaz', (
      tester,
    ) async {
      _useTallPhone(tester);
      final gate = Completer<void>();
      final repo = _Repo(appleGate: gate);
      await tester.pumpWidget(_app(overrides(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_appleButton));
      await tester.pump();

      expect(_apple(tester).onPressed, isNull);
      expect(_google(tester).onPressed, isNull);
      await tester.tap(find.byKey(_appleButton), warnIfMissed: false);
      await tester.tap(find.byKey(_googleButton), warnIfMissed: false);
      await tester.pump();
      expect(repo.appleCalls, 1);
      expect(repo.googleCalls, 0);

      gate.complete();
      await tester.pumpAndSettle();
      expect(_apple(tester).onPressed, isNotNull);
      expect(_google(tester).onPressed, isNotNull);
    });
  });

  group('WP-902 sifresiz hesap uygulama icinde silinebilir', () {
    testWidgets('sifre alani yok, signIn cagrilmaz, silme planlanir', (
      tester,
    ) async {
      _useTallPhone(tester);
      final repo = _DeletionRepo(hasPassword: false);
      await repo.signUp(
        email: 'x7@privaterelay.appleid.com',
        password: 'kullanilmaz1',
        displayName: 'Ayşe',
      );
      await tester.pumpWidget(
        _app([
          authRepositoryProvider.overrideWithValue(repo),
        ], home: const AccountSettingsScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_forever));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deleteAccountPassword')), findsNothing);
      expect(
        find.text(
          'Hesabın 14 gün içinde kalıcı silinmek üzere planlanır. Bu süre '
          'içinde iptal edebilirsin.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('deleteAccountSubmit')));
      await tester.pumpAndSettle();

      expect(repo.signInCalls, 0);
      expect(repo.requestCalls, 1);
      expect(find.textContaining('Silme planlandı'), findsWidgets);
    });

    testWidgets('sifreli hesapta sifre hala sorulur (degismedi)', (
      tester,
    ) async {
      _useTallPhone(tester);
      final repo = _DeletionRepo(hasPassword: true);
      await repo.signUp(
        email: 'ali@ornek.com',
        password: 'guvenli123',
        displayName: 'Ali',
      );
      await tester.pumpWidget(
        _app([
          authRepositoryProvider.overrideWithValue(repo),
        ], home: const AccountSettingsScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_forever));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('deleteAccountPassword')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('deleteAccountPassword')),
        'guvenli123',
      );
      await tester.tap(find.byKey(const Key('deleteAccountSubmit')));
      await tester.pumpAndSettle();

      expect(repo.signInCalls, 1);
      expect(repo.requestCalls, 1);
    });
  });
}

class _DeletionRepo extends InMemoryAuthRepository {
  _DeletionRepo({required this.hasPassword});

  final bool hasPassword;
  int signInCalls = 0;
  int requestCalls = 0;
  AccountDeletionStatus _status = AccountDeletionStatus.inactive;

  @override
  bool get currentUserHasPassword => hasPassword;

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return super.signIn(email: email, password: password);
  }

  @override
  Future<AccountDeletionStatus> requestAccountDeletion() async {
    requestCalls++;
    _status = AccountDeletionStatus(
      active: true,
      purgeAfter: DateTime.utc(2026, 10, 6),
    );
    return _status;
  }

  @override
  Future<AccountDeletionStatus> fetchAccountDeletionStatus() async => _status;
}
