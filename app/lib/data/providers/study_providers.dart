import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../models/presence.dart';
import '../models/study_session.dart';
import '../repositories/study_repository.dart';
import '../repositories/in_memory/in_memory_study_repository.dart';
import '../repositories/supabase/supabase_study_repository.dart';
import 'auth_providers.dart';
import 'group_providers.dart';
import 'presence_providers.dart';

/// Aktif StudyRepository. Anahtarlar verilmişse Supabase, yoksa bellek-içi.
final studyRepositoryProvider = Provider<StudyRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseStudyRepository(Supabase.instance.client);
  }
  final repo = InMemoryStudyRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Giriş yapan kullanıcının oturumları (yeni → eski).
final userSessionsProvider = StreamProvider<List<StudySession>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(studyRepositoryProvider).watchUserSessions(user.id);
});

/// Kullanıcının sınıfındaki tüm oturumlar (istatistik/sıralama için).
final groupSessionsProvider = StreamProvider<List<StudySession>>((ref) {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(studyRepositoryProvider).watchGroupSessions(group.id);
});

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Kullanıcının bugün KAYDEDİLMİŞ toplam süresi (saniye). Devam eden oturum hariç
/// (canlı kısım UI'da anlık eklenir).
final todayRecordedSecondsProvider = Provider<int>((ref) {
  final sessions = ref.watch(userSessionsProvider).value ?? const [];
  final now = DateTime.now();
  return sessions
      .where((s) => _isSameDay(s.day, now))
      .fold<int>(0, (sum, s) => sum + s.durationSeconds);
});

/// Sınıftaki her üyenin bugün KAYDEDİLMİŞ toplam süresi (userId -> saniye).
/// Canlı sınıf ekranında "bugünkü toplam" buradan okunur; devam eden oturumun
/// anlık kısmı UI'da presence üzerinden eklenir.
final groupTodaySecondsProvider = Provider<Map<String, int>>((ref) {
  final sessions = ref.watch(groupSessionsProvider).value ?? const [];
  final now = DateTime.now();
  final totals = <String, int>{};
  for (final s in sessions) {
    if (!_isSameDay(s.day, now)) continue;
    totals[s.userId] = (totals[s.userId] ?? 0) + s.durationSeconds;
  }
  return totals;
});

/// Çalışma sayacının fazı: boşta / çalışıyor / molada.
enum StudyPhase { idle, running, onBreak }

/// Çalışma sayacının durumu.
class StudyTimerState {
  const StudyTimerState({this.phase = StudyPhase.idle, this.startedAt});
  final StudyPhase phase;

  /// Çalışırken mevcut oturumun başlangıcı (anlık süre buradan hesaplanır).
  final DateTime? startedAt;

  bool get isRunning => phase == StudyPhase.running;
  bool get isOnBreak => phase == StudyPhase.onBreak;
}

/// Çalışma sayacını yönetir: başlat / mola / durdur ve oturumu kaydet.
/// Mola "sadece durum"dur — mola süresi tutulmaz (bkz. project.md §3.5/§9):
/// molaya geçince o ana kadarki süre kaydedilir, çalışma sayma durur.
class StudyTimerNotifier extends Notifier<StudyTimerState> {
  static const _uuid = Uuid();

  @override
  StudyTimerState build() => const StudyTimerState();

  /// Çalışmaya başla (boştan veya moladan yeni oturum).
  void start() {
    if (state.phase == StudyPhase.running) return;
    final now = DateTime.now();
    state = StudyTimerState(phase: StudyPhase.running, startedAt: now);
    _publishPresence(status: PresenceStatus.studying, startedAt: now);
  }

  /// Mola ver: o ana kadarki süreyi kaydet, sayacı durdur, durumu mola yap.
  Future<void> pause() async {
    if (state.phase != StudyPhase.running) return;
    final startedAt = state.startedAt;
    state = const StudyTimerState(phase: StudyPhase.onBreak);
    _publishPresence(status: PresenceStatus.onBreak, startedAt: null);
    if (startedAt != null) await _recordSession(startedAt, DateTime.now());
  }

  /// Tamamen bitir: çalışıyorsa süreyi kaydet, durumu çevrimdışına çek.
  Future<void> stop() async {
    final phase = state.phase;
    final startedAt = state.startedAt;
    if (phase == StudyPhase.idle) return;
    state = const StudyTimerState();
    _publishPresence(status: PresenceStatus.offline, startedAt: null);
    if (phase == StudyPhase.running && startedAt != null) {
      await _recordSession(startedAt, DateTime.now());
    }
  }

  /// Tamamlanan bir aralığı `study_sessions`'a yazar.
  Future<void> _recordSession(DateTime start, DateTime end) async {
    final user = ref.read(authStateProvider).value;
    final group = ref.read(userGroupProvider).value;
    if (user == null || group == null) return;

    final duration = end.difference(start).inSeconds;
    if (duration <= 0) return;

    await ref.read(studyRepositoryProvider).addSession(
          StudySession(
            id: _uuid.v4(),
            userId: user.id,
            groupId: group.id,
            start: start,
            end: end,
            durationSeconds: duration,
            source: StudySource.live,
          ),
        );
  }

  /// Kullanıcının canlı durumunu presence deposuna yazar (hata olursa sayacı bozmaz).
  void _publishPresence({
    required PresenceStatus status,
    required DateTime? startedAt,
  }) {
    final user = ref.read(authStateProvider).value;
    final group = ref.read(userGroupProvider).value;
    if (user == null || group == null) return;

    final presence = Presence(
      userId: user.id,
      groupId: group.id,
      status: status,
      startedAt: startedAt,
      todaySeconds: ref.read(todayRecordedSecondsProvider),
    );
    // Yangına-at-unut: presence yazımı başarısız olsa bile çalışma akışı sürmeli.
    ref.read(presenceRepositoryProvider).setPresence(presence).catchError((_) {});
  }
}

final studyTimerProvider =
    NotifierProvider<StudyTimerNotifier, StudyTimerState>(
        StudyTimerNotifier.new);
