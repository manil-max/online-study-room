import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';

void main() {
  test('updateDisplayName görünen adı değiştirir', () async {
    final repo = InMemoryAuthRepository();
    await repo.signUp(email: 'a@b.com', password: '123456', displayName: 'Ali');
    await repo.updateDisplayName('Ali Veli');
    expect(repo.currentUser?.displayName, 'Ali Veli');
  });

  test('updateDisplayName boş ad reddedilir', () async {
    final repo = InMemoryAuthRepository();
    await repo.signUp(email: 'a@b.com', password: '123456', displayName: 'Ali');
    expect(() => repo.updateDisplayName('   '), throwsA(isA<AuthException>()));
  });

  test(
    'updateAvatar bellek-içi modda desteklenmez (Supabase gerekli)',
    () async {
      final repo = InMemoryAuthRepository();
      await repo.signUp(
        email: 'a@b.com',
        password: '123456',
        displayName: 'Ali',
      );
      expect(
        () => repo.updateAvatar(
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/png',
        ),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test(
    'sendPasswordResetEmail geçerli e-postada hesap var/yok sızdırmaz',
    () async {
      final repo = InMemoryAuthRepository();

      await repo.sendPasswordResetEmail('kimse@ornek.com');

      expect(repo.currentUser, isNull);
    },
  );

  test('sendPasswordResetEmail geçersiz e-postayı reddeder', () async {
    final repo = InMemoryAuthRepository();

    expect(
      () => repo.sendPasswordResetEmail('yanlis'),
      throwsA(isA<AuthException>()),
    );
  });
}
