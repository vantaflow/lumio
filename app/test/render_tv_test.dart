// Rendu PNG des écrans TV à 1920x1080 pour comparer aux maquettes. Inactif
// sauf avec LUMIO_RENDER_DIR=<dossier> (sinon ignoré).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/jellyfin/jellyfin_screen.dart';
import 'package:lumio/features/local/local_screen.dart';
import 'package:lumio/features/settings/settings_screen.dart' show AboutScreen;
import 'package:lumio/features/onboarding/onboarding_flow.dart';
import 'package:lumio/features/settings/stremio_import_screen.dart';
import 'package:lumio/features/tracking/tracking_providers.dart';
import 'package:lumio/features/tracking/tracking_screen.dart';
import 'package:lumio/providers.dart';

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

  testWidgets('lot 4 : import, dossiers, suivi', skip: skip != null, (t) async {
    await t.runAsync(_fonts);
    final h = AppHarness(t);
    final key = GlobalKey();
    await h.pump(
      RepaintBoundary(key: key, child: const StremioImportScreen()),
    );
    await _save(t, key, 'r-TV32');
    await h.close();

    final h2 = AppHarness(t);
    final k2 = GlobalKey();
    await h2.pump(
      RepaintBoundary(key: k2, child: const LocalFoldersScreen()),
    );
    await _save(t, k2, 'r-TV49');
    await h2.close();

    final h3 = AppHarness(t);
    final k3 = GlobalKey();
    await h3.pump(
      RepaintBoundary(key: k3, child: const TrackingScreen()),
      extra: [
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        traktCredentialsProvider.overrideWithValue((id: 'c', secret: 's')),
        trackingStatusProvider.overrideWith(
          (ref, key) async => const TrackingStatus(
            configured: true,
            connected: true,
            reauthRequired: false,
            pending: 1,
            kidAllowed: false,
          ),
        ),
      ],
    );
    await _save(t, k3, 'r-TV25');
    await h3.close();

    final h4 = AppHarness(t);
    final k4 = GlobalKey();
    await h4.pump(
      RepaintBoundary(key: k4, child: const TrackingScreen()),
      extra: [
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        traktCredentialsProvider.overrideWithValue((id: '', secret: '')),
      ],
    );
    await _save(t, k4, 'r-TV48');
    await h4.close();
    final h5 = AppHarness(t);
    final k5 = GlobalKey();
    await h5.pump(RepaintBoundary(key: k5, child: const AboutScreen()));
    await _save(t, k5, 'r-TV34');
    await h5.close();

    final h6 = AppHarness(t);
    final k6 = GlobalKey();
    await h6.pump(
      RepaintBoundary(key: k6, child: const JellyfinServersScreen()),
    );
    await _save(t, k6, 'r-TV50');
    await h6.close();
  });
}
