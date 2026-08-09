// WP-378: okunmamış duyuru sinyalinin zinciri.
//
// Sahip: "eğer duyurular kısmına bir şey gelirse profil ve ayarlarda da
// bildirim yönlendirmesi olsun sanırım şu an yok."
//
// Kodda doğrulandı: nokta **vardı** ama yalnız Ayarlar'ın *içindeki* Duyurular
// satırında (`settings_screen.dart`). Yani kullanıcı Ayarlar'ı açmadan yeni
// duyuruyu hiç fark etmiyordu — zincirin üstteki iki halkası eksikti.
//
// Bu testler üç halkayı da tek kaynağa (`unreadAnnouncementCountProvider`)
// bağlar ve halka koptuğunda kırmızı düşer.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/providers/notification_providers.dart';
import 'package:online_study_room/features/profile/widgets/unread_announcement_dot.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

Announcement _announcement(String id) => Announcement(
  id: id,
  title: 'Duyuru $id',
  message: 'Gövde',
  targetType: 'all',
  createdAt: DateTime(2026, 7, 28),
  createdBy: 'admin',
);

ProviderContainer _container({
  required List<Announcement> announcements,
  required Set<String> read,
}) {
  final container = ProviderContainer(
    overrides: [
      myAnnouncementsProvider.overrideWith((ref) async => announcements),
      readAnnouncementIdsProvider.overrideWith((ref) async => read),
    ],
  );
  addTearDown(container.dispose);
  // Riverpod 3: dinleyicisiz provider her read'de yeniden kurulur ve regresyon
  // testini sessizce etkisizleştirir.
  container.listen(unreadAnnouncementCountProvider, (_, _) {});
  return container;
}

Future<int> _unreadCount({
  required List<Announcement> announcements,
  required Set<String> read,
}) async {
  final container = _container(announcements: announcements, read: read);
  await container.read(myAnnouncementsProvider.future);
  await container.read(readAnnouncementIdsProvider.future);
  return container.read(unreadAnnouncementCountProvider);
}

void main() {
  group('unreadAnnouncementCountProvider', () {
    test('okunmamış duyuruyu sayar', () async {
      expect(
        await _unreadCount(
          announcements: [_announcement('a'), _announcement('b')],
          read: {'a'},
        ),
        1,
      );
    });

    test('hepsi okunduysa sıfırdır', () async {
      expect(
        await _unreadCount(
          announcements: [_announcement('a')],
          read: {'a'},
        ),
        0,
      );
    });

    test('hiç duyuru yoksa sıfırdır', () async {
      expect(await _unreadCount(announcements: const [], read: const {}), 0);
    });
  });

  group('UnreadAnnouncementDot', () {
    testWidgets('rengini uyarı token’ından değil temanın primary’sinden alır', (
      tester,
    ) async {
      const primary = Color(0xFF3355FF);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: primary),
          ),
          home: const Scaffold(body: UnreadAnnouncementDot(count: 3)),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, primary);
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('erişilebilirlik değeri sayıyı taşır', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: UnreadAnnouncementDot(count: 4)),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byType(UnreadAnnouncementDot),
      );
      expect(semantics.value, '4');
    });
  });

  group('sinyal zinciri kaynak sözleşmesi', () {
    // 🔴 Üç yüzey de aynı zincirden beslenmeli. Biri kendi sayacını türetirse
    // "okundu" işaretlemesi yüzeyler arasında ayrışır ve nokta asla sönmez.
    //
    // WP-459: Profil sekmesi artık duyuruyu **ve** okunmamış yönetici yanıtını
    // birlikte taşıyan `settingsBadgeCountProvider`ı okur; o da bu iki ayağın
    // toplamıdır. Alt iki yüzey duyuru ayağını doğrudan okumayı sürdürür.
    test('üç yüzey de aynı okunmamış zincirini okur', () {
      final surfaces = {
        'Profil sekmesi': (
          'lib/core/navigation/home_shell.dart',
          'settingsBadgeCountProvider',
        ),
        'Profil → Ayarlar satırı': (
          'lib/features/profile/profile_screen.dart',
          'unreadAnnouncementCountProvider',
        ),
        'Ayarlar → Duyurular satırı': (
          'lib/features/profile/settings_screen.dart',
          'unreadAnnouncementCountProvider',
        ),
      };
      surfaces.forEach((name, entry) {
        final (path, provider) = entry;
        expect(
          _read(path).contains(provider),
          isTrue,
          reason: '$name artık tek kaynağı okumuyor ($path)',
        );
      });
    });

    test('üst iki yüzey noktayı gerçekten çiziyor', () {
      // WP-594: rozet kararı `home_shell.dart`tan `profile_tab_badge.dart`a
      // taşındı — masaüstü kolu da aynı kaynağı kullansın diye. Sözleşme aynı,
      // yalnız dosyası değişti.
      expect(
        _read('lib/core/navigation/profile_tab_badge.dart')
            .contains('unreadProfileSignals > 0'),
        isTrue,
        reason: 'Profil sekmesinde okunmamış noktası çizilmiyor',
      );
      expect(
        _read('lib/features/profile/profile_screen.dart')
            .contains('UnreadAnnouncementDot'),
        isTrue,
        reason: 'Profil→Ayarlar satırında duyuru noktası çizilmiyor',
      );
    });

    test('kayıp uyarısı duyuru noktasının önünde gelir', () {
      // WP-352 kararı: aynı sekmede iki sinyal yarışmaz. Eksik birincil grup
      // bir kayıptır, duyuru yalnız yeni içerik — kayıp önceliklidir.
      // WP-594: karar `profile_tab_badge.dart`ta, iki kol da onu okuyor.
      expect(
        _read('lib/core/navigation/profile_tab_badge.dart')
            .contains('!missingPrimaryGroup && unreadProfileSignals > 0'),
        isTrue,
      );
    });
  });
}

/// Kaynak dosyayi satir sonundan bagimsiz okur (repo karisik satir sonu tasir).
String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
