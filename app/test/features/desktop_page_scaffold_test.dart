import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';

void main() {
  testWidgets('dar desktop genişliğinde başlık ve komutlar taşmaz', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopPageScaffold(
          title: 'Saat Merkezi',
          subtitle:
              'Saati izle, kronometreyi yönet veya yapılandırılmış bir odak oturumu başlat.',
          icon: Icons.schedule_outlined,
          actions: [
            FilledButton.tonalIcon(
              onPressed: () {},
              icon: const Icon(Icons.picture_in_picture_alt_outlined),
              label: const Text('Compact Focus'),
            ),
          ],
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Saat Merkezi'), findsOneWidget);
    expect(find.text('Compact Focus'), findsOneWidget);
  });

  testWidgets('geniş desktop görünümünde iki paneli yan yana dizer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: DesktopResponsiveColumns(
              primary: SizedBox(key: ValueKey('primary'), height: 80),
              secondary: SizedBox(key: ValueKey('secondary'), height: 80),
            ),
          ),
        ),
      ),
    );

    final primary = tester.getTopLeft(find.byKey(const ValueKey('primary')));
    final secondary = tester.getTopLeft(
      find.byKey(const ValueKey('secondary')),
    );
    expect(secondary.dx, greaterThan(primary.dx));
    expect(secondary.dy, primary.dy);
  });
}
