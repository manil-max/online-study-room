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
  static const schemaVersion = 2;
  static const accountIdKey = 'timer_v2_active_account_id';

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

    final revision = raw['expected_run_revision'];
    final expectedRunRevision = switch (revision) {
      int value when value > 0 => value,
      num value when value > 0 && value == value.roundToDouble() =>
        value.toInt(),
      _ => null,
    };
    return TimerV2CommandEnvelope(
      commandId: commandId,
      accountId: accountId,
      installationId: installationId,
      action: action!,
      clientOccurredAt: occurredAt.toUtc(),
      origin: origin,
      runId: value('run_id'),
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
