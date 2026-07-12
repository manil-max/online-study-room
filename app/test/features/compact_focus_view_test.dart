import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/features/desktop/compact_focus_view.dart';

void main() {
  testWidgets('oturum yoksa kayıt başlatmaz ve tam pencereye yönlendirir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: CompactFocusView()),
      ),
    );
    await tester.pump();

    expect(
      find.text('Çalışmayı kaydetmek için giriş yapmalısın.'),
      findsOneWidget,
    );
    expect(find.text('Tam pencereye dön'), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-focus-toggle')), findsNothing);
  });
}
