import '../../data/repositories/nudge_repository.dart';
import '../../l10n/app_localizations.dart';

/// WP-477: `NudgeErrorCode` → kullanıcı metni.
///
/// Çeviri **burada** yapılır çünkü repository katmanı `AppLocalizations`
/// göremez. Tek eşleme noktası olması bilinçli: dürtme hatası iki ekranda
/// gösteriliyor (grup detayı ve susturulanlar listesi) ve ikisi ayrışırsa
/// aynı hata iki farklı cümle üretir.
extension NudgeErrorText on NudgeException {
  String localize(AppLocalizations l10n) => switch (code) {
    NudgeErrorCode.cooldown => l10n.nudgeErrorCooldown(
      kNudgeCooldown.inMinutes,
    ),
    NudgeErrorCode.recipientIsStudying =>
      l10n.classroomStudyingNudgeUnavailable,
    NudgeErrorCode.cannotNudgeSelf => l10n.commonKendineDurtmeGonderemezsin,
    NudgeErrorCode.notGroupMember => l10n.commonBuGruptaDurtmeGonderme,
    NudgeErrorCode.blocked => l10n.nudgeErrorBlocked,
    NudgeErrorCode.messageTooLong => l10n.commonDurtmeNotuEnFazla,
    NudgeErrorCode.cannotMuteSelf => l10n.nudgeErrorCannotMuteSelf,
    NudgeErrorCode.sendFailed => l10n.nudgeErrorSendFailed,
    NudgeErrorCode.markReadFailed => l10n.nudgeErrorMarkReadFailed,
    NudgeErrorCode.mutesUnavailable => l10n.nudgeErrorMutesUnavailable,
    NudgeErrorCode.muteSaveFailed => l10n.nudgeErrorMuteSaveFailed,
  };
}
