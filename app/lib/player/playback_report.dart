import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio_core/lumio_core.dart';

/// Message expliquant un échec de lecture (français par défaut), sans jamais
/// citer d'URL.
///
/// [err] peut être une exception ou le texte d'erreur du moteur ; [httpStatus]
/// (réponse de la source, relevée par le proxy) prime sur le reste.
String explainFailure(
  Object err, {
  int? httpStatus,
  bool refused = false,
  AppLocalizations? l10n,
}) {
  final l = l10n ?? AppLocalizationsFr();
  if (refused) return l.failRefused;
  final status = httpStatus ?? _statusFrom(err.toString());
  if (status != null) return _statusMessage(status, l);
  if (err is TimeoutException) return l.failTimeout;
  if (err is SocketException) return l.failNetwork;
  if (err is UnsafeUrlException || err is InsecureRedirectException) {
    return l.failRefused;
  }
  if (err is TooManyRedirectsException || err is InvalidRedirectException) {
    return l.failRedirect;
  }
  if (err is ResponseTooLargeException) return l.failTooLarge;
  final text = err.toString().toLowerCase();
  if (text.contains('timed out') || text.contains('timeout')) {
    return l.failTimeout;
  }
  if (text.contains('failed to recognize') ||
      text.contains('unrecognized file format') ||
      text.contains('unsupported') ||
      text.contains('no video or audio')) {
    return l.failFormat;
  }
  if (text.contains('tls') || text.contains('ssl')) return l.failTls;
  if (text.contains('connection') ||
      text.contains('host lookup') ||
      text.contains('network')) {
    return l.failNetwork;
  }
  return l.failGeneric;
}

String _statusMessage(int s, AppLocalizations l) => switch (s) {
  401 || 403 => l.httpDenied(s),
  404 || 410 => l.httpGone(s),
  429 => l.httpTooMany,
  >= 500 => l.httpServer(s),
  _ => l.httpOther(s),
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
