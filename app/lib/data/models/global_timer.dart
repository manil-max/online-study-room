import 'package:flutter/foundation.dart';

/// WP-342: V2 timer gerçeğinin legacy [LiveStudyRun]'dan ayrı, versioned taşıması.
@immutable
class GlobalTimerSnapshot {
  const GlobalTimerSnapshot({
    this.userId,
    required this.stateVersion,
    required this.serverTime,
    this.run,
    this.resultCode,
  });

  final String? userId;
  final int stateVersion;
  final DateTime serverTime;
  final GlobalTimerRun? run;
  final String? resultCode;

  factory GlobalTimerSnapshot.fromMap(Map<String, dynamic> map) {
    final rawRun = map['run'];
    return GlobalTimerSnapshot(
      userId: map['user_id'] as String?,
      stateVersion: (map['state_version'] as num?)?.toInt() ?? 0,
      serverTime:
          DateTime.tryParse(map['server_time']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      run: rawRun is Map
          ? GlobalTimerRun.fromMap(Map<String, dynamic>.from(rawRun))
          : null,
      resultCode: map['result_code'] as String?,
    );
  }
}

@immutable
class GlobalTimerRun {
  const GlobalTimerRun({
    required this.id,
    required this.status,
    required this.revision,
    this.effectiveStartedAt,
    this.leaseExpiresAt,
    this.leaseExpired = false,
    this.controllerDeviceId,
  });
  final String id;
  final String status;
  final int revision;
  final DateTime? effectiveStartedAt;

  /// WP-431 (K3): koşunun sunucudaki kira son tarihi.
  ///
  /// 🔴 WP-430 bulgusu: bu alan istemci sözleşmesinde **hiç yoktu**. Sunucu
  /// snapshot'ta gönderiyor olsa bile `fromMap` onu düşürüyordu; ayna cihaz
  /// kirası çoktan dolmuş bir koşuyu "çalışıyor" diye açabiliyordu (V56-S04).
  final DateTime? leaseExpiresAt;

  /// Sunucunun okuma anında hesapladığı gerçek: controller heartbeat'i gecikti mi?
  ///
  /// İstemci saatine güvenmeyiz — süpürücü (`0089`) ile snapshot arasındaki
  /// yarışta doğru cevap sunucununkidir (`0101`).
  final bool leaseExpired;

  /// Koşunun kirasını en son tazeleyen cihaz. Bu cihaz `origin_device_id` ile
  /// eşleşiyorsa yerel rol `source`, eşleşmiyorsa `mirror`'dır.
  final String? controllerDeviceId;

  factory GlobalTimerRun.fromMap(Map<String, dynamic> map) => GlobalTimerRun(
    id: map['id'] as String,
    status: map['status'] as String,
    revision: (map['run_revision'] as num?)?.toInt() ?? 1,
    effectiveStartedAt: DateTime.tryParse(
      map['effective_started_at']?.toString() ?? '',
    )?.toLocal(),
    leaseExpiresAt: DateTime.tryParse(
      map['lease_expires_at']?.toString() ?? '',
    )?.toUtc(),
    // Sunucu `0101`den itibaren bunu hesaplayıp gönderir. Alan yoksa (eski
    // şema) `false` kalır ve karar yalnız yaş sınırına düşer — fail-safe.
    leaseExpired: map['lease_expired'] == true,
    controllerDeviceId: map['controller_device_id']?.toString(),
  );

  /// Bu koşu bu cihazda **canlı** olarak gösterilebilir mi?
  ///
  /// [maxRunAge]: sunucu saatine göre bir koşunun makul üst yaşı. Kısa kira
  /// controller tazeliğini ölçer; açık çalışma niyetini ancak recovery grace
  /// aşıldığında terminal sayarız. Yaş sınırı ikinci fail-safe'tir.
  bool isDisplayableAt(DateTime serverTime, {Duration? maxRunAge}) {
    if (status != 'running') return false;
    final startedAt = effectiveStartedAt;
    if (startedAt == null) return false;
    // Android foreground service calisirken Dart isolate'i askiya alinabilir.
    // Kisa lease gecikmesi acik calismayi kapatmaz; yalniz hard-abandonment
    // penceresini asan gecikme hayalet kosu olarak reddedilir.
    if (leaseExpired) {
      final lease = leaseExpiresAt;
      if (lease == null) return false;
      final leaseDelay = serverTime.toUtc().difference(lease.toUtc());
      if (leaseDelay > kGlobalTimerLeaseRecoveryGrace) return false;
    }
    final limit = maxRunAge ?? kGlobalTimerMaxMirrorRunAge;
    return !serverTime.toUtc().difference(startedAt.toUtc()).isNegative &&
        serverTime.toUtc().difference(startedAt.toUtc()) <= limit;
  }
}

/// WP-431 (K2): bir ayna koşusunun sorgusuz benimsenebileceği üst yaş.
///
/// Sunucu tazelik kirası 150 sn'dir; sağlıklı bir koşu bu pencerede sürekli
/// tazelenir. 12 saat, "gerçekten uzun bir çalışma seansı" ile
/// "gece boyu unutulmuş hayalet koşu" arasındaki ürün sınırıdır: sahibin
/// bildirdiği vaka ~8 saatti ve **kayıt üretmemişti**.
const kGlobalTimerMaxMirrorRunAge = Duration(hours: 12);

/// Heartbeat gecikince acik calismayi kurtarmak icin taninan ust pencere.
/// Sunucu supurucusu de ayni esikle terminal `abandoned` karari verir.
const kGlobalTimerLeaseRecoveryGrace = Duration(hours: 12);

/// Uzak snapshot'ın yerel sayaç durumuna göre güvenli uygulanabilir sonucu.
/// Sinyal yalnız tetikleyicidir; bu karar her zaman doğrulanmış snapshot'tan gelir.
enum GlobalTimerForegroundDirectiveKind {
  mirrorStart,
  mirrorStop,
  deferred,

  /// WP-431 (K2): sunucu koşuyu `running` diyor ama koşu güvenle
  /// gösterilemiyor (kira dolmuş ya da yaş sınırı aşılmış). Yerel yüzey
  /// **canlı sayaç açmaz**; kullanıcıya uzlaştırma gerektiği gösterilir.
  needsReconcile,

  /// WP-491: sunucu `running` diyor, koşu gösterilebilir **ve** koşunun
  /// `controllerDeviceId`'i bu cihazın kendi kimliğiyle eşleşiyor — yani
  /// başka bir cihaz yok, bu cihazın dünkü Durdur'u sunucuya ulaşmamış
  /// (bkz. `docs/qa/V58-GHOST-RUN-DIAGNOSIS.md`). Canlı sayaç AÇILMAZ,
  /// kullanıcıya yanlış "diğer cihazdaki kronometre durdurulacak" diyaloğu
  /// gösterilmez; koşu sessizce sunucuda kapatılır.
  staleOwnRunCleanup,
}

class GlobalTimerForegroundDirective {
  const GlobalTimerForegroundDirective({
    required this.kind,
    required this.snapshot,
  });

  final GlobalTimerForegroundDirectiveKind kind;
  final GlobalTimerSnapshot snapshot;
}

GlobalTimerForegroundDirective planGlobalTimerForegroundApply({
  required GlobalTimerSnapshot snapshot,
  required bool localRunning,
  required bool localIsMirror,
  required String? localMirrorRunId,
  String? myDeviceId,
  Duration? maxRunAge,
}) {
  final run = snapshot.run;
  if (run != null && run.status == 'running') {
    final displayable = run.isDisplayableAt(
      snapshot.serverTime,
      maxRunAge: maxRunAge,
    );
    // WP-431 (K2 · V56-S04): kirası dolmuş ya da yaşı sınırı aşmış koşu
    // AYNALANMAZ. Eskiden burada tek koşul `effectiveStartedAt != null` idi ve
    // sekiz saatlik ölü bir koşu sorgusuz canlı sayaç açıyordu.
    if (!displayable) {
      // Bu cihaz o ölü koşuyu zaten aynalıyorsa önce onu kapatmak gerekir;
      // aksi halde hayalet sayaç ekranda kalır.
      if (localRunning && localIsMirror && localMirrorRunId == run.id) {
        return GlobalTimerForegroundDirective(
          kind: GlobalTimerForegroundDirectiveKind.mirrorStop,
          snapshot: snapshot,
        );
      }
      return GlobalTimerForegroundDirective(
        kind: GlobalTimerForegroundDirectiveKind.needsReconcile,
        snapshot: snapshot,
      );
    }
    if (!localRunning) {
      // WP-491: `controllerDeviceId` bu cihazın kendi kimliğiyle eşleşiyorsa
      // gerçek bir ayna yok — bu cihazın kendi dünkü koşusu sunucuda kapanmadan
      // kalmış demektir. Başka cihaz olmadan "diğer cihaz" diyaloğu açmak
      // yanıltıcıdır; sessiz temizlik dalına yönlendirilir.
      final isOwnDevice =
          myDeviceId != null &&
          myDeviceId.isNotEmpty &&
          run.controllerDeviceId != null &&
          run.controllerDeviceId == myDeviceId;
      return GlobalTimerForegroundDirective(
        kind: isOwnDevice
            ? GlobalTimerForegroundDirectiveKind.staleOwnRunCleanup
            : GlobalTimerForegroundDirectiveKind.mirrorStart,
        snapshot: snapshot,
      );
    }
  }
  // Eski ya da başka bir koşuya ait stop, kullanıcının yeni yerel koşusuna
  // dokunamaz. Yalnız aynı mirror run güvenle kapatılır.
  if (run == null &&
      localRunning &&
      localIsMirror &&
      localMirrorRunId != null) {
    return GlobalTimerForegroundDirective(
      kind: GlobalTimerForegroundDirectiveKind.mirrorStop,
      snapshot: snapshot,
    );
  }
  return GlobalTimerForegroundDirective(
    kind: GlobalTimerForegroundDirectiveKind.deferred,
    snapshot: snapshot,
  );
}

/// WP-431: bu cihazın koşu üzerindeki rolü.
///
/// Rol **native state'te açıkça saklanır** (`flutter.timer_v2_controller_role`).
/// Eskiden rol yalnız Dart `state.isGlobalTimerMirror` alanında yaşıyordu;
/// native taraf (bildirim/widget Durdur'u) onu göremediği için ayna cihazda hem
/// yanlış oturum yazıyor hem de sunucuya durdurma komutu üretemiyordu (V56-S01).
enum TimerControllerRole {
  /// Koşuyu bu cihaz başlattı; oturum muhasebesi buradadır.
  source,

  /// Koşu başka cihaza ait; bu cihaz yalnız projeksiyondur.
  mirror;

  static const prefsKey = 'timer_v2_controller_role';

  static TimerControllerRole parse(String? raw) =>
      raw?.trim() == mirror.name ? mirror : source;
}

/// Durdurma niyetinin **tek** karar sonucu.
@immutable
class TimerStopPlan {
  const TimerStopPlan({
    required this.role,
    required this.emitServerCommand,
    required this.recordLocalInterval,
    required this.runId,
    required this.expectedRunRevision,
    required this.blockedReason,
  });

  final TimerControllerRole role;

  /// Sunucuya CAS `stop` komutu üretilecek mi?
  final bool emitServerCommand;

  /// Yerel `timer_pending_intervals` kuyruğuna tamamlanmış aralık yazılacak mı?
  /// Ayna için **her zaman false**: projeksiyon oturum üretmez.
  final bool recordLocalInterval;

  final String? runId;
  final int? expectedRunRevision;

  /// Komut üretilemiyorsa nedeni (tanı kaydı için slug). Üretilebiliyorsa null.
  final String? blockedReason;
}

/// WP-431: uygulama içi / bildirim / widget Durdur'unun **tek** karar noktası.
///
/// 🔴 Neden tek fonksiyon: v56'da üç giriş üç ayrı davranıyordu. Uygulama içi
/// Durdur `stopMirroredRun()` ile gerçek CAS komutu üretiyor, bildirim ve widget
/// ise native `handleStop`'a düşüp (a) sunucuya hiçbir şey göndermiyor,
/// (b) ayna cihazda uydurma bir yerel aralık yazıyordu. Kural artık girişten
/// değil **rolden** türer.
///
/// [wasWorkPhase]: mola durdurmaları oturum üretmez (mevcut semantik korunur).
TimerStopPlan planTimerStop({
  required TimerControllerRole role,
  required String? runId,
  required int? expectedRunRevision,
  required bool wasWorkPhase,
  bool isSilentAppStop = false,
}) {
  final hasIdentity =
      runId != null &&
      runId.trim().isNotEmpty &&
      expectedRunRevision != null &&
      expectedRunRevision >= 1;
  if (role == TimerControllerRole.mirror) {
    return TimerStopPlan(
      role: role,
      emitServerCommand: hasIdentity,
      // Ayna asla yerel oturum üretmez — kimliği olsa da olmasa da.
      recordLocalInterval: false,
      runId: hasIdentity ? runId : null,
      expectedRunRevision: hasIdentity ? expectedRunRevision : null,
      blockedReason: hasIdentity ? null : 'mirror_identity_missing',
    );
  }
  return TimerStopPlan(
    role: role,
    emitServerCommand: true,
    // Uygulama içi Durdur'da oturumu Dart yazar; native kuyruğa yazarsa çift
    // kayıt olur (mevcut `STOP_SILENT` semantiği korunur).
    recordLocalInterval: wasWorkPhase && !isSilentAppStop,
    runId: hasIdentity ? runId : null,
    expectedRunRevision: hasIdentity ? expectedRunRevision : null,
    // Kaynak cihaz kimliksizse komut yine üretilir: çevrimdışı başlatılmış bir
    // koşunun terminal niyeti `deferred_until_run_identity` ile korunur.
    blockedReason: hasIdentity ? null : 'deferred_until_run_identity',
  );
}
