import 'dart:io' show CertificateException;

import 'package:lumio/data/jellyfin_repository.dart'
    show JellyfinInsecureException;
import 'package:lumio/data/profile_repository.dart' show ProfileLimitException;
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/torrent/network_watcher.dart' show VpnRequiredException;
import 'package:lumio_core/lumio_core.dart';

/// Message d'erreur traduit pour l'interface. Le [AddonException.message]
/// français reste réservé aux journaux.
String l10nForError(AppLocalizations l, Object error) {
  if (error is ProfileLimitException) return l.maxProfilesReached;
  if (error is BackupFormatException) {
    return switch (error.error) {
      BackupFormatError.unknownFormat => l.backupErrUnknown,
      BackupFormatError.unsupportedVersion => l.backupErrVersion,
      BackupFormatError.malformed => l.backupErrMalformed,
      BackupFormatError.tooLarge => l.backupErrTooLarge,
      BackupFormatError.passphraseRequired => l.backupWrongPassphrase,
    };
  }
  if (error is WrongPassphraseException) return l.backupWrongPassphrase;
  if (error is InsufficientStorageException) {
    return l.torrentInsufficientStorage;
  }
  if (error is VpnRequiredException) return l.torrentVpnRequired;
  if (error is JellyfinAuthException) {
    return error.expired ? l.jellyfinErrExpired : l.jellyfinErrAuth;
  }
  if (error is JellyfinException) {
    return switch (error.code) {
      JellyfinErrorCode.timeout => l.jellyfinErrTimeout,
      JellyfinErrorCode.unreachable => l.jellyfinErrUnreachable,
      JellyfinErrorCode.serverError => l.jellyfinErrServer(error.status ?? 500),
      JellyfinErrorCode.refused => l.jellyfinErrRefused(error.status ?? 0),
      JellyfinErrorCode.tooLarge => l.jellyfinErrTooLarge,
      JellyfinErrorCode.redirect => l.jellyfinErrRedirect,
      JellyfinErrorCode.invalidResponse => l.jellyfinErrInvalid,
      JellyfinErrorCode.invalidServer => l.jellyfinErrAddress,
    };
  }
  // Certificat invalide : toujours dit explicitement, jamais contourné.
  if (error is CertificateException) return l.jellyfinErrCert;
  if (error is JellyfinInsecureException) return l.jellyfinInsecureBody;
  if (error is UnsafeUrlException) return l.errAddressRefused;
  if (error is TrackerNotConfigured) return l.trackingNotConfigured;
  if (error is TrackerReauthRequired) return l.trackingReauth;
  if (error is TrackerAuthDenied) return l.trackingAuthDenied;
  if (error is TrackerAuthExpired) return l.trackingAuthExpired;
  if (error is TrackerException) return l.trackingAuthUnavailable;
  if (error is AddonException) {
    return switch (error.code) {
      AddonErrorCode.duplicate => l.errDuplicate,
      AddonErrorCode.privateAddress => l.errPrivateAddress,
      AddonErrorCode.invalidAddress => l.errInvalidAddress,
      AddonErrorCode.addressRefused => l.errAddressRefused,
      AddonErrorCode.timeout => l.errTimeout,
      AddonErrorCode.unreachable => l.errUnreachable,
      AddonErrorCode.tlsFailed => l.errTls,
      AddonErrorCode.notFound => l.errNotFound,
      AddonErrorCode.serverError => l.errServer(error.status ?? 500),
      AddonErrorCode.refused => l.errRefused(error.status ?? 0),
      AddonErrorCode.tooLarge => l.errTooLarge,
      AddonErrorCode.invalidJson => l.errInvalidJson,
      AddonErrorCode.redirect => l.errRedirect,
      AddonErrorCode.manifestInvalid => l.errManifestInvalid,
      AddonErrorCode.unexpected => l.errUnexpected,
      // Exception sans code (ex. fournie par un addon tiers) : message tel quel.
      AddonErrorCode.other => error.message,
    };
  }
  return l.errOther;
}
