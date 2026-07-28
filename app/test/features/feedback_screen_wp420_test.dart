// WP-420: geri bildirim ekranının yeniden düzeni.
//
// Sahip destek akışını uçtan uca denedi: çalışıyor, ama dar telefonda konu +
// açıklama + **üç düğme alt alta** + klavye = yazdığı metin görünmüyor.
// Üçüncü düğme sekmeye taşındı, kalan ikisi yan yana ve sabit alt şeritte.
//
// 🔴 Koşum üretimdeki kabuğu taklit eder: `FeedbackScreen` kendi `Scaffold`'unu
// getirir ve doğrudan `home:`e konur. Kabuk taklit edilmezse (ör. ekstra bir
// Scaffold sarmalanırsa) klavye/yer paylaşımı hatası testin altından geçer —
// bu repoda tam olarak bu yaşandı.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

Widget _wrap(InMemoryAdminRepository repo) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026)),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      locale: Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FeedbackScreen(),
    ),
  );
}

void main() {
  // Dar telefon: 1080 fiziksel / 3x = 360x640 dp.
  void useNarrowPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
  }

  testWidgets('gönderme formunda iki düğme yan yana, üçüncüsü sekmede', (
    tester,
  ) async {
    final repo = InMemoryAdminRepository();
    addTearDown(repo.dispose);
    useNarrowPhone(tester);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Üçüncü düğme artık düğme değil, sekme.
    expect(find.byKey(const Key('feedback-tab-compose')), findsOneWidget);
    expect(find.byKey(const Key('feedback-tab-tickets')), findsOneWidget);

    final cancel = tester.getRect(find.byKey(const Key('feedback-cancel')));
    final submit = tester.getRect(find.byKey(const Key('feedback-submit')));

    // Yan yana: aynı satırda ve İptal solda.
    expect(cancel.top, closeTo(submit.top, 0.5));
    expect(cancel.right, lessThanOrEqualTo(submit.left));
    // İkisi de dokunulabilir yükseklikte.
    expect(cancel.height, greaterThanOrEqualTo(40));
    expect(submit.height, greaterThanOrEqualTo(40));
  });

  testWidgets('klavye açıkken yazılan metin görünür kalır', (tester) async {
    final repo = InMemoryAdminRepository();
    addTearDown(repo.dispose);
    useNarrowPhone(tester);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Klavye: 900 fiziksel px = 300 dp. Görünür alan 640 - 300 = 340 dp.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    final messageField = find.byKey(const Key('feedback-message-field'));
    await tester.ensureVisible(messageField);
    await tester.pumpAndSettle();
    await tester.enterText(messageField, 'Klavye açıkken yazıyorum.');
    await tester.pumpAndSettle();

    const visibleBottom = 640.0 - 300.0;
    final field = tester.getRect(messageField);
    final submit = tester.getRect(find.byKey(const Key('feedback-submit')));

    // 🔴 Asıl kapan: `Scaffold.bottomSheet` gövdeye yer ayırmaz, üstüne biner —
    // o hâlde şerit metin alanını örter ve bu iddia düşer.
    expect(
      submit.top,
      greaterThanOrEqualTo(field.bottom - 0.5),
      reason: 'alt şerit metin alanının üstüne biniyor',
    );
    // Şerit de metin de klavyenin üstünde kalır.
    expect(submit.bottom, lessThanOrEqualTo(visibleBottom + 0.5));
    expect(field.top, lessThan(visibleBottom));
    expect(find.text('Klavye açıkken yazıyorum.'), findsOneWidget);
  });

  testWidgets('gönderilen bilet ikinci sekmede en üstte görünür', (
    tester,
  ) async {
    final repo = InMemoryAdminRepository();
    addTearDown(repo.dispose);
    useNarrowPhone(tester);

    // Önceden gelen eski bir kayıt: yenisi onun üstüne çıkmalı.
    await repo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.feedback,
      subject: 'Eski kayıt',
      message: 'Geçen haftadan.',
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('feedback-subject-field')),
      'Yeni kayıt',
    );
    await tester.enterText(
      find.byKey(const Key('feedback-message-field')),
      'Bugünkü mesaj.',
    );
    await tester.tap(find.byKey(const Key('feedback-submit')));
    await tester.pumpAndSettle();

    // Gönderim sonrası ikinci sekmeye geçilir ve kayıt görünür.
    expect(find.text('Yeni kayıt'), findsOneWidget);
    expect(find.text('Eski kayıt'), findsOneWidget);
    // Tarih sıralı, en yeni en üstte.
    expect(
      tester.getTopLeft(find.text('Yeni kayıt')).dy,
      lessThan(tester.getTopLeft(find.text('Eski kayıt')).dy),
    );
  });

  testWidgets('sekmeler arasında geçiş her iki yönde çalışır', (tester) async {
    final repo = InMemoryAdminRepository();
    addTearDown(repo.dispose);
    useNarrowPhone(tester);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feedback-tab-tickets')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feedback-submit')), findsNothing);

    await tester.tap(find.byKey(const Key('feedback-tab-compose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feedback-submit')), findsOneWidget);
  });
}
