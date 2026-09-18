import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notifications/reminder_notification_service.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/time_engine/clock_permissions.dart';
import '../../data/providers/push_notification_providers.dart';

/// WP-848: bildirim izninin sistem penceresi **bir kez, kendiliğinden** açıldı mı.
///
/// Cihaz geneli (kullanıcıya özel değil): izin telefona verilir, hesaba değil.
/// Aynı telefonda hesap değiştiren ikinci kişiye pencereyi yeniden açmak
/// yalnız ret edilmiş bir soruyu tekrar sormak olurdu.
const kNotificationAutoAskKey = 'permissions.notification_auto_ask.v1';

/// Onboarding'deki "Bildirimlere izin ver" düğmesi de pencereyi açar. O yol
/// da bu bayrağı yazar; aksi hâlde onboarding'de "İzin verme" diyen kullanıcıya
/// kabuğa girer girmez aynı pencere ikinci kez çıkardı.
Future<void> markNotificationAutoAskDone(SharedPreferences prefs) =>
    prefs.setBool(kNotificationAutoAskKey, true);

/// Sistem penceresini gerekiyorsa bir kez açar; açtıysa `true` döner.
///
/// Kurallar (sırası anlamlı):
///  1. Android değilse hiçbir şey yapma, bayrak da yazma (Windows/web'de
///     sorulacak bir izin yok).
///  2. Bayrak varsa hiç sorma — kullanıcı daha önce reddettiyse bir daha
///     **kendiliğinden** sorulmaz; yol İzinler ekranındadır.
///  3. Durum okunamadıysa (kanal hatası) bayrak yazmadan çık; bir sonraki
///     açılış yeniden dener.
///  4. Bayrak pencereden **önce** yazılır: pencere açıkken uygulama öldürülse
///     bile bir sonraki açılışta ikinci kez sorulmaz.
///  5. İzin zaten verilmişse (Android 12 ve altı dahil — orada izin kurulumla
///     gelir, `getPermissionSnapshot` `true` döner) pencere açılmaz.
Future<bool> maybeAutoAskNotificationPermission({
  required SharedPreferences prefs,
  required bool isAndroid,
  required Future<ClockPermissionSnapshot> Function() snapshot,
  required Future<bool> Function() request,
}) async {
  if (!isAndroid) return false;
  if (prefs.getBool(kNotificationAutoAskKey) ?? false) return false;
  final current = await snapshot();
  if (current.availability != ClockPermissionAvailability.available) {
    return false;
  }
  await markNotificationAutoAskDone(prefs);
  if (current.notifications) return false;
  await request();
  return true;
}

/// Yalnız test: platform kararını ezmek için. `null` → gerçek platform.
@visibleForTesting
bool? debugNotificationAutoAskIsAndroid;

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
  if (!isAndroid) return;
  final prefs = ref.read(sharedPreferencesProvider);
  unawaited(() async {
    try {
      final asked = await maybeAutoAskNotificationPermission(
        prefs: prefs,
        isAndroid: isAndroid,
        snapshot: ClockPermissions.instance.snapshot,
        request: ref
            .read(reminderNotificationServiceProvider)
            .requestPermissionIfNeeded,
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
