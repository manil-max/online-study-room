import 'package:flutter/foundation.dart';

enum GoalStreakScopeType {
  personal('personal'),
  group('group');

  const GoalStreakScopeType(this.wireValue);

  final String wireValue;

  static GoalStreakScopeType fromWire(String value) => values.firstWhere(
    (candidate) => candidate.wireValue == value,
    orElse: () => throw FormatException('Unknown goal streak scope: $value'),
  );
}

@immutable
class GoalStreakScope {
  const GoalStreakScope({
    required this.type,
    required this.id,
    required this.timeZone,
  }) : assert(id != ''),
       assert(timeZone != '');

  const GoalStreakScope.personal(String userId)
    : this(
        type: GoalStreakScopeType.personal,
        id: userId,
        timeZone: 'Europe/Istanbul',
      );

  const GoalStreakScope.group({
    required String groupId,
    required String timeZone,
  }) : this(type: GoalStreakScopeType.group, id: groupId, timeZone: timeZone);

  final GoalStreakScopeType type;
  final String id;
  final String timeZone;

  String get ledgerKey => '${type.wireValue}:$id';

  Map<String, Object?> toMap() => {
    'scope_type': type.wireValue,
    'scope_id': id,
    'time_zone': timeZone,
  };

  factory GoalStreakScope.fromMap(Map<String, dynamic> map) => GoalStreakScope(
    type: GoalStreakScopeType.fromWire(map['scope_type'] as String),
    id: map['scope_id'] as String,
    timeZone: map['time_zone'] as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalStreakScope &&
          type == other.type &&
          id == other.id &&
          timeZone == other.timeZone;

  @override
  int get hashCode => Object.hash(type, id, timeZone);
}

enum GoalProgressEventKind {
  appOpened('app_opened'),
  timerStarted('timer_started'),
  partialProgress('partial_progress'),
  goalCompleted('goal_completed');

  const GoalProgressEventKind(this.wireValue);

  final String wireValue;

  static GoalProgressEventKind fromWire(String value) => values.firstWhere(
    (candidate) => candidate.wireValue == value,
    orElse: () => throw FormatException('Unknown goal progress event: $value'),
  );
}

@immutable
class GoalProgressEvent {
  const GoalProgressEvent({
    required this.eventKey,
    required this.scope,
    required this.kind,
    required this.goalDay,
    required this.occurredAt,
  }) : assert(eventKey != '');

  final String eventKey;
  final GoalStreakScope scope;
  final GoalProgressEventKind kind;
  final DateTime goalDay;
  final DateTime occurredAt;

  Map<String, Object?> toMap() => {
    'event_key': eventKey,
    ...scope.toMap(),
    'event_kind': kind.wireValue,
    'goal_day': _wireDay(goalDay),
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };

  factory GoalProgressEvent.fromMap(Map<String, dynamic> map) =>
      GoalProgressEvent(
        eventKey: map['event_key'] as String,
        scope: GoalStreakScope.fromMap(map),
        kind: GoalProgressEventKind.fromWire(map['event_kind'] as String),
        goalDay: DateTime.parse(map['goal_day'] as String),
        occurredAt: DateTime.parse(map['occurred_at'] as String),
      );
}

enum GoalStreakState {
  empty('empty'),
  completedToday('completed_today'),
  pendingToday('pending_today'),
  atRisk('at_risk'),
  expired('expired');

  const GoalStreakState(this.wireValue);

  final String wireValue;

  static GoalStreakState fromWire(String value) => values.firstWhere(
    (candidate) => candidate.wireValue == value,
    orElse: () => throw FormatException('Unknown goal streak state: $value'),
  );
}

@immutable
class GoalStreakProjection {
  const GoalStreakProjection({
    required this.scope,
    required this.asOfDay,
    required this.currentStreak,
    required this.completionCount,
    required this.state,
    required this.sourceVersion,
    this.lastCompletedDay,
  }) : assert(currentStreak >= 0),
       assert(completionCount >= 0);

  final GoalStreakScope scope;
  final DateTime asOfDay;
  final int currentStreak;
  final int completionCount;
  final DateTime? lastCompletedDay;
  final GoalStreakState state;
  final String sourceVersion;

  bool get isProtectedByAutomaticGrace => state == GoalStreakState.atRisk;

  Map<String, Object?> toMap() => {
    ...scope.toMap(),
    'as_of_day': _wireDay(asOfDay),
    'current_streak': currentStreak,
    'completion_count': completionCount,
    'last_completed_day': lastCompletedDay == null
        ? null
        : _wireDay(lastCompletedDay!),
    'state': state.wireValue,
    'source_version': sourceVersion,
  };

  factory GoalStreakProjection.fromMap(Map<String, dynamic> map) =>
      GoalStreakProjection(
        scope: GoalStreakScope.fromMap(map),
        asOfDay: DateTime.parse(map['as_of_day'] as String),
        currentStreak: map['current_streak'] as int,
        completionCount: map['completion_count'] as int,
        lastCompletedDay: switch (map['last_completed_day']) {
          final String value => DateTime.parse(value),
          _ => null,
        },
        state: GoalStreakState.fromWire(map['state'] as String),
        sourceVersion: map['source_version'] as String,
      );
}

String _wireDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
