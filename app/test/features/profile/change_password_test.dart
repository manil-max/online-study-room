import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/profile/account_settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Çağrıları sayan repository. "Ekran doğrulamayı atlıyor mu?" sorusunun
/// cevabı ancak **kaç kez ve hangi argümanla** çağrıldığına bakılarak verilir.
class _RecordingAuthRepository extends InMemoryAuthRepository {
  final List<String> resetEmails = <String>[];
  int changeCalls = 0;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    changeCalls++;
    return super.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmails.add(email);
    await super.sendPasswordResetEmail(email);
  }
}

Future<_RecordingAuthRepository> _pumpScreen(WidgetTester tester) async {
  final repo = _RecordingAuthRepository();
  await repo.signUp(email: 'a@b.com', password: 'eski123', displayName: 'Ali');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Şifre satırındaki "Değiştir" düğmesi. Metinle değil **yapıyla** bulunuyor:
/// aynı ekranda e-posta satırında da bir "Değiştir" var ve metin dile bağlı.
Future<void> _openDialog(WidgetTester tester) async {
  final tile = find.ancestor(
    of: find.byIcon(Icons.lock_outline),
    matching: find.byType(ListTile),
  );
  expect(tile, findsOneWidget);
  await tester.tap(find.descendant(of: tile, matching: find.byType(TextButton)));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('changePasswordCurrent')), findsOneWidget);
}

Future<void> _fill(
  WidgetTester tester, {
  required String current,
  required String next,
  String? confirm,
}) async {
  await tester.enterText(find.byKey(const Key('changePasswordCurrent')), current);
  await tester.enterText(find.byKey(const Key('changePasswordNew')), next);
  await tester.enterText(
    find.byKey(const Key('changePasswordConfirm')),
    confirm ?? next,
  );
  await tester.pump();
}

void main() {
  // WP-319: bu ekran daha önce yalnız "yeni şifre" soruyor ve doğrudan
  // `updatePassword` çağırıyordu — Supabase eski şifreyi doğrulamadığı için
  // kullanıcı korunduğunu sanıyordu. Testler o dönüşü kilitler.
  group('WP-319 şifre değiştirme diyaloğu', () {
    testWidgets('üç alan da var — "mevcut şifre" dekoratif değil', (
      tester,
    ) async {
      await _pumpScreen(tester);
      await _openDialog(tester);

      expect(find.byKey(const Key('changePasswordCurrent')), findsOneWidget);
      expect(find.byKey(const Key('changePasswordNew')), findsOneWidget);
      expect(find.byKey(const Key('changePasswordConfirm')), findsOneWidget);
    });

    testWidgets(
      '🔴 yanlış mevcut şifre: hata görünür, diyalog kapanmaz, şifre değişmez',
      (tester) async {
        final repo = await _pumpScreen(tester);
        await _openDialog(tester);
        await _fill(tester, current: 'yanlis99', next: 'yeni123');

        await tester.tap(find.byKey(const Key('changePasswordSubmit')));
        await tester.pumpAndSettle();

        expect(
          find.text('Mevcut şifre hatalı.'),
          findsOneWidget,
          reason: 'kullanıcı NEDEN başarısız olduğunu görmeli',
        );
        expect(
          find.byKey(const Key('changePasswordCurrent')),
          findsOneWidget,
          reason: 'diyalog açık kalmalı, alanlar silinmemeli',
        );

        // Asıl kanıt: yazma olmadı.
        await repo.signOut();
        await expectLater(
          repo.signIn(email: 'a@b.com', password: 'yeni123'),
          throwsA(isA<AuthException>()),
        );
        final profile = await repo.signIn(
          email: 'a@b.com',
          password: 'eski123',
        );
        expect(profile.displayName, 'Ali');
      },
    );

    testWidgets('doğru mevcut şifre: diyalog kapanır ve şifre gerçekten değişir', (
      tester,
    ) async {
      final repo = await _pumpScreen(tester);
      await _openDialog(tester);
      await _fill(tester, current: 'eski123', next: 'yeni123');

      await tester.tap(find.byKey(const Key('changePasswordSubmit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('changePasswordCurrent')), findsNothing);
      expect(find.text('Şifre başarıyla güncellendi.'), findsOneWidget);

      await repo.signOut();
      final profile = await repo.signIn(email: 'a@b.com', password: 'yeni123');
      expect(profile.displayName, 'Ali');
    });

    testWidgets('tekrar alanı uyuşmazsa istek sunucuya HİÇ gitmez', (
      tester,
    ) async {
      final repo = await _pumpScreen(tester);
      await _openDialog(tester);
      await _fill(
        tester,
        current: 'eski123',
        next: 'yeni123',
        confirm: 'yeni124',
      );

      await tester.tap(find.byKey(const Key('changePasswordSubmit')));
      await tester.pumpAndSettle();

      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
      expect(
        repo.changeCalls,
        0,
        reason: 'istemci doğrulaması geçmeden ağ isteği açılmamalı',
      );
    });

    testWidgets('yeni şifre mevcutla aynıysa reddedilir', (tester) async {
      final repo = await _pumpScreen(tester);
      await _openDialog(tester);
      await _fill(tester, current: 'eski123', next: 'eski123');

      await tester.tap(find.byKey(const Key('changePasswordSubmit')));
      await tester.pumpAndSettle();

      expect(find.text('Yeni şifre mevcut şifreyle aynı olamaz.'), findsWidgets);
      expect(repo.changeCalls, 0);
    });

    testWidgets(
      '"Şifremi unuttum" oturumdaki adrese sıfırlama e-postası gönderir',
      (tester) async {
        final repo = await _pumpScreen(tester);
        await _openDialog(tester);

        await tester.tap(find.byKey(const Key('changePasswordForgot')));
        await tester.pumpAndSettle();

        expect(repo.resetEmails, ['a@b.com']);
        expect(
          find.text('Şifre sıfırlama bağlantısı e-postana gönderildi.'),
          findsOneWidget,
        );
      },
    );
  });
}
