import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/presence.dart';

/// WP-363: legacy `public.presence` yazma payload'ı ile gerçek tablo şeması
/// arasındaki sözleşme.
///
/// Bu testin varlık sebebi somut bir üretim hatasıdır: WP-339 modele
/// `leaseExpiresAt` ekledi, `toMap()` payload'a `lease_expires_at` koydu, ama o
/// kolon legacy tabloda yok. `upsert` PostgREST'te reddedildi, hata iki katmanda
/// yutuldu ve **v49 ile v50 boyunca presence sunucuya hiç yazılmadı** —
/// kullanıcı kendini yerel cache'ten aktif görüyor, karşı taraf hiç görmüyordu.
///
/// Test iki yönlü çalışır: payload uydurma kolon yazamaz, ve kolon listesi
/// migration dosyasındaki gerçek tablo tanımından sapamaz.
void main() {
  final presence = Presence(
    userId: 'u1',
    status: PresenceStatus.studying,
    todaySeconds: 900,
    groupId: 'g1',
    startedAt: DateTime.utc(2026, 7, 27, 10),
    subjectId: 's1',
    updatedAt: DateTime.utc(2026, 7, 27, 10, 5),
    // Modelde var, tabloda YOK: payload'a sızmamalı.
    leaseExpiresAt: DateTime.utc(2026, 7, 27, 10, 6),
  );

  test('payload yalnız legacy tablo kolonlarını içerir', () {
    final keys = presence.toMap().keys.toSet();
    final allowed = kLegacyPresenceColumns.toSet();
    expect(
      keys.difference(allowed),
      isEmpty,
      reason:
          'Tabloda olmayan kolon yazmak upsert\'i sessizce öldürür. '
          'Önce kolonu ekleyen ileri migration yaz.',
    );
  });

  test('lease_expires_at payload\'a girmez — bu hatanın kendisiydi', () {
    expect(presence.toMap().containsKey('lease_expires_at'), isFalse);
    // Alan modelden silinmedi; projeksiyon yolu onu okumaya devam eder.
    expect(presence.leaseExpiresAt, isNotNull);
  });

  test('modeldeki her legacy alan payload\'da taşınır', () {
    final map = presence.toMap();
    expect(map['user_id'], 'u1');
    expect(map['group_id'], 'g1');
    expect(map['status'], 'studying');
    expect(map['today_seconds'], 900);
    expect(map['subject_id'], 's1');
    // started_at UTC ISO olarak gider (saat dilimi kayması anlık süreyi bozar).
    expect(map['started_at'], '2026-07-27T10:00:00.000Z');
    expect(map['updated_at'], isA<String>());
  });

  test('kLegacyPresenceColumns 0001 migration şemasıyla birebir aynı', () {
    // Liste elle güncellenirse ama tablo değişmezse (veya tersi) burası kırılır.
    final sql = File(
      '../supabase/migrations/0001_initial_schema.sql',
    ).readAsStringSync();
    final match = RegExp(
      r'create table if not exists public\.presence \(([\s\S]*?)\n\);',
    ).firstMatch(sql);
    expect(match, isNotNull, reason: 'presence tablo tanımı bulunamadı');

    final columns = <String>[
      for (final line in match!.group(1)!.split('\n'))
        if (line.trim().isNotEmpty && !line.trim().startsWith('--'))
          line.trim().split(RegExp(r'\s+')).first,
    ];
    expect(columns, kLegacyPresenceColumns);
  });
}
