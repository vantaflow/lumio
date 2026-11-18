import '../torrent/magnet.dart';
import '../util/redact.dart';
import 'stream_item.dart';

/// Transforme un objet flux brut d'addon en [StreamItem].
class StreamNormalizer {
  /// Renvoie `null` si le flux est inutilisable. Chaque rejet est signalé à
  /// [onReject] (message sans URL en clair : `redactUrl`).
  static StreamItem? normalize(
    Map<String, dynamic> raw,
    String addonId, {
    void Function(String message)? onReject,
  }) {
    void reject(String why) => onReject?.call('Flux rejeté ($addonId) : $why');

    final rawUrl = raw['url'];
    Uri? url;
    if (rawUrl is String && rawUrl.trim().isNotEmpty) {
      final u = Uri.tryParse(rawUrl.trim());
      if (u != null &&
          u.host.isNotEmpty &&
          (u.scheme == 'http' || u.scheme == 'https')) {
        url = u;
      } else {
        reject('schéma d\'URL refusé ${redactUrl(rawUrl)}');
      }
    }

    String? infoHash;
    final rawHash = raw['infoHash'];
    if (rawHash is String && rawHash.trim().isNotEmpty) {
      final h = rawHash.trim();
      if (isInfoHash(h)) {
        infoHash = h.toLowerCase();
      } else {
        reject('infoHash invalide');
      }
    }

    if (url == null && infoHash == null) {
      reject(
        raw['ytId'] != null || raw['externalUrl'] != null
            ? 'flux externe (ytId/externalUrl) non pris en charge'
            : 'ni url ni infoHash exploitable',
      );
      return null;
    }

    final name = _str(raw['name']);
    final title = _str(raw['title']);
    final description = _str(raw['description']);
    final texts = [name, title, description].whereType<String>().toList();
    final all = texts.join('\n');

    var quality = Quality.unknown;
    for (final t in texts) {
      final q = _quality(t);
      if (q != Quality.unknown) {
        quality = q;
        break;
      }
    }

    final hints = raw['behaviorHints'];
    final headers = <String, String>{};
    var notWebReady = false;
    if (hints is Map) {
      notWebReady = hints['notWebReady'] == true;
      final ph = hints['proxyHeaders'];
      final req = ph is Map ? ph['request'] : null;
      if (req is Map) {
        req.forEach((k, v) {
          if (v != null) headers[k.toString()] = v.toString();
        });
      }
    }

    final idx = raw['fileIdx'];
    return StreamItem(
      addonId: addonId,
      title: title ?? description ?? name ?? '',
      url: url,
      infoHash: infoHash,
      fileIdx: idx is num ? idx.toInt() : null,
      quality: quality,
      language: _language(all),
      sizeBytes: _size(all),
      seeders: _seeders(all),
      requestHeaders: headers,
      notWebReady: notWebReady,
    );
  }

  static String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static final _q2160 = RegExp(r'(2160p|\b4k\b|\buhd\b)', caseSensitive: false);
  static final _q1080 = RegExp(r'(1080[pi])', caseSensitive: false);
  static final _q720 = RegExp(r'(720p)', caseSensitive: false);
  static final _q480 = RegExp(r'(480p|\bsd\b)', caseSensitive: false);

  static Quality _quality(String t) {
    if (_q2160.hasMatch(t)) return Quality.uhd2160;
    if (_q1080.hasMatch(t)) return Quality.hd1080;
    if (_q720.hasMatch(t)) return Quality.hd720;
    if (_q480.hasMatch(t)) return Quality.sd;
    return Quality.unknown;
  }

  static final _sizeRe = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(GiB|GB|Go|MiB|MB|Mo)\b',
    caseSensitive: false,
  );

  static int? _size(String t) {
    final m = _sizeRe.firstMatch(t);
    if (m == null) return null;
    final n = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (n == null) return null;
    final unit = m.group(2)!.toLowerCase();
    final mult = unit.startsWith('g') ? 1073741824 : 1048576;
    return (n * mult).toInt();
  }

  static final _seedRe = RegExp(
    r'(?:👤\s*(\d+))|(?:seeders?\s*[:=]?\s*(\d+))',
    caseSensitive: false,
  );

  static int? _seeders(String t) {
    final m = _seedRe.firstMatch(t);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? m.group(2)!);
  }

  static final _langRules = <(RegExp, String)>[
    (RegExp(r'\bmulti\b', caseSensitive: false), 'multi'),
    (
      RegExp(
        '🇫🇷|\\b(french|francais|français|vff|vfq|vfi|vf|vostfr|truefrench)\\b',
        caseSensitive: false,
      ),
      'fr',
    ),
    (RegExp('🇬🇧|🇺🇸|\\b(english|eng|vo)\\b', caseSensitive: false), 'en'),
    (
      RegExp(
        '🇪🇸|\\b(spanish|espanol|español|esp|castellano)\\b',
        caseSensitive: false,
      ),
      'es',
    ),
    (RegExp('🇩🇪|\\b(german|deutsch|ger)\\b', caseSensitive: false), 'de'),
    (RegExp('🇮🇹|\\b(italian|italiano|ita)\\b', caseSensitive: false), 'it'),
    (
      RegExp(
        '🇵🇹|🇧🇷|\\b(portuguese|portugues|por)\\b',
        caseSensitive: false,
      ),
      'pt',
    ),
    (RegExp('🇷🇺|\\b(russian|rus)\\b', caseSensitive: false), 'ru'),
  ];

  static String? _language(String t) {
    for (final (re, code) in _langRules) {
      if (re.hasMatch(t)) return code;
    }
    return null;
  }
}
