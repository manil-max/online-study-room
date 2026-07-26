import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WP-319-G sözleşme testi: **şifre değişince diğer cihazların oturumu kapanır.**
///
/// Neden kaynak okunuyor da davranış koşulmuyor: iptal `SupabaseClient.auth`
/// üzerinden yapılıyor ve bu sınıfın sahte (fake) bir karşılığı repoda yok;
/// bellek-içi repository'nin ise çok cihazlı oturum kavramı yok, yani orada
/// "kapandı" demek gerçeği taklit etmek olurdu. Repoda bu tür yüzeyler için
/// yerleşik desen kaynak sözleşmesi testidir (bkz. `push_delivery_contract_test`,
/// `verified_timer_bridge_contract_test`). Test, çağrının **silinmesini** ve
/// yanlış kapsamla yapılmasını yakalar.
void main() {
  final source = File(
    'lib/data/repositories/supabase/supabase_auth_repository.dart',
  ).readAsStringSync();

  /// [signature] ile başlayan metodun gövdesini (süslü parantez eşleyerek) döner.
  String bodyOf(String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature bulunamadı');
    // Adlandırılmış parametre listesi de `{...}` — gövdeye `async {`den girilir.
    final marker = source.indexOf('async {', start);
    expect(marker, isNot(-1), reason: '$signature gövdesi bulunamadı');
    final open = marker + 'async '.length;
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      if (source[i] == '{') depth++;
      if (source[i] == '}') {
        depth--;
        if (depth == 0) return source.substring(open, i + 1);
      }
    }
    fail('$signature gövdesi kapanmıyor');
  }

  test('changePassword, şifreyi yazdıktan SONRA diğer oturumları kapatır', () {
    final body = bodyOf('Future<PasswordChangeOutcome> changePassword(');

    expect(
      body,
      contains('_revokeOtherSessions()'),
      reason:
          'sahip kararı (2026-07-26): şifre değişince diğer cihazlar çıkarılır. '
          'Çağrı silinirse şifre değiştirmek saldırganı dışarı atmaz ama '
          'kullanıcı atıldığını sanır.',
    );

    final write = body.indexOf('updateUser(');
    final revoke = body.indexOf('_revokeOtherSessions()');
    expect(write, isNot(-1));
    expect(
      revoke,
      greaterThan(write),
      reason:
          'iptal yazmadan ÖNCE yapılırsa, yazma başarısız olduğunda kullanıcı '
          'hiçbir şey kazanmadan diğer cihazlarından atılmış olur',
    );
  });

  test('iptal edilemezse istisna atılmaz, sonuç taşınır', () {
    final body = bodyOf('Future<PasswordChangeOutcome> changePassword(');

    // Şifre bu noktada zaten YAZILMIŞTIR. İstisna atmak kullanıcıya "işlem
    // olmadı" dedirtir ve artık geçersiz olan eski şifreyi tekrar girdirir.
    expect(body, contains('PasswordChangeOutcome.otherSessionsKept'));
    expect(body, contains('PasswordChangeOutcome.done'));

    final helper = bodyOf('Future<bool> _revokeOtherSessions()');
    expect(helper, contains('return false;'));
    expect(
      helper,
      isNot(contains('throw')),
      reason: 'yardımcı hata fırlatırsa çağıran akış istisnaya döner',
    );
  });

  test('kapsam "others" — kullanıcı kendi cihazından atılmaz', () {
    final helper = bodyOf('Future<bool> _revokeOtherSessions()');

    expect(helper, contains('supa.SignOutScope.others'));
    expect(
      source,
      isNot(contains('SignOutScope.global')),
      reason:
          '`global` bu cihazın oturumunu da kapatır: kullanıcı şifresini '
          'değiştirir değiştirmez giriş ekranına düşer. Özellik cezaya döner '
          've kullanılmaz hâle gelir.',
    );
  });

  test('şifre iptal yolunda log/analitiğe yazılmaz', () {
    final body = bodyOf('Future<PasswordChangeOutcome> changePassword(');
    expect(body, isNot(contains('print(')));
    expect(body, isNot(contains('debugPrint')));
    expect(body, isNot(contains('newPassword)}')));
  });
}
