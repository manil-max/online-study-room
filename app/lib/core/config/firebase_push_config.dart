import 'package:firebase_core/firebase_core.dart';

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

  static FirebasePushConfigStatus get status => resolveStatus(
    projectId: projectId,
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
  );

  static bool get isConfigured => status == FirebasePushConfigStatus.configured;

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
