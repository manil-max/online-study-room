import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/auth_redirect_config.dart';

void main() {
  group('authRecoveryRedirectUrl (WP-287)', () {
    // Regresyon: bug'ın kökü, resetPasswordForEmail'e redirectTo verilmemesiydi;
    // link Site URL'e (localhost:3000) gidiyordu. Artık Android'de her flavor
    // için doğru derin bağlantı üretilmeli. Bu test boş/yanlış üretimi yakalar.

    test('stable paket → suffixsiz scheme', () {
      expect(
        authRecoveryRedirectUrl(
          'com.manilmax.online_study_room',
          isAndroid: true,
        ),
        'com.manilmax.onlinestudyroom://login-callback',
      );
    });

    test('beta paket → .beta scheme (stable ile karışmaz)', () {
      expect(
        authRecoveryRedirectUrl(
          'com.manilmax.online_study_room.beta',
          isAndroid: true,
        ),
        'com.manilmax.onlinestudyroom.beta://login-callback',
      );
    });

    test('local paket → .local scheme', () {
      expect(
        authRecoveryRedirectUrl(
          'com.manilmax.online_study_room.local',
          isAndroid: true,
        ),
        'com.manilmax.onlinestudyroom.local://login-callback',
      );
    });

    test('Android değilse null (Windows/masaüstü → OTP yolu)', () {
      expect(
        authRecoveryRedirectUrl(
          'com.manilmax.online_study_room',
          isAndroid: false,
        ),
        isNull,
      );
    });

    test('beklenmeyen paket adı → null (güvenli OTP yoluna düş)', () {
      expect(
        authRecoveryRedirectUrl('com.example.other', isAndroid: true),
        isNull,
      );
    });

    test('Android paketi için asla null değil — redirect her zaman üretilir', () {
      // Bu, "redirectTo olmadan çağrı" regresyonunun kırmızı-yeşil kilididir:
      // stable/beta/local üçü de geçerli bir hedef üretmeli.
      for (final pkg in const [
        'com.manilmax.online_study_room',
        'com.manilmax.online_study_room.beta',
        'com.manilmax.online_study_room.local',
      ]) {
        final url = authRecoveryRedirectUrl(pkg, isAndroid: true);
        expect(url, isNotNull, reason: '$pkg için redirect üretilmeli');
        expect(url, endsWith('://login-callback'));
      }
    });
  });
}
