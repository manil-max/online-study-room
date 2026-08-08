// WP-510 (v59 saha geri bildirimi · madde 2 + E5): "sohbet pencere içinde
// pencere."
//
// Eski hâl üç kattı: `AppBar("Sohbet")` → gövdede bir `ListView` → içinde önce
// grup adı, sonra **sabit yükseklikli** (`messageListHeight`, 300–560 arası
// kırpılan) bir sohbet kartı. Yan etkisi yalnız görsel değildi:
//   * mesaj listesi ekranın boş kalan yerini kullanmıyordu,
//   * dıştaki `ListView` yüzünden yazma alanı klavyeyle doğru davranmıyordu.
//
// Bu dosya iki şeyi birden kilitler: yeni yerleşimin **ölçülebilir** sonucu
// (liste ekranın çoğunu kaplıyor, klavye açılınca yazma alanı görünür kalıyor)
// ve eski deseni geri getirecek kapının kapalı olduğu (sabit yükseklik yok).
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
import 'package:online_study_room/data/repositories/in_memory/in_memory_chat_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const Size _kSurface = Size(360, 800);

final _me = Profile(
  id: 'u1',
  displayName: 'Ben',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g1',
  name: 'Odak Grubu',
  inviteCode: 'KAMP42',
  createdBy: _me.id,
  createdAt: DateTime(2026, 1, 1),
);

final _messages = [
  ChatMessage(
    id: 'm-1',
    groupId: _group.id,
    userId: _me.id,
    body: 'Merhaba',
    createdAt: DateTime.utc(2026, 1, 1, 9),
    authorDisplayName: _me.displayName,
  ),
];

/// Sohbet ekranını gerçek pencere boyutunda kurar.
///
/// 🔴 `MediaQuery(size: ...)` yetmez — kök kısıt test penceresinden gelir
/// (komşu `member_row_wp498_test.dart`da ölçülen tuzak). Yükseklik iddiası için
/// pencerenin kendisi ayarlanmalı.
Future<void> _pumpChat(
  WidgetTester tester, {
  double keyboardInset = 0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _kSurface;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        classMessagesProvider(
          _group.id,
        ).overrideWith((ref) => Stream.value(_messages)),
        chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
        // WP-538 sonrasi ZORUNLU: sohbet, engelli kullanici kumesi BILINMEDEN
        // mesaj cizmez (ag hatasi engellemeyi sessizce kapatmasin diye kasten
        // fail-closed). Kapi `--dart-define-from-file=env.json` ile kostugu
        // icin varsayilan moderasyon deposu Supabase olur, testte hicbir zaman
        // cozulmez ve liste sonsuza dek bos kalir; yerlesim iddialarinin hepsi
        // anlamsizca kirmizi duser.
        // Olculdu: bu override olmadan bu dosyada 8 testin 6'si kirmizi.
        moderationRepositoryProvider.overrideWithValue(
          InMemoryModerationRepository(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClassChatScreen(group: _group),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('pencere içinde pencere kalktı', () {
    testWidgets('başlık grup adı; ikinci bir "Sohbet" katmanı yok', (
      tester,
    ) async {
      await _pumpChat(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(_group.name),
        ),
        findsOneWidget,
      );
      // Eski üç katın ortadaki ikisi: başlıktaki "Sohbet" ve gövdedeki
      // grup adı satırı. İkisi de gitti.
      expect(find.text('Sohbet'), findsNothing);
      expect(find.text(_group.name), findsOneWidget);
    });

    testWidgets('sohbetin çevresinde Card kabuğu yok', (tester) async {
      await _pumpChat(tester);

      expect(
        find.ancestor(
          of: find.byType(ClassChatCard),
          matching: find.byType(Card),
        ),
        findsNothing,
      );
    });

    testWidgets('gövdede dıştan saran ikinci kaydırıcı yok', (tester) async {
      await _pumpChat(tester);

      // 🔴 `Scrollable` sayılmaz: `TextField` de içeride bir tane kurar
      // (ölçüldü, iddia bu yüzden ikiye düşüyordu). Ölçülecek şey mesaj
      // listesini saran ikinci `ListView`ün olmadığıdır.
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('liste boş alanın tamamını alıyor', () {
    testWidgets('mesaj listesi ekranın en az %60ını kaplıyor', (tester) async {
      await _pumpChat(tester);

      final listHeight = tester.getSize(find.byType(ListView)).height;

      // Eski hâlde bu değer `messageListHeight` idi: 800 dp ekranda
      // (800 - 260).clamp(300, 560) = 540, üstelik AppBar + grup adı + kart
      // dolgusu da ekrandan düşüyordu. Yeni ölçü kalan alanın tamamıdır.
      expect(
        listHeight / _kSurface.height,
        greaterThan(0.6),
        reason: 'liste ekranın ${(listHeight / _kSurface.height * 100).round()}%\'ini alıyor',
      );
    });

    testWidgets('sabit yükseklik kapısı kapandı: SizedBox(height:) yok', (
      tester,
    ) async {
      await _pumpChat(tester);

      // 🔴 E5: `messageListHeight` parametresi kalsaydı "kart içinde kart"
      // bir gün geri gelirdi. Parametre kalktı; bu iddia listeyi saran
      // sabit yükseklikli kutunun da geri gelmediğini ölçer.
      final fixedBoxAroundList = find.ancestor(
        of: find.byType(ListView),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height != null,
        ),
      );
      expect(fixedBoxAroundList, findsNothing);
    });
  });

  group('klavye', () {
    testWidgets('klavye açıkken yazma alanı ve gönder düğmesi görünür kalır', (
      tester,
    ) async {
      await _pumpChat(tester, keyboardInset: 320);

      // `Scaffold`un varsayılan `resizeToAvoidBottomInset` davranışı gövdeyi
      // kısaltır; daralan yalnız mesaj listesi olmalı.
      final field = tester.getRect(find.byType(TextField));
      final visibleBottom = _kSurface.height - 320;
      expect(
        field.bottom,
        lessThanOrEqualTo(visibleBottom),
        reason: 'yazma alanı ${field.bottom} dp\'de, klavye $visibleBottom dp\'de başlıyor',
      );
      expect(
        tester.getRect(find.byTooltip('Gönder')).bottom,
        lessThanOrEqualTo(visibleBottom),
      );
    });

    testWidgets('klavye açılınca daralan yalnız mesaj listesi', (tester) async {
      await _pumpChat(tester);
      final before = tester.getSize(find.byType(ListView)).height;
      final fieldBefore = tester.getSize(find.byType(TextField)).height;

      await _pumpChat(tester, keyboardInset: 320);
      final after = tester.getSize(find.byType(ListView)).height;

      expect(after, lessThan(before));
      expect(tester.getSize(find.byType(TextField)).height, fieldBefore);
    });
  });

  group('sohbetin kendisi çalışmaya devam ediyor', () {
    testWidgets('mesaj çiziliyor ve yazma alanı etkin', (tester) async {
      await _pumpChat(tester);

      expect(find.text('Merhaba'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });
  });
}
