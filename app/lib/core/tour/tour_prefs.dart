import 'package:shared_preferences/shared_preferences.dart';

/// WP-323: tur "görüldü" anahtarları.
///
/// 🔴 Üç şey aynı anda doğru olmalı, yoksa anahtar sessizce yanlış davranır:
///
/// 1. **Ekran başına ayrı** — tek bayrak kullanılsaydı Ana Sayfa turunu gören
///    kullanıcı Gruplar turunu hiç görmezdi.
/// 2. **Sürümlü** (`home.v1`) — ekran ciddi değişince tur yeniden gösterilebilir,
///    ama her sürümde herkese açılmaz.
/// 3. **Kullanıcı başına** — WP-166'da öğrenildi: cihaz geneli anahtar, aynı
///    cihazda hesap değiştiren kullanıcıyı "görmüş" sayıyordu. Aynı telefonu
///    paylaşan iki kişiden ikincisi turu hiç görmezdi.
const kTourKeyPrefix = 'tour.';

String tourSeenKey({required String storageId, required String userId}) =>
    '$kTourKeyPrefix$storageId.$userId';

bool tourSeen(
  SharedPreferences prefs, {
  required String storageId,
  required String userId,
}) => prefs.getBool(tourSeenKey(storageId: storageId, userId: userId)) ?? false;

Future<void> markTourSeen(
  SharedPreferences prefs, {
  required String storageId,
  required String userId,
}) => prefs.setBool(tourSeenKey(storageId: storageId, userId: userId), true);

/// "Tanıtım turlarını sıfırla": yalnız **bu kullanıcının** tur anahtarları
/// silinir.
///
/// `prefs.clear()` demek kolay olurdu ve temayı, hedefleri, bildirim
/// tercihlerini de silerdi — kullanıcı ayarlardaki masum bir düğmeye basıp
/// uygulamasını sıfırlamış olurdu.
Future<int> resetToursForUser(
  SharedPreferences prefs, {
  required String userId,
}) async {
  final keys = prefs
      .getKeys()
      .where((k) => k.startsWith(kTourKeyPrefix) && k.endsWith('.$userId'))
      .toList(growable: false);
  for (final key in keys) {
    await prefs.remove(key);
  }
  return keys.length;
}
