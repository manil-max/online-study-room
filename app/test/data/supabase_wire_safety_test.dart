// Kablo testleri — hesap silme, engelleme, şikâyet ve itiraz yüzeyleri.
//
// Şablon ve gerekçe: `supabase_wire_contract_test.dart` başlığı.
//
// Bu grup ürünün en yüksek riskli yüzeyi: hesap silme geri alınamaz,
// şikâyet/engelleme ise kullanıcı güvenliğidir. `0113`/`0114` ile purge
// zinciri yeni kuruldu; istemci ucunun doğru RPC'leri çağırdığı ve
// sunucu hatasını yutmadığı burada sabitlenir.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/moderation_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_moderation_repository.dart';

import '../support/supabase_wire_harness.dart';

void main() {
  late SupabaseWireHarness wire;
  setUp(() => wire = SupabaseWireHarness());

  group('SupabaseAuthRepository — hesap silme', () {
    test('silme talebi request_account_deletion RPC adiyla, parametresiz gider',
        () async {
      wire.respond('request_account_deletion', {
        'active': true,
        'status': 'scheduled',
        'requested_at': '2026-08-01T10:00:00Z',
        'purge_after': '2026-08-15T10:00:00Z',
      });
      final repo = SupabaseAuthRepository(wire.client());

      final status = await repo.requestAccountDeletion();

      // Sunucu imzasi parametresiz (`auth.uid()` kullanir). Fazladan anahtar
      // PostgREST'te eslesmez ve cagri 404 olur.
      expect(wire.rpc('request_account_deletion').json, isEmpty);
      expect(status.active, isTrue);
      expect(status.status, 'scheduled');
      expect(status.purgeAfter, DateTime.utc(2026, 8, 15, 10));
    });

    test('iptal cancel_account_deletion RPC adiyla gider', () async {
      wire.respond('cancel_account_deletion', {'active': false});
      final repo = SupabaseAuthRepository(wire.client());

      final status = await repo.cancelAccountDeletion();

      expect(wire.rpc('cancel_account_deletion').json, isEmpty);
      expect(status.active, isFalse);
    });

    test('durum sorgusu my_account_deletion_status RPC adiyla gider', () async {
      wire.respond('my_account_deletion_status', {'active': false});
      final repo = SupabaseAuthRepository(wire.client());

      await repo.fetchAccountDeletionStatus();

      expect(wire.rpc('my_account_deletion_status').json, isEmpty);
    });

    // 🔴 Sunucu Map disinda bir sey dondurdugunde (RPC yok, sema degisti)
    // sessizce "silme talebi yok" denmemeli mi? Mevcut davranis
    // `inactive` donmek. Bu testi kirmadan o davranisi degistirmek mumkun
    // degil — yani karar bilincli olarak sabitlenmis olur.
    test('sunucu beklenmedik sekil dondurunce inactive kabul edilir', () async {
      wire.respond('my_account_deletion_status', const []);
      final repo = SupabaseAuthRepository(wire.client());

      final status = await repo.fetchAccountDeletionStatus();

      expect(status.active, isFalse);
    });

    test('sunucu hatasi AuthException olur, yutulmaz', () async {
      wire.failWith('request_account_deletion',
          status: 400, message: 'deletion_already_scheduled');
      final repo = SupabaseAuthRepository(wire.client());

      await expectLater(
        repo.requestAccountDeletion(),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('SupabaseModerationRepository — engelleme', () {
    test('engelle/kaldir dogru RPC adlarini ve p_blocked_id kullanir',
        () async {
      wire.respond('block_user', null);
      wire.respond('unblock_user', null);
      final repo = SupabaseModerationRepository(wire.client());

      await repo.blockUser('u2');
      expect(wire.rpc('block_user').json['p_blocked_id'], 'u2');

      await repo.unblockUser('u2');
      expect(wire.rpc('unblock_user').json['p_blocked_id'], 'u2');
    });

    test('topluluk kurallari kabulu surum numarasi tasir', () async {
      wire.respond('accept_community_terms', null);
      final repo = SupabaseModerationRepository(wire.client());

      await repo.acceptCommunityTerms('2026-01');

      expect(wire.rpc('accept_community_terms').json['p_version'], '2026-01');
    });

    test('engelli yoksa dizin RPC\'si hic cagrilmaz', () async {
      wire.respond('user_blocks', const []);
      final repo = SupabaseModerationRepository(wire.client());

      final profiles = await repo.fetchBlockedProfiles();

      expect(profiles, isEmpty);
      expect(wire.calls.map((c) => c.rpcName),
          isNot(contains('blocked_user_directory')),
          reason: 'bos listede sunucuya bos yere cagri gitmemeli');
    });

    test('engelli profiller blocked_user_directory RPC adiyla zenginlestirilir',
        () async {
      wire.respond('user_blocks', [
        {'blocked_id': 'u2'}
      ]);
      wire.respond('blocked_user_directory', [
        {
          'id': 'u2',
          'display_name': 'Bora',
          'created_at': '2026-01-01T00:00:00Z',
        }
      ]);
      final repo = SupabaseModerationRepository(wire.client());

      final profiles = await repo.fetchBlockedProfiles();

      // WP-413: `profiles` engelli cifti reddediyor; kullanici kimi
      // engelledigini yalniz bu RPC uzerinden gorebilir.
      expect(profiles.single.displayName, 'Bora');
    });

    // 🔴 RPC'si olmayan eski sunucuda ekran BOS kalmamali; kullanici kimi
    // engellediginin en azindan maskeli kimligini gormeli.
    test('dizin RPC\'si yoksa maskeli kimlige dusulur, ekran boslamaz',
        () async {
      wire.respond('user_blocks', [
        {'blocked_id': 'abcdef1234567890'}
      ]);
      wire.failWith('blocked_user_directory',
          status: 404, message: 'Could not find the function');
      final repo = SupabaseModerationRepository(wire.client());

      final profiles = await repo.fetchBlockedProfiles();

      expect(profiles, hasLength(1));
      expect(profiles.single.displayName, 'abcdef12…');
    });
  });

  group('SupabaseModerationRepository — sikayet', () {
    test('mesaj sikayeti report_ugc RPC adiyla ve baglam grubuyla gider',
        () async {
      wire.respond('report_ugc', null);
      final repo = SupabaseModerationRepository(wire.client());

      await repo.reportUgc(
        target: ReportTarget.message(
          messageId: 'm1',
          groupId: 'g1',
          hint: 'kotu mesaj',
        ),
        reason: 'harassment',
      );

      final json = wire.rpc('report_ugc').json;
      expect(json['p_target_type'], 'message');
      expect(json['p_target_id'], 'm1');
      expect(json['p_reason'], 'harassment');
      // Sunucu bunu mesajin gercek grubuyla birebir dogrular.
      expect(json['p_context_group_id'], 'g1');
    });

    test('profil sikayetinde baglam grubu anahtari hic gonderilmez', () async {
      wire.respond('report_ugc', null);
      final repo = SupabaseModerationRepository(wire.client());

      await repo.reportUgc(
        target: ReportTarget.profile(userId: 'u2'),
        reason: 'spam',
      );

      final json = wire.rpc('report_ugc').json;
      expect(json['p_target_type'], 'profile');
      // null gondermek ile hic gondermemek PostgREST'te farkli sonuclanir.
      expect(json.containsKey('p_context_group_id'), isFalse);
    });

    test('ek yuklemesi basarisizsa sikayet yine de eksiz gider (WP-423)',
        () async {
      wire.respond('report_ugc', null);
      // Storage yuklemesi hata dondursun.
      wire.failWith('report-attachments', status: 500, message: 'storage down');
      final repo = SupabaseModerationRepository(wire.client());

      await repo.reportUgc(
        target: ReportTarget.profile(userId: 'u2'),
        reason: 'spam',
        attachmentBytes: Uint8List.fromList([1, 2, 3]),
        attachmentExt: 'png',
      );

      // Bildirim kaybolmamali; yalniz ek yolu null olmali.
      expect(wire.rpc('report_ugc').json['p_attachment_path'], isNull);
    });
  });

  group('SupabaseModerationRepository — itiraz', () {
    test('cok kisa itiraz sunucuya hic gitmez', () async {
      final repo = SupabaseModerationRepository(wire.client());

      await expectLater(
        repo.submitAppeal(sanctionId: 's1', statement: 'kisa'),
        throwsA(isA<ModerationException>()),
      );
      expect(wire.calls, isEmpty,
          reason: 'istemci kapisi sunucuya bos yere yuk bindirmemeli');
    });

    test('uzun itiraz sunucuya gitmeden ust sinira kirpilir', () async {
      wire.respond('submit_moderation_appeal', {
        'id': 'ap1',
        'sanction_id': 's1',
        'statement': 'x',
        'status': 'open',
        'created_at': '2026-08-01T10:00:00Z',
      });
      final repo = SupabaseModerationRepository(wire.client());

      await repo.submitAppeal(
        sanctionId: 's1',
        statement: 'a' * (kAppealMaxLength + 500),
      );

      final sent = wire.rpc('submit_moderation_appeal').json['p_statement']
          as String;
      expect(sent.length, kAppealMaxLength);
    });

    test('sunucu decidable=false dondurunce istemci karar veremez', () async {
      wire.respond('submit_moderation_appeal', {
        'id': 'ap1',
        'sanction_id': 's1',
        'statement': 'yeterince uzun bir itiraz metni',
        'status': 'open',
        'created_at': '2026-08-01T10:00:00Z',
        'decidable': false,
      });
      final repo = SupabaseModerationRepository(wire.client());

      final appeal = await repo.submitAppeal(
        sanctionId: 's1',
        statement: 'yeterince uzun bir itiraz metni',
      );

      // `decidable` sunucuda `actor_id <> auth.uid()` ile hesaplanir;
      // istemci bunu kendi basina true yapamamali.
      expect(appeal.decidable, isFalse);
    });
  });
}
