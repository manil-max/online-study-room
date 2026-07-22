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

  test(
    'Edge dispatcher uses OAuth HTTP v1, bounded claims and redacted errors',
    () {
      final source = File(
        '../supabase/functions/dispatch-push/index.ts',
      ).readAsStringSync();

      expect(source, contains('FCM_SERVICE_ACCOUNT_JSON'));
      expect(source, contains('claim_push_deliveries'));
      expect(source, contains('complete_push_delivery'));
      expect(source, contains('https://fcm.googleapis.com/v1/projects/'));
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
  });

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
}
