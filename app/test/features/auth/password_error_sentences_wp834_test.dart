// WP-834: şifre yazan ÜÇ ekran da aynı sebebi aynı cümleye çeviriyor mu?
//
// Sahip v85'te (gerçek cihaz, production) sıfırlama bağlantısından gelip yeni
// şifresini yazdı, "Beklenmeyen bir hata oluştu." gördü; **tek harf**
// değiştirince aynı şifre kabul edildi. Sunucu somut bir sebep söylemişti,
// ekran onu yuttu.
//
// Ölçülenler:
//  1. Her eşlenmiş kod **kendi** cümlesini üretir ve genel cümle görünmez.
//  2. Üç ekran da aynı eşlemeyi kullanır (eskiden üçü de farklıydı: kurtarma
//     ekranı dört kod, kod ekranı deponun ham mesajı, ayarlar diyaloğu beş kod).
//  3. Kural metni **hata olmadan** görünür — kullanıcı kuralı öğrenmek için
//     önce reddedilmek zorunda değil.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/auth/password_rules.dart';
import 'package:online_study_room/features/auth/recovery_screen.dart';
import 'package:online_study_room/features/auth/reset_with_code_screen.dart';
import 'package:online_study_room/features/profile/account_settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Sahibin bildirdiği iki cümle katalogdan **gerçekten** ulaşılabilir olmalı;
/// genel cümleye katlanmamalı.
const _generic = 'Beklenmeyen bir hata oluştu.';
const _pwned = 'Bu şifre veri sızıntılarında görülmüş, başka bir şifre seç.';
const _same = 'Yeni şifren eskisiyle aynı olamaz.';
const _tooShort = 'Şifre çok kısa. En az 6 karakter olmalı.';
const _otpExpired = 'Kod geçersiz veya süresi dolmuş. Yeni kod iste.';

/// Yalnız şifre yazma yollarını reddeden depo. Diğer her şey bellek-içi
/// gerçek davranışı korur (ekranın başka bir yerde patlaması testi yanıltmasın).
class _RejectingAuthRepository extends InMemoryAuthRepository {
  _RejectingAuthRepository(this.code);

  final String code;

  AuthException get _failure => AuthException('wp834 test failure', code: code);

  @override
  Future<void> updatePassword(String newPassword) async => throw _failure;

  @override
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async => throw _failure;

  @override
  Future<PasswordChangeOutcome> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => throw _failure;
}

Widget _app(Widget home, AuthRepository repo) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Kurtarma ekranını kurar, şifreyi yazar, gönderir.
Future<void> _submitRecovery(WidgetTester tester, String code) async {
  _useTallPhone(tester);
  await tester.pumpWidget(
    _app(const RecoveryScreen(), _RejectingAuthRepository(code)),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), 'yeniguvenli456');
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

/// Kod ile sıfırlama ekranını kurar, üç alanı da doldurur, gönderir.
Future<void> _submitResetWithCode(WidgetTester tester, String code) async {
  _useTallPhone(tester);
  await tester.pumpWidget(
    _app(const ResetWithCodeScreen(), _RejectingAuthRepository(code)),
  );
  await tester.pumpAndSettle();
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'ali@example.com');
  await tester.enterText(fields.at(1), '123456');
  await tester.enterText(fields.at(2), 'yeniguvenli456');
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

/// Ayarlardaki şifre değiştirme diyaloğunu açar, doldurur, gönderir.
Future<void> _submitSettingsDialog(WidgetTester tester, String code) async {
  _useTallPhone(tester);
  final repo = _RejectingAuthRepository(code);
  await repo.signUp(email: 'a@b.com', password: 'eski123', displayName: 'Ali');
  await tester.pumpWidget(_app(const AccountSettingsScreen(), repo));
  await tester.pumpAndSettle();

  // Şifre satırı metinle değil **yapıyla** bulunur: e-posta satırında da bir
  // "Değiştir" düğmesi var ve metin dile bağlı.
  final tile = find.ancestor(
    of: find.byIcon(Icons.lock_outline),
    matching: find.byType(ListTile),
  );
  await tester.tap(find.descendant(of: tile, matching: find.byType(TextButton)));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('changePasswordCurrent')),
    'eski123',
  );
  await tester.enterText(
    find.byKey(const Key('changePasswordNew')),
    'yeniguvenli456',
  );
  await tester.enterText(
    find.byKey(const Key('changePasswordConfirm')),
    'yeniguvenli456',
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('changePasswordSubmit')));
  await tester.pumpAndSettle();
}

void _expectOwnSentence(String sentence) {
  expect(find.text(sentence), findsOneWidget);
  expect(find.text(_generic), findsNothing);
}

void main() {
  group('WP-834 kurtarma ekrani (sifirlama baglantisi)', () {
    testWidgets('🔴 sizmis sifre kendi cumlesini alir', (tester) async {
      await _submitRecovery(tester, AuthErrorCode.weakPasswordPwned);
      _expectOwnSentence(_pwned);
    });

    testWidgets('🔴 ayni sifre kendi cumlesini alir', (tester) async {
      await _submitRecovery(tester, AuthErrorCode.samePassword);
      _expectOwnSentence(_same);
    });

    testWidgets('kisa sifre kendi cumlesini alir', (tester) async {
      await _submitRecovery(tester, AuthErrorCode.weakPasswordLength);
      _expectOwnSentence(_tooShort);
    });

    testWidgets('karakter cesidi genel cumleye katlanmaz', (tester) async {
      await _submitRecovery(tester, AuthErrorCode.weakPasswordCharacters);
      expect(find.text(_generic), findsNothing);
      expect(find.byKey(passwordRulesKey), findsOneWidget);
    });

    testWidgets('🔴 kural metni HATA OLMADAN gorunur', (tester) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(
          const RecoveryScreen(),
          _RejectingAuthRepository(AuthErrorCode.samePassword),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(passwordRulesKey), findsOneWidget);
      expect(find.text(_generic), findsNothing);
      expect(find.text(_same), findsNothing);
    });
  });

  group('WP-834 kod ile sifirlama ekrani', () {
    testWidgets('🔴 sizmis sifre kendi cumlesini alir', (tester) async {
      await _submitResetWithCode(tester, AuthErrorCode.weakPasswordPwned);
      _expectOwnSentence(_pwned);
    });

    testWidgets('🔴 ayni sifre kendi cumlesini alir', (tester) async {
      await _submitResetWithCode(tester, AuthErrorCode.samePassword);
      _expectOwnSentence(_same);
    });

    testWidgets('suresi dolmus kod kendi cumlesini alir', (tester) async {
      await _submitResetWithCode(tester, AuthErrorCode.otpExpired);
      _expectOwnSentence(_otpExpired);
    });

    testWidgets('🔴 kural metni HATA OLMADAN gorunur', (tester) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(
          const ResetWithCodeScreen(),
          _RejectingAuthRepository(AuthErrorCode.samePassword),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(passwordRulesKey), findsOneWidget);
      expect(find.text(_generic), findsNothing);
    });
  });

  group('WP-834 ayarlardaki sifre degistirme diyalogu', () {
    testWidgets('🔴 sizmis sifre kendi cumlesini alir', (tester) async {
      await _submitSettingsDialog(tester, AuthErrorCode.weakPasswordPwned);
      _expectOwnSentence(_pwned);
    });

    testWidgets('🔴 ayni sifre kendi cumlesini alir', (tester) async {
      await _submitSettingsDialog(tester, AuthErrorCode.samePassword);
      _expectOwnSentence(_same);
    });

    testWidgets('kisa sifre kendi cumlesini alir', (tester) async {
      await _submitSettingsDialog(tester, AuthErrorCode.weakPasswordLength);
      _expectOwnSentence(_tooShort);
    });

    testWidgets('🔴 kural metni diyalog acilir acilmaz gorunur', (
      tester,
    ) async {
      _useTallPhone(tester);
      final repo = _RejectingAuthRepository(AuthErrorCode.samePassword);
      await repo.signUp(
        email: 'a@b.com',
        password: 'eski123',
        displayName: 'Ali',
      );
      await tester.pumpWidget(_app(const AccountSettingsScreen(), repo));
      await tester.pumpAndSettle();
      final tile = find.ancestor(
        of: find.byIcon(Icons.lock_outline),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(passwordRulesKey), findsOneWidget);
      expect(find.text(_generic), findsNothing);
    });
  });
}
