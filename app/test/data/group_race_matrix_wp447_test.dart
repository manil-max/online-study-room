// WP-447: grup yarış koşulu ve güvenlik kabul matrisi.
//
// Bu dosya tek bir özelliği değil, **kavramlar arası** davranışı sabitler.
// v57 denetiminde çıkan ders şuydu: her kavram kendi WP'sinde tek başına
// doğrulanmıştı, ama aralarındaki sızıntı hiç ölçülmemişti. Aşağıdaki dört
// kabul kriteri kartın kendisinden geliyor:
//
//   * duplicate mutation 0
//   * gecikmiş "sonradan çıkmış" görünüm 0
//   * muted nudge bypass 0
//   * kavramlar arası istenmeyen yan etki 0
//
// Sunucu karşılığı: `supabase/tests/036_group_departure_matrix.test.sql`.
// İki uç arasında sözleşme testi olmadan ölen özellikler yaşandı (WP-373),
// bu yüzden buradaki her satırın SQL tarafında bir eşi vardır.
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_chat_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';

Profile _p(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026));

final _owner = _p('owner', 'Sahip');
final _member = _p('member', 'Üye');
final _other = _p('other', 'Ucuncu');

/// Ağ hatasını taklit eden sarmalayıcı: ilk [failures] çağrı patlar, sonrası
/// gerçek işi yapar. Çağrı ve komut anahtarı sayısı dışarıdan okunabilir.
class _FlakyGroupRepository extends InMemoryGroupRepository {
  _FlakyGroupRepository({this.failures = 0});

  int failures;
  int leaveCalls = 0;
  final List<String> commandIds = [];

  @override
  Future<GroupLeaveOutcome> leaveGroup(
    String groupId,
    String userId, {
    required String commandId,
  }) async {
    leaveCalls++;
    commandIds.add(commandId);
    if (leaveCalls <= failures) {
      throw const GroupException('Bağlantı kurulamadı.');
    }
    return super.leaveGroup(groupId, userId, commandId: commandId);
  }
}

void main() {
  late InMemoryGroupRepository groups;
  late StudyGroup club;

  Future<void> seed(InMemoryGroupRepository repo) async {
    groups = repo;
    club = await repo.createGroup(name: 'Matris', creator: _owner);
    await repo.joinGroup(inviteCode: club.inviteCode, member: _member);
    await repo.joinGroup(inviteCode: club.inviteCode, member: _other);
  }

  setUp(() async => seed(InMemoryGroupRepository()));

  Future<List<String>> memberIds() async =>
      (await groups.watchMembers(club.id).first)
          .map((m) => m.id)
          .toList(growable: false);

  group('yarış koşulu: duplicate mutation 0', () {
    test('20 EŞZAMANLI tap tek üyelik mutasyonu bırakır', () async {
      // WP-445 testi tapleri SIRAYLA atıyordu; sıralı çağrıda ikinci istek
      // birincinin yazdığı anahtarı zaten görür. Gerçek çift tapte istekler
      // iç içe geçer: hepsi `await`ten önce aynı boş komut tablosunu görür.
      final outcomes = await Future.wait([
        for (var i = 0; i < 20; i++)
          groups.leaveGroup(club.id, _member.id, commandId: 'cmd-race'),
      ]);

      // Sunucuda advisory lock 20 çağrıyı sıraya sokar; 19'u replay dalından
      // ilk sonucu alır. Hiçbiri hata döndürmez.
      expect(outcomes, everyElement(GroupLeaveOutcome.left));
      // Ölçülen şey dönen değer değil, DURUM: üye tam olarak bir kez gitti ve
      // kalan iki üyeye dokunulmadı.
      expect(await memberIds(), unorderedEquals([_owner.id, _other.id]));
    });

    test('çevrimdışı hata sonrası AYNI anahtarla retry tek çıkış üretir', () async {
      final flaky = _FlakyGroupRepository(failures: 2);
      await seed(flaky);

      const commandId = 'cmd-offline';
      var attempts = 0;
      GroupLeaveOutcome? outcome;
      while (outcome == null && attempts < 5) {
        attempts++;
        try {
          outcome = await flaky.leaveGroup(
            club.id,
            _member.id,
            commandId: commandId,
          );
        } on GroupException {
          // Kullanıcı hareketi tek; retry aynı anahtarı taşır.
        }
      }

      expect(outcome, GroupLeaveOutcome.left);
      expect(flaky.leaveCalls, 3, reason: 'iki hata + bir başarı');
      expect(
        flaky.commandIds.toSet(),
        {commandId},
        reason: 'retry yeni anahtar üretirse sunucu iki ayrı komut görür',
      );
      expect(await memberIds(), unorderedEquals([_owner.id, _other.id]));
    });

    test('hata anahtarı tüketmez: başarısız denemeden sonra çıkış hâlâ mümkün', () async {
      final flaky = _FlakyGroupRepository(failures: 1);
      await seed(flaky);

      await expectLater(
        flaky.leaveGroup(club.id, _member.id, commandId: 'cmd-burn'),
        throwsA(isA<GroupException>()),
      );
      // Anahtar "işlenmiş" sayılsaydı retry sessizce alreadyLeft döner ve
      // kullanıcı hiç çıkmamış olurdu — sessiz veri kaybı.
      expect(
        await flaky.leaveGroup(club.id, _member.id, commandId: 'cmd-burn'),
        GroupLeaveOutcome.left,
      );
      expect(await memberIds(), unorderedEquals([_owner.id, _other.id]));
    });
  });

  group('iki cihaz: gecikmiş "sonradan çıkmış" görünümü 0', () {
    test('A cihazı çıkınca B cihazının canlı akışı restart beklemeden düzelir', () async {
      // İkinci abonelik = ikinci cihaz. B, A'nın hareketinden ÖNCE dinlemeye
      // başlar; ölçülen şey "yeniden okuyunca doğru" değil, "haber kendiliğinden
      // geldi mi".
      final seen = <List<String>>[];
      final deviceB = groups
          .watchUserGroups(_member.id)
          .listen((list) => seen.add(list.map((g) => g.id).toList()));
      addTearDown(deviceB.cancel);

      await pumpEventQueue();
      expect(seen.last, contains(club.id));
      final beforeLeave = seen.length;

      await groups.leaveGroup(club.id, _member.id, commandId: 'cmd-a');
      await pumpEventQueue();

      expect(
        seen.length,
        greaterThan(beforeLeave),
        reason: 'B cihazına yeni bir değer İTİLMELİ; sessiz kalırsa kullanıcı '
            'app restart edene kadar çıktığı grubu görmeye devam eder',
      );
      expect(
        seen.last,
        isNot(contains(club.id)),
        reason: 'grup app restart beklemeden kaybolmalı',
      );
    });

    test('B cihazının geç gelen çıkışı FARKLI anahtarla sahte hata üretmez', () async {
      await groups.leaveGroup(club.id, _member.id, commandId: 'cmd-a');

      // B cihazı A'nın çıkışını henüz görmemiştir; kendi anahtarını üretir.
      expect(
        await groups.leaveGroup(club.id, _member.id, commandId: 'cmd-b'),
        GroupLeaveOutcome.alreadyLeft,
      );
      expect(await memberIds(), unorderedEquals([_owner.id, _other.id]));
    });
  });

  group('sahiplik değişmezi her çıkış yolunda', () {
    test('sahip leaveGroup ile çıkamaz', () async {
      await expectLater(
        groups.leaveGroup(club.id, _owner.id, commandId: 'cmd-owner'),
        throwsA(isA<GroupOwnerCannotLeaveException>()),
      );
    });

    test('sahip removeMember (kick) yolundan da çıkarılamaz', () async {
      // 🔴 v57 bulgusu: `leaveGroup` sahibi reddediyordu, kick yolu hiçbir şey
      // sormuyordu. Sunucuda da aynıydı — `0108` RPC'yi kapatmış, doğrudan
      // `group_members` UPDATE kapısını (`0008` politikası) açık bırakmıştı.
      // Sahipsiz grupta davet kodu yenilenemez, üye çıkarılamaz, grup silinemez.
      await expectLater(
        groups.removeMember(club.id, _owner.id),
        throwsA(isA<GroupOwnerCannotLeaveException>()),
      );
      expect(await memberIds(), contains(_owner.id));
    });

    test('sahip banMember yolundan da çıkarılamaz', () async {
      await expectLater(
        groups.banMember(club.id, _owner.id),
        throwsA(isA<GroupException>()),
      );
      expect(await memberIds(), contains(_owner.id));
      expect(await groups.listBannedMembers(club.id), isEmpty);
    });
  });

  group('primary group çıkıştan sonra askıda kalmaz', () {
    test('birincil gruptan çıkınca tercih o grubu göstermeye devam etmez', () async {
      final second = await groups.createGroup(name: 'İkinci', creator: _other);
      await groups.joinGroup(inviteCode: second.inviteCode, member: _member);

      final before = await groups.watchPrimaryGroupPreference(_member.id).first;
      final pinned = await groups.setPrimaryGroup(
        userId: _member.id,
        groupId: club.id,
        expectedRevision: before.selectionRevision,
      );
      expect(pinned.primaryGroupId, club.id);

      await groups.leaveGroup(club.id, _member.id, commandId: 'cmd-primary');

      final after = await groups.watchPrimaryGroupPreference(_member.id).first;
      expect(
        after.primaryGroupId,
        isNot(club.id),
        reason: 'çıkılan grup birincil kalırsa ana ekran ölü gruba bakar',
      );
      expect(
        after.selectionRevision,
        greaterThan(pinned.selectionRevision),
        reason: 'revision artmazsa eski CAS yazması sessizce kabul edilir',
      );
    });

    test('çıkıştan önceki revision ile yapılan CAS yazması reddedilir', () async {
      final second = await groups.createGroup(name: 'İkinci', creator: _other);
      await groups.joinGroup(inviteCode: second.inviteCode, member: _member);
      final stale = await groups.watchPrimaryGroupPreference(_member.id).first;

      await groups.leaveGroup(club.id, _member.id, commandId: 'cmd-stale');

      await expectLater(
        groups.setPrimaryGroup(
          userId: _member.id,
          groupId: club.id,
          expectedRevision: stale.selectionRevision,
        ),
        throwsA(isA<GroupException>()),
      );
    });
  });

  group('kavramlar arası yan etki 0', () {
    late InMemoryModerationRepository moderation;
    late InMemoryNudgeRepository nudges;
    late InMemoryChatRepository chat;

    setUp(() {
      moderation = InMemoryModerationRepository();
      nudges = InMemoryNudgeRepository(currentUserId: _owner.id);
      chat = InMemoryChatRepository();
      addTearDown(nudges.dispose);
      addTearDown(chat.dispose);
    });

    test('grup yasağı kişisel engelleme ya da dürtme susturması YARATMAZ', () async {
      await groups.banMember(club.id, _member.id);

      expect(await groups.listBannedMembers(club.id), hasLength(1));
      expect(
        await moderation.listBlockedUserIds(),
        isEmpty,
        reason: 'grup yasağı hesap-kapsamlı engel değildir',
      );
      expect(
        await nudges.listMutedNudgeSenderIds(),
        isEmpty,
        reason: 'grup yasağı dürtme tercihine dokunmaz',
      );
    });

    test('kişiyi engellemek grup üyeliğini ya da grup yasağını değiştirmez', () async {
      await moderation.blockUser(_member.id);

      expect(await moderation.listBlockedUserIds(), [_member.id]);
      expect(
        await memberIds(),
        containsAll([_owner.id, _member.id, _other.id]),
        reason: 'engelleme yalnız görünürlüktür, üyelik kaydı değil',
      );
      expect(await groups.listBannedMembers(club.id), isEmpty);
    });

    test('dürtme susturması sohbeti ve üyeliği etkilemez', () async {
      await nudges.muteNudgesFrom(_member.id);
      await chat.sendMessage(groupId: club.id, sender: _member, text: 'Selam');

      final messages = await chat.watchGroupMessages(club.id).first;
      expect(
        messages.map((m) => m.userId),
        contains(_member.id),
        reason: 'susturma dürtmeye özeldir; mesajı gizleyen engellemedir',
      );
      expect(await memberIds(), contains(_member.id));
      expect(await moderation.listBlockedUserIds(), isEmpty);
    });

    test('mesajı raporlamak engelleme, susturma ya da çıkarma tetiklemez', () async {
      await moderation.reportUgc(
        target: ReportTarget.message(
          messageId: 'msg-1',
          groupId: club.id,
          hint: 'Selam',
        ),
        reason: 'spam',
      );

      expect(moderation.reports, hasLength(1));
      expect(await moderation.listBlockedUserIds(), isEmpty);
      expect(await nudges.listMutedNudgeSenderIds(), isEmpty);
      expect(await memberIds(), contains(_member.id));
      expect(await groups.listBannedMembers(club.id), isEmpty);
    });
  });

  group('muted nudge bypass 0', () {
    test('susturma hesap kapsamlıdır: ikinci grup üzerinden sızmaz', () async {
      final nudges = InMemoryNudgeRepository(currentUserId: _owner.id);
      addTearDown(nudges.dispose);
      await nudges.muteNudgesFrom(_member.id);

      // Aynı kişi, BAŞKA bir grup. Susturma grup değil hesap tercihidir.
      await nudges.sendNudge(
        groupId: 'baska-grup',
        sender: _member,
        recipient: _owner,
      );
      // Susturulmamış üçüncü kişi aynı gruptan geçebilmeli — aksi hâlde iddia
      // "hiç dürtme düşmüyor" diye boşa geçerdi.
      await nudges.sendNudge(
        groupId: 'baska-grup',
        sender: _other,
        recipient: _owner,
      );

      final received = await nudges.watchReceivedNudges(_owner.id).first;
      expect(received.map((n) => n.senderId), [_other.id]);
    });

    test('gruptan çıkıp yeniden katılmak susturmayı sıfırlamaz', () async {
      final nudges = InMemoryNudgeRepository(currentUserId: _owner.id);
      addTearDown(nudges.dispose);
      await nudges.muteNudgesFrom(_member.id);

      await groups.leaveGroup(club.id, _member.id, commandId: 'cmd-rejoin');
      await groups.joinGroup(inviteCode: club.inviteCode, member: _member);
      expect(await memberIds(), contains(_member.id));

      await nudges.sendNudge(
        groupId: club.id,
        sender: _member,
        recipient: _owner,
      );
      expect(
        await nudges.watchReceivedNudges(_owner.id).first,
        isEmpty,
        reason: 'üyelik döngüsü susturmayı temizlerse bypass açılır',
      );
      expect(await nudges.listMutedNudgeSenderIds(), [_member.id]);
    });
  });

  group('restart: yeniden abone olan istemci aynı durumu görür', () {
    test('çıkış, yasak ve üye listesi yeni aboneliklerde tutarlı', () async {
      await groups.leaveGroup(club.id, _member.id, commandId: 'cmd-restart');
      await groups.banMember(club.id, _other.id);

      // "Restart" = tüm akışların ilk değerini yeniden okumak. Kalıcı olan
      // durum ile ilk yayılan değer ayrışırsa kullanıcı eski grubu bir an için
      // yeniden görür (WP-447 kabul: gecikmiş görünüm 0).
      expect(await memberIds(), [_owner.id]);
      expect(await groups.watchUserGroups(_member.id).first, isEmpty);
      expect(await groups.watchUserGroups(_other.id).first, isEmpty);
      expect(
        (await groups.listBannedMembers(club.id)).map((p) => p.id),
        [_other.id],
      );
      // Çıkan kişi davet koduyla dönebilir; yasaklı dönemez.
      await groups.joinGroup(inviteCode: club.inviteCode, member: _member);
      await expectLater(
        groups.joinGroup(inviteCode: club.inviteCode, member: _other),
        throwsA(isA<GroupException>()),
      );
    });
  });
}
