// WP-587: kayıt doğrulama e-postası gelmezse kullanıcının çıkışı.
//
// 🔴 Ölçülen boşluk: e-posta doğrulaması açıkken `signUp` oturum döndürmüyor,
// depo "hesabın oluşturuldu, e-postana bak" diyor, ekran giriş moduna dönüyor —
// ve orada duruyor. `app/lib` genelinde `resend` araması **0 sonuç** veriyordu:
// posta gelmezse (ücretsiz katmanın saatlik gönderim sınırı, spam klasörü,
// kuyruğun düşmesi) hesap var, giriş yok, çıkış yok.
//
// Ölçüm WP-539'un iki uçlu desenini izler ve iki uç da üretim sembolünü
// kullanır:
//   (1) DEPO UCU  — gerçek `SupabaseAuthRepository` + sahte gotrue: çağrı
//       gerçekten `/resend`e gidiyor mu, hız sınırı hangi koda dönüşüyor?
//   (2) EKRAN UCU — gerçek `AuthScreen`: düğme YALNIZ doğrulanmamış e-posta
//       durumunda çiziliyor mu, bastığında gerçekten çağırıyor mu, hız sınırı
//       generic'e mi düşüyor?
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
// `show`: supabase da `AuthException` tanımlıyor; bizimkiyle çarpışmasın.
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, AuthFlowType, SupabaseClient;

const _resendLabel = 'Doğrulama e-postasını yeniden gönder';
const _resendKey = Key('auth-resend-verification');
const _spamHint =
    'Doğrulama bağlantısı için gelen kutunu ve spam/gereksiz klasörünü '
    'kontrol et.';
const _resentInfo =
    'Doğrulama e-postası yeniden gönderildi. Gelen kutunu ve spam klasörünü '
    'kontrol et.';
const _rateLimited = 'Çok sık denedin. Biraz bekleyip tekrar dene.';
const _generic = 'Beklenmeyen bir hata oluştu.';

// ---------------------------------------------------------------------------
// Ortak yardımcılar
// ---------------------------------------------------------------------------

void _useTallPhone(WidgetTester tester) {
  // Uzun ekran: yeni ipucu + düğme eklendiğinde `tap` kaydırma gerektirmesin.
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(Widget home, List<Override> overrides) {
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

http.StreamedResponse _json(
  http.BaseRequest request,
  Object body, {
  int status = 200,
}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    status,
    request: request,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

/// Gerçek depo + sahte gotrue sunucusu (WP-539 ile aynı koşum).
SupabaseAuthRepository _repositoryAnswering(
  Future<http.StreamedResponse> Function(http.BaseRequest request) handler,
) {
  return SupabaseAuthRepository(
    SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      httpClient: _FakeClient(handler),
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    ),
  );
}

/// Ekran ucu için sahte depo. Sayaç `InMemoryAuthRepository`den gelir; bu
/// dosya kendi kopyasını uydurmaz.
class _ResendAuthRepository extends InMemoryAuthRepository {
  _ResendAuthRepository({this.signInError, this.signUpError, this.resendError});

  final AuthException? signInError;
  final AuthException? signUpError;
  final AuthException? resendError;

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    final error = signInError;
    if (error != null) throw error;
    return super.signIn(email: email, password: password);
  }

  @override
  Future<Profile> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final error = signUpError;
    if (error != null) throw error;
    return super.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  @override
  Future<void> resendVerificationEmail(String email) async {
    final error = resendError;
    if (error != null) throw error;
    await super.resendVerificationEmail(email);
  }
}

Future<void> _pumpAuth(WidgetTester tester, AuthRepository repo) async {
  _useTallPhone(tester);
  await tester.pumpWidget(
    _app(const AuthScreen(), [authRepositoryProvider.overrideWithValue(repo)]),
  );
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'E-posta'),
    'ali@ornek.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Şifre'),
    'guvenli123',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
  await tester.pumpAndSettle();
}

Future<void> _register(WidgetTester tester) async {
  await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Görünen ad'),
    'Yeni Kullanıcı',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'E-posta'),
    'yeni@ornek.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Şifre'),
    'guvenli123',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // (1) DEPO UCU — çağrı gerçekten gotrue `/resend`e gidiyor
  // -------------------------------------------------------------------------
  group('WP-587 depo: dogrulama postasi yeniden gonderilir', () {
    test('cagri /resend uc noktasina signup tipiyle gider', () async {
      String? path;
      Map<String, dynamic>? body;
      final repository = _repositoryAnswering((request) async {
        path = request.url.path;
        if (request is http.Request) {
          body = jsonDecode(request.body) as Map<String, dynamic>;
        }
        return _json(request, <String, dynamic>{});
      });

      await repository.resendVerificationEmail('  Ali@Ornek.com  ');

      // 🔴 Ölü yol kapanı: metot sessizce hiçbir şey yapmazsa burası düşer.
      expect(path, endsWith('/resend'));
      expect(body?['type'], 'signup');
      expect(body?['email'], 'Ali@Ornek.com', reason: 'boşluklar kırpılmalı');
    });

    test('hiz siniri -> rateLimited (generic degil)', () async {
      final repository = _repositoryAnswering(
        (request) async => _json(request, {
          'error_code': 'over_email_send_rate_limit',
          'msg': 'For security purposes, you can only request this after 51s.',
          'message':
              'For security purposes, you can only request this after 51s.',
        }, status: 429),
      );

      await expectLater(
        repository.resendVerificationEmail('ali@ornek.com'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.rateLimited,
          ),
        ),
      );
    });

    test('gecersiz e-posta sunucuya hic gitmez', () async {
      var calls = 0;
      final repository = _repositoryAnswering((request) async {
        calls++;
        return _json(request, <String, dynamic>{});
      });

      await expectLater(
        repository.resendVerificationEmail('bos-degil-ama-eposta-degil'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.invalidEmail,
          ),
        ),
      );
      expect(calls, 0);
    });
  });

  // -------------------------------------------------------------------------
  // (2) EKRAN UCU — düğme yalnız doğru durumda çizilir ve gerçekten çalışır
  // -------------------------------------------------------------------------
  group('WP-587 ekran: yeniden gonder yalniz dogrulanmamis e-postada', () {
    // 🔴 Tek yönlü iddia kapanı: düğme koşulsuz çizilirse bu iki test düşer.
    testWidgets('acilista dugme yok', (tester) async {
      await _pumpAuth(tester, _ResendAuthRepository());

      expect(find.byKey(_resendKey), findsNothing);
      expect(find.text(_resendLabel), findsNothing);
      expect(find.text(_spamHint), findsNothing);
    });

    testWidgets('yanlis sifre hatasinda dugme yok', (tester) async {
      await _pumpAuth(
        tester,
        _ResendAuthRepository(
          signInError: const AuthException(
            'server said invalid_credentials',
            code: AuthErrorCode.invalidCredentials,
          ),
        ),
      );
      await _login(tester);

      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
      expect(
        find.byKey(_resendKey),
        findsNothing,
        reason:
            'doğrulama sorunu olmayan hatada "yeniden gönder" yanlış yönlendirir',
      );
    });

    testWidgets('emailNotConfirmed girisinde dugme + ne yapilacagi gorunur', (
      tester,
    ) async {
      await _pumpAuth(
        tester,
        _ResendAuthRepository(
          signInError: const AuthException(
            'server said email_not_confirmed',
            code: AuthErrorCode.emailNotConfirmed,
          ),
        ),
      );
      await _login(tester);

      expect(find.text('E-posta doğrulaması gerekiyor.'), findsOneWidget);
      expect(find.byKey(_resendKey), findsOneWidget);
      expect(find.text(_resendLabel), findsOneWidget);
      expect(
        find.text(_spamHint),
        findsOneWidget,
        reason: 'kullanıcıya ne yapacağı (gelen kutusu + spam) söylenmeli',
      );
    });

    testWidgets('kayit dogrulama bekliyorsa cikis ayni ekranda duruyor', (
      tester,
    ) async {
      await _pumpAuth(
        tester,
        _ResendAuthRepository(
          // Depo `signUp`ın oturumsuz ucunda tam bu cümleyi fırlatıyor.
          signUpError: const AuthException(
            'Hesabın oluşturuldu. Giriş yapabilmek için e-postana gönderilen '
            'doğrulama bağlantısına tıkla.',
          ),
        ),
      );
      await _register(tester);

      // Kayıt onayı modalı kapanınca ekran giriş moduna döner — WP-587 öncesi
      // kullanıcının gördüğü son şey buydu ve yapabileceği bir şey yoktu.
      await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
      await tester.pumpAndSettle();

      expect(find.text('E-posta doğrulaması gerekiyor.'), findsOneWidget);
      expect(find.byKey(_resendKey), findsOneWidget);
      expect(find.text(_spamHint), findsOneWidget);
    });

    // 🔴 Ölü anahtar kapanı: `onPressed` null'a çekilirse sayaç 0'da kalır.
    testWidgets('dugmeye basmak depoyu gercekten cagirir', (tester) async {
      final repo = _ResendAuthRepository(
        signInError: const AuthException(
          'server said email_not_confirmed',
          code: AuthErrorCode.emailNotConfirmed,
        ),
      );
      await _pumpAuth(tester, repo);
      await _login(tester);

      expect(repo.resendVerificationCalls, 0);
      await tester.tap(find.byKey(_resendKey));
      await tester.pumpAndSettle();

      expect(
        repo.resendVerificationCalls,
        1,
        reason: 'düğme çiziliyor ama depoya hiç ulaşmıyor (ölü anahtar)',
      );
      expect(
        find.text(_resentInfo),
        findsOneWidget,
        reason: 'kullanıcı gönderimin olduğunu görmeli',
      );
    });

    testWidgets('hiz siniri generic mesaja dusmez, dugme kaybolmaz', (
      tester,
    ) async {
      await _pumpAuth(
        tester,
        _ResendAuthRepository(
          signInError: const AuthException(
            'server said email_not_confirmed',
            code: AuthErrorCode.emailNotConfirmed,
          ),
          resendError: const AuthException(
            'server said rate_limited',
            code: AuthErrorCode.rateLimited,
          ),
        ),
      );
      await _login(tester);
      await tester.tap(find.byKey(_resendKey));
      await tester.pumpAndSettle();

      expect(find.text(_rateLimited), findsOneWidget);
      expect(find.text(_generic), findsNothing);
      expect(
        find.byKey(_resendKey),
        findsOneWidget,
        reason: 'düğme kaybolursa kullanıcı yine çıkışsız kalır',
      );
    });
  });
}
