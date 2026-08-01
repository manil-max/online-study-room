// `alarm_providers.dart` — sayaç durum makinesi.
//
// 🔴 Bu dosya kapsam denetiminde **%3.1** çıktı: 317 satır hiç
// çalıştırılmamıştı. Sayaç/alarm ise projenin tarihsel olarak en çok hata
// üreten alanı (WP-245/246/247 notifier katmanı, WP-250 ekran katmanı,
// WP-251 kuyruk, beta-v12 açılış çökmesi). Kapsamsız bırakmak,
// en kırılgan kodu korumasız bırakmaktı.
//
// Odak, kalıcı hata sınıfının kendisi: **süre epoch'tan türetilir.**
// `remainingSeconds` yalnız bir görüntü/önbellek değeridir; uygulama
// arka plandayken ilerlemez. Açılışta gerçek geçen süre `endsAtEpochMs`
// ile yeniden hesaplanmazsa sayaç donmuş görünür — sahada tam olarak bu
// yaşandı.
//
// ⚠️ Riverpod 3 tuzağı: dinleyicisi olmayan provider her `read`'de yeniden
// build olur ve regresyon testini sessizce etkisiz kılar. Bu yüzden her
// senaryoda `listen(..., (_, _) {})` ile abonelik açılıyor.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/alarm_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/time_engine/epoch_clock.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/providers/alarm_providers.dart';
import 'package:online_study_room/data/repositories/alarm_repository.dart';
import 'package:online_study_room/data/repositories/local/local_alarm_repository.dart';

const _kNow = 1800000000000; // sabit epoch ms

/// Bildirim/planlama yan etkilerini susturur.
///
/// Gercek servis `flutter_local_notifications` platform arayuzunu cagirir;
/// test ortaminda o `late` alan hic kurulmaz ve
/// `LateInitializationError` firlatir. Burada sinanan sey **sayac durum
/// makinesi**, bildirim gonderimi degil.
class _SilentAlarmService extends AlarmNotificationService {
  final List<String> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<void> initialize({
    void Function(NotificationResponse)? onResponse,
  }) async {}

  @override
  Future<void> scheduleTimer(
    TimerInstance instance, {
    SharedPreferences? prefs,
  }) async =>
      scheduled.add(instance.id);

  @override
  Future<void> cancelTimer(String id) async => cancelled.add(id);

  @override
  Future<void> showImmediate(String title, String body) async {}
}

Future<ProviderContainer> _container(
  List<TimerInstance> seed, {
  int nowMs = _kNow,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = LocalAlarmRepository(prefs);
  for (final instance in seed) {
    await repo.saveTimerInstance(instance);
  }
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      alarmRepositoryProvider.overrideWithValue(repo),
      epochClockProvider.overrideWithValue(FakeEpochClock(nowMs)),
      alarmNotificationServiceProvider.overrideWithValue(_SilentAlarmService()),
    ],
  );
}

/// Provider'ı canlı tutar (auto-dispose tuzağı) ve ilk değeri bekler.
Future<List<TimerInstance>> _read(ProviderContainer container) async {
  container.listen(timerInstancesProvider, (_, _) {});
  return container.read(timerInstancesProvider.future);
}

/// Mutasyon sonrası güncel durum.
///
/// `_mutate` sonunda `ref.invalidateSelf()` çağırır: durum senkron
/// değişmez, provider yeniden build olur ve değeri depodan tazeler.
/// Doğrudan `container.read(...).value` okumak eski değeri görür.
Future<List<TimerInstance>> _after(ProviderContainer container) =>
    container.read(timerInstancesProvider.future);

TimerInstance _running({
  required String id,
  required int durationSeconds,
  required int endsAtEpochMs,
  int? remainingSeconds,
}) =>
    TimerInstance(
      id: id,
      label: 'Odak',
      durationSeconds: durationSeconds,
      remainingSeconds: remainingSeconds ?? durationSeconds,
      status: TimerStateStatus.running,
      endsAtEpochMs: endsAtEpochMs,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimerInstancesNotifier.build — acilis uzlastirmasi', () {
    // 🔴 Kalici ders: uygulama arka plandayken `remainingSeconds` DONAR.
    // Gercek kalan sure yalnizca `endsAtEpochMs - now` ile bulunur.
    test('arka planda gecen sure acilista epoch\'tan yeniden hesaplanir',
        () async {
      final container = await _container([
        // 600 sn'lik sayac; bitisine 120 sn kaldi ama onbellek hala 600 diyor.
        _running(
          id: 't1',
          durationSeconds: 600,
          endsAtEpochMs: _kNow + 120 * 1000,
          remainingSeconds: 600,
        ),
      ]);
      addTearDown(container.dispose);

      final list = await _read(container);

      expect(list.single.status, TimerStateStatus.running);
      expect(list.single.remainingSeconds, 120,
          reason: 'onbellek degil, epoch farki gecerli olmali');
    });

    test('suresi arka planda dolan sayac acilista done olur', () async {
      final container = await _container([
        _running(
          id: 't1',
          durationSeconds: 600,
          endsAtEpochMs: _kNow - 5 * 1000, // 5 sn once bitmis
          remainingSeconds: 600,
        ),
      ]);
      addTearDown(container.dispose);

      final list = await _read(container);

      expect(list.single.status, TimerStateStatus.done);
      expect(list.single.remainingSeconds, 0);
      expect(list.single.endsAtEpochMs, isNull,
          reason: 'biten sayacta bitis damgasi temizlenmeli');
    });

    // Eski kayit gocu: `endsAtEpochMs` alani eklenmeden once kaydedilmis
    // satirlar. Turetilmezse sayac hicbir zaman bitmez.
    test('endsAt tasimayan eski kayit icin bitis damgasi turetilir', () async {
      final container = await _container([
        TimerInstance(
          id: 't1',
          label: 'Odak',
          durationSeconds: 600,
          remainingSeconds: 300,
          status: TimerStateStatus.running,
          // Eski kayitlarda bitis damgasi yok ama son guncelleme var;
          // bitis bu ikisinden turetilir.
          lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(_kNow),
        ),
      ]);
      addTearDown(container.dispose);

      final list = await _read(container);

      expect(list.single.endsAtEpochMs, _kNow + 300 * 1000);
      expect(list.single.remainingSeconds, 300);
    });

    test('duraklatilmis sayac acilista dokunulmadan kalir', () async {
      final container = await _container([
        TimerInstance(
          id: 't1',
          label: 'Odak',
          durationSeconds: 600,
          remainingSeconds: 420,
          status: TimerStateStatus.paused,
        ),
      ]);
      addTearDown(container.dispose);

      final list = await _read(container);

      expect(list.single.status, TimerStateStatus.paused);
      expect(list.single.remainingSeconds, 420,
          reason: 'duraklatilmis sayacta zaman islememeli');
    });
  });

  group('TimerInstancesNotifier — duraklat / devam et', () {
    test('duraklatma kalan sureyi dondurur ve bitis damgasini siler',
        () async {
      final container = await _container([
        _running(
          id: 't1',
          durationSeconds: 600,
          endsAtEpochMs: _kNow + 200 * 1000,
        ),
      ]);
      addTearDown(container.dispose);
      await _read(container);

      await container.read(timerInstancesProvider.notifier).pauseInstance('t1');
      final list = await _after(container);

      expect(list.single.status, TimerStateStatus.paused);
      expect(list.single.remainingSeconds, 200);
      // 🔴 Damga silinmezse devam ettirildiginde eski bitise atlar.
      expect(list.single.endsAtEpochMs, isNull);
    });

    test('devam ettirme kalan sureden yeni bitis damgasi kurar', () async {
      final container = await _container([
        TimerInstance(
          id: 't1',
          label: 'Odak',
          durationSeconds: 600,
          remainingSeconds: 200,
          status: TimerStateStatus.paused,
        ),
      ]);
      addTearDown(container.dispose);
      await _read(container);

      await container
          .read(timerInstancesProvider.notifier)
          .resumeInstance('t1');
      final list = await _after(container);

      expect(list.single.status, TimerStateStatus.running);
      expect(list.single.endsAtEpochMs, _kNow + 200 * 1000);
    });
  });

  group('TimerInstancesNotifier — durdur ve sure ekle', () {
    test('durdurma sayaci baslangica sifirlar', () async {
      final container = await _container([
        _running(
          id: 't1',
          durationSeconds: 600,
          endsAtEpochMs: _kNow + 100 * 1000,
        ),
      ]);
      addTearDown(container.dispose);
      await _read(container);

      await container.read(timerInstancesProvider.notifier).stopInstance('t1');
      final list = await _after(container);

      expect(list.single.status, TimerStateStatus.initial);
      expect(list.single.remainingSeconds, 600);
      expect(list.single.endsAtEpochMs, isNull);
    });

    test('sure ekleme calisan sayacin bitisini ileri atar', () async {
      final container = await _container([
        _running(
          id: 't1',
          durationSeconds: 600,
          endsAtEpochMs: _kNow + 100 * 1000,
        ),
      ]);
      addTearDown(container.dispose);
      await _read(container);

      await container
          .read(timerInstancesProvider.notifier)
          .addMinute('t1', minutes: 2);
      final list = await _after(container);

      expect(list.single.remainingSeconds, 100 + 120);
    });

    test('silme sayaci listeden cikarir', () async {
      final container = await _container([
        _running(
          id: 't1',
          durationSeconds: 600,
          endsAtEpochMs: _kNow + 100 * 1000,
        ),
        _running(
          id: 't2',
          durationSeconds: 300,
          endsAtEpochMs: _kNow + 50 * 1000,
        ),
      ]);
      addTearDown(container.dispose);
      await _read(container);

      await container
          .read(timerInstancesProvider.notifier)
          .deleteInstance('t1');
      final list = await _after(container);

      expect(list.map((e) => e.id), ['t2']);
    });
  });

  group('AlarmsNotifier', () {
    test('alarmlar saate, sonra dakikaya gore siralanir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final AlarmRepository repo = LocalAlarmRepository(prefs);
      await repo.saveAlarm(
        const AlarmRule(id: 'a', label: 'gec', hour: 9, minute: 30),
      );
      await repo.saveAlarm(
        const AlarmRule(id: 'b', label: 'erken', hour: 7, minute: 15),
      );
      await repo.saveAlarm(
        const AlarmRule(id: 'c', label: 'orta', hour: 7, minute: 45),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          alarmRepositoryProvider.overrideWithValue(repo),
          epochClockProvider.overrideWithValue(FakeEpochClock(_kNow)),
          alarmNotificationServiceProvider
              .overrideWithValue(_SilentAlarmService()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(alarmsProvider, (_, _) {});

      final list = await container.read(alarmsProvider.future);

      expect(list.map((e) => e.id), ['b', 'c', 'a']);
    });
  });
}
