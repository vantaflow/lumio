import 'package:flutter/widgets.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';

export 'package:lumio/l10n/app_localizations.dart';

/// Langues proposées dans l'interface (français par défaut).
const supportedUiLocales = [Locale('fr'), Locale('en')];

extension L10nContext on BuildContext {
  /// Textes traduits ; repli sur le français hors d'une application
  /// localisée (widgets testés isolément).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsFr();
}
