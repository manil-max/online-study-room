// WP-557 — tekrarlayan alarmın hayatta kalması ve hayalet alarm kapısı.
//
// Bağımsız denetimin bulduğu iki en ağır kullanıcı hatası:
//
// 🔴 Hata 1: Pzt-Cum 07:00 alarmı bir kez çalıyor, bir daha ASLA kurulmuyordu.
//    `AlarmReceiver`ın FIRE dalında `scheduleAlarm` yoktu, "Kapat"
//    PendingIntent'i iptal ediyordu ve Dart tarafında yeniden kurma yalnız
//    `saveAlarm/deleteAlarm/toggleAlarm/skipNext` yollarından geçiyordu.
//    `rescheduleAll()` repo genelinde HİÇ çağrılmıyordu.
//
// 🔴 Hata 2: `main()` `RESCHEDULE_PENDING` bayrağını okuyup atıyor (`if`
//    gövdesi boştu), `rescheduleFromMirror()` ise bayraktan bağımsız her
//    açılışta koşuyordu. Mirror'daki geçmiş `triggerAtMs` "kaçırılmış alarm"
//    sayıldığı için 14:30'da uygulamayı açmak sabahki alarmı çaldırıyordu.
//
// Burada mantık yeniden yazılmaz: gerçek `AlarmsNotifier`, gerçek
// `NativeAlarmBridge` ve gerçek `main.dart` kapısı sahte prefs üzerinde
// koşturulur. Geçmiş tetiğin `fireNow` üretmemesinin native yarısı
// `AlarmNextOccurrenceTest` (JVM) tarafında ölçülür.

import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/alarm_notification_service.dart';
import 'package:online_study_room/core/notifications/native_alarm_bridge.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/time_engine/epoch_clock.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/providers/alarm_providers.dart';
import 'package:online_study_room/data/repositories/local/local_alarm_repository.dart';
import 'package:online_study_room/main.dart';

/// Salı 07:00:05 — alarm az önce çaldı, kullanıcı "Kapat"a bastı.
final _tuesdayJustAfterRing = DateTime(2026, 8, 11, 7, 0, 5);
final _wednesdayRing = DateTime(2026, 8, 12, 7, 0);

const _weekdayAlarm = AlarmRule(
  id: 'a1',
  hour: 7,
  minute: 0,
  days: [1, 2, 3, 4, 5],
  isActive: true,
  label: 'Sabah',
);

/// Planlama yan etkilerini susturur; mirror yazımı `_syncNative` içinde
/// doğrudan `NativeAlarmBridge` üzerinden olur, bu yüzden ölçüm bozulmaz.
class _SilentAlarmService extends AlarmNotificationService {
  int rescheduleAllCalls = 0;

  @override
  Future<void> initialize({
    void Function(NotificationResponse)? onResponse,
  }) async {}

  @override
  Future<void> rescheduleAll(
    List<AlarmRule> alarms, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    rescheduleAllCalls++;
  }
}

/// `main()` kapısını ölçmek için: gerçek köprü test hostunda
/// (`Platform.isAndroid == false`) kanalı hiç çağırmaz, o yüzden çağrı
/// sayısı köprü seviyesinde sayılır.
class _RecordingBridge extends NativeAlarmBridge {
  int rescheduleFromMirrorCalls = 0;

  @override
  Future<void> rescheduleFromMirror() async {
    rescheduleFromMirrorCalls++;
  }
}

Future<ProviderContainer> _container({
  required SharedPreferences prefs,
  required DateTime now,
  required _SilentAlarmService service,
}) async {
  final repo = LocalAlarmRepository(prefs);
  await repo.saveAlarm(_weekdayAlarm);
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      alarmRepositoryProvider.overrideWithValue(repo),
      epochClockProvider.overrideWithValue(
        FakeEpochClock(now.millisecondsSinceEpoch),
      ),
      alarmNotificationServiceProvider.overrideWithValue(service),
    ],
  );
}

List<Map<String, dynamic>> _mirror(SharedPreferences prefs) {
  final raw = prefs.getString(NativeAlarmBridge.mirrorAlarmsKey);
  if (raw == null) return const [];
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

/// Native FIRE dalının bıraktığı cold-start yükü.
String _pendingRing(String id) =>
    jsonEncode({'kind': 'alarm', 'id': id, 'label': 'Sabah', 'at': 1});

/// Alarm çaldıktan sonra tazelenmemiş mirror (Hata 1'in bıraktığı durum).
String _staleMirror(DateTime firedAt) => jsonEncode([
  {
    'id': 'a1',
    'active': true,
    'triggerAtMs': firedAt.millisecondsSinceEpoch,
    'label': 'Sabah',
    'hour': 7,
    'minute': 0,
    'crescendo': true,
    'vibrate': true,
    'antiSnooze': false,
    'snoozeMin': 5,
    'days': [1, 2, 3, 4, 5],
  },
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hata 1 — tekrarlayan alarm çaldıktan sonra yeniden kurulur', () {
    test('native çalma tüketilince mirror bir sonraki occurrence\'a ilerler',
        () async {
      SharedPreferences.setMockInitialValues({
        NativeAlarmBridge.pendingRingKey: _pendingRing('a1'),
        NativeAlarmBridge.mirrorAlarmsKey:
            _staleMirror(DateTime(2026, 8, 11, 7, 0)),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = _SilentAlarmService();
      final container = await _container(
        prefs: prefs,
        now: _tuesdayJustAfterRing,
        service: service,
      );
      addTearDown(container.dispose);
      // Riverpod 3: dinleyicisiz provider her read'de yeniden build olur.
      container.listen(alarmsProvider, (_, _) {});

      await container.read(alarmsProvider.future);

      final entry = _mirror(prefs).single;
      expect(
        entry['triggerAtMs'],
        _wednesdayRing.millisecondsSinceEpoch,
        reason: 'Salı çaldıktan sonra Çarşamba 07:00 kurulmalı',
      );
      expect(
        entry['triggerAtMs'],
        greaterThan(_tuesdayJustAfterRing.millisecondsSinceEpoch),
        reason: 'geçmiş tetik bırakmak hayalet alarm üretir',
      );
      expect(
        service.rescheduleAllCalls,
        1,
        reason: 'native planlayıcı da tazelenmeli, yalnız mirror değil',
      );
    });

    test('tüketilen cold-start yükü prefs\'te bayat kalmaz', () async {
      SharedPreferences.setMockInitialValues({
        NativeAlarmBridge.pendingRingKey: _pendingRing('a1'),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = await _container(
        prefs: prefs,
        now: _tuesdayJustAfterRing,
        service: _SilentAlarmService(),
      );
      addTearDown(container.dispose);
      container.listen(alarmsProvider, (_, _) {});

      await container.read(alarmsProvider.future);

      expect(prefs.getString(NativeAlarmBridge.pendingRingKey), isNull);
    });

    test('çalma olmadan açılış native planlamayı boşuna tekrarlamaz', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = _SilentAlarmService();
      final container = await _container(
        prefs: prefs,
        now: _tuesdayJustAfterRing,
        service: service,
      );
      addTearDown(container.dispose);
      container.listen(alarmsProvider, (_, _) {});

      await container.read(alarmsProvider.future);

      expect(service.rescheduleAllCalls, 0);
    });

    test('mirror tekrar kuralını taşır — native onsuz hesap yapamaz', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bridge = NativeAlarmBridge.instance;

      await bridge.writeAlarmMirror(
        prefs,
        [
          _weekdayAlarm.copyWith(skipNextOn: DateTime(2026, 8, 12)),
        ],
        _tuesdayJustAfterRing,
      );

      final entry = _mirror(prefs).single;
      expect(entry['days'], [1, 2, 3, 4, 5]);
      expect(entry['skipNextOn'], startsWith('2026-08-12'));
      expect(entry.containsKey('date'), isTrue);
      // Skip edilen Çarşamba atlandı → Perşembe.
      expect(
        entry['triggerAtMs'],
        DateTime(2026, 8, 13, 7, 0).millisecondsSinceEpoch,
      );
    });
  });

  group('Hata 2 — açılış geçmişteki alarmı çaldırmaz', () {
    test('bayrak yokken mirror\'dan yeniden kurma HİÇ çağrılmaz', () async {
      SharedPreferences.setMockInitialValues({
        NativeAlarmBridge.mirrorAlarmsKey:
            _staleMirror(DateTime(2026, 8, 11, 7, 0)),
      });
      final prefs = await SharedPreferences.getInstance();
      final bridge = _RecordingBridge();

      await reconcileNativeAlarmsOnStart(prefs, bridge);

      expect(
        bridge.rescheduleFromMirrorCalls,
        0,
        reason: 'her açılışta çağırmak geçmiş tetiği kaçırılmış alarm sanar',
      );
    });

    test('boot bayrağı basılıysa tam bir kez çağrılır ve bayrak temizlenir',
        () async {
      SharedPreferences.setMockInitialValues({
        NativeAlarmBridge.reschedulePendingKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final bridge = _RecordingBridge();

      await reconcileNativeAlarmsOnStart(prefs, bridge);
      expect(bridge.rescheduleFromMirrorCalls, 1);

      // İkinci açılış: bayrak tüketildiği için tekrar koşmaz.
      await reconcileNativeAlarmsOnStart(prefs, bridge);
      expect(
        bridge.rescheduleFromMirrorCalls,
        1,
        reason: 'bayrak tüketilmezse her açılış native reschedule tetikler',
      );
      expect(prefs.getBool(NativeAlarmBridge.reschedulePendingKey), isFalse);
    });
  });
}
