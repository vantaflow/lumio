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
  String subtitleLabel(String lang, String source) {
    return '$lang · $source';
  }

  @override
  String subtitleLabelN(String lang, String source, int n) {
    return '$lang · $source $n';
  }

  @override
  String get langUnknown => 'Unknown language';

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
  String get openSheet => 'Open details';

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
  String get settingsPreferDirect => 'Prefer direct links over torrents';

  @override
  String get preferDirectOn => 'Direct links first';

  @override
  String get preferDirectOff => 'No preference';

  @override
  String otherAddonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other addons',
      one: '1 other addon',
    );
    return '+$_temp0';
  }

  @override
  String get playerSourceFallback => 'Source unavailable, trying the next one…';

  @override
  String playingFallback(String title) {
    return 'Playing from another source: $title';
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
  String get useCopiedLink => 'Use the copied link';

  @override
  String get installLinkInvalid => 'This is not an add-on install link.';

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
  String get torrentVpnRequired =>
      'A VPN is required for torrents and none is active. Turn on your VPN and try again.';

  @override
  String get torrentVpnLost =>
      'VPN disconnected: torrent stopped to protect your IP address.';

  @override
  String get torrentNoVpnReminder =>
      'No VPN detected: your IP address is visible to other peers.';

  @override
  String get torrentIpWarningTitle => 'Your IP address will be visible';

  @override
  String get torrentIpWarningBody =>
      'With a torrent, the other participants of the swarm can see your IP address. Use a VPN to protect it. You can require one in the settings.';

  @override
  String get torrentIpWarningContinue => 'Continue';

  @override
  String get torrentIpWarningCancel => 'Cancel';

  @override
  String get torrentIpWarningDeclined =>
      'Torrent not started. Start playback again to continue.';

  @override
  String get settingsRequireVpn => 'Require a VPN for torrents';

  @override
  String get settingsVpnInterface => 'VPN interface';

  @override
  String get vpnAny => 'Any VPN';

  @override
  String vpnInterfaceRequired(String name) {
    return '$name: required, torrents stop if it drops';
  }

  @override
  String get vpnNone => 'No active VPN detected';

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
  String get kidProfileNeedsPin =>
      'This kids profile came from another device. Create a parent PIN first to use it.';

  @override
  String get addonUrlAllow => 'Allow';

  @override
  String get addonUrlIgnore => 'Ignore';

  @override
  String get passphraseLabel => 'Backup secret phrase';

  @override
  String get passphraseConfirmLabel => 'Confirm the secret phrase';

  @override
  String get passphraseErrShort => 'At least 12 characters';

  @override
  String get passphraseErrMismatch => 'The two phrases differ';

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

  @override
  String get healthReliable => 'Reliable';

  @override
  String get healthSlow => 'Slow (> 3 s)';

  @override
  String get healthFailing => 'Failing';

  @override
  String get healthUnknown => 'No measurements yet';

  @override
  String healthDetail(Object latency, int percent) {
    return 'Median $latency · $percent% success';
  }

  @override
  String healthSemantic(Object level, Object detail) {
    return 'Health: $level, $detail';
  }

  @override
  String resetHealth(Object name) {
    return 'Reset measurements for $name';
  }

  @override
  String get localFolders => 'Local folders';

  @override
  String get localFoldersHint => 'Videos stored on this device';

  @override
  String get localAddFolder => 'Add a folder';

  @override
  String get localEmpty =>
      'No folders yet. Add a folder of videos to see them in Lumio.';

  @override
  String localVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
      zero: 'No videos',
    );
    return '$_temp0';
  }

  @override
  String get localScanNow => 'Scan now';

  @override
  String get localScanning => 'Scanning…';

  @override
  String localScanDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
      zero: 'no videos',
    );
    return 'Scan finished: $_temp0';
  }

  @override
  String localRemoveFolder(String path) {
    return 'Remove folder $path';
  }

  @override
  String get localFolderRemoved =>
      'Folder removed from Lumio. Your files are untouched.';

  @override
  String get localPermissionDenied =>
      'Lumio needs access to your videos. Allow it in the device settings.';

  @override
  String get localPickerUnavailable =>
      'The folder picker is not available. Type the folder path.';

  @override
  String get localPathTitle => 'Folder path';

  @override
  String get localPathLabel => 'Path';

  @override
  String get localPathHint => '/storage/emulated/0/Movies';

  @override
  String get localChooseFolder => 'Choose with the picker';

  @override
  String get localTypePath => 'Type a path';

  @override
  String get localSdNote =>
      'The picker only reaches internal storage. For an SD card or USB drive, type the path.';

  @override
  String get localFolderMissing => 'This folder was not found.';

  @override
  String get localFolderDenied => 'Access to this folder was denied.';

  @override
  String get localFolderOverlap =>
      'This folder overlaps a folder already added.';

  @override
  String localFolderAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
      zero: 'no videos',
    );
    return 'Folder added: $_temp0';
  }

  @override
  String get localScanFailed => 'Scanning the folder failed.';

  @override
  String get localFixTitle => 'Fix the title';

  @override
  String get localFixLabel => 'Title';

  @override
  String get localFixReset => 'Restore the detected title';

  @override
  String get localFileMissing =>
      'File not found: it may have been moved. Scan again.';

  @override
  String get localPlayFailed => 'This file cannot be played.';

  @override
  String localDetected(String title) {
    return 'Detected: $title';
  }

  @override
  String get localScanIncomplete => 'Incomplete scan: folder too large';

  @override
  String get localFolderForbidden =>
      'This folder cannot be added (system folder or non-absolute path).';

  @override
  String get jellyfinServers => 'Jellyfin servers';

  @override
  String get jellyfinServersHint =>
      'Your Jellyfin libraries on the home screen';

  @override
  String get jellyfinAddServer => 'Add a server';

  @override
  String get jellyfinEmpty =>
      'No servers yet. Add a Jellyfin server to see its libraries in Lumio.';

  @override
  String get jellyfinServerUrl => 'Server address';

  @override
  String get jellyfinServerUrlHint => 'https://jellyfin.example.com';

  @override
  String get jellyfinUser => 'Username';

  @override
  String get jellyfinPassword => 'Password';

  @override
  String get jellyfinConnect => 'Sign in';

  @override
  String get jellyfinConnecting => 'Signing in…';

  @override
  String jellyfinSignedInAs(String user) {
    return 'Signed in as $user';
  }

  @override
  String jellyfinRemove(String name) {
    return 'Sign out of $name';
  }

  @override
  String jellyfinRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get jellyfinRemoveBody =>
      'The sign-in token will be deleted from this device.';

  @override
  String get jellyfinRemoved => 'Server removed';

  @override
  String get jellyfinAdded => 'Server added';

  @override
  String get jellyfinInsecureTitle => 'Unencrypted connection';

  @override
  String get jellyfinInsecureBody =>
      'Unencrypted connection: your password would travel in clear text. Prefer an https address.';

  @override
  String get jellyfinInsecureContinue => 'Continue anyway';

  @override
  String get jellyfinLibraries => 'Libraries';

  @override
  String get jellyfinLoadMore => 'Load more';

  @override
  String get jellyfinEmptyFolder => 'Nothing to show';

  @override
  String get jellyfinPlayFailed =>
      'Cannot play: the Jellyfin server did not respond.';

  @override
  String get jellyfinErrAuth => 'Wrong username or password.';

  @override
  String get jellyfinErrExpired =>
      'Session expired. Sign in to the server again.';

  @override
  String get jellyfinErrCert =>
      'Invalid server certificate: the connection is refused.';

  @override
  String get jellyfinErrTimeout =>
      'Timed out: the Jellyfin server is not responding.';

  @override
  String get jellyfinErrUnreachable => 'Jellyfin server unreachable.';

  @override
  String jellyfinErrServer(int status) {
    return 'The Jellyfin server reported an error (HTTP $status).';
  }

  @override
  String jellyfinErrRefused(int status) {
    return 'Request refused by the Jellyfin server (HTTP $status).';
  }

  @override
  String get jellyfinErrInvalid =>
      'Unexpected response: is this really a Jellyfin server?';

  @override
  String get jellyfinErrTooLarge => 'Server response too large.';

  @override
  String get jellyfinErrRedirect =>
      'The server redirects to another address: enter the final address.';

  @override
  String get jellyfinErrAddress => 'Invalid server address.';

  @override
  String get trackingTitle => 'Tracking (Trakt)';

  @override
  String get trackingNoConnectHint =>
      'No “Connect” button until the app is configured.';

  @override
  String get trackingHint => 'Record what you watch on your account';

  @override
  String get trackingTrakt => 'Trakt';

  @override
  String get trackingNotConfigured =>
      'Not configured: the Trakt application credentials are missing. Nothing is sent.';

  @override
  String get trackingConnectedShort => 'Connected';

  @override
  String get trackingNotConnected => 'Not connected';

  @override
  String get trackingConnected =>
      'Connected: your plays are recorded on Trakt.';

  @override
  String get trackingReauth =>
      'Sign-in required: Trakt rejected the connection. Reconnect the account to resume sending.';

  @override
  String get trackingConnect => 'Connect Trakt';

  @override
  String get trackingDisconnect => 'Disconnect Trakt';

  @override
  String get trackingDisconnected => 'Trakt disconnected';

  @override
  String trackingPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events waiting to be sent',
      one: '1 event waiting to be sent',
      zero: 'Nothing waiting to be sent',
    );
    return '$_temp0';
  }

  @override
  String get trackingRetry => 'Retry sending';

  @override
  String get trackingRetried => 'Sending retried';

  @override
  String get trackingKidAllow => 'Allow tracking for this kid profile';

  @override
  String get trackingKidAllowHint =>
      'Only a parent can enable it. Otherwise nothing is sent for this profile.';

  @override
  String get trackingAuthTitle => 'Connect Trakt';

  @override
  String get trackingAuthStep =>
      'On another device, open this address then enter the code:';

  @override
  String get trackingAuthWaiting => 'Waiting for your authorization…';

  @override
  String get trackingAuthDone => 'Trakt is connected.';

  @override
  String get trackingAuthDenied => 'Authorization denied.';

  @override
  String get trackingAuthExpired =>
      'The code expired or is no longer valid. Request a new one.';

  @override
  String get trackingAuthNewCode => 'New code';

  @override
  String get trackingAuthUnavailable =>
      'The tracking service is unreachable. Try again later.';

  @override
  String get trackingQrSemantic => 'QR code for the authorization address';

  @override
  String get homeCalendar => 'Calendar';

  @override
  String get calendarTitle => 'Release calendar';

  @override
  String get calendarEmpty =>
      'No series in your list. Add a series to \"My list\" to follow its upcoming episodes.';

  @override
  String get calendarNothingSoon => 'No release planned in the next 30 days.';

  @override
  String get calendarLoadError => 'Could not load the calendar.';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarTomorrow => 'Tomorrow';

  @override
  String get calendarUnknownHeader => 'Date unknown';

  @override
  String get calendarUnknownEntry => 'Date unknown';

  @override
  String calendarEpisodeLabel(int season, int episode) {
    return 'S$season · E$episode';
  }

  @override
  String calendarEpisodeOnly(int episode) {
    return 'Episode $episode';
  }

  @override
  String get calendarNotify => 'Notify me about new episodes';

  @override
  String get calendarNotifyHint =>
      'Local notification on release day, on this device. Off by default.';

  @override
  String get calendarNotifyDenied =>
      'Notifications denied: enable them in the system settings.';

  @override
  String get calendarNotifyOn =>
      'You will be notified about upcoming episodes.';

  @override
  String get calendarNotifyChannel => 'New episodes';

  @override
  String calendarNotifyBody(String episode) {
    return 'New episode available: $episode';
  }

  @override
  String get calendarNotifyError =>
      'Notifications could not be scheduled. Try again by reopening the calendar.';

  @override
  String get castTooltip => 'Cast to a device';

  @override
  String get castChooseDevice => 'Choose a device';

  @override
  String get castSearching => 'Looking for devices…';

  @override
  String get castNoDevice => 'No device found';

  @override
  String get castNoDeviceHint =>
      'Make sure the TV is on and on the same Wi-Fi network.';

  @override
  String castPlayingOn(String device) {
    return 'Playing on $device';
  }

  @override
  String get castStop => 'Stop casting';

  @override
  String get castFailed => 'Could not cast to this device.';

  @override
  String get castUnsupported => 'This stream cannot be cast to a device.';

  @override
  String get castLost => 'Cast device lost: playback resumes here.';

  @override
  String get castNetworkError => 'No local network shared with this device.';

  @override
  String get partyTitle => 'Watch together';

  @override
  String get partyHint => 'Synchronised playback with friends and family';

  @override
  String get partyTooltip => 'Watch together';

  @override
  String get partyCreate => 'Create a room';

  @override
  String get partyCreateHint =>
      'You invite: only position and play state are shared. Everyone opens the title with their own addons.';

  @override
  String get partyJoinTitle => 'Join a room';

  @override
  String get partyJoinField => 'Invitation link';

  @override
  String get partyJoinHint => 'Paste the link you received (lumio://party…).';

  @override
  String get partyJoinButton => 'Join';

  @override
  String get partyConnecting => 'Connecting to the room…';

  @override
  String get partyInviteCode => 'Invitation code';

  @override
  String get partyLinkLabel => 'Link to share (valid for 6 h)';

  @override
  String get partyCopyLink => 'Copy link';

  @override
  String get partyLinkCopied => 'Link copied.';

  @override
  String get partyQrLabel => 'Invitation link QR code';

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
  String get partyAllControl => 'Everyone can control';

  @override
  String get partyAllControlHint => 'Otherwise only the host pauses or seeks.';

  @override
  String get partyOpenTitle => 'Open the title';

  @override
  String get partyLeave => 'Leave the room';

  @override
  String get partyRoleHost => 'You are the host';

  @override
  String get partyRoleGuest => 'You follow the host';

  @override
  String get partyErrInvalidLink => 'This invitation link is not valid.';

  @override
  String get partyErrWrongCode => 'Invitation code refused.';

  @override
  String get partyErrFull => 'The room is full (8 people).';

  @override
  String get partyErrNotFound => 'This room no longer exists.';

  @override
  String get partyErrRateLimited => 'Too many attempts, try again in a moment.';

  @override
  String get partyErrUnavailable => 'Cannot reach the room.';

  @override
  String get partyHostOnly => 'Only the host controls playback in this room.';

  @override
  String get tvNavHome => 'Home';

  @override
  String get tvSwitchProfile => 'Switch profile';

  @override
  String get tvEmptyEyebrow => 'WELCOME';

  @override
  String get tvEmptyTitle => 'Your home is waiting for its sources';

  @override
  String get tvEmptyBody =>
      'Lumio contains no content. Add a trusted addon, a folder of your videos or your Jellyfin server: your catalogs will appear here in rows.';

  @override
  String get tvEmptyLocal => 'Local folder';

  @override
  String get tvEmptyJellyfin => 'Jellyfin server';

  @override
  String get tvEmptyStep1Title => 'Paste a link';

  @override
  String get tvEmptyStep1Body =>
      'The addon\'s manifest.json link, or a stremio:// link.';

  @override
  String get tvEmptyStep2Title => 'Or send it from your phone';

  @override
  String get tvEmptyStep2Body =>
      'Scan the QR code shown, paste the link on your phone.';

  @override
  String get tvEmptyStep3Title => 'Watch';

  @override
  String get tvEmptyStep3Body =>
      'Catalogs, \"Continue\" and \"My list\" fill the home screen.';

  @override
  String get tvOnbTagline => 'Your library, your sources.';

  @override
  String get tvOnbTaglineBody =>
      'Bring movies, series and local files together in one place.';

  @override
  String get tvOnbDefault => 'Default';

  @override
  String get tvOnbProfileHeading => 'Create your profile';

  @override
  String get tvOnbProfileBody =>
      'Each profile keeps its own list, progress and settings.';

  @override
  String get tvOnbLater => 'Later';

  @override
  String get tvOnbFinish => 'Finish';

  @override
  String get tvOnbAddonTitle => 'An addon';

  @override
  String get tvOnbAddonBody => 'Paste a link or scan a QR code';

  @override
  String get tvOnbJellyfinTitle => 'A Jellyfin server';

  @override
  String get tvOnbJellyfinBody => 'Your personal media library';

  @override
  String get tvOnbLocalTitle => 'A local folder';

  @override
  String get tvOnbLocalBody => 'Files on this device or on the network';

  @override
  String get tvOnbKidTitle => 'Kid profile';

  @override
  String get tvOnbKidBody => 'Age filter and PIN to leave';

  @override
  String get quitTitle => 'Quit Lumio?';

  @override
  String get quitBody => 'You will go back to the box home screen.';

  @override
  String get quitAction => 'Quit';

  @override
  String libraryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titles',
      one: '1 title',
    );
    return '$_temp0';
  }

  @override
  String get customizeHomeHint => 'Hide or reorder the home rows.';

  @override
  String get settingsCatSources => 'Sources';

  @override
  String get settingsCatPlayback => 'Playback';

  @override
  String get settingsCatTorrents => 'Torrents and VPN';

  @override
  String get settingsCatProfiles => 'Profiles and parental control';

  @override
  String get settingsCatTracking => 'Trakt tracking';

  @override
  String get settingsCatBackup => 'Backup and import';

  @override
  String get settingsCatGeneral => 'General';

  @override
  String get settingsSourcesHint => 'Where your movies and series come from.';

  @override
  String get secAddons => 'Addons';

  @override
  String get secPersonalSources => 'My own sources';

  @override
  String get secSourceChoice => 'Choosing a source';

  @override
  String get secLanguages => 'Languages';

  @override
  String get secProtection => 'Protection';

  @override
  String get secStorage => 'Storage and speed';

  @override
  String get secInterfaceLanguage => 'Interface language';

  @override
  String get secProfiles => 'Profiles';

  @override
  String settingsForProfile(String name) {
    return 'For the profile $name.';
  }

  @override
  String addonsInstalledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count addons installed',
      one: '1 addon installed',
      zero: 'No addon installed',
    );
    return '$_temp0';
  }

  @override
  String get settingsProfilesHint =>
      'Add, edit or delete profiles; the parent PIN protects kid profiles.';

  @override
  String settingsProfilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles',
      one: '1 profile',
    );
    return '$_temp0';
  }

  @override
  String searchResultsHeader(String what, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$what · $_temp0';
  }

  @override
  String get searchMoviesAndSeries => 'Movies and series';

  @override
  String get pinChecking => 'Checking…';

  @override
  String get addonsPriorityHint => 'The order sets the priority of sources.';

  @override
  String get profileAdult => 'Adult profile';

  @override
  String get profileChange => 'Change';

  @override
  String get settingsBackHome => 'Back: home';

  @override
  String vpnCardActive(String name) {
    return 'VPN active · $name';
  }

  @override
  String get vpnCardStopHint => 'Torrents stop if the VPN drops.';

  @override
  String get vpnCardIpHint =>
      'Your IP address is visible to other peers without a VPN.';

  @override
  String cacheUsedOf(String used) {
    return '$used used of';
  }

  @override
  String sizeGbDecimal(String n) {
    return '$n GB';
  }

  @override
  String get profileAdultShort => 'Adult';

  @override
  String get manageProfilesHint =>
      'Edit a profile: name, kid profile and age limit, PIN lock. Six profiles at most.';

  @override
  String get profileEditorHint =>
      'For an adult profile, the \"Lock with PIN\" option replaces the age limit: \"The parent PIN is required to open this profile.\"';

  @override
  String get subtitleAppearance => 'Appearance';

  @override
  String get subtitleSmaller => 'Make subtitles smaller';

  @override
  String get subtitleLarger => 'Make subtitles larger';

  @override
  String get subtitleSizeSmall => 'Small';

  @override
  String get subtitleSizeNormal => 'Normal';

  @override
  String get subtitleSizeLarge => 'Large';

  @override
  String get subtitleSizeXLarge => 'Extra large';

  @override
  String get subtitleOtherLanguages => 'Other languages…';

  @override
  String get subtitleHideOtherLanguages => 'Hide other languages';

  @override
  String get seekBackShort => '−10 s';

  @override
  String get seekForwardShort => '+10 s';

  @override
  String get tracksShort => 'Tracks';

  @override
  String get nextShort => 'Next';

  @override
  String playbackSpeed(String rate) {
    return 'Speed $rate×';
  }

  @override
  String get castShort => 'Cast';

  @override
  String get partyShort => 'Together';

  @override
  String get localSubtitle => 'Videos stored on this device';

  @override
  String get heroResume => 'Resume';

  @override
  String heroMinutesLeft(Object minutes) {
    return '$minutes min left';
  }

  @override
  String get searchCaption => 'Searches all your addons and folders.';

  @override
  String streamsAvailable(Object count) {
    return 'Available streams · $count';
  }

  @override
  String get streamGroupAddon => 'ADDON';

  @override
  String get healthLineGood => 'Health: good';

  @override
  String get healthLineSlow => 'Health: slow';

  @override
  String get healthLineBad => 'Health: poor';

  @override
  String seedersCount(Object count) {
    return '$count seeders';
  }

  @override
  String get detailUnavailableBody => 'Page unavailable. Try again.';

  @override
  String get addToListShort => '+ My list';

  @override
  String get streamBadgeDirect => 'Direct';

  @override
  String get streamBadgeTorrent => 'Torrent';

  @override
  String get secAddonsPriority => 'Addons · order sets the priority';

  @override
  String get addonsMenuHint => 'OK on an addon: move up, move down, remove.';

  @override
  String get healthShortGood => 'Good health';

  @override
  String get healthShortSlow => 'Slow';

  @override
  String get healthShortOffline => 'Offline';

  @override
  String get menuMoveUp => 'Move up';

  @override
  String get menuMoveDown => 'Move down';

  @override
  String get menuResetHealth => 'Reset measurements';

  @override
  String localFoldersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders',
      one: '1 folder',
      zero: 'No folder',
    );
    return '$_temp0';
  }

  @override
  String localLastScan(Object ago) {
    return 'last scan $ago';
  }

  @override
  String agoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String agoHours(int n) {
    return '$n h ago';
  }

  @override
  String agoDays(int n) {
    return '$n d ago';
  }

  @override
  String jellyfinServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
      zero: 'No server',
    );
    return '$_temp0';
  }

  @override
  String get addAddonBreadcrumb => 'Settings › Sources';

  @override
  String get addonTabCatalog => 'Catalogue';

  @override
  String get addonTabLink => 'By link';

  @override
  String get addonTabPhone => 'From your phone';

  @override
  String get catPopular => 'Popular';

  @override
  String addonServerLine(String host) {
    return 'Server: $host';
  }

  @override
  String addonReplacesNote(String name) {
    return 'Replaces the version of “$name” already installed.';
  }

  @override
  String get unknownTitle => 'Unknown title';

  @override
  String get catOfficial => 'Official';

  @override
  String get catMoviesSeries => 'Movies and series';

  @override
  String get catTorrents => 'Torrents';

  @override
  String get catDebrid => 'Debrid';

  @override
  String get catSubtitles => 'Subtitles';

  @override
  String get catAnime => 'Anime';

  @override
  String get catMetadata => 'Metadata';

  @override
  String get catTracking => 'Tracking';

  @override
  String get catMore => 'More…';

  @override
  String get catHttpStreams => 'Direct streams';

  @override
  String get catUsenet => 'Usenet';

  @override
  String get catAsianDrama => 'Asian drama';

  @override
  String get catBollywood => 'Bollywood';

  @override
  String get catMusic => 'Music';

  @override
  String get catRadios => 'Radios';

  @override
  String get catLiveTv => 'Live TV';

  @override
  String get catMisc => 'Misc';

  @override
  String get catMoreTitle => 'Other categories';

  @override
  String get catalogInstalled => 'Installed';

  @override
  String get catalogLoadMore => 'Show more';

  @override
  String get catalogRefresh => 'Refresh';

  @override
  String catalogOffline(Object date) {
    return 'Offline: list saved on $date.';
  }

  @override
  String get catalogFallbackNote =>
      'The catalogue site is unreachable: reduced official list.';

  @override
  String get catalogLoadError => 'Couldn\'t load the catalogue.';

  @override
  String get catalogEmpty => 'No addon in this category.';

  @override
  String get catalogDetailError => 'Couldn\'t read this addon\'s page.';

  @override
  String catalogCardMeta(Object stars, Object version) {
    return '★ $stars · v$version';
  }

  @override
  String catalogCardStars(Object stars) {
    return '★ $stars';
  }

  @override
  String get chooseInstanceTitle => 'Choose a server';

  @override
  String get instanceNeedsSetup => 'needs setup';

  @override
  String get addonLinkHelp =>
      'manifest.json link or stremio:// link. A link copied on this device is offered automatically.';

  @override
  String addonPreviewLabel(Object version) {
    return 'PREVIEW · v$version';
  }

  @override
  String get addonLinkTrust =>
      'Only install sources you trust: the link may contain a personal key, kept encrypted on this device.';

  @override
  String get phoneStep1 => 'Phone on the same Wi-Fi as the TV';

  @override
  String get phoneStep2 => 'Scan the code: this TV\'s Lumio page opens';

  @override
  String get phoneStep3 =>
      'Pick an addon, tap Install, then confirm here on the TV';

  @override
  String get phoneOrType => 'Or type in the phone\'s browser';

  @override
  String get phoneCodeLabel => 'Security code:';

  @override
  String get phoneLive =>
      'Page open while this screen is shown · no external server';

  @override
  String get phoneKeepOpen => 'Keep this screen open while you use your phone.';

  @override
  String get settingsManagePhonePress => 'Press OK';

  @override
  String get phoneConnected =>
      'Phone connected · page open while this screen is shown';

  @override
  String get phoneLocked =>
      'Too many attempts: a new code is shown, try again in a minute';

  @override
  String get phoneNoNetworkTitle => 'No local network';

  @override
  String get phoneNoNetworkBody =>
      'Connect the TV to the home Wi-Fi or Ethernet: the phone page is never served over a VPN or the mobile network.';

  @override
  String get phoneIdleStopped =>
      'The page closed after 10 minutes without activity.';

  @override
  String get phoneTooManyTries =>
      'Too many attempts: the page was closed for safety. Restart it to get a new code.';

  @override
  String get phoneErrorBody => 'The page could not start. Try again.';

  @override
  String get phoneRestart => 'Restart';

  @override
  String get phoneQrLabel => 'QR code of the Lumio page on the local network';

  @override
  String get settingsManagePhone => 'Manage from your phone';

  @override
  String get settingsManagePhoneNoNetwork => 'Local network unavailable';

  @override
  String get phoneAddWaiting =>
      'Request received from the phone: check the preview and confirm here.';

  @override
  String get addonInstall => 'Install';

  @override
  String get addonConfigure => 'Configure';

  @override
  String get addonConfigurePortal => 'Configure from the portal';

  @override
  String get addonReconfigurePortal => 'Reconfigure from the portal';

  @override
  String get addonSheetRequired =>
      'This addon needs setup before it works (debrid key, languages…). Use the web portal on your phone or computer to configure it.';

  @override
  String get addonSheetConfigurable =>
      'Install it as is, or choose your settings from the web portal.';

  @override
  String portalAddonHint(Object name) {
    return 'Open this page on the portal: the “$name” page shows up directly.';
  }

  @override
  String get typePageNoMovies => 'Your addons offer no movie catalogue';

  @override
  String get typePageNoSeries => 'Your addons offer no series catalogue';

  @override
  String get guideGotIt => 'Got it';

  @override
  String get guideHelp => 'Help';

  @override
  String get guideNoteKeyStays =>
      'Your key stays encrypted on the TV: it is never sent to the phone.';

  @override
  String get guideCatalogTitle => 'Add an addon from the catalogue';

  @override
  String get guideCatalogStep1 => 'Pick an addon in the grid.';

  @override
  String get guideCatalogStep2 => 'Press \"Install\".';

  @override
  String get guideCatalogStep3 =>
      'If it needs a setting, press \"Set up from the portal\": your phone takes care of it.';

  @override
  String get guideLinkTitle => 'Add an addon with its link';

  @override
  String get guideLinkStep1 =>
      'On the addon\'s page, tap \"Copy link\" (or \"Install\", then \"Copy link address\").';

  @override
  String get guideLinkStep2 =>
      'Come back here and paste the link in the field, or press \"Paste\".';

  @override
  String get guideLinkStep3 =>
      'Check the addon\'s name, then press \"Install\".';

  @override
  String get guidePhoneTitle => 'Add from the phone';

  @override
  String get guidePhoneStep1 => 'Put the phone on the same Wi-Fi as the TV.';

  @override
  String get guidePhoneStep2 =>
      'Scan the code, then enter the security code shown here.';

  @override
  String get guidePhoneStep3 =>
      'Paste a link, tap \"Add\", then confirm here on the TV.';

  @override
  String get portalBoxTitle => 'On your phone';

  @override
  String get portalStep1 => 'Scan the code: this TV\'s Lumio page opens.';

  @override
  String get portalStep2 => 'Enter the security code shown below.';

  @override
  String get portalStep3 =>
      'Set the addon up, then \"Copy link\" (or \"Install\").';

  @override
  String get portalStep4 => 'Paste the link into the page, tap \"Add\".';

  @override
  String get portalStep5 => 'Come back here and confirm on the TV.';

  @override
  String get traktStepsTitle => 'To connect Trakt';

  @override
  String get traktStep1 => 'Press \"Connect Trakt\": a code is shown.';

  @override
  String get traktStep2 =>
      'On your phone, open trakt.tv/activate (or scan the code).';

  @override
  String get traktStep3 => 'Enter the code shown on the TV.';

  @override
  String get traktStep4 => 'Accept on Trakt: the TV connects by itself.';

  @override
  String get settingsHelp => 'Help';

  @override
  String get settingsHelpHint =>
      'Step-by-step guides: addons, phone, Trakt, profiles, subtitles';

  @override
  String get helpAddonsTitle => 'Add an addon';

  @override
  String get helpAddonsStep1 =>
      'Open Settings › Sources, then \"Add an addon\".';

  @override
  String get helpAddonsStep2 =>
      'Pick a tab: Catalogue, By link or From the phone.';

  @override
  String get helpAddonsStep3 =>
      'Press \"Install\". No addon is provided by default.';

  @override
  String get helpSettingTitle => 'Set up an addon';

  @override
  String get helpSettingStep1 =>
      'On an addon\'s card in the catalogue, press \"Set up from the portal\".';

  @override
  String get helpSettingStep2 =>
      'On the phone, set the addon up, then tap \"Copy link\".';

  @override
  String get helpSettingStep3 =>
      'Paste the link into the page, tap \"Add\", then confirm on the TV.';

  @override
  String get helpPortalTitle => 'The phone portal';

  @override
  String get helpPortalStep1 =>
      'The phone must be on the same Wi-Fi as the TV.';

  @override
  String get helpPortalStep2 =>
      'Open Settings › Sources › From the phone, then scan the code.';

  @override
  String get helpPortalStep3 => 'Enter the security code shown on the TV.';

  @override
  String get helpPortalStep4 =>
      'Keep the TV screen open: the page closes with it.';

  @override
  String get helpTraktTitle => 'Trakt';

  @override
  String get helpProfilesTitle => 'Profiles and PIN';

  @override
  String get helpProfilesStep1 => 'Open Settings › Profiles › Manage profiles.';

  @override
  String get helpProfilesStep2 => 'For a child profile, pick the age limit.';

  @override
  String get helpProfilesStep3 =>
      'The parent PIN protects locked profiles and sensitive settings.';

  @override
  String get helpSubsTitle => 'Subtitles';

  @override
  String get helpSubsStep1 => 'During playback, open \"Tracks and subtitles\".';

  @override
  String get helpSubsStep2 => 'Pick the language, the size and the delay.';

  @override
  String get helpSubsStep3 =>
      'In Settings › Playback, pick the preferred language: it applies by itself when it exists.';
}
