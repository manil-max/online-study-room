// WP-616: Windows'ta şifre sıfırlamanın çalışan yolu YOK — ekran "gönderildi"
// diyordu.
//
// 🔴 Ölçülen boşluk (`docs/denetim/DENETIM-auth.md` KANAMA-1): masaüstünde
// `resolveRecoveryRedirect()` null döner → Supabase bağlantıyı Android'e özel
// scheme'e düşürür → Windows'ta o bağlantıyı açacak kayıt yok. Yedek olan
// 6 haneli kod ekranı ücretsiz katmanda kapalı, PKCE yüzünden postayı telefonda
// açmak da kurtarmıyor. Buna rağmen `_sendPasswordReset` her platformda
// e-postayı gönderip "Şifre sıfırlama bağlantısı e-postana gönderildi." yazıyordu.
//
// Ölçüm iki yönlüdür ve platform **enjekte edilir**
// (`debugDefaultTargetPlatformOverride`), gerçek host platformuna bağlanmaz:
//   (1) MASAÜSTÜ — depoya hiç gidilmez, kullanıcıya gerçek + çalışan yol söylenir.
//   (2) ANDROID  — eski davranış AYNEN durur (gönderim + "gönderildi" metni).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/auth/password_reset_platform.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _forgotLabel = 'Şifremi unuttum';
const _sentInfo =
    'Şifre sıfırlama bağlantısı e-postana gönderildi. Gelen kutunu kontrol et.';
const _desktopTitle = 'Şifre sıfırlama bu bilgisayarda çalışmıyor';
const _dialogKey = Key('auth-reset-desktop-unavailable');

/// Gönderim sayacı: ekran depoya gidiyor mu, gitmiyor mu — tek ölçüm noktası.
class _CountingAuthRepository extends InMemoryAuthRepository {
  int passwordResetCalls = 0;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    passwordResetCalls++;
    await super.sendPasswordResetEmail(email);
  }
}

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Platform **enjekte edilir**; gövde bitince mutlaka geri alınır (aksi hâlde
/// flutter_test "foundation debug variable was changed" diye düşer ve sızıntı
/// bir sonraki testi sessizce etkiler).
Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpAuth(WidgetTester tester, AuthRepository repo) async {
  _useTallPhone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AuthScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapForgotPassword(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'E-posta'),
    'ali@ornek.com',
  );
  await tester.tap(find.text(_forgotLabel));
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // (0) Saf karar — hangi platformda bağlantı gerçekten açılıyor
  // -------------------------------------------------------------------------
  group('WP-616 karar: baglantiyi yalniz Android acabiliyor', () {
    test('Android true, masaustu uclarinin hepsi false', () {
      expect(passwordResetLinkOpensHere(platform: TargetPlatform.android), isTrue);
      for (final platform in const [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(
          passwordResetLinkOpensHere(platform: platform),
          isFalse,
          reason: '$platform derin bağlantı scheme kaydı yok',
        );
      }
    });

    test('web Android raporlasa bile false', () {
      // Web derlemesinde de karşılayıcı yok; `defaultTargetPlatform` orada
      // işletim sistemini söyler ve tek başına yanıltır.
      expect(
        passwordResetLinkOpensHere(
          platform: TargetPlatform.android,
          isWeb: true,
        ),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // (1) MASAÜSTÜ — yalan biter: e-posta gönderilmez, gerçek yol söylenir
  // -------------------------------------------------------------------------
  group('WP-616 masaustu: gonderildi denmez', () {
    testWidgets('Windows: depoya hic gidilmez', (tester) async {
      final repo = _CountingAuthRepository();
      await _onPlatform(TargetPlatform.windows, () async {
        await _pumpAuth(tester, repo);
        await _tapForgotPassword(tester);
      });

      expect(
        repo.passwordResetCalls,
        0,
        reason:
            'açılamayacak bir bağlantı için e-posta göndermek kullanıcıyı '
            'bekletmekten başka bir şey yapmıyor',
      );
    });

    testWidgets('Windows: "gonderildi" metni cikmaz', (tester) async {
      await _onPlatform(TargetPlatform.windows, () async {
        await _pumpAuth(tester, _CountingAuthRepository());
        await _tapForgotPassword(tester);
      });

      expect(
        find.text(_sentInfo),
        findsNothing,
        reason: 'KANAMA-1 tam olarak bu cümleydi',
      );
    });

    testWidgets('Windows: calisan yol (telefondaki uygulama) gosterilir', (
      tester,
    ) async {
      await _onPlatform(TargetPlatform.windows, () async {
        await _pumpAuth(tester, _CountingAuthRepository());
        await _tapForgotPassword(tester);
      });

      expect(find.byKey(_dialogKey), findsOneWidget);
      expect(find.text(_desktopTitle), findsOneWidget);

      final body = tester.widget<Text>(
        find.byKey(const Key('auth-reset-desktop-body')),
      );
      final text = body.data ?? '';
      expect(
        text,
        contains('Android'),
        reason: 'kullanıcıya nereye gideceği söylenmeli',
      );
      expect(
        text,
        contains('Şifremi unuttum'),
        reason: 'telefonda basacağı düğmenin adı verilmeli',
      );
    });

    testWidgets('macOS ucu da ayni davranir', (tester) async {
      final repo = _CountingAuthRepository();
      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpAuth(tester, repo);
        await _tapForgotPassword(tester);
      });

      expect(repo.passwordResetCalls, 0);
      expect(find.byKey(_dialogKey), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // (2) ANDROID — eski, çalışan davranış AYNEN duruyor
  // -------------------------------------------------------------------------
  group('WP-616 Android: calisan yol bozulmadi', () {
    testWidgets('gonderim gercekten yapilir ve onay metni cikar', (
      tester,
    ) async {
      final repo = _CountingAuthRepository();
      await _onPlatform(TargetPlatform.android, () async {
        await _pumpAuth(tester, repo);
        await _tapForgotPassword(tester);
      });

      expect(
        repo.passwordResetCalls,
        1,
        reason: 'Android derin bağlantı yolu çalışıyor, kapatılmamalı',
      );
      expect(find.text(_sentInfo), findsOneWidget);
    });

    testWidgets('masaustu uyarisi Android tarafinda cizilmez', (tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        await _pumpAuth(tester, _CountingAuthRepository());
        await _tapForgotPassword(tester);
      });

      expect(find.byKey(_dialogKey), findsNothing);
      expect(find.text(_desktopTitle), findsNothing);
    });
  });
}
