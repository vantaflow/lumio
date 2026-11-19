import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/subtitle_style.dart';

void main() {
  test('la taille choisie change la police affichée (rendu Flutter)', () {
    double fs(SubtitleSize s) =>
        SubtitleStyle(size: s).viewConfiguration().style.fontSize!;
    expect(fs(SubtitleSize.m), 32);
    expect(fs(SubtitleSize.s), lessThan(fs(SubtitleSize.m)));
    expect(fs(SubtitleSize.l), greaterThan(fs(SubtitleSize.m)));
    expect(fs(SubtitleSize.xl), greaterThan(fs(SubtitleSize.l)));
  });

  test('fond opaque : fond noir plein ; sinon pas de fond', () {
    final on = const SubtitleStyle(opaqueBackground: true).viewConfiguration();
    final off = const SubtitleStyle().viewConfiguration();
    expect(on.style.backgroundColor, const Color(0xFF000000));
    expect(off.style.backgroundColor, isNull);
    expect(off.style.shadows, isNotEmpty);
  });
}
