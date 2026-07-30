import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/profile/account_settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

class _RecordingAuthRepository extends InMemoryAuthRepository {
  _RecordingAuthRepository({this.outcome = EmailChangeOutcome.confirmed});

  final EmailChangeOutcome outcome;
  int changeCalls = 0;
  String? receivedPassword;
  String? receivedEmail;

  @override
  Future<EmailChangeOutcome> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    changeCalls++;
    receivedPassword = currentPassword;
    receivedEmail = newEmail;
    await super.changeEmail(
      currentPassword: currentPassword,
      newEmail: newEmail,
    );
    return outcome;
  }
}

Future<_RecordingAuthRepository> _pumpScreen(
  WidgetTester tester, {
  EmailChangeOutcome outcome = EmailChangeOutcome.confirmed,
}) async {
  final repository = _RecordingAuthRepository(outcome: outcome);
  await repository.signUp(
    email: 'ali@example.com',
    password: 'eski123',
    displayName: 'Ali',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _openDialog(WidgetTester tester) async {
  final tile = find.ancestor(
    of: find.byIcon(Icons.email_outlined),
    matching: find.byType(ListTile),
  );
  expect(tile, findsOneWidget);
  await tester.tap(
    find.descendant(of: tile, matching: find.byType(TextButton)),
  );
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  required String password,
  required String email,
}) async {
  await tester.enterText(
    find.byKey(const Key('changeEmailCurrentPassword')),
    password,
  );
  await tester.enterText(find.byKey(const Key('changeEmailNewEmail')), email);
  await tester.pump();
}

void main() {
  group('WP-458 e-posta değiştirme diyaloğu', () {
    testWidgets('mevcut şifre zorunlu ve güvenli süreç görünür', (
      tester,
    ) async {
      final repository = await _pumpScreen(tester);
      addTearDown(repository.dispose);
      await _openDialog(tester);

      expect(
        find.byKey(const Key('changeEmailCurrentPassword')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('changeEmailNewEmail')), findsOneWidget);
      expect(
        find.textContaining('Mevcut e-postan, değişiklik doğrulanana kadar'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('changeEmailNewEmail')),
        'yeni@example.com',
      );
      await tester.tap(find.byKey(const Key('changeEmailSubmit')));
      await tester.pump();

      expect(find.text('Mevcut şifreni gir.'), findsOneWidget);
      expect(repository.changeCalls, 0);
    });

    testWidgets('yanlış şifre hatası diyaloğun içinde kalır ve yazma olmaz', (
      tester,
    ) async {
      final repository = await _pumpScreen(tester);
      addTearDown(repository.dispose);
      await _openDialog(tester);
      await _fill(tester, password: 'yanlis123', email: 'yeni@example.com');

      await tester.tap(find.byKey(const Key('changeEmailSubmit')));
      await tester.pumpAndSettle();

      expect(find.text('Mevcut şifre hatalı.'), findsOneWidget);
      expect(
        find.byKey(const Key('changeEmailCurrentPassword')),
        findsOneWidget,
      );
      expect(repository.currentUserEmail, 'ali@example.com');
    });

    testWidgets('doğru bilgiler tek güvenli repository çağrısına gider', (
      tester,
    ) async {
      final repository = await _pumpScreen(tester);
      addTearDown(repository.dispose);
      await _openDialog(tester);
      await _fill(tester, password: 'eski123', email: 'yeni@example.com');

      await tester.tap(find.byKey(const Key('changeEmailSubmit')));
      await tester.pumpAndSettle();

      expect(repository.changeCalls, 1);
      expect(repository.receivedPassword, 'eski123');
      expect(repository.receivedEmail, 'yeni@example.com');
      expect(find.text('E-posta adresin değiştirildi.'), findsOneWidget);
      expect(find.text('yeni@example.com'), findsOneWidget);
      expect(find.text('ali@example.com'), findsNothing);
      expect(find.byKey(const Key('changeEmailSubmit')), findsNothing);
    });

    testWidgets('Supabase pending sonucu eski e-postanın kaldığını açıklar', (
      tester,
    ) async {
      final repository = await _pumpScreen(
        tester,
        outcome: EmailChangeOutcome.verificationPending,
      );
      addTearDown(repository.dispose);
      await _openDialog(tester);
      await _fill(tester, password: 'eski123', email: 'yeni@example.com');

      await tester.tap(find.byKey(const Key('changeEmailSubmit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Doğrulama bekleniyor.'), findsOneWidget);
      expect(
        find.textContaining(
          'Süresi dolan, iptal edilen veya daha önce kullanılan',
        ),
        findsOneWidget,
      );
    });

    testWidgets('aynı e-posta istemci tarafında reddedilir', (tester) async {
      final repository = await _pumpScreen(tester);
      addTearDown(repository.dispose);
      await _openDialog(tester);
      await _fill(tester, password: 'eski123', email: 'ALI@example.com');

      await tester.tap(find.byKey(const Key('changeEmailSubmit')));
      await tester.pump();

      expect(
        find.text('Yeni e-posta mevcut e-postayla aynı olamaz.'),
        findsOneWidget,
      );
      expect(repository.changeCalls, 0);
    });
  });
}
