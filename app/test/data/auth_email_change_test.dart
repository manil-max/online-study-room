import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';

void main() {
  group('WP-458 güvenli e-posta değiştirme', () {
    late InMemoryAuthRepository repository;

    setUp(() async {
      repository = InMemoryAuthRepository();
      await repository.signUp(
        email: 'ali@example.com',
        password: 'eski123',
        displayName: 'Ali',
      );
    });

    tearDown(() => repository.dispose());

    test('yanlış mevcut şifre hiçbir hesap anahtarını değiştirmez', () async {
      await expectLater(
        repository.changeEmail(
          currentPassword: 'yanlis123',
          newEmail: 'yeni@example.com',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.code,
            'code',
            AuthErrorCode.invalidCurrentPassword,
          ),
        ),
      );

      expect(repository.currentUserEmail, 'ali@example.com');
      await repository.signOut();
      await expectLater(
        repository.signIn(email: 'yeni@example.com', password: 'eski123'),
        throwsA(isA<AuthException>()),
      );
      expect(
        (await repository.signIn(
          email: 'ali@example.com',
          password: 'eski123',
        )).displayName,
        'Ali',
      );
    });

    test(
      'başarı atomik kalır ve yeniden girişte yeni adres kullanılır',
      () async {
        final outcome = await repository.changeEmail(
          currentPassword: 'eski123',
          newEmail: ' YENI@example.com ',
        );

        expect(outcome, EmailChangeOutcome.confirmed);
        expect(repository.currentUserEmail, 'yeni@example.com');

        await repository.signOut();
        await expectLater(
          repository.signIn(email: 'ali@example.com', password: 'eski123'),
          throwsA(isA<AuthException>()),
        );
        final profile = await repository.signIn(
          email: 'yeni@example.com',
          password: 'eski123',
        );
        expect(profile.displayName, 'Ali');
      },
    );

    test(
      'başka hesaba ait adres reddedilir ve hesaplar birbirine sızmaz',
      () async {
        await repository.signOut();
        await repository.signUp(
          email: 'ayse@example.com',
          password: 'ayse123',
          displayName: 'Ayşe',
        );
        await repository.signOut();
        await repository.signIn(email: 'ali@example.com', password: 'eski123');

        await expectLater(
          repository.changeEmail(
            currentPassword: 'eski123',
            newEmail: 'ayse@example.com',
          ),
          throwsA(
            isA<AuthException>().having(
              (error) => error.code,
              'code',
              AuthErrorCode.emailAlreadyInUse,
            ),
          ),
        );

        expect(repository.currentUserEmail, 'ali@example.com');
        await repository.signOut();
        expect(
          (await repository.signIn(
            email: 'ayse@example.com',
            password: 'ayse123',
          )).displayName,
          'Ayşe',
        );
      },
    );

    test(
      'oturumsuz ve aynı-adres istekleri eyleme dönük kodla reddedilir',
      () async {
        await expectLater(
          repository.changeEmail(
            currentPassword: 'eski123',
            newEmail: 'ALI@example.com',
          ),
          throwsA(
            isA<AuthException>().having(
              (error) => error.code,
              'code',
              AuthErrorCode.sameEmail,
            ),
          ),
        );

        await repository.signOut();
        await expectLater(
          repository.changeEmail(
            currentPassword: 'eski123',
            newEmail: 'yeni@example.com',
          ),
          throwsA(
            isA<AuthException>().having(
              (error) => error.code,
              'code',
              AuthErrorCode.noSession,
            ),
          ),
        );
      },
    );
  });
}
