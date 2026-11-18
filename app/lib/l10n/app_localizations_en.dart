// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get continueAction => 'Continue';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get paste => 'Paste';

  @override
  String get install => 'Install';

  @override
  String get done => 'Done';

  @override
  String get loading => 'Loading';

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get homeSearch => 'Search';

  @override
  String get homeManageList => 'Manage my list';

  @override
  String get homeCustomize => 'Customize';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeAddonsError => 'Couldn\'t load your addons';

  @override
  String get homeNoCatalog => 'Your addons offer no catalogue';

  @override
  String get homeNoAddons =>
      'Add an addon or a personal source to fill your home screen.';

  @override
  String get homeManageAddons => 'Manage addons';

  @override
  String get homeFiltered => 'No content suitable for this profile';

  @override
  String get homeRowFailed => 'Couldn\'t load';

  @override
  String get myList => 'My list';

  @override
  String get continueWatching => 'Continue watching';

  @override
  String get sourceLocal => 'Local';

  @override
  String get sourceAddon => 'addon';

  @override
  String resumeSemantic(Object title) {
    return 'Resume $title';
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
  String get sheetUnavailable => 'Details unavailable. Try again.';

  @override
  String get notAllowedForProfile =>
      'This content is not allowed for this profile.';

  @override
  String get noSourceAvailable => 'No source available. Check your addons.';

  @override
  String get addonsTitle => 'Addons';

  @override
  String get addAddon => 'Add an addon';

  @override
  String get addonsLoadError => 'Couldn\'t load addons';

  @override
  String get addonsEmpty =>
      'No addon installed. An addon provides catalogues and sources: add one with its link.';

  @override
  String get addonActionFailed => 'Action failed: the addon was not changed';

  @override
  String get removeAddonTitle => 'Delete this addon?';

  @override
  String removeAddonBody(Object name) {
    return '\"$name\" will be removed from Lumio. Its catalogues and sources will no longer be offered.';
  }

  @override
  String get addonBroken => 'Unreadable addon: delete it, then reinstall it';

  @override
  String get addonDisabled => 'Disabled';

  @override
  String moveAddonUp(Object name) {
    return 'Move $name up';
  }

  @override
  String moveAddonDown(Object name) {
    return 'Move $name down';
  }

  @override
  String enableAddon(Object name) {
    return 'Enable $name';
  }

  @override
  String deleteAddon(Object name) {
    return 'Delete $name';
  }

  @override
  String get typeMovie => 'Movies';

  @override
  String get typeSeries => 'Series';

  @override
  String get typeAnime => 'Anime';

  @override
  String get typeOther => 'Other';

  @override
  String get resCatalog => 'Catalogs';

  @override
  String get resMeta => 'Details';

  @override
  String get resStream => 'Streams';

  @override
  String get resSubtitles => 'Subtitles';

  @override
  String get resAddonCatalog => 'Addons';

  @override
  String get clipboardEmpty => 'The clipboard is empty';

  @override
  String get localAddressRefused => 'Local address refused: no addon installed';

  @override
  String get addonUnreadable => 'Couldn\'t read this addon';

  @override
  String get localAddressTitle => 'Local address';

  @override
  String get localAddressBody =>
      'This address points to your device or local network. Only continue if you started this addon yourself.';

  @override
  String get installFailed => 'Couldn\'t install';

  @override
  String get addonLinkLabel => 'Addon link';

  @override
  String get trustWarning =>
      'Only install addons from sources you trust: an addon sees what you browse.';

  @override
  String versionLabel(Object version) {
    return 'Version $version';
  }

  @override
  String get alreadyInstalled => 'Already installed';

  @override
  String provides(Object list) {
    return 'Provides: $list';
  }

  @override
  String get libraryLoadError => 'Couldn\'t read your list.';

  @override
  String get libraryEmpty =>
      'Your list is empty. Open a title and choose \"Add to my list\".';

  @override
  String updateAvailable(Object version) {
    return 'Update available: version $version';
  }

  @override
  String get download => 'Download';

  @override
  String get customizeHome => 'Customize home';

  @override
  String get progressNotSaved => 'Progress not saved';

  @override
  String resumeAt(Object time) {
    return 'Resuming at $time';
  }

  @override
  String get settingsNotSaved => 'Settings not saved';

  @override
  String get settingsUnavailable => 'Saved settings unavailable';

  @override
  String get subtitleSettingsNotApplied => 'Subtitle settings not applied';

  @override
  String get nextEpisodeUnavailable => 'Next episode unavailable';

  @override
  String get buffering => 'Buffering';

  @override
  String get chooseOtherSource => 'Choose another source';

  @override
  String get seekBack10 => 'Back 10 seconds';

  @override
  String get seekForward10 => 'Forward 10 seconds';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get tracksAndSubtitles => 'Tracks and subtitles';

  @override
  String get seekBar => 'Playback position';

  @override
  String get audio => 'Audio';

  @override
  String get noAudioTrack => 'No audio track available';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get subtitlesOff => 'Off';

  @override
  String addonSubtitle(Object lang) {
    return 'Addon · $lang';
  }

  @override
  String get subtitleDelay => 'Subtitle delay';

  @override
  String get subtitleAdvance => 'Advance subtitles by 100 ms';

  @override
  String get subtitleRetard => 'Delay subtitles by 100 ms';

  @override
  String get subtitleSize => 'Size';

  @override
  String get opaqueBackground => 'Opaque background';

  @override
  String get subtitleUnreadable => 'Unreadable subtitle';

  @override
  String trackN(int n) {
    return 'Track $n';
  }

  @override
  String nextEpisodeIn(int seconds, Object title) {
    return 'Next episode in $seconds seconds: $title';
  }

  @override
  String nextEpisodeInShort(int seconds) {
    return 'Next episode in $seconds s';
  }

  @override
  String get playNow => 'Play now';

  @override
  String get torrentNotPlayable =>
      'This stream uses a torrent: it cannot be played here.';

  @override
  String get failTimeout => 'Timed out: the source is not responding.';

  @override
  String get failNetwork => 'Can\'t connect: check the network.';

  @override
  String get failRedirect => 'The source redirects incorrectly.';

  @override
  String get failTooLarge => 'The source\'s response is too large.';

  @override
  String get failFormat => 'Format not supported by the player.';

  @override
  String get failTls => 'The secure connection to the source failed.';

  @override
  String get failGeneric => 'Playback failed.';

  @override
  String get failRefused => 'Source refused for security reasons.';

  @override
  String httpDenied(int status) {
    return 'The source replied $status: access denied.';
  }

  @override
  String httpGone(int status) {
    return 'The source replied $status: the file no longer exists.';
  }

  @override
  String get httpTooMany =>
      'The source replied 429: too many requests, try again later.';

  @override
  String httpServer(int status) {
    return 'The source replied $status: it is down.';
  }

  @override
  String httpOther(int status) {
    return 'The source replied $status.';
  }

  @override
  String get noStreams => 'No stream found. Check your addons.';

  @override
  String get addonFallback => 'Addon';

  @override
  String get noResponse => 'Not responding';

  @override
  String streamCount(int count) {
    return '$count streams';
  }

  @override
  String get torrentLabel => 'Torrent';

  @override
  String get kindTorrent => 'torrent';

  @override
  String get kindDirect => 'direct link';

  @override
  String seedersSemantic(int count) {
    return '$count sources';
  }

  @override
  String get recommendedSemantic => 'recommended';

  @override
  String get recommended => 'Recommended';

  @override
  String sizeGb(Object value) {
    return '$value GB';
  }

  @override
  String sizeMb(int value) {
    return '$value MB';
  }

  @override
  String get listUpdateFailed => 'My list couldn\'t be updated.';

  @override
  String get detailLoadError => 'Couldn\'t load the details.';

  @override
  String get autoPlayBest => 'Auto play · best source';

  @override
  String get removeFromList => 'Remove from my list';

  @override
  String get addToList => 'Add to my list';

  @override
  String get seasonEpisodes => 'Episodes';

  @override
  String get seasonSpecials => 'Specials';

  @override
  String seasonN(int n) {
    return 'Season $n';
  }

  @override
  String get noEpisodes => 'No episode available for this series.';

  @override
  String get seasonsTitle => 'Seasons';

  @override
  String get sourcesTitle => 'Sources';

  @override
  String get watchedSemantic => 'watched';

  @override
  String get unwatchedSemantic => 'unwatched';

  @override
  String get episodeLetter => 'E';

  @override
  String get watchedBadge => 'Watched';

  @override
  String get searchHint => 'Search for a title';

  @override
  String get kbSpace => 'Space';

  @override
  String get kbErase => 'Erase';

  @override
  String get kbAll => 'All';

  @override
  String get kbClearAll => 'Clear all';

  @override
  String get kbLatin => 'Latin keyboard';

  @override
  String get kbArabic => 'Arabic keyboard';

  @override
  String get dictationStop => 'Stop dictation';

  @override
  String get dictationStart => 'Voice dictation';

  @override
  String get searchPrompt => 'Type a title to start searching';

  @override
  String get searchNoAddon => 'No active addon offers search';

  @override
  String get searchNoResults => 'No results';

  @override
  String get filterAll => 'All';

  @override
  String get filterMovies => 'Movies';

  @override
  String get filterSeries => 'Series';

  @override
  String get kidAllAges => 'Kid · All audiences';

  @override
  String kidYears(int years) {
    return 'Kid · $years+';
  }

  @override
  String get profilesLoadError => 'Couldn\'t load profiles';

  @override
  String get parentalUnavailable => 'Parental control unavailable. Try again.';

  @override
  String pinFor(Object name) {
    return 'PIN for $name';
  }

  @override
  String get maxProfilesReached => 'Six profiles maximum';

  @override
  String get profileNotModified => 'Action failed: the profile was not changed';

  @override
  String get whoIsWatching => 'Who is watching?';

  @override
  String get manageProfiles => 'Manage profiles';

  @override
  String get lockedSemantic => 'locked, PIN required';

  @override
  String get editSemantic => 'edit';

  @override
  String get pinBadge => 'PIN';

  @override
  String get addProfileSemantic => 'Add a profile';

  @override
  String get nameRequired => 'Give the profile a name';

  @override
  String get deleteProfileTitle => 'Delete this profile?';

  @override
  String get deleteProfileBody =>
      'Its progress, list and settings will be deleted.';

  @override
  String get ageAll => 'All audiences';

  @override
  String get newProfile => 'New profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get nameLabel => 'Name';

  @override
  String get kidProfile => 'Kid profile';

  @override
  String get kidProfileHint =>
      'Content filtered by age; settings and profile switching protected by the parent PIN.';

  @override
  String get ageLimit => 'Age limit';

  @override
  String get lockByPin => 'Lock with PIN';

  @override
  String get lockByPinHint =>
      'The parent PIN is required to open this profile.';

  @override
  String get profileFallback => 'Profile';

  @override
  String tooManyTries(int min) {
    return 'Too many attempts. Try again in $min min.';
  }

  @override
  String get pinWrong => 'Wrong PIN';

  @override
  String get pinCheckFailed => 'Couldn\'t verify. Try again.';

  @override
  String get pinForgot => 'Forgot PIN?';

  @override
  String pinDotsSemantic(int filled) {
    String _temp0 = intl.Intl.pluralLogic(
      filled,
      locale: localeName,
      other: '$filled digits entered out of 4',
      one: '1 digit entered out of 4',
      zero: '0 digits entered out of 4',
    );
    return '$_temp0';
  }

  @override
  String digitSemantic(Object digit) {
    return 'Digit $digit';
  }

  @override
  String get eraseLastDigit => 'Erase the last digit';

  @override
  String get recoveryTitle => 'Recovery code';

  @override
  String get recoveryBody =>
      'Write this code down and keep it safe: it lets you choose a new PIN if you forget it. It will never be shown again.';

  @override
  String get recoveryNoted => 'I wrote the code down';

  @override
  String get choosePin => 'Choose a PIN';

  @override
  String get pinHint => '4 digits. It protects kid profiles and settings.';

  @override
  String get confirmPin => 'Confirm the PIN';

  @override
  String get pinMismatch => 'The two PINs don\'t match';

  @override
  String get pinSaveFailed => 'Couldn\'t save the PIN';

  @override
  String get recoveryWrong => 'Wrong recovery code';

  @override
  String get tooManyTriesLater =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get recoveryFailed => 'Couldn\'t recover';

  @override
  String get parentPin => 'Parent PIN';

  @override
  String get askParent => 'Ask a parent to enter their PIN.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAddons => 'Addons';

  @override
  String get settingsAddonsHint => 'Reorder, enable or delete your addons';

  @override
  String get settingsLanguage => 'Interface language';

  @override
  String get langFrench => 'Français';

  @override
  String get langEnglish => 'English';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsAudioLang => 'Default audio language';

  @override
  String get settingsSubtitleLang => 'Default subtitle language';

  @override
  String get settingsQuality => 'Preferred quality';

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
  String get settingsTorrentCache => 'Torrent cache';

  @override
  String get settingsUpload => 'Upload speed';

  @override
  String get unlimited => 'Unlimited';

  @override
  String get uploadOff => 'Off (no seeding)';

  @override
  String get settingsClearCacheOnExit => 'Clear cache on exit';

  @override
  String get optionYes => 'Yes';

  @override
  String get optionNo => 'No';

  @override
  String cacheGb(int n) {
    return '$n GB';
  }

  @override
  String uploadKbps(int n) {
    return '$n KB/s';
  }

  @override
  String get settingsVersion => 'Version';

  @override
  String versionValue(Object version) {
    return 'Lumio $version';
  }

  @override
  String get debugUnlocked => 'Debug menu enabled';

  @override
  String get debugMenuTitle => 'Debug menu';

  @override
  String get debugNone => 'No debug screen';

  @override
  String get debugTorrent => 'Torrent spike';

  @override
  String get debugPlayer => 'Player spike';

  @override
  String get debugLoop => 'Endurance loop';

  @override
  String get settingsAbout => 'About';

  @override
  String get aboutLicense => 'GPL-3.0 licence';

  @override
  String get aboutCredits => 'Credits: libmpv, media_kit, libtorrent';

  @override
  String get openSourceLicenses => 'Open source licences';

  @override
  String get settingSaveFailed => 'Setting not saved';

  @override
  String get gplTitle => 'GPL-3.0 licence';

  @override
  String get gplText =>
      'Lumio is free software, distributed under the GNU General Public License version 3 (GPL-3.0). You may copy, modify and redistribute it under the terms of this licence. It comes with no warranty. Full text: https://www.gnu.org/licenses/gpl-3.0.html';

  @override
  String get creditsLibmpv => 'libmpv: video player (LGPL/GPL)';

  @override
  String get creditsMediaKit => 'media_kit: Flutter integration of the player';

  @override
  String get creditsLibtorrent => 'libtorrent: torrent engine (BSD)';

  @override
  String get creditsFonts =>
      'Fonts Bricolage Grotesque and Manrope (SIL OFL 1.1 licence)';

  @override
  String get settingsNone => 'None';

  @override
  String get subtitlesNone => 'No subtitles';

  @override
  String get errDuplicate => 'This addon is already installed';

  @override
  String get errPrivateAddress => 'This address points to your local network';

  @override
  String get errInvalidAddress => 'Invalid address';

  @override
  String get errAddressRefused => 'Address refused';

  @override
  String get errTimeout => 'Timed out: the addon is not responding';

  @override
  String get errUnreachable => 'Addon unreachable';

  @override
  String get errTls => 'Secure connection failed (certificate rejected)';

  @override
  String get errNotFound => 'Addon or resource not found';

  @override
  String errServer(int status) {
    return 'Addon error (HTTP $status)';
  }

  @override
  String errRefused(int status) {
    return 'Response refused by the addon (HTTP $status)';
  }

  @override
  String get errTooLarge => 'Response too large';

  @override
  String get errInvalidJson => 'Invalid response: not valid JSON';

  @override
  String get errRedirect => 'Redirect refused or invalid';

  @override
  String get errManifestInvalid => 'Invalid manifest';

  @override
  String get errUnexpected => 'Unexpected error while loading';

  @override
  String get errOther => 'Something went wrong';

  @override
  String get qualityAuto => 'Automatic';

  @override
  String get pairPhoneButton => 'Enter from my phone';

  @override
  String get pairTitle => 'Enter from my phone';

  @override
  String get pairStep1 => 'Scan this code with your phone.';

  @override
  String get pairStep2 => 'Paste the link and tap Send.';

  @override
  String get pairStep3 => 'It arrives here: you then confirm the installation.';

  @override
  String pairOrOpen(String url) {
    return 'Or open $url and enter the code.';
  }

  @override
  String get pairCodeLabel => 'Code';

  @override
  String pairExpiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String get pairWaiting => 'Waiting for your phone…';

  @override
  String get pairExpired => 'This code has expired.';

  @override
  String get pairNewCode => 'New code';

  @override
  String get pairQrLabel => 'Pairing QR code';

  @override
  String get errPairInsecure => 'Insecure server address';

  @override
  String get errPairUnavailable => 'Server unreachable, try again';

  @override
  String get errPairRateLimited => 'Too many requests, try again in a minute';

  @override
  String onboardingStep(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingLanguageTitle => 'Choose your language';

  @override
  String get onboardingProfileTitle => 'Your profile';

  @override
  String get onboardingProfileBody =>
      'What should we call you? You can change it later.';

  @override
  String get onboardingProfileName => 'Profile name';

  @override
  String get onboardingAddKid => 'Add a kid profile';

  @override
  String onboardingKidAdded(String name) {
    return 'Kid profile added: $name';
  }

  @override
  String get onboardingSourcesTitle => 'Add your sources';

  @override
  String get onboardingSourcesBody =>
      'Lumio ships with no content: add your own sources to fill the home screen.';

  @override
  String onboardingAddonsInstalled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count addons installed',
      one: '1 addon installed',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDoneTitle => 'All set';

  @override
  String get onboardingDoneBody =>
      'You can add or change your sources at any time from the settings.';

  @override
  String get onboardingSaveError => 'Could not save, please try again';

  @override
  String get sourcesReminderTitle => 'Add your sources';

  @override
  String get sourcesReminderBody =>
      'Your home stays empty until you add a source.';

  @override
  String get sourcesReminderDismiss => 'Hide';

  @override
  String get torrentInsufficientStorage =>
      'Not enough storage space to play this torrent. Free up some space and try again.';

  @override
  String get torrentNoPeers =>
      'No source available for this torrent. Try another stream.';

  @override
  String get torrentNoFile =>
      'This torrent has no playable file. Try another stream.';

  @override
  String get torrentFailed =>
      'The torrent could not start. Try another stream.';

  @override
  String get torrentConnecting => 'Connecting to sources…';

  @override
  String get torrentConnectionLost => 'Connection lost, retrying…';

  @override
  String torrentPeers(Object count) {
    return '$count sources';
  }

  @override
  String torrentRateKb(Object value) {
    return '$value KB/s';
  }

  @override
  String torrentRateMb(Object value) {
    return '$value MB/s';
  }

  @override
  String torrentBuffered(Object percent) {
    return '$percent% downloaded';
  }

  @override
  String get settingsAccount => 'Account and sync';

  @override
  String get accountSettingsHint =>
      'Get your list and progress on your other devices';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountIntro =>
      'Sign in with your e-mail to sync your list, progress, profiles and settings. Your addon links only leave encrypted with a secret phrase you choose.';

  @override
  String get accountEmailLabel => 'E-mail address';

  @override
  String get accountSendCode => 'Get a code';

  @override
  String get accountCodeSent => 'A sign-in code was sent to your e-mail.';

  @override
  String get accountCodeLabel => 'Code received by e-mail';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String accountSignedInAs(Object email) {
    return 'Signed in: $email';
  }

  @override
  String get accountSyncIdle => 'Up to date';

  @override
  String get accountSyncSyncing => 'Syncing…';

  @override
  String get accountSyncOffline => 'Offline: retrying automatically';

  @override
  String get accountSyncNow => 'Sync now';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignedOutDone =>
      'Signed out. Your data stays on this device.';

  @override
  String get accountDelete => 'Delete my account';

  @override
  String get accountDeleteConfirm =>
      'Delete the account and all synced data on the server? Data on this device is kept.';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get accountErrInvalidEmail => 'Invalid e-mail address';

  @override
  String get accountErrRejected => 'Code refused or expired';

  @override
  String get accountErrRate => 'Too many attempts, try again later';

  @override
  String get accountErrUnavailable => 'Server unreachable, try again later';

  @override
  String get kidProfileNeedsPin =>
      'This kids profile came from another device. Create a parent PIN first to use it.';

  @override
  String get accountAddonsTitle => 'Synced addons';

  @override
  String get addonSyncNoPassphrase =>
      'No secret phrase: your addons are not synced.';

  @override
  String get addonSyncWaiting =>
      'Waiting for the first exchange with the server…';

  @override
  String get addonSyncReady =>
      'Your addons are synced, encrypted with your secret phrase.';

  @override
  String get addonSyncWrong =>
      'Wrong secret phrase: your addons are not synced';

  @override
  String get addonSyncTooLarge =>
      'Too many addons to sync. Remove a few to resume.';

  @override
  String get addonSyncResetting =>
      'Reset waiting for a connection to the server…';

  @override
  String addonSyncFailed(int count) {
    return '$count received addon(s) could not be installed for now; retrying automatically.';
  }

  @override
  String addonSyncPrivate(Object label) {
    return 'Address on your local network needs confirmation: $label';
  }

  @override
  String get addonSyncAllow => 'Allow';

  @override
  String get addonSyncIgnore => 'Ignore';

  @override
  String get passphraseSet => 'Set the secret phrase';

  @override
  String get passphraseEnter => 'Enter the secret phrase';

  @override
  String get passphraseChange => 'Change the secret phrase';

  @override
  String get passphraseReset => 'Reset';

  @override
  String get passphraseResetConfirm =>
      'Delete your synced addons from the server? The addons on this device are kept and the rest of your data is untouched. You can then set a new secret phrase.';

  @override
  String get passphraseResetDone => 'Reset requested';

  @override
  String get passphraseTitle => 'Sync secret phrase';

  @override
  String get passphraseIntro =>
      'This phrase encrypts your addons before they are sent: the server cannot read them and never receives the phrase. Enter the same one on each of your devices. If you lose it, your addons must be added again; the rest of your data stays available.';

  @override
  String get passphraseLabel => 'Sync secret phrase';

  @override
  String get passphraseConfirmLabel => 'Confirm the secret phrase';

  @override
  String get passphraseErrShort => 'At least 12 characters';

  @override
  String get passphraseErrMismatch => 'The two phrases differ';

  @override
  String get passphraseSave => 'Save';

  @override
  String get passphraseSaved => 'Secret phrase saved';

  @override
  String get passphraseErrSave => 'Could not save the secret phrase';

  @override
  String get addonSyncPhraseReset =>
      'Secret phrase needs to be entered again: addon sync was reset from another device.';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get backupExport => 'Export my data';

  @override
  String get backupExportHint =>
      'Profiles, my list, progress and settings in one file';

  @override
  String get backupImport => 'Import a backup';

  @override
  String get backupImportHint =>
      'Adds the file\'s content to your data; nothing is deleted';

  @override
  String get backupSecretsTitle => 'Include addon addresses?';

  @override
  String get backupSecretsWarning =>
      'This file will contain your addon addresses. It will be encrypted with a passphrase you choose: without it nobody can read it, you included. Without the addresses, the file contains no secret.';

  @override
  String get backupWithoutSecrets => 'Without addresses';

  @override
  String get backupWithSecrets => 'Include (encrypted)';

  @override
  String get backupPassphraseTitle => 'Backup passphrase';

  @override
  String get backupPassphraseHint =>
      'Choose a passphrase of at least 12 characters. It is not saved: write it down.';

  @override
  String get backupImportPassphraseTitle => 'Encrypted backup';

  @override
  String get backupImportPassphraseHint =>
      'Enter the passphrase chosen when exporting.';

  @override
  String get backupWrongPassphrase => 'Wrong passphrase, or damaged file.';

  @override
  String get backupContinue => 'Continue';

  @override
  String get backupErrUnknown => 'This file is not a Lumio backup.';

  @override
  String get backupErrVersion =>
      'This backup comes from a newer version of Lumio. Update the app.';

  @override
  String get backupErrMalformed => 'This backup is unreadable or damaged.';

  @override
  String get backupErrTooLarge => 'This backup is too large (10 MB maximum).';

  @override
  String get backupErrFile => 'Could not read or write the file.';

  @override
  String backupExported(String path) {
    return 'Backup saved: $path';
  }

  @override
  String get backupPickTitle => 'Choose a backup';

  @override
  String backupNoFiles(String dir) {
    return 'No backup found. Copy a .lumio.json file into this folder: $dir';
  }

  @override
  String get backupConfirmTitle => 'Import this backup?';

  @override
  String get backupConfirmBody =>
      'The file\'s content is added to your data. Nothing is deleted or replaced, except progress older than the file\'s.';

  @override
  String get backupImportBusy => 'Importing…';

  @override
  String get backupDoneTitle => 'Import finished';

  @override
  String backupSumProfiles(int n) {
    return '$n profile(s) added';
  }

  @override
  String backupSumLibrary(int n) {
    return '$n title(s) added to the list';
  }

  @override
  String backupSumProgress(int n) {
    return '$n progress entr(ies) imported';
  }

  @override
  String backupSumAddons(int n) {
    return '$n addon(s) installed';
  }

  @override
  String get backupSumNothing =>
      'Nothing new: your data already had everything.';

  @override
  String backupSumNameOnly(int n) {
    return '$n addon(s) to reinstall by hand: the file has no addresses.';
  }

  @override
  String backupSumFailed(int n) {
    return '$n addon(s) could not be installed.';
  }

  @override
  String backupSumSkipped(int n) {
    return '$n invalid entr(ies) ignored.';
  }

  @override
  String backupSumProfilesSkipped(int n) {
    return '$n profile(s) not added: six profiles at most.';
  }

  @override
  String get backupKidNeedsPin =>
      'A kids profile was added: create a parent PIN first to use it.';

  @override
  String get backupPrivateTitle => 'Local address';

  @override
  String backupPrivateBody(String name, String host) {
    return '\"$name\" ($host) points to your local network. Install it anyway?';
  }

  @override
  String get otherImportTitle => 'Import from another client';

  @override
  String get otherImportHint => 'Addons and list from exported files';

  @override
  String get otherImportHelp =>
      'Choose or paste the JSON files exported from your previous compatible client (for example Stremio: the addonCollectionGet and datastoreGet responses). No account is contacted: only these files are read. The list is added to the active profile; addons are installed one by one.';

  @override
  String get otherImportAddonsLabel => 'Addons (JSON)';

  @override
  String get otherImportLibraryLabel => 'Library (JSON)';

  @override
  String get otherImportPasteHint => 'Paste the content here…';

  @override
  String get otherImportChooseFile => 'Choose a file';

  @override
  String get otherImportRemoveFile => 'Remove the file';

  @override
  String otherImportFileLoaded(String name) {
    return 'File: $name';
  }

  @override
  String get otherImportPickTitle => 'Choose a JSON file';

  @override
  String otherImportNoFiles(String dir) {
    return 'No .json file found. Copy your exported files there: $dir';
  }

  @override
  String get otherImportRun => 'Import';

  @override
  String get otherImportNothing => 'Choose or paste at least one file.';

  @override
  String otherImportErrFormat(String which) {
    return 'This content is not a recognised export: $which.';
  }

  @override
  String get otherImportErrTooLarge =>
      'This content is too large (10 MB maximum).';

  @override
  String otherImportProgressAddons(int done, int total) {
    return 'Installing addons: $done of $total';
  }

  @override
  String get otherImportProgressLibrary => 'Adding to the list…';

  @override
  String get otherImportDoneTitle => 'Import finished';

  @override
  String otherImportSumInstalled(int n) {
    return '$n addon(s) installed';
  }

  @override
  String otherImportSumAlready(int n) {
    return '$n addon(s) already present';
  }

  @override
  String otherImportSumPending(int n) {
    return '$n addon(s) waiting (local address)';
  }

  @override
  String otherImportSumSkipped(int n, String names) {
    return '$n item(s) skipped: $names';
  }

  @override
  String otherImportSumLibrary(int n) {
    return '$n title(s) added to the list';
  }

  @override
  String otherImportSumLibraryAlready(int n) {
    return '$n title(s) already in the list';
  }

  @override
  String get otherImportSumNothing => 'Nothing to import in these files.';

  @override
  String otherImportPendingItem(String host) {
    return 'An addon points to your local network ($host). Install it anyway?';
  }

  @override
  String get otherImportWhatAddons => 'addons';

  @override
  String get otherImportWhatLibrary => 'library';

  @override
  String otherImportSumFailedInvalid(int n) {
    return '$n addon(s) rejected: invalid manifest';
  }

  @override
  String otherImportSumFailedUnreachable(int n) {
    return '$n addon(s) unreachable';
  }

  @override
  String otherImportSumFailedOther(int n) {
    return '$n addon(s) could not be installed (other cause)';
  }

  @override
  String otherImportSumLibraryFailed(int n) {
    return '$n title(s) could not be added to the list';
  }
}
