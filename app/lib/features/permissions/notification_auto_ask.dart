import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notifications/notification_auto_ask_flag.dart';
import '../../core/notifications/notification_preferences.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/time_engine/clock_permissions.dart';
import '../../data/providers/push_notification_providers.dart';

export '../../core/notifications/notification_auto_ask_flag.dart';

/// Sistem penceresini gerekiyorsa bir kez açar; açtıysa `true` döner.
///
/// Kurallar (sırası anlamlı):
///  1. Android veya iOS değilse hiçbir şey yapma, bayrak da yazma
///     (Windows/web'de sorulacak bir izin yok). WP-901: iOS aynı kurallarla
///     bir kez sorar; iOS'ta izin kurulumla GELMEZ, pencere açılmadan hiçbir
///     bildirim görünmez.
///  2. Bayrak varsa hiç sorma — kullanıcı daha önce reddettiyse bir daha
///     **kendiliğinden** sorulmaz; yol İzinler ekranındadır.
///  3. Durum okunamadıysa (kanal hatası) bayrak yazmadan çık; bir sonraki
///     açılış yeniden dener.
///  4. Bayrak pencereden **önce** yazılır: pencere açıkken uygulama öldürülse
///     bile bir sonraki açılışta ikinci kez sorulmaz.
///  5. İzin zaten verilmişse (Android 12 ve altı dahil — orada izin kurulumla
///     gelir, `getPermissionSnapshot` `true` döner) pencere açılmaz.
///  6. WP-923: pencere açıldı ve kullanıcı izni **verdiyse** [onGranted]
///     çağrılır (seri koruma + haftalık özet açılır). Zaten verilmiş izinde
///     kullanıcı bir karar vermediği için çağrılmaz.
Future<bool> maybeAutoAskNotificationPermission({
  required SharedPreferences prefs,
  required bool isAndroid,
  required Future<ClockPermissionSnapshot> Function() snapshot,
  required Future<bool> Function() request,
  bool deferredThisSession = false,
  bool isIos = false,
  Future<void> Function()? onGranted,
}) async {
  if (!isAndroid && !isIos) return false;
  // WP-873: onboarding'de "Şimdi değil" → bu açılışta sorma, bayrak da yazma;
  // bir sonraki açılış bir kez sorar.
  if (deferredThisSession) return false;
  if (notificationAutoAskDone(prefs)) return false;
  final current = await snapshot();
  if (current.availability != ClockPermissionAvailability.available) {
    return false;
  }
  await markNotificationAutoAskDone(prefs);
  if (current.notifications) return false;
  final granted = await request();
  if (granted && onGranted != null) await onGranted();
  return true;
}

/// Yalnız test: platform kararını ezmek için. `null` → gerçek platform.
@visibleForTesting
bool? debugNotificationAutoAskIsAndroid;

/// Yalnız test (WP-901): iOS kararını ezmek için. `null` → gerçek platform.
@visibleForTesting
bool? debugNotificationAutoAskIsIos;

/// WP-848: ana kabuk (`HomeShell`) ilk kez kurulduğunda izlenir.
///
/// Neden o an: kabuk yalnız **oturum açık ve onboarding bitmiş** kullanıcıya
/// çizilir (`auth_gate.dart`). Giriş ekranında sormak bağlamsız olurdu,
/// onboarding'in kendi izin sayfası da zaten var. Provider bir kez kurulur ve
/// ayakta kalır; kabuk yeniden kurulsa bile tekrar çalışmaz, kalıcı tekrar
/// koruması ise [kNotificationAutoAskKey]'dir.
final notificationAutoAskProvider = Provider<void>((ref) {
  // 🔴 Platform kararı prefs okumasından ÖNCE: masaüstü/test kabuklarında
  // `sharedPreferencesProvider` ezilmemiş olabilir; orada tek satır bile
  // çalışmamalı.
  final isAndroid =
      debugNotificationAutoAskIsAndroid ?? (!kIsWeb && Platform.isAndroid);
  final isIos = debugNotificationAutoAskIsIos ?? (!kIsWeb && Platform.isIOS);
  if (!isAndroid && !isIos) return;
  final prefs = ref.read(sharedPreferencesProvider);
  unawaited(() async {
    try {
      final asked = await maybeAutoAskNotificationPermission(
        prefs: prefs,
        isAndroid: isAndroid,
        isIos: isIos,
        deferredThisSession: notificationAutoAskDeferredThisSession,
        snapshot: ClockPermissions.instance.snapshot,
        request: ref
            .read(reminderNotificationServiceProvider)
            .requestPermissionIfNeeded,
        // WP-923: tercih yazımı düşse bile push uzlaşması aşağıda sürer.
        onGranted: () async {
          if (!ref.mounted) return;
          try {
            await ref
                .read(notificationPreferencesProvider.notifier)
                .enableSmartRemindersAfterPermissionGrant();
          } catch (_) {}
        },
      );
      // İzin yeni verildiyse push cihaz kaydı beklemeden uzlaşsın (Bildirim
      // Merkezi'ndeki düğmenin yaptığının aynısı).
      if (asked && ref.mounted) {
        await ref.read(pushHealthProvider.notifier).synchronize(force: true);
      }
    } catch (_) {
      // İzin sorusu hiçbir koşulda kabuğu düşürmez.
    }
  }());
});
