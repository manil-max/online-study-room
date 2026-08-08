// WP-539: kimlik akışındaki hata mesajları — depo **kodu** taşır, ekran metni
// üretir.
//
// 🔴 Bu dosyanın varlık sebebi iki YALANCI YEŞİL:
//
//  B11: `account_settings_screen.dart`taki
//       `AuthErrorCode.network => l10n.profileSunucuyaUlasilamadi` satırı
//       silindiğinde 15 test yeşil kaldı — ekran katmanının **kodu metne
//       çevirdiğini** ölçen hiçbir test yoktu.
//  B12: `signup_group_feedback_wp530_test.dart` sahtesi üretim metnini import
//       etmiyor, kendi kopyasını fırlatıyor; depo cümlesi değişirse akış
//       bozulur ama test kırılmaz.
//
// Bu yüzden ölçüm iki uçtan yapılır ve ikisi de üretim sembolünü kullanır:
//   (1) DEPO UCU — gerçek `SupabaseAuthRepository`, sahte HTTP istemcisiyle:
//       sunucunun gerçek gotrue cevabı hangi `AuthErrorCode`u üretiyor?
//   (2) EKRAN UCU — gerçek `AuthScreen`/`RecoveryScreen`/`AuthGate`: o kod
//       ekranda hangi katalog cümlesine dönüşüyor?
// Aradaki sözleşme string değil `AuthErrorCode` sabitidir; sahte repo o sabiti
// üretimden import eder, kendi kopyasını uydurmaz.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/push_notification_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_gate.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/auth/recovery_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
// `show`: supabase da `AuthException` tanımlıyor; bizimkiyle çarpışmasın.
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, AuthFlowType, SupabaseClient;

// ---------------------------------------------------------------------------
// Ortak yardımcılar
// ---------------------------------------------------------------------------

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
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

/// Verilen kodu **üretimden** alıp fırlatan sahte depo.
///
/// Kritik ayrıntı: mesaj bilerek anlamsız bir teknik dize. Ekran metni
/// mesajdan türetirse test kırmızı düşer — bu dosyanın asıl kilidi budur.
class _CodedAuthRepository extends InMemoryAuthRepository {
  _CodedAuthRepository({this.signInError, this.resetError, this.updateError});

  final AuthException? signInError;
  final AuthException? resetError;
  final AuthException? updateError;

  int signInCalls = 0;

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    final error = signInError;
    if (error != null) throw error;
    return super.signIn(email: email, password: password);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final error = resetError;
    if (error != null) throw error;
    await super.sendPasswordResetEmail(email);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final error = updateError;
    if (error != null) throw error;
    await super.updatePassword(newPassword);
  }
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

/// Gerçek depo + sahte gotrue sunucusu.
SupabaseAuthRepository _repositoryAnswering(
  Future<http.StreamedResponse> Function(http.BaseRequest request) handler,
) {
  return SupabaseAuthRepository(
    SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      httpClient: _FakeClient(handler),
      // PKCE akışı `asyncStorage` istiyor; testte kurulu bir depo yok ve o
      // assert hatası ölçmek istediğimiz hatayı gizliyordu.
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Ekranı sürmek için küçük yardımcılar
// ---------------------------------------------------------------------------

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

void main() {
  // -------------------------------------------------------------------------
  // (1) DEPO UCU — gotrue cevabı → AuthErrorCode
  // -------------------------------------------------------------------------
  group('WP-539 depo: giris yolu hatanin nedenini kodla tasir', () {
    test('dogrulanmamis e-posta -> emailNotConfirmed', () async {
      final repository = _repositoryAnswering(
        (request) async => _json(request, {
          'error_code': 'email_not_confirmed',
          'msg': 'Email not confirmed',
          'message': 'Email not confirmed',
        }, status: 400),
      );

      await expectLater(
        repository.signIn(email: 'ali@ornek.com', password: 'guvenli123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.emailNotConfirmed,
          ),
        ),
      );
    });

    test('yanlis sifre -> invalidCredentials', () async {
      final repository = _repositoryAnswering(
        (request) async => _json(request, {
          'error_code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
          'message': 'Invalid login credentials',
        }, status: 400),
      );

      await expectLater(
        repository.signIn(email: 'ali@ornek.com', password: 'yanlis'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.invalidCredentials,
          ),
        ),
      );
    });

    // Sahadaki ölçüm: `ClientException: connection closed` → ekranda generic.
    test('ag hatasi -> network', () async {
      final repository = _repositoryAnswering(
        (_) async => throw http.ClientException('connection closed'),
      );

      await expectLater(
        repository.signIn(email: 'ali@ornek.com', password: 'guvenli123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.network,
          ),
        ),
      );
    });

    test('sifremi unuttum hiz siniri -> rateLimited', () async {
      final repository = _repositoryAnswering(
        (request) async => _json(request, {
          'error_code': 'over_request_rate_limit',
          'msg': 'For security purposes, you can only request this after 25s.',
          'message':
              'For security purposes, you can only request this after 25s.',
        }, status: 429),
      );

      await expectLater(
        repository.sendPasswordResetEmail('ali@ornek.com'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.rateLimited,
          ),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // (2) EKRAN UCU — AuthErrorCode → katalog cümlesi
  // -------------------------------------------------------------------------
  group('WP-539 giris ekrani: her kod dogru cumleye donusur', () {
    // 🔴 B11'in kilidi. Tablodaki her satır ekran katmanındaki **bir** switch
    // koluna karşılık gelir; kol silinirse o satır kırmızı düşer.
    const cases = <String, String>{
      AuthErrorCode.emailNotConfirmed: 'E-posta doğrulaması gerekiyor.',
      AuthErrorCode.invalidCredentials: 'E-posta veya şifre hatalı.',
      AuthErrorCode.emailAlreadyInUse: 'Bu e-posta zaten kayıtlı.',
      AuthErrorCode.invalidEmail: 'Geçerli bir e-posta girin',
      AuthErrorCode.weakPassword: 'Şifre en az 6 karakter olmalı',
      AuthErrorCode.rateLimited: 'Çok sık denedin. Biraz bekleyip tekrar dene.',
      AuthErrorCode.network:
          'Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.',
    };

    cases.forEach((code, expected) {
      testWidgets('$code -> "$expected"', (tester) async {
        _useTallPhone(tester);
        final repo = _CodedAuthRepository(
          // Mesaj kasten anlamsız: ekran metni buradan türetirse test düşer.
          signInError: AuthException('server said $code', code: code),
        );
        await tester.pumpWidget(
          _app(const AuthScreen(), [
            authRepositoryProvider.overrideWithValue(repo),
          ]),
        );
        await tester.pumpAndSettle();
        await _login(tester);

        expect(repo.signInCalls, 1);
        expect(
          find.text(expected),
          findsWidgets,
          reason:
              'ekran $code kodunu katalog cümlesine çevirmedi; '
              'switch kolu eksik veya yanlış anahtara bağlı',
        );
        expect(
          find.text('Beklenmeyen bir hata oluştu.'),
          findsNothing,
          reason: 'bilinen bir neden generic mesaja düşürülmemeli',
        );
      });
    });

    testWidgets('bilinmeyen kod generic mesaja duser', (tester) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(const AuthScreen(), [
          authRepositoryProvider.overrideWithValue(
            _CodedAuthRepository(
              signInError: const AuthException('boom', code: 'kim_bilir'),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await _login(tester);

      expect(find.text('Beklenmeyen bir hata oluştu.'), findsOneWidget);
    });

    testWidgets('sunucu ham metni kullaniciya sizmaz', (tester) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(const AuthScreen(), [
          authRepositoryProvider.overrideWithValue(
            _CodedAuthRepository(
              signInError: const AuthException(
                'Email not confirmed',
                code: AuthErrorCode.emailNotConfirmed,
              ),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await _login(tester);

      expect(find.text('Email not confirmed'), findsNothing);
      expect(find.text('E-posta doğrulaması gerekiyor.'), findsOneWidget);
    });

    testWidgets('"Sifremi unuttum" hiz sinirini generic yapmaz', (
      tester,
    ) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(const AuthScreen(), [
          authRepositoryProvider.overrideWithValue(
            _CodedAuthRepository(
              resetError: const AuthException(
                'rate limited',
                code: AuthErrorCode.rateLimited,
              ),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'ali@ornek.com',
      );
      await tester.tap(find.text('Şifremi unuttum'));
      await tester.pumpAndSettle();

      expect(
        find.text('Çok sık denedin. Biraz bekleyip tekrar dene.'),
        findsOneWidget,
      );
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // (3) ÇIKMAZ YOL — kod ile sıfırlama erişilemez
  // -------------------------------------------------------------------------
  group('WP-539 cikmaz yol: kod ile sifirlama kapali', () {
    testWidgets('kod yolu dugmesi cizilmez, calisan yol durur', (tester) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(const AuthScreen(), [
          authRepositoryProvider.overrideWithValue(_CodedAuthRepository()),
        ]),
      );
      await tester.pumpAndSettle();

      // Supabase ücretsiz plan kurtarma şablonunu kilitlediği için e-postada
      // 6 haneli kod YOK (docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md:9-14). Düğme
      // açık kaldığı sürece kullanıcı "kod geçersiz → yeni kod iste → yine
      // gelmiyor" döngüsüne giriyordu.
      expect(find.byKey(const Key('auth-reset-with-code')), findsNothing);
      expect(find.text('Bunun yerine kodu gir'), findsNothing);
      expect(
        kResetWithCodeEnabled,
        isFalse,
        reason: 'bayrak varsayılan olarak kapalı olmalı',
      );
      // Çalışan yol açık kalmalı: kapatmak kullanıcıyı yine çıkışsız bırakırdı.
      expect(find.text('Şifremi unuttum'), findsOneWidget);
    });

    testWidgets('sifirlama e-postasi gonderilince baglanti yolu anlatilir', (
      tester,
    ) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(const AuthScreen(), [
          authRepositoryProvider.overrideWithValue(_CodedAuthRepository()),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'ali@ornek.com',
      );
      await tester.tap(find.text('Şifremi unuttum'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Şifre sıfırlama bağlantısı e-postana gönderildi. '
          'Gelen kutunu kontrol et.',
        ),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // (4) KURTARMA EKRANI — üç sebep üç ayrı cümle
  // -------------------------------------------------------------------------
  group('WP-539 kurtarma ekrani: istisna gercekten okunuyor', () {
    const cases = <String, String>{
      AuthErrorCode.noSession:
          'Şifre sıfırlama bağlantısı artık geçerli değil. '
              'Yeni bir sıfırlama e-postası iste.',
      AuthErrorCode.network:
          'Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.',
      AuthErrorCode.rateLimited: 'Çok sık denedin. Biraz bekleyip tekrar dene.',
    };

    cases.forEach((code, expected) {
      testWidgets('$code -> "$expected"', (tester) async {
        _useTallPhone(tester);
        await tester.pumpWidget(
          _app(const RecoveryScreen(), [
            authRepositoryProvider.overrideWithValue(
              _CodedAuthRepository(
                updateError: AuthException('server said $code', code: code),
              ),
            ),
          ]),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField),
          'yeniguvenli456',
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
        expect(
          find.text('Beklenmeyen bir hata oluştu.'),
          findsNothing,
          reason:
              'eskiden `on AuthException {` idi: istisna hiç bağlanmıyordu ve '
              'üç sebep tek cümleye düşüyordu',
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // (5) AUTH GATE — hata ekranının çıkışı var
  // -------------------------------------------------------------------------
  group('WP-539 auth gate: hata ekrani cikissiz degil', () {
    testWidgets('tekrar dene + cikis yap gorunur ve calisir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      _useTallPhone(tester);
      final repo = _CodedAuthRepository();
      var streamBuilds = 0;

      await tester.pumpWidget(
        _app(const AuthGate(), [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(repo),
          pushLifecycleListenerProvider.overrideWithValue(null),
          authStateProvider.overrideWith((ref) {
            streamBuilds++;
            return Stream<Profile?>.error(StateError('auth stream down'));
          }),
        ]),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Oturum durumu okunamadı. Bağlantını kontrol edip tekrar dene.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('auth-gate-retry')), findsOneWidget);
      expect(find.byKey(const Key('auth-gate-signout')), findsOneWidget);

      // Ölü anahtar olmasın: "Tekrar dene" akışı gerçekten yeniden kuruyor.
      final before = streamBuilds;
      await tester.tap(find.byKey(const Key('auth-gate-retry')));
      await tester.pump();
      await tester.pump();
      expect(
        streamBuilds,
        greaterThan(before),
        reason: '"Tekrar dene" oturum akışını yeniden kurmalı',
      );
    });
  });
}
