import 'dart:async';

/// Codecs vidéo dont le décodeur matériel (MediaCodec) est fiable sur les box
/// Android TV. Les autres (MPEG-4 Part 2 Xvid/DivX, MS-MPEG4, H.263, VC-1,
/// WMV…) passent en décodage logiciel : MediaCodec y est capricieux (PTS
/// manquants, B-frames packées → aucune image) et ces codecs sont légers à
/// décoder sur le processeur.
const androidHwdecCodecs =
    'h264,hevc,vp8,vp9,av1,mpeg2video'; // option mpv `hwdec-codecs`

/// Surveille un décodage matériel qui ne sort aucune image alors que des
/// données arrivent, et demande alors le basculement en décodage logiciel.
///
/// Logique pure (lecture des propriétés et bascule injectées) pour être
/// testée sans moteur : [check] est appelée périodiquement par le lecteur.
class HwDecodeGuard {
  HwDecodeGuard({
    required this.readProp,
    required this.onFallback,
    this.minWait = const Duration(seconds: 5),
    this.dataAhead = const Duration(seconds: 2),
    this.confirmations = 2,
  });

  /// Lit une propriété libmpv (chaîne vide si absente).
  final Future<String> Function(String name) readProp;

  /// Bascule en décodage logiciel à [position].
  final Future<void> Function(Duration position) onFallback;

  /// Délai minimal depuis l'ouverture avant tout verdict.
  final Duration minWait;

  /// Données mises en tampon au-delà de la position pour conclure que la
  /// source répond (sinon c'est le réseau, pas le décodeur).
  final Duration dataAhead;

  /// Nombre de contrôles consécutifs défavorables avant de basculer.
  final int confirmations;

  int _bad = 0;
  bool _done = false;

  /// Vrai une fois la bascule demandée ou le décodage jugé sain.
  bool get finished => _done;

  /// Remet à zéro pour une nouvelle ouverture.
  void reset() {
    _bad = 0;
    _done = false;
  }

  /// Un contrôle ; retourne vrai si la bascule a été demandée.
  Future<bool> check({
    required Duration elapsed,
    required Duration position,
    required Duration start,
    required Duration buffered,
  }) async {
    if (_done || elapsed < minWait) return false;
    // L'image avance : tout va bien.
    if (position > start + const Duration(milliseconds: 500)) {
      _done = true;
      return false;
    }
    final hw = (await readProp('hwdec-current')).trim();
    if (hw.isEmpty || hw == 'no') {
      _bad = 0; // décodage logiciel (ou décodeur pas encore choisi)
      return false;
    }
    final fps = double.tryParse((await readProp('estimated-vf-fps')).trim());
    if (fps != null && fps > 0) {
      _done = true; // des images sortent
      return false;
    }
    if (buffered - position < dataAhead) {
      _bad = 0; // peu de données : on attend la source, pas le décodeur
      return false;
    }
    if (++_bad < confirmations) return false;
    _done = true;
    await onFallback(position);
    return true;
  }
}
