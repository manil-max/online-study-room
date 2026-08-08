import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repositorySource = File(
    'lib/data/repositories/supabase/supabase_auth_repository.dart',
  ).readAsStringSync();
  final interfaceSource = File(
    'lib/data/repositories/auth_repository.dart',
  ).readAsStringSync();

  String bodyOf(String signature) {
    final start = repositorySource.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature bulunamadı');
    final marker = repositorySource.indexOf('async {', start);
    expect(marker, isNot(-1), reason: '$signature gövdesi bulunamadı');
    final open = marker + 'async '.length;
    var depth = 0;
    for (var i = open; i < repositorySource.length; i++) {
      if (repositorySource[i] == '{') depth++;
      if (repositorySource[i] == '}') {
        depth--;
        if (depth == 0) return repositorySource.substring(open, i + 1);
      }
    }
    fail('$signature gövdesi kapanmıyor');
  }

  test('eski doğrulamasız updateEmail sözleşmesi tamamen kaldırıldı', () {
    expect(interfaceSource, isNot(contains('updateEmail(')));
    expect(repositorySource, isNot(contains('updateEmail(')));
    expect(
      interfaceSource,
      contains('Future<EmailChangeOutcome> changeEmail('),
    );
  });

  test('Supabase yazması şifreyle reauth sonrasında yapılır', () {
    final body = bodyOf('Future<EmailChangeOutcome> changeEmail(');
    final reauth = body.indexOf('signInWithPassword(');
    final write = body.indexOf('updateUser(');

    expect(reauth, isNot(-1));
    expect(write, isNot(-1));
    expect(
      write,
      greaterThan(reauth),
      reason: 'updateUser mevcut şifre doğrulanmadan çağrılamaz',
    );
    // WP-536: hata kodu artık gövdeye satır içi yazılmıyor; ortak
    // `_reauthFailure` sınıflandırıcısı üretiyor (ağ hatası ile yanlış şifreyi
    // ayırmak için). Sözleşme aynı kaldı: yazma aşamasından ÖNCE hata
    // kodlanmalı. `invalidCurrentPassword` iddiası sınıflandırıcının kendi
    // testinde: `auth_reauth_failure_wp536_test.dart`.
    expect(
      body.substring(0, write),
      contains('throw _reauthFailure('),
      reason: 'yanlış şifre yazma aşamasına geçmeden kodlanmış hata olmalı',
    );
  });

  test('sağlayıcı doğrulama linki ve pending kullanıcı alanı kullanılır', () {
    final body = bodyOf('Future<EmailChangeOutcome> changeEmail(');

    expect(body, contains('emailRedirectTo: redirectTo'));
    expect(body, contains('response.user?.newEmail'));
    expect(body, contains('EmailChangeOutcome.verificationPending'));
    expect(
      body,
      isNot(contains('verifyOTP')),
      reason: 'uygulama e-posta değişikliği için özel kod uydurmamalı',
    );
  });

  test('istek sırasında mevcut profil/e-posta elle değiştirilmez', () {
    final body = bodyOf('Future<EmailChangeOutcome> changeEmail(');

    expect(body, isNot(contains('_current =')));
    expect(body, isNot(contains("'email':")));
    expect(body, isNot(contains('.from(')));
  });
}
