import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';

/// Message français expliquant un échec de lecture, sans jamais citer d'URL.
///
/// [err] peut être une exception ou le texte d'erreur du moteur ; [httpStatus]
/// (réponse de la source, relevée par le proxy) prime sur le reste.
String explainFailure(Object err, {int? httpStatus, bool refused = false}) {
  if (refused) return _refusedMessage;
  final status = httpStatus ?? _statusFrom(err.toString());
  if (status != null) return _statusMessage(status);
  if (err is TimeoutException) {
    return 'Délai dépassé : la source ne répond pas.';
  }
  if (err is SocketException) {
    return 'Connexion impossible : vérifiez le réseau.';
  }
  if (err is UnsafeUrlException || err is InsecureRedirectException) {
    return _refusedMessage;
  }
  if (err is TooManyRedirectsException || err is InvalidRedirectException) {
    return 'La source redirige de façon incorrecte.';
  }
  if (err is ResponseTooLargeException) {
    return 'La réponse de la source est trop volumineuse.';
  }
  final text = err.toString().toLowerCase();
  if (text.contains('timed out') || text.contains('timeout')) {
    return 'Délai dépassé : la source ne répond pas.';
  }
  if (text.contains('failed to recognize') ||
      text.contains('unrecognized file format') ||
      text.contains('unsupported') ||
      text.contains('no video or audio')) {
    return 'Format non pris en charge par le lecteur.';
  }
  if (text.contains('tls') || text.contains('ssl')) {
    return 'La connexion sécurisée avec la source a échoué.';
  }
  if (text.contains('connection') ||
      text.contains('host lookup') ||
      text.contains('network')) {
    return 'Connexion impossible : vérifiez le réseau.';
  }
  return 'La lecture a échoué.';
}

const _refusedMessage = 'Source refusée pour des raisons de sécurité.';

String _statusMessage(int s) => switch (s) {
  401 || 403 => 'La source a répondu $s : accès refusé.',
  404 || 410 => 'La source a répondu $s : le fichier n\'existe plus.',
  429 => 'La source a répondu 429 : trop de demandes, réessayez plus tard.',
  >= 500 => 'La source a répondu $s : elle est en panne.',
  _ => 'La source a répondu $s.',
};

final _httpCode = RegExp(
  r'http error (\d{3})|\bhttp (\d{3})\b',
  caseSensitive: false,
);

int? _statusFrom(String text) {
  final m = _httpCode.firstMatch(text);
  if (m == null) return null;
  final code = int.parse(m.group(1) ?? m.group(2)!);
  return code >= 400 && code < 600 ? code : null;
}

/// Mesure d'une lecture, journalisée `LUMIO_PLAYER {json}` (sans URL
/// complète : [redactUrl]).
class PlaybackReport {
  const PlaybackReport({
    required this.source,
    required this.viaProxy,
    this.firstFrameMs,
    this.url,
    this.error,
    this.extra = const {},
  });

  final String source;
  final bool viaProxy;
  final int? firstFrameMs;
  final Uri? url;
  final String? error;
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() => {
    'source': source,
    'via_proxy': viaProxy,
    'first_frame_ms': ?firstFrameMs,
    if (url != null) 'host': redactUrl(url.toString()),
    'error': ?error,
    ...extra,
  };

  String toLogLine() => 'LUMIO_PLAYER ${jsonEncode(toJson())}';
}
