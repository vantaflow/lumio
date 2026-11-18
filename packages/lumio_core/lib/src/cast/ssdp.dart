import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../net/http_fetcher.dart';

/// Cible de recherche SSDP : lecteurs multimédias UPnP/DLNA.
const ssdpRendererTarget = 'urn:schemas-upnp-org:device:MediaRenderer:1';

/// Taille maximale d'une description d'appareil (XML).
const maxDeviceDescriptionBytes = 256 * 1024;

const _ssdpGroup = '239.255.255.250';
const _ssdpPort = 1900;
const _maxDatagram = 4096;
const _maxDevices = 32;

/// Appareil de diffusion (lecteur DLNA) découvert sur le réseau local.
class CastDevice {
  const CastDevice({
    required this.usn,
    required this.friendlyName,
    required this.location,
    required this.address,
    required this.controlUrl,
    required this.serviceType,
  });

  final String usn;
  final String friendlyName;

  /// URL de la description (hôte = [address]).
  final Uri location;

  /// Adresse d'où l'appareil a répondu : seule autorisée à lui parler et à
  /// télécharger le média.
  final InternetAddress address;

  /// Point de contrôle SOAP du service AVTransport (même hôte que [address]).
  final Uri controlUrl;

  /// Type complet du service AVTransport (ex. `...:service:AVTransport:1`).
  final String serviceType;
}

/// Réponse SSDP analysée.
class SsdpResponse {
  const SsdpResponse({
    required this.location,
    required this.st,
    required this.usn,
  });
  final Uri location;
  final String st;
  final String usn;
}

/// Requête M-SEARCH pour [st].
String buildMSearch({String st = ssdpRendererTarget, int mx = 2}) =>
    'M-SEARCH * HTTP/1.1\r\n'
    'HOST: $_ssdpGroup:$_ssdpPort\r\n'
    'MAN: "ssdp:discover"\r\n'
    'MX: $mx\r\n'
    'ST: $st\r\n'
    '\r\n';

/// Analyse une réponse SSDP ; `null` si elle est invalide (statut ≠ 200,
/// `LOCATION` absent, illisible ou autre schéma que http/https).
SsdpResponse? parseSsdpResponse(String text) {
  if (text.length > _maxDatagram) return null;
  final lines = const LineSplitter().convert(text);
  if (lines.isEmpty) return null;
  final status = lines.first.trim().split(RegExp(r'\s+'));
  if (status.length < 2 ||
      !status[0].startsWith('HTTP/') ||
      status[1] != '200') {
    return null;
  }
  final h = <String, String>{};
  for (final l in lines.skip(1)) {
    final i = l.indexOf(':');
    if (i <= 0) continue;
    h.putIfAbsent(
      l.substring(0, i).trim().toLowerCase(),
      () => l.substring(i + 1).trim(),
    );
  }
  final raw = h['location'];
  if (raw == null || raw.isEmpty) return null;
  final Uri loc;
  try {
    loc = Uri.parse(raw);
  } on FormatException {
    return null;
  }
  if ((loc.scheme != 'http' && loc.scheme != 'https') || loc.host.isEmpty) {
    return null;
  }
  return SsdpResponse(location: loc, st: h['st'] ?? '', usn: h['usn'] ?? raw);
}

/// Résultat de l'analyse d'une description d'appareil.
class DeviceDescription {
  const DeviceDescription({
    required this.friendlyName,
    required this.controlUrl,
    required this.serviceType,
  });
  final String friendlyName;
  final Uri controlUrl;
  final String serviceType;
}

final _doctype = RegExp(r'<!\s*(doctype|entity)', caseSensitive: false);

/// Refuse tout document XML qui déclare un DOCTYPE ou une entité (XXE,
/// « milliard de rires ») avant même de l'analyser. Lève [FormatException].
void rejectDangerousXml(String text) {
  if (_doctype.hasMatch(text)) {
    throw const FormatException('DOCTYPE ou entité XML refusés');
  }
}

/// Analyse la description XML d'un appareil : nom et `controlURL` du service
/// AVTransport, résolu par rapport à [location] (ou `URLBase`) ; l'hôte du
/// contrôle doit rester celui de [location]. Lève [FormatException].
DeviceDescription parseDeviceDescription(List<int> body, Uri location) {
  if (body.length > maxDeviceDescriptionBytes) {
    throw const FormatException('description trop grande');
  }
  final text = utf8.decode(body, allowMalformed: true);
  rejectDangerousXml(text);
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(text);
  } on XmlException catch (e) {
    throw FormatException('XML illisible: ${e.message}');
  }
  String? textOf(XmlNode n, String name) {
    for (final e in n.descendants.whereType<XmlElement>()) {
      if (e.name.local == name) return e.innerText.trim();
    }
    return null;
  }

  var base = location;
  final urlBase = textOf(doc, 'URLBase');
  if (urlBase != null && urlBase.isNotEmpty) {
    final u = Uri.tryParse(urlBase);
    if (u != null && u.host == location.host) base = u;
  }
  for (final s in doc.descendants.whereType<XmlElement>()) {
    if (s.name.local != 'service') continue;
    final type = textOf(s, 'serviceType') ?? '';
    final ctl = textOf(s, 'controlURL');
    if (!type.contains(':service:AVTransport:') || ctl == null || ctl.isEmpty) {
      continue;
    }
    final Uri url;
    try {
      url = base.resolve(ctl);
    } on FormatException {
      continue;
    }
    if ((url.scheme != 'http' && url.scheme != 'https') ||
        url.host != location.host) {
      throw const FormatException('controlURL vers un autre hôte');
    }
    final name = textOf(doc, 'friendlyName');
    return DeviceDescription(
      friendlyName: (name == null || name.isEmpty) ? location.host : name,
      controlUrl: url,
      serviceType: type,
    );
  }
  throw const FormatException('service AVTransport absent');
}

/// Adresse de réseau local : privée, lien local (jamais publique).
bool isLanAddress(InternetAddress a, {bool allowLoopback = false}) {
  if (a.isLoopback) return allowLoopback;
  final b = a.rawAddress;
  if (b.length != 4) return false;
  if (b[0] == 10) return true;
  if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
  if (b[0] == 192 && b[1] == 168) return true;
  return b[0] == 169 && b[1] == 254;
}

/// Recherche des lecteurs DLNA par M-SEARCH SSDP pendant [timeout].
///
/// Sécurité : seule l'adresse d'où la réponse UDP est venue (réseau local
/// uniquement) peut être jointe ; le `LOCATION` doit désigner exactement cette
/// adresse, sinon la réponse est ignorée. La description est téléchargée par
/// [fetcher] (256 Ko au plus, redirections vers le même hôte seulement) et
/// refusée si elle contient un DOCTYPE ou une entité. Aucun appareil : flux
/// vide ; erreurs réseau (pas de multidiffusion) : flux vide également.
///
/// [target], [targetPort], [allowLoopback] sont réservés aux tests.
Stream<CastDevice> discover({
  Duration timeout = const Duration(seconds: 4),
  HttpFetcher? fetcher,
  InternetAddress? target,
  int targetPort = _ssdpPort,
  bool allowLoopback = false,
}) {
  final out = StreamController<CastDevice>();
  unawaited(
    _discover(
      out,
      timeout,
      fetcher ?? IoHttpFetcher(),
      target ?? InternetAddress(_ssdpGroup),
      targetPort,
      allowLoopback,
    ),
  );
  return out.stream;
}

Future<void> _discover(
  StreamController<CastDevice> out,
  Duration timeout,
  HttpFetcher fetcher,
  InternetAddress target,
  int targetPort,
  bool allowLoopback,
) async {
  RawDatagramSocket? socket;
  final pending = <Future<void>>[];
  final seen = <String>{};
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final s = socket;
    s.listen((e) {
      if (e != RawSocketEvent.read) return;
      final d = s.receive();
      if (d == null || out.isClosed) return;
      if (!isLanAddress(d.address, allowLoopback: allowLoopback)) return;
      final r = parseSsdpResponse(utf8.decode(d.data, allowMalformed: true));
      if (r == null || r.location.host != d.address.address) return;
      if (seen.length >= _maxDevices || !seen.add(r.usn)) return;
      pending.add(
        _describe(r, d.address, fetcher).then((dev) {
          if (dev != null && !out.isClosed) out.add(dev);
        }),
      );
    });
    final msg = utf8.encode(buildMSearch());
    s.send(msg, target, targetPort);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    s.send(msg, target, targetPort);
    await Future<void>.delayed(timeout);
  } on Object {
    // Pas de multidiffusion (réseau, droits) : aucun appareil.
  } finally {
    socket?.close();
    await Future.wait(pending);
    if (!out.isClosed) await out.close();
  }
}

Future<CastDevice?> _describe(
  SsdpResponse r,
  InternetAddress from,
  HttpFetcher fetcher,
) async {
  try {
    final res = await fetcher.get(
      r.location,
      maxBytes: maxDeviceDescriptionBytes,
      timeout: const Duration(seconds: 4),
      guard: (u) {
        if ((u.scheme != 'http' && u.scheme != 'https') ||
            u.host != from.address) {
          throw const FormatException('hôte de description inattendu');
        }
      },
    );
    if (res.status != 200) return null;
    final d = parseDeviceDescription(res.body, r.location);
    return CastDevice(
      usn: r.usn,
      friendlyName: d.friendlyName,
      location: r.location,
      address: from,
      controlUrl: d.controlUrl,
      serviceType: d.serviceType,
    );
  } on Object {
    return null;
  }
}
