import 'dart:io';

import 'package:media_kit/media_kit.dart' show MPVLogLevel;
import 'package:path_provider/path_provider.dart';

/// Réglages avancés de libmpv lus dans `mpv.conf` du dossier de fichiers de
/// l'application (`Android/data/<paquet>/files/mpv.conf`, déposé à la main ou
/// par adb) : une ligne `clé=valeur`, `#` pour un commentaire. Sert à régler
/// le décodage sur une box précise sans refaire un APK. Liste blanche : rien
/// d'autre que le rendu et le décodage n'est accepté (jamais de script,
/// d'entrée réseau ni de chemin).
const mpvOverrideKeys = {
  'hwdec',
  'hwdec-codecs',
  'vd-lavc-threads',
  'vd-lavc-dr',
  'vd-lavc-fast',
  'vd-lavc-skiploopfilter',
  'video-sync',
  'framedrop',
  'interpolation',
  'vo',
  'gpu-api',
  'gpu-context',
  'cache-secs',
  'demuxer-max-bytes',
  'demuxer-readahead-secs',
  'audio-buffer',
  'video-latency-hacks',
  'opengl-es',
  'log-level',
  'demuxer-lavf-probesize',
  'demuxer-lavf-analyzeduration',
  'demuxer-lavf-probe-info',
  'cache',
  'cache-pause-initial',
};

Map<String, String> parseMpvConf(String text) {
  final out = <String, String>{};
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final i = line.indexOf('=');
    if (i <= 0) continue;
    final k = line.substring(0, i).trim();
    final v = line.substring(i + 1).trim();
    if (!mpvOverrideKeys.contains(k) || v.isEmpty || v.length > 64) continue;
    if (!RegExp(r'^[A-Za-z0-9_.,:+\-]+$').hasMatch(v)) continue;
    out[k] = v;
  }
  return out;
}

/// Valeurs lues au démarrage ([primeMpvOverrides]) : le contrôleur vidéo les
/// lit de façon synchrone à sa création.
Map<String, String> cachedMpvOverrides = const {};

Future<void> primeMpvOverrides() async {
  cachedMpvOverrides = await loadMpvOverrides();
}

/// Réglages qui vont dans la configuration du contrôleur vidéo (sortie et
/// décodage matériel), pas dans une propriété appliquée à l'ouverture.
const mpvControllerKeys = {'vo', 'hwdec', 'log-level'};

/// Niveau des journaux libmpv (clé `log-level` de `mpv.conf`) ; avertissements par défaut.
MPVLogLevel mpvLogLevelFor(Map<String, String> overrides) =>
    switch (overrides['log-level']) {
      'info' => MPVLogLevel.info,
      'v' => MPVLogLevel.v,
      'debug' => MPVLogLevel.debug,
      _ => MPVLogLevel.warn,
    };

Future<Map<String, String>> loadMpvOverrides() async {
  try {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return const {};
    final f = File('${dir.path}/mpv.conf');
    if (!await f.exists()) return const {};
    final s = await f.readAsString();
    return parseMpvConf(s.length > 4096 ? s.substring(0, 4096) : s);
  } on Object {
    return const {};
  }
}

/// Décodage matériel par défaut sur Android : `mediacodec` écrit directement
/// sur la surface de l'écran (sans copie). Mesuré sur la box 4K Google TV
/// (armeabi-v7a, 2 Go, 1080p H.264 24 i/s) : 0 image perdue sur 60 s, contre
/// ~11 par seconde avec `mediacodec-copy` (copie mémoire puis texture).
/// `mediacodec-copy` reste le repli si le décodeur direct refuse le flux.
const androidDefaultHwdec = 'mediacodec,mediacodec-copy';

/// Configuration (sortie, décodage matériel) du contrôleur vidéo : `mpv.conf`
/// l'emporte, puis la valeur par défaut de la plateforme (`null` = celle de
/// media_kit).
({String? vo, String? hwdec}) videoConfigFor({
  required bool android,
  Map<String, String> overrides = const {},
}) => (
  vo: overrides['vo'],
  hwdec: overrides['hwdec'] ?? (android ? androidDefaultHwdec : null),
);

/// Format du démultiplexeur à imposer à libmpv pour [source] : `hls` pour une
/// playlist `.m3u8`, sinon vide (détection automatique).
///
/// Mesuré sur la box : la playlist maître d'Apple (HEVC et fMP4) commence par
/// de longues lignes `#EXT-X-MEDIA` ; une fois les adresses réécrites par le
/// proxy local, `#EXT-X-STREAM-INF` dépasse la fenêtre de reconnaissance de
/// ffmpeg, qui la lit alors comme une simple liste de fichiers
/// (« Reading plaintext playlist ») et la lecture finit en « délai dépassé ».
String lavfFormatFor(Uri source) =>
    source.path.toLowerCase().endsWith('.m3u8') ? 'hls' : '';
