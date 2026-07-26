import 'package:flutter/widgets.dart';

import '../../core/tour/tour_models.dart';
import '../../l10n/app_localizations.dart';

/// WP-324: ürün yüzeylerinin kısa, sürümlü ve yerelleştirilmiş tur içerikleri.
///
/// Motor [TourDefinition] dışında ürün bilgisi taşımaz. Böylece metin, boş
/// durum ve hedef seçimi feature katmanında kalır.
abstract final class AppTours {
  static TourDefinition home(
    AppLocalizations l10n, {
    required GlobalKey dashboardAnchor,
    required GlobalKey editAnchor,
    required bool isEmpty,
  }) => TourDefinition(
    id: 'home',
    version: 1,
    steps: isEmpty
        ? [
            TourStep(
              id: 'empty',
              title: l10n.homeAnaSayfanBos,
              text: l10n.tourHomeEdit,
              anchor: editAnchor,
            ),
          ]
        : [
            TourStep(
              id: 'overview',
              title: l10n.homeAnaSayfa,
              text: l10n.tourHomeOverview,
              anchor: dashboardAnchor,
            ),
            TourStep(
              id: 'edit',
              title: l10n.homeKartlariDuzenle,
              text: l10n.tourHomeEdit,
              anchor: editAnchor,
            ),
          ],
  );

  static TourDefinition timer(
    AppLocalizations l10n, {
    required GlobalKey dashboardAnchor,
    required GlobalKey editAnchor,
    required bool isAvailable,
  }) => TourDefinition(
    id: 'timer',
    version: 1,
    steps: [
      TourStep(
        id: isAvailable ? 'overview' : 'missing',
        title: l10n.homeSayac,
        text: isAvailable ? l10n.tourTimerOverview : l10n.tourTimerMissing,
        anchor: isAvailable ? dashboardAnchor : editAnchor,
      ),
    ],
  );

  static TourDefinition groups(
    AppLocalizations l10n, {
    required GlobalKey contentAnchor,
    required GlobalKey switcherAnchor,
    required bool hasGroup,
  }) => TourDefinition(
    id: 'groups',
    version: 1,
    steps: [
      TourStep(
        id: hasGroup ? 'overview' : 'empty',
        title: l10n.desktopGruplar,
        text: hasGroup ? l10n.tourGroupsOverview : l10n.tourGroupsEmpty,
        anchor: contentAnchor,
      ),
      if (hasGroup)
        TourStep(
          id: 'switch',
          title: l10n.classroomGrupDegistir,
          text: l10n.tourGroupsSwitch,
          anchor: switcherAnchor,
        ),
    ],
  );

  static TourDefinition campfire(
    AppLocalizations l10n, {
    required GlobalKey? campfireAnchor,
    required bool hasGroup,
  }) => TourDefinition(
    id: 'campfire',
    version: 1,
    steps: [
      TourStep(
        id: hasGroup ? 'overview' : 'empty',
        title: l10n.coreKampAtesi,
        text: hasGroup ? l10n.tourCampfireOverview : l10n.tourCampfireEmpty,
        // Grup yokken sahnede bulunmayan bir öğeyi işaretleme.
        anchor: hasGroup ? campfireAnchor : null,
      ),
    ],
  );

  static TourDefinition stats(
    AppLocalizations l10n, {
    required GlobalKey periodAnchor,
    required bool hasSessions,
  }) => TourDefinition(
    id: 'stats',
    version: 1,
    steps: [
      TourStep(
        id: hasSessions ? 'overview' : 'empty',
        title: l10n.statsIstatistik,
        text: hasSessions ? l10n.tourStatsOverview : l10n.tourStatsEmpty,
        // Veri yokken dönem çubuğunu işaretlemek yerine neyin eksik olduğunu
        // ortadaki balonda açıkla.
        anchor: hasSessions ? periodAnchor : null,
      ),
    ],
  );

  static TourDefinition profile(
    AppLocalizations l10n, {
    required GlobalKey identityAnchor,
    required GlobalKey actionsAnchor,
  }) => TourDefinition(
    id: 'profile',
    version: 1,
    steps: [
      TourStep(
        id: 'identity',
        title: l10n.profileProfil,
        text: l10n.tourProfileOverview,
        anchor: identityAnchor,
      ),
      TourStep(
        id: 'actions',
        title: l10n.profileAyarlar,
        text: l10n.tourProfileActions,
        anchor: actionsAnchor,
      ),
    ],
  );
}
