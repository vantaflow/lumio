import 'dart:convert';

import 'package:xml/xml.dart';

import '../net/http_fetcher.dart';
import 'ssdp.dart';

/// Échec d'une commande DLNA (réponse inattendue, XML refusé).
class DlnaException implements Exception {
  const DlnaException(this.message);
  final String message;

  @override
  String toString() => 'DlnaException: $message';
}

/// Défaut SOAP renvoyé par l'appareil (ex. 701 « Transition not available »,
/// 714 « Illegal MIME-type », 716 « Resource not found »).
class SoapFaultException extends DlnaException {
  const SoapFaultException(this.code, this.description)
    : super('défaut SOAP $code');
  final int code;
  final String description;

  @override
  String toString() => 'SoapFaultException: $code $description';
}

/// Commandes d'un lecteur distant (abstrait pour les tests de session).
abstract class CastRenderer {
  Future<void> setUri(Uri media, String title);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<Duration> position();
}

const _didlNs = 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/';

String _esc(String s) => s
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Métadonnées DIDL-Lite d'une vidéo (non échappées pour l'enveloppe : le
/// titre et l'URL le sont ici, l'ensemble l'est une seconde fois dans
/// `CurrentURIMetaData`).
String buildDidl(Uri media, String title) =>
    '<DIDL-Lite xmlns="$_didlNs" xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
    '<item id="0" parentID="-1" restricted="1">'
    '<dc:title>${_esc(title)}</dc:title>'
    '<upnp:class>object.item.videoItem</upnp:class>'
    '<res protocolInfo="http-get:*:video/mp4:*">${_esc(media.toString())}</res>'
    '</item></DIDL-Lite>';

/// Enveloppe SOAP d'une [action] AVTransport ; [args] dans l'ordre, valeurs
/// échappées.
String buildSoapEnvelope(
  String serviceType,
  String action,
  List<MapEntry<String, String>> args,
) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="utf-8"?>')
    ..write(
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">',
    )
    ..write('<s:Body><u:$action xmlns:u="$serviceType">');
  for (final a in args) {
    b.write('<${a.key}>${_esc(a.value)}</${a.key}>');
  }
  b.write('</u:$action></s:Body></s:Envelope>');
  return b.toString();
}

String _clock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:'
      '${two(d.inSeconds.remainder(60))}';
}

/// Lit `H:MM:SS[.mmm]` ; `NOT_IMPLEMENTED` et illisible valent zéro.
Duration parseRelTime(String s) {
  final m = RegExp(
    r'^\+?(\d+):(\d{2}):(\d{2})(?:\.(\d{1,3}))?',
  ).firstMatch(s.trim());
  if (m == null) return Duration.zero;
  return Duration(
    hours: int.parse(m[1]!),
    minutes: int.parse(m[2]!),
    seconds: int.parse(m[3]!),
    milliseconds: m[4] == null ? 0 : int.parse(m[4]!.padRight(3, '0')),
  );
}

/// Pilote un lecteur DLNA par SOAP AVTransport.
///
/// Les requêtes ne partent que vers l'hôte de l'appareil découvert ; les
/// redirections ne sont pas suivies (POST) ; réponses limitées à 256 Ko et
/// refusées si elles déclarent un DOCTYPE ou une entité.
class DlnaRenderer implements CastRenderer {
  DlnaRenderer(this.device, {HttpPostFetcher? fetcher})
    : _fetcher = fetcher ?? IoHttpFetcher() {
    if (device.controlUrl.host != device.address.address ||
        (device.controlUrl.scheme != 'http' &&
            device.controlUrl.scheme != 'https')) {
      throw ArgumentError('controlUrl hors de l\'hôte de l\'appareil');
    }
  }

  final CastDevice device;
  final HttpPostFetcher _fetcher;

  void _guard(Uri u) {
    if (u.host != device.address.address) {
      throw const DlnaException('hôte inattendu');
    }
  }

  Future<XmlDocument> _call(
    String action,
    List<MapEntry<String, String>> args,
  ) async {
    final body = utf8.encode(
      buildSoapEnvelope(device.serviceType, action, [
        const MapEntry('InstanceID', '0'),
        ...args,
      ]),
    );
    final res = await _fetcher.post(
      device.controlUrl,
      body: body,
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPACTION': '"${device.serviceType}#$action"',
      },
      maxBytes: maxDeviceDescriptionBytes,
      timeout: const Duration(seconds: 5),
      guard: _guard,
    );
    final XmlDocument doc;
    try {
      final text = utf8.decode(res.body, allowMalformed: true);
      rejectDangerousXml(text);
      doc = XmlDocument.parse(text);
    } on FormatException catch (e) {
      throw DlnaException(e.message);
    } on XmlException {
      if (res.status >= 200 && res.status < 300) {
        throw const DlnaException('réponse illisible');
      }
      throw DlnaException('HTTP ${res.status}');
    }
    if (res.status >= 200 && res.status < 300) return doc;
    final code = _text(doc, 'errorCode');
    if (code != null && int.tryParse(code) != null) {
      throw SoapFaultException(
        int.parse(code),
        _text(doc, 'errorDescription') ?? '',
      );
    }
    throw DlnaException('HTTP ${res.status}');
  }

  static String? _text(XmlNode n, String local) {
    for (final e in n.descendants.whereType<XmlElement>()) {
      if (e.name.local == local) return e.innerText.trim();
    }
    return null;
  }

  @override
  Future<void> setUri(Uri media, String title) async {
    await _call('SetAVTransportURI', [
      MapEntry('CurrentURI', media.toString()),
      MapEntry('CurrentURIMetaData', buildDidl(media, title)),
    ]);
  }

  @override
  Future<void> play() async {
    await _call('Play', const [MapEntry('Speed', '1')]);
  }

  @override
  Future<void> pause() async {
    await _call('Pause', const []);
  }

  @override
  Future<void> stop() async {
    await _call('Stop', const []);
  }

  @override
  Future<void> seek(Duration position) async {
    await _call('Seek', [
      const MapEntry('Unit', 'REL_TIME'),
      MapEntry('Target', _clock(position)),
    ]);
  }

  @override
  Future<Duration> position() async {
    final doc = await _call('GetPositionInfo', const []);
    return parseRelTime(_text(doc, 'RelTime') ?? '');
  }
}
