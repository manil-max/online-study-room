// WP-615 — WP-592'nin (aynı gün eklendi) eksik yarısı.
//
// WP-592 sayaç kartına "bildirim izni kapalı" uyarı şeridi ve "Eksik izinleri
// aç" çıkışı ekledi. Ama izin durumu **bir kez** hesaplanıyordu: düz bir
// `FutureProvider` ve repoda onu geçersiz kılan tek satır yok. Kullanıcının
// yaşadığı:
//
//   1. şeridi görüyor, "Eksik izinleri aç"a basıyor,
//   2. sistem ayarlarında izni GERÇEKTEN veriyor,
//   3. uygulamaya dönüyor — **şerit hâlâ orada.**
//
// Yani düzeltmenin kendisi kullanıcıya "yaptığın işe yaramadı" dedirtiyordu.
//
// 🔴 WP-592'nin testi bunu göremezdi: sabit bir sahte geçit döndürüyordu, yani
// "durum yeniden okunuyor mu" sorusu hiç sorulmuyordu. Bu dosya tam o soruyu
// ölçer — geçit **değişebilir** ve okuma sayısı sayılır.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';

/// İzni sonradan "verilmiş" hâle çevirebilen geçit. Sabit sahte ile bu hata
/// ölçülemezdi; kusurun kendisi zaten "değişimi görmemek"ti.
class _MutablePermissionGateway implements TimerNotificationPermissionGateway {
  bool granted = false;
  int reads = 0;

  @override
  Future<bool> hasPermission() async {
    reads++;
    return granted;
  }

  @override
  Future<void> openSystemNotificationSettings() async {}
}

void main() {
  testWidgets('sistem ayarlarından dönünce izin durumu YENİDEN okunur', (
    tester,
  ) async {
    final gateway = _MutablePermissionGateway();
    final container = ProviderContainer(
      overrides: [
        timerNotificationPermissionProvider.overrideWithValue(gateway),
      ],
    );

    // İlk okuma: izin kapalı.
    await container.read(timerNotificationPermissionStatusProvider.future);
    expect(gateway.reads, 1);
    expect(
      container.read(timerNotificationPermissionStatusProvider).value,
      isFalse,
    );

    // Kullanıcı sistem ayarlarında izni veriyor ve uygulamaya dönüyor.
    gateway.granted = true;
    container
        .read(timerNotificationPermissionRefresherProvider)
        .didChangeAppLifecycleState(AppLifecycleState.resumed);

    final after = await container.read(
      timerNotificationPermissionStatusProvider.future,
    );

    expect(
      gateway.reads,
      greaterThan(1),
      reason:
          'Durum yeniden okunmadı: kullanıcı izni verip dönüyor ama uyarı '
          'şeridi yerinde kalıyor -- düzeltme kendini yalanlıyor.',
    );
    expect(after, isTrue, reason: 'İzin verildi ama şerit hâlâ çizilecek.');

    container.dispose();
  });

  testWidgets('öne gelme DIŞINDA bir durum değişimi tazeleme YAPMAZ', (
    tester,
  ) async {
    // Ters iddia. Bu olmadan "her yaşam döngüsü olayında tazele" çözümü de
    // geçerdi; o da arka plana her geçişte platform çağrısı demektir.
    final gateway = _MutablePermissionGateway();
    final container = ProviderContainer(
      overrides: [
        timerNotificationPermissionProvider.overrideWithValue(gateway),
      ],
    );

    await container.read(timerNotificationPermissionStatusProvider.future);
    final before = gateway.reads;

    final refresher = container.read(
      timerNotificationPermissionRefresherProvider,
    );
    refresher.didChangeAppLifecycleState(AppLifecycleState.paused);
    refresher.didChangeAppLifecycleState(AppLifecycleState.inactive);
    refresher.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await container.read(timerNotificationPermissionStatusProvider.future);

    expect(gateway.reads, before);

    container.dispose();
  });
}
