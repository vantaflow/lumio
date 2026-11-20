import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/hw_decode_guard.dart';

void main() {
  late Map<String, String> props;
  late List<Duration> fallbacks;
  late HwDecodeGuard guard;

  setUp(() {
    props = {'hwdec-current': 'mediacodec', 'estimated-vf-fps': ''};
    fallbacks = [];
    guard = HwDecodeGuard(
      readProp: (k) async => props[k] ?? '',
      onFallback: (p) async => fallbacks.add(p),
    );
  });

  Future<bool> check({int secs = 6, int pos = 0, int buffered = 10}) =>
      guard.check(
        elapsed: Duration(seconds: secs),
        position: Duration(seconds: pos),
        buffered: Duration(seconds: buffered),
      );

  test('codecs matériels fiables : mpeg4 et msmpeg4 exclus', () {
    final l = androidHwdecCodecs.split(',');
    expect(l, containsAll(['h264', 'hevc', 'vp9', 'av1']));
    expect(l, isNot(contains('mpeg4')));
    expect(l.any((c) => c.startsWith('msmpeg4') || c == 'h263'), isFalse);
  });

  test('aucune image, données reçues : bascule après 2 contrôles', () async {
    expect(await check(secs: 6), isFalse);
    expect(await check(secs: 8, pos: 3), isTrue);
    expect(fallbacks, [const Duration(seconds: 3)]);
    expect(guard.finished, isTrue);
  });

  test('trop tôt : aucun verdict', () async {
    expect(await check(secs: 2), isFalse);
    expect(await check(secs: 4), isFalse);
    expect(fallbacks, isEmpty);
  });

  test('des images sortent : jamais de bascule', () async {
    props['estimated-vf-fps'] = '23.976';
    expect(await check(secs: 6), isFalse);
    expect(await check(secs: 9), isFalse);
    expect(fallbacks, isEmpty);
    expect(guard.finished, isTrue);
  });

  test('le son avance mais aucune image : bascule quand même', () async {
    expect(await check(secs: 6, pos: 4, buffered: 20), isFalse);
    expect(await check(secs: 8, pos: 6, buffered: 20), isTrue);
  });

  test('décodage déjà logiciel : rien à faire', () async {
    props['hwdec-current'] = 'no';
    expect(await check(secs: 6), isFalse);
    expect(await check(secs: 9), isFalse);
    expect(fallbacks, isEmpty);
  });

  test('peu de données (réseau lent) : pas de bascule', () async {
    expect(await check(secs: 6, buffered: 1), isFalse);
    expect(await check(secs: 9, buffered: 1), isFalse);
    expect(fallbacks, isEmpty);
  });

  test(
    'un contrôle sain entre deux défavorables remet le compte à zéro',
    () async {
      expect(await check(secs: 6), isFalse);
      expect(await check(secs: 8, buffered: 0), isFalse);
      expect(await check(secs: 10), isFalse);
      expect(fallbacks, isEmpty);
      expect(await check(secs: 12), isTrue);
    },
  );

  test('une seule bascule, reset pour une nouvelle ouverture', () async {
    await check(secs: 6);
    await check(secs: 8);
    expect(await check(secs: 10), isFalse);
    expect(fallbacks, hasLength(1));
    guard.reset();
    expect(guard.finished, isFalse);
  });
}
