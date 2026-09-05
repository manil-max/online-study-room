// WP-780 — vaka yazismasinin VERI YOLU.
//
// `admin_case_conversations_page.dart` WP-778'de yazildi ve kendi testleri
// yesildi, ama sayfanin zorunlu `CaseConversationGateway` parametresinin
// GERCEK bir uygulamasi depoda yoktu. Yani ozellik mevcut degildi: bu deponun
// kayitli kusuru olan "bitmis arka uc, baglanmamis on uc".
//
// Bu dosya o dikisi iki yerden birden olcer:
//
//   1. **Davranis** — bellek ici depo uzerinden kanal okunur, mesaj gonderilir
//      ve EK ile gonderilen mesajin ek yolunun gercekten tasindigi olculur.
//      Saglayicinin depoya bagli oldugu ayrica olculur; bagli olmayan bir
//      saglayici tam da "yazildi ama yok" halidir.
//   2. **Iki uclu sozlesme** — istemcinin CAGIRDIGI RPC adlari ve parametre
//      adlari, `0138` migration dosyasinda GERCEKTEN tanimli olanlarla
//      karsilastirilir. Ad uyusmazsa uygulama calisma aninda sessizce patlar
//      ve davranis testleri (sahte depo uzerinden kostugu icin) yesil kalir.
//
// 🔴 Sozlesme kapisinin kendisi de kasten bozuk girdiyle sinanir
// (`sozlesme kapisi bozuk girdide KIRMIZI verir` grubu): karsilastirmayi yapan
// yardimcilar, uydurma ama BOZUK bir istemci/SQL cifti uzerinde uyusmazligi
// gorebiliyor mu? Goremiyorsa kapi yesil yanar ama hicbir sey olcmez.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket_message.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/repositories/supabase/report_attachment_upload.dart';

const _admin = 'admin';
const _reportId = 'report-1';

/// 1x1 saydam PNG — gercek goruntu bayti.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
  'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Sikayet EDEN kanali: `report_ugc` ayna bileti actigi icin `ticketId` VAR.
const _reporterChannel = CaseConversationChannel(
  party: CaseConversationParty.reporter,
  userId: 'u-reporter',
  displayName: 'Ayse',
  ticketId: 't-reporter',
);

/// Sikayet EDILEN kanali: kanal TEMBEL, `ticketId` yok.
const _reportedChannel = CaseConversationChannel(
  party: CaseConversationParty.reported,
  userId: 'u-reported',
  displayName: 'Mehmet',
);

InMemoryAdminRepository _seededRepo() {
  final repo = InMemoryAdminRepository(superAdminUserIds: const {_admin});
  addTearDown(repo.dispose);
  repo.seedCaseConversationChannels(_reportId, const [
    _reporterChannel,
    _reportedChannel,
  ]);
  return repo;
}

/// Sikayet edenin ayna bileti sunucuda zaten vardir; sahtede de olmali ki
/// `fetchTicketMessages` o kanali okuyabilsin.
Future<void> _seedReporterTicket(InMemoryAdminRepository repo) async {
  await repo.sendCaseMessage(
    userId: _admin,
    reportId: _reportId,
    party: CaseConversationParty.reporter,
    message: 'ilk temas',
  );
}

Profile _profile(String id) =>
    Profile(id: id, displayName: id, createdAt: DateTime(2026));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bellek ici veri yolu', () {
    test('kanal listesi iki tarafi da doner; tembel kanalin bileti yok', () async {
      final repo = _seededRepo();

      final channels = await repo.fetchCaseConversationChannels(
        userId: _admin,
        reportId: _reportId,
      );

      expect(channels, hasLength(2));
      expect(channels.first.party, CaseConversationParty.reporter);
      expect(channels.first.ticketId, 't-reporter');
      expect(channels.last.party, CaseConversationParty.reported);
      expect(
        channels.last.ticketId,
        isNull,
        reason: 'Sikayet edilen kanali ilk mesaja kadar acilmaz.',
      );
      expect(channels.last.displayName, 'Mehmet');
    });

    test('tohumlanmamis vaka bos liste doner, cokmez', () async {
      final repo = _seededRepo();
      expect(
        await repo.fetchCaseConversationChannels(
          userId: _admin,
          reportId: 'baska-vaka',
        ),
        isEmpty,
      );
    });

    test('yonetici olmayan kanal listesini okuyamaz', () async {
      final repo = _seededRepo();
      expect(
        () => repo.fetchCaseConversationChannels(
          userId: 'u-reporter',
          reportId: _reportId,
        ),
        throwsA(isA<AdminException>()),
      );
    });

    test('tembel kanala ilk mesaj kanali acar ve bilet kimligini geri verir', () async {
      final repo = _seededRepo();

      final sent = await repo.sendCaseMessage(
        userId: _admin,
        reportId: _reportId,
        party: CaseConversationParty.reported,
        message: 'Moderasyon ekibi hakkinda bir sey soracak.',
      );

      expect(sent.ticketId, isNotEmpty);
      expect(sent.senderRole, FeedbackTicketSenderRole.admin);
      expect(sent.messageSeq, 1);

      // 🔴 Kanal listesi YERINDE guncellenmeli: cagiran eski (ticketId == null)
      // tarafla okumaya devam ederse yeni acilan kanal ekranda BOS gorunur.
      final channels = await repo.fetchCaseConversationChannels(
        userId: _admin,
        reportId: _reportId,
      );
      expect(channels.last.ticketId, sent.ticketId);

      final history = await repo.fetchTicketMessages(
        userId: _admin,
        ticketId: sent.ticketId,
      );
      expect(history.single.message, 'Moderasyon ekibi hakkinda bir sey soracak.');
    });

    test('acilmis kanalda mesajlar sirayla birikir', () async {
      final repo = _seededRepo();
      await _seedReporterTicket(repo);

      final second = await repo.sendCaseMessage(
        userId: _admin,
        reportId: _reportId,
        party: CaseConversationParty.reporter,
        message: 'ikinci mesaj',
      );

      final history = await repo.fetchTicketMessages(
        userId: _admin,
        ticketId: second.ticketId,
      );
      expect(history.map((m) => m.message), ['ilk temas', 'ikinci mesaj']);
      expect(history.map((m) => m.messageSeq), [1, 2]);
    });

    test('EK ile gonderilen mesajin ek yolu GERCEKTEN tasinir', () async {
      final repo = _seededRepo();
      await _seedReporterTicket(repo);

      final sent = await repo.sendCaseMessage(
        userId: _admin,
        reportId: _reportId,
        party: CaseConversationParty.reporter,
        message: 'ekli mesaj',
        attachmentBytes: _png,
        attachmentExt: 'png',
      );

      // 1) Donen satirda yol var ve sunucunun bekledigi `<uid>/<uuid>.<ext>`
      //    bicimini tasiyor (`0138` `assert_ticket_message_attachment_allowed`
      //    ilk klasoru `auth.uid()` ile karsilastirir).
      final path = sent.attachmentPath;
      expect(path, isNotNull);
      expect(path!.split('/').first, _admin);
      expect(path.endsWith('.png'), isTrue);

      // 2) Yol GERI OKUNAN satirda da duruyor — donus degeri dogru olup
      //    kaydin bos kalmasi bu depoda gorulmus bir kusur sinifidir.
      final history = await repo.fetchTicketMessages(
        userId: _admin,
        ticketId: sent.ticketId,
      );
      expect(history.last.attachmentPath, path);

      // 3) Baytlar gercekten yuklendi ve yol imzalanabiliyor.
      expect(repo.ticketMessageAttachments[path], _png);
      expect(await repo.getTicketMessageAttachmentUrl(path), isNotNull);
    });

    test('eksiz mesaj ek yolu tasimaz; bilinmeyen yol imzalanmaz', () async {
      final repo = _seededRepo();
      await _seedReporterTicket(repo);

      final sent = await repo.sendCaseMessage(
        userId: _admin,
        reportId: _reportId,
        party: CaseConversationParty.reporter,
        message: 'eksiz',
      );

      expect(sent.attachmentPath, isNull);
      expect(repo.ticketMessageAttachments, isEmpty);
      expect(
        await repo.getTicketMessageAttachmentUrl('$_admin/yok.png'),
        isNull,
      );
    });

    test('ayni komut kimligi ikinci kanal/mesaj uretmez', () async {
      final repo = _seededRepo();

      final first = await repo.sendCaseMessage(
        userId: _admin,
        reportId: _reportId,
        party: CaseConversationParty.reported,
        message: 'tek sefer',
        clientMessageId: 'cmd-1',
      );
      final replay = await repo.sendCaseMessage(
        userId: _admin,
        reportId: _reportId,
        party: CaseConversationParty.reported,
        message: 'tek sefer',
        clientMessageId: 'cmd-1',
      );

      expect(replay.id, first.id);
      final history = await repo.fetchTicketMessages(
        userId: _admin,
        ticketId: first.ticketId,
      );
      expect(history, hasLength(1));
    });

    test('yonetici olmayan taraf kanalina yazamaz', () async {
      final repo = _seededRepo();
      expect(
        () => repo.sendCaseMessage(
          userId: 'u-reporter',
          reportId: _reportId,
          party: CaseConversationParty.reporter,
          message: 'izinsiz',
        ),
        throwsA(isA<AdminException>()),
      );
    });
  });

  group('saglayici depoya bagli', () {
    test('adminCaseConversationChannelsProvider kanallari okur', () async {
      final repo = _seededRepo();
      final container = ProviderContainer(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_profile(_admin)),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Riverpod 3 tuzagi: dinleyicisiz saglayici her `read`de yeniden kurulur.
      final sub = container.listen(
        adminCaseConversationChannelsProvider(_reportId),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(authStateProvider.future);

      final channels = await container.read(
        adminCaseConversationChannelsProvider(_reportId).future,
      );

      expect(channels.map((c) => c.party), [
        CaseConversationParty.reporter,
        CaseConversationParty.reported,
      ]);
    });
  });

  group('0138 sozlesmesi — istemcinin cagirdigi ad sunucuda VAR', () {
    final migration = _stripSqlComments(
      File(
        '../supabase/migrations/0138_case_conversation_and_message_photo.sql',
      ).readAsStringSync(),
    );
    final client = File(
      'lib/data/repositories/supabase/supabase_admin_repository.dart',
    ).readAsStringSync();

    test('admin_case_conversation_channels: parametre adlari birebir', () {
      expect(
        _sqlFunctionParams(migration, 'admin_case_conversation_channels'),
        _clientRpcParams(client, 'admin_case_conversation_channels'),
      );
    });

    test('admin_send_case_message: parametre adlari birebir', () {
      // 🔴 Kume esitligi iki yonu birden kapatir: istemci var olmayan bir
      // parametre gonderirse de, sunucunun bekledigi bir parametreyi hic
      // gondermezse de kirmizi olur.
      expect(
        _sqlFunctionParams(migration, 'admin_send_case_message'),
        _clientRpcParams(client, 'admin_send_case_message'),
      );
    });

    test('kanal satirinin kolon adlari modelin okudugu adlar', () {
      // Sunucunun `returns table (...)` bloku.
      final columns = _sqlReturnsTableColumns(
        migration,
        'admin_case_conversation_channels',
      );
      expect(columns, {'party', 'user_id', 'display_name', 'ticket_id'});

      // Ayni adlarla kurulan wire satiri model tarafinda gercekten cozuluyor.
      final channel = CaseConversationChannel.fromMap(const {
        'party': 'reported',
        'user_id': 'u-reported',
        'display_name': 'Mehmet',
        'ticket_id': 't-reported',
      });
      expect(channel.party, CaseConversationParty.reported);
      expect(channel.userId, 'u-reported');
      expect(channel.displayName, 'Mehmet');
      expect(channel.ticketId, 't-reported');
    });

    test('taraf degerleri sunucunun kabul ettikleri', () {
      expect(CaseConversationParty.reporter.dbValue, 'reporter');
      expect(CaseConversationParty.reported.dbValue, 'reported');
      expect(
        migration.contains("case_party in ('reporter', 'reported')"),
        isTrue,
      );
      expect(
        migration.contains("p_party not in ('reporter', 'reported')"),
        isTrue,
      );
    });

    test('bucket adi 0138 ile BIREBIR ayni', () {
      expect(kTicketMessageAttachmentBucket, 'ticket_message_attachments');
      // Bucket kaydi, iki storage politikasi ve sunucu kapisi ayni adi kullanir.
      expect(
        "'$kTicketMessageAttachmentBucket'".allMatches(migration).length,
        greaterThanOrEqualTo(4),
        reason:
            'Yukleme bir bucket, okuma politikasi baskasi olursa foto sessizce '
            'gorunmez kalir.',
      );
      expect(
        migration.contains("bucket_id = '$kTicketMessageAttachmentBucket'"),
        isTrue,
      );
      // 🔴 Delil bucket'i (`0096`) yazisma bucket'i DEGILDIR.
      expect(kTicketMessageAttachmentBucket, isNot(kReportAttachmentBucket));
    });

    test('eski cagiranlarin bucket varsayilani degismedi', () {
      final upload = File(
        'lib/data/repositories/supabase/report_attachment_upload.dart',
      ).readAsStringSync();
      expect(
        upload.contains('String bucket = kReportAttachmentBucket'),
        isTrue,
        reason:
            'Varsayilan degisirse sikayet ve destek sorusu ekleri sessizce '
            'baska bucket a giderdi.',
      );
    });

    test('sunucudaki foto kapisi hala yerinde', () {
      // Istemci sinirlari kozmetiktir; asil kapi sunucudadir.
      expect(
        migration.contains('assert_ticket_message_attachment_allowed'),
        isTrue,
      );
      expect(migration.contains('5242880'), isTrue);
      expect(migration.contains('is_super_admin()'), isTrue);
    });
  });

  group('sozlesme kapisi bozuk girdide KIRMIZI verir', () {
    // 🔴 Yukaridaki kume karsilastirmasi, yardimcilar bir sey BULAMAZSA da
    // (iki bos kume) yesil yanardi. Bu grup, yardimcilarin uydurma ama bozuk
    // bir cift uzerinde uyusmazligi gercekten gordugunu olcer.
    const sql = '''
create or replace function public.fake_rpc(
  p_report_id uuid,
  p_party text,
  p_message text default null
)
returns table (
  party text,
  ticket_id uuid
)
language sql
as \$\$ select 1 \$\$;
''';
    const dart = '''
      final row = await _client.rpc(
        'fake_rpc',
        params: {
          'p_report_id': reportId,
          'p_party': party.dbValue,
          'p_message': normalized,
        },
      );
''';

    test('saglam cift esittir', () {
      expect(_sqlFunctionParams(sql, 'fake_rpc'), {
        'p_report_id',
        'p_party',
        'p_message',
      });
      expect(_clientRpcParams(dart, 'fake_rpc'), {
        'p_report_id',
        'p_party',
        'p_message',
      });
      expect(_sqlFunctionParams(sql, 'fake_rpc'), _clientRpcParams(dart, 'fake_rpc'));
    });

    test('istemci tarafinda tek harf bozulunca esitlik duser', () {
      final bozuk = dart.replaceFirst("'p_party'", "'p_partyy'");
      expect(
        _sqlFunctionParams(sql, 'fake_rpc'),
        isNot(_clientRpcParams(bozuk, 'fake_rpc')),
      );
    });

    test('sunucu tarafinda tek harf bozulunca esitlik duser', () {
      final bozuk = sql.replaceFirst('p_message text', 'p_mesaj text');
      expect(
        _sqlFunctionParams(bozuk, 'fake_rpc'),
        isNot(_clientRpcParams(dart, 'fake_rpc')),
      );
    });

    test('kolon adi bozulunca kolon kumesi degisir', () {
      final bozuk = sql.replaceFirst('ticket_id uuid', 'bilet_id uuid');
      expect(_sqlReturnsTableColumns(bozuk, 'fake_rpc'), {'party', 'bilet_id'});
    });

    test('adi olmayan RPC sessizce bos kume dondurmez', () {
      expect(() => _sqlFunctionParams(sql, 'yok_boyle_rpc'), throwsStateError);
      expect(() => _clientRpcParams(dart, 'yok_boyle_rpc'), throwsStateError);
    });
  });
}

/// Tam satir SQL yorumlarini atar.
///
/// 🔴 WP-777'nin dersi: `0138`in basindaki karar blogu RPC ve parametre
/// adlarini bol bol geciyor. Ham metinde arayan bir iddia yorumu "tanim" sanip
/// yanlis YESIL verir.
String _stripSqlComments(String sql) => sql
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('--'))
    .join('\n');

/// `create [or replace] function public.<ad>(...)` imzasindaki parametre adlari.
Set<String> _sqlFunctionParams(String sql, String name) {
  final match = RegExp(
    'create (?:or replace )?function public\\.$name\\s*\\(([^)]*)\\)',
  ).firstMatch(sql);
  if (match == null) {
    throw StateError('0138 icinde `$name` fonksiyon tanimi yok.');
  }
  return RegExp(
    r'^\s*(p_[a-z_]+)\s',
    multiLine: true,
  ).allMatches(match.group(1)!).map((m) => m.group(1)!).toSet();
}

/// `returns table (...)` blogundaki kolon adlari.
Set<String> _sqlReturnsTableColumns(String sql, String name) {
  final createAt = sql.indexOf('function public.$name');
  if (createAt < 0) {
    throw StateError('0138 icinde `$name` fonksiyon tanimi yok.');
  }
  final match = RegExp(
    r'returns table\s*\(([^)]*)\)',
  ).firstMatch(sql.substring(createAt));
  if (match == null) {
    throw StateError('`$name` bir tablo dondurmuyor.');
  }
  return RegExp(
    r'^\s*([a-z_]+)\s',
    multiLine: true,
  ).allMatches(match.group(1)!).map((m) => m.group(1)!).toSet();
}

/// Istemcinin `_client.rpc('<ad>', params: {...})` cagrisinda GONDERDIGI
/// parametre adlari.
Set<String> _clientRpcParams(String dart, String name) {
  final nameAt = dart.indexOf("'$name'");
  if (nameAt < 0) {
    throw StateError('Istemci `$name` RPC sini hic cagirmiyor.');
  }
  final paramsAt = dart.indexOf('params: {', nameAt);
  if (paramsAt < 0 || paramsAt - nameAt > 200) {
    throw StateError('`$name` cagrisinin params blogu bulunamadi.');
  }
  var depth = 0;
  var index = dart.indexOf('{', paramsAt);
  final start = index;
  for (; index < dart.length; index++) {
    final char = dart[index];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) break;
    }
  }
  final block = dart.substring(start, index + 1);
  return RegExp(
    r"'(p_[a-z_]+)'\s*:",
  ).allMatches(block).map((m) => m.group(1)!).toSet();
}
