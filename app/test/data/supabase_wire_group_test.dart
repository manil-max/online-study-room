// Kablo testleri — grup yaşam döngüsü.
//
// Şablon ve gerekçe: `supabase_wire_contract_test.dart` başlığı.
//
// Buradaki asıl invariant: **davet kodu ve üyelik sunucuda kurulur.**
// İstemci `groups`/`group_members` tablolarına doğrudan yazmaz; yazsaydı
// kod bilinmeden gruba katılma ve kod ifşası mümkün olurdu. Testler bu
// sınırın kabloda gerçekten tutulduğunu doğruluyor.

import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_group_repository.dart';

import '../support/supabase_wire_harness.dart';

final _creator = Profile(
  id: 'u1',
  displayName: 'Ada',
  createdAt: DateTime.utc(2026, 1, 1),
);

Map<String, dynamic> _groupRow() => {
      'id': 'g1',
      'name': 'Calisma',
      'invite_code': 'ABC123',
      'created_by': 'u1',
      'created_at': '2026-01-01T00:00:00Z',
      'daily_goal_minutes': 120,
      'visibility': 'private',
      'member_limit': 20,
      'time_zone': 'Europe/Istanbul',
    };

void main() {
  late SupabaseWireHarness wire;
  setUp(() => wire = SupabaseWireHarness());

  group('SupabaseGroupRepository — kurulum', () {
    test('grup create_group_with_access RPC ile kurulur, tabloya insert yok',
        () async {
      wire.respond('create_group_with_access', _groupRow());
      final repo = SupabaseGroupRepository(wire.client());

      final createdGroup = await repo.createGroup(
        name: '  Calisma  ',
        creator: _creator,
      );

      final json = wire.rpc('create_group_with_access').json;
      expect(json['p_name'], 'Calisma');
      expect(json['p_visibility'], 'private');
      expect(json['p_time_zone'], 'Europe/Istanbul');
      // 🔴 Davet kodu SUNUCUDA uretilir; istemci gondermez.
      expect(json.containsKey('p_invite_code'), isFalse);
      // Istemci `groups` tablosuna dogrudan yazmamali.
      expect(wire.calls.map((c) => c.table), isNot(contains('groups')));
      expect(createdGroup.inviteCode, 'ABC123');
    });

    test('bos grup adi sunucuya hic gitmez', () async {
      final repo = SupabaseGroupRepository(wire.client());

      await expectLater(
        repo.createGroup(name: '   ', creator: _creator),
        throwsA(isA<GroupException>()),
      );
      expect(wire.calls, isEmpty);
    });

    test('davet kodu buyuk harfe cevrilip sunucuda dogrulanir', () async {
      wire.respond('join_group', _groupRow());
      final repo = SupabaseGroupRepository(wire.client());

      await repo.joinGroup(inviteCode: '  abc123 ', member: _creator);

      expect(wire.rpc('join_group').json['p_code'], 'ABC123');
      // Istemci `group_members`a dogrudan insert atmamali.
      expect(wire.calls.map((c) => c.table), isNot(contains('group_members')));
    });

    test('bilinmeyen kod icin sunucu null dondurunce anlamli hata verilir',
        () async {
      wire.respond('join_group', null);
      final repo = SupabaseGroupRepository(wire.client());

      await expectLater(
        repo.joinGroup(inviteCode: 'YOK123', member: _creator),
        throwsA(isA<GroupException>()),
      );
    });

    test('acik gruba katilim yalniz grup kimligi tasir', () async {
      wire.respond('join_public_group', _groupRow());
      final repo = SupabaseGroupRepository(wire.client());

      await repo.joinPublicGroup(groupId: 'g1', member: _creator);

      expect(wire.rpc('join_public_group').json['p_group_id'], 'g1');
    });
  });

  group('SupabaseGroupRepository — kesif', () {
    test('acik grup kesfi limiti 1-50 araligina kirpar', () async {
      wire.respond('discover_public_groups', const []);
      final repo = SupabaseGroupRepository(wire.client());

      await repo.discoverPublicGroups(limit: 500, offset: -3);

      final json = wire.rpc('discover_public_groups').json;
      expect(json['p_limit'], 50);
      // Negatif offset sunucuda hata olurdu; istemci sifira cekmeli.
      expect(json['p_offset'], 0);
    });
  });

  group('SupabaseGroupRepository — yonetim', () {
    test('davet kodu yenileme sunucuda yapilir', () async {
      wire.respond('regenerate_group_invite_code', 'XYZ789');
      final repo = SupabaseGroupRepository(wire.client());

      final code = await repo.regenerateInviteCode('g1');

      expect(wire.rpc('regenerate_group_invite_code').json['p_group_id'], 'g1');
      expect(code, 'XYZ789');
    });

    test('uye yasaklama/kaldirma dogru RPC adlarini kullanir', () async {
      wire.respond('ban_group_member', null);
      wire.respond('unban_group_member', null);
      final repo = SupabaseGroupRepository(wire.client());

      await repo.banMember('g1', 'u2');
      expect(wire.rpc('ban_group_member').json['p_user_id'], 'u2');

      await repo.unbanMember('g1', 'u2');
      expect(wire.rpc('unban_group_member').json['p_user_id'], 'u2');
    });

    test('saat dilimi guncellemesi kirpilmis deger gonderir', () async {
      wire.respond('update_group_time_zone', null);
      final repo = SupabaseGroupRepository(wire.client());

      await repo.updateGroupTimeZone('g1', '  Europe/Istanbul  ');

      expect(wire.rpc('update_group_time_zone').json['p_time_zone'],
          'Europe/Istanbul');
    });
  });

  group('SupabaseGroupRepository — gruptan cikma', () {
    // 🔴 `userId` sunucuya GONDERILMEZ; kimlik `auth.uid()`ten okunur.
    // Gonderilseydi bir kullanici baskasini gruptan atabilirdi.
    test('cikis komutu kullanici kimligi gondermez', () async {
      wire.respond('leave_group', 'left');
      final repo = SupabaseGroupRepository(wire.client());

      await repo.leaveGroup('g1', 'u1', commandId: 'cmd-1');

      final json = wire.rpc('leave_group').json;
      expect(json['p_group_id'], 'g1');
      expect(json['p_command_id'], 'cmd-1');
      expect(json.containsKey('p_user_id'), isFalse);
    });

    // Idempotans: ayni komut iki kez gonderilirse ikinci kez `already_left`
    // doner ve istemci bunu hata saymamali (aglar tekrar dener).
    test('already_left ayri sonuc olarak ayirt edilir, hata degil', () async {
      wire.respond('leave_group', 'already_left');
      final repo = SupabaseGroupRepository(wire.client());

      final outcome = await repo.leaveGroup('g1', 'u1', commandId: 'cmd-1');

      expect(outcome, GroupLeaveOutcome.alreadyLeft);
    });

    test('sahip cikamaz hatasi ayri istisna tipine cevrilir', () async {
      wire.failWith('leave_group',
          status: 400, message: 'owner_must_transfer_or_delete');
      final repo = SupabaseGroupRepository(wire.client());

      await expectLater(
        repo.leaveGroup('g1', 'u1', commandId: 'cmd-1'),
        throwsA(isA<GroupOwnerCannotLeaveException>()),
      );
    });

    test('son yonetici hatasi da ayni ozel istisnaya duser', () async {
      wire.failWith('leave_group',
          status: 400, message: 'last_admin_must_transfer');
      final repo = SupabaseGroupRepository(wire.client());

      await expectLater(
        repo.leaveGroup('g1', 'u1', commandId: 'cmd-1'),
        throwsA(isA<GroupOwnerCannotLeaveException>()),
      );
    });

    test('diger sunucu hatalari genel GroupException olur', () async {
      wire.failWith('leave_group', status: 500, message: 'boom');
      final repo = SupabaseGroupRepository(wire.client());

      await expectLater(
        repo.leaveGroup('g1', 'u1', commandId: 'cmd-1'),
        throwsA(isA<GroupException>()),
      );
    });
  });
}
