import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio_core/lumio_core.dart';

StreamItem _t(String addon, String h, {int? idx}) =>
    StreamItem(addonId: addon, title: h, infoHash: h * 40, fileIdx: idx);

void main() {
  final a = _t('s1', 'a');
  final b = _t('s2', 'b', idx: 1);
  final bOther = _t('s1', 'b', idx: 1);

  test('aucune identité : aucun choix', () {
    expect(findSavedStream([a, b], addonId: null, key: null), isNull);
  });

  test('même addon et même source : retrouvé', () {
    expect(findSavedStream([a, b], addonId: 's2', key: b.identityKey), same(b));
  });

  test(
    'même source chez un autre addon (réinstallé) : repris, l\'addon d\'origine d\'abord',
    () {
      expect(
        findSavedStream([bOther, b], addonId: 's2', key: b.identityKey),
        same(b),
      );
      expect(
        findSavedStream([bOther], addonId: 's2', key: b.identityKey),
        same(bOther),
      );
    },
  );

  test('fileIdx différent : autre fichier du même torrent, pas retrouvé', () {
    final other = _t('s2', 'b', idx: 2);
    expect(findSavedStream([other], addonId: 's2', key: b.identityKey), isNull);
  });

  test('flux absent : null', () {
    expect(findSavedStream([a], addonId: 's2', key: b.identityKey), isNull);
  });
}
