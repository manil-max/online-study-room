import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, immutable, kIsWeb, TargetPlatform;

enum FirebasePushConfigStatus { notConfigured, incomplete, configured }

/// WP-266: Firebase'in istemciye açık Android tanımlayıcıları.
///
/// Service-account/private key burada **asla** bulunmaz. Bu dört değer tam
/// değilse push fail-closed devre dışı kalır ve Bildirim Sağlığı açık neden
/// gösterir; uygulamanın geri kalanı çalışmaya devam eder.
class FirebasePushConfig {
  const FirebasePushConfig._();

  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const apiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );

  /// WP-901: iOS istemci tanımlayıcıları. Proje kimliği ve gönderici kimliği
  /// Android ile ortaktır. iOS'ta `GoogleService-Info.plist` YOK; Firebase
  /// yalnız buradaki define'lardan kurulur.
  static const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.manilmax.focuscamp',
  );

  /// Çalışan platformun durumu: iOS'ta iOS değerleri, diğer her yerde
  /// (Android dahil) bugünkü Android değerleri — Android davranışı aynıdır.
  static FirebasePushConfigStatus get status =>
      statusFor(isIos: _isIos, android: _android, ios: _ios);

  static bool get isConfigured => status == FirebasePushConfigStatus.configured;

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static const _android = FirebasePlatformValues(
    projectId: projectId,
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
  );

  static const _ios = FirebasePlatformValues(
    projectId: projectId,
    apiKey: iosApiKey,
    appId: iosAppId,
    messagingSenderId: messagingSenderId,
    iosBundleId: iosBundleId,
  );

  /// Çalışan platformun `FirebaseOptions`ı; eksikse [StateError].
  static FirebaseOptions get currentPlatformOptions =>
      optionsFor(isIos: _isIos, android: _android, ios: _ios);

  /// Saf seçici — birim test için.
  static FirebasePushConfigStatus statusFor({
    required bool isIos,
    required FirebasePlatformValues android,
    required FirebasePlatformValues ios,
  }) {
    final v = isIos ? ios : android;
    return resolveStatus(
      projectId: v.projectId,
      apiKey: v.apiKey,
      appId: v.appId,
      messagingSenderId: v.messagingSenderId,
    );
  }

  /// Saf seçici — eksik değerle Firebase **asla** kurulmaz (fail-closed).
  static FirebaseOptions optionsFor({
    required bool isIos,
    required FirebasePlatformValues android,
    required FirebasePlatformValues ios,
  }) {
    if (statusFor(isIos: isIos, android: android, ios: ios) !=
        FirebasePushConfigStatus.configured) {
      throw StateError('firebase_push_not_configured');
    }
    final v = isIos ? ios : android;
    return FirebaseOptions(
      apiKey: v.apiKey,
      appId: v.appId,
      messagingSenderId: v.messagingSenderId,
      projectId: v.projectId,
      iosBundleId: isIos ? v.iosBundleId : null,
    );
  }

  static FirebaseOptions get androidOptions {
    if (!isConfigured) {
      throw StateError('firebase_push_not_configured');
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
    );
  }

  static FirebasePushConfigStatus resolveStatus({
    required String projectId,
    required String apiKey,
    required String appId,
    required String messagingSenderId,
  }) {
    final values = [
      projectId,
      apiKey,
      appId,
      messagingSenderId,
    ].map((value) => value.trim()).toList(growable: false);
    if (values.every((value) => value.isEmpty)) {
      return FirebasePushConfigStatus.notConfigured;
    }
    if (values.any((value) => value.isEmpty)) {
      return FirebasePushConfigStatus.incomplete;
    }
    return FirebasePushConfigStatus.configured;
  }
}

/// WP-901: bir platformun Firebase istemci değerleri.
@immutable
class FirebasePlatformValues {
  const FirebasePlatformValues({
    required this.projectId,
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    this.iosBundleId,
  });

  final String projectId;
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String? iosBundleId;
}
