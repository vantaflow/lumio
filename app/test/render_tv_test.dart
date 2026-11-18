// Rendu PNG des écrans TV à 1920x1080 pour comparer aux maquettes. Inactif
// sauf avec LUMIO_RENDER_DIR=<dossier> (sinon ignoré).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/onboarding/onboarding_flow.dart';

import 'support/app_harness.dart';

final _dir = Platform.environment['LUMIO_RENDER_DIR'];

Future<void> _fonts() async {
  for (final (family, file) in const [
    ('Bricolage Grotesque', 'BricolageGrotesque-Variable.ttf'),
    ('Manrope', 'Manrope-Variable.ttf'),
  ]) {
    final loader = FontLoader(family)
      ..addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
        ),
      );
    await loader.load();
  }
}

Future<void> _save(WidgetTester t, GlobalKey key, String name) async {
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final skip = _dir == null ? 'LUMIO_RENDER_DIR non défini' : null;

  testWidgets('onboarding TV', skip: skip != null, (t) async {
    await t.runAsync(_fonts);
    final h = AppHarness(t);
    final key = GlobalKey();
    await h.pump(RepaintBoundary(key: key, child: const OnboardingFlow()));
    await _save(t, key, 'render-onboarding-1');
    await t.tap(find.byKey(const ValueKey('onboarding-next')));
    await h.settle();
    await _save(t, key, 'render-onboarding-2');
    await t.tap(find.byKey(const ValueKey('onboarding-next')));
    await h.settle();
    await _save(t, key, 'render-onboarding-3');
    await h.close();
  });
}
