import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/title_settings_store.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/features/onboarding/onboarding_flow.dart';
import 'package:lumio/features/search/search_screen.dart';
import 'package:lumio/features/settings/settings_screen.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

import 'player_panel_test.dart' show Backend, FakeCtl;
import 'support/app_harness.dart';

Future<void> _guidelines(WidgetTester t) async {
  await expectLater(t, meetsGuideline(textContrastGuideline));
  await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(t, meetsGuideline(androidTapTargetGuideline));
}

const _sizes = {
  'TV 1920x1080': (Size(1920, 1080), true),
  'téléphone 400x800': (Size(400, 800), false),
};

void main() {
  for (final entry in _sizes.entries) {
    final (size, tv) = entry.value;
    group('accessibilité - ${entry.key}', () {
      testWidgets('accueil', (t) async {
        final sem = t.ensureSemantics();
        final h = AppHarness(t, size: size, tv: tv);
        await h.pump(const HomeScreen());
        expect(
          find.bySemanticsLabel(RegExp('Big Buck Bunny, 2008, ')),
          findsOneWidget,
        );
        await _guidelines(t);
        await h.close();
        sem.dispose();
      });

      testWidgets('fiche', (t) async {
        final sem = t.ensureSemantics();
        final h = AppHarness(t, size: size, tv: tv);
        await h.pump(DetailScreen(preview: fakeItems.first));
        await _guidelines(t);
        await h.close();
        sem.dispose();
      });

      testWidgets('réglages', (t) async {
        final sem = t.ensureSemantics();
        final h = AppHarness(t, size: size, tv: tv);
        await h.pump(const SettingsScreen());
        await _guidelines(t);
        await h.close();
        sem.dispose();
      });

      testWidgets('recherche', (t) async {
        final sem = t.ensureSemantics();
        final h = AppHarness(t, size: size, tv: tv);
        await h.pump(const SearchScreen());
        await _guidelines(t);
        await h.close();
        sem.dispose();
      });

      testWidgets('premier lancement', (t) async {
        final sem = t.ensureSemantics();
        final h = AppHarness(t, size: size, tv: tv);
        await h.pump(const OnboardingFlow());
        await _guidelines(t);
        await h.close();
        sem.dispose();
      });

      testWidgets('commandes du lecteur', (t) async {
        final sem = t.ensureSemantics();
        final h = AppHarness(t, size: size, tv: tv);
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await h.pump(
          PlayerScreen(
            item: StreamItem(
              addonId: 'ad',
              title: 'Film',
              url: Uri.parse('https://x.test/v.mp4'),
            ),
            metaId: 'tt1',
            controller: FakeCtl(),
            videoBuilder: (_) => const ColoredBox(color: Colors.black),
            tracksBackend: (_) => Backend(),
          ),
          extra: [
            titleSettingsStoreProvider.overrideWith(
              (ref) async => DriftTitleSettingsStore(db),
            ),
            subtitleStyleStoreProvider.overrideWithValue(
              SubtitleStyleStore(db),
            ),
          ],
        );
        await _guidelines(t);
        await h.close();
        sem.dispose();
      });
    });
  }
}
