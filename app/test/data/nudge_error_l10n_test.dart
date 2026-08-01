import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/nudge_error_text.dart';
import 'package:online_study_room/data/repositories/nudge_repository.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

/// WP-477 (V57-N01, V57-N08 dil yarısı): dürtme hataları İngilizce arayüzde
/// Türkçe çıkıyordu, çünkü metin repository sabitiydi. Bu dosya hatanın
/// bekçisidir: bir hata koduna yeniden Türkçe sabit bağlanırsa kırmızıya döner.
void main() {
  final en = AppLocalizationsEn();
  final tr = AppLocalizationsTr();

  /// Türkçe'ye özgü harfler — İngilizce katalogda hiçbiri bulunmamalı.
  final turkishChars = RegExp(r'[ÇĞİÖŞÜçğıöşü]');

  group('NudgeErrorCode → l10n', () {
    test('her kod iki katalogda da metin üretir ve diller ayrışır', () {
      for (final code in NudgeErrorCode.values) {
        final exception = NudgeException(code);
        final english = exception.localize(en);
        final turkish = exception.localize(tr);

        expect(english, isNotEmpty, reason: '$code için EN metin yok');
        expect(turkish, isNotEmpty, reason: '$code için TR metin yok');
        expect(
          english,
          isNot(equals(turkish)),
          reason: '$code iki dilde aynı metni veriyor — çeviri bağlanmamış',
        );
      }
    });

    test('İngilizce katalog hiçbir kodda Türkçe metin döndürmez', () {
      for (final code in NudgeErrorCode.values) {
        expect(
          NudgeException(code).localize(en),
          isNot(matches(turkishChars)),
          reason: '$code İngilizce arayüzde Türkçe metin veriyor (V57-N01)',
        );
      }
    });

    // Sahibin raporladığı üç metin — belirtinin birebir karşılığı.
    test('sahibin gördüğü üç hata İngilizce arayüzde İngilizce', () {
      expect(
        const NudgeException(NudgeErrorCode.cooldown).localize(en),
        'You can nudge the same person once every 20 minutes.',
      );
      expect(
        const NudgeException(NudgeErrorCode.recipientIsStudying).localize(en),
        'This person is studying; nudges are disabled to protect their focus.',
      );
      expect(
        const NudgeException(NudgeErrorCode.messageTooLong).localize(en),
        'The nudge note can be up to 120 characters.',
      );
    });

    // Süre metne gömülü olsaydı `kNudgeCooldown` değişince katalog geride
    // kalırdı (WP-476'da 10 → 20 dk değişimi tam olarak bunu yaşattı).
    test('cooldown metni süreyi koddan alır, katalogdan değil', () {
      final minutes = kNudgeCooldown.inMinutes;
      for (final l10n in <AppLocalizations>[en, tr]) {
        expect(
          const NudgeException(NudgeErrorCode.cooldown).localize(l10n),
          contains('$minutes'),
        );
      }
    });
  });

  group('repository katmanı metin taşımaz', () {
    test('istisna yalnız kod + teknik ayrıntı taşır', () {
      const exception = NudgeException(
        NudgeErrorCode.sendFailed,
        detail: 'PostgrestException(code: 500)',
      );

      // `toString` günlük içindir; kullanıcı metni yalnız `localize` ile üretilir.
      expect(exception.toString(), contains('sendFailed'));
      expect(exception.toString(), isNot(matches(turkishChars)));
    });

    test('120 karakter sınırı da koddan geçer', () {
      expect(
        () => normalizeNudgeMessage('a' * (kMaxNudgeMessageLength + 1)),
        throwsA(
          isA<NudgeException>().having(
            (e) => e.code,
            'code',
            NudgeErrorCode.messageTooLong,
          ),
        ),
      );
    });
  });
}
