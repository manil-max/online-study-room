import 'dart:ui';

import 'package:online_study_room/l10n/app_localizations.dart';

/// BuildContext bulunmayan bildirim/widget arka planlarında sistem dilini,
/// uygulamanın EN/TR resolver sözleşmesiyle yükler.
Future<AppLocalizations> loadSystemLocalizations([Locale? requested]) {
  final locale = requested ?? PlatformDispatcher.instance.locale;
  final resolved = locale.languageCode.toLowerCase() == 'tr'
      ? const Locale('tr')
      : const Locale('en');
  return AppLocalizations.delegate.load(resolved);
}
