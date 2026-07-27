import 'package:shared_preferences/shared_preferences.dart';

/// WP-340: Native'in tek `pendingIntervals` dizisine eklediği V2 global-timer
/// komutunun güvenli, ağdan bağımsız sözleşmesi.
///
/// Bu sınıf server apply yapmaz. Delivery C hazır olana kadar doğrulanmış kayıtlar
/// shadow/deferred kalır; yanlış veya hesabı belirsiz kayıtlar asla başka hesap
/// adına gönderilmez.
enum TimerV2CommandDisposition { notV2, deferred, quarantine, discard }

class TimerV2CommandEnvelope {
  const TimerV2CommandEnvelope({
    required this.commandId,
    required this.accountId,
    required this.installationId,
    required this.action,
    required this.clientOccurredAt,
    required this.origin,
    this.runId,
    this.expectedRunRevision,
  });

  static const kind = 'global_timer_command';

  /// WP-373: 2 → 3. `origin` sözlüğü değişti (bkz. [canonicalOrigins]); eski
  /// şemayla yazılmış zarflar sunucuda **hiçbir zaman** uygulanamaz, bu yüzden
  /// [tryParse] onları reddeder ve kuyruk temizleyici `discard` ile düşürür.
  static const schemaVersion = 3;
  static const accountIdKey = 'timer_v2_active_account_id';

  /// 🔴 **Sunucu allowlist'inin istemci aynası.** `apply_global_timer_command`
  /// bu kümenin dışındaki her değeri `invalid_global_timer_origin` ile reddeder
  /// (`supabase/migrations/0082_global_timer_v2.sql`). Kümeler ayrışırsa çoklu
  /// cihaz senkronu **sessizce** ölür — WP-373'ye kadar tam olarak bu oldu.
  ///
  /// Sözleşme `test/core/timer_v2_origin_contract_test.dart` ile üç uçtan
  /// (Kotlin üretici · bu sabit · migration) birlikte kilitlidir.
  static const canonicalOrigins = <String>{
    'app',
    'widget',
    'notification',
    'recovery',
  };

  /// Sunucunun kabul ettiği koşu kimliği. Dart yazar (apply başarılı olunca),
  /// native `stop` zarfını kurarken okur. Revision da **String** tutulur:
  /// Flutter `setInt` Android'de `putLong` üretir, native `getInt` ile okumak
  /// ClassCastException verir.
  static const runIdKey = 'timer_v2_run_id';
  static const runRevisionKey = 'timer_v2_run_revision';

  final String commandId;
  final String accountId;
  final String installationId;
  final String action;
  final DateTime clientOccurredAt;
  final String origin;
  final String? runId;
  final int? expectedRunRevision;

  static TimerV2CommandEnvelope? tryParse(Map<dynamic, dynamic> raw) {
    if (raw['kind'] != kind) return null;
    if (raw['schema_version'] != schemaVersion) return null;

    String? value(String key) {
      final rawValue = raw[key]?.toString().trim();
      return rawValue == null || rawValue.isEmpty ? null : rawValue;
    }

    final commandId = value('command_id');
    final accountId = raw['account_id']?.toString().trim() ?? '';
    final installationId = value('installation_id');
    final action = value('action');
    final occurredAt = DateTime.tryParse(value('client_occurred_at') ?? '');
    final origin = value('origin');
    if (commandId == null ||
        installationId == null ||
        occurredAt == null ||
        origin == null ||
        (action != 'start' && action != 'stop')) {
      return null;
    }

    // WP-373: sunucunun tanımadığı origin taşıyan zarf geçerli sayılmaz.
    // Böyle bir kayıt gönderilse exception alır ve kuyrukta kalıcı zehir olur;
    // `null` dönerek `discard` edilmesini ve kuyruktan düşmesini sağlıyoruz.
    if (!canonicalOrigins.contains(origin)) return null;

    final runId = value('run_id');
    final revision = raw['expected_run_revision'];
    final expectedRunRevision = switch (revision) {
      int value when value > 0 => value,
      num value when value > 0 && value == value.roundToDouble() =>
        value.toInt(),
      _ => null,
    };
    // WP-373: sunucu `stop` için ikisini de zorunlu tutar. Eksikse zarf en
    // baştan geçersizdir — denenip her turda patlamasındansa düşsün.
    if (action == 'stop' && (runId == null || expectedRunRevision == null)) {
      return null;
    }
    return TimerV2CommandEnvelope(
      commandId: commandId,
      accountId: accountId,
      installationId: installationId,
      action: action!,
      clientOccurredAt: occurredAt.toUtc(),
      origin: origin,
      runId: runId,
      expectedRunRevision: expectedRunRevision,
    );
  }
}

class TimerV2CommandFlushAdapter {
  const TimerV2CommandFlushAdapter();

  /// Auth state değiştikçe native writer'ın kullanacağı hesap bağını günceller.
  /// Queue kayıtları değiştirilmez: eski hesabın kayıtları karantinada kalır.
  Future<void> bindActiveAccount(SharedPreferences prefs, String? accountId) =>
      accountId == null || accountId.isEmpty
      ? prefs.remove(TimerV2CommandEnvelope.accountIdKey)
      : prefs.setString(TimerV2CommandEnvelope.accountIdKey, accountId);

  TimerV2CommandDisposition inspect(
    Map<dynamic, dynamic> raw, {
    required String? authenticatedAccountId,
  }) {
    if (raw['kind'] != TimerV2CommandEnvelope.kind) {
      return TimerV2CommandDisposition.notV2;
    }
    final command = TimerV2CommandEnvelope.tryParse(raw);
    if (command == null) return TimerV2CommandDisposition.discard;
    if (authenticatedAccountId == null ||
        authenticatedAccountId.isEmpty ||
        command.accountId != authenticatedAccountId) {
      return TimerV2CommandDisposition.quarantine;
    }
    return TimerV2CommandDisposition.deferred;
  }
}
