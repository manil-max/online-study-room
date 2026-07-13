import 'package:equatable/equatable.dart';

import '../../core/time_engine/epoch_countdown.dart';

/// Hızlı/hazır zamanlayıcı (Preset).
class TimerPreset extends Equatable {
  const TimerPreset({
    required this.id,
    required this.label,
    required this.durationSeconds,
    this.colorHex,
    this.iconCode,
  });

  final String id;
  final String label;
  final int durationSeconds;
  final String? colorHex;

  /// Material Icons codePoint (opsiyonel).
  final int? iconCode;

  TimerPreset copyWith({
    String? id,
    String? label,
    int? durationSeconds,
    String? colorHex,
    int? iconCode,
  }) {
    return TimerPreset(
      id: id ?? this.id,
      label: label ?? this.label,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      colorHex: colorHex ?? this.colorHex,
      iconCode: iconCode ?? this.iconCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'durationSeconds': durationSeconds,
      'colorHex': colorHex,
      'iconCode': iconCode,
    };
  }

  factory TimerPreset.fromMap(Map<String, dynamic> map) {
    return TimerPreset(
      id: map['id'] as String,
      label: map['label'] as String,
      durationSeconds: (map['durationSeconds'] as num).toInt(),
      colorHex: map['colorHex'] as String?,
      iconCode: (map['iconCode'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [id, label, durationSeconds, colorHex, iconCode];
}

/// Varsayılan preset listesi (ilk kurulum).
List<TimerPreset> defaultTimerPresets() => const [
      TimerPreset(
        id: 'preset_5',
        label: '5 dk',
        durationSeconds: 300,
        colorHex: '#22C55E',
      ),
      TimerPreset(
        id: 'preset_10',
        label: '10 dk',
        durationSeconds: 600,
        colorHex: '#3B82F6',
      ),
      TimerPreset(
        id: 'preset_15',
        label: '15 dk',
        durationSeconds: 900,
        colorHex: '#8B5CF6',
      ),
      TimerPreset(
        id: 'preset_25',
        label: '25 dk',
        durationSeconds: 1500,
        colorHex: '#F59E0B',
      ),
      TimerPreset(
        id: 'preset_45',
        label: '45 dk',
        durationSeconds: 2700,
        colorHex: '#EF4444',
      ),
      TimerPreset(
        id: 'preset_60',
        label: '60 dk',
        durationSeconds: 3600,
        colorHex: '#06B6D4',
      ),
    ];

enum TimerStateStatus { initial, running, paused, done }

/// Aktif çoklu timer — epoch tabanlı.
class TimerInstance extends Equatable {
  const TimerInstance({
    required this.id,
    this.presetId,
    required this.label,
    required this.durationSeconds,
    required this.remainingSeconds,
    this.status = TimerStateStatus.initial,
    this.lastUpdatedAt,
    this.endsAtEpochMs,
    this.colorHex,
    this.iconCode,
  });

  final String id;
  final String? presetId;
  final String label;
  final int durationSeconds;

  /// Görüntü/cache; kaynak gerçekte [countdown] + epoch.
  final int remainingSeconds;
  final TimerStateStatus status;
  final DateTime? lastUpdatedAt;

  /// Çalışırken mutlak bitiş epoch ms.
  final int? endsAtEpochMs;
  final String? colorHex;
  final int? iconCode;

  EpochCountdownState get countdown {
    final durationMs = durationSeconds * 1000;
    switch (status) {
      case TimerStateStatus.running:
        return EpochCountdownState(
          durationMs: durationMs,
          endsAtMs: endsAtEpochMs ??
              (lastUpdatedAt != null
                  ? lastUpdatedAt!.millisecondsSinceEpoch +
                      remainingSeconds * 1000
                  : null),
          running: true,
        );
      case TimerStateStatus.paused:
      case TimerStateStatus.initial:
        return EpochCountdownState(
          durationMs: durationMs,
          remainingMsWhenPaused: remainingSeconds * 1000,
          running: false,
        );
      case TimerStateStatus.done:
        return EpochCountdownState(
          durationMs: durationMs,
          remainingMsWhenPaused: 0,
          running: false,
        );
    }
  }

  /// Epoch ile taze kalan saniye.
  int remainingAt(int nowMs) {
    final ms = countdown.remainingMs(nowMs);
    return (ms / 1000).ceil().clamp(0, durationSeconds);
  }

  TimerInstance copyWith({
    String? id,
    String? presetId,
    String? label,
    int? durationSeconds,
    int? remainingSeconds,
    TimerStateStatus? status,
    DateTime? lastUpdatedAt,
    int? endsAtEpochMs,
    bool clearEndsAt = false,
    String? colorHex,
    int? iconCode,
  }) {
    return TimerInstance(
      id: id ?? this.id,
      presetId: presetId ?? this.presetId,
      label: label ?? this.label,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      status: status ?? this.status,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      endsAtEpochMs: clearEndsAt ? null : (endsAtEpochMs ?? this.endsAtEpochMs),
      colorHex: colorHex ?? this.colorHex,
      iconCode: iconCode ?? this.iconCode,
    );
  }

  /// Durumu epoch motorundan senkronla.
  TimerInstance syncedWith(EpochCountdownState c, int nowMs) {
    final remSec = (c.remainingMs(nowMs) / 1000).ceil();
    final done = c.isDone(nowMs) && c.durationMs > 0;
    return copyWith(
      remainingSeconds: done ? 0 : remSec.clamp(0, durationSeconds),
      status: done
          ? TimerStateStatus.done
          : (c.running ? TimerStateStatus.running : TimerStateStatus.paused),
      lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
      endsAtEpochMs: c.endsAtMs,
      clearEndsAt: c.endsAtMs == null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'presetId': presetId,
      'label': label,
      'durationSeconds': durationSeconds,
      'remainingSeconds': remainingSeconds,
      'status': status.name,
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      'endsAtEpochMs': endsAtEpochMs,
      'colorHex': colorHex,
      'iconCode': iconCode,
    };
  }

  factory TimerInstance.fromMap(Map<String, dynamic> map) {
    return TimerInstance(
      id: map['id'] as String,
      presetId: map['presetId'] as String?,
      label: map['label'] as String,
      durationSeconds: (map['durationSeconds'] as num).toInt(),
      remainingSeconds: (map['remainingSeconds'] as num).toInt(),
      status: TimerStateStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TimerStateStatus.initial,
      ),
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? DateTime.parse(map['lastUpdatedAt'] as String)
          : null,
      endsAtEpochMs: (map['endsAtEpochMs'] as num?)?.toInt(),
      colorHex: map['colorHex'] as String?,
      iconCode: (map['iconCode'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        presetId,
        label,
        durationSeconds,
        remainingSeconds,
        status,
        lastUpdatedAt,
        endsAtEpochMs,
        colorHex,
        iconCode,
      ];
}
