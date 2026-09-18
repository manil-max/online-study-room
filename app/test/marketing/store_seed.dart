// WP-853 — mağaza kareleri için ÖRNEK hesap.
//
// Boş hesapla çekilen kare (sayaç 0s, boş grafik, boş hedef) mağaza sayfasında
// uygulamanın ne yaptığını göstermiyordu. Buradaki veri uygulamanın kendi
// modelleri ve sağlayıcı override'larıyla ekrana girer; ekran kodu (`lib/`)
// hiç değişmez.
//
// Kararlar:
// * **Saat sahtelenmez, veri "şimdi"ye göre üretilir.** Ekranlar (bugün
//   toplamı, hafta aralığı, gökyüzü) `DateTime.now()`u doğrudan okuyor; saati
//   enjekte etmek `lib/` değişikliği ister. Bu yüzden oturumlar çekim anına
//   göre geriye doğru dizilir. Aynı gün içindeki iki koşum aynı sayıları verir;
//   rastgelelik yok (sabit tablo).
// * Kişisel veri yok: adlar uydurmadır, kimlikler `store-` önekli.
// `Override` tipi ana pakette değil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tour/tour_prefs.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/achievement_provider.dart';
import 'package:online_study_room/data/providers/achievement_reward_provider.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/chat_providers.dart';
import 'package:online_study_room/data/providers/exam_countdown_providers.dart';
import 'package:online_study_room/data/providers/gamification_providers.dart';
import 'package:online_study_room/data/providers/global_timer_providers.dart';
import 'package:online_study_room/data/providers/goal_streak_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/notification_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/push_notification_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/providers/support_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_achievement_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_achievement_reward_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_analytics_query_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_chat_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_gamification_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_global_timer_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_goal_streak_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_notification_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_presence_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_push_registration_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_subject_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_support_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/tours/app_tours.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart' show GlobalKey;

/// Günlük hedef: 4 saat. Varsayılan 6 saat örnek hesapta bugünü yarıda
/// gösterirdi; 4 saat hem ulaşılabilir hem de bugünkü ilerlemeyi okunur kılar.
const int kStoreGoalMinutes = 240;

/// Canlı sayaç çekim anından bu kadar önce başlamış görünür.
const Duration kStoreLiveElapsed = Duration(minutes: 47, seconds: 12);

const _meId = 'store-me';
const _groupId = 'store-group';

/// Örnek hesabın tamamı. [StoreSeed.build] ile üretilir, override listesi
/// [StoreSeed.overrides] ile alınır.
class StoreSeed {
  StoreSeed._({
    required this.now,
    required this.me,
    required this.subjects,
    required this.sessions,
    required this.group,
    required this.members,
    required this.presence,
    required this.groupStats,
    required this.tasks,
  });

  final DateTime now;
  final Profile me;
  final List<Subject> subjects;
  final List<StudySession> sessions;
  final StudyGroup group;
  final List<Profile> members;
  final List<Presence> presence;
  final List<DailyStat> groupStats;
  final List<UserTask> tasks;

  /// Geçmiş günlerin toplamı (dakika), indeks = kaç gün önce (1 = dün).
  ///
  /// Son 11 gün hedefi (240 dk) tutturur → 11 günlük seri; 12. gün kaçar,
  /// öncesi inişli çıkışlı.
  static const List<int> _pastMinutes = [
    0, // bugün ayrıca kurulur
    265, 248, 302, 256, 281, 244, 318, 262, 251, 289, 247, // 1..11
    150, 205, 262, 178, 96, 231, 254, 140, 212, 186, // 12..21
  ];

  /// Oturum başlangıç saatleri (saat, dakika).
  static const List<(int, int)> _slots = [
    (9, 10),
    (11, 5),
    (14, 20),
    (16, 40),
    (20, 15),
  ];

  /// Parça sayısına göre kullanılan saatler: az parçalı günde oturumlar uzun
  /// olduğundan saatler aralıklı seçilir, oturumlar üst üste binmez.
  static const Map<int, List<int>> _slotsByParts = {
    2: [0, 3],
    3: [0, 2, 4],
    4: [0, 1, 3, 4],
    5: [0, 1, 2, 3, 4],
  };

  static StoreSeed build(DateTime now) {
    final me = Profile(
      id: _meId,
      displayName: 'Deniz',
      createdAt: now.subtract(const Duration(days: 60)),
      dailyGoalMinutes: kStoreGoalMinutes,
    );
    final subjects = [
      for (final (i, name) in const [
        'Matematik',
        'Fizik',
        'Türkçe',
        'İngilizce',
      ].indexed)
        Subject(
          id: 'store-subject-$i',
          userId: _meId,
          name: name,
          color: kSubjectColorTokens[i],
        ),
    ];

    final sessions = <StudySession>[];
    final today = DateTime(now.year, now.month, now.day);
    for (var daysAgo = 1; daysAgo < _pastMinutes.length; daysAgo++) {
      final day = today.subtract(Duration(days: daysAgo));
      var remaining = _pastMinutes[daysAgo];
      // Gün 2–5 oturuma bölünür; parça sayısı gün indeksinden türer.
      final parts = 2 + daysAgo % 4;
      for (var p = 0; p < parts && remaining > 0; p++) {
        final minutes = p == parts - 1
            ? remaining
            : (remaining / (parts - p)).round() + (p.isEven ? 7 : -7);
        final (h, m) = _slots[_slotsByParts[parts]![p]];
        final start = DateTime(day.year, day.month, day.day, h, m);
        sessions.add(
          _session(
            'store-s-$daysAgo-$p',
            subjects[(daysAgo + p) % subjects.length].id,
            start,
            minutes,
          ),
        );
        remaining -= minutes;
      }
    }

    // Bugün: canlı sayaçtan önce iki kayıtlı oturum (toplam 2 sa 35 dk). Çekim
    // sabahın erken saatine düşerse gece yarısını aşmamak için kırpılır.
    final liveStart = now.subtract(kStoreLiveElapsed);
    var cursor = liveStart.subtract(const Duration(minutes: 15));
    for (final (i, minutes) in const [(0, 85), (1, 70)].reversed) {
      final start = cursor.subtract(Duration(minutes: minutes));
      final clipped = start.isBefore(today) ? today : start;
      final length = cursor.difference(clipped).inMinutes;
      if (length >= 5) {
        sessions.add(
          _session('store-s-0-$i', subjects[i].id, clipped, length),
        );
      }
      cursor = clipped.subtract(const Duration(minutes: 20));
      if (!cursor.isAfter(today)) break;
    }
    sessions.sort((a, b) => b.start.compareTo(a.start));

    final group = StudyGroup(
      id: _groupId,
      name: 'YKS Sabah Kampı',
      inviteCode: 'KAMP24',
      createdBy: _meId,
      createdAt: now.subtract(const Duration(days: 45)),
      dailyGoalMinutes: kStoreGoalMinutes,
    );
    // Uydurma adlar; hayvanlar kimlikten deterministik türer.
    const others = [
      ('store-u1', 'Elif'),
      ('store-u2', 'Mert'),
      ('store-u3', 'Zeynep'),
      ('store-u4', 'Can'),
      ('store-u5', 'Ayşe'),
    ];
    final members = [
      me,
      for (final (id, name) in others)
        Profile(
          id: id,
          displayName: name,
          createdAt: now.subtract(const Duration(days: 40)),
          dailyGoalMinutes: kStoreGoalMinutes,
        ),
    ];

    final myTotals = <DateTime, int>{};
    for (final s in sessions) {
      final d = DateTime(s.start.year, s.start.month, s.start.day);
      myTotals[d] = (myTotals[d] ?? 0) + s.durationSeconds;
    }
    // Diğer üyelerin gün toplamı (dakika) — üye başına sabit taban + gün kayması.
    const baseMinutes = [210, 185, 260, 140, 230];
    final groupStats = <DailyStat>[
      for (var daysAgo = 0; daysAgo < 21; daysAgo++) ...[
        DailyStat(
          userId: _meId,
          day: today.subtract(Duration(days: daysAgo)),
          seconds: myTotals[today.subtract(Duration(days: daysAgo))] ?? 0,
        ),
        for (final (i, (id, _)) in others.indexed)
          DailyStat(
            userId: id,
            day: today.subtract(Duration(days: daysAgo)),
            // Bugün gün yarısında: diğerleri de tabanlarının ~yarısında.
            seconds: daysAgo == 0
                ? baseMinutes[i] * 60 ~/ 2
                : (baseMinutes[i] + ((daysAgo * 37 + i * 53) % 90) - 45) * 60,
          ),
      ],
    ];

    final presence = [
      Presence(
        userId: _meId,
        groupId: _groupId,
        status: PresenceStatus.studying,
        startedAt: liveStart,
        todaySeconds: myTotals[today] ?? 0,
        subjectId: subjects[0].id,
        updatedAt: now,
      ),
      Presence(
        userId: 'store-u1',
        groupId: _groupId,
        status: PresenceStatus.studying,
        startedAt: now.subtract(const Duration(minutes: 32)),
        todaySeconds: baseMinutes[0] * 60 ~/ 2,
        updatedAt: now,
      ),
      Presence(
        userId: 'store-u3',
        groupId: _groupId,
        status: PresenceStatus.studying,
        startedAt: now.subtract(const Duration(minutes: 64)),
        todaySeconds: baseMinutes[2] * 60 ~/ 2,
        updatedAt: now,
      ),
      Presence(
        userId: 'store-u2',
        groupId: _groupId,
        status: PresenceStatus.onBreak,
        startedAt: now.subtract(const Duration(minutes: 6)),
        todaySeconds: baseMinutes[1] * 60 ~/ 2,
        updatedAt: now,
      ),
    ];

    final tasks = [
      for (final (i, (title, done)) in const [
        ('Paragraf: 40 soru', true),
        ('Türev tekrar', false),
        ('Fizik deneme analizi', false),
      ].indexed)
        UserTask(
          id: 'store-task-$i',
          title: title,
          completed: done,
          completedAt: done ? now.subtract(const Duration(hours: 2)) : null,
          createdAt: now.subtract(const Duration(days: 1)),
          dueAt: DateTime(today.year, today.month, today.day, 23, 0),
          sortOrder: i,
          userId: _meId,
        ),
    ];

    return StoreSeed._(
      now: now,
      me: me,
      subjects: subjects,
      sessions: sessions,
      group: group,
      members: members,
      presence: presence,
      groupStats: groupStats,
      tasks: tasks,
    );
  }

  static StudySession _session(
    String id,
    String subjectId,
    DateTime start,
    int minutes,
  ) => StudySession(
    id: id,
    userId: _meId,
    subjectId: subjectId,
    start: start,
    end: start.add(Duration(minutes: minutes)),
    durationSeconds: minutes * 60,
    source: StudySource.manual,
  );

  /// Ardışık hedef günleri (dünden geriye). Bugün henüz tamamlanmadı.
  int get streakDays {
    var streak = 0;
    for (var daysAgo = 1; daysAgo < _pastMinutes.length; daysAgo++) {
      if (_pastMinutes[daysAgo] < kStoreGoalMinutes) break;
      streak++;
    }
    return streak;
  }

  int get lifetimeSeconds =>
      sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);

  /// Kazanılmış rozetler: 21 günlük geçmişle tutarlı, abartısız kademeler.
  List<UserAchievement> get achievements => [
    for (final (id, tier) in const [
      ('steel_will', 2),
      ('day_hero', 2),
      ('fire_streak', 1),
      ('marathon_total', 2),
      ('campfire_hours', 1),
      ('secret_night_owl', 1),
    ])
      UserAchievement(
        id: 'store-ach-$id',
        userId: _meId,
        achievementId: id,
        tier: tier,
        progress: tier,
        unlockedAt: now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
  ];

  GamificationProfile get gamification => GamificationProfile(
    userId: _meId,
    streakFreezes: 2,
    xp: 18450,
    crownRank: 'silver',
    selectedBadges: const ['fire_streak', 'day_hero', 'steel_will'],
    createdAt: now.subtract(const Duration(days: 60)),
    updatedAt: now,
  );

  /// Tanıtım turları görüldü sayılır: balon kareyi örtmesin. Anahtarlar
  /// uygulamanın kendi tur tanımlarından türer; sürüm artınca da doğru kalır.
  void markToursSeen(SharedPreferences prefs) {
    final l10n = AppLocalizationsTr();
    final definitions = [
      AppTours.home(l10n),
      AppTours.dashboardEdit(l10n),
      AppTours.stats(l10n),
      AppTours.settings(l10n),
      for (final hasGroup in const [true, false]) ...[
        AppTours.groups(
          l10n,
          contentAnchor: GlobalKey(),
          switcherAnchor: GlobalKey(),
          hasGroup: hasGroup,
        ),
        AppTours.campfire(l10n, campfireAnchor: null, hasGroup: hasGroup),
      ],
      AppTours.profile(
        l10n,
        identityAnchor: GlobalKey(),
        actionsAnchor: GlobalKey(),
      ),
    ];
    for (final d in definitions) {
      markTourSeen(prefs, storageId: d.storageId, userId: _meId);
    }
  }

  /// Tüm veri katmanı: depolar bellek-içi (env.json anahtarları verilse de
  /// Supabase'e gidilmez), okuma sağlayıcıları örnek veriyle.
  List<Override> overrides(SharedPreferences prefs) {
    final tasksRepo = InMemoryUserTaskRepository()
      ..saveAll(userKey: _meId, tasks: tasks);
    final gamificationRepo = InMemoryGamificationRepository()
      ..updateProfile(gamification)
      ..updateUserAchievements(achievements);
    final summary = UserStudySummary(
      lifetimeSeconds: lifetimeSeconds + 41 * 3600,
      yearSeconds: lifetimeSeconds + 41 * 3600,
      hotWindowSeconds: lifetimeSeconds,
    );
    return [
      sharedPreferencesProvider.overrideWithValue(prefs),

      // — depolar: hepsi bellek-içi —
      authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
      studyRepositoryProvider.overrideWithValue(InMemoryStudyRepository()),
      subjectRepositoryProvider.overrideWithValue(InMemorySubjectRepository()),
      groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
      presenceRepositoryProvider.overrideWithValue(
        InMemoryPresenceRepository(),
      ),
      userTaskRepositoryProvider.overrideWithValue(tasksRepo),
      gamificationRepositoryProvider.overrideWithValue(gamificationRepo),
      achievementRepositoryProvider.overrideWithValue(
        InMemoryAchievementRepository(),
      ),
      achievementRewardRepositoryProvider.overrideWithValue(
        InMemoryAchievementRewardRepository(),
      ),
      goalStreakRepositoryProvider.overrideWithValue(
        InMemoryGoalStreakRepository(),
      ),
      analyticsQueryRepositoryProvider.overrideWithValue(
        InMemoryAnalyticsQueryRepository(),
      ),
      adminRepositoryProvider.overrideWithValue(InMemoryAdminRepository()),
      chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
      moderationRepositoryProvider.overrideWithValue(
        InMemoryModerationRepository(),
      ),
      notificationRepositoryProvider.overrideWithValue(
        InMemoryNotificationRepository(),
      ),
      nudgeRepositoryProvider.overrideWithValue(
        InMemoryNudgeRepository(currentUserId: _meId),
      ),
      pushRegistrationRepositoryProvider.overrideWithValue(
        InMemoryPushRegistrationRepository(),
      ),
      supportRepositoryProvider.overrideWithValue(InMemorySupportRepository()),
      globalTimerRepositoryProvider.overrideWithValue(
        InMemoryGlobalTimerRepository(),
      ),
      examCountdownRepositoryProvider.overrideWithValue(null),

      // — okuma sağlayıcıları: örnek hesap —
      authStateProvider.overrideWith((ref) => Stream.value(me)),
      userSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
      userStudySummaryProvider.overrideWith((ref) async => summary),
      userSubjectsProvider.overrideWith((ref) => Stream.value(subjects)),
      userGroupsProvider.overrideWith((ref) => Stream.value([group])),
      primaryGroupPreferenceProvider.overrideWith(
        (ref) => Stream.value(
          const PrimaryGroupPreference(
            primaryGroupId: _groupId,
            selectionRevision: 1,
          ),
        ),
      ),
      groupMembersProvider.overrideWith((ref) => Stream.value(members)),
      groupMembersByIdProvider.overrideWith(
        (ref, groupId) => Stream.value(members),
      ),
      groupDailyStatsProvider.overrideWith((ref) => Stream.value(groupStats)),
      groupPresenceProvider.overrideWith((ref) => Stream.value(presence)),
      goalStreakProjectionProvider.overrideWith(
        (ref, scope) => Stream.value(
          GoalStreakProjection(
            scope: scope,
            asOfDay: DateTime(now.year, now.month, now.day),
            currentStreak: streakDays,
            completionCount: streakDays + 5,
            lastCompletedDay: DateTime(now.year, now.month, now.day - 1),
            state: GoalStreakState.pendingToday,
            sourceVersion: 'store-seed',
          ),
        ),
      ),
      // Rozetler elle tohumlandı; ilerleme eşitlemesi (yazma yolu) koşmasın,
      // yoksa kareye konfeti düşebilir.
      gamificationProgressSyncProvider.overrideWith((ref) async {}),

      // Sayaç koşuyor: 47 dk önce Matematik'le başlamış.
      studyTimerProvider.overrideWith(
        () => _FrozenRunningTimer(
          startedAt: now.subtract(kStoreLiveElapsed),
          subjectId: subjects[0].id,
        ),
      ),
    ];
  }
}

/// Koşan sayacı gösteren ama hiçbir yan etki (servis, bildirim, ağ) başlatmayan
/// sayaç. Üretim `build()`u geri yükleme/kanal dinleme yapar; kare için gereken
/// yalnız durumdur.
class _FrozenRunningTimer extends StudyTimerNotifier {
  _FrozenRunningTimer({required this.startedAt, required this.subjectId});

  final DateTime startedAt;
  final String subjectId;

  @override
  StudyTimerState build() => StudyTimerState(
    isRunning: true,
    startedAt: startedAt,
    subjectId: subjectId,
    lastUpdatedAt: startedAt,
  );
}
