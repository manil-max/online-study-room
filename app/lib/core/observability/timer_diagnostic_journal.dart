import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/app_prefs.dart';

/// WP-430: sayaç gerçeğinin **yerel uçuş kaydı** (flight recorder).
///
/// Neden var: v56 saha bulgularının dördü (ayna cihazdan durdurma, kendiliğinden
/// başlama şüphesi, aralıklı senkron ve sekiz saatlik hayalet koşu) "bazen
/// oluyor" sınıfındaydı ve elimizde olayın **hangi sırayla** olduğunu gösteren
/// tek bir kayıt yoktu. Bu sınıf o boşluğu kapatır: her sayaç geçişi
/// `reason + outcome + state_version/queue_age` bırakır.
///
/// 🔴 Bu bir çözüm değil, ölçüm aracıdır. Kök nedenler WP-431…433'te onarılır;
/// burada yalnız kanıt üretilir (`docs/qa/V57-TIMER-EVIDENCE.md`).
///
/// Gizlilik sözleşmesi (yapısal, "dikkat edelim" değil):
/// * Kayıt **cihazdan çıkmaz.** Telemetri açık olsa bile bu sınıf hiçbir
///   transport'a yazmaz; dışa aktarım yalnız kullanıcı isteğiyle
///   [TimerDiagnosticJournal.exportEntries] üzerinden olur.
/// * Ham hesap/koşu/ders/komut/cihaz kimliği **saklanmaz.** Kimlikler
///   [TimerJournalRef] ile kısa, tek yönlü ve kurulum-bazlı tuzlanmış özete
///   çevrilir; aynı oturumda aynı koşu izlenebilir, kimlik geri üretilemez.
/// * Serbest metin **kabul edilmez.** `reason`/`outcome`/`origin` alanları slug
///   allowlist'inden geçer; mesaj içeriği, e-posta, token buraya sızamaz.
/// * Kayıt döner ve TTL'lidir ([maxEntries] / [retention]).
@immutable
class TimerJournalEntry {
  const TimerJournalEntry({
    required this.at,
    required this.event,
    required this.reason,
    required this.outcome,
    this.origin = TimerJournalSlug.unknown,
    this.trigger = TimerJournalTriggers.unknown,
    this.accountRef = TimerJournalRef.absent,
    this.runRef = TimerJournalRef.absent,
    this.deviceRef = TimerJournalRef.absent,
    this.commandRef = TimerJournalRef.absent,
    this.runRevision,
    this.stateVersion,
    this.queueAgeMs,
    this.elapsedSeconds,
  });

  /// Olay anı (UTC). Sıralama ve TTL bunun üzerinden yürür.
  final DateTime at;

  /// Zaman çizelgesindeki geçiş adı (slug).
  final String event;

  /// Geçişin **nedeni** — hangi girdi bu geçişi doğurdu.
  final String reason;

  /// Geçişin **sonucu** — istek uygulandı mı, ertelendi mi, düşürüldü mü.
  final String outcome;

  /// Kanonik komut kaynağı (`app` / `widget` / `notification` / `recovery` /
  /// `mirror` / `unknown`).
  final String origin;

  /// WP-599: geçişi **tetikleyen yüzey** — "bunu gerçekten parmak mı yaptı".
  ///
  /// [origin] bu soruyu cevaplayamaz: bir Samsung Routine ya da ana ekran
  /// kısayolu sayacı başlattığında komutu yayınlayan yine uygulamadır, yani
  /// `origin=app` çıkar ve satır parmakla başlatmadan **ayırt edilemez**.
  /// Sahibin "sayacı gerçekten kardeşim mi başlattı" sorusu
  /// (`docs/analiz/WP-595-sayac-xp-teshis.md`) tam olarak bu yüzden
  /// cevapsız kaldı.
  ///
  /// Neden yeni **alan**, neden yeni bir `origin` değeri değil: `origin`
  /// sunucuyla paylaşılan kapalı bir sözlüktür — `0082_global_timer_v2.sql`
  /// `origin not in ('app','widget','notification','recovery')` görürse
  /// `invalid_global_timer_origin` fırlatır. Oraya yeni bir değer sokmak
  /// sunucu değişikliği ister; tanı alanı yüzünden komut zarfını riske atmak
  /// yanlış takas olurdu. [trigger] **yalnız cihazda kalan** günlük alanıdır.
  ///
  /// Geriye dönük okunabilirlik: WP-599 öncesi satırlarda bu alan yoktur →
  /// [TimerJournalTriggers.unknown] okunur. Okuyucu "bilinmiyor" görür,
  /// "kullanıcı" **görmez**; eski satırların hepsini parmağa yazmak, kapatmaya
  /// çalıştığımız açığı geçmişe doğru kalıcılaştırmak olurdu.
  final String trigger;

  final String accountRef;
  final String runRef;
  final String deviceRef;
  final String commandRef;

  final int? runRevision;
  final int? stateVersion;

  /// Komut/sinyal üretildiğinden bu yana geçen süre. "Bayat komut yeni koşu
  /// doğurdu" iddiası ancak bu alanla kanıtlanabilir.
  final int? queueAgeMs;

  /// Geçiş anında yüzeyde **görünen** süre. Hayalet koşuda görünen süre ile
  /// yazılan oturum arasındaki farkı bu alan ölçer.
  final int? elapsedSeconds;

  Map<String, Object> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'event': event,
    'reason': reason,
    'outcome': outcome,
    'origin': origin,
    'trigger': trigger,
    'account_ref': accountRef,
    'run_ref': runRef,
    'device_ref': deviceRef,
    'command_ref': commandRef,
    'run_revision': ?runRevision,
    'state_version': ?stateVersion,
    'queue_age_ms': ?queueAgeMs,
    'elapsed_seconds': ?elapsedSeconds,
  };

  static TimerJournalEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse(raw['at']?.toString() ?? '');
    final event = TimerJournalSlug.normalize(raw['event']);
    if (at == null || event == TimerJournalSlug.unknown) return null;
    int? number(String key) {
      final value = raw[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    String ref(String key) => TimerJournalRef.sanitize(raw[key]);

    return TimerJournalEntry(
      at: at.toUtc(),
      event: event,
      reason: TimerJournalSlug.normalize(raw['reason']),
      outcome: TimerJournalSlug.normalize(raw['outcome']),
      origin: TimerJournalSlug.normalize(raw['origin']),
      trigger: TimerJournalSlug.normalize(raw['trigger']),
      accountRef: ref('account_ref'),
      runRef: ref('run_ref'),
      deviceRef: ref('device_ref'),
      commandRef: ref('command_ref'),
      runRevision: number('run_revision'),
      stateVersion: number('state_version'),
      queueAgeMs: number('queue_age_ms'),
      elapsedSeconds: number('elapsed_seconds'),
    );
  }
}

/// Slug kapısı: sayısal/boolean olmayan her alan buradan geçer.
///
/// Serbest metin yerine kapalı bir sözlük kullanmak, "log'a bir de şu mesajı
/// yazayım" refleksini **yapısal olarak** imkânsız kılar.
abstract final class TimerJournalSlug {
  static const unknown = 'unknown';

  /// En fazla 48 karakter, yalnız küçük harf/rakam/alt çizgi.
  static final _pattern = RegExp(r'^[a-z0-9_]{1,48}$');

  static String normalize(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    if (value == null || value.isEmpty) return unknown;
    return _pattern.hasMatch(value) ? value : unknown;
  }
}

/// Kimlik referansı: tek yönlü, kısa ve **tuzlanmış** özet.
///
/// Tuz kurulum başına üretilir ve cihazda kalır; böylece iki farklı kurulumun
/// kayıtları birleştirilse bile aynı hesap eşleştirilemez, ama tek cihazın
/// kaydında "aynı koşu mu" sorusu yanıtlanabilir.
abstract final class TimerJournalRef {
  static const absent = 'none';
  static const saltKey = 'timer_journal_ref_salt_v1';
  static final _refPattern = RegExp(r'^[0-9a-f]{12}$');

  static String of(Object? raw, {required String salt}) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return absent;
    final digest = sha256.convert(utf8.encode('$salt|$value'));
    return digest.toString().substring(0, 12);
  }

  /// Diskten okunan bir referansın hâlâ özet biçiminde olduğunu doğrular.
  /// Biçimi bozuk değer ham kimlik olabilir → [absent]'e düşürülür.
  static String sanitize(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty || value == absent) return absent;
    return _refPattern.hasMatch(value) ? value : absent;
  }
}

/// Zaman çizelgesindeki geçiş adları. Diyagramla birebir eşleşir
/// (`docs/qa/V57-TIMER-EVIDENCE.md` §2).
abstract final class TimerJournalEvents {
  /// Kullanıcı/komut bir başlatma **istedi** (henüz sunucu otoritesi yok).
  static const startRequested = 'start_requested';

  /// Sunucu bir koşu kimliği verdi ya da mevcut koşuyu benimsetti.
  static const runIdentityAccepted = 'run_identity_accepted';

  /// Uzak koşu bu cihazda **projeksiyon** olarak açıldı (ayna). WP-491
  /// sonrası bu olay `origin=recovery` ile de gelebilir — o durumda hiçbir
  /// projeksiyon açılmaz, sunucudaki terk edilmiş kendi koşusu sessizce
  /// kapatılır; `origin` alanı ikisini ayırt eder.
  static const mirrorAdopted = 'mirror_adopted';

  /// Ayna cihazda durdurma isteği (yerel kapatma değil, global komut).
  static const mirrorStopRequested = 'mirror_stop_requested';

  /// Kullanıcı/komut durdurma istedi.
  static const stopRequested = 'stop_requested';

  /// Koşu bu cihazda gerçekten sonlandı (terminal geçiş).
  static const runTerminal = 'run_terminal';

  /// Sunucu snapshot'ı okundu ve bir talimata çevrildi.
  static const snapshotReconciled = 'snapshot_reconciled';

  /// Kuyruktaki V2 zarfı sunucuya yayınlandı (ya da yayınlanamadı).
  static const commandFlushed = 'command_flushed';

  /// Kira tazeleme turu.
  static const leaseHeartbeat = 'lease_heartbeat';

  /// Soğuk açılışta prefs'ten durum geri yüklendi.
  static const coldStartRestore = 'cold_start_restore';

  /// Bildirim/widget'ın bıraktığı tek-atımlık dış komut tüketildi.
  static const externalCommand = 'external_command';

  /// Uzak senkron sinyali (FCM) görüldü.
  static const syncSignal = 'sync_signal';

  /// Native SSOT ile Dart durumu uzlaştırıldı.
  static const nativeReconciled = 'native_reconciled';

  /// `study_sessions`'a gerçek bir oturum yazıldı (ya da yazılamadı).
  static const sessionRecorded = 'session_recorded';
}

/// Geçiş nedenleri (girdi) — "hangi olay bu geçişi doğurdu".
abstract final class TimerJournalReasons {
  static const userAction = 'user_action';

  /// WP-599: cihaz entegrasyonu (Samsung Routines / ana ekran kısayolu).
  /// Ekranda parmak YOK; `user_action` yazmak yalan olur.
  static const deviceIntegration = 'device_integration';
  static const notificationAction = 'notification_action';
  static const widgetAction = 'widget_action';
  static const externalCommandQueue = 'external_command_queue';
  static const remoteSnapshot = 'remote_snapshot';
  static const remoteSignal = 'remote_signal';
  static const nativeStoreIdle = 'native_store_idle';
  static const nativeStoreRunning = 'native_store_running';
  static const lifecycleResume = 'lifecycle_resume';
  static const coldStart = 'cold_start';
  static const periodicPoll = 'periodic_poll';
  static const phaseTarget = 'phase_target';
  static const queueReplay = 'queue_replay';
}

/// Geçiş sonuçları (çıktı) — "istek ne oldu".
abstract final class TimerJournalOutcomes {
  static const applied = 'applied';
  static const deferred = 'deferred';
  static const dropped = 'dropped';
  static const failed = 'failed';
  static const duplicate = 'duplicate';
  static const stale = 'stale';

  /// 🔴 Görünür koşu vardı ama karşılığında hiçbir oturum yazılmadı.
  /// Hayalet koşu iddiasının tek makine-okunur kanıtı budur.
  static const ghostNoSession = 'ghost_no_session';

  /// Sunucu otoritesi olmadan yalnız yerel yüzey kapatıldı.
  static const localOnly = 'local_only';
}

/// Kanonik komut kaynakları. Sunucu allowlist'i (`app|widget|notification|
/// recovery`) + yalnız tanı için ayna/bilinmeyen.
abstract final class TimerJournalOrigins {
  static const app = 'app';
  static const widget = 'widget';
  static const notification = 'notification';
  static const recovery = 'recovery';
  static const mirror = 'mirror';
  static const unknown = TimerJournalSlug.unknown;
}

/// WP-599: **tetikleyici yüzey** sözlüğü — "bu başlatmayı kim yaptı".
///
/// [TimerJournalOrigins] "komut hangi kanaldan yayınlandı" sorusunu yanıtlar ve
/// sunucuyla paylaşılır. Bu sözlük ise **çağrı yerini** adlandırır ve cihazdan
/// çıkmaz. İkisi dik: bir Samsung Routine başlatması `origin=app` +
/// `trigger=device_start_timer_warm` yazar.
abstract final class TimerJournalTriggers {
  /// WP-599 öncesi satırlar + kaynağını bildirmeyen çağrı yerleri.
  /// 🔴 "kullanıcı" ile eş anlamlı DEĞİLDİR.
  static const unknown = TimerJournalSlug.unknown;

  /// Ekrandaki Başlat/Durdur düğmesi — parmak.
  static const userButton = 'user_button';

  /// Uygulama kapalıyken bildirimden/widget'tan basılan düğmenin kuyruğu
  /// (`TimerExternalCommandStore`). Parmak vardır ama **uygulama içinde** değil.
  static const externalCommandQueue = 'external_command_queue';

  /// Uygulama AYAKTAYKEN kalıcı bildirimin Durdur düğmesi
  /// (`TimerNotificationAction.stop` akışı). Ekrandaki düğmeyle aynı
  /// satırı yazıyordu; "ekrandan mı bildirimden mi durdurdum" sorusu
  /// cevapsızdı.
  static const notificationButton = 'notification_button';

  /// Cihaz entegrasyonu tetikleyicilerinin ortak öneki.
  static const devicePrefix = 'device_';

  /// Cihaz entegrasyonu (App Shortcuts / Samsung Modes & Routines) aksiyonu.
  ///
  /// [action] intent adının kısa hâli (`start_timer`, `take_break`, …),
  /// [coldStart] uygulamanın o anda kapalı olup olmadığı: `cold` =
  /// `getInitialAction()` (süreç bu intentle doğdu), `warm` = `onIntentAction`
  /// (uygulama zaten açıktı). İkisini ayırmak şart, çünkü "uygulamayı hiç
  /// açmadım" diyen kullanıcının anlatısını yalnız `cold` doğrular.
  static String deviceIntegration({
    required String action,
    required bool coldStart,
  }) => TimerJournalSlug.normalize(
    '$devicePrefix${action}_${coldStart ? 'cold' : 'warm'}',
  );

  /// Bu tetikleyici ekrandaki bir parmağa mı ait — iki yönlü iddianın ölçütü.
  static bool isUserButton(String trigger) => trigger == userButton;

  /// Tetikleyicinin kanonik [TimerJournalReasons] karşılığı.
  ///
  /// `reason` ile `trigger`ın ayrı ayrı verilmesi, ikisinin birbirini
  /// yalanladığı satırlar üretirdi (bugünkü hata tam olarak bu: cihaz
  /// entegrasyonu `user_action` yazıyordu). Tek kaynak burasıdır.
  static String reasonFor(String trigger) {
    if (trigger == userButton) return TimerJournalReasons.userAction;
    if (trigger == externalCommandQueue) {
      return TimerJournalReasons.externalCommandQueue;
    }
    if (trigger == notificationButton) {
      return TimerJournalReasons.notificationAction;
    }
    if (trigger.startsWith(devicePrefix)) {
      return TimerJournalReasons.deviceIntegration;
    }
    return TimerJournalSlug.unknown;
  }
}

/// [SharedPreferences] üstünde dönen, TTL'li, PII'siz sayaç uçuş kaydı.
class TimerDiagnosticJournal {
  TimerDiagnosticJournal(this._prefs);

  final SharedPreferences _prefs;

  static const storageKey = 'timer_diagnostic_journal_v1';

  /// Halka tamponun üst sınırı. 240 kayıt, yoğun bir gün için yeterlidir ve
  /// prefs'i (tek satır JSON) makul boyutta tutar.
  static const maxEntries = 240;

  /// Kayıt penceresi. Sahibin "sabah kalktım sekiz saat görünüyordu" vakası bir
  /// gecelik; üç gün, olayı bildirmesi için de zaman bırakır.
  static const retention = Duration(hours: 72);

  String? _salt;

  /// Kurulum-bazlı tuz. Yoksa üretilir; üretimi tek seferliktir.
  String _ensureSalt() {
    final cached = _salt;
    if (cached != null) return cached;
    final stored = _prefs.getString(TimerJournalRef.saltKey)?.trim();
    if (stored != null && stored.length >= 16) {
      _salt = stored;
      return stored;
    }
    // Kimlik özetini geri çevirmeyi engellemek için tuzun tahmin edilemez
    // olması yeterlidir; kriptografik anahtar değildir.
    final seed = sha256
        .convert(
          utf8.encode(
            '${DateTime.now().microsecondsSinceEpoch}|'
            '${identityHashCode(this)}|${_prefs.getKeys().length}',
          ),
        )
        .toString();
    _salt = seed;
    _prefs.setString(TimerJournalRef.saltKey, seed);
    return seed;
  }

  /// Kimliği kayda uygun kısa özete çevirir.
  String ref(Object? rawIdentity) =>
      TimerJournalRef.of(rawIdentity, salt: _ensureSalt());

  List<TimerJournalEntry> _read() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?TimerJournalEntry.tryParse(item)];
    } catch (_) {
      // Bozuk kayıt tanı aracıdır, ürün verisi değil: sessizce sıfırlanır.
      return const [];
    }
  }

  /// Tek bir geçişi kaydeder.
  ///
  /// [reason] ve [outcome] **zorunludur**: nedeni ya da sonucu olmayan bir satır
  /// "log eklemek" olur, kanıt olmaz (WP-430 tuzağı).
  ///
  /// Kimlik alanları ham verilir; sınıf onları [ref] ile özetler.
  Future<void> record({
    required String event,
    required String reason,
    required String outcome,
    String origin = TimerJournalOrigins.unknown,
    String trigger = TimerJournalTriggers.unknown,
    Object? accountId,
    Object? runId,
    Object? deviceId,
    Object? commandId,
    int? runRevision,
    int? stateVersion,
    int? queueAgeMs,
    int? elapsedSeconds,
    DateTime? at,
  }) async {
    final entry = TimerJournalEntry(
      at: (at ?? DateTime.now()).toUtc(),
      event: TimerJournalSlug.normalize(event),
      reason: TimerJournalSlug.normalize(reason),
      outcome: TimerJournalSlug.normalize(outcome),
      origin: TimerJournalSlug.normalize(origin),
      trigger: TimerJournalSlug.normalize(trigger),
      accountRef: ref(accountId),
      runRef: ref(runId),
      deviceRef: ref(deviceId),
      commandRef: ref(commandId),
      runRevision: runRevision,
      stateVersion: stateVersion,
      queueAgeMs: queueAgeMs,
      elapsedSeconds: elapsedSeconds,
    );
    final pruned = prune([..._read(), entry], now: entry.at);
    await _prefs.setString(
      storageKey,
      jsonEncode([for (final item in pruned) item.toJson()]),
    );
  }

  /// TTL + halka tamponu birlikte uygular. Saf fonksiyon: test edilebilir.
  @visibleForTesting
  static List<TimerJournalEntry> prune(
    List<TimerJournalEntry> entries, {
    required DateTime now,
  }) {
    final cutoff = now.toUtc().subtract(retention);
    final fresh = [
      for (final entry in entries)
        if (!entry.at.isBefore(cutoff)) entry,
    ]..sort((left, right) => left.at.compareTo(right.at));
    if (fresh.length <= maxEntries) return fresh;
    return fresh.sublist(fresh.length - maxEntries);
  }

  /// Zaman sıralı kayıt. TTL dışı satırlar okunurken de gizlenir; böylece
  /// yazma olmayan bir cihazda bayat kayıt görünmez.
  List<TimerJournalEntry> entries({DateTime? now}) =>
      prune(_read(), now: now ?? DateTime.now());

  /// Kullanıcı isteğiyle destek dosyasına yazılabilir düz metin.
  /// Bu çağrı **ağ yapmaz**; nereye yazılacağına çağıran karar verir.
  String exportEntries({DateTime? now}) => const JsonEncoder.withIndent(
    '  ',
  ).convert([for (final entry in entries(now: now)) entry.toJson()]);

  Future<void> clear() async {
    await _prefs.remove(storageKey);
  }
}

/// WP-430: gunluk tek ornek. Sayac yollari bunu okur; test ortaminda
/// `sharedPreferencesProvider` override'i yeterlidir.
final timerDiagnosticJournalProvider = Provider<TimerDiagnosticJournal>(
  (ref) => TimerDiagnosticJournal(ref.watch(sharedPreferencesProvider)),
);
