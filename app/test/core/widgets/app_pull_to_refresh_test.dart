import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/widgets/app_pull_to_refresh.dart';

void main() {
  testWidgets('short vertical content can still start pull-to-refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AppPullToRefresh(
            child: ListView(children: [SizedBox(height: 24)]),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, 220));
    await tester.pump();

    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
