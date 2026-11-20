import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @continueAction.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueAction;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @paste.
  ///
  /// In fr, this message translates to:
  /// **'Coller'**
  String get paste;

  /// No description provided for @install.
  ///
  /// In fr, this message translates to:
  /// **'Installer'**
  String get install;

  /// No description provided for @done.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get done;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement'**
  String get loading;

  /// No description provided for @show.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get hide;

  /// No description provided for @moveUp.
  ///
  /// In fr, this message translates to:
  /// **'Monter'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In fr, this message translates to:
  /// **'Descendre'**
  String get moveDown;

  /// No description provided for @homeSearch.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get homeSearch;

  /// No description provided for @homeManageList.
  ///
  /// In fr, this message translates to:
  /// **'Gérer ma liste'**
  String get homeManageList;

  /// No description provided for @homeCustomize.
  ///
  /// In fr, this message translates to:
  /// **'Personnaliser'**
  String get homeCustomize;

  /// No description provided for @homeSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get homeSettings;

  /// No description provided for @homeAddonsError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos addons'**
  String get homeAddonsError;

  /// No description provided for @homeNoCatalog.
  ///
  /// In fr, this message translates to:
  /// **'Vos addons ne proposent aucun catalogue'**
  String get homeNoCatalog;

  /// No description provided for @homeNoAddons.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un addon ou une source personnelle pour remplir votre accueil.'**
  String get homeNoAddons;

  /// No description provided for @homeManageAddons.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les addons'**
  String get homeManageAddons;

  /// No description provided for @homeFiltered.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contenu adapté à ce profil'**
  String get homeFiltered;

  /// No description provided for @homeRowFailed.
  ///
  /// In fr, this message translates to:
  /// **'Chargement impossible'**
  String get homeRowFailed;

  /// No description provided for @myList.
  ///
  /// In fr, this message translates to:
  /// **'Ma liste'**
  String get myList;

  /// No description provided for @continueWatching.
  ///
  /// In fr, this message translates to:
  /// **'Continuer à regarder'**
  String get continueWatching;

  /// No description provided for @sourceLocal.
  ///
  /// In fr, this message translates to:
  /// **'Local'**
  String get sourceLocal;

  /// No description provided for @sourceAddon.
  ///
  /// In fr, this message translates to:
  /// **'addon'**
  String get sourceAddon;

  /// No description provided for @resumeSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre {title}'**
  String resumeSemantic(Object title);

  /// No description provided for @itemSemantic.
  ///
  /// In fr, this message translates to:
  /// **'{name}, {source}'**
  String itemSemantic(Object name, Object source);

  /// No description provided for @itemSemanticYear.
  ///
  /// In fr, this message translates to:
  /// **'{name}, {year}, {source}'**
  String itemSemanticYear(Object name, Object year, Object source);

  /// No description provided for @sheetUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Fiche indisponible. Réessayez.'**
  String get sheetUnavailable;

  /// No description provided for @notAllowedForProfile.
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu n\'est pas autorisé pour ce profil.'**
  String get notAllowedForProfile;

  /// No description provided for @noSourceAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucune source disponible. Vérifiez vos addons.'**
  String get noSourceAvailable;

  /// No description provided for @addonsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Addons'**
  String get addonsTitle;

  /// No description provided for @addAddon.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un addon'**
  String get addAddon;

  /// No description provided for @addonsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les addons'**
  String get addonsLoadError;

  /// No description provided for @addonsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun addon installé. Un addon apporte des catalogues et des sources : ajoutez-en un avec son lien.'**
  String get addonsEmpty;

  /// No description provided for @addonActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible : l\'addon n\'a pas été modifié'**
  String get addonActionFailed;

  /// No description provided for @removeAddonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cet addon ?'**
  String get removeAddonTitle;

  /// No description provided for @removeAddonBody.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » sera retiré de Lumio. Ses catalogues et ses sources ne seront plus proposés.'**
  String removeAddonBody(Object name);

  /// No description provided for @addonBroken.
  ///
  /// In fr, this message translates to:
  /// **'Addon illisible : supprimez-le puis réinstallez-le'**
  String get addonBroken;

  /// No description provided for @addonDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get addonDisabled;

  /// No description provided for @moveAddonUp.
  ///
  /// In fr, this message translates to:
  /// **'Monter {name}'**
  String moveAddonUp(Object name);

  /// No description provided for @moveAddonDown.
  ///
  /// In fr, this message translates to:
  /// **'Descendre {name}'**
  String moveAddonDown(Object name);

  /// No description provided for @enableAddon.
  ///
  /// In fr, this message translates to:
  /// **'Activer {name}'**
  String enableAddon(Object name);

  /// No description provided for @deleteAddon.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {name}'**
  String deleteAddon(Object name);

  /// No description provided for @typeMovie.
  ///
  /// In fr, this message translates to:
  /// **'Films'**
  String get typeMovie;

  /// No description provided for @typeSeries.
  ///
  /// In fr, this message translates to:
  /// **'Séries'**
  String get typeSeries;

  /// No description provided for @typeAnime.
  ///
  /// In fr, this message translates to:
  /// **'Animes'**
  String get typeAnime;

  /// No description provided for @typeOther.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get typeOther;

  /// No description provided for @resCatalog.
  ///
  /// In fr, this message translates to:
  /// **'Catalogues'**
  String get resCatalog;

  /// No description provided for @resMeta.
  ///
  /// In fr, this message translates to:
  /// **'Fiches'**
  String get resMeta;

  /// No description provided for @resStream.
  ///
  /// In fr, this message translates to:
  /// **'Flux'**
  String get resStream;

  /// No description provided for @resSubtitles.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get resSubtitles;

  /// No description provided for @resAddonCatalog.
  ///
  /// In fr, this message translates to:
  /// **'Addons'**
  String get resAddonCatalog;

  /// No description provided for @clipboardEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Le presse-papiers est vide'**
  String get clipboardEmpty;

  /// No description provided for @localAddressRefused.
  ///
  /// In fr, this message translates to:
  /// **'Adresse locale refusée : aucun addon installé'**
  String get localAddressRefused;

  /// No description provided for @addonUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire cet addon'**
  String get addonUnreadable;

  /// No description provided for @localAddressTitle.
  ///
  /// In fr, this message translates to:
  /// **'Adresse locale'**
  String get localAddressTitle;

  /// No description provided for @localAddressBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse pointe vers votre appareil ou votre réseau local. Ne continuez que si vous avez vous-même lancé cet addon.'**
  String get localAddressBody;

  /// No description provided for @installFailed.
  ///
  /// In fr, this message translates to:
  /// **'Installation impossible'**
  String get installFailed;

  /// No description provided for @addonLinkLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lien de l\'addon'**
  String get addonLinkLabel;

  /// No description provided for @trustWarning.
  ///
  /// In fr, this message translates to:
  /// **'N\'installez que des addons de sources de confiance : un addon voit ce que vous consultez.'**
  String get trustWarning;

  /// No description provided for @versionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String versionLabel(Object version);

  /// No description provided for @alreadyInstalled.
  ///
  /// In fr, this message translates to:
  /// **'Déjà installé'**
  String get alreadyInstalled;

  /// No description provided for @provides.
  ///
  /// In fr, this message translates to:
  /// **'Fournit : {list}'**
  String provides(Object list);

  /// No description provided for @libraryLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire votre liste.'**
  String get libraryLoadError;

  /// No description provided for @libraryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Votre liste est vide. Ouvrez la fiche d\'un titre puis choisissez « Ajouter à ma liste ».'**
  String get libraryEmpty;

  /// No description provided for @updateAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour disponible : version {version}'**
  String updateAvailable(Object version);

  /// No description provided for @download.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get download;

  /// No description provided for @customizeHome.
  ///
  /// In fr, this message translates to:
  /// **'Personnaliser l\'accueil'**
  String get customizeHome;

  /// No description provided for @progressNotSaved.
  ///
  /// In fr, this message translates to:
  /// **'Progression non enregistrée'**
  String get progressNotSaved;

  /// No description provided for @resumeAt.
  ///
  /// In fr, this message translates to:
  /// **'Reprise à {time}'**
  String resumeAt(Object time);

  /// No description provided for @settingsNotSaved.
  ///
  /// In fr, this message translates to:
  /// **'Réglages non enregistrés'**
  String get settingsNotSaved;

  /// No description provided for @settingsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Réglages mémorisés indisponibles'**
  String get settingsUnavailable;

  /// No description provided for @subtitleSettingsNotApplied.
  ///
  /// In fr, this message translates to:
  /// **'Réglages de sous-titres non appliqués'**
  String get subtitleSettingsNotApplied;

  /// No description provided for @nextEpisodeUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Épisode suivant indisponible'**
  String get nextEpisodeUnavailable;

  /// No description provided for @buffering.
  ///
  /// In fr, this message translates to:
  /// **'Mise en mémoire tampon'**
  String get buffering;

  /// No description provided for @chooseOtherSource.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une autre source'**
  String get chooseOtherSource;

  /// No description provided for @seekBack10.
  ///
  /// In fr, this message translates to:
  /// **'Reculer de 10 secondes'**
  String get seekBack10;

  /// No description provided for @seekForward10.
  ///
  /// In fr, this message translates to:
  /// **'Avancer de 10 secondes'**
  String get seekForward10;

  /// No description provided for @pause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get play;

  /// No description provided for @tracksAndSubtitles.
  ///
  /// In fr, this message translates to:
  /// **'Pistes et sous-titres'**
  String get tracksAndSubtitles;

  /// No description provided for @seekBar.
  ///
  /// In fr, this message translates to:
  /// **'Position de lecture'**
  String get seekBar;

  /// No description provided for @audio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @noAudioTrack.
  ///
  /// In fr, this message translates to:
  /// **'Aucune piste audio disponible'**
  String get noAudioTrack;

  /// No description provided for @subtitles.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get subtitles;

  /// No description provided for @subtitlesOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivés'**
  String get subtitlesOff;

  /// No description provided for @subtitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'{lang} · {source}'**
  String subtitleLabel(String lang, String source);

  /// No description provided for @subtitleLabelN.
  ///
  /// In fr, this message translates to:
  /// **'{lang} · {source} {n}'**
  String subtitleLabelN(String lang, String source, int n);

  /// No description provided for @langUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Langue inconnue'**
  String get langUnknown;

  /// No description provided for @subtitleDelay.
  ///
  /// In fr, this message translates to:
  /// **'Décalage des sous-titres'**
  String get subtitleDelay;

  /// No description provided for @subtitleAdvance.
  ///
  /// In fr, this message translates to:
  /// **'Avancer les sous-titres de 100 ms'**
  String get subtitleAdvance;

  /// No description provided for @subtitleRetard.
  ///
  /// In fr, this message translates to:
  /// **'Retarder les sous-titres de 100 ms'**
  String get subtitleRetard;

  /// No description provided for @subtitleSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get subtitleSize;

  /// No description provided for @opaqueBackground.
  ///
  /// In fr, this message translates to:
  /// **'Fond opaque'**
  String get opaqueBackground;

  /// No description provided for @subtitleUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titre illisible'**
  String get subtitleUnreadable;

  /// No description provided for @trackN.
  ///
  /// In fr, this message translates to:
  /// **'Piste {n}'**
  String trackN(int n);

  /// No description provided for @nextEpisodeIn.
  ///
  /// In fr, this message translates to:
  /// **'Épisode suivant dans {seconds} secondes : {title}'**
  String nextEpisodeIn(int seconds, Object title);

  /// No description provided for @nextEpisodeInShort.
  ///
  /// In fr, this message translates to:
  /// **'Épisode suivant dans {seconds} s'**
  String nextEpisodeInShort(int seconds);

  /// No description provided for @playNow.
  ///
  /// In fr, this message translates to:
  /// **'Lire maintenant'**
  String get playNow;

  /// No description provided for @torrentNotPlayable.
  ///
  /// In fr, this message translates to:
  /// **'Ce flux passe par un torrent : il n\'est pas lisible ici.'**
  String get torrentNotPlayable;

  /// No description provided for @failTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Délai dépassé : la source ne répond pas.'**
  String get failTimeout;

  /// No description provided for @failNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible : vérifiez le réseau.'**
  String get failNetwork;

  /// No description provided for @failRedirect.
  ///
  /// In fr, this message translates to:
  /// **'La source redirige de façon incorrecte.'**
  String get failRedirect;

  /// No description provided for @failTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'La réponse de la source est trop volumineuse.'**
  String get failTooLarge;

  /// No description provided for @failFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format non pris en charge par le lecteur.'**
  String get failFormat;

  /// No description provided for @failTls.
  ///
  /// In fr, this message translates to:
  /// **'La connexion sécurisée avec la source a échoué.'**
  String get failTls;

  /// No description provided for @failGeneric.
  ///
  /// In fr, this message translates to:
  /// **'La lecture a échoué.'**
  String get failGeneric;

  /// No description provided for @failRefused.
  ///
  /// In fr, this message translates to:
  /// **'Source refusée pour des raisons de sécurité.'**
  String get failRefused;

  /// No description provided for @httpDenied.
  ///
  /// In fr, this message translates to:
  /// **'La source a répondu {status} : accès refusé.'**
  String httpDenied(int status);

  /// No description provided for @httpGone.
  ///
  /// In fr, this message translates to:
  /// **'La source a répondu {status} : le fichier n\'existe plus.'**
  String httpGone(int status);

  /// No description provided for @httpTooMany.
  ///
  /// In fr, this message translates to:
  /// **'La source a répondu 429 : trop de demandes, réessayez plus tard.'**
  String get httpTooMany;

  /// No description provided for @httpServer.
  ///
  /// In fr, this message translates to:
  /// **'La source a répondu {status} : elle est en panne.'**
  String httpServer(int status);

  /// No description provided for @httpOther.
  ///
  /// In fr, this message translates to:
  /// **'La source a répondu {status}.'**
  String httpOther(int status);

  /// No description provided for @noStreams.
  ///
  /// In fr, this message translates to:
  /// **'Aucun flux trouvé. Vérifiez vos addons.'**
  String get noStreams;

  /// No description provided for @addonFallback.
  ///
  /// In fr, this message translates to:
  /// **'Addon'**
  String get addonFallback;

  /// No description provided for @noResponse.
  ///
  /// In fr, this message translates to:
  /// **'Ne répond pas'**
  String get noResponse;

  /// No description provided for @streamCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} flux'**
  String streamCount(int count);

  /// No description provided for @torrentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Torrent'**
  String get torrentLabel;

  /// No description provided for @kindTorrent.
  ///
  /// In fr, this message translates to:
  /// **'torrent'**
  String get kindTorrent;

  /// No description provided for @kindDirect.
  ///
  /// In fr, this message translates to:
  /// **'lien direct'**
  String get kindDirect;

  /// No description provided for @seedersSemantic.
  ///
  /// In fr, this message translates to:
  /// **'{count} sources'**
  String seedersSemantic(int count);

  /// No description provided for @recommendedSemantic.
  ///
  /// In fr, this message translates to:
  /// **'recommandé'**
  String get recommendedSemantic;

  /// No description provided for @recommended.
  ///
  /// In fr, this message translates to:
  /// **'Recommandé'**
  String get recommended;

  /// No description provided for @sizeGb.
  ///
  /// In fr, this message translates to:
  /// **'{value} Go'**
  String sizeGb(Object value);

  /// No description provided for @sizeMb.
  ///
  /// In fr, this message translates to:
  /// **'{value} Mo'**
  String sizeMb(int value);

  /// No description provided for @listUpdateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Ma liste n\'a pas pu être modifiée.'**
  String get listUpdateFailed;

  /// No description provided for @detailLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la fiche.'**
  String get detailLoadError;

  /// No description provided for @autoPlayBest.
  ///
  /// In fr, this message translates to:
  /// **'Lecture auto · meilleure source'**
  String get autoPlayBest;

  /// No description provided for @removeFromList.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de ma liste'**
  String get removeFromList;

  /// No description provided for @openSheet.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la fiche'**
  String get openSheet;

  /// No description provided for @addToList.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à ma liste'**
  String get addToList;

  /// No description provided for @seasonEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'Épisodes'**
  String get seasonEpisodes;

  /// No description provided for @seasonSpecials.
  ///
  /// In fr, this message translates to:
  /// **'Spéciaux'**
  String get seasonSpecials;

  /// No description provided for @seasonN.
  ///
  /// In fr, this message translates to:
  /// **'Saison {n}'**
  String seasonN(int n);

  /// No description provided for @noEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'Aucun épisode disponible pour cette série.'**
  String get noEpisodes;

  /// No description provided for @seasonsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisons'**
  String get seasonsTitle;

  /// No description provided for @sourcesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sources'**
  String get sourcesTitle;

  /// No description provided for @watchedSemantic.
  ///
  /// In fr, this message translates to:
  /// **'vu'**
  String get watchedSemantic;

  /// No description provided for @unwatchedSemantic.
  ///
  /// In fr, this message translates to:
  /// **'non vu'**
  String get unwatchedSemantic;

  /// No description provided for @episodeLetter.
  ///
  /// In fr, this message translates to:
  /// **'É'**
  String get episodeLetter;

  /// No description provided for @watchedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Vu'**
  String get watchedBadge;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un titre'**
  String get searchHint;

  /// No description provided for @kbSpace.
  ///
  /// In fr, this message translates to:
  /// **'Espace'**
  String get kbSpace;

  /// No description provided for @kbErase.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get kbErase;

  /// No description provided for @kbAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get kbAll;

  /// No description provided for @kbClearAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get kbClearAll;

  /// No description provided for @kbLatin.
  ///
  /// In fr, this message translates to:
  /// **'Clavier latin'**
  String get kbLatin;

  /// No description provided for @kbArabic.
  ///
  /// In fr, this message translates to:
  /// **'Clavier arabe'**
  String get kbArabic;

  /// No description provided for @dictationStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter la dictée'**
  String get dictationStop;

  /// No description provided for @dictationStart.
  ///
  /// In fr, this message translates to:
  /// **'Dictée vocale'**
  String get dictationStart;

  /// No description provided for @searchPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Tapez un titre pour lancer la recherche'**
  String get searchPrompt;

  /// No description provided for @searchNoAddon.
  ///
  /// In fr, this message translates to:
  /// **'Aucun addon actif ne propose la recherche'**
  String get searchNoAddon;

  /// No description provided for @searchNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get searchNoResults;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get filterAll;

  /// No description provided for @filterMovies.
  ///
  /// In fr, this message translates to:
  /// **'Films'**
  String get filterMovies;

  /// No description provided for @filterSeries.
  ///
  /// In fr, this message translates to:
  /// **'Séries'**
  String get filterSeries;

  /// No description provided for @kidAllAges.
  ///
  /// In fr, this message translates to:
  /// **'Enfant · Tous publics'**
  String get kidAllAges;

  /// No description provided for @kidYears.
  ///
  /// In fr, this message translates to:
  /// **'Enfant · {years}+'**
  String kidYears(int years);

  /// No description provided for @profilesLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les profils'**
  String get profilesLoadError;

  /// No description provided for @parentalUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Contrôle parental indisponible. Réessayez.'**
  String get parentalUnavailable;

  /// No description provided for @pinFor.
  ///
  /// In fr, this message translates to:
  /// **'PIN pour {name}'**
  String pinFor(Object name);

  /// No description provided for @maxProfilesReached.
  ///
  /// In fr, this message translates to:
  /// **'Six profils au maximum'**
  String get maxProfilesReached;

  /// No description provided for @profileNotModified.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible : le profil n\'a pas été modifié'**
  String get profileNotModified;

  /// No description provided for @whoIsWatching.
  ///
  /// In fr, this message translates to:
  /// **'Qui regarde ?'**
  String get whoIsWatching;

  /// No description provided for @manageProfiles.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les profils'**
  String get manageProfiles;

  /// No description provided for @lockedSemantic.
  ///
  /// In fr, this message translates to:
  /// **'verrouillé, PIN demandé'**
  String get lockedSemantic;

  /// No description provided for @editSemantic.
  ///
  /// In fr, this message translates to:
  /// **'modifier'**
  String get editSemantic;

  /// No description provided for @pinBadge.
  ///
  /// In fr, this message translates to:
  /// **'PIN'**
  String get pinBadge;

  /// No description provided for @addProfileSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un profil'**
  String get addProfileSemantic;

  /// No description provided for @nameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom au profil'**
  String get nameRequired;

  /// No description provided for @deleteProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce profil ?'**
  String get deleteProfileTitle;

  /// No description provided for @deleteProfileBody.
  ///
  /// In fr, this message translates to:
  /// **'Sa progression, sa liste et ses réglages seront supprimés.'**
  String get deleteProfileBody;

  /// No description provided for @ageAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous publics'**
  String get ageAll;

  /// No description provided for @newProfile.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau profil'**
  String get newProfile;

  /// No description provided for @editProfile.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get editProfile;

  /// No description provided for @nameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get nameLabel;

  /// No description provided for @kidProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil enfant'**
  String get kidProfile;

  /// No description provided for @kidProfileHint.
  ///
  /// In fr, this message translates to:
  /// **'Contenus filtrés selon l\'âge ; réglages et changement de profil protégés par le PIN parent.'**
  String get kidProfileHint;

  /// No description provided for @ageLimit.
  ///
  /// In fr, this message translates to:
  /// **'Limite d\'âge'**
  String get ageLimit;

  /// No description provided for @lockByPin.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller par PIN'**
  String get lockByPin;

  /// No description provided for @lockByPinHint.
  ///
  /// In fr, this message translates to:
  /// **'Le PIN parent est demandé pour ouvrir ce profil.'**
  String get lockByPinHint;

  /// No description provided for @profileFallback.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileFallback;

  /// No description provided for @tooManyTries.
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais. Réessayez dans {min} min.'**
  String tooManyTries(int min);

  /// No description provided for @pinWrong.
  ///
  /// In fr, this message translates to:
  /// **'PIN incorrect'**
  String get pinWrong;

  /// No description provided for @pinCheckFailed.
  ///
  /// In fr, this message translates to:
  /// **'Vérification impossible. Réessayez.'**
  String get pinCheckFailed;

  /// No description provided for @pinForgot.
  ///
  /// In fr, this message translates to:
  /// **'PIN oublié ?'**
  String get pinForgot;

  /// No description provided for @pinDotsSemantic.
  ///
  /// In fr, this message translates to:
  /// **'{filled, plural, =0{0 chiffre saisi sur 4} =1{1 chiffre saisi sur 4} other{{filled} chiffres saisis sur 4}}'**
  String pinDotsSemantic(int filled);

  /// No description provided for @digitSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Chiffre {digit}'**
  String digitSemantic(Object digit);

  /// No description provided for @eraseLastDigit.
  ///
  /// In fr, this message translates to:
  /// **'Effacer le dernier chiffre'**
  String get eraseLastDigit;

  /// No description provided for @recoveryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code de récupération'**
  String get recoveryTitle;

  /// No description provided for @recoveryBody.
  ///
  /// In fr, this message translates to:
  /// **'Notez ce code et gardez-le en lieu sûr : il permet de choisir un nouveau PIN si vous l\'oubliez. Il ne sera plus jamais affiché.'**
  String get recoveryBody;

  /// No description provided for @recoveryNoted.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai noté le code'**
  String get recoveryNoted;

  /// No description provided for @choosePin.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un PIN'**
  String get choosePin;

  /// No description provided for @pinHint.
  ///
  /// In fr, this message translates to:
  /// **'4 chiffres. Il protège les profils enfants et les réglages.'**
  String get pinHint;

  /// No description provided for @confirmPin.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez le PIN'**
  String get confirmPin;

  /// No description provided for @pinMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux PIN ne correspondent pas'**
  String get pinMismatch;

  /// No description provided for @pinSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer le PIN'**
  String get pinSaveFailed;

  /// No description provided for @recoveryWrong.
  ///
  /// In fr, this message translates to:
  /// **'Code de récupération incorrect'**
  String get recoveryWrong;

  /// No description provided for @tooManyTriesLater.
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais. Réessayez dans quelques minutes.'**
  String get tooManyTriesLater;

  /// No description provided for @recoveryFailed.
  ///
  /// In fr, this message translates to:
  /// **'Récupération impossible'**
  String get recoveryFailed;

  /// No description provided for @parentPin.
  ///
  /// In fr, this message translates to:
  /// **'PIN parent'**
  String get parentPin;

  /// No description provided for @askParent.
  ///
  /// In fr, this message translates to:
  /// **'Demandez à un parent de saisir son PIN.'**
  String get askParent;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settingsTitle;

  /// No description provided for @settingsAddons.
  ///
  /// In fr, this message translates to:
  /// **'Addons'**
  String get settingsAddons;

  /// No description provided for @settingsAddonsHint.
  ///
  /// In fr, this message translates to:
  /// **'Réordonner, activer ou supprimer vos addons'**
  String get settingsAddonsHint;

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'interface'**
  String get settingsLanguage;

  /// No description provided for @langFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get langFrench;

  /// No description provided for @langEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @settingsPlayback.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get settingsPlayback;

  /// No description provided for @settingsAudioLang.
  ///
  /// In fr, this message translates to:
  /// **'Langue audio'**
  String get settingsAudioLang;

  /// No description provided for @settingsSubtitleLang.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get settingsSubtitleLang;

  /// No description provided for @settingsQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité préférée'**
  String get settingsQuality;

  /// No description provided for @settingsPreferDirect.
  ///
  /// In fr, this message translates to:
  /// **'Préférer les liens directs'**
  String get settingsPreferDirect;

  /// No description provided for @preferDirectOn.
  ///
  /// In fr, this message translates to:
  /// **'Avant les torrents, à qualité égale.'**
  String get preferDirectOn;

  /// No description provided for @preferDirectOff.
  ///
  /// In fr, this message translates to:
  /// **'Sans préférence'**
  String get preferDirectOff;

  /// No description provided for @otherAddonsCount.
  ///
  /// In fr, this message translates to:
  /// **'+{count, plural, =1{1 autre addon} other{{count} autres addons}}'**
  String otherAddonsCount(int count);

  /// No description provided for @playerSourceFallback.
  ///
  /// In fr, this message translates to:
  /// **'Source indisponible, essai de la suivante…'**
  String get playerSourceFallback;

  /// No description provided for @playingFallback.
  ///
  /// In fr, this message translates to:
  /// **'Lecture depuis une autre source : {title}'**
  String playingFallback(String title);

  /// No description provided for @langSpanish.
  ///
  /// In fr, this message translates to:
  /// **'Español'**
  String get langSpanish;

  /// No description provided for @langGerman.
  ///
  /// In fr, this message translates to:
  /// **'Deutsch'**
  String get langGerman;

  /// No description provided for @langItalian.
  ///
  /// In fr, this message translates to:
  /// **'Italiano'**
  String get langItalian;

  /// No description provided for @langPortuguese.
  ///
  /// In fr, this message translates to:
  /// **'Português'**
  String get langPortuguese;

  /// No description provided for @langArabic.
  ///
  /// In fr, this message translates to:
  /// **'العربية'**
  String get langArabic;

  /// No description provided for @settingsDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Torrents'**
  String get settingsDownloads;

  /// No description provided for @settingsTorrentCache.
  ///
  /// In fr, this message translates to:
  /// **'Cache'**
  String get settingsTorrentCache;

  /// No description provided for @settingsUpload.
  ///
  /// In fr, this message translates to:
  /// **'Limite d\'envoi'**
  String get settingsUpload;

  /// No description provided for @unlimited.
  ///
  /// In fr, this message translates to:
  /// **'Illimité'**
  String get unlimited;

  /// No description provided for @uploadOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé (pas d\'ensemencement, envoi minimal de 256 Ko/s)'**
  String get uploadOff;

  /// No description provided for @settingsClearCacheOnExit.
  ///
  /// In fr, this message translates to:
  /// **'Vider le cache en quittant'**
  String get settingsClearCacheOnExit;

  /// No description provided for @optionYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get optionYes;

  /// No description provided for @optionNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get optionNo;

  /// No description provided for @cacheGb.
  ///
  /// In fr, this message translates to:
  /// **'{n} Go'**
  String cacheGb(int n);

  /// No description provided for @uploadKbps.
  ///
  /// In fr, this message translates to:
  /// **'{n} Ko/s'**
  String uploadKbps(int n);

  /// No description provided for @settingsVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @versionValue.
  ///
  /// In fr, this message translates to:
  /// **'Lumio {version}'**
  String versionValue(Object version);

  /// No description provided for @debugUnlocked.
  ///
  /// In fr, this message translates to:
  /// **'Menu debug activé'**
  String get debugUnlocked;

  /// No description provided for @debugMenuTitle.
  ///
  /// In fr, this message translates to:
  /// **'Menu debug'**
  String get debugMenuTitle;

  /// No description provided for @debugNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun écran de debug'**
  String get debugNone;

  /// No description provided for @debugTorrent.
  ///
  /// In fr, this message translates to:
  /// **'Spike torrent'**
  String get debugTorrent;

  /// No description provided for @debugPlayer.
  ///
  /// In fr, this message translates to:
  /// **'Spike lecteur'**
  String get debugPlayer;

  /// No description provided for @debugLoop.
  ///
  /// In fr, this message translates to:
  /// **'Boucle d\'endurance'**
  String get debugLoop;

  /// No description provided for @settingsAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get settingsAbout;

  /// No description provided for @aboutLicense.
  ///
  /// In fr, this message translates to:
  /// **'Licence GPL-3.0'**
  String get aboutLicense;

  /// No description provided for @aboutCredits.
  ///
  /// In fr, this message translates to:
  /// **'Crédits : libmpv, media_kit, libtorrent'**
  String get aboutCredits;

  /// No description provided for @openSourceLicenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences open source'**
  String get openSourceLicenses;

  /// No description provided for @settingSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Réglage non enregistré'**
  String get settingSaveFailed;

  /// No description provided for @gplTitle.
  ///
  /// In fr, this message translates to:
  /// **'Licence GPL-3.0'**
  String get gplTitle;

  /// No description provided for @gplText.
  ///
  /// In fr, this message translates to:
  /// **'Lumio est un logiciel libre, distribué sous la licence publique générale GNU version 3 (GPL-3.0). Vous pouvez le copier, le modifier et le redistribuer selon les termes de cette licence. Il est fourni sans aucune garantie. Texte complet : https://www.gnu.org/licenses/gpl-3.0.html'**
  String get gplText;

  /// No description provided for @creditsLibmpv.
  ///
  /// In fr, this message translates to:
  /// **'libmpv : lecteur vidéo (LGPL/GPL)'**
  String get creditsLibmpv;

  /// No description provided for @creditsMediaKit.
  ///
  /// In fr, this message translates to:
  /// **'media_kit : intégration Flutter du lecteur'**
  String get creditsMediaKit;

  /// No description provided for @creditsLibtorrent.
  ///
  /// In fr, this message translates to:
  /// **'libtorrent : moteur de torrents (BSD)'**
  String get creditsLibtorrent;

  /// No description provided for @creditsFonts.
  ///
  /// In fr, this message translates to:
  /// **'Polices Bricolage Grotesque et Manrope (licence SIL OFL 1.1)'**
  String get creditsFonts;

  /// No description provided for @settingsNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get settingsNone;

  /// No description provided for @subtitlesNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sous-titre'**
  String get subtitlesNone;

  /// No description provided for @errDuplicate.
  ///
  /// In fr, this message translates to:
  /// **'Cet addon est déjà installé'**
  String get errDuplicate;

  /// No description provided for @errPrivateAddress.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse pointe vers votre réseau local'**
  String get errPrivateAddress;

  /// No description provided for @errInvalidAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse invalide'**
  String get errInvalidAddress;

  /// No description provided for @errAddressRefused.
  ///
  /// In fr, this message translates to:
  /// **'Adresse refusée'**
  String get errAddressRefused;

  /// No description provided for @errTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Délai dépassé : l\'addon ne répond pas'**
  String get errTimeout;

  /// No description provided for @errUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Addon injoignable'**
  String get errUnreachable;

  /// No description provided for @errTls.
  ///
  /// In fr, this message translates to:
  /// **'Connexion sécurisée impossible (certificat refusé)'**
  String get errTls;

  /// No description provided for @errNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Addon ou ressource introuvable'**
  String get errNotFound;

  /// No description provided for @errServer.
  ///
  /// In fr, this message translates to:
  /// **'Addon en erreur (HTTP {status})'**
  String errServer(int status);

  /// No description provided for @errRefused.
  ///
  /// In fr, this message translates to:
  /// **'Réponse refusée par l\'addon (HTTP {status})'**
  String errRefused(int status);

  /// No description provided for @errTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Réponse trop volumineuse'**
  String get errTooLarge;

  /// No description provided for @errInvalidJson.
  ///
  /// In fr, this message translates to:
  /// **'Réponse invalide : ce n\'est pas du JSON valide'**
  String get errInvalidJson;

  /// No description provided for @errRedirect.
  ///
  /// In fr, this message translates to:
  /// **'Redirection refusée ou invalide'**
  String get errRedirect;

  /// No description provided for @errManifestInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Manifeste invalide'**
  String get errManifestInvalid;

  /// No description provided for @errUnexpected.
  ///
  /// In fr, this message translates to:
  /// **'Erreur inattendue lors du chargement'**
  String get errUnexpected;

  /// No description provided for @errOther.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errOther;

  /// No description provided for @qualityAuto.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get qualityAuto;

  /// No description provided for @useCopiedLink.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser le lien copié'**
  String get useCopiedLink;

  /// No description provided for @installLinkInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien n\'est pas un lien d\'installation d\'addon.'**
  String get installLinkInvalid;

  /// No description provided for @onboardingStep.
  ///
  /// In fr, this message translates to:
  /// **'Étape {n} sur {total}'**
  String onboardingStep(int n, int total);

  /// No description provided for @onboardingSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get onboardingSkip;

  /// No description provided for @onboardingStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get onboardingStart;

  /// No description provided for @onboardingLanguageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre langue'**
  String get onboardingLanguageTitle;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingProfileBody.
  ///
  /// In fr, this message translates to:
  /// **'Comment doit-on vous appeler ? Vous pourrez le changer plus tard.'**
  String get onboardingProfileBody;

  /// No description provided for @onboardingProfileName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du profil'**
  String get onboardingProfileName;

  /// No description provided for @onboardingAddKid.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un profil enfant'**
  String get onboardingAddKid;

  /// No description provided for @onboardingKidAdded.
  ///
  /// In fr, this message translates to:
  /// **'Profil enfant ajouté : {name}'**
  String onboardingKidAdded(String name);

  /// No description provided for @onboardingSourcesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez vos sources'**
  String get onboardingSourcesTitle;

  /// No description provided for @onboardingSourcesBody.
  ///
  /// In fr, this message translates to:
  /// **'Lumio ne propose aucun contenu : ajoutez vos propres sources pour remplir l\'accueil.'**
  String get onboardingSourcesBody;

  /// No description provided for @onboardingAddonsInstalled.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 addon installé} other{{count} addons installés}}'**
  String onboardingAddonsInstalled(int count);

  /// No description provided for @onboardingDoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tout est prêt'**
  String get onboardingDoneTitle;

  /// No description provided for @onboardingDoneBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez ajouter ou changer vos sources à tout moment depuis les réglages.'**
  String get onboardingDoneBody;

  /// No description provided for @onboardingSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement impossible, réessayez'**
  String get onboardingSaveError;

  /// No description provided for @sourcesReminderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez vos sources'**
  String get sourcesReminderTitle;

  /// No description provided for @sourcesReminderBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre accueil est vide tant qu\'aucune source n\'est ajoutée.'**
  String get sourcesReminderBody;

  /// No description provided for @sourcesReminderDismiss.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get sourcesReminderDismiss;

  /// No description provided for @torrentInsufficientStorage.
  ///
  /// In fr, this message translates to:
  /// **'Espace insuffisant sur l\'appareil pour lire ce torrent. Libérez de la place puis réessayez.'**
  String get torrentInsufficientStorage;

  /// No description provided for @torrentNoPeers.
  ///
  /// In fr, this message translates to:
  /// **'Aucune source disponible pour ce torrent. Essayez un autre flux.'**
  String get torrentNoPeers;

  /// No description provided for @torrentVpnRequired.
  ///
  /// In fr, this message translates to:
  /// **'Un VPN est exigé pour les torrents et aucun n\'est actif. Activez votre VPN puis réessayez.'**
  String get torrentVpnRequired;

  /// No description provided for @torrentVpnLost.
  ///
  /// In fr, this message translates to:
  /// **'VPN coupé : torrent arrêté pour protéger votre adresse IP.'**
  String get torrentVpnLost;

  /// No description provided for @torrentNoVpnReminder.
  ///
  /// In fr, this message translates to:
  /// **'Aucun VPN détecté : votre adresse IP est visible des autres pairs.'**
  String get torrentNoVpnReminder;

  /// No description provided for @torrentIpWarningTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre adresse IP sera visible'**
  String get torrentIpWarningTitle;

  /// No description provided for @torrentIpWarningBody.
  ///
  /// In fr, this message translates to:
  /// **'Avec un torrent, les autres participants de l\'échange voient votre adresse IP. Pour la protéger, utilisez un VPN. Vous pouvez en exiger un dans les réglages.'**
  String get torrentIpWarningBody;

  /// No description provided for @torrentIpWarningContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get torrentIpWarningContinue;

  /// No description provided for @torrentIpWarningCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get torrentIpWarningCancel;

  /// No description provided for @torrentIpWarningDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Torrent non démarré. Relancez la lecture pour continuer.'**
  String get torrentIpWarningDeclined;

  /// No description provided for @settingsRequireVpn.
  ///
  /// In fr, this message translates to:
  /// **'Exiger un VPN pour les torrents'**
  String get settingsRequireVpn;

  /// No description provided for @settingsVpnInterface.
  ///
  /// In fr, this message translates to:
  /// **'Interface VPN'**
  String get settingsVpnInterface;

  /// No description provided for @vpnAny.
  ///
  /// In fr, this message translates to:
  /// **'N\'importe quel VPN'**
  String get vpnAny;

  /// No description provided for @vpnInterfaceRequired.
  ///
  /// In fr, this message translates to:
  /// **'{name} : exigée, torrents arrêtés si elle tombe'**
  String vpnInterfaceRequired(String name);

  /// No description provided for @vpnNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun VPN actif détecté'**
  String get vpnNone;

  /// No description provided for @torrentNoFile.
  ///
  /// In fr, this message translates to:
  /// **'Ce torrent ne contient aucun fichier lisible. Essayez un autre flux.'**
  String get torrentNoFile;

  /// No description provided for @torrentFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le torrent n\'a pas pu démarrer. Essayez un autre flux.'**
  String get torrentFailed;

  /// No description provided for @torrentConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion aux sources…'**
  String get torrentConnecting;

  /// No description provided for @torrentConnectionLost.
  ///
  /// In fr, this message translates to:
  /// **'Connexion perdue, nouvelle tentative…'**
  String get torrentConnectionLost;

  /// No description provided for @torrentPeers.
  ///
  /// In fr, this message translates to:
  /// **'{count} sources'**
  String torrentPeers(Object count);

  /// No description provided for @torrentRateKb.
  ///
  /// In fr, this message translates to:
  /// **'{value} Ko/s'**
  String torrentRateKb(Object value);

  /// No description provided for @torrentRateMb.
  ///
  /// In fr, this message translates to:
  /// **'{value} Mo/s'**
  String torrentRateMb(Object value);

  /// No description provided for @torrentBuffered.
  ///
  /// In fr, this message translates to:
  /// **'{percent} % téléchargé'**
  String torrentBuffered(Object percent);

  /// No description provided for @kidProfileNeedsPin.
  ///
  /// In fr, this message translates to:
  /// **'Ce profil enfant vient d\'un autre appareil. Créez d\'abord un PIN parent pour l\'utiliser.'**
  String get kidProfileNeedsPin;

  /// No description provided for @addonUrlAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get addonUrlAllow;

  /// No description provided for @addonUrlIgnore.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get addonUrlIgnore;

  /// No description provided for @passphraseLabel.
  ///
  /// In fr, this message translates to:
  /// **'Phrase secrète de la sauvegarde'**
  String get passphraseLabel;

  /// No description provided for @passphraseConfirmLabel.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la phrase secrète'**
  String get passphraseConfirmLabel;

  /// No description provided for @passphraseErrShort.
  ///
  /// In fr, this message translates to:
  /// **'12 caractères au moins'**
  String get passphraseErrShort;

  /// No description provided for @passphraseErrMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux phrases sont différentes'**
  String get passphraseErrMismatch;

  /// No description provided for @settingsBackup.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde'**
  String get settingsBackup;

  /// No description provided for @backupExport.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes données'**
  String get backupExport;

  /// No description provided for @backupExportHint.
  ///
  /// In fr, this message translates to:
  /// **'Profils, ma liste, progression et réglages dans un fichier'**
  String get backupExportHint;

  /// No description provided for @backupImport.
  ///
  /// In fr, this message translates to:
  /// **'Importer une sauvegarde'**
  String get backupImport;

  /// No description provided for @backupImportHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute le contenu du fichier à vos données ; rien n\'est supprimé'**
  String get backupImportHint;

  /// No description provided for @backupSecretsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inclure les adresses d\'addons ?'**
  String get backupSecretsTitle;

  /// No description provided for @backupSecretsWarning.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier contiendra vos adresses d\'addons. Il sera chiffré avec une phrase secrète que vous choisissez : sans elle, personne ne pourra le lire, vous non plus. Sans les adresses, le fichier ne contient aucun secret.'**
  String get backupSecretsWarning;

  /// No description provided for @backupWithoutSecrets.
  ///
  /// In fr, this message translates to:
  /// **'Sans les adresses'**
  String get backupWithoutSecrets;

  /// No description provided for @backupWithSecrets.
  ///
  /// In fr, this message translates to:
  /// **'Inclure (chiffré)'**
  String get backupWithSecrets;

  /// No description provided for @backupPassphraseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Phrase secrète de la sauvegarde'**
  String get backupPassphraseTitle;

  /// No description provided for @backupPassphraseHint.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une phrase d\'au moins 12 caractères. Elle n\'est pas enregistrée : notez-la.'**
  String get backupPassphraseHint;

  /// No description provided for @backupImportPassphraseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde chiffrée'**
  String get backupImportPassphraseTitle;

  /// No description provided for @backupImportPassphraseHint.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez la phrase secrète choisie lors de l\'export.'**
  String get backupImportPassphraseHint;

  /// No description provided for @backupWrongPassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Phrase secrète incorrecte, ou fichier abîmé.'**
  String get backupWrongPassphrase;

  /// No description provided for @backupContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get backupContinue;

  /// No description provided for @backupErrUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'est pas une sauvegarde Lumio.'**
  String get backupErrUnknown;

  /// No description provided for @backupErrVersion.
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde vient d\'une version plus récente de Lumio. Mettez l\'application à jour.'**
  String get backupErrVersion;

  /// No description provided for @backupErrMalformed.
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde est illisible ou abîmée.'**
  String get backupErrMalformed;

  /// No description provided for @backupErrTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde est trop volumineuse (10 Mo au maximum).'**
  String get backupErrTooLarge;

  /// No description provided for @backupErrFile.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire ou d\'écrire le fichier.'**
  String get backupErrFile;

  /// No description provided for @backupExported.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde enregistrée : {path}'**
  String backupExported(String path);

  /// No description provided for @backupPickTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une sauvegarde'**
  String get backupPickTitle;

  /// No description provided for @backupNoFiles.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sauvegarde trouvée. Copiez un fichier .lumio.json dans ce dossier : {dir}'**
  String backupNoFiles(String dir);

  /// No description provided for @backupConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Importer cette sauvegarde ?'**
  String get backupConfirmTitle;

  /// No description provided for @backupConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Le contenu du fichier est ajouté à vos données. Rien n\'est supprimé ni remplacé, sauf une progression moins récente que celle du fichier.'**
  String get backupConfirmBody;

  /// No description provided for @backupImportBusy.
  ///
  /// In fr, this message translates to:
  /// **'Import en cours…'**
  String get backupImportBusy;

  /// No description provided for @backupDoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Import terminé'**
  String get backupDoneTitle;

  /// No description provided for @backupSumProfiles.
  ///
  /// In fr, this message translates to:
  /// **'{n} profil(s) ajouté(s)'**
  String backupSumProfiles(int n);

  /// No description provided for @backupSumLibrary.
  ///
  /// In fr, this message translates to:
  /// **'{n} titre(s) ajouté(s) à la liste'**
  String backupSumLibrary(int n);

  /// No description provided for @backupSumProgress.
  ///
  /// In fr, this message translates to:
  /// **'{n} progression(s) importée(s)'**
  String backupSumProgress(int n);

  /// No description provided for @backupSumAddons.
  ///
  /// In fr, this message translates to:
  /// **'{n} addon(s) installé(s)'**
  String backupSumAddons(int n);

  /// No description provided for @backupSumNothing.
  ///
  /// In fr, this message translates to:
  /// **'Rien de nouveau : vos données contenaient déjà tout.'**
  String get backupSumNothing;

  /// No description provided for @backupSumNameOnly.
  ///
  /// In fr, this message translates to:
  /// **'{n} addon(s) à réinstaller à la main : le fichier ne contient pas leurs adresses.'**
  String backupSumNameOnly(int n);

  /// No description provided for @backupSumFailed.
  ///
  /// In fr, this message translates to:
  /// **'{n} addon(s) n\'ont pas pu être installés.'**
  String backupSumFailed(int n);

  /// No description provided for @backupSumSkipped.
  ///
  /// In fr, this message translates to:
  /// **'{n} entrée(s) invalide(s) ignorée(s).'**
  String backupSumSkipped(int n);

  /// No description provided for @backupSumProfilesSkipped.
  ///
  /// In fr, this message translates to:
  /// **'{n} profil(s) non ajouté(s) : six profils au maximum.'**
  String backupSumProfilesSkipped(int n);

  /// No description provided for @backupKidNeedsPin.
  ///
  /// In fr, this message translates to:
  /// **'Un profil enfant a été ajouté : créez d\'abord un PIN parent pour l\'utiliser.'**
  String get backupKidNeedsPin;

  /// No description provided for @backupPrivateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Adresse locale'**
  String get backupPrivateTitle;

  /// No description provided for @backupPrivateBody.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » ({host}) pointe vers votre réseau local. L\'installer quand même ?'**
  String backupPrivateBody(String name, String host);

  /// No description provided for @otherImportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Importer depuis un autre client'**
  String get otherImportTitle;

  /// No description provided for @otherImportHint.
  ///
  /// In fr, this message translates to:
  /// **'Addons et liste depuis des fichiers exportés'**
  String get otherImportHint;

  /// No description provided for @otherImportHelp.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez ou collez les fichiers JSON exportés depuis votre ancien client compatible (par exemple Stremio : réponses de addonCollectionGet et datastoreGet). Aucun compte n\'est contacté : seuls ces fichiers sont lus. La liste est ajoutée au profil actif ; les addons sont installés un par un.'**
  String get otherImportHelp;

  /// No description provided for @otherImportAddonsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Addons (JSON)'**
  String get otherImportAddonsLabel;

  /// No description provided for @otherImportLibraryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque (JSON)'**
  String get otherImportLibraryLabel;

  /// No description provided for @otherImportPasteHint.
  ///
  /// In fr, this message translates to:
  /// **'Collez le contenu ici…'**
  String get otherImportPasteHint;

  /// No description provided for @otherImportChooseFile.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un fichier'**
  String get otherImportChooseFile;

  /// No description provided for @otherImportRemoveFile.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le fichier'**
  String get otherImportRemoveFile;

  /// No description provided for @otherImportFileLoaded.
  ///
  /// In fr, this message translates to:
  /// **'Fichier : {name}'**
  String otherImportFileLoaded(String name);

  /// No description provided for @otherImportPickTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un fichier JSON'**
  String get otherImportPickTitle;

  /// No description provided for @otherImportNoFiles.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fichier .json trouvé. Copiez-y vos fichiers exportés : {dir}'**
  String otherImportNoFiles(String dir);

  /// No description provided for @otherImportRun.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get otherImportRun;

  /// No description provided for @otherImportNothing.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez ou collez au moins un fichier.'**
  String get otherImportNothing;

  /// No description provided for @otherImportErrFormat.
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu n\'est pas un export reconnu : {which}.'**
  String otherImportErrFormat(String which);

  /// No description provided for @otherImportErrTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu est trop volumineux (10 Mo au maximum).'**
  String get otherImportErrTooLarge;

  /// No description provided for @otherImportProgressAddons.
  ///
  /// In fr, this message translates to:
  /// **'Installation des addons : {done} sur {total}'**
  String otherImportProgressAddons(int done, int total);

  /// No description provided for @otherImportProgressLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Ajout à la liste…'**
  String get otherImportProgressLibrary;

  /// No description provided for @otherImportDoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Import terminé'**
  String get otherImportDoneTitle;

  /// No description provided for @otherImportSumInstalled.
  ///
  /// In fr, this message translates to:
  /// **'{n} addon(s) installé(s)'**
  String otherImportSumInstalled(int n);

  /// No description provided for @otherImportSumAlready.
  ///
  /// In fr, this message translates to:
  /// **'{n} addon(s) déjà présent(s)'**
  String otherImportSumAlready(int n);

  /// No description provided for @otherImportSumPending.
  ///
  /// In fr, this message translates to:
  /// **'{n} addon(s) en attente (adresse locale)'**
  String otherImportSumPending(int n);

  /// No description provided for @otherImportSumSkipped.
  ///
  /// In fr, this message translates to:
  /// **'{n} élément(s) ignoré(s) : {names}'**
  String otherImportSumSkipped(int n, String names);

  /// No description provided for @otherImportSumLibrary.
  ///
  /// In fr, this message translates to:
  /// **'{n} titre(s) ajouté(s) à la liste'**
  String otherImportSumLibrary(int n);

  /// No description provided for @otherImportSumLibraryAlready.
  ///
  /// In fr, this message translates to:
  /// **'{n} titre(s) déjà dans la liste'**
  String otherImportSumLibraryAlready(int n);

  /// No description provided for @otherImportSumNothing.
  ///
  /// In fr, this message translates to:
  /// **'Rien à importer dans ces fichiers.'**
  String get otherImportSumNothing;

  /// No description provided for @otherImportPendingItem.
  ///
  /// In fr, this message translates to:
  /// **'Un addon pointe vers votre réseau local ({host}). L\'installer quand même ?'**
  String otherImportPendingItem(String host);

  /// No description provided for @otherImportWhatAddons.
  ///
  /// In fr, this message translates to:
  /// **'addons'**
  String get otherImportWhatAddons;

  /// No description provided for @otherImportWhatLibrary.
  ///
  /// In fr, this message translates to:
  /// **'bibliothèque'**
  String get otherImportWhatLibrary;

  /// No description provided for @otherImportSumFailedInvalid.
  ///
  /// In fr, this message translates to:
  /// **'{n} addon(s) refusé(s) : manifeste invalide'**
  String otherImportSumFailedInvalid(int n);

  /// No description provided for @otherImportSumFailedUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'{n} addon(s) injoignable(s)'**
  String otherImportSumFailedUnreachable(int n);

  /// No description provided for @otherImportSumFailedOther.
  ///
  /// In fr, this message translates to:
  /// **'{n} addon(s) n\'ont pas pu être installés (autre cause)'**
  String otherImportSumFailedOther(int n);

  /// No description provided for @otherImportSumLibraryFailed.
  ///
  /// In fr, this message translates to:
  /// **'{n} titre(s) n\'ont pas pu être ajoutés à la liste'**
  String otherImportSumLibraryFailed(int n);

  /// No description provided for @healthReliable.
  ///
  /// In fr, this message translates to:
  /// **'Fiable'**
  String get healthReliable;

  /// No description provided for @healthSlow.
  ///
  /// In fr, this message translates to:
  /// **'Lent (> 3 s)'**
  String get healthSlow;

  /// No description provided for @healthFailing.
  ///
  /// In fr, this message translates to:
  /// **'Défaillant'**
  String get healthFailing;

  /// No description provided for @healthUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de mesure'**
  String get healthUnknown;

  /// No description provided for @healthDetail.
  ///
  /// In fr, this message translates to:
  /// **'Médiane {latency} · {percent} % de réussite'**
  String healthDetail(Object latency, int percent);

  /// No description provided for @healthSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Santé : {level}, {detail}'**
  String healthSemantic(Object level, Object detail);

  /// No description provided for @resetHealth.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser les mesures de {name}'**
  String resetHealth(Object name);

  /// No description provided for @localFolders.
  ///
  /// In fr, this message translates to:
  /// **'Dossiers locaux'**
  String get localFolders;

  /// No description provided for @localFoldersHint.
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos stockées sur cet appareil'**
  String get localFoldersHint;

  /// No description provided for @localAddFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un dossier'**
  String get localAddFolder;

  /// No description provided for @localEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun dossier. Ajoutez un dossier de vidéos pour les retrouver dans Lumio.'**
  String get localEmpty;

  /// No description provided for @localVideoCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune vidéo} =1{1 vidéo} other{{count} vidéos}}'**
  String localVideoCount(int count);

  /// No description provided for @localScanNow.
  ///
  /// In fr, this message translates to:
  /// **'Analyser maintenant'**
  String get localScanNow;

  /// No description provided for @localScanning.
  ///
  /// In fr, this message translates to:
  /// **'Analyse en cours…'**
  String get localScanning;

  /// No description provided for @localScanDone.
  ///
  /// In fr, this message translates to:
  /// **'Analyse terminée : {count, plural, =0{aucune vidéo} =1{1 vidéo} other{{count} vidéos}}'**
  String localScanDone(int count);

  /// No description provided for @localRemoveFolder.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le dossier {path}'**
  String localRemoveFolder(String path);

  /// No description provided for @localFolderRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Dossier retiré de Lumio. Vos fichiers ne sont pas touchés.'**
  String get localFolderRemoved;

  /// No description provided for @localPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Lumio a besoin d\'accéder à vos vidéos. Autorisez l\'accès dans les réglages de l\'appareil.'**
  String get localPermissionDenied;

  /// No description provided for @localPickerUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le sélecteur de dossier n\'est pas disponible. Saisissez le chemin du dossier.'**
  String get localPickerUnavailable;

  /// No description provided for @localPathTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chemin du dossier'**
  String get localPathTitle;

  /// No description provided for @localPathLabel.
  ///
  /// In fr, this message translates to:
  /// **'Chemin'**
  String get localPathLabel;

  /// No description provided for @localPathHint.
  ///
  /// In fr, this message translates to:
  /// **'/storage/emulated/0/Movies'**
  String get localPathHint;

  /// No description provided for @localChooseFolder.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans le sélecteur'**
  String get localChooseFolder;

  /// No description provided for @localTypePath.
  ///
  /// In fr, this message translates to:
  /// **'Saisir un chemin'**
  String get localTypePath;

  /// No description provided for @localSdNote.
  ///
  /// In fr, this message translates to:
  /// **'Le sélecteur n\'atteint que le stockage interne. Pour une carte SD ou une clé USB, saisissez le chemin.'**
  String get localSdNote;

  /// No description provided for @localFolderMissing.
  ///
  /// In fr, this message translates to:
  /// **'Ce dossier est introuvable.'**
  String get localFolderMissing;

  /// No description provided for @localFolderDenied.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé à ce dossier.'**
  String get localFolderDenied;

  /// No description provided for @localFolderOverlap.
  ///
  /// In fr, this message translates to:
  /// **'Ce dossier recoupe un dossier déjà ajouté.'**
  String get localFolderOverlap;

  /// No description provided for @localFolderAdded.
  ///
  /// In fr, this message translates to:
  /// **'Dossier ajouté : {count, plural, =0{aucune vidéo} =1{1 vidéo} other{{count} vidéos}}'**
  String localFolderAdded(int count);

  /// No description provided for @localScanFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'analyse du dossier a échoué.'**
  String get localScanFailed;

  /// No description provided for @localFixTitle.
  ///
  /// In fr, this message translates to:
  /// **'Corriger le titre'**
  String get localFixTitle;

  /// No description provided for @localFixLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get localFixLabel;

  /// No description provided for @localFixReset.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir le titre détecté'**
  String get localFixReset;

  /// No description provided for @localFileMissing.
  ///
  /// In fr, this message translates to:
  /// **'Fichier introuvable : il a peut-être été déplacé. Relancez l\'analyse.'**
  String get localFileMissing;

  /// No description provided for @localPlayFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire ce fichier.'**
  String get localPlayFailed;

  /// No description provided for @localDetected.
  ///
  /// In fr, this message translates to:
  /// **'Détecté : {title}'**
  String localDetected(String title);

  /// No description provided for @localScanIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Analyse incomplète : dossier trop volumineux'**
  String get localScanIncomplete;

  /// No description provided for @localFolderForbidden.
  ///
  /// In fr, this message translates to:
  /// **'Ce dossier ne peut pas être ajouté (dossier système ou chemin non absolu).'**
  String get localFolderForbidden;

  /// No description provided for @jellyfinServers.
  ///
  /// In fr, this message translates to:
  /// **'Serveurs Jellyfin'**
  String get jellyfinServers;

  /// No description provided for @jellyfinServersHint.
  ///
  /// In fr, this message translates to:
  /// **'Vos bibliothèques Jellyfin sur l\'accueil'**
  String get jellyfinServersHint;

  /// No description provided for @jellyfinAddServer.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un serveur'**
  String get jellyfinAddServer;

  /// No description provided for @jellyfinEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun serveur. Ajoutez un serveur Jellyfin pour retrouver ses bibliothèques dans Lumio.'**
  String get jellyfinEmpty;

  /// No description provided for @jellyfinServerUrl.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du serveur'**
  String get jellyfinServerUrl;

  /// No description provided for @jellyfinServerUrlHint.
  ///
  /// In fr, this message translates to:
  /// **'https://jellyfin.exemple.fr'**
  String get jellyfinServerUrlHint;

  /// No description provided for @jellyfinUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get jellyfinUser;

  /// No description provided for @jellyfinPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get jellyfinPassword;

  /// No description provided for @jellyfinConnect.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get jellyfinConnect;

  /// No description provided for @jellyfinConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion…'**
  String get jellyfinConnecting;

  /// No description provided for @jellyfinSignedInAs.
  ///
  /// In fr, this message translates to:
  /// **'Connecté en tant que {user}'**
  String jellyfinSignedInAs(String user);

  /// No description provided for @jellyfinRemove.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter de {name}'**
  String jellyfinRemove(String name);

  /// No description provided for @jellyfinRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name} ?'**
  String jellyfinRemoveTitle(String name);

  /// No description provided for @jellyfinRemoveBody.
  ///
  /// In fr, this message translates to:
  /// **'Le jeton de connexion sera supprimé de cet appareil.'**
  String get jellyfinRemoveBody;

  /// No description provided for @jellyfinRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Serveur retiré'**
  String get jellyfinRemoved;

  /// No description provided for @jellyfinAdded.
  ///
  /// In fr, this message translates to:
  /// **'Serveur ajouté'**
  String get jellyfinAdded;

  /// No description provided for @jellyfinInsecureTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion non chiffrée'**
  String get jellyfinInsecureTitle;

  /// No description provided for @jellyfinInsecureBody.
  ///
  /// In fr, this message translates to:
  /// **'Connexion non chiffrée : votre mot de passe circulerait en clair. Préférez une adresse https.'**
  String get jellyfinInsecureBody;

  /// No description provided for @jellyfinInsecureContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer quand même'**
  String get jellyfinInsecureContinue;

  /// No description provided for @jellyfinLibraries.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèques'**
  String get jellyfinLibraries;

  /// No description provided for @jellyfinLoadMore.
  ///
  /// In fr, this message translates to:
  /// **'Charger la suite'**
  String get jellyfinLoadMore;

  /// No description provided for @jellyfinEmptyFolder.
  ///
  /// In fr, this message translates to:
  /// **'Aucun élément à afficher'**
  String get jellyfinEmptyFolder;

  /// No description provided for @jellyfinPlayFailed.
  ///
  /// In fr, this message translates to:
  /// **'Lecture impossible : le serveur Jellyfin n\'a pas répondu.'**
  String get jellyfinPlayFailed;

  /// No description provided for @jellyfinErrAuth.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'utilisateur ou mot de passe incorrect.'**
  String get jellyfinErrAuth;

  /// No description provided for @jellyfinErrExpired.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée. Reconnectez-vous au serveur.'**
  String get jellyfinErrExpired;

  /// No description provided for @jellyfinErrCert.
  ///
  /// In fr, this message translates to:
  /// **'Certificat du serveur invalide : la connexion est refusée.'**
  String get jellyfinErrCert;

  /// No description provided for @jellyfinErrTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Délai dépassé : le serveur Jellyfin ne répond pas.'**
  String get jellyfinErrTimeout;

  /// No description provided for @jellyfinErrUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Serveur Jellyfin injoignable.'**
  String get jellyfinErrUnreachable;

  /// No description provided for @jellyfinErrServer.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur Jellyfin est en erreur (HTTP {status}).'**
  String jellyfinErrServer(int status);

  /// No description provided for @jellyfinErrRefused.
  ///
  /// In fr, this message translates to:
  /// **'Requête refusée par le serveur Jellyfin (HTTP {status}).'**
  String jellyfinErrRefused(int status);

  /// No description provided for @jellyfinErrInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Réponse inattendue : est-ce bien un serveur Jellyfin ?'**
  String get jellyfinErrInvalid;

  /// No description provided for @jellyfinErrTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Réponse du serveur trop volumineuse.'**
  String get jellyfinErrTooLarge;

  /// No description provided for @jellyfinErrRedirect.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur redirige vers une autre adresse : saisissez l\'adresse finale.'**
  String get jellyfinErrRedirect;

  /// No description provided for @jellyfinErrAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du serveur invalide.'**
  String get jellyfinErrAddress;

  /// No description provided for @trackingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivi (Trakt)'**
  String get trackingTitle;

  /// No description provided for @trackingNoConnectHint.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bouton « Connecter » tant que l\'application n\'est pas configurée.'**
  String get trackingNoConnectHint;

  /// No description provided for @trackingHint.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez vos lectures sur votre compte'**
  String get trackingHint;

  /// No description provided for @trackingTrakt.
  ///
  /// In fr, this message translates to:
  /// **'Trakt'**
  String get trackingTrakt;

  /// No description provided for @trackingNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Non configuré : les identifiants de l\'application Trakt sont absents. Rien n\'est envoyé.'**
  String get trackingNotConfigured;

  /// No description provided for @trackingConnectedShort.
  ///
  /// In fr, this message translates to:
  /// **'Connecté'**
  String get trackingConnectedShort;

  /// No description provided for @trackingNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Non connecté'**
  String get trackingNotConnected;

  /// No description provided for @trackingConnected.
  ///
  /// In fr, this message translates to:
  /// **'Connecté : vos lectures sont enregistrées sur Trakt.'**
  String get trackingConnected;

  /// No description provided for @trackingReauth.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion nécessaire : Trakt a refusé la connexion. Reconnectez le compte pour reprendre l\'envoi.'**
  String get trackingReauth;

  /// No description provided for @trackingConnect.
  ///
  /// In fr, this message translates to:
  /// **'Connecter Trakt'**
  String get trackingConnect;

  /// No description provided for @trackingDisconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter Trakt'**
  String get trackingDisconnect;

  /// No description provided for @trackingDisconnected.
  ///
  /// In fr, this message translates to:
  /// **'Trakt déconnecté'**
  String get trackingDisconnected;

  /// No description provided for @trackingPending.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun envoi en attente} =1{1 envoi en attente} other{{count} envois en attente}}'**
  String trackingPending(int count);

  /// No description provided for @trackingRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer l\'envoi'**
  String get trackingRetry;

  /// No description provided for @trackingRetried.
  ///
  /// In fr, this message translates to:
  /// **'Envoi relancé'**
  String get trackingRetried;

  /// No description provided for @trackingKidAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser le suivi pour ce profil enfant'**
  String get trackingKidAllow;

  /// No description provided for @trackingKidAllowHint.
  ///
  /// In fr, this message translates to:
  /// **'Seul un parent peut l\'activer. Sans cela, rien n\'est envoyé pour ce profil.'**
  String get trackingKidAllowHint;

  /// No description provided for @trackingAuthTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connecter Trakt'**
  String get trackingAuthTitle;

  /// No description provided for @trackingAuthStep.
  ///
  /// In fr, this message translates to:
  /// **'Sur un autre appareil, ouvrez cette adresse puis saisissez le code :'**
  String get trackingAuthStep;

  /// No description provided for @trackingAuthWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente de votre autorisation…'**
  String get trackingAuthWaiting;

  /// No description provided for @trackingAuthDone.
  ///
  /// In fr, this message translates to:
  /// **'Trakt est connecté.'**
  String get trackingAuthDone;

  /// No description provided for @trackingAuthDenied.
  ///
  /// In fr, this message translates to:
  /// **'Autorisation refusée.'**
  String get trackingAuthDenied;

  /// No description provided for @trackingAuthExpired.
  ///
  /// In fr, this message translates to:
  /// **'Le code a expiré ou n\'est plus valable. Demandez-en un nouveau.'**
  String get trackingAuthExpired;

  /// No description provided for @trackingAuthNewCode.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code'**
  String get trackingAuthNewCode;

  /// No description provided for @trackingAuthUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le service de suivi est injoignable. Réessayez plus tard.'**
  String get trackingAuthUnavailable;

  /// No description provided for @trackingQrSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Code QR vers l\'adresse d\'autorisation'**
  String get trackingQrSemantic;

  /// No description provided for @homeCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier'**
  String get homeCalendar;

  /// No description provided for @calendarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier des sorties'**
  String get calendarTitle;

  /// No description provided for @calendarEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune série dans votre liste. Ajoutez une série à « Ma liste » pour suivre ses prochains épisodes.'**
  String get calendarEmpty;

  /// No description provided for @calendarNothingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sortie prévue dans les 30 prochains jours.'**
  String get calendarNothingSoon;

  /// No description provided for @calendarLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le calendrier.'**
  String get calendarLoadError;

  /// No description provided for @calendarToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get calendarToday;

  /// No description provided for @calendarTomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get calendarTomorrow;

  /// No description provided for @calendarUnknownHeader.
  ///
  /// In fr, this message translates to:
  /// **'Date inconnue'**
  String get calendarUnknownHeader;

  /// No description provided for @calendarUnknownEntry.
  ///
  /// In fr, this message translates to:
  /// **'Date inconnue'**
  String get calendarUnknownEntry;

  /// No description provided for @calendarEpisodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'S{season} · É{episode}'**
  String calendarEpisodeLabel(int season, int episode);

  /// No description provided for @calendarEpisodeOnly.
  ///
  /// In fr, this message translates to:
  /// **'Épisode {episode}'**
  String calendarEpisodeOnly(int episode);

  /// No description provided for @calendarNotify.
  ///
  /// In fr, this message translates to:
  /// **'Me prévenir des nouveaux épisodes'**
  String get calendarNotify;

  /// No description provided for @calendarNotifyHint.
  ///
  /// In fr, this message translates to:
  /// **'Notification locale le jour de la sortie, sur cet appareil. Désactivé par défaut.'**
  String get calendarNotifyHint;

  /// No description provided for @calendarNotifyDenied.
  ///
  /// In fr, this message translates to:
  /// **'Notifications refusées : activez-les dans les réglages du système.'**
  String get calendarNotifyDenied;

  /// No description provided for @calendarNotifyOn.
  ///
  /// In fr, this message translates to:
  /// **'Vous serez prévenu des prochains épisodes.'**
  String get calendarNotifyOn;

  /// No description provided for @calendarNotifyChannel.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux épisodes'**
  String get calendarNotifyChannel;

  /// No description provided for @calendarNotifyBody.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel épisode disponible : {episode}'**
  String calendarNotifyBody(String episode);

  /// No description provided for @calendarNotifyError.
  ///
  /// In fr, this message translates to:
  /// **'Notifications non programmées : une erreur est survenue. Réessayez en rouvrant le calendrier.'**
  String get calendarNotifyError;

  /// No description provided for @castTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Diffuser sur un appareil'**
  String get castTooltip;

  /// No description provided for @castChooseDevice.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un appareil'**
  String get castChooseDevice;

  /// No description provided for @castSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche d\'appareils…'**
  String get castSearching;

  /// No description provided for @castNoDevice.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appareil trouvé'**
  String get castNoDevice;

  /// No description provided for @castNoDeviceHint.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez que le téléviseur est allumé et sur le même réseau Wi-Fi.'**
  String get castNoDeviceHint;

  /// No description provided for @castPlayingOn.
  ///
  /// In fr, this message translates to:
  /// **'Lecture sur {device}'**
  String castPlayingOn(String device);

  /// No description provided for @castStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter la diffusion'**
  String get castStop;

  /// No description provided for @castFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de diffuser sur cet appareil.'**
  String get castFailed;

  /// No description provided for @castUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Ce flux ne peut pas être diffusé sur un appareil.'**
  String get castUnsupported;

  /// No description provided for @castLost.
  ///
  /// In fr, this message translates to:
  /// **'Appareil de diffusion perdu : la lecture reprend ici.'**
  String get castLost;

  /// No description provided for @castNetworkError.
  ///
  /// In fr, this message translates to:
  /// **'Aucun réseau local commun avec cet appareil.'**
  String get castNetworkError;

  /// No description provided for @partyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Regarder ensemble'**
  String get partyTitle;

  /// No description provided for @partyHint.
  ///
  /// In fr, this message translates to:
  /// **'Lecture synchronisée avec des proches'**
  String get partyHint;

  /// No description provided for @partyTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Regarder ensemble'**
  String get partyTooltip;

  /// No description provided for @partyCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer une salle'**
  String get partyCreate;

  /// No description provided for @partyCreateHint.
  ///
  /// In fr, this message translates to:
  /// **'Vous invitez : seules la position et l\'état de lecture sont partagés. Chacun ouvre le titre avec ses propres addons.'**
  String get partyCreateHint;

  /// No description provided for @partyJoinTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre une salle'**
  String get partyJoinTitle;

  /// No description provided for @partyJoinField.
  ///
  /// In fr, this message translates to:
  /// **'Lien d\'invitation'**
  String get partyJoinField;

  /// No description provided for @partyJoinHint.
  ///
  /// In fr, this message translates to:
  /// **'Collez le lien reçu (lumio://party…).'**
  String get partyJoinHint;

  /// No description provided for @partyJoinButton.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get partyJoinButton;

  /// No description provided for @partyConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion à la salle…'**
  String get partyConnecting;

  /// No description provided for @partyInviteCode.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'invitation'**
  String get partyInviteCode;

  /// No description provided for @partyLinkLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lien à partager (valable 6 h)'**
  String get partyLinkLabel;

  /// No description provided for @partyCopyLink.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get partyCopyLink;

  /// No description provided for @partyLinkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié.'**
  String get partyLinkCopied;

  /// No description provided for @partyQrLabel.
  ///
  /// In fr, this message translates to:
  /// **'QR code du lien d\'invitation'**
  String get partyQrLabel;

  /// No description provided for @partyParticipants.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 participant} other{{count} participants}}'**
  String partyParticipants(int count);

  /// No description provided for @partyAllControl.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde peut contrôler'**
  String get partyAllControl;

  /// No description provided for @partyAllControlHint.
  ///
  /// In fr, this message translates to:
  /// **'Sinon, seul l\'hôte met en pause ou avance.'**
  String get partyAllControlHint;

  /// No description provided for @partyOpenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le titre'**
  String get partyOpenTitle;

  /// No description provided for @partyLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la salle'**
  String get partyLeave;

  /// No description provided for @partyRoleHost.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes l\'hôte'**
  String get partyRoleHost;

  /// No description provided for @partyRoleGuest.
  ///
  /// In fr, this message translates to:
  /// **'Vous suivez l\'hôte'**
  String get partyRoleGuest;

  /// No description provided for @partyErrInvalidLink.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien d\'invitation n\'est pas valide.'**
  String get partyErrInvalidLink;

  /// No description provided for @partyErrWrongCode.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'invitation refusé.'**
  String get partyErrWrongCode;

  /// No description provided for @partyErrFull.
  ///
  /// In fr, this message translates to:
  /// **'La salle est pleine (8 personnes).'**
  String get partyErrFull;

  /// No description provided for @partyErrNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Cette salle n\'existe plus.'**
  String get partyErrNotFound;

  /// No description provided for @partyErrRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais, réessayez dans un moment.'**
  String get partyErrRateLimited;

  /// No description provided for @partyErrUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre la salle.'**
  String get partyErrUnavailable;

  /// No description provided for @partyHostOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seul l\'hôte contrôle la lecture dans cette salle.'**
  String get partyHostOnly;

  /// No description provided for @tvNavHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get tvNavHome;

  /// No description provided for @tvSwitchProfile.
  ///
  /// In fr, this message translates to:
  /// **'Changer de profil'**
  String get tvSwitchProfile;

  /// No description provided for @tvEmptyEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'BIENVENUE'**
  String get tvEmptyEyebrow;

  /// No description provided for @tvEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre accueil attend ses sources'**
  String get tvEmptyTitle;

  /// No description provided for @tvEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Lumio ne contient aucun contenu. Ajoutez un addon de confiance, un dossier de vos vidéos ou votre serveur Jellyfin : vos catalogues apparaîtront ici en rangées.'**
  String get tvEmptyBody;

  /// No description provided for @tvEmptyLocal.
  ///
  /// In fr, this message translates to:
  /// **'Dossier local'**
  String get tvEmptyLocal;

  /// No description provided for @tvEmptyJellyfin.
  ///
  /// In fr, this message translates to:
  /// **'Serveur Jellyfin'**
  String get tvEmptyJellyfin;

  /// No description provided for @tvEmptyStep1Title.
  ///
  /// In fr, this message translates to:
  /// **'Collez un lien'**
  String get tvEmptyStep1Title;

  /// No description provided for @tvEmptyStep1Body.
  ///
  /// In fr, this message translates to:
  /// **'Le lien manifest.json de l\'addon, ou un lien stremio://.'**
  String get tvEmptyStep1Body;

  /// No description provided for @tvEmptyStep2Title.
  ///
  /// In fr, this message translates to:
  /// **'Ou envoyez-le du téléphone'**
  String get tvEmptyStep2Title;

  /// No description provided for @tvEmptyStep2Body.
  ///
  /// In fr, this message translates to:
  /// **'Scannez le QR code affiché, collez le lien sur le téléphone.'**
  String get tvEmptyStep2Body;

  /// No description provided for @tvEmptyStep3Title.
  ///
  /// In fr, this message translates to:
  /// **'Regardez'**
  String get tvEmptyStep3Title;

  /// No description provided for @tvEmptyStep3Body.
  ///
  /// In fr, this message translates to:
  /// **'Catalogues, « Continuer » et « Ma liste » remplissent l\'accueil.'**
  String get tvEmptyStep3Body;

  /// No description provided for @tvOnbTagline.
  ///
  /// In fr, this message translates to:
  /// **'Votre bibliothèque, vos sources.'**
  String get tvOnbTagline;

  /// No description provided for @tvOnbTaglineBody.
  ///
  /// In fr, this message translates to:
  /// **'Réunissez films, séries et fichiers locaux au même endroit.'**
  String get tvOnbTaglineBody;

  /// No description provided for @tvOnbDefault.
  ///
  /// In fr, this message translates to:
  /// **'Par défaut'**
  String get tvOnbDefault;

  /// No description provided for @tvOnbProfileHeading.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre profil'**
  String get tvOnbProfileHeading;

  /// No description provided for @tvOnbProfileBody.
  ///
  /// In fr, this message translates to:
  /// **'Chaque profil garde sa liste, sa progression et ses réglages.'**
  String get tvOnbProfileBody;

  /// No description provided for @tvOnbLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get tvOnbLater;

  /// No description provided for @tvOnbFinish.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get tvOnbFinish;

  /// No description provided for @tvOnbAddonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un addon'**
  String get tvOnbAddonTitle;

  /// No description provided for @tvOnbAddonBody.
  ///
  /// In fr, this message translates to:
  /// **'Collez un lien ou scannez un QR code'**
  String get tvOnbAddonBody;

  /// No description provided for @tvOnbJellyfinTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un serveur Jellyfin'**
  String get tvOnbJellyfinTitle;

  /// No description provided for @tvOnbJellyfinBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre médiathèque personnelle'**
  String get tvOnbJellyfinBody;

  /// No description provided for @tvOnbLocalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un dossier local'**
  String get tvOnbLocalTitle;

  /// No description provided for @tvOnbLocalBody.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers de cet appareil ou du réseau'**
  String get tvOnbLocalBody;

  /// No description provided for @tvOnbKidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil enfant'**
  String get tvOnbKidTitle;

  /// No description provided for @tvOnbKidBody.
  ///
  /// In fr, this message translates to:
  /// **'Filtre par âge et PIN pour quitter'**
  String get tvOnbKidBody;

  /// No description provided for @quitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter Lumio ?'**
  String get quitTitle;

  /// No description provided for @quitBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous reviendrez à l\'écran d\'accueil de la box.'**
  String get quitBody;

  /// No description provided for @quitAction.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get quitAction;

  /// No description provided for @libraryCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 titre} =1{1 titre} other{{count} titres}}'**
  String libraryCount(int count);

  /// No description provided for @customizeHomeHint.
  ///
  /// In fr, this message translates to:
  /// **'Masquez ou réordonnez les rangées de l\'accueil.'**
  String get customizeHomeHint;

  /// No description provided for @settingsCatSources.
  ///
  /// In fr, this message translates to:
  /// **'Sources'**
  String get settingsCatSources;

  /// No description provided for @settingsCatPlayback.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get settingsCatPlayback;

  /// No description provided for @settingsCatTorrents.
  ///
  /// In fr, this message translates to:
  /// **'Torrents et VPN'**
  String get settingsCatTorrents;

  /// No description provided for @settingsCatProfiles.
  ///
  /// In fr, this message translates to:
  /// **'Profils et contrôle parental'**
  String get settingsCatProfiles;

  /// No description provided for @settingsCatTracking.
  ///
  /// In fr, this message translates to:
  /// **'Suivi Trakt'**
  String get settingsCatTracking;

  /// No description provided for @settingsCatBackup.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde et import'**
  String get settingsCatBackup;

  /// No description provided for @settingsCatGeneral.
  ///
  /// In fr, this message translates to:
  /// **'Général'**
  String get settingsCatGeneral;

  /// No description provided for @settingsSourcesHint.
  ///
  /// In fr, this message translates to:
  /// **'D\'où viennent vos films et séries.'**
  String get settingsSourcesHint;

  /// No description provided for @secAddons.
  ///
  /// In fr, this message translates to:
  /// **'Addons'**
  String get secAddons;

  /// No description provided for @secPersonalSources.
  ///
  /// In fr, this message translates to:
  /// **'Mes sources personnelles'**
  String get secPersonalSources;

  /// No description provided for @secSourceChoice.
  ///
  /// In fr, this message translates to:
  /// **'Choix de la source'**
  String get secSourceChoice;

  /// No description provided for @secLanguages.
  ///
  /// In fr, this message translates to:
  /// **'Langues'**
  String get secLanguages;

  /// No description provided for @secProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection'**
  String get secProtection;

  /// No description provided for @secStorage.
  ///
  /// In fr, this message translates to:
  /// **'Stockage et débit'**
  String get secStorage;

  /// No description provided for @secInterfaceLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'interface'**
  String get secInterfaceLanguage;

  /// No description provided for @secProfiles.
  ///
  /// In fr, this message translates to:
  /// **'Profils'**
  String get secProfiles;

  /// No description provided for @settingsForProfile.
  ///
  /// In fr, this message translates to:
  /// **'Pour le profil {name}.'**
  String settingsForProfile(String name);

  /// No description provided for @addonsInstalledCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun addon installé} =1{1 addon installé} other{{count} addons installés}}'**
  String addonsInstalledCount(int count);

  /// No description provided for @settingsProfilesHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter, modifier ou supprimer des profils ; le PIN parent protège les profils enfants.'**
  String get settingsProfilesHint;

  /// No description provided for @settingsProfilesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 profil} other{{count} profils}}'**
  String settingsProfilesCount(int count);

  /// No description provided for @searchResultsHeader.
  ///
  /// In fr, this message translates to:
  /// **'{what} · {count, plural, =1{1 résultat} other{{count} résultats}}'**
  String searchResultsHeader(String what, int count);

  /// No description provided for @searchMoviesAndSeries.
  ///
  /// In fr, this message translates to:
  /// **'Films et séries'**
  String get searchMoviesAndSeries;

  /// No description provided for @pinChecking.
  ///
  /// In fr, this message translates to:
  /// **'Vérification…'**
  String get pinChecking;

  /// No description provided for @addonsPriorityHint.
  ///
  /// In fr, this message translates to:
  /// **'L\'ordre décide de la priorité des sources.'**
  String get addonsPriorityHint;

  /// No description provided for @profileAdult.
  ///
  /// In fr, this message translates to:
  /// **'Profil adulte'**
  String get profileAdult;

  /// No description provided for @profileChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get profileChange;

  /// No description provided for @settingsBackHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour : accueil'**
  String get settingsBackHome;

  /// No description provided for @vpnCardActive.
  ///
  /// In fr, this message translates to:
  /// **'VPN actif · {name}'**
  String vpnCardActive(String name);

  /// No description provided for @vpnCardStopHint.
  ///
  /// In fr, this message translates to:
  /// **'Les torrents s\'arrêtent si le VPN tombe.'**
  String get vpnCardStopHint;

  /// No description provided for @vpnCardIpHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre adresse IP est visible des autres pairs sans VPN.'**
  String get vpnCardIpHint;

  /// No description provided for @cacheUsedOf.
  ///
  /// In fr, this message translates to:
  /// **'{used} utilisés sur'**
  String cacheUsedOf(String used);

  /// No description provided for @sizeGbDecimal.
  ///
  /// In fr, this message translates to:
  /// **'{n} Go'**
  String sizeGbDecimal(String n);

  /// No description provided for @profileAdultShort.
  ///
  /// In fr, this message translates to:
  /// **'Adulte'**
  String get profileAdultShort;

  /// No description provided for @manageProfilesHint.
  ///
  /// In fr, this message translates to:
  /// **'Modifier un profil : nom, profil enfant et limite d\'âge, verrou par PIN. Six profils au maximum.'**
  String get manageProfilesHint;

  /// No description provided for @profileEditorHint.
  ///
  /// In fr, this message translates to:
  /// **'Pour un profil adulte, l\'option « Verrouiller par PIN » remplace la limite d\'âge : « Le PIN parent est demandé pour ouvrir ce profil. »'**
  String get profileEditorHint;

  /// No description provided for @subtitleAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get subtitleAppearance;

  /// No description provided for @subtitleSmaller.
  ///
  /// In fr, this message translates to:
  /// **'Réduire les sous-titres'**
  String get subtitleSmaller;

  /// No description provided for @subtitleLarger.
  ///
  /// In fr, this message translates to:
  /// **'Agrandir les sous-titres'**
  String get subtitleLarger;

  /// No description provided for @subtitleSizeSmall.
  ///
  /// In fr, this message translates to:
  /// **'Petite'**
  String get subtitleSizeSmall;

  /// No description provided for @subtitleSizeNormal.
  ///
  /// In fr, this message translates to:
  /// **'Normale'**
  String get subtitleSizeNormal;

  /// No description provided for @subtitleSizeLarge.
  ///
  /// In fr, this message translates to:
  /// **'Grande'**
  String get subtitleSizeLarge;

  /// No description provided for @subtitleSizeXLarge.
  ///
  /// In fr, this message translates to:
  /// **'Très grande'**
  String get subtitleSizeXLarge;

  /// No description provided for @subtitleOtherLanguages.
  ///
  /// In fr, this message translates to:
  /// **'Autres langues…'**
  String get subtitleOtherLanguages;

  /// No description provided for @subtitleHideOtherLanguages.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les autres langues'**
  String get subtitleHideOtherLanguages;

  /// No description provided for @seekBackShort.
  ///
  /// In fr, this message translates to:
  /// **'−10 s'**
  String get seekBackShort;

  /// No description provided for @seekForwardShort.
  ///
  /// In fr, this message translates to:
  /// **'+10 s'**
  String get seekForwardShort;

  /// No description provided for @tracksShort.
  ///
  /// In fr, this message translates to:
  /// **'Pistes'**
  String get tracksShort;

  /// No description provided for @nextShort.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get nextShort;

  /// No description provided for @playbackSpeed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse {rate}×'**
  String playbackSpeed(String rate);

  /// No description provided for @castShort.
  ///
  /// In fr, this message translates to:
  /// **'Diffuser'**
  String get castShort;

  /// No description provided for @partyShort.
  ///
  /// In fr, this message translates to:
  /// **'Ensemble'**
  String get partyShort;

  /// No description provided for @localSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos stockées sur cet appareil'**
  String get localSubtitle;

  /// No description provided for @heroResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get heroResume;

  /// No description provided for @heroMinutesLeft.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min restantes'**
  String heroMinutesLeft(Object minutes);

  /// No description provided for @searchCaption.
  ///
  /// In fr, this message translates to:
  /// **'Recherche dans tous vos addons, vos dossiers.'**
  String get searchCaption;

  /// No description provided for @streamsAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Flux disponibles · {count}'**
  String streamsAvailable(Object count);

  /// No description provided for @streamGroupAddon.
  ///
  /// In fr, this message translates to:
  /// **'ADDON'**
  String get streamGroupAddon;

  /// No description provided for @healthLineGood.
  ///
  /// In fr, this message translates to:
  /// **'Santé : bonne'**
  String get healthLineGood;

  /// No description provided for @healthLineSlow.
  ///
  /// In fr, this message translates to:
  /// **'Santé : lente'**
  String get healthLineSlow;

  /// No description provided for @healthLineBad.
  ///
  /// In fr, this message translates to:
  /// **'Santé : mauvaise'**
  String get healthLineBad;

  /// No description provided for @seedersCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} seeders'**
  String seedersCount(Object count);

  /// No description provided for @detailUnavailableBody.
  ///
  /// In fr, this message translates to:
  /// **'Fiche indisponible. Réessayez.'**
  String get detailUnavailableBody;

  /// No description provided for @addToListShort.
  ///
  /// In fr, this message translates to:
  /// **'+ Ma liste'**
  String get addToListShort;

  /// No description provided for @streamBadgeDirect.
  ///
  /// In fr, this message translates to:
  /// **'Direct'**
  String get streamBadgeDirect;

  /// No description provided for @streamBadgeTorrent.
  ///
  /// In fr, this message translates to:
  /// **'Torrent'**
  String get streamBadgeTorrent;

  /// No description provided for @secAddonsPriority.
  ///
  /// In fr, this message translates to:
  /// **'Addons · l\'ordre décide de la priorité'**
  String get secAddonsPriority;

  /// No description provided for @addonsMenuHint.
  ///
  /// In fr, this message translates to:
  /// **'OK sur un addon : monter, descendre, supprimer.'**
  String get addonsMenuHint;

  /// No description provided for @healthShortGood.
  ///
  /// In fr, this message translates to:
  /// **'Bonne santé'**
  String get healthShortGood;

  /// No description provided for @healthShortSlow.
  ///
  /// In fr, this message translates to:
  /// **'Lente'**
  String get healthShortSlow;

  /// No description provided for @healthShortOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get healthShortOffline;

  /// No description provided for @menuMoveUp.
  ///
  /// In fr, this message translates to:
  /// **'Monter'**
  String get menuMoveUp;

  /// No description provided for @menuMoveDown.
  ///
  /// In fr, this message translates to:
  /// **'Descendre'**
  String get menuMoveDown;

  /// No description provided for @menuResetHealth.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser les mesures'**
  String get menuResetHealth;

  /// No description provided for @localFoldersCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun dossier} =1{1 dossier} other{{count} dossiers}}'**
  String localFoldersCount(int count);

  /// No description provided for @localLastScan.
  ///
  /// In fr, this message translates to:
  /// **'dernière analyse {ago}'**
  String localLastScan(Object ago);

  /// No description provided for @agoMinutes.
  ///
  /// In fr, this message translates to:
  /// **'il y a {n} min'**
  String agoMinutes(int n);

  /// No description provided for @agoHours.
  ///
  /// In fr, this message translates to:
  /// **'il y a {n} h'**
  String agoHours(int n);

  /// No description provided for @agoDays.
  ///
  /// In fr, this message translates to:
  /// **'il y a {n} j'**
  String agoDays(int n);

  /// No description provided for @jellyfinServersCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun serveur} =1{1 serveur} other{{count} serveurs}}'**
  String jellyfinServersCount(int count);

  /// No description provided for @addAddonBreadcrumb.
  ///
  /// In fr, this message translates to:
  /// **'Réglages › Sources'**
  String get addAddonBreadcrumb;

  /// No description provided for @addonTabCatalog.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue'**
  String get addonTabCatalog;

  /// No description provided for @addonTabLink.
  ///
  /// In fr, this message translates to:
  /// **'Par lien'**
  String get addonTabLink;

  /// No description provided for @addonTabPhone.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le téléphone'**
  String get addonTabPhone;

  /// No description provided for @catPopular.
  ///
  /// In fr, this message translates to:
  /// **'Populaires'**
  String get catPopular;

  /// No description provided for @addonServerLine.
  ///
  /// In fr, this message translates to:
  /// **'Serveur : {host}'**
  String addonServerLine(String host);

  /// No description provided for @addonReplacesNote.
  ///
  /// In fr, this message translates to:
  /// **'Remplace la version déjà installée de « {name} ».'**
  String addonReplacesNote(String name);

  /// No description provided for @unknownTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre inconnu'**
  String get unknownTitle;

  /// No description provided for @catOfficial.
  ///
  /// In fr, this message translates to:
  /// **'Officiels'**
  String get catOfficial;

  /// No description provided for @catMoviesSeries.
  ///
  /// In fr, this message translates to:
  /// **'Films et séries'**
  String get catMoviesSeries;

  /// No description provided for @catTorrents.
  ///
  /// In fr, this message translates to:
  /// **'Torrents'**
  String get catTorrents;

  /// No description provided for @catDebrid.
  ///
  /// In fr, this message translates to:
  /// **'Débrideurs'**
  String get catDebrid;

  /// No description provided for @catSubtitles.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get catSubtitles;

  /// No description provided for @catAnime.
  ///
  /// In fr, this message translates to:
  /// **'Anime'**
  String get catAnime;

  /// No description provided for @catMetadata.
  ///
  /// In fr, this message translates to:
  /// **'Métadonnées'**
  String get catMetadata;

  /// No description provided for @catTracking.
  ///
  /// In fr, this message translates to:
  /// **'Suivi'**
  String get catTracking;

  /// No description provided for @catMore.
  ///
  /// In fr, this message translates to:
  /// **'Plus…'**
  String get catMore;

  /// No description provided for @catHttpStreams.
  ///
  /// In fr, this message translates to:
  /// **'Flux directs'**
  String get catHttpStreams;

  /// No description provided for @catUsenet.
  ///
  /// In fr, this message translates to:
  /// **'Usenet'**
  String get catUsenet;

  /// No description provided for @catAsianDrama.
  ///
  /// In fr, this message translates to:
  /// **'Drames asiatiques'**
  String get catAsianDrama;

  /// No description provided for @catBollywood.
  ///
  /// In fr, this message translates to:
  /// **'Bollywood'**
  String get catBollywood;

  /// No description provided for @catMusic.
  ///
  /// In fr, this message translates to:
  /// **'Musique'**
  String get catMusic;

  /// No description provided for @catRadios.
  ///
  /// In fr, this message translates to:
  /// **'Radios'**
  String get catRadios;

  /// No description provided for @catLiveTv.
  ///
  /// In fr, this message translates to:
  /// **'TV en direct'**
  String get catLiveTv;

  /// No description provided for @catMisc.
  ///
  /// In fr, this message translates to:
  /// **'Divers'**
  String get catMisc;

  /// No description provided for @catMoreTitle.
  ///
  /// In fr, this message translates to:
  /// **'Autres catégories'**
  String get catMoreTitle;

  /// No description provided for @catalogInstalled.
  ///
  /// In fr, this message translates to:
  /// **'Installé'**
  String get catalogInstalled;

  /// No description provided for @catalogLoadMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get catalogLoadMore;

  /// No description provided for @catalogRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get catalogRefresh;

  /// No description provided for @catalogOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne : liste enregistrée le {date}.'**
  String catalogOffline(Object date);

  /// No description provided for @catalogFallbackNote.
  ///
  /// In fr, this message translates to:
  /// **'Le site du catalogue est inaccessible : liste officielle réduite.'**
  String get catalogFallbackNote;

  /// No description provided for @catalogLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le catalogue.'**
  String get catalogLoadError;

  /// No description provided for @catalogEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun addon dans cette catégorie.'**
  String get catalogEmpty;

  /// No description provided for @catalogDetailError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire la fiche de cet addon.'**
  String get catalogDetailError;

  /// No description provided for @catalogCardMeta.
  ///
  /// In fr, this message translates to:
  /// **'★ {stars} · v{version}'**
  String catalogCardMeta(Object stars, Object version);

  /// No description provided for @catalogCardStars.
  ///
  /// In fr, this message translates to:
  /// **'★ {stars}'**
  String catalogCardStars(Object stars);

  /// No description provided for @chooseInstanceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un serveur'**
  String get chooseInstanceTitle;

  /// No description provided for @instanceNeedsSetup.
  ///
  /// In fr, this message translates to:
  /// **'à régler'**
  String get instanceNeedsSetup;

  /// No description provided for @addonLinkHelp.
  ///
  /// In fr, this message translates to:
  /// **'Lien manifest.json ou lien stremio://. Un lien copié sur cet appareil est proposé automatiquement.'**
  String get addonLinkHelp;

  /// No description provided for @addonPreviewLabel.
  ///
  /// In fr, this message translates to:
  /// **'APERÇU · v{version}'**
  String addonPreviewLabel(Object version);

  /// No description provided for @addonLinkTrust.
  ///
  /// In fr, this message translates to:
  /// **'Installez uniquement des sources de confiance : le lien peut contenir une clé personnelle, gardée chiffrée sur cet appareil.'**
  String get addonLinkTrust;

  /// No description provided for @phoneStep1.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone sur le même Wi-Fi que la TV'**
  String get phoneStep1;

  /// No description provided for @phoneStep2.
  ///
  /// In fr, this message translates to:
  /// **'Scannez le code : la page Lumio de cette TV s\'ouvre'**
  String get phoneStep2;

  /// No description provided for @phoneStep3.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un addon, appuyez sur Installer, puis confirmez ici sur la TV'**
  String get phoneStep3;

  /// No description provided for @phoneOrType.
  ///
  /// In fr, this message translates to:
  /// **'Ou tapez dans le navigateur du téléphone'**
  String get phoneOrType;

  /// No description provided for @phoneCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code de sécurité :'**
  String get phoneCodeLabel;

  /// No description provided for @phoneLive.
  ///
  /// In fr, this message translates to:
  /// **'Page ouverte tant que cet écran est affiché · aucun serveur externe'**
  String get phoneLive;

  /// No description provided for @phoneKeepOpen.
  ///
  /// In fr, this message translates to:
  /// **'Laissez cet écran ouvert pendant que vous utilisez votre téléphone.'**
  String get phoneKeepOpen;

  /// No description provided for @settingsManagePhonePress.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur OK'**
  String get settingsManagePhonePress;

  /// No description provided for @phoneConnected.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone connecté · page ouverte tant que cet écran est affiché'**
  String get phoneConnected;

  /// No description provided for @phoneLocked.
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais : un nouveau code est affiché, nouvel essai possible dans une minute'**
  String get phoneLocked;

  /// No description provided for @phoneNoNetworkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réseau local'**
  String get phoneNoNetworkTitle;

  /// No description provided for @phoneNoNetworkBody.
  ///
  /// In fr, this message translates to:
  /// **'Connectez la TV au Wi-Fi ou à l\'Ethernet de la maison : la page du téléphone n\'est jamais servie sur un VPN ni sur le réseau mobile.'**
  String get phoneNoNetworkBody;

  /// No description provided for @phoneIdleStopped.
  ///
  /// In fr, this message translates to:
  /// **'La page s\'est fermée après 10 minutes sans activité.'**
  String get phoneIdleStopped;

  /// No description provided for @phoneTooManyTries.
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais : la page est fermée par sécurité. Relancez-la pour obtenir un nouveau code.'**
  String get phoneTooManyTries;

  /// No description provided for @phoneErrorBody.
  ///
  /// In fr, this message translates to:
  /// **'La page n\'a pas pu démarrer. Réessayez.'**
  String get phoneErrorBody;

  /// No description provided for @phoneRestart.
  ///
  /// In fr, this message translates to:
  /// **'Relancer'**
  String get phoneRestart;

  /// No description provided for @phoneQrLabel.
  ///
  /// In fr, this message translates to:
  /// **'QR code de la page Lumio sur le réseau local'**
  String get phoneQrLabel;

  /// No description provided for @settingsManagePhone.
  ///
  /// In fr, this message translates to:
  /// **'Gérer depuis le téléphone'**
  String get settingsManagePhone;

  /// No description provided for @settingsManagePhoneNoNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Réseau local indisponible'**
  String get settingsManagePhoneNoNetwork;

  /// No description provided for @phoneAddWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Demande reçue du téléphone : vérifiez l\'aperçu et confirmez ici.'**
  String get phoneAddWaiting;

  /// No description provided for @addonInstall.
  ///
  /// In fr, this message translates to:
  /// **'Installer'**
  String get addonInstall;

  /// No description provided for @addonConfigure.
  ///
  /// In fr, this message translates to:
  /// **'Configurer'**
  String get addonConfigure;

  /// No description provided for @addonConfigurePortal.
  ///
  /// In fr, this message translates to:
  /// **'Configurer depuis le portail'**
  String get addonConfigurePortal;

  /// No description provided for @addonReconfigurePortal.
  ///
  /// In fr, this message translates to:
  /// **'Reconfigurer depuis le portail'**
  String get addonReconfigurePortal;

  /// No description provided for @addonSheetRequired.
  ///
  /// In fr, this message translates to:
  /// **'Cet addon demande un réglage avant de fonctionner (clé de débrideur, langues…). Le portail web du téléphone ou de l\'ordinateur sert à le configurer.'**
  String get addonSheetRequired;

  /// No description provided for @addonSheetConfigurable.
  ///
  /// In fr, this message translates to:
  /// **'Installez-le tel quel, ou choisissez vos réglages depuis le portail web.'**
  String get addonSheetConfigurable;

  /// No description provided for @portalAddonHint.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez cette page sur le portail : la fiche de « {name} » s’affiche directement.'**
  String portalAddonHint(Object name);

  /// No description provided for @typePageNoMovies.
  ///
  /// In fr, this message translates to:
  /// **'Vos addons ne proposent aucun catalogue de films'**
  String get typePageNoMovies;

  /// No description provided for @typePageNoSeries.
  ///
  /// In fr, this message translates to:
  /// **'Vos addons ne proposent aucun catalogue de séries'**
  String get typePageNoSeries;

  /// No description provided for @guideGotIt.
  ///
  /// In fr, this message translates to:
  /// **'Compris'**
  String get guideGotIt;

  /// No description provided for @guideHelp.
  ///
  /// In fr, this message translates to:
  /// **'Aide'**
  String get guideHelp;

  /// No description provided for @guideNoteKeyStays.
  ///
  /// In fr, this message translates to:
  /// **'Votre clé reste chiffrée sur la TV : elle n\'est jamais envoyée au téléphone.'**
  String get guideNoteKeyStays;

  /// No description provided for @guideCatalogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un addon du catalogue'**
  String get guideCatalogTitle;

  /// No description provided for @guideCatalogStep1.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un addon dans la grille.'**
  String get guideCatalogStep1;

  /// No description provided for @guideCatalogStep2.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur « Installer ».'**
  String get guideCatalogStep2;

  /// No description provided for @guideCatalogStep3.
  ///
  /// In fr, this message translates to:
  /// **'S\'il demande un réglage, appuyez sur « Configurer depuis le portail » : votre téléphone s\'en charge.'**
  String get guideCatalogStep3;

  /// No description provided for @guideLinkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un addon avec son lien'**
  String get guideLinkTitle;

  /// No description provided for @guideLinkStep1.
  ///
  /// In fr, this message translates to:
  /// **'Sur la page de l\'addon, touchez « Copier le lien » (ou « Install », puis « Copier l\'adresse du lien »).'**
  String get guideLinkStep1;

  /// No description provided for @guideLinkStep2.
  ///
  /// In fr, this message translates to:
  /// **'Revenez ici et collez le lien dans le champ, ou appuyez sur « Coller ».'**
  String get guideLinkStep2;

  /// No description provided for @guideLinkStep3.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez le nom de l\'addon, puis appuyez sur « Installer ».'**
  String get guideLinkStep3;

  /// No description provided for @guidePhoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter depuis le téléphone'**
  String get guidePhoneTitle;

  /// No description provided for @guidePhoneStep1.
  ///
  /// In fr, this message translates to:
  /// **'Mettez le téléphone sur le même Wi-Fi que la TV.'**
  String get guidePhoneStep1;

  /// No description provided for @guidePhoneStep2.
  ///
  /// In fr, this message translates to:
  /// **'Scannez le code, puis saisissez le code de sécurité affiché ici.'**
  String get guidePhoneStep2;

  /// No description provided for @guidePhoneStep3.
  ///
  /// In fr, this message translates to:
  /// **'Collez un lien, touchez « Ajouter », puis confirmez ici sur la TV.'**
  String get guidePhoneStep3;

  /// No description provided for @portalBoxTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sur votre téléphone'**
  String get portalBoxTitle;

  /// No description provided for @portalStep1.
  ///
  /// In fr, this message translates to:
  /// **'Scannez le code : la page Lumio de cette TV s\'ouvre.'**
  String get portalStep1;

  /// No description provided for @portalStep2.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code de sécurité affiché ci-dessous.'**
  String get portalStep2;

  /// No description provided for @portalStep3.
  ///
  /// In fr, this message translates to:
  /// **'Réglez l\'addon, puis « Copier le lien » (ou « Install »).'**
  String get portalStep3;

  /// No description provided for @portalStep4.
  ///
  /// In fr, this message translates to:
  /// **'Collez le lien dans la page, touchez « Ajouter ».'**
  String get portalStep4;

  /// No description provided for @portalStep5.
  ///
  /// In fr, this message translates to:
  /// **'Revenez ici et confirmez sur la TV.'**
  String get portalStep5;

  /// No description provided for @traktStepsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pour connecter Trakt'**
  String get traktStepsTitle;

  /// No description provided for @traktStep1.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur « Connecter Trakt » : un code s\'affiche.'**
  String get traktStep1;

  /// No description provided for @traktStep2.
  ///
  /// In fr, this message translates to:
  /// **'Sur votre téléphone, ouvrez trakt.tv/activate (ou scannez le code).'**
  String get traktStep2;

  /// No description provided for @traktStep3.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code affiché sur la TV.'**
  String get traktStep3;

  /// No description provided for @traktStep4.
  ///
  /// In fr, this message translates to:
  /// **'Acceptez sur Trakt : la TV se connecte toute seule.'**
  String get traktStep4;

  /// No description provided for @settingsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Aide'**
  String get settingsHelp;

  /// No description provided for @settingsHelpHint.
  ///
  /// In fr, this message translates to:
  /// **'Guides pas à pas : addons, téléphone, Trakt, profils, sous-titres'**
  String get settingsHelpHint;

  /// No description provided for @helpAddonsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un addon'**
  String get helpAddonsTitle;

  /// No description provided for @helpAddonsStep1.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez Réglages › Sources, puis « Ajouter un addon ».'**
  String get helpAddonsStep1;

  /// No description provided for @helpAddonsStep2.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un onglet : Catalogue, Par lien ou Depuis le téléphone.'**
  String get helpAddonsStep2;

  /// No description provided for @helpAddonsStep3.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur « Installer ». Aucun addon n\'est fourni d\'office.'**
  String get helpAddonsStep3;

  /// No description provided for @helpSettingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Régler un addon'**
  String get helpSettingTitle;

  /// No description provided for @helpSettingStep1.
  ///
  /// In fr, this message translates to:
  /// **'Sur la fiche d\'un addon du catalogue, appuyez sur « Configurer depuis le portail ».'**
  String get helpSettingStep1;

  /// No description provided for @helpSettingStep2.
  ///
  /// In fr, this message translates to:
  /// **'Sur le téléphone, réglez l\'addon puis touchez « Copier le lien ».'**
  String get helpSettingStep2;

  /// No description provided for @helpSettingStep3.
  ///
  /// In fr, this message translates to:
  /// **'Collez le lien dans la page, touchez « Ajouter », puis confirmez sur la TV.'**
  String get helpSettingStep3;

  /// No description provided for @helpPortalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le portail du téléphone'**
  String get helpPortalTitle;

  /// No description provided for @helpPortalStep1.
  ///
  /// In fr, this message translates to:
  /// **'Le téléphone doit être sur le même Wi-Fi que la TV.'**
  String get helpPortalStep1;

  /// No description provided for @helpPortalStep2.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez Réglages › Sources › Depuis le téléphone, puis scannez le code.'**
  String get helpPortalStep2;

  /// No description provided for @helpPortalStep3.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code de sécurité affiché sur la TV.'**
  String get helpPortalStep3;

  /// No description provided for @helpPortalStep4.
  ///
  /// In fr, this message translates to:
  /// **'Laissez l\'écran de la TV ouvert : la page se ferme avec lui.'**
  String get helpPortalStep4;

  /// No description provided for @helpTraktTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trakt'**
  String get helpTraktTitle;

  /// No description provided for @helpProfilesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profils et code PIN'**
  String get helpProfilesTitle;

  /// No description provided for @helpProfilesStep1.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez Réglages › Profils › Gérer les profils.'**
  String get helpProfilesStep1;

  /// No description provided for @helpProfilesStep2.
  ///
  /// In fr, this message translates to:
  /// **'Pour un profil enfant, choisissez l\'âge limite.'**
  String get helpProfilesStep2;

  /// No description provided for @helpProfilesStep3.
  ///
  /// In fr, this message translates to:
  /// **'Le code PIN parent protège les profils verrouillés et les réglages sensibles.'**
  String get helpProfilesStep3;

  /// No description provided for @helpSubsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get helpSubsTitle;

  /// No description provided for @helpSubsStep1.
  ///
  /// In fr, this message translates to:
  /// **'Pendant la lecture, ouvrez « Pistes et sous-titres ».'**
  String get helpSubsStep1;

  /// No description provided for @helpSubsStep2.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la langue, la taille et le décalage.'**
  String get helpSubsStep2;

  /// No description provided for @helpSubsStep3.
  ///
  /// In fr, this message translates to:
  /// **'Dans Réglages › Lecture, choisissez la langue préférée : elle s\'applique toute seule quand elle existe.'**
  String get helpSubsStep3;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
