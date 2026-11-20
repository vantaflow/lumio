import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../net/http_fetcher.dart';

/// Manifeste de mise à jour : `{version, apk, sha256}` et, facultativement,
/// `apks: {<abi>: {apk, sha256}}` pour proposer un APK par architecture
/// (`apk`/`sha256` à la racine servent de repli).
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.apkUrl,
    required this.sha256,
  });

  final String version;
  final Uri apkUrl;
  final String sha256;
}

/// Vérifie si une version plus récente est publiée. Ne lève jamais : hors
/// ligne, erreur serveur ou manifeste invalide donnent `null`.
class UpdateChecker {
  UpdateChecker(
    this._fetcher,
    this._manifestUrl,
    this._currentVersion, {
    List<String> supportedAbis = const [],
  }) : _abis = supportedAbis;

  final HttpFetcher _fetcher;
  final Uri _manifestUrl;
  final String _currentVersion;

  /// ABI de l'appareil, par ordre de préférence (`Build.SUPPORTED_ABIS`).
  final List<String> _abis;

  /// Manifeste si la version distante est strictement plus récente, sinon
  /// `null`.
  Future<UpdateManifest?> check() async {
    try {
      final current = _parseVersion(_currentVersion);
      if (current == null) return null;
      final res = await _fetcher.get(
        _manifestUrl,
        maxBytes: 64 * 1024,
        timeout: const Duration(seconds: 8),
      );
      if (res.status != 200) return null;
      final json = jsonDecode(utf8.decode(res.body));
      if (json is! Map) return null;
      final version = json['version'];
      final apk = json['apk'];
      final hash = json['sha256'];
      if (version is! String || apk is! String || hash is! String) return null;
      final remote = _parseVersion(version);
      if (remote == null) return null;
      if (_compare(remote, current) <= 0) return null;
      var chosenApk = apk;
      var chosenHash = hash;
      final apks = json['apks'];
      if (apks is Map) {
        for (final abi in _abis) {
          final entry = apks[abi];
          if (entry is Map &&
              entry['apk'] is String &&
              entry['sha256'] is String) {
            chosenApk = entry['apk'] as String;
            chosenHash = entry['sha256'] as String;
            break;
          }
        }
      }
      final apkUrl = Uri.tryParse(chosenApk);
      if (apkUrl == null ||
          !(apkUrl.scheme == 'http' || apkUrl.scheme == 'https') ||
          apkUrl.host.isEmpty) {
        return null;
      }
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(chosenHash)) return null;
      return UpdateManifest(
        version: version,
        apkUrl: apkUrl,
        sha256: chosenHash,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Vrai si le SHA-256 de [bytes] égale [expectedHex] (casse indifférente).
bool verifySha256(List<int> bytes, String expectedHex) =>
    sha256.convert(bytes).toString() == expectedHex.trim().toLowerCase();

/// `major.minor.patch` ; suffixes `+build` et `-pré-version` ignorés.
List<int>? _parseVersion(String v) {
  final core = v.trim().split(RegExp(r'[+-]')).first;
  final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(core);
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

int _compare(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}
