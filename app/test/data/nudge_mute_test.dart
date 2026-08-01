import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/data/repositories/nudge_repository.dart';

/// WP-444: kişi bazlı "yalnız dürtme" susturması.
///
/// Sözleşme testi: burada doğrulanan davranışın **aynısı** sunucu tarafında
/// `send_nudge` / `mute_nudges_from` pgTAP testleriyle kanıtlanır. İki uç
/// arasında sözleşme testi olmadığı için sessizce ölen özellikler yaşandı
/// (WP-373), bu yüzden semptom değil davranış sabitlenir.
Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026));

void main() {
  final ada = _profile('u1', 'Ada');
  final ece = _profile('u2', 'Ece');
  final can = _profile('u3', 'Can');

  InMemoryNudgeRepository repo({String currentUserId = 'u2'}) {
    final instance = InMemoryNudgeRepository(currentUserId: currentUserId);
    addTearDown(instance.dispose);
    return instance;
  }

  test('susturulan kişinin dürtmesi alıcıya düşmez, diğerleri düşer', () async {
    final nudges = repo(); // oturumdaki hesap: Ece
    await nudges.muteNudgesFrom(ada.id);

    await nudges.sendNudge(groupId: 'g1', sender: ada, recipient: ece);
    await nudges.sendNudge(groupId: 'g1', sender: can, recipient: ece);

    final received = await nudges.watchReceivedNudges(ece.id).first;
    expect(received.map((n) => n.senderId), [can.id]);
  });

  test('gönderen susturulduğunu anlayamaz: sonuç ve cooldown aynı', () async {
    final muted = repo();
    await muted.muteNudgesFrom(ada.id);
    final open = repo();

    final mutedResult = await muted.sendNudge(
      groupId: 'g1',
      sender: ada,
      recipient: ece,
      message: 'hadi',
    );
    final openResult = await open.sendNudge(
      groupId: 'g1',
      sender: ada,
      recipient: ece,
      message: 'hadi',
    );

    // Dönen satır susturulmamış durumla aynı şekildedir.
    expect(mutedResult.recipientId, openResult.recipientId);
    expect(mutedResult.message, openResult.message);
    expect(mutedResult.senderDisplayName, openResult.senderDisplayName);

    // Cooldown susturulmuş alıcıda da işler; yoksa "ikinci dürtme hemen kabul
    // edildi" farkı susturmayı ifşa ederdi.
    expect(
      () => muted.sendNudge(groupId: 'g1', sender: ada, recipient: ece),
      throwsA(
        isA<NudgeException>().having(
          (e) => e.message,
          'message',
          'Aynı kişiye 20 dakikada bir dürtme gönderebilirsin.',
        ),
      ),
    );
  });

  test('susturma geri alınabilir; sonraki dürtme normal düşer', () async {
    final nudges = repo();
    await nudges.muteNudgesFrom(ada.id);
    await nudges.sendNudge(groupId: 'g1', sender: ada, recipient: ece);
    expect(await nudges.watchReceivedNudges(ece.id).first, isEmpty);

    await nudges.unmuteNudgesFrom(ada.id);
    // Aynı çift için cooldown penceresi hâlâ açık olduğundan başka grup kullan.
    await nudges.sendNudge(groupId: 'g2', sender: ada, recipient: ece);

    final received = await nudges.watchReceivedNudges(ece.id).first;
    expect(received.map((n) => n.senderId), [ada.id]);
  });

  test('susturma hesap kapsamlıdır: yalnız susturanı etkiler', () async {
    final nudges = repo(); // Ece susturur
    await nudges.muteNudgesFrom(ada.id);

    await nudges.sendNudge(groupId: 'g1', sender: ada, recipient: ece);
    await nudges.sendNudge(groupId: 'g1', sender: ada, recipient: can);

    expect(await nudges.watchReceivedNudges(ece.id).first, isEmpty);
    expect(await nudges.watchReceivedNudges(can.id).first, hasLength(1));
  });

  test(
    'liste yalnız çağıranın kendi tercihini döndürür ve idempotenttir',
    () async {
      final nudges = repo();
      await nudges.muteNudgesFrom(ada.id);
      await nudges.muteNudgesFrom(ada.id); // tekrar → tek kayıt
      await nudges.muteNudgesFrom(can.id);

      expect((await nudges.listMutedNudgeSenderIds()).toSet(), {
        ada.id,
        can.id,
      });
      expect((await nudges.fetchNudgeMutes()).map((m) => m.mutedUserId), [
        ada.id,
        can.id,
      ]);

      // Gönderen (Ada) kendi oturumunda kimin kendisini susturduğunu göremez.
      final adaSession = repo(currentUserId: ada.id);
      expect(await adaSession.listMutedNudgeSenderIds(), isEmpty);

      await nudges.unmuteNudgesFrom(ada.id);
      expect(await nudges.listMutedNudgeSenderIds(), [can.id]);
    },
  );

  test('kendini susturma reddedilir', () async {
    final nudges = repo();
    expect(() => nudges.muteNudgesFrom(ece.id), throwsA(isA<NudgeException>()));
  });
}
