import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/theme.dart';

Color _hex(String h) =>
    Color(0xFF000000 | int.parse(h.substring(1), radix: 16));

void main() {
  final tokens =
      jsonDecode(File('../docs/design/tokens.json').readAsStringSync())
          as Map<String, dynamic>;

  void check(String mode, LumioColors c) {
    final t = (tokens['color'] as Map)[mode] as Map;
    final actual = {
      'bg': c.bg,
      'bgAlt': c.bgAlt,
      'surface': c.surface,
      'surfaceRaised': c.surfaceRaised,
      'surfaceFocus': c.surfaceFocus,
      'outline': c.outline,
      'text': c.text,
      'textMuted': c.textMuted,
      'accent': c.accent,
      'onAccent': c.onAccent,
      'secondary': c.secondary,
      'focusRing': c.focusRing,
      'success': c.success,
      'warning': c.warning,
      'error': c.error,
    };
    expect(actual.keys.toSet(), t.keys.toSet(), reason: mode);
    for (final e in actual.entries) {
      expect(e.value, _hex(t[e.key] as String), reason: '$mode.${e.key}');
    }
  }

  test('couleurs sombres = tokens.json', () => check('dark', LumioColors.dark));
  test(
    'couleurs claires = tokens.json',
    () => check('light', LumioColors.light),
  );

  test('espacements et rayons = tokens.json', () {
    final sp = tokens['spacing'] as Map;
    expect(LumioSpacing.xs, sp['xs']);
    expect(LumioSpacing.sm, sp['sm']);
    expect(LumioSpacing.md, sp['md']);
    expect(LumioSpacing.lg, sp['lg']);
    expect(LumioSpacing.xl, sp['xl']);
    expect(LumioSpacing.xxl, sp['xxl']);
    final r = tokens['radius'] as Map;
    expect(LumioRadius.sm, r['sm']);
    expect(LumioRadius.md, r['md']);
    expect(LumioRadius.lg, r['lg']);
    expect(LumioRadius.xl, r['xl']);
    expect((tokens['focusRing'] as Map)['width'], lumioFocusWidth);
  });
}
