import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/firebase_push_config.dart';

/// WP-901: Firebase seçenekleri platforma göre seçilir; iOS eksikse push
/// Android'deki gibi fail-closed kapanır.
void main() {
  const android = FirebasePlatformValues(
    projectId: 'focus-prod',
    apiKey: 'android-key',
    appId: '1:123456:android:abcdef',
    messagingSenderId: '123456',
  );
  const iosFull = FirebasePlatformValues(
    projectId: 'focus-prod',
    apiKey: 'ios-key',
    appId: '1:123456:ios:fedcba',
    messagingSenderId: '123456',
    iosBundleId: 'com.manilmax.focuscamp',
  );
  const iosMissing = FirebasePlatformValues(
    projectId: 'focus-prod',
    apiKey: '',
    appId: '',
    messagingSenderId: '123456',
    iosBundleId: 'com.manilmax.focuscamp',
  );
  const empty = FirebasePlatformValues(
    projectId: '',
    apiKey: '',
    appId: '',
    messagingSenderId: '',
  );

  test('iOS tam değerlerle iOS seçeneklerini ve bundle id\'yi kullanır', () {
    final options = FirebasePushConfig.optionsFor(
      isIos: true,
      android: android,
      ios: iosFull,
    );
    expect(options.apiKey, 'ios-key');
    expect(options.appId, '1:123456:ios:fedcba');
    expect(options.iosBundleId, 'com.manilmax.focuscamp');
    expect(options.projectId, 'focus-prod');
    expect(options.messagingSenderId, '123456');
  });

  test('Android seçenekleri değişmedi (iOS değerleri karışmaz)', () {
    final options = FirebasePushConfig.optionsFor(
      isIos: false,
      android: android,
      ios: iosFull,
    );
    expect(options.apiKey, 'android-key');
    expect(options.appId, '1:123456:android:abcdef');
    expect(options.iosBundleId, isNull);
  });

  test('iOS değerleri eksikse durum incomplete ve kurulum reddedilir', () {
    expect(
      FirebasePushConfig.statusFor(
        isIos: true,
        android: android,
        ios: iosMissing,
      ),
      FirebasePushConfigStatus.incomplete,
    );
    expect(
      () => FirebasePushConfig.optionsFor(
        isIos: true,
        android: android,
        ios: iosMissing,
      ),
      throwsStateError,
    );
  });

  test('Android dolu olsa bile iOS Android anahtarıyla kurulmaz', () {
    expect(
      FirebasePushConfig.statusFor(isIos: true, android: android, ios: empty),
      FirebasePushConfigStatus.notConfigured,
    );
  });

  test('iOS bundle id varsayılanı App Store paketidir', () {
    expect(FirebasePushConfig.iosBundleId, 'com.manilmax.focuscamp');
  });
}
