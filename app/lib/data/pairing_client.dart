import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Cause d'un échec d'appairage (traduite à l'affichage, voir `l10nForError`).
enum PairingErrorCode { insecureUrl, unavailable, expired, rateLimited }

class PairingException implements Exception {
  const PairingException(this.code);
  final PairingErrorCode code;

  @override
  String toString() => 'PairingException: ${code.name}';
}

/// Session d'appairage ouverte sur la télé : [code] est montré à l'écran
/// (QR et texte), [pollToken] reste secret et authentifie l'interrogation.
class PairSession {
  const PairSession({
    required this.code,
    required this.pollToken,
    required this.expiresAt,
  });

  final String code;
  final String pollToken;
  final DateTime expiresAt;
}

/// Réponse HTTP minimale (statut, corps texte, en-têtes en minuscules).
class PairHttpResponse {
  const PairHttpResponse(this.status, this.body, [this.headers = const {}]);
  final int status;
  final String body;
  final Map<String, String> headers;
}

/// Transport HTTP du client d'appairage (POST nécessaire, absent de
/// `HttpFetcher` qui est GET seul) ; substituable en test.
abstract class PairHttp {
  Future<PairHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers,
  });
}

class IoPairHttp implements PairHttp {
  const IoPairHttp({this.timeout = const Duration(seconds: 8)});
  final Duration timeout;

  static const _maxBytes = 16 * 1024;

  @override
  Future<PairHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await () async {
        final req = await client.openUrl(method, url);
        req.followRedirects = false;
        headers.forEach(req.headers.set);
        final res = await req.close();
        final bytes = <int>[];
        await for (final chunk in res) {
          bytes.addAll(chunk);
          if (bytes.length > _maxBytes) {
            throw const PairingException(PairingErrorCode.unavailable);
          }
        }
        final h = <String, String>{};
        res.headers.forEach((k, v) => h[k.toLowerCase()] = v.join(','));
        return PairHttpResponse(
          res.statusCode,
          utf8.decode(bytes, allowMalformed: true),
          h,
        );
      }().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }
}

/// Client de l'appairage mobile : la télé crée un code, le téléphone y dépose
/// un texte (URL d'addon…), la télé l'interroge jusqu'à réception.
class PairingClient {
  PairingClient(
    String backendUrl, {
    PairHttp http = const IoPairHttp(),
    this.pollInterval = const Duration(seconds: 2),
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : baseUrl = _parseBase(backendUrl),
       _http = http,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  final Uri baseUrl;
  final Duration pollInterval;
  final PairHttp _http;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  static const _maxTransientErrors = 5;

  /// https obligatoire, sauf http vers localhost (développement).
  static Uri _parseBase(String raw) {
    final u = Uri.tryParse(raw.trim());
    final local =
        u != null &&
        (u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1');
    if (u == null ||
        u.host.isEmpty ||
        u.hasQuery ||
        u.userInfo.isNotEmpty ||
        !(u.scheme == 'https' || (u.scheme == 'http' && local))) {
      throw const PairingException(PairingErrorCode.insecureUrl);
    }
    return u.replace(path: u.path.replaceAll(RegExp(r'/+$'), ''));
  }

  Uri _url(String path) => baseUrl.replace(path: '${baseUrl.path}$path');

  /// Adresse encodée dans le QR : page compagnon du téléphone.
  Uri companionUrl(String code) => _url('/p/$code');

  Future<PairSession> create() async {
    final started = _now();
    final PairHttpResponse res;
    try {
      res = await _http.send('POST', _url('/pair'));
    } catch (_) {
      throw const PairingException(PairingErrorCode.unavailable);
    }
    if (res.status == 429) {
      throw const PairingException(PairingErrorCode.rateLimited);
    }
    if (res.status != 201 && res.status != 200) {
      throw const PairingException(PairingErrorCode.unavailable);
    }
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final code = j['code'] as String;
      final token = j['pollToken'] as String;
      final ttl = (j['expiresIn'] as num).toInt();
      if (!RegExp(r'^[A-Z2-9]{6}$').hasMatch(code) || token.isEmpty) {
        throw const FormatException('code');
      }
      return PairSession(
        code: code,
        pollToken: token,
        expiresAt: started.add(Duration(seconds: ttl)),
      );
    } catch (_) {
      throw const PairingException(PairingErrorCode.unavailable);
    }
  }

  /// Émet le texte envoyé par le téléphone, puis se termine. Annuler
  /// l'abonnement arrête l'interrogation. Erreur [PairingException] si le code
  /// expire (ou est refusé) ou si le serveur reste injoignable.
  Stream<String> waitPayload(PairSession s) {
    // `async*` ne verrait l'annulation qu'au prochain `yield` : on pilote
    // l'interrogation nous-mêmes pour l'arrêter aussitôt.
    var cancelled = false;
    late final StreamController<String> out;
    out = StreamController<String>(
      onListen: () => unawaited(
        _poll(s, out, () => cancelled)
            .catchError((Object e, StackTrace st) {
              if (!cancelled && !out.isClosed) out.addError(e, st);
            })
            .whenComplete(() {
              if (!out.isClosed) unawaited(out.close());
            }),
      ),
      onCancel: () => cancelled = true,
    );
    return out.stream;
  }

  Future<void> _poll(
    PairSession s,
    StreamController<String> out,
    bool Function() cancelled,
  ) async {
    var failures = 0;
    while (!cancelled()) {
      if (!_now().isBefore(s.expiresAt)) {
        throw const PairingException(PairingErrorCode.expired);
      }
      PairHttpResponse? res;
      try {
        res = await _http.send(
          'GET',
          _url('/pair/${s.code}'),
          headers: {'Authorization': 'Bearer ${s.pollToken}'},
        );
        failures = 0;
      } catch (_) {
        if (++failures >= _maxTransientErrors) {
          throw const PairingException(PairingErrorCode.unavailable);
        }
      }
      if (cancelled()) return;
      if (res != null) {
        switch (res.status) {
          case 200:
            final payload = _parsePayload(res.body);
            if (payload == null) {
              throw const PairingException(PairingErrorCode.unavailable);
            }
            out.add(payload);
            return;
          case 204:
            break;
          case 404:
          case 410:
            throw const PairingException(PairingErrorCode.expired);
          case 429:
            final wait = int.tryParse(res.headers['retry-after'] ?? '');
            await _delay(
              wait == null
                  ? pollInterval
                  : Duration(seconds: wait.clamp(1, 60)),
            );
            continue;
          default:
            if (++failures >= _maxTransientErrors) {
              throw const PairingException(PairingErrorCode.unavailable);
            }
        }
      }
      await _delay(pollInterval);
    }
  }

  static String? _parsePayload(String body) {
    try {
      final p = (jsonDecode(body) as Map<String, dynamic>)['payload'];
      return p is String && p.trim().isNotEmpty ? p.trim() : null;
    } catch (_) {
      return null;
    }
  }
}
