// WP-446: kavram ayrımı ve raporlamanın keşfedilebilirliği.
//
// Kart üç şey istiyor ve üçü de burada bağlanıyor:
//   1. davet kodu yinelenmez → tek kanonik yer `ClassDetailScreen`;
//   2. rapor yalnız uzun basmanın arkasında olmaz → görünür 48 dp hedef;
//   3. her eylem KAPSAMINI açıklar → çıkarma ≠ yasak ≠ kişiyi engelleme.
//
// (3) bir kozmetik ayar değil. Yasak düğmesi `safetyBlock` ("Kişiyi engelle")
// metnini kullanıyor, onay diyaloğu da çıkarmayla birebir aynı cümleyi
// gösteriyordu; yönetici "engelliyorum" sanıp geri dönüşü olmayan bir grup
// yasağı koyabiliyordu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/chat_message.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/chat_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_chat_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

final _owner = Profile(
  id: 'owner-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);
final _peer = Profile(
  id: 'peer-1',
  displayName: 'Komsu',
  createdAt: DateTime(2026, 1, 1),
);

final _other = Profile(
  id: 'other-1',
  displayName: 'Ucuncu',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'group-1',
  name: 'Odak Grubu',
  inviteCode: 'KAMP42',
  createdBy: _owner.id,
  createdAt: DateTime(2026, 1, 1),
);

Widget _wrap(Widget child, {required List<dynamic> overrides}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Sohbet kartını, karşı taraftan gelmiş tek mesajla kurar.
Widget _chatHarness() {
  final message = ChatMessage(
    id: 'msg-1',
    groupId: _group.id,
    userId: _peer.id,
    body: 'Merhaba',
    createdAt: DateTime.utc(2026, 1, 1, 9),
    authorDisplayName: _peer.displayName,
  );
  return _wrap(
    ClassChatCard(group: _group),
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_owner)),
      classMessagesProvider(_group.id).overrideWith(
        (ref) => Stream.value([message]),
      ),
      chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
      // WP-538: sohbet, engelli kullanici kumesi BILINMEDEN mesaj cizmez
      // (fail-closed). Kapi `--dart-define-from-file=env.json` ile kostugu
      // icin varsayilan depo Supabase olur ve testte hic cozulmez.
      moderationRepositoryProvider.overrideWithValue(
        InMemoryModerationRepository(),
      ),
    ],
  );
}

/// Detay ekranini GERCEK uye listesiyle kurar.
///
/// 🔴 Uye satiri olmadan "yasak dugmesi su metni kullanmiyor" iddiasi bosuna
/// gecerdi: bakilan agacta hic dugme bulunmaz. Bu yuzden grup in-memory
/// repository'de gercekten olusturulur ve ikinci bir uye katilir; testler once
/// dugmelerin VAR oldugunu, sonra hangi metni tasidiklarini olcer.
Future<Widget> _detailHarness({required Profile viewer}) async {
  final repo = InMemoryGroupRepository();
  final group = await repo.createGroup(name: 'Odak Grubu', creator: _owner);
  await repo.joinGroup(inviteCode: group.inviteCode, member: _peer);
  await repo.joinGroup(inviteCode: group.inviteCode, member: _other);

  return ProviderScope(
    overrides: [
      groupRepositoryProvider.overrideWithValue(repo),
      authStateProvider.overrideWith((ref) => Stream.value(viewer)),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ClassDetailScreen(group: group),
    ),
  );
}

void main() {
  group('davet kodu tek kanonik yerde', () {
    testWidgets('detay ekranı kodu ve yenileme eylemini taşır', (tester) async {
      await tester.pumpWidget(await _detailHarness(viewer: _owner));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Kopyala'), findsOneWidget);
      // Yenileme yalnız burada var; ikinci kopyanın taşımadığı eylem buydu.
      expect(find.byTooltip('Kodu yenile'), findsOneWidget);
    });
  });

  group('sohbette rapor keşfedilebilir', () {
    testWidgets('başkasının mesajında görünür eylem düğmesi var', (
      tester,
    ) async {
      await tester.pumpWidget(_chatHarness());
      await tester.pump();

      final button = find.byTooltip('Mesaj seçenekleri');
      expect(
        button,
        findsOneWidget,
        reason: 'rapor yalnız uzun basmanın arkasında kalamaz',
      );

      // Dokunma hedefi erişilebilirlik alt sınırını karşılamalı.
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('düğme rapor/engelle sayfasını kapsam metniyle açar', (
      tester,
    ) async {
      await tester.pumpWidget(_chatHarness());
      await tester.pump();

      await tester.tap(find.byTooltip('Mesaj seçenekleri'));
      await tester.pumpAndSettle();

      expect(find.text('Bildir'), findsOneWidget);
      expect(find.text('Engelle'), findsOneWidget);
      // İki eylemin kapsamı ekranda yazılı; kullanıcı hangisinin karşı tarafa
      // gittiğini tahmin etmek zorunda değil.
      expect(
        find.textContaining('yöneticilere gider'),
        findsOneWidget,
        reason: 'şikâyetin kapsamı açıklanmalı',
      );
      expect(
        find.textContaining('Yalnız sizin için'),
        findsOneWidget,
        reason: 'engellemenin kapsamı açıklanmalı',
      );
    });

    testWidgets('kendi mesajımda eylem düğmesi çıkmaz', (tester) async {
      final mine = ChatMessage(
        id: 'msg-mine',
        groupId: _group.id,
        userId: _owner.id,
        body: 'Benim mesajım',
        createdAt: DateTime.utc(2026, 1, 1, 9),
        authorDisplayName: _owner.displayName,
      );
      await tester.pumpWidget(
        _wrap(
          ClassChatCard(group: _group),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(_owner)),
            classMessagesProvider(
              _group.id,
            ).overrideWith((ref) => Stream.value([mine])),
            chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
      // WP-538: sohbet, engelli kullanici kumesi BILINMEDEN mesaj cizmez
      // (fail-closed). Kapi `--dart-define-from-file=env.json` ile kostugu
      // icin varsayilan depo Supabase olur ve testte hic cozulmez.
      moderationRepositoryProvider.overrideWithValue(
        InMemoryModerationRepository(),
      ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Mesaj seçenekleri'), findsNothing);
    });
  });

  group('çıkarma ile yasak ayrı kavramlar', () {
    testWidgets('yönetici iki eylemi de ayrı adlarla görür', (tester) async {
      await tester.pumpWidget(await _detailHarness(viewer: _owner));
      await tester.pumpAndSettle();

      // `scrollUntilVisible` tek eleman bekler; iki uye satiri oldugu icin
      // once uye bolumune, benzersiz bir metinle kaydiriliyor.
      await tester.scrollUntilVisible(
        find.text('Ucuncu'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // WP-498: iki eylem satırdaki ayrı simgelerden **tek taşma menüsüne**
      // indi (dört yuva ada yer bırakmıyordu). Bu testin iddiası değişmedi:
      // kurucu dışındaki her üye için ayrı bir moderasyon girişi var ve
      // içindeki iki eylem ayrı adlarla duruyor.
      expect(find.byKey(const ValueKey('moderate-peer-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('moderate-other-1')), findsOneWidget);
      // Kurucunun kendi satırında moderasyon yok (koşul aynen korundu).
      expect(find.byKey(const ValueKey('moderate-owner-1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('moderate-other-1')));
      await tester.pumpAndSettle();

      expect(find.text('Üyeyi çıkar'), findsOneWidget);
      expect(find.text('Üyeyi yasakla'), findsOneWidget);
      // Eski hâlde grup yasağı `safetyBlock` ile etiketliydi; o metin
      // hesap-kapsamlı KİŞİSEL engellemeye aittir ve yönetici işlemi değildir.
      expect(find.text('Engelle'), findsNothing);
      expect(find.byTooltip('Engelle'), findsNothing);
    });

    testWidgets('yönetici olmayan üye çıkarma/yasak göremez', (tester) async {
      await tester.pumpWidget(await _detailHarness(viewer: _peer));
      await tester.pumpAndSettle();

      // 🔴 Bu iddia iki kez boşa düşebilirdi: üye listesi hiç render edilmezse
      // ya da bakılan tek satır kurucununki olursa (kurucuya yönetici bile
      // kick/ban göremez). Bu yüzden gruba ÜÇÜNCÜ bir üye katıldı ve önce onun
      // satırının gerçekten çizildiği doğrulanıyor.
      final row = find.text('Ucuncu');
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(row, findsOneWidget);
      expect(find.byTooltip('Dürt'), findsWidgets);

      // WP-498: eylemler menüye indi; kapının yeri değişmedi — yönetici
      // olmayan izleyicide **menü düğmesi hiç çizilmez**, boş menü açılmaz.
      expect(find.byKey(const ValueKey('moderate-other-1')), findsNothing);
      expect(find.byKey(const ValueKey('moderate-owner-1')), findsNothing);
      expect(find.text('Üyeyi çıkar'), findsNothing);
      expect(find.text('Üyeyi yasakla'), findsNothing);
    });
  });
}
