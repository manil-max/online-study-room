import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/tasks/task_deadline.dart';

/// WP-200: aciliyet spektrumu smoke (renk kademeleri).
void main() {
  test('urgency spectrum moves from calm toward red as deadline nears', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    final now = DateTime.utc(2026, 7, 18, 12);
    final far = taskUrgencyColor(
      now,
      now.add(const Duration(days: 20)),
      scheme,
    );
    final mid = taskUrgencyColor(
      now,
      now.add(const Duration(hours: 12)),
      scheme,
    );
    final near = taskUrgencyColor(
      now,
      now.add(const Duration(hours: 1)),
      scheme,
    );
    final late = taskUrgencyColor(
      now,
      now.subtract(const Duration(hours: 1)),
      scheme,
    );
    // Gecikmiş kırmızı baskın
    expect(late.r, greaterThan(near.r * 0.5));
    expect(taskUrgencyKind(now, now.add(const Duration(days: 20))),
        TaskUrgencyKind.calm);
    expect(taskUrgencyKind(now, now.add(const Duration(hours: 1))),
        TaskUrgencyKind.urgent);
    expect(taskUrgencyKind(now, now.subtract(const Duration(minutes: 1))),
        TaskUrgencyKind.overdue);
    // far uses scheme.primary-ish (not pure red overdue)
    expect(far, isNot(equals(late)));
    expect(mid, isNot(equals(far)));
  });
}
