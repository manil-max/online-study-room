import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/home/widgets/card_scaffold.dart';

/// WP-172: unbounded (ListView) kart iskeleti nested SingleChildScrollView kurmamalı.
void main() {
  testWidgets('CardScaffold unbounded has no nested SingleChildScrollView',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              CardScaffold(
                header: const Text('Header'),
                bodyBuilder: _body,
                fallbackBodyHeight: 120,
              ),
              const SizedBox(height: 400),
              const Text('bottom'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kartın içindeki tek olası scroll ebeveyn ListView olmalı.
    final scrolls = find.byType(SingleChildScrollView);
    expect(scrolls, findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('bottom'), findsOneWidget);
  });
}

Widget _body(BuildContext context, double h) => SizedBox(
      height: h,
      child: const ColoredBox(color: Colors.blue),
    );
