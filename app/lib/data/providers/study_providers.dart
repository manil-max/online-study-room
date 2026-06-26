import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../../core/stats/study_stats.dart';
import '../models/daily_stat.dart';
import '../models/presence.dart';
import '../models/profile.dart';
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

/// Kullanıcının sınıfının **per-user-per-gün** toplamları (grup geneli
/// istatistik/sıralama/seri için). Ham oturumlar artık akıtılmaz; veri sunucuda
/// toplanır (F1). Leaderboard, grup serisi ve trend bundan hesaplanır.
final groupDailyStatsProvider = StreamProvider<List<DailyStat>>((ref) {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(studyRepositoryProvider).watchGroupDailyStats(group.id);
});

/// Kullanıcının bugün KAYDEDİLMİŞ toplam süresi (saniye). Devam eden oturum hariç
/// (canlı kısım UI'da anlık eklenir).
final todayRecordedSecondsProvider = Provider<int>((ref) {
  final sessions = ref.watch(userSessionsProvider).value ?? const [];
  final now = DateTime.now();
  return sessions
      .where((s) => isSameDay(s.day, now))
      .fold<int>(0, (sum, s) => sum + s.durationSeconds);
});

/// Kullanıcının günlük hedefi (dakika). Profil yoksa varsayılan (§3.7).
final dailyGoalMinutesProvider = Provider<int>((ref) {
  return ref.watch(authStateProvider).value?.dailyGoalMinutes ??
      kDefaultDailyGoalMinutes;
});

/// Günlük hedefe bağlı güncel seri (üst üste hedef tutturulan gün, §3.7).
final currentStreakProvider = Provider<int>((ref) {
  final sessions = ref.watch(userSessionsProvider).value ?? const [];
  final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
  return currentStreak(sessions, goalSeconds);
});

/// Sınıftaki her üyenin bugün KAYDEDİLMİŞ toplam süresi (userId -> saniye).
/// Canlı sınıf ekranında "bugünkü toplam" buradan okunur; devam eden oturumun
/// anlık kısmı UI'da presence üzerinden eklenir.
final groupTodaySecondsProvider = Provider<Map<String, int>>((ref) {
  final stats = ref.watch(groupDailyStatsProvider).value ?? const [];
  return todaySecondsByUser(stats);
});

/// Çalışma sayacının durumu.
class StudyTimerState {
  const StudyTimerState({this.isRunning = false, this.startedAt, this.subjectId});
  final bool isRunning;

  /// Çalışırken mevcut oturumun başlangıcı (anlık süre buradan hesaplanır).
  final DateTime? startedAt;

  /// Seçili ders (opsiyonel — null ise "derssiz"). Bkz. project.md §3.7.
  final String? subjectId;
}

/// Çalışma sayacını yönetir: başlat / durdur ve durunca oturumu kaydet.
/// Not: süre arka planda kesintisiz sayılır (bkz. project.md §3.5).
class StudyTimerNotifier extends Notifier<StudyTimerState> {
  static const _uuid = Uuid();

  @override
  StudyTimerState build() => const StudyTimerState();

  /// Aktif dersi seçer (yalnızca sayaç dururken; null → derssiz).
  void selectSubject(String? subjectId) {
    if (state.isRunning) return;
    state = StudyTimerState(subjectId: subjectId);
  }

  /// Çalışmaya başla.
  void start() {
    if (state.isRunning) return;
    final now = DateTime.now();
    state = StudyTimerState(
        isRunning: true, startedAt: now, subjectId: state.subjectId);
    _publishPresence(status: PresenceStatus.studying, startedAt: now);
  }

  /// Durdur: süreyi kaydet, durumu çevrimdışına çek. Ders seçimi korunur.
  Future<void> stop() async {
    if (!state.isRunning) return;
    final startedAt = state.startedAt;
    final subjectId = state.subjectId;
    state = StudyTimerState(subjectId: subjectId);
    _publishPresence(status: PresenceStatus.offline, startedAt: null);
    if (startedAt != null) {
      await _recordSession(startedAt, DateTime.now(), subjectId);
    }
  }

  /// Tamamlanan bir aralığı `study_sessions`'a yazar.
  Future<void> _recordSession(
      DateTime start, DateTime end, String? subjectId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final duration = end.difference(start).inSeconds;
    if (duration <= 0) return;

    await ref.read(studyRepositoryProvider).addSession(
          StudySession(
            id: _uuid.v4(),
            userId: user.id,
            subjectId: subjectId,
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
