import 'dart:async';

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

  test('settleRefreshSource completes when source hangs past timeout (H2)', () async {
    final sw = Stopwatch()..start();
    await settleRefreshSource(
      () => Completer<void>().future,
      timeout: const Duration(milliseconds: 80),
    );
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(2000));
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(70));
  });

  test('settleRefreshSource swallows errors', () async {
    await settleRefreshSource(
      () async => throw StateError('network'),
      timeout: const Duration(seconds: 1),
    );
  });

  test('default timeouts are user-friendly (≤2s global, ≤1.5s per source)', () {
    expect(
      kPullToRefreshPerSourceTimeout,
      lessThanOrEqualTo(const Duration(milliseconds: 1500)),
    );
    expect(
      kPullToRefreshGlobalTimeout,
      lessThanOrEqualTo(const Duration(seconds: 2)),
    );
  });
}
