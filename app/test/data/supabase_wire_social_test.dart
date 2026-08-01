// Kablo testleri — dürtme, ödül ve presence repository'leri.
//
// Şablon ve gerekçe: `supabase_wire_contract_test.dart` başlığı.
//
// Bu grupta ağırlık **hata eşlemesinde**: dürtme yüzeyi sunucudan gelen
// `nudge_cooldown` / `nudge_blocked` gibi kodları kullanıcıya gösterilecek
// Türkçe metne çevirir. Eşleme kayarsa kullanıcı "Dürtme gönderilemedi:
// nudge_cooldown" gibi ham sunucu metni görür — sessiz bir UX regresyonu.

import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/repositories/nudge_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_achievement_reward_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_nudge_repository.dart';

import '../support/supabase_wire_harness.dart';

final _sender = Profile(
  id: 'u1',
  displayName: 'Ada',
  createdAt: DateTime.utc(2026, 1, 1),
);
final _recipient = Profile(
  id: 'u2',
  displayName: 'Bora',
  createdAt: DateTime.utc(2026, 1, 1),
);

Map<String, dynamic> _nudgeRow() => {
  'id': 'n1',
  'group_id': 'g1',
  'sender_id': 'u1',
  'recipient_id': 'u2',
  'message': 'hadi',
  'created_at': '2026-08-01T10:00:00Z',
  'read_at': null,
};

void main() {
  late SupabaseWireHarness wire;
  setUp(() => wire = SupabaseWireHarness());

  group('SupabaseNudgeRepository', () {
    test('durtme send_nudge RPC adiyla ve normalize mesajla gider', () async {
      wire.respond('send_nudge', _nudgeRow());
      final repo = SupabaseNudgeRepository(wire.client());

      final nudge = await repo.sendNudge(
        groupId: 'g1',
        sender: _sender,
        recipient: _recipient,
        message: '  hadi  ',
      );

      final json = wire.rpc('send_nudge').json;
      expect(json['p_group_id'], 'g1');
      expect(json['p_recipient_id'], 'u2');
      expect(json['p_message'], 'hadi');
      // Gonderen bilgisi istemcide eklenir; sunucu dondurmez.
      expect(nudge.senderDisplayName, 'Ada');
    });

    // 🔴 WP-444: susturma karari SUNUCUDA. Istemci susturulmus aliciyi
    // ayirt edememeli, yoksa suzgeci atlayabilir. Sunucu normal satir
    // dondurur; repository de normal davranmali.
    test('susturulmus alicida da normal durtme donulur (istemci ayirt edemez)',
      () async {
        wire.respond('send_nudge', _nudgeRow());
        final repo = SupabaseNudgeRepository(wire.client());

        final nudge = await repo.sendNudge(
          groupId: 'g1',
          sender: _sender,
          recipient: _recipient,
        );

        expect(nudge.id, 'n1');
    });

    test('mesajsiz durtmede p_message null gider', () async {
      wire.respond('send_nudge', _nudgeRow());
      final repo = SupabaseNudgeRepository(wire.client());

      await repo.sendNudge(
        groupId: 'g1',
        sender: _sender,
        recipient: _recipient,
      );

      expect(wire.rpc('send_nudge').json.containsKey('p_message'), isTrue);
    });

    // Sunucu kodu -> kullaniciya gosterilen Turkce metin eslemesi.
    // Eslemenin her dali ayri ayri sinaniyor; biri kayarsa ham sunucu
    // metni ekrana dusrer.
    for (final entry in const {
      'nudge_cooldown': '20 dakikada bir',
      'recipient_is_studying': 'şu an çalışıyor',
      'cannot_nudge_self': 'Kendine dürtme',
      'not_group_member': 'yetkin yok',
      'nudge_blocked': 'Engellenen kullanıcıyla',
    }.entries) {
      test('sunucu kodu `${entry.key}` Turkce mesaja cevrilir', () async {
        wire.failWith('send_nudge', status: 400, message: entry.key);
        final repo = SupabaseNudgeRepository(wire.client());

        await expectLater(
          repo.sendNudge(
            groupId: 'g1',
            sender: _sender,
            recipient: _recipient,
          ),
          throwsA(
            isA<NudgeException>().having(
              (e) => e.message,
              'mesaj',
              contains(entry.value),
            ),
          ),
        );
      });
    }

    test('susturma listesi nudge_mute_directory RPC adiyla cekilir', () async {
      wire.respond('nudge_mute_directory', [
        {
          'muted_sender_id': 'u3',
          'muted_at': '2026-08-01T10:00:00Z',
          'display_name': 'Cem',
          'avatar_url': null,
        }
      ]);
      final repo = SupabaseNudgeRepository(wire.client());

      final mutes = await repo.fetchNudgeMutes();

      expect(mutes.single.mutedUserId, 'u3');
      expect(mutes.single.displayName, 'Cem');
    });

    test('susturma/kaldirma dogru RPC adlarini kullanir', () async {
      wire.respond('mute_nudges_from', null);
      wire.respond('unmute_nudges_from', null);
      final repo = SupabaseNudgeRepository(wire.client());

      await repo.muteNudgesFrom('u3');
      expect(wire.rpc('mute_nudges_from').json['p_user_id'], 'u3');

      await repo.unmuteNudgesFrom('u3');
      expect(wire.rpc('unmute_nudges_from').json['p_user_id'], 'u3');
    });

    test('kendini susturma denemesi ayri mesaja cevrilir', () async {
      wire.failWith('mute_nudges_from', status: 400, message: 'cannot_mute_self');
      final repo = SupabaseNudgeRepository(wire.client());

      await expectLater(
        repo.muteNudgesFrom('u1'),
        throwsA(isA<NudgeException>()
            .having((e) => e.message, 'mesaj', contains('Kendini'))),
      );
    });

    test('okundu isareti mark_nudge_read RPC adiyla gider', () async {
      wire.respond('mark_nudge_read', null);
      final repo = SupabaseNudgeRepository(wire.client());

      await repo.markRead('n1');

      expect(wire.rpc('mark_nudge_read').json['p_nudge_id'], 'n1');
    });
  });

  group('SupabaseAchievementRewardRepository', () {
    Map<String, dynamic> reward(String id) => {
      'id': id,
      'user_id': 'u1',
      'achievement_id': 'a1',
      'tier': 1,
      'xp_amount': 50,
      'reason': null,
      'status': 'pending',
      'created_at': '2026-08-01T10:00:00Z',
      'claimed_at': null,
    };

    // 🔴 `userId` bilerek kabloya GONDERILMEZ; RPC onu `auth.uid()`den
    // turetir. Gonderilseydi istemci baskasinin odullerini isteyebilirdi.
    test('bekleyen odul listesi userId gondermez (sunucu auth.uid kullanir)',
      () async {
        wire.respond('list_pending_achievement_rewards', [reward('r1')]);
        final repo = SupabaseAchievementRewardRepository(wire.client());

        await repo.listPendingRewards(userId: 'u1', limit: 20);

        final json = wire.rpc('list_pending_achievement_rewards').json;
        expect(json.containsKey('p_user_id'), isFalse);
        expect(json['p_limit'], 20);
    });

    test('sayfa dolmadiginda sonraki imlec uretilmez', () async {
      wire.respond('list_pending_achievement_rewards', [reward('r1')]);
      final repo = SupabaseAchievementRewardRepository(wire.client());

      final page = await repo.listPendingRewards(userId: 'u1', limit: 20);

      expect(page.rewards, hasLength(1));
      expect(page.nextCursor, isNull);
    });

    test('sayfa tam dolunca sonraki imlec son satirdan uretilir', () async {
      wire.respond('list_pending_achievement_rewards',
          [reward('r1'), reward('r2')]);
      final repo = SupabaseAchievementRewardRepository(wire.client());

      final page = await repo.listPendingRewards(userId: 'u1', limit: 2);

      expect(page.nextCursor, isNotNull);
      expect(page.nextCursor!.id, 'r2');
    });

    test('odul talebi claim_achievement_reward RPC adiyla gider', () async {
      wire.respond('claim_achievement_reward', {
        'status': 'claimed',
        'reward': reward('r1'),
      });
      final repo = SupabaseAchievementRewardRepository(wire.client());

      await repo.claimReward(userId: 'u1', rewardId: 'r1');

      expect(wire.rpc('claim_achievement_reward').json['p_reward_id'], 'r1');
    });

    test('ozet RPC parametresiz cagrilir', () async {
      wire.respond('pending_achievement_reward_summary',
          {'pending_count': 2, 'pending_xp': 100});
      final repo = SupabaseAchievementRewardRepository(wire.client());

      await repo.getPendingSummary(userId: 'u1');

      // Sunucu imzasi parametresiz; fazladan anahtar PostgREST'te 404 olur.
      expect(wire.rpc('pending_achievement_reward_summary').json, isEmpty);
    });
  });
}
