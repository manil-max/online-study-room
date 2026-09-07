import '../models/push_notification.dart';

class PushRegistrationException implements Exception {
  const PushRegistrationException(this.code);

  final String code;

  @override
  String toString() => 'PushRegistrationException($code)';
}

/// Bu kurulumun push kimliginin `SharedPreferences` anahtari.
///
/// 🔴 WP-815: bu dize IKI YERDE yasiyordu ve biri KOPYAYDI.
/// `push_notification_providers.dart:24` onu `_pushInstallationIdKey` adiyla
/// **private** tutuyordu; private oldugu icin `supabase_auth_repository.dart`
/// import edemedi ve dizeyi elle yazdi (`signOut` icinde).
///
/// Bugun ikisi ayni. Ama biri degisirse -- diyelim `_v2` -- cikis yolu
/// SESSIZCE bozulur: `prefs.getString(...)` `null` doner, `unregister_push_device`
/// hic cagrilmaz, cihaz kaydi sunucuda kalir ve **eski hesabin bildirimleri o
/// cihaza dusmeye devam eder**. Ne derleyici ne de bir test uyarirdi, cunku
/// kod tamamen gecerlidir; yalnizca iki dize artik esit degildir.
///
/// Anahtar burada, arayuz dosyasinda duruyor: hem saglayici hem kimlik deposu
/// buraya bagimli, yani ikisi de ayni yerden okuyabilir.
const String kPushInstallationIdPrefsKey = 'push_installation_id_v1';

abstract interface class PushRegistrationRepository {
  /// Server device UUID'si V2 timer RPC'lerinde account-bound capability'dir.
  Future<String?> registerDevice(PushDeviceRegistration registration);

  Future<void> unregisterDevice(String installationId);

  /// Self-test yalnız bu cihazın doğrulanmış sunucu kimliğine yönelir.
  Future<PushSelfTestRequest> requestSelfTest(String deviceId);

  Future<PushSelfTestStatus?> fetchSelfTestStatus(String outboxId);
}
