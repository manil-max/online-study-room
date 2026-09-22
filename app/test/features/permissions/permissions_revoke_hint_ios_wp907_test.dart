// WP-907 — iOS İzinler ekranı Android geri alma cümlesi yerine iOS cümlesini
// gösterir; Android ekranı yalnız Android cümlesini gösterir.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/features/permissions/permissions_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

Widget _app(Locale locale) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const PermissionsScreen(),
  ),
);

void main() {
  tearDown(() {
    ClockPermissions.debugSnapshotOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: iOS ipucu görünür, Android ipucu yok (TR)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    ClockPermissions.debugSnapshotOverride =
        const ClockPermissionSnapshot.notificationsOnly(notifications: true);
    await tester.pumpWidget(_app(const Locale('tr')));
    await tester.pump();

    final tr = AppLocalizationsTr();
    expect(
      find.byKey(const Key('permissions-revoke-hint-ios')),
      findsOneWidget,
    );
    expect(find.text(tr.permissionsRevokeHintIos), findsOneWidget);
    expect(find.byKey(const Key('permissions-revoke-hint')), findsNothing);
    expect(find.text(tr.permissionsRevokeHint), findsNothing);
    expect(tr.permissionsRevokeHintIos, contains('iOS Ayarlar'));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: İngilizce metin', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    ClockPermissions.debugSnapshotOverride =
        const ClockPermissionSnapshot.notificationsOnly(notifications: false);
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.pump();

    final en = AppLocalizationsEn();
    expect(find.text(en.permissionsRevokeHintIos), findsOneWidget);
    expect(en.permissionsRevokeHintIos, contains('iOS Settings'));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android: yalnız Android ipucu', (tester) async {
    ClockPermissions.debugSnapshotOverride = ClockPermissionSnapshot.ok;
    await tester.pumpWidget(_app(const Locale('tr')));
    await tester.pump();

    expect(find.byKey(const Key('permissions-revoke-hint')), findsOneWidget);
    expect(find.byKey(const Key('permissions-revoke-hint-ios')), findsNothing);
  });
}
