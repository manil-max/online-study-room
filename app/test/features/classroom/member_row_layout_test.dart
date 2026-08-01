// WP-487 (V57-N11): "Ünvan eklendikten sonra bir üye listede dört satır
// kaplayabiliyor."
//
// Kök neden: satırdaki hiçbir metnin satır sınırı yoktu. Ad sarmalanıyordu,
// ünvan ayrı bir `Text` olarak yine sarmalanıyordu, grup sahibinde "Yönetici"
// üçüncü bir `Text` olarak ekleniyordu. `ListTile` yüksekliği içerikle
// büyüdüğü için liste satırları farklı yüksekliklere düşüyordu.
//
// Bu dosya iddiayı ölçüyle sabitler: satır yüksekliği ad/ünvan uzunluğundan
// **bağımsız** olmalı.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Ünvan sözlüğündeki gerçek bir başarım kimliği; TR adı sözlükteki en uzun
/// olanlardan biri ("Son Saniye Kurtarıcısı").
const _longTitleId = 'secret_last_second';

const _longName =
    'Abdurrahman Muhammed Kemalettin Serdaroglu Buyukcekmeceli Ogrenci';

Profile _member(String id, String name, {String? titleId}) => Profile(
  id: id,
  displayName: name,
  createdAt: DateTime(2026, 1, 1),
  titleAchievementId: titleId,
);

final _owner = _member('owner-1', 'Sahip', titleId: _longTitleId);
final _shortMember = _member('peer-1', 'Ada');
final _longMember = _member('peer-2', _longName, titleId: _longTitleId);

Future<Widget> _detail({
  Size surface = const Size(360, 900),
  double textScale = 1.0,
}) async {
  final groups = InMemoryGroupRepository();
  final group = await groups.createGroup(name: 'Odak Grubu', creator: _owner);
  await groups.joinGroup(inviteCode: group.inviteCode, member: _shortMember);
  await groups.joinGroup(inviteCode: group.inviteCode, member: _longMember);

  return ProviderScope(
    overrides: [
      groupRepositoryProvider.overrideWithValue(groups),
      authStateProvider.overrideWith((ref) => Stream.value(_owner)),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: surface,
          textScaler: TextScaler.linear(textScale),
        ),
        child: ClassDetailScreen(group: group),
      ),
    ),
  );
}

/// Üye satırlarını görünür hâle getirir ve yüksekliklerini döndürür.
Future<List<double>> _memberRowHeights(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text(_longName),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  // Üye kartındaki satırlar: adları benzersiz olan üç üye.
  return [
    for (final name in [_owner.displayName, _shortMember.displayName, _longName])
      tester
          .getSize(
            find.ancestor(
              of: find.text(name),
              matching: find.byType(ListTile),
            ),
          )
          .height,
  ];
}

void main() {
  testWidgets('ad ve ünvan tek satıra sınırlanır', (tester) async {
    await tester.pumpWidget(await _detail());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(_longName),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final name = tester.widget<Text>(find.text(_longName));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
  });

  testWidgets('satır yüksekliği ad/ünvan uzunluğundan bağımsız', (
    tester,
  ) async {
    await tester.pumpWidget(await _detail());
    await tester.pumpAndSettle();

    final heights = await _memberRowHeights(tester);

    // Üç üye: uzun ünvanlı yönetici, ünvansız kısa ad, uzun ad + uzun ünvan.
    // Eskiden sonuncusu diğerlerinin iki katına çıkabiliyordu.
    expect(
      heights.toSet(),
      hasLength(1),
      reason: 'liste satırları farklı yükseklikte: $heights',
    );
  });

  testWidgets('dar ekran ve büyük yazı tipi ölçeğinde taşma yok', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _detail(surface: const Size(320, 900), textScale: 1.6),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(_longName),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    // `RenderFlex overflowed` uyarısı test hatası olarak yükselirdi; buraya
    // gelinmesi taşma olmadığının kanıtıdır. Yine de açıkça doğrulanıyor.
    expect(tester.takeException(), isNull);
    expect(find.text(_longName), findsOneWidget);
  });
}
