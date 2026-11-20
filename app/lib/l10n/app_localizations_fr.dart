// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get retry => 'Réessayer';

  @override
  String get close => 'Fermer';

  @override
  String get back => 'Retour';

  @override
  String get continueAction => 'Continuer';

  @override
  String get save => 'Enregistrer';

  @override
  String get add => 'Ajouter';

  @override
  String get paste => 'Coller';

  @override
  String get install => 'Installer';

  @override
  String get done => 'Terminé';

  @override
  String get loading => 'Chargement';

  @override
  String get show => 'Afficher';

  @override
  String get hide => 'Masquer';

  @override
  String get moveUp => 'Monter';

  @override
  String get moveDown => 'Descendre';

  @override
  String get homeSearch => 'Recherche';

  @override
  String get homeManageList => 'Gérer ma liste';

  @override
  String get homeCustomize => 'Personnaliser';

  @override
  String get homeSettings => 'Réglages';

  @override
  String get homeAddonsError => 'Impossible de charger vos addons';

  @override
  String get homeNoCatalog => 'Vos addons ne proposent aucun catalogue';

  @override
  String get homeNoAddons =>
      'Ajoutez un addon ou une source personnelle pour remplir votre accueil.';

  @override
  String get homeManageAddons => 'Gérer les addons';

  @override
  String get homeFiltered => 'Aucun contenu adapté à ce profil';

  @override
  String get homeRowFailed => 'Chargement impossible';

  @override
  String get myList => 'Ma liste';

  @override
  String get continueWatching => 'Continuer à regarder';

  @override
  String get sourceLocal => 'Local';

  @override
  String get sourceAddon => 'addon';

  @override
  String resumeSemantic(Object title) {
    return 'Reprendre $title';
  }

  @override
  String itemSemantic(Object name, Object source) {
    return '$name, $source';
  }

  @override
  String itemSemanticYear(Object name, Object year, Object source) {
    return '$name, $year, $source';
  }

  @override
  String get sheetUnavailable => 'Fiche indisponible. Réessayez.';

  @override
  String get notAllowedForProfile =>
      'Ce contenu n\'est pas autorisé pour ce profil.';

  @override
  String get noSourceAvailable =>
      'Aucune source disponible. Vérifiez vos addons.';

  @override
  String get addonsTitle => 'Addons';

  @override
  String get addAddon => 'Ajouter un addon';

  @override
  String get addonsLoadError => 'Impossible de charger les addons';

  @override
  String get addonsEmpty =>
      'Aucun addon installé. Un addon apporte des catalogues et des sources : ajoutez-en un avec son lien.';

  @override
  String get addonActionFailed =>
      'Action impossible : l\'addon n\'a pas été modifié';

  @override
  String get removeAddonTitle => 'Supprimer cet addon ?';

  @override
  String removeAddonBody(Object name) {
    return '« $name » sera retiré de Lumio. Ses catalogues et ses sources ne seront plus proposés.';
  }

  @override
  String get addonBroken =>
      'Addon illisible : supprimez-le puis réinstallez-le';

  @override
  String get addonDisabled => 'Désactivé';

  @override
  String moveAddonUp(Object name) {
    return 'Monter $name';
  }

  @override
  String moveAddonDown(Object name) {
    return 'Descendre $name';
  }

  @override
  String enableAddon(Object name) {
    return 'Activer $name';
  }

  @override
  String deleteAddon(Object name) {
    return 'Supprimer $name';
  }

  @override
  String get typeMovie => 'Films';

  @override
  String get typeSeries => 'Séries';

  @override
  String get typeAnime => 'Animes';

  @override
  String get typeOther => 'Autres';

  @override
  String get resCatalog => 'Catalogues';

  @override
  String get resMeta => 'Fiches';

  @override
  String get resStream => 'Flux';

  @override
  String get resSubtitles => 'Sous-titres';

  @override
  String get resAddonCatalog => 'Addons';

  @override
  String get clipboardEmpty => 'Le presse-papiers est vide';

  @override
  String get localAddressRefused =>
      'Adresse locale refusée : aucun addon installé';

  @override
  String get addonUnreadable => 'Impossible de lire cet addon';

  @override
  String get localAddressTitle => 'Adresse locale';

  @override
  String get localAddressBody =>
      'Cette adresse pointe vers votre appareil ou votre réseau local. Ne continuez que si vous avez vous-même lancé cet addon.';

  @override
  String get installFailed => 'Installation impossible';

  @override
  String get addonLinkLabel => 'Lien de l\'addon';

  @override
  String get trustWarning =>
      'N\'installez que des addons de sources de confiance : un addon voit ce que vous consultez.';

  @override
  String versionLabel(Object version) {
    return 'Version $version';
  }

  @override
  String get alreadyInstalled => 'Déjà installé';

  @override
  String provides(Object list) {
    return 'Fournit : $list';
  }

  @override
  String get libraryLoadError => 'Impossible de lire votre liste.';

  @override
  String get libraryEmpty =>
      'Votre liste est vide. Ouvrez la fiche d\'un titre puis choisissez « Ajouter à ma liste ».';

  @override
  String updateAvailable(Object version) {
    return 'Mise à jour disponible : version $version';
  }

  @override
  String get download => 'Télécharger';

  @override
  String get customizeHome => 'Personnaliser l\'accueil';

  @override
  String get progressNotSaved => 'Progression non enregistrée';

  @override
  String resumeAt(Object time) {
    return 'Reprise à $time';
  }

  @override
  String get settingsNotSaved => 'Réglages non enregistrés';

  @override
  String get settingsUnavailable => 'Réglages mémorisés indisponibles';

  @override
  String get subtitleSettingsNotApplied =>
      'Réglages de sous-titres non appliqués';

  @override
  String get nextEpisodeUnavailable => 'Épisode suivant indisponible';

  @override
  String get buffering => 'Mise en mémoire tampon';

  @override
  String get chooseOtherSource => 'Choisir une autre source';

  @override
  String get seekBack10 => 'Reculer de 10 secondes';

  @override
  String get seekForward10 => 'Avancer de 10 secondes';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Lecture';

  @override
  String get tracksAndSubtitles => 'Pistes et sous-titres';

  @override
  String get seekBar => 'Position de lecture';

  @override
  String get audio => 'Audio';

  @override
  String get noAudioTrack => 'Aucune piste audio disponible';

  @override
  String get subtitles => 'Sous-titres';

  @override
  String get subtitlesOff => 'Désactivés';

  @override
  String subtitleLabel(String lang, String source) {
    return '$lang · $source';
  }

  @override
  String subtitleLabelN(String lang, String source, int n) {
    return '$lang · $source $n';
  }

  @override
  String get langUnknown => 'Langue inconnue';

  @override
  String get subtitleDelay => 'Décalage des sous-titres';

  @override
  String get subtitleAdvance => 'Avancer les sous-titres de 100 ms';

  @override
  String get subtitleRetard => 'Retarder les sous-titres de 100 ms';

  @override
  String get subtitleSize => 'Taille';

  @override
  String get opaqueBackground => 'Fond opaque';

  @override
  String get subtitleUnreadable => 'Sous-titre illisible';

  @override
  String trackN(int n) {
    return 'Piste $n';
  }

  @override
  String nextEpisodeIn(int seconds, Object title) {
    return 'Épisode suivant dans $seconds secondes : $title';
  }

  @override
  String nextEpisodeInShort(int seconds) {
    return 'Épisode suivant dans $seconds s';
  }

  @override
  String get playNow => 'Lire maintenant';

  @override
  String get torrentNotPlayable =>
      'Ce flux passe par un torrent : il n\'est pas lisible ici.';

  @override
  String get failTimeout => 'Délai dépassé : la source ne répond pas.';

  @override
  String get failNetwork => 'Connexion impossible : vérifiez le réseau.';

  @override
  String get failRedirect => 'La source redirige de façon incorrecte.';

  @override
  String get failTooLarge => 'La réponse de la source est trop volumineuse.';

  @override
  String get failFormat => 'Format non pris en charge par le lecteur.';

  @override
  String get failTls => 'La connexion sécurisée avec la source a échoué.';

  @override
  String get failGeneric => 'La lecture a échoué.';

  @override
  String get failRefused => 'Source refusée pour des raisons de sécurité.';

  @override
  String httpDenied(int status) {
    return 'La source a répondu $status : accès refusé.';
  }

  @override
  String httpGone(int status) {
    return 'La source a répondu $status : le fichier n\'existe plus.';
  }

  @override
  String get httpTooMany =>
      'La source a répondu 429 : trop de demandes, réessayez plus tard.';

  @override
  String httpServer(int status) {
    return 'La source a répondu $status : elle est en panne.';
  }

  @override
  String httpOther(int status) {
    return 'La source a répondu $status.';
  }

  @override
  String get noStreams => 'Aucun flux trouvé. Vérifiez vos addons.';

  @override
  String get addonFallback => 'Addon';

  @override
  String get noResponse => 'Ne répond pas';

  @override
  String streamCount(int count) {
    return '$count flux';
  }

  @override
  String get torrentLabel => 'Torrent';

  @override
  String get kindTorrent => 'torrent';

  @override
  String get kindDirect => 'lien direct';

  @override
  String seedersSemantic(int count) {
    return '$count sources';
  }

  @override
  String get recommendedSemantic => 'recommandé';

  @override
  String get recommended => 'Recommandé';

  @override
  String sizeGb(Object value) {
    return '$value Go';
  }

  @override
  String sizeMb(int value) {
    return '$value Mo';
  }

  @override
  String get listUpdateFailed => 'Ma liste n\'a pas pu être modifiée.';

  @override
  String get detailLoadError => 'Impossible de charger la fiche.';

  @override
  String get autoPlayBest => 'Lecture auto · meilleure source';

  @override
  String get removeFromList => 'Retirer de ma liste';

  @override
  String get openSheet => 'Ouvrir la fiche';

  @override
  String get addToList => 'Ajouter à ma liste';

  @override
  String get seasonEpisodes => 'Épisodes';

  @override
  String get seasonSpecials => 'Spéciaux';

  @override
  String seasonN(int n) {
    return 'Saison $n';
  }

  @override
  String get noEpisodes => 'Aucun épisode disponible pour cette série.';

  @override
  String get seasonsTitle => 'Saisons';

  @override
  String get sourcesTitle => 'Sources';

  @override
  String get watchedSemantic => 'vu';

  @override
  String get unwatchedSemantic => 'non vu';

  @override
  String get episodeLetter => 'É';

  @override
  String get watchedBadge => 'Vu';

  @override
  String get searchHint => 'Rechercher un titre';

  @override
  String get kbSpace => 'Espace';

  @override
  String get kbErase => 'Effacer';

  @override
  String get kbAll => 'Tout';

  @override
  String get kbClearAll => 'Tout effacer';

  @override
  String get kbLatin => 'Clavier latin';

  @override
  String get kbArabic => 'Clavier arabe';

  @override
  String get dictationStop => 'Arrêter la dictée';

  @override
  String get dictationStart => 'Dictée vocale';

  @override
  String get searchPrompt => 'Tapez un titre pour lancer la recherche';

  @override
  String get searchNoAddon => 'Aucun addon actif ne propose la recherche';

  @override
  String get searchNoResults => 'Aucun résultat';

  @override
  String get filterAll => 'Tout';

  @override
  String get filterMovies => 'Films';

  @override
  String get filterSeries => 'Séries';

  @override
  String get kidAllAges => 'Enfant · Tous publics';

  @override
  String kidYears(int years) {
    return 'Enfant · $years+';
  }

  @override
  String get profilesLoadError => 'Impossible de charger les profils';

  @override
  String get parentalUnavailable =>
      'Contrôle parental indisponible. Réessayez.';

  @override
  String pinFor(Object name) {
    return 'PIN pour $name';
  }

  @override
  String get maxProfilesReached => 'Six profils au maximum';

  @override
  String get profileNotModified =>
      'Action impossible : le profil n\'a pas été modifié';

  @override
  String get whoIsWatching => 'Qui regarde ?';

  @override
  String get manageProfiles => 'Gérer les profils';

  @override
  String get lockedSemantic => 'verrouillé, PIN demandé';

  @override
  String get editSemantic => 'modifier';

  @override
  String get pinBadge => 'PIN';

  @override
  String get addProfileSemantic => 'Ajouter un profil';

  @override
  String get nameRequired => 'Donnez un nom au profil';

  @override
  String get deleteProfileTitle => 'Supprimer ce profil ?';

  @override
  String get deleteProfileBody =>
      'Sa progression, sa liste et ses réglages seront supprimés.';

  @override
  String get ageAll => 'Tous publics';

  @override
  String get newProfile => 'Nouveau profil';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get nameLabel => 'Nom';

  @override
  String get kidProfile => 'Profil enfant';

  @override
  String get kidProfileHint =>
      'Contenus filtrés selon l\'âge ; réglages et changement de profil protégés par le PIN parent.';

  @override
  String get ageLimit => 'Limite d\'âge';

  @override
  String get lockByPin => 'Verrouiller par PIN';

  @override
  String get lockByPinHint =>
      'Le PIN parent est demandé pour ouvrir ce profil.';

  @override
  String get profileFallback => 'Profil';

  @override
  String tooManyTries(int min) {
    return 'Trop d\'essais. Réessayez dans $min min.';
  }

  @override
  String get pinWrong => 'PIN incorrect';

  @override
  String get pinCheckFailed => 'Vérification impossible. Réessayez.';

  @override
  String get pinForgot => 'PIN oublié ?';

  @override
  String pinDotsSemantic(int filled) {
    String _temp0 = intl.Intl.pluralLogic(
      filled,
      locale: localeName,
      other: '$filled chiffres saisis sur 4',
      one: '1 chiffre saisi sur 4',
      zero: '0 chiffre saisi sur 4',
    );
    return '$_temp0';
  }

  @override
  String digitSemantic(Object digit) {
    return 'Chiffre $digit';
  }

  @override
  String get eraseLastDigit => 'Effacer le dernier chiffre';

  @override
  String get recoveryTitle => 'Code de récupération';

  @override
  String get recoveryBody =>
      'Notez ce code et gardez-le en lieu sûr : il permet de choisir un nouveau PIN si vous l\'oubliez. Il ne sera plus jamais affiché.';

  @override
  String get recoveryNoted => 'J\'ai noté le code';

  @override
  String get choosePin => 'Choisissez un PIN';

  @override
  String get pinHint =>
      '4 chiffres. Il protège les profils enfants et les réglages.';

  @override
  String get confirmPin => 'Confirmez le PIN';

  @override
  String get pinMismatch => 'Les deux PIN ne correspondent pas';

  @override
  String get pinSaveFailed => 'Impossible d\'enregistrer le PIN';

  @override
  String get recoveryWrong => 'Code de récupération incorrect';

  @override
  String get tooManyTriesLater =>
      'Trop d\'essais. Réessayez dans quelques minutes.';

  @override
  String get recoveryFailed => 'Récupération impossible';

  @override
  String get parentPin => 'PIN parent';

  @override
  String get askParent => 'Demandez à un parent de saisir son PIN.';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsAddons => 'Addons';

  @override
  String get settingsAddonsHint =>
      'Réordonner, activer ou supprimer vos addons';

  @override
  String get settingsLanguage => 'Langue de l\'interface';

  @override
  String get langFrench => 'Français';

  @override
  String get langEnglish => 'English';

  @override
  String get settingsPlayback => 'Lecture';

  @override
  String get settingsAudioLang => 'Langue audio';

  @override
  String get settingsSubtitleLang => 'Sous-titres';

  @override
  String get settingsQuality => 'Qualité préférée';

  @override
  String get settingsPreferDirect => 'Préférer les liens directs';

  @override
  String get preferDirectOn => 'Avant les torrents, à qualité égale.';

  @override
  String get preferDirectOff => 'Sans préférence';

  @override
  String otherAddonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres addons',
      one: '1 autre addon',
    );
    return '+$_temp0';
  }

  @override
  String get playerSourceFallback =>
      'Source indisponible, essai de la suivante…';

  @override
  String playingFallback(String title) {
    return 'Lecture depuis une autre source : $title';
  }

  @override
  String get langSpanish => 'Español';

  @override
  String get langGerman => 'Deutsch';

  @override
  String get langItalian => 'Italiano';

  @override
  String get langPortuguese => 'Português';

  @override
  String get langArabic => 'العربية';

  @override
  String get settingsDownloads => 'Torrents';

  @override
  String get settingsTorrentCache => 'Cache';

  @override
  String get settingsUpload => 'Limite d\'envoi';

  @override
  String get unlimited => 'Illimité';

  @override
  String get uploadOff =>
      'Désactivé (pas d\'ensemencement, envoi minimal de 256 Ko/s)';

  @override
  String get settingsClearCacheOnExit => 'Vider le cache en quittant';

  @override
  String get optionYes => 'Oui';

  @override
  String get optionNo => 'Non';

  @override
  String cacheGb(int n) {
    return '$n Go';
  }

  @override
  String uploadKbps(int n) {
    return '$n Ko/s';
  }

  @override
  String get settingsVersion => 'Version';

  @override
  String versionValue(Object version) {
    return 'Lumio $version';
  }

  @override
  String get debugUnlocked => 'Menu debug activé';

  @override
  String get debugMenuTitle => 'Menu debug';

  @override
  String get debugNone => 'Aucun écran de debug';

  @override
  String get debugTorrent => 'Spike torrent';

  @override
  String get debugPlayer => 'Spike lecteur';

  @override
  String get debugLoop => 'Boucle d\'endurance';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get aboutLicense => 'Licence GPL-3.0';

  @override
  String get aboutCredits => 'Crédits : libmpv, media_kit, libtorrent';

  @override
  String get openSourceLicenses => 'Licences open source';

  @override
  String get settingSaveFailed => 'Réglage non enregistré';

  @override
  String get gplTitle => 'Licence GPL-3.0';

  @override
  String get gplText =>
      'Lumio est un logiciel libre, distribué sous la licence publique générale GNU version 3 (GPL-3.0). Vous pouvez le copier, le modifier et le redistribuer selon les termes de cette licence. Il est fourni sans aucune garantie. Texte complet : https://www.gnu.org/licenses/gpl-3.0.html';

  @override
  String get creditsLibmpv => 'libmpv : lecteur vidéo (LGPL/GPL)';

  @override
  String get creditsMediaKit => 'media_kit : intégration Flutter du lecteur';

  @override
  String get creditsLibtorrent => 'libtorrent : moteur de torrents (BSD)';

  @override
  String get creditsFonts =>
      'Polices Bricolage Grotesque et Manrope (licence SIL OFL 1.1)';

  @override
  String get settingsNone => 'Aucun';

  @override
  String get subtitlesNone => 'Aucun sous-titre';

  @override
  String get errDuplicate => 'Cet addon est déjà installé';

  @override
  String get errPrivateAddress =>
      'Cette adresse pointe vers votre réseau local';

  @override
  String get errInvalidAddress => 'Adresse invalide';

  @override
  String get errAddressRefused => 'Adresse refusée';

  @override
  String get errTimeout => 'Délai dépassé : l\'addon ne répond pas';

  @override
  String get errUnreachable => 'Addon injoignable';

  @override
  String get errTls => 'Connexion sécurisée impossible (certificat refusé)';

  @override
  String get errNotFound => 'Addon ou ressource introuvable';

  @override
  String errServer(int status) {
    return 'Addon en erreur (HTTP $status)';
  }

  @override
  String errRefused(int status) {
    return 'Réponse refusée par l\'addon (HTTP $status)';
  }

  @override
  String get errTooLarge => 'Réponse trop volumineuse';

  @override
  String get errInvalidJson =>
      'Réponse invalide : ce n\'est pas du JSON valide';

  @override
  String get errRedirect => 'Redirection refusée ou invalide';

  @override
  String get errManifestInvalid => 'Manifeste invalide';

  @override
  String get errUnexpected => 'Erreur inattendue lors du chargement';

  @override
  String get errOther => 'Une erreur est survenue';

  @override
  String get qualityAuto => 'Automatique';

  @override
  String get useCopiedLink => 'Utiliser le lien copié';

  @override
  String get installLinkInvalid =>
      'Ce lien n\'est pas un lien d\'installation d\'addon.';

  @override
  String onboardingStep(int n, int total) {
    return 'Étape $n sur $total';
  }

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String get onboardingLanguageTitle => 'Choisissez votre langue';

  @override
  String get onboardingProfileTitle => 'Votre profil';

  @override
  String get onboardingProfileBody =>
      'Comment doit-on vous appeler ? Vous pourrez le changer plus tard.';

  @override
  String get onboardingProfileName => 'Nom du profil';

  @override
  String get onboardingAddKid => 'Ajouter un profil enfant';

  @override
  String onboardingKidAdded(String name) {
    return 'Profil enfant ajouté : $name';
  }

  @override
  String get onboardingSourcesTitle => 'Ajoutez vos sources';

  @override
  String get onboardingSourcesBody =>
      'Lumio ne propose aucun contenu : ajoutez vos propres sources pour remplir l\'accueil.';

  @override
  String onboardingAddonsInstalled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count addons installés',
      one: '1 addon installé',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDoneTitle => 'Tout est prêt';

  @override
  String get onboardingDoneBody =>
      'Vous pourrez ajouter ou changer vos sources à tout moment depuis les réglages.';

  @override
  String get onboardingSaveError => 'Enregistrement impossible, réessayez';

  @override
  String get sourcesReminderTitle => 'Ajoutez vos sources';

  @override
  String get sourcesReminderBody =>
      'Votre accueil est vide tant qu\'aucune source n\'est ajoutée.';

  @override
  String get sourcesReminderDismiss => 'Masquer';

  @override
  String get torrentInsufficientStorage =>
      'Espace insuffisant sur l\'appareil pour lire ce torrent. Libérez de la place puis réessayez.';

  @override
  String get torrentNoPeers =>
      'Aucune source disponible pour ce torrent. Essayez un autre flux.';

  @override
  String get torrentVpnRequired =>
      'Un VPN est exigé pour les torrents et aucun n\'est actif. Activez votre VPN puis réessayez.';

  @override
  String get torrentVpnLost =>
      'VPN coupé : torrent arrêté pour protéger votre adresse IP.';

  @override
  String get torrentNoVpnReminder =>
      'Aucun VPN détecté : votre adresse IP est visible des autres pairs.';

  @override
  String get torrentIpWarningTitle => 'Votre adresse IP sera visible';

  @override
  String get torrentIpWarningBody =>
      'Avec un torrent, les autres participants de l\'échange voient votre adresse IP. Pour la protéger, utilisez un VPN. Vous pouvez en exiger un dans les réglages.';

  @override
  String get torrentIpWarningContinue => 'Continuer';

  @override
  String get torrentIpWarningCancel => 'Annuler';

  @override
  String get torrentIpWarningDeclined =>
      'Torrent non démarré. Relancez la lecture pour continuer.';

  @override
  String get settingsRequireVpn => 'Exiger un VPN pour les torrents';

  @override
  String get settingsVpnInterface => 'Interface VPN';

  @override
  String get vpnAny => 'N\'importe quel VPN';

  @override
  String vpnInterfaceRequired(String name) {
    return '$name : exigée, torrents arrêtés si elle tombe';
  }

  @override
  String get vpnNone => 'Aucun VPN actif détecté';

  @override
  String get torrentNoFile =>
      'Ce torrent ne contient aucun fichier lisible. Essayez un autre flux.';

  @override
  String get torrentFailed =>
      'Le torrent n\'a pas pu démarrer. Essayez un autre flux.';

  @override
  String get torrentConnecting => 'Connexion aux sources…';

  @override
  String get torrentConnectionLost => 'Connexion perdue, nouvelle tentative…';

  @override
  String torrentPeers(Object count) {
    return '$count sources';
  }

  @override
  String torrentRateKb(Object value) {
    return '$value Ko/s';
  }

  @override
  String torrentRateMb(Object value) {
    return '$value Mo/s';
  }

  @override
  String torrentBuffered(Object percent) {
    return '$percent % téléchargé';
  }

  @override
  String get kidProfileNeedsPin =>
      'Ce profil enfant vient d\'un autre appareil. Créez d\'abord un PIN parent pour l\'utiliser.';

  @override
  String get addonUrlAllow => 'Autoriser';

  @override
  String get addonUrlIgnore => 'Ignorer';

  @override
  String get passphraseLabel => 'Phrase secrète de la sauvegarde';

  @override
  String get passphraseConfirmLabel => 'Confirmer la phrase secrète';

  @override
  String get passphraseErrShort => '12 caractères au moins';

  @override
  String get passphraseErrMismatch => 'Les deux phrases sont différentes';

  @override
  String get settingsBackup => 'Sauvegarde';

  @override
  String get backupExport => 'Exporter mes données';

  @override
  String get backupExportHint =>
      'Profils, ma liste, progression et réglages dans un fichier';

  @override
  String get backupImport => 'Importer une sauvegarde';

  @override
  String get backupImportHint =>
      'Ajoute le contenu du fichier à vos données ; rien n\'est supprimé';

  @override
  String get backupSecretsTitle => 'Inclure les adresses d\'addons ?';

  @override
  String get backupSecretsWarning =>
      'Ce fichier contiendra vos adresses d\'addons. Il sera chiffré avec une phrase secrète que vous choisissez : sans elle, personne ne pourra le lire, vous non plus. Sans les adresses, le fichier ne contient aucun secret.';

  @override
  String get backupWithoutSecrets => 'Sans les adresses';

  @override
  String get backupWithSecrets => 'Inclure (chiffré)';

  @override
  String get backupPassphraseTitle => 'Phrase secrète de la sauvegarde';

  @override
  String get backupPassphraseHint =>
      'Choisissez une phrase d\'au moins 12 caractères. Elle n\'est pas enregistrée : notez-la.';

  @override
  String get backupImportPassphraseTitle => 'Sauvegarde chiffrée';

  @override
  String get backupImportPassphraseHint =>
      'Saisissez la phrase secrète choisie lors de l\'export.';

  @override
  String get backupWrongPassphrase =>
      'Phrase secrète incorrecte, ou fichier abîmé.';

  @override
  String get backupContinue => 'Continuer';

  @override
  String get backupErrUnknown => 'Ce fichier n\'est pas une sauvegarde Lumio.';

  @override
  String get backupErrVersion =>
      'Cette sauvegarde vient d\'une version plus récente de Lumio. Mettez l\'application à jour.';

  @override
  String get backupErrMalformed => 'Cette sauvegarde est illisible ou abîmée.';

  @override
  String get backupErrTooLarge =>
      'Cette sauvegarde est trop volumineuse (10 Mo au maximum).';

  @override
  String get backupErrFile => 'Impossible de lire ou d\'écrire le fichier.';

  @override
  String backupExported(String path) {
    return 'Sauvegarde enregistrée : $path';
  }

  @override
  String get backupPickTitle => 'Choisir une sauvegarde';

  @override
  String backupNoFiles(String dir) {
    return 'Aucune sauvegarde trouvée. Copiez un fichier .lumio.json dans ce dossier : $dir';
  }

  @override
  String get backupConfirmTitle => 'Importer cette sauvegarde ?';

  @override
  String get backupConfirmBody =>
      'Le contenu du fichier est ajouté à vos données. Rien n\'est supprimé ni remplacé, sauf une progression moins récente que celle du fichier.';

  @override
  String get backupImportBusy => 'Import en cours…';

  @override
  String get backupDoneTitle => 'Import terminé';

  @override
  String backupSumProfiles(int n) {
    return '$n profil(s) ajouté(s)';
  }

  @override
  String backupSumLibrary(int n) {
    return '$n titre(s) ajouté(s) à la liste';
  }

  @override
  String backupSumProgress(int n) {
    return '$n progression(s) importée(s)';
  }

  @override
  String backupSumAddons(int n) {
    return '$n addon(s) installé(s)';
  }

  @override
  String get backupSumNothing =>
      'Rien de nouveau : vos données contenaient déjà tout.';

  @override
  String backupSumNameOnly(int n) {
    return '$n addon(s) à réinstaller à la main : le fichier ne contient pas leurs adresses.';
  }

  @override
  String backupSumFailed(int n) {
    return '$n addon(s) n\'ont pas pu être installés.';
  }

  @override
  String backupSumSkipped(int n) {
    return '$n entrée(s) invalide(s) ignorée(s).';
  }

  @override
  String backupSumProfilesSkipped(int n) {
    return '$n profil(s) non ajouté(s) : six profils au maximum.';
  }

  @override
  String get backupKidNeedsPin =>
      'Un profil enfant a été ajouté : créez d\'abord un PIN parent pour l\'utiliser.';

  @override
  String get backupPrivateTitle => 'Adresse locale';

  @override
  String backupPrivateBody(String name, String host) {
    return '« $name » ($host) pointe vers votre réseau local. L\'installer quand même ?';
  }

  @override
  String get otherImportTitle => 'Importer depuis un autre client';

  @override
  String get otherImportHint => 'Addons et liste depuis des fichiers exportés';

  @override
  String get otherImportHelp =>
      'Choisissez ou collez les fichiers JSON exportés depuis votre ancien client compatible (par exemple Stremio : réponses de addonCollectionGet et datastoreGet). Aucun compte n\'est contacté : seuls ces fichiers sont lus. La liste est ajoutée au profil actif ; les addons sont installés un par un.';

  @override
  String get otherImportAddonsLabel => 'Addons (JSON)';

  @override
  String get otherImportLibraryLabel => 'Bibliothèque (JSON)';

  @override
  String get otherImportPasteHint => 'Collez le contenu ici…';

  @override
  String get otherImportChooseFile => 'Choisir un fichier';

  @override
  String get otherImportRemoveFile => 'Retirer le fichier';

  @override
  String otherImportFileLoaded(String name) {
    return 'Fichier : $name';
  }

  @override
  String get otherImportPickTitle => 'Choisir un fichier JSON';

  @override
  String otherImportNoFiles(String dir) {
    return 'Aucun fichier .json trouvé. Copiez-y vos fichiers exportés : $dir';
  }

  @override
  String get otherImportRun => 'Importer';

  @override
  String get otherImportNothing => 'Choisissez ou collez au moins un fichier.';

  @override
  String otherImportErrFormat(String which) {
    return 'Ce contenu n\'est pas un export reconnu : $which.';
  }

  @override
  String get otherImportErrTooLarge =>
      'Ce contenu est trop volumineux (10 Mo au maximum).';

  @override
  String otherImportProgressAddons(int done, int total) {
    return 'Installation des addons : $done sur $total';
  }

  @override
  String get otherImportProgressLibrary => 'Ajout à la liste…';

  @override
  String get otherImportDoneTitle => 'Import terminé';

  @override
  String otherImportSumInstalled(int n) {
    return '$n addon(s) installé(s)';
  }

  @override
  String otherImportSumAlready(int n) {
    return '$n addon(s) déjà présent(s)';
  }

  @override
  String otherImportSumPending(int n) {
    return '$n addon(s) en attente (adresse locale)';
  }

  @override
  String otherImportSumSkipped(int n, String names) {
    return '$n élément(s) ignoré(s) : $names';
  }

  @override
  String otherImportSumLibrary(int n) {
    return '$n titre(s) ajouté(s) à la liste';
  }

  @override
  String otherImportSumLibraryAlready(int n) {
    return '$n titre(s) déjà dans la liste';
  }

  @override
  String get otherImportSumNothing => 'Rien à importer dans ces fichiers.';

  @override
  String otherImportPendingItem(String host) {
    return 'Un addon pointe vers votre réseau local ($host). L\'installer quand même ?';
  }

  @override
  String get otherImportWhatAddons => 'addons';

  @override
  String get otherImportWhatLibrary => 'bibliothèque';

  @override
  String otherImportSumFailedInvalid(int n) {
    return '$n addon(s) refusé(s) : manifeste invalide';
  }

  @override
  String otherImportSumFailedUnreachable(int n) {
    return '$n addon(s) injoignable(s)';
  }

  @override
  String otherImportSumFailedOther(int n) {
    return '$n addon(s) n\'ont pas pu être installés (autre cause)';
  }

  @override
  String otherImportSumLibraryFailed(int n) {
    return '$n titre(s) n\'ont pas pu être ajoutés à la liste';
  }

  @override
  String get healthReliable => 'Fiable';

  @override
  String get healthSlow => 'Lent (> 3 s)';

  @override
  String get healthFailing => 'Défaillant';

  @override
  String get healthUnknown => 'Pas encore de mesure';

  @override
  String healthDetail(Object latency, int percent) {
    return 'Médiane $latency · $percent % de réussite';
  }

  @override
  String healthSemantic(Object level, Object detail) {
    return 'Santé : $level, $detail';
  }

  @override
  String resetHealth(Object name) {
    return 'Réinitialiser les mesures de $name';
  }

  @override
  String get localFolders => 'Dossiers locaux';

  @override
  String get localFoldersHint => 'Les vidéos stockées sur cet appareil';

  @override
  String get localAddFolder => 'Ajouter un dossier';

  @override
  String get localEmpty =>
      'Aucun dossier. Ajoutez un dossier de vidéos pour les retrouver dans Lumio.';

  @override
  String localVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos',
      one: '1 vidéo',
      zero: 'Aucune vidéo',
    );
    return '$_temp0';
  }

  @override
  String get localScanNow => 'Analyser maintenant';

  @override
  String get localScanning => 'Analyse en cours…';

  @override
  String localScanDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos',
      one: '1 vidéo',
      zero: 'aucune vidéo',
    );
    return 'Analyse terminée : $_temp0';
  }

  @override
  String localRemoveFolder(String path) {
    return 'Retirer le dossier $path';
  }

  @override
  String get localFolderRemoved =>
      'Dossier retiré de Lumio. Vos fichiers ne sont pas touchés.';

  @override
  String get localPermissionDenied =>
      'Lumio a besoin d\'accéder à vos vidéos. Autorisez l\'accès dans les réglages de l\'appareil.';

  @override
  String get localPickerUnavailable =>
      'Le sélecteur de dossier n\'est pas disponible. Saisissez le chemin du dossier.';

  @override
  String get localPathTitle => 'Chemin du dossier';

  @override
  String get localPathLabel => 'Chemin';

  @override
  String get localPathHint => '/storage/emulated/0/Movies';

  @override
  String get localChooseFolder => 'Choisir dans le sélecteur';

  @override
  String get localTypePath => 'Saisir un chemin';

  @override
  String get localSdNote =>
      'Le sélecteur n\'atteint que le stockage interne. Pour une carte SD ou une clé USB, saisissez le chemin.';

  @override
  String get localFolderMissing => 'Ce dossier est introuvable.';

  @override
  String get localFolderDenied => 'Accès refusé à ce dossier.';

  @override
  String get localFolderOverlap => 'Ce dossier recoupe un dossier déjà ajouté.';

  @override
  String localFolderAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos',
      one: '1 vidéo',
      zero: 'aucune vidéo',
    );
    return 'Dossier ajouté : $_temp0';
  }

  @override
  String get localScanFailed => 'L\'analyse du dossier a échoué.';

  @override
  String get localFixTitle => 'Corriger le titre';

  @override
  String get localFixLabel => 'Titre';

  @override
  String get localFixReset => 'Rétablir le titre détecté';

  @override
  String get localFileMissing =>
      'Fichier introuvable : il a peut-être été déplacé. Relancez l\'analyse.';

  @override
  String get localPlayFailed => 'Impossible de lire ce fichier.';

  @override
  String localDetected(String title) {
    return 'Détecté : $title';
  }

  @override
  String get localScanIncomplete =>
      'Analyse incomplète : dossier trop volumineux';

  @override
  String get localFolderForbidden =>
      'Ce dossier ne peut pas être ajouté (dossier système ou chemin non absolu).';

  @override
  String get jellyfinServers => 'Serveurs Jellyfin';

  @override
  String get jellyfinServersHint => 'Vos bibliothèques Jellyfin sur l\'accueil';

  @override
  String get jellyfinAddServer => 'Ajouter un serveur';

  @override
  String get jellyfinEmpty =>
      'Aucun serveur. Ajoutez un serveur Jellyfin pour retrouver ses bibliothèques dans Lumio.';

  @override
  String get jellyfinServerUrl => 'Adresse du serveur';

  @override
  String get jellyfinServerUrlHint => 'https://jellyfin.exemple.fr';

  @override
  String get jellyfinUser => 'Utilisateur';

  @override
  String get jellyfinPassword => 'Mot de passe';

  @override
  String get jellyfinConnect => 'Se connecter';

  @override
  String get jellyfinConnecting => 'Connexion…';

  @override
  String jellyfinSignedInAs(String user) {
    return 'Connecté en tant que $user';
  }

  @override
  String jellyfinRemove(String name) {
    return 'Se déconnecter de $name';
  }

  @override
  String jellyfinRemoveTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get jellyfinRemoveBody =>
      'Le jeton de connexion sera supprimé de cet appareil.';

  @override
  String get jellyfinRemoved => 'Serveur retiré';

  @override
  String get jellyfinAdded => 'Serveur ajouté';

  @override
  String get jellyfinInsecureTitle => 'Connexion non chiffrée';

  @override
  String get jellyfinInsecureBody =>
      'Connexion non chiffrée : votre mot de passe circulerait en clair. Préférez une adresse https.';

  @override
  String get jellyfinInsecureContinue => 'Continuer quand même';

  @override
  String get jellyfinLibraries => 'Bibliothèques';

  @override
  String get jellyfinLoadMore => 'Charger la suite';

  @override
  String get jellyfinEmptyFolder => 'Aucun élément à afficher';

  @override
  String get jellyfinPlayFailed =>
      'Lecture impossible : le serveur Jellyfin n\'a pas répondu.';

  @override
  String get jellyfinErrAuth => 'Nom d\'utilisateur ou mot de passe incorrect.';

  @override
  String get jellyfinErrExpired =>
      'Session expirée. Reconnectez-vous au serveur.';

  @override
  String get jellyfinErrCert =>
      'Certificat du serveur invalide : la connexion est refusée.';

  @override
  String get jellyfinErrTimeout =>
      'Délai dépassé : le serveur Jellyfin ne répond pas.';

  @override
  String get jellyfinErrUnreachable => 'Serveur Jellyfin injoignable.';

  @override
  String jellyfinErrServer(int status) {
    return 'Le serveur Jellyfin est en erreur (HTTP $status).';
  }

  @override
  String jellyfinErrRefused(int status) {
    return 'Requête refusée par le serveur Jellyfin (HTTP $status).';
  }

  @override
  String get jellyfinErrInvalid =>
      'Réponse inattendue : est-ce bien un serveur Jellyfin ?';

  @override
  String get jellyfinErrTooLarge => 'Réponse du serveur trop volumineuse.';

  @override
  String get jellyfinErrRedirect =>
      'Le serveur redirige vers une autre adresse : saisissez l\'adresse finale.';

  @override
  String get jellyfinErrAddress => 'Adresse du serveur invalide.';

  @override
  String get trackingTitle => 'Suivi (Trakt)';

  @override
  String get trackingNoConnectHint =>
      'Aucun bouton « Connecter » tant que l\'application n\'est pas configurée.';

  @override
  String get trackingHint => 'Enregistrez vos lectures sur votre compte';

  @override
  String get trackingTrakt => 'Trakt';

  @override
  String get trackingNotConfigured =>
      'Non configuré : les identifiants de l\'application Trakt sont absents. Rien n\'est envoyé.';

  @override
  String get trackingConnectedShort => 'Connecté';

  @override
  String get trackingNotConnected => 'Non connecté';

  @override
  String get trackingConnected =>
      'Connecté : vos lectures sont enregistrées sur Trakt.';

  @override
  String get trackingReauth =>
      'Reconnexion nécessaire : Trakt a refusé la connexion. Reconnectez le compte pour reprendre l\'envoi.';

  @override
  String get trackingConnect => 'Connecter Trakt';

  @override
  String get trackingDisconnect => 'Déconnecter Trakt';

  @override
  String get trackingDisconnected => 'Trakt déconnecté';

  @override
  String trackingPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count envois en attente',
      one: '1 envoi en attente',
      zero: 'Aucun envoi en attente',
    );
    return '$_temp0';
  }

  @override
  String get trackingRetry => 'Réessayer l\'envoi';

  @override
  String get trackingRetried => 'Envoi relancé';

  @override
  String get trackingKidAllow => 'Autoriser le suivi pour ce profil enfant';

  @override
  String get trackingKidAllowHint =>
      'Seul un parent peut l\'activer. Sans cela, rien n\'est envoyé pour ce profil.';

  @override
  String get trackingAuthTitle => 'Connecter Trakt';

  @override
  String get trackingAuthStep =>
      'Sur un autre appareil, ouvrez cette adresse puis saisissez le code :';

  @override
  String get trackingAuthWaiting => 'En attente de votre autorisation…';

  @override
  String get trackingAuthDone => 'Trakt est connecté.';

  @override
  String get trackingAuthDenied => 'Autorisation refusée.';

  @override
  String get trackingAuthExpired =>
      'Le code a expiré ou n\'est plus valable. Demandez-en un nouveau.';

  @override
  String get trackingAuthNewCode => 'Nouveau code';

  @override
  String get trackingAuthUnavailable =>
      'Le service de suivi est injoignable. Réessayez plus tard.';

  @override
  String get trackingQrSemantic => 'Code QR vers l\'adresse d\'autorisation';

  @override
  String get homeCalendar => 'Calendrier';

  @override
  String get calendarTitle => 'Calendrier des sorties';

  @override
  String get calendarEmpty =>
      'Aucune série dans votre liste. Ajoutez une série à « Ma liste » pour suivre ses prochains épisodes.';

  @override
  String get calendarNothingSoon =>
      'Aucune sortie prévue dans les 30 prochains jours.';

  @override
  String get calendarLoadError => 'Impossible de charger le calendrier.';

  @override
  String get calendarToday => 'Aujourd\'hui';

  @override
  String get calendarTomorrow => 'Demain';

  @override
  String get calendarUnknownHeader => 'Date inconnue';

  @override
  String get calendarUnknownEntry => 'Date inconnue';

  @override
  String calendarEpisodeLabel(int season, int episode) {
    return 'S$season · É$episode';
  }

  @override
  String calendarEpisodeOnly(int episode) {
    return 'Épisode $episode';
  }

  @override
  String get calendarNotify => 'Me prévenir des nouveaux épisodes';

  @override
  String get calendarNotifyHint =>
      'Notification locale le jour de la sortie, sur cet appareil. Désactivé par défaut.';

  @override
  String get calendarNotifyDenied =>
      'Notifications refusées : activez-les dans les réglages du système.';

  @override
  String get calendarNotifyOn => 'Vous serez prévenu des prochains épisodes.';

  @override
  String get calendarNotifyChannel => 'Nouveaux épisodes';

  @override
  String calendarNotifyBody(String episode) {
    return 'Nouvel épisode disponible : $episode';
  }

  @override
  String get calendarNotifyError =>
      'Notifications non programmées : une erreur est survenue. Réessayez en rouvrant le calendrier.';

  @override
  String get castTooltip => 'Diffuser sur un appareil';

  @override
  String get castChooseDevice => 'Choisir un appareil';

  @override
  String get castSearching => 'Recherche d\'appareils…';

  @override
  String get castNoDevice => 'Aucun appareil trouvé';

  @override
  String get castNoDeviceHint =>
      'Vérifiez que le téléviseur est allumé et sur le même réseau Wi-Fi.';

  @override
  String castPlayingOn(String device) {
    return 'Lecture sur $device';
  }

  @override
  String get castStop => 'Arrêter la diffusion';

  @override
  String get castFailed => 'Impossible de diffuser sur cet appareil.';

  @override
  String get castUnsupported =>
      'Ce flux ne peut pas être diffusé sur un appareil.';

  @override
  String get castLost =>
      'Appareil de diffusion perdu : la lecture reprend ici.';

  @override
  String get castNetworkError => 'Aucun réseau local commun avec cet appareil.';

  @override
  String get partyTitle => 'Regarder ensemble';

  @override
  String get partyHint => 'Lecture synchronisée avec des proches';

  @override
  String get partyTooltip => 'Regarder ensemble';

  @override
  String get partyCreate => 'Créer une salle';

  @override
  String get partyCreateHint =>
      'Vous invitez : seules la position et l\'état de lecture sont partagés. Chacun ouvre le titre avec ses propres addons.';

  @override
  String get partyJoinTitle => 'Rejoindre une salle';

  @override
  String get partyJoinField => 'Lien d\'invitation';

  @override
  String get partyJoinHint => 'Collez le lien reçu (lumio://party…).';

  @override
  String get partyJoinButton => 'Rejoindre';

  @override
  String get partyConnecting => 'Connexion à la salle…';

  @override
  String get partyInviteCode => 'Code d\'invitation';

  @override
  String get partyLinkLabel => 'Lien à partager (valable 6 h)';

  @override
  String get partyCopyLink => 'Copier le lien';

  @override
  String get partyLinkCopied => 'Lien copié.';

  @override
  String get partyQrLabel => 'QR code du lien d\'invitation';

  @override
  String partyParticipants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String get partyAllControl => 'Tout le monde peut contrôler';

  @override
  String get partyAllControlHint =>
      'Sinon, seul l\'hôte met en pause ou avance.';

  @override
  String get partyOpenTitle => 'Ouvrir le titre';

  @override
  String get partyLeave => 'Quitter la salle';

  @override
  String get partyRoleHost => 'Vous êtes l\'hôte';

  @override
  String get partyRoleGuest => 'Vous suivez l\'hôte';

  @override
  String get partyErrInvalidLink => 'Ce lien d\'invitation n\'est pas valide.';

  @override
  String get partyErrWrongCode => 'Code d\'invitation refusé.';

  @override
  String get partyErrFull => 'La salle est pleine (8 personnes).';

  @override
  String get partyErrNotFound => 'Cette salle n\'existe plus.';

  @override
  String get partyErrRateLimited => 'Trop d\'essais, réessayez dans un moment.';

  @override
  String get partyErrUnavailable => 'Impossible de joindre la salle.';

  @override
  String get partyHostOnly =>
      'Seul l\'hôte contrôle la lecture dans cette salle.';

  @override
  String get tvNavHome => 'Accueil';

  @override
  String get tvSwitchProfile => 'Changer de profil';

  @override
  String get tvEmptyEyebrow => 'BIENVENUE';

  @override
  String get tvEmptyTitle => 'Votre accueil attend ses sources';

  @override
  String get tvEmptyBody =>
      'Lumio ne contient aucun contenu. Ajoutez un addon de confiance, un dossier de vos vidéos ou votre serveur Jellyfin : vos catalogues apparaîtront ici en rangées.';

  @override
  String get tvEmptyLocal => 'Dossier local';

  @override
  String get tvEmptyJellyfin => 'Serveur Jellyfin';

  @override
  String get tvEmptyStep1Title => 'Collez un lien';

  @override
  String get tvEmptyStep1Body =>
      'Le lien manifest.json de l\'addon, ou un lien stremio://.';

  @override
  String get tvEmptyStep2Title => 'Ou envoyez-le du téléphone';

  @override
  String get tvEmptyStep2Body =>
      'Scannez le QR code affiché, collez le lien sur le téléphone.';

  @override
  String get tvEmptyStep3Title => 'Regardez';

  @override
  String get tvEmptyStep3Body =>
      'Catalogues, « Continuer » et « Ma liste » remplissent l\'accueil.';

  @override
  String get tvOnbTagline => 'Votre bibliothèque, vos sources.';

  @override
  String get tvOnbTaglineBody =>
      'Réunissez films, séries et fichiers locaux au même endroit.';

  @override
  String get tvOnbDefault => 'Par défaut';

  @override
  String get tvOnbProfileHeading => 'Créez votre profil';

  @override
  String get tvOnbProfileBody =>
      'Chaque profil garde sa liste, sa progression et ses réglages.';

  @override
  String get tvOnbLater => 'Plus tard';

  @override
  String get tvOnbFinish => 'Terminer';

  @override
  String get tvOnbAddonTitle => 'Un addon';

  @override
  String get tvOnbAddonBody => 'Collez un lien ou scannez un QR code';

  @override
  String get tvOnbJellyfinTitle => 'Un serveur Jellyfin';

  @override
  String get tvOnbJellyfinBody => 'Votre médiathèque personnelle';

  @override
  String get tvOnbLocalTitle => 'Un dossier local';

  @override
  String get tvOnbLocalBody => 'Fichiers de cet appareil ou du réseau';

  @override
  String get tvOnbKidTitle => 'Profil enfant';

  @override
  String get tvOnbKidBody => 'Filtre par âge et PIN pour quitter';

  @override
  String get quitTitle => 'Quitter Lumio ?';

  @override
  String get quitBody => 'Vous reviendrez à l\'écran d\'accueil de la box.';

  @override
  String get quitAction => 'Quitter';

  @override
  String libraryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
      zero: '0 titre',
    );
    return '$_temp0';
  }

  @override
  String get customizeHomeHint =>
      'Masquez ou réordonnez les rangées de l\'accueil.';

  @override
  String get settingsCatSources => 'Sources';

  @override
  String get settingsCatPlayback => 'Lecture';

  @override
  String get settingsCatTorrents => 'Torrents et VPN';

  @override
  String get settingsCatProfiles => 'Profils et contrôle parental';

  @override
  String get settingsCatTracking => 'Suivi Trakt';

  @override
  String get settingsCatBackup => 'Sauvegarde et import';

  @override
  String get settingsCatGeneral => 'Général';

  @override
  String get settingsSourcesHint => 'D\'où viennent vos films et séries.';

  @override
  String get secAddons => 'Addons';

  @override
  String get secPersonalSources => 'Mes sources personnelles';

  @override
  String get secSourceChoice => 'Choix de la source';

  @override
  String get secLanguages => 'Langues';

  @override
  String get secProtection => 'Protection';

  @override
  String get secStorage => 'Stockage et débit';

  @override
  String get secInterfaceLanguage => 'Langue de l\'interface';

  @override
  String get secProfiles => 'Profils';

  @override
  String settingsForProfile(String name) {
    return 'Pour le profil $name.';
  }

  @override
  String addonsInstalledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count addons installés',
      one: '1 addon installé',
      zero: 'Aucun addon installé',
    );
    return '$_temp0';
  }

  @override
  String get settingsProfilesHint =>
      'Ajouter, modifier ou supprimer des profils ; le PIN parent protège les profils enfants.';

  @override
  String settingsProfilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profils',
      one: '1 profil',
    );
    return '$_temp0';
  }

  @override
  String searchResultsHeader(String what, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
    );
    return '$what · $_temp0';
  }

  @override
  String get searchMoviesAndSeries => 'Films et séries';

  @override
  String get pinChecking => 'Vérification…';

  @override
  String get addonsPriorityHint =>
      'L\'ordre décide de la priorité des sources.';

  @override
  String get profileAdult => 'Profil adulte';

  @override
  String get profileChange => 'Changer';

  @override
  String get settingsBackHome => 'Retour : accueil';

  @override
  String vpnCardActive(String name) {
    return 'VPN actif · $name';
  }

  @override
  String get vpnCardStopHint => 'Les torrents s\'arrêtent si le VPN tombe.';

  @override
  String get vpnCardIpHint =>
      'Votre adresse IP est visible des autres pairs sans VPN.';

  @override
  String cacheUsedOf(String used) {
    return '$used utilisés sur';
  }

  @override
  String sizeGbDecimal(String n) {
    return '$n Go';
  }

  @override
  String get profileAdultShort => 'Adulte';

  @override
  String get manageProfilesHint =>
      'Modifier un profil : nom, profil enfant et limite d\'âge, verrou par PIN. Six profils au maximum.';

  @override
  String get profileEditorHint =>
      'Pour un profil adulte, l\'option « Verrouiller par PIN » remplace la limite d\'âge : « Le PIN parent est demandé pour ouvrir ce profil. »';

  @override
  String get subtitleAppearance => 'Apparence';

  @override
  String get subtitleSmaller => 'Réduire les sous-titres';

  @override
  String get subtitleLarger => 'Agrandir les sous-titres';

  @override
  String get subtitleSizeSmall => 'Petite';

  @override
  String get subtitleSizeNormal => 'Normale';

  @override
  String get subtitleSizeLarge => 'Grande';

  @override
  String get subtitleSizeXLarge => 'Très grande';

  @override
  String get subtitleOtherLanguages => 'Autres langues…';

  @override
  String get subtitleHideOtherLanguages => 'Masquer les autres langues';

  @override
  String get seekBackShort => '−10 s';

  @override
  String get seekForwardShort => '+10 s';

  @override
  String get tracksShort => 'Pistes';

  @override
  String get nextShort => 'Suivant';

  @override
  String playbackSpeed(String rate) {
    return 'Vitesse $rate×';
  }

  @override
  String get castShort => 'Diffuser';

  @override
  String get partyShort => 'Ensemble';

  @override
  String get localSubtitle => 'Les vidéos stockées sur cet appareil';

  @override
  String get heroResume => 'Reprendre';

  @override
  String heroMinutesLeft(Object minutes) {
    return '$minutes min restantes';
  }

  @override
  String get searchCaption => 'Recherche dans tous vos addons, vos dossiers.';

  @override
  String streamsAvailable(Object count) {
    return 'Flux disponibles · $count';
  }

  @override
  String get streamGroupAddon => 'ADDON';

  @override
  String get healthLineGood => 'Santé : bonne';

  @override
  String get healthLineSlow => 'Santé : lente';

  @override
  String get healthLineBad => 'Santé : mauvaise';

  @override
  String seedersCount(Object count) {
    return '$count seeders';
  }

  @override
  String get detailUnavailableBody => 'Fiche indisponible. Réessayez.';

  @override
  String get addToListShort => '+ Ma liste';

  @override
  String get streamBadgeDirect => 'Direct';

  @override
  String get streamBadgeTorrent => 'Torrent';

  @override
  String get secAddonsPriority => 'Addons · l\'ordre décide de la priorité';

  @override
  String get addonsMenuHint =>
      'OK sur un addon : monter, descendre, supprimer.';

  @override
  String get healthShortGood => 'Bonne santé';

  @override
  String get healthShortSlow => 'Lente';

  @override
  String get healthShortOffline => 'Hors ligne';

  @override
  String get menuMoveUp => 'Monter';

  @override
  String get menuMoveDown => 'Descendre';

  @override
  String get menuResetHealth => 'Réinitialiser les mesures';

  @override
  String localFoldersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dossiers',
      one: '1 dossier',
      zero: 'Aucun dossier',
    );
    return '$_temp0';
  }

  @override
  String localLastScan(Object ago) {
    return 'dernière analyse $ago';
  }

  @override
  String agoMinutes(int n) {
    return 'il y a $n min';
  }

  @override
  String agoHours(int n) {
    return 'il y a $n h';
  }

  @override
  String agoDays(int n) {
    return 'il y a $n j';
  }

  @override
  String jellyfinServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs',
      one: '1 serveur',
      zero: 'Aucun serveur',
    );
    return '$_temp0';
  }

  @override
  String get addAddonBreadcrumb => 'Réglages › Sources';

  @override
  String get addonTabCatalog => 'Catalogue';

  @override
  String get addonTabLink => 'Par lien';

  @override
  String get addonTabPhone => 'Depuis le téléphone';

  @override
  String get catPopular => 'Populaires';

  @override
  String addonServerLine(String host) {
    return 'Serveur : $host';
  }

  @override
  String addonReplacesNote(String name) {
    return 'Remplace la version déjà installée de « $name ».';
  }

  @override
  String get unknownTitle => 'Titre inconnu';

  @override
  String get catOfficial => 'Officiels';

  @override
  String get catMoviesSeries => 'Films et séries';

  @override
  String get catTorrents => 'Torrents';

  @override
  String get catDebrid => 'Débrideurs';

  @override
  String get catSubtitles => 'Sous-titres';

  @override
  String get catAnime => 'Anime';

  @override
  String get catMetadata => 'Métadonnées';

  @override
  String get catTracking => 'Suivi';

  @override
  String get catMore => 'Plus…';

  @override
  String get catHttpStreams => 'Flux directs';

  @override
  String get catUsenet => 'Usenet';

  @override
  String get catAsianDrama => 'Drames asiatiques';

  @override
  String get catBollywood => 'Bollywood';

  @override
  String get catMusic => 'Musique';

  @override
  String get catRadios => 'Radios';

  @override
  String get catLiveTv => 'TV en direct';

  @override
  String get catMisc => 'Divers';

  @override
  String get catMoreTitle => 'Autres catégories';

  @override
  String get catalogInstalled => 'Installé';

  @override
  String get catalogLoadMore => 'Voir plus';

  @override
  String get catalogRefresh => 'Actualiser';

  @override
  String catalogOffline(Object date) {
    return 'Hors ligne : liste enregistrée le $date.';
  }

  @override
  String get catalogFallbackNote =>
      'Le site du catalogue est inaccessible : liste officielle réduite.';

  @override
  String get catalogLoadError => 'Impossible de charger le catalogue.';

  @override
  String get catalogEmpty => 'Aucun addon dans cette catégorie.';

  @override
  String get catalogDetailError => 'Impossible de lire la fiche de cet addon.';

  @override
  String catalogCardMeta(Object stars, Object version) {
    return '★ $stars · v$version';
  }

  @override
  String catalogCardStars(Object stars) {
    return '★ $stars';
  }

  @override
  String get chooseInstanceTitle => 'Choisir un serveur';

  @override
  String get instanceNeedsSetup => 'à régler';

  @override
  String get addonLinkHelp =>
      'Lien manifest.json ou lien stremio://. Un lien copié sur cet appareil est proposé automatiquement.';

  @override
  String addonPreviewLabel(Object version) {
    return 'APERÇU · v$version';
  }

  @override
  String get addonLinkTrust =>
      'Installez uniquement des sources de confiance : le lien peut contenir une clé personnelle, gardée chiffrée sur cet appareil.';

  @override
  String get phoneStep1 => 'Téléphone sur le même Wi-Fi que la TV';

  @override
  String get phoneStep2 =>
      'Scannez le code : la page Lumio de cette TV s\'ouvre';

  @override
  String get phoneStep3 =>
      'Choisissez un addon, appuyez sur Installer, puis confirmez ici sur la TV';

  @override
  String get phoneOrType => 'Ou tapez dans le navigateur du téléphone';

  @override
  String get phoneCodeLabel => 'Code de sécurité :';

  @override
  String get phoneLive =>
      'Page ouverte tant que cet écran est affiché · aucun serveur externe';

  @override
  String get phoneKeepOpen =>
      'Laissez cet écran ouvert pendant que vous utilisez votre téléphone.';

  @override
  String get settingsManagePhonePress => 'Appuyez sur OK';

  @override
  String get phoneConnected =>
      'Téléphone connecté · page ouverte tant que cet écran est affiché';

  @override
  String get phoneLocked =>
      'Trop d\'essais : un nouveau code est affiché, nouvel essai possible dans une minute';

  @override
  String get phoneNoNetworkTitle => 'Pas de réseau local';

  @override
  String get phoneNoNetworkBody =>
      'Connectez la TV au Wi-Fi ou à l\'Ethernet de la maison : la page du téléphone n\'est jamais servie sur un VPN ni sur le réseau mobile.';

  @override
  String get phoneIdleStopped =>
      'La page s\'est fermée après 10 minutes sans activité.';

  @override
  String get phoneTooManyTries =>
      'Trop d\'essais : la page est fermée par sécurité. Relancez-la pour obtenir un nouveau code.';

  @override
  String get phoneErrorBody => 'La page n\'a pas pu démarrer. Réessayez.';

  @override
  String get phoneRestart => 'Relancer';

  @override
  String get phoneQrLabel => 'QR code de la page Lumio sur le réseau local';

  @override
  String get settingsManagePhone => 'Gérer depuis le téléphone';

  @override
  String get settingsManagePhoneNoNetwork => 'Réseau local indisponible';

  @override
  String get phoneAddWaiting =>
      'Demande reçue du téléphone : vérifiez l\'aperçu et confirmez ici.';

  @override
  String get addonInstall => 'Installer';

  @override
  String get addonConfigure => 'Configurer';

  @override
  String get addonConfigurePortal => 'Configurer depuis le portail';

  @override
  String get addonReconfigurePortal => 'Reconfigurer depuis le portail';

  @override
  String get addonSheetRequired =>
      'Cet addon demande un réglage avant de fonctionner (clé de débrideur, langues…). Le portail web du téléphone ou de l\'ordinateur sert à le configurer.';

  @override
  String get addonSheetConfigurable =>
      'Installez-le tel quel, ou choisissez vos réglages depuis le portail web.';

  @override
  String portalAddonHint(Object name) {
    return 'Ouvrez cette page sur le portail : la fiche de « $name » s’affiche directement.';
  }

  @override
  String get typePageNoMovies =>
      'Vos addons ne proposent aucun catalogue de films';

  @override
  String get typePageNoSeries =>
      'Vos addons ne proposent aucun catalogue de séries';

  @override
  String get guideGotIt => 'Compris';

  @override
  String get guideHelp => 'Aide';

  @override
  String get guideNoteKeyStays =>
      'Votre clé reste chiffrée sur la TV : elle n\'est jamais envoyée au téléphone.';

  @override
  String get guideCatalogTitle => 'Ajouter un addon du catalogue';

  @override
  String get guideCatalogStep1 => 'Choisissez un addon dans la grille.';

  @override
  String get guideCatalogStep2 => 'Appuyez sur « Installer ».';

  @override
  String get guideCatalogStep3 =>
      'S\'il demande un réglage, appuyez sur « Configurer depuis le portail » : votre téléphone s\'en charge.';

  @override
  String get guideLinkTitle => 'Ajouter un addon avec son lien';

  @override
  String get guideLinkStep1 =>
      'Sur la page de l\'addon, touchez « Copier le lien » (ou « Install », puis « Copier l\'adresse du lien »).';

  @override
  String get guideLinkStep2 =>
      'Revenez ici et collez le lien dans le champ, ou appuyez sur « Coller ».';

  @override
  String get guideLinkStep3 =>
      'Vérifiez le nom de l\'addon, puis appuyez sur « Installer ».';

  @override
  String get guidePhoneTitle => 'Ajouter depuis le téléphone';

  @override
  String get guidePhoneStep1 =>
      'Mettez le téléphone sur le même Wi-Fi que la TV.';

  @override
  String get guidePhoneStep2 =>
      'Scannez le code, puis saisissez le code de sécurité affiché ici.';

  @override
  String get guidePhoneStep3 =>
      'Collez un lien, touchez « Ajouter », puis confirmez ici sur la TV.';

  @override
  String get portalBoxTitle => 'Sur votre téléphone';

  @override
  String get portalStep1 =>
      'Scannez le code : la page Lumio de cette TV s\'ouvre.';

  @override
  String get portalStep2 => 'Saisissez le code de sécurité affiché ci-dessous.';

  @override
  String get portalStep3 =>
      'Réglez l\'addon, puis « Copier le lien » (ou « Install »).';

  @override
  String get portalStep4 => 'Collez le lien dans la page, touchez « Ajouter ».';

  @override
  String get portalStep5 => 'Revenez ici et confirmez sur la TV.';

  @override
  String get traktStepsTitle => 'Pour connecter Trakt';

  @override
  String get traktStep1 =>
      'Appuyez sur « Connecter Trakt » : un code s\'affiche.';

  @override
  String get traktStep2 =>
      'Sur votre téléphone, ouvrez trakt.tv/activate (ou scannez le code).';

  @override
  String get traktStep3 => 'Saisissez le code affiché sur la TV.';

  @override
  String get traktStep4 =>
      'Acceptez sur Trakt : la TV se connecte toute seule.';

  @override
  String get settingsHelp => 'Aide';

  @override
  String get settingsHelpHint =>
      'Guides pas à pas : addons, téléphone, Trakt, profils, sous-titres';

  @override
  String get helpAddonsTitle => 'Ajouter un addon';

  @override
  String get helpAddonsStep1 =>
      'Ouvrez Réglages › Sources, puis « Ajouter un addon ».';

  @override
  String get helpAddonsStep2 =>
      'Choisissez un onglet : Catalogue, Par lien ou Depuis le téléphone.';

  @override
  String get helpAddonsStep3 =>
      'Appuyez sur « Installer ». Aucun addon n\'est fourni d\'office.';

  @override
  String get helpSettingTitle => 'Régler un addon';

  @override
  String get helpSettingStep1 =>
      'Sur la fiche d\'un addon du catalogue, appuyez sur « Configurer depuis le portail ».';

  @override
  String get helpSettingStep2 =>
      'Sur le téléphone, réglez l\'addon puis touchez « Copier le lien ».';

  @override
  String get helpSettingStep3 =>
      'Collez le lien dans la page, touchez « Ajouter », puis confirmez sur la TV.';

  @override
  String get helpPortalTitle => 'Le portail du téléphone';

  @override
  String get helpPortalStep1 =>
      'Le téléphone doit être sur le même Wi-Fi que la TV.';

  @override
  String get helpPortalStep2 =>
      'Ouvrez Réglages › Sources › Depuis le téléphone, puis scannez le code.';

  @override
  String get helpPortalStep3 =>
      'Saisissez le code de sécurité affiché sur la TV.';

  @override
  String get helpPortalStep4 =>
      'Laissez l\'écran de la TV ouvert : la page se ferme avec lui.';

  @override
  String get helpTraktTitle => 'Trakt';

  @override
  String get helpProfilesTitle => 'Profils et code PIN';

  @override
  String get helpProfilesStep1 =>
      'Ouvrez Réglages › Profils › Gérer les profils.';

  @override
  String get helpProfilesStep2 =>
      'Pour un profil enfant, choisissez l\'âge limite.';

  @override
  String get helpProfilesStep3 =>
      'Le code PIN parent protège les profils verrouillés et les réglages sensibles.';

  @override
  String get helpSubsTitle => 'Sous-titres';

  @override
  String get helpSubsStep1 =>
      'Pendant la lecture, ouvrez « Pistes et sous-titres ».';

  @override
  String get helpSubsStep2 => 'Choisissez la langue, la taille et le décalage.';

  @override
  String get helpSubsStep3 =>
      'Dans Réglages › Lecture, choisissez la langue préférée : elle s\'applique toute seule quand elle existe.';
}
