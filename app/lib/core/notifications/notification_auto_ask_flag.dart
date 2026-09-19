import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-848: bildirim izninin sistem penceresi **bir kez, kendiliğinden** açıldı mı.
///
/// Cihaz geneli (kullanıcıya özel değil): izin telefona verilir, hesaba değil.
/// Aynı telefonda hesap değiştiren ikinci kişiye pencereyi yeniden açmak
/// yalnız ret edilmiş bir soruyu tekrar sormak olurdu.
///
/// WP-872: `core/` altında, çünkü sayaç başlatma yolu (`data/providers`) da
/// aynı bayrağa bakar — ret eden kullanıcıya her başlatmada yeniden sorulmaz.
const kNotificationAutoAskKey = 'permissions.notification_auto_ask.v1';

/// Pencereyi açan her yol bu bayrağı yazar (onboarding düğmesi, kabuk, sayaç).
Future<void> markNotificationAutoAskDone(SharedPreferences prefs) =>
    prefs.setBool(kNotificationAutoAskKey, true);

bool notificationAutoAskDone(SharedPreferences prefs) =>
    prefs.getBool(kNotificationAutoAskKey) ?? false;

bool _deferredThisSession = false;

/// WP-873: onboarding'de "Şimdi değil" → bu açılışta kendiliğinden sorulmaz.
/// Bayrak **yazılmaz**: bir sonraki açılışta kabuk bir kez sorar.
void deferNotificationAutoAskThisSession() => _deferredThisSession = true;

bool get notificationAutoAskDeferredThisSession => _deferredThisSession;

@visibleForTesting
void debugResetNotificationAutoAskDeferral() => _deferredThisSession = false;
