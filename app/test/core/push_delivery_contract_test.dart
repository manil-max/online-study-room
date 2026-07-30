import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration keeps tokens/outbox private and provider RPC service-only', () {
    final sql = File(
      '../supabase/migrations/0066_push_notification_delivery.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('alter table public.push_devices enable row level security'),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.push_devices from anon, authenticated',
      ),
    );
    expect(sql, contains('unique (outbox_id, device_id)'));
    expect(sql, contains("'nudge:' || new.id::text"));
    expect(
      sql,
      contains(
        'grant execute on function public.claim_push_deliveries(uuid, integer, integer) to service_role',
      ),
    );
    expect(sql, isNot(contains('BEGIN PRIVATE KEY')));
  });

  test('WP-432 scopes self-test to its registered device', () {
    final migration = File(
      '../supabase/migrations/0102_push_device_targeting.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/supabase/supabase_push_registration_repository.dart',
    ).readAsStringSync();
    final provider = File(
      'lib/data/providers/push_notification_providers.dart',
    ).readAsStringSync();

    expect(migration, contains('target_device_id uuid'));
    expect(
      migration,
      contains('new.target_device_id is null or d.id = new.target_device_id'),
    );
    expect(migration, contains('request_push_self_test(p_device_id uuid)'));
    expect(migration, contains('push_test_target_device_required'));
    expect(
      migration,
      contains('new.origin_device_id is null or d.id <> new.origin_device_id'),
    );
    expect(migration, isNot(contains('BEGIN PRIVATE KEY')));
    expect(repository, contains("params: {'p_device_id': deviceId}"));
    expect(provider, contains('repository.requestSelfTest(deviceId)'));
  });

  test(
    'Edge dispatcher uses OAuth HTTP v1, bounded claims and redacted errors',
    () {
      final source = File(
        '../supabase/functions/dispatch-push/index.ts',
      ).readAsStringSync();

      expect(source, contains('FCM_SERVICE_ACCOUNT_BASE64'));
      expect(source, contains('decodeBase64Utf8'));
      expect(source, contains('claim_push_deliveries'));
      expect(source, contains('complete_push_delivery'));
      expect(source, contains('configure_push_dispatch'));
      expect(source, contains('get_push_dispatch_queue_health'));
      expect(source, contains('requestBody.action === "health"'));
      expect(source, contains('https://fcm.googleapis.com/v1/projects/'));
      expect(source, contains('data: stringData(delivery, content)'));
      expect(source, isNot(contains('notification: content')));
      // WP-303: mesaj data-only kalmalı. `android.notification` blokunun
      // varlığı — title/body taşımasa bile — FCM SDK'sına bildirimi kendisi
      // göstertir; blok içeriksiz olduğu için kullanıcıya BOŞ bir bildirim
      // düşer ve Dart'ın gösterdiği gerçek bildirimin yanında ikinci satır
      // olarak görünür. Beta 1'de bildirilen hata tam olarak buydu.
      expect(source, isNot(matches(RegExp(r'notification:\s*\{'))));
      expect(source, isNot(contains('notification_priority')));
      expect(source, isNot(contains('channel_id:')));
      expect(source, contains('UNREGISTERED'.toLowerCase()));
      expect(source, isNot(contains('console.log(delivery.fcm_token)')));
    },
  );

  test('Flutter receiver covers foreground/background/terminated states', () {
    final source = File(
      'lib/core/notifications/app_push_notification_service.dart',
    ).readAsStringSync();

    expect(source, contains('FirebaseMessaging.onMessage.listen'));
    expect(source, contains('FirebaseMessaging.onMessageOpenedApp.listen'));
    expect(source, contains('getInitialMessage()'));
    expect(source, contains('FirebaseMessaging.onBackgroundMessage'));
    expect(source, contains("@pragma('vm:entry-point')"));
    expect(
      source,
      contains('AppNotificationCoordinator.instance.showRemote(message)'),
    );
    expect(source, contains("message.data['title']"));
    expect(source, contains('_markReceivedOnce'));
    expect(source, contains("'social_nudges'"));
    expect(source, contains("'push_system_test'"));
    final healthSource = File(
      'lib/data/providers/push_notification_providers.dart',
    ).readAsStringSync();
    expect(
      healthSource,
      contains("snapshot.lastEventId == 'self_test:\${request.outboxId}'"),
    );
    expect(healthSource, contains('const Duration(seconds: 25)'));
    expect(healthSource, contains('classifyPushSelfTestFailure(status)'));
    final notificationScreen = File(
      'lib/features/notifications/notification_center_screen.dart',
    ).readAsStringSync();
    expect(
      notificationScreen,
      contains("health.errorCode == 'push_test_cooldown'"),
    );
    expect(notificationScreen, contains('notificationsRemoteTestCooldown'));
  });

  test(
    'retry worker keeps its secret out of cron commands and health read-only',
    () {
      final sql = File(
        '../supabase/migrations/0069_push_dispatch_retry_health.sql',
      ).readAsStringSync();
      final transportSql = File(
        '../supabase/migrations/0070_require_pg_net_for_push_dispatch.sql',
      ).readAsStringSync();

      expect(sql, contains("'push-dispatch-retry-worker'"));
      expect(
        sql,
        contains("'select public._request_scheduled_push_dispatch()'"),
      );
      expect(sql, contains('get_push_dispatch_queue_health'));
      expect(sql, contains('get_push_self_test_status'));
      expect(sql, isNot(contains('BEGIN PRIVATE KEY')));
      expect(transportSql, contains('create extension if not exists pg_net'));
      expect(transportSql, contains("'transport_unavailable'"));
      expect(transportSql, contains("p.proname = 'http_post'"));
    },
  );

  test('release build injects Firebase config and enqueues update push', () {
    final workflow = File(
      '../.github/workflows/release.yml',
    ).readAsStringSync();

    expect(workflow, contains('FIREBASE_PROJECT_ID'));
    expect(workflow, contains('FIREBASE_ANDROID_APP_ID'));
    expect(workflow, contains('Missing required environment variable'));
    expect(workflow, contains('action:"enqueue_update"'));
    expect(workflow, contains('PUSH_DISPATCH_SECRET'));
  });

  test('Android flavors use their matching native Firebase configs', () {
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final appGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final beta =
        jsonDecode(
              File(
                'android/app/src/beta/google-services.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final stable =
        jsonDecode(
              File(
                'android/app/src/stable/google-services.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    String packageFor(Map<String, dynamic> config, String appId) {
      final clients = config['client'] as List<dynamic>;
      final client = clients.cast<Map<String, dynamic>>().singleWhere(
        (entry) =>
            (entry['client_info']
                as Map<String, dynamic>)['mobilesdk_app_id'] ==
            appId,
      );
      return ((client['client_info']
                  as Map<String, dynamic>)['android_client_info']
              as Map<String, dynamic>)['package_name']
          as String;
    }

    expect(settings, contains('com.google.gms.google-services'));
    expect(appGradle, contains('id("com.google.gms.google-services")'));
    expect(appGradle, contains('processLocal'));
    expect(
      packageFor(beta, '1:422149816131:android:93ffb8db7b3bd201a8f9f6'),
      'com.manilmax.online_study_room.beta',
    );
    expect(
      packageFor(stable, '1:422149816131:android:82802517f9fa5ff9a8f9f6'),
      'com.manilmax.online_study_room',
    );
  });
}
