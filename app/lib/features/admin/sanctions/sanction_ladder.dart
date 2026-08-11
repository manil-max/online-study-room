import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-C (`docs/design/ADMIN-PANEL-PLAN.md` §2.3 / §5) — yaptirim basamaklarinin
/// **tek kanonik kaynagi**.
///
/// Sahibin sikayeti: *"banlama farkli yere gidiyorum herhalde"*. Olculdu ve
/// haklıydı: ayni is iki ayri listeyle yapiliyordu — UGC sekmesinde dokuz
/// basamak (`ModerationAction.values`), Kullanicilar sekmesinde elle yazilmis
/// bes basamak (`admin_users_tab.dart:19-25`). Iki liste demek, birine eklenen
/// basamagin otekinde **sessizce** eksik kalmasi demek.
///
/// Artik iki yuzey de buradan turer:
/// * [kAdminSanctionLadder] — tam katalog, sunucudaki siralamayla.
/// * [kAdminAccountRestrictionLadder] — hesaba dokunan (auth tarafina inen)
///   alt kume; Kullanicilar/kisi dosyasi yuzeyi bunu sunar.
///
/// Turetim `requiresAuthBan` uzerinden yapilir: alt kume elle sayilmaz, aksi
/// halde yine iki liste olurdu. `admin_sanction_surface_test.dart` hem turemeyi
/// hem de "kaynakta ikinci bir liste literali yok" kuralini olcer.
const List<ModerationAction> kAdminSanctionLadder = ModerationAction.values;

/// Hesabi kapatan basamaklar — [kAdminSanctionLadder]'dan **turetilir**.
final List<ModerationAction> kAdminAccountRestrictionLadder =
    List<ModerationAction>.unmodifiable(
      kAdminSanctionLadder.where((action) => action.requiresAuthBan),
    );

/// Basamagin kullaniciya gorunen adi. Iki yuzeyde iki ayri `switch` vardi;
/// etiket de tek yerden gelir.
String adminSanctionLabel(AppLocalizations l10n, ModerationAction action) =>
    switch (action) {
      ModerationAction.noAction => l10n.adminModerationSanctionNoAction,
      ModerationAction.warn => l10n.adminModerationSanctionWarn,
      ModerationAction.nameReset => l10n.adminModerationSanctionNameReset,
      ModerationAction.mute24h => l10n.adminModerationSanctionMute24h,
      ModerationAction.suspend24h => l10n.adminModerationSanctionSuspend24h,
      ModerationAction.suspend7d => l10n.adminModerationSanctionSuspend7d,
      ModerationAction.suspend14d => l10n.adminModerationSanctionSuspend14d,
      ModerationAction.suspend30d => l10n.adminModerationSanctionSuspend30d,
      ModerationAction.banPermanent => l10n.adminModerationSanctionBan,
    };

/// Yaptirimin durumu (gecmis satirinda okunur).
String adminSanctionStateLabel(
  AppLocalizations l10n,
  ModerationSanctionState state,
) => switch (state) {
  ModerationSanctionState.pending => l10n.adminSanctionStatePending,
  ModerationSanctionState.applied => l10n.adminModerationSanctionApplied,
  ModerationSanctionState.failed => l10n.adminSanctionStateFailed,
  ModerationSanctionState.revoked => l10n.adminModerationSanctionRevoked,
};

/// 🔴 Sahip karari (PLAN §6 S3, "ayrimli yaptirim"): geri alinabilen bir eylem
/// **teyit istemez** — teyit enflasyonu teyidi gorunmez yapar; onun yerine
/// 10 sn "Geri al" seridi cikar. Geri alinamayan eylem ise hedefin
/// e-postasini **yazdiran** sert teyit ister.
///
/// Suresi olan her basamak kendiliginden doldugu icin geri alinabilir sayilir;
/// suresiz olan tek kisitlayici basamak kalici yasaktir.
bool adminSanctionNeedsHardConfirm(ModerationAction action) =>
    action.isRestrictive && action.duration == null;
