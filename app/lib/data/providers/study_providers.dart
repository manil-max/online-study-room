import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/study_session.dart';
import '../repositories/study_repository.dart';
import '../repositories/in_memory/in_memory_study_repository.dart';
import 'auth_providers.dart';
import 'group_providers.dart';

/// Aktif StudyRepository. Şimdilik bellek-içi; Supabase'de değiştirilecek.
final studyRepositoryProvider = Provider<StudyRepository>((ref) {
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

/// Çalışma sayacının durumu.
class StudyTimerState {
  const StudyTimerState({this.isRunning = false, this.startedAt});
  final bool isRunning;
  final DateTime? startedAt;
}

/// Çalışma sayacını yönetir: başlat/durdur ve durunca oturumu kaydet.
/// Not: süre arka planda kesintisiz sayılır (bkz. project.md §3.5).
class StudyTimerNotifier extends Notifier<StudyTimerState> {
  static const _uuid = Uuid();

  @override
  StudyTimerState build() => const StudyTimerState();

  void start() {
    if (state.isRunning) return;
    state = StudyTimerState(isRunning: true, startedAt: DateTime.now());
  }

  Future<void> stop() async {
    final startedAt = state.startedAt;
    if (!state.isRunning || startedAt == null) return;
    final end = DateTime.now();
    state = const StudyTimerState();

    final user = ref.read(authStateProvider).value;
    final group = ref.read(userGroupProvider).value;
    if (user == null || group == null) return;

    final duration = end.difference(startedAt).inSeconds;
    if (duration <= 0) return;

    await ref.read(studyRepositoryProvider).addSession(
          StudySession(
            id: _uuid.v4(),
            userId: user.id,
            groupId: group.id,
            start: startedAt,
            end: end,
            durationSeconds: duration,
            source: StudySource.live,
          ),
        );
  }
}

final studyTimerProvider =
    NotifierProvider<StudyTimerNotifier, StudyTimerState>(
        StudyTimerNotifier.new);
