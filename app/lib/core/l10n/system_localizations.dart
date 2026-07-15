import 'dart:ui';

import 'app_locale.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// BuildContext bulunmayan bildirim/widget arka planlarında sistem dilini,
/// uygulamanın EN/TR resolver sözleşmesiyle yükler.
Future<AppLocalizations> loadSystemLocalizations([Locale? requested]) {
  final resolved = resolvePreferredAppLocale(
    requested ?? PlatformDispatcher.instance.locale,
    AppLanguage.system,
  );
  return AppLocalizations.delegate.load(resolved);
}
