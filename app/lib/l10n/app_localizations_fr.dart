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
  String addonSubtitle(Object lang) {
    return 'Addon · $lang';
  }

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
  String get settingsAudioLang => 'Langue audio par défaut';

  @override
  String get settingsSubtitleLang => 'Langue des sous-titres par défaut';

  @override
  String get settingsQuality => 'Qualité préférée';

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
  String get settingsTorrentCache => 'Cache torrents';

  @override
  String get settingsUpload => 'Débit montant';

  @override
  String get unlimited => 'Illimité';

  @override
  String get uploadOff => 'Désactivé (pas d\'ensemencement)';

  @override
  String get settingsClearCacheOnExit => 'Vider le cache à la fermeture';

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
  String get pairPhoneButton => 'Saisir depuis mon téléphone';

  @override
  String get pairTitle => 'Saisir depuis mon téléphone';

  @override
  String get pairStep1 => 'Scannez ce code avec votre téléphone.';

  @override
  String get pairStep2 => 'Collez le lien et touchez Envoyer.';

  @override
  String get pairStep3 =>
      'Il arrive ici : vous confirmez ensuite l\'installation.';

  @override
  String pairOrOpen(String url) {
    return 'Ou ouvrez $url et saisissez le code.';
  }

  @override
  String get pairCodeLabel => 'Code';

  @override
  String pairExpiresIn(String time) {
    return 'Expire dans $time';
  }

  @override
  String get pairWaiting => 'En attente du téléphone…';

  @override
  String get pairExpired => 'Ce code a expiré.';

  @override
  String get pairNewCode => 'Nouveau code';

  @override
  String get pairQrLabel => 'Code QR d\'appairage';

  @override
  String get errPairInsecure => 'Adresse du serveur non sécurisée';

  @override
  String get errPairUnavailable => 'Serveur injoignable, réessayez';

  @override
  String get errPairRateLimited =>
      'Trop de demandes, réessayez dans une minute';

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
  String get settingsAccount => 'Compte et synchronisation';

  @override
  String get accountSettingsHint =>
      'Retrouvez votre liste et votre progression sur vos autres appareils';

  @override
  String get accountTitle => 'Compte';

  @override
  String get accountIntro =>
      'Connectez-vous avec votre e-mail pour synchroniser votre liste, votre progression, vos profils et vos réglages. Vos liens d\'addons ne sont pas envoyés.';

  @override
  String get accountEmailLabel => 'Adresse e-mail';

  @override
  String get accountSendCode => 'Recevoir un code';

  @override
  String get accountCodeSent =>
      'Un code de connexion vous a été envoyé par e-mail.';

  @override
  String get accountCodeLabel => 'Code reçu par e-mail';

  @override
  String get accountSignIn => 'Se connecter';

  @override
  String accountSignedInAs(Object email) {
    return 'Connecté : $email';
  }

  @override
  String get accountSyncIdle => 'Synchronisé';

  @override
  String get accountSyncSyncing => 'Synchronisation en cours…';

  @override
  String get accountSyncOffline => 'Hors ligne : nouvel essai automatique';

  @override
  String get accountSyncNow => 'Synchroniser maintenant';

  @override
  String get accountSignOut => 'Se déconnecter';

  @override
  String get accountSignedOutDone =>
      'Déconnecté. Vos données restent sur cet appareil.';

  @override
  String get accountDelete => 'Supprimer mon compte';

  @override
  String get accountDeleteConfirm =>
      'Supprimer le compte et toutes les données synchronisées sur le serveur ? Les données de cet appareil sont conservées.';

  @override
  String get accountDeleted => 'Compte supprimé';

  @override
  String get accountErrInvalidEmail => 'Adresse e-mail invalide';

  @override
  String get accountErrRejected => 'Code refusé ou expiré';

  @override
  String get accountErrRate => 'Trop de tentatives, réessayez plus tard';

  @override
  String get accountErrUnavailable =>
      'Serveur injoignable, réessayez plus tard';

  @override
  String get kidProfileNeedsPin =>
      'Ce profil enfant vient d\'un autre appareil. Créez d\'abord un PIN parent pour l\'utiliser.';
}
