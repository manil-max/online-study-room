import 'package:equatable/equatable.dart';

/// Kullanıcının oluşturduğu hızlı/hazır zamanlayıcı (Preset) veri modeli.
class TimerPreset extends Equatable {
  const TimerPreset({
    required this.id,
    required this.label,
    required this.durationSeconds,
    this.colorHex,
  });

  final String id;
  final String label;
  final int durationSeconds;
  
  /// Örneğin renk veya ikon bilgisi tutmak için (isteğe bağlı)
  final String? colorHex;

  TimerPreset copyWith({
    String? id,
    String? label,
    int? durationSeconds,
    String? colorHex,
  }) {
    return TimerPreset(
      id: id ?? this.id,
      label: label ?? this.label,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'durationSeconds': durationSeconds,
      'colorHex': colorHex,
    };
  }

  factory TimerPreset.fromMap(Map<String, dynamic> map) {
    return TimerPreset(
      id: map['id'] as String,
      label: map['label'] as String,
      durationSeconds: (map['durationSeconds'] as num).toInt(),
      colorHex: map['colorHex'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, label, durationSeconds, colorHex];
}

/// Zamanlayıcının anlık durumu.
enum TimerStateStatus { initial, running, paused, done }

/// Aktif olarak çalışan/duraklatılmış bir Timer'ın durumunu (State) temsil eder.
class TimerInstance extends Equatable {
  const TimerInstance({
    required this.id,
    this.presetId,
    required this.label,
    required this.durationSeconds,
    required this.remainingSeconds,
    this.status = TimerStateStatus.initial,
    this.lastUpdatedAt,
  });

  final String id;
  final String? presetId;
  final String label;
  final int durationSeconds;
  final int remainingSeconds;
  final TimerStateStatus status;
  
  /// Uygulama arkaya atıldığında, geri gelindiğinde geçen süreyi hesaplamak için kullanılır.
  final DateTime? lastUpdatedAt;

  TimerInstance copyWith({
    String? id,
    String? presetId,
    String? label,
    int? durationSeconds,
    int? remainingSeconds,
    TimerStateStatus? status,
    DateTime? lastUpdatedAt,
  }) {
    return TimerInstance(
      id: id ?? this.id,
      presetId: presetId ?? this.presetId,
      label: label ?? this.label,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      status: status ?? this.status,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
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
      ];
}
