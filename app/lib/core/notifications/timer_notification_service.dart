import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../l10n/system_localizations.dart';
import '../utils/duration_format.dart';

final timerNotificationServiceProvider = Provider<TimerNotificationGateway>(
  (ref) => TimerNotificationService.instance,
);

enum TimerNotificationAction { open, stop, start }

abstract interface class TimerNotificationGateway {
  Stream<TimerNotificationAction> get commands;

  Future<void> requestPermissionIfNeeded();

  Future<void> showRunning(TimerNotificationSnapshot snapshot);

  Future<void> cancel();
}

@immutable
class TimerNotificationSnapshot {
  const TimerNotificationSnapshot({
    required this.title,
    required this.modeLabel,
    required this.phaseLabel,
    required this.startedAt,
    required this.elapsedSeconds,
    required this.remainingSeconds,
    required this.isCountingDown,
    required this.isRunning,
    this.progress,
    this.progressMax,
  });

  final String title;
  final String modeLabel;
  final String phaseLabel;
  final DateTime startedAt;
  final int elapsedSeconds;
  final int? remainingSeconds;
  final bool isCountingDown;
  final bool isRunning;
  final int? progress;
  final int? progressMax;

  bool get hasProgress =>
      progressMax != null &&
      progressMax! > 0 &&
      progress != null &&
      progress! >= 0;

  String body(AppLocalizations l10n) {
    // Geçen/kalan süre bildirim başlığındaki CANLI kronometre (usesChronometer)
    // ile saat gibi (HH:MM:SS) tikleyerek gösterilir. Gövdeye sabit bir sayı
    // yazmayız; yoksa bildirim tekrar push edilmediği için "0 sn"de takılır.
    if (remainingSeconds == null) {
      return '$modeLabel · ${l10n.commonCalsyor}';
    }
    return phaseLabel;
  }

  String expandedBody(AppLocalizations l10n) {
    final elapsed = formatHms(elapsedSeconds);
    final remaining = remainingSeconds == null
        ? null
        : formatHms(remainingSeconds!);
    final lines = [title, modeLabel, phaseLabel, elapsed];
    if (remaining != null) lines.add(remaining);
    lines.add(l10n.coreDurdurmakIcinBildirimdekiDurdur);
    return lines.join('\n');
  }
}

@pragma('vm:entry-point')
void timerNotificationBackgroundHandler(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final command = response.actionId == 'stop_timer'
      ? 'stop'
      : response.actionId == 'start_timer'
      ? 'start'
      : null;
  if (command == null) return;
  var sequence = 1;
  try {
    final raw = prefs.getString('timer_external_command');
    sequence =
        ((jsonDecode(raw ?? '{}') as Map<String, dynamic>)['sequence']
                as int? ??
            0) +
        1;
  } catch (_) {}
  await prefs.setString(
    'timer_external_command',
    jsonEncode({'command': command, 'sequence': sequence}),
  );
}

class TimerNotificationService implements TimerNotificationGateway {
  TimerNotificationService._(this._plugin);

  static final instance = TimerNotificationService._(
    FlutterLocalNotificationsPlugin(),
  );

  static const int _notificationId = 7001;
  // Yeni kanal id: eski `study_timer_ongoing` LOW importance ile oluşturulmuştu ve
  // Android kanal importance'ını kilitler (koddan değiştirmek etkisizdir). Canlı
  // kronometreli bildirim düz servis bildiriminin altında gizli kalıyordu → yeni
  // kanal + DEFAULT importance ile baskın/görünür yapılır.
  static const String _channelId = 'study_timer_live';
  static const String _stopActionId = 'stop_timer';
  static const String _startActionId = 'start_timer';

  static final _commands =
      StreamController<TimerNotificationAction>.broadcast();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Stream<TimerNotificationAction> get commands => _commands.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: dispatchResponse,
      onDidReceiveBackgroundNotificationResponse:
          timerNotificationBackgroundHandler,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        response != null) {
      dispatchResponse(response);
    }

    _initialized = true;
  }

  @override
  Future<void> requestPermissionIfNeeded() async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> showRunning(TimerNotificationSnapshot snapshot) async {
    if (!_isAndroid) return;
    await initialize();
    final l10n = await loadSystemLocalizations();

    final details = AndroidNotificationDetails(
      _channelId,
      l10n.clockCalismaSayaci,
      channelDescription: l10n.coreCalismaSayaciCalisirkenGosterilen,
      // DEFAULT: kronometreli bildirim tepside görünür ve düz FGS bildiriminin
      // ÜSTÜNDE durur. Sürekli çalışan sayaç bildirimi olduğu için ses/titreşim
      // KAPALI (görünür ama sessiz); onlyAlertOnce ek güvence.
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: _chronometerWhen(snapshot),
      usesChronometer: true,
      chronometerCountDown: snapshot.isCountingDown,
      category: AndroidNotificationCategory.progress,
      visibility: NotificationVisibility.public,
      showProgress: snapshot.hasProgress,
      maxProgress: snapshot.progressMax ?? 0,
      progress: snapshot.progress ?? 0,
      actions: [
        AndroidNotificationAction(
          snapshot.isRunning ? _stopActionId : _startActionId,
          snapshot.isRunning ? l10n.profileDurdur : l10n.desktopBaslat,
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    );

    await _plugin.show(
      id: _notificationId,
      title: l10n.coreOdakKampi,
      body: snapshot.body(l10n),
      notificationDetails: NotificationDetails(android: details),
      payload: 'timer:toggle',
    );
  }

  @override
  Future<void> cancel() async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancel(id: _notificationId);
  }

  @visibleForTesting
  static void dispatchResponse(NotificationResponse response) {
    if (response.actionId == _stopActionId) {
      _commands.add(TimerNotificationAction.stop);
      return;
    }
    _commands.add(TimerNotificationAction.open);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  int _chronometerWhen(TimerNotificationSnapshot snapshot) {
    if (snapshot.isCountingDown && snapshot.remainingSeconds != null) {
      return DateTime.now()
          .add(Duration(seconds: snapshot.remainingSeconds!))
          .millisecondsSinceEpoch;
    }
    return snapshot.startedAt.millisecondsSinceEpoch;
  }
}
