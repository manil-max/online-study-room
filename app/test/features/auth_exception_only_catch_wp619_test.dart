// WP-619 — "yalnız `on AuthException` yakala" hatası BEŞ yerde birden vardı.
//
// Belirti hep aynıydı: kullanıcı bir şeyi değiştiriyor (günlük hedef, ad,
// avatar, kamp hayvanı), ağ kopuk, **hiçbir şey olmuyor** — ne hata ne onay.
//
// Kök neden: `updateDailyGoal` gibi profil yazmaları `AuthException` **atmaz**.
// Ağ/sunucu hatası `PostgrestException`, `StorageException`, `ClientException`
// ya da `SocketException` olarak gelir; `on AuthException` dalının yanından
// geçip global yutucuya gider.
//
// WP-610 bunu Ayarlar ve Profil'de kapattı ama sayaç kartını kapatamadı (o tur
// bu dosya başka bir ajandaydı) — ve kullanıcı hedefini **en çok oradan**
// değiştiriyor. WP-619 onu kapattı.
//
// 🔴 Bu dosya tekil bir yolu değil **deseni** ölçer. Beşinci örneğin de aynı
// şekilde ortaya çıkması, tek tek düzeltmenin yetmediğini gösterdi: altıncısı
// eklenirse buradan yakalanır.
//
// Kural: `lib/features/auth/**` DIŞINDA bir `on AuthException` dalı tek başına
// duramaz — aynı `try` içinde onu takip eden **geniş bir `catch`** olmalı.
// `features/auth/**` muaf: giriş, kayıt ve kurtarma akışlarında `AuthException`
// gerçekten beklenen hata türüdür ve özel mesajları oradan gelir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `lib/` altındaki tüm Dart kaynakları.
Iterable<File> _sources() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

bool _isAuthFeature(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return normalized.contains('/features/auth/');
}

void main() {
  test('`on AuthException` tek başına kalmaz (geniş catch zorunlu)', () {
    final offenders = <String>[];

    for (final file in _sources()) {
      if (_isAuthFeature(file.path)) continue;
      final source = file.readAsStringSync();

      // Yorum satırları hariç: bu depoda kusurun kendisi yorumlarda
      // ANLATILIYOR (WP-610/WP-619 notları) ve onları ihlal saymak testi
      // yanlış kırmızıya düşürürdü.
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      for (final match in RegExp(
        r'\}\s*on\s+AuthException',
      ).allMatches(code)) {
        // Aynı `try` zincirinde ilerideki bir `} catch (` aranır. Pencere
        // dar tutuldu: bir sonraki fonksiyona taşarsa iddia anlamsızlaşır.
        final tailEnd = (match.end + 600).clamp(0, code.length);
        final tail = code.substring(match.end, tailEnd);
        final hasBroadCatch = RegExp(r'\}\s*catch\s*\(').hasMatch(tail);
        if (!hasBroadCatch) {
          final line = '\n'.allMatches(code.substring(0, match.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dallar yalnız `AuthException` yakalıyor; profil/veri yazmaları bu '
          'türü ATMAZ. Kullanıcı değişikliği yapıyor, ağ kopuk, hiçbir şey '
          'söylenmiyor ve eski değer sessizce kalıyor:\n'
          '${offenders.join('\n')}',
    );
  });

  test('kural gerçekten ölçüyor: muaf olmayan bir ihlal YAKALANIR', () {
    // 🔴 Kapının kendini sınaması. Yukarıdaki test bugün yeşil; yeşil olması
    // "ölçüyor" demek değil. Aynı tarama mantığı, ihlal içeren yapay bir
    // kaynağa uygulanınca ihlali BULMALI.
    const violating = '''
      try {
        await repo.updateDailyGoal(value);
      } on AuthException {
        show(error);
      }
    ''';
    const compliant = '''
      try {
        await repo.updateDailyGoal(value);
      } on AuthException catch (e) {
        show(e.message);
      } catch (_) {
        show(generic);
      }
    ''';

    bool violates(String code) {
      for (final match in RegExp(r'\}\s*on\s+AuthException').allMatches(code)) {
        final tailEnd = (match.end + 600).clamp(0, code.length);
        if (!RegExp(
          r'\}\s*catch\s*\(',
        ).hasMatch(code.substring(match.end, tailEnd))) {
          return true;
        }
      }
      return false;
    }

    expect(violates(violating), isTrue, reason: 'Tarama ihlali kaçırıyor.');
    expect(violates(compliant), isFalse, reason: 'Tarama doğruyu ihlal sayıyor.');
  });
}
