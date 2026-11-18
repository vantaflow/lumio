import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/title_settings_store.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/features/addons/addons_screen.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_panel.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio_core/lumio_core.dart';

import 'player_panel_test.dart' show Backend, FakeCtl;
import 'support/app_harness.dart';

void main() {
  testWidgets('lecteur : Retour système ferme d\'abord le panneau des pistes, '
      'puis quitte la lecture', (t) async {
    final h = AppHarness(t);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await h.pump(
      const Scaffold(body: Text('RACINE')),
      extra: [
        titleSettingsStoreProvider.overrideWith(
          (ref) async => DriftTitleSettingsStore(db),
        ),
        subtitleStyleStoreProvider.overrideWithValue(SubtitleStyleStore(db)),
      ],
    );
    unawaited(
      Navigator.of(t.element(find.text('RACINE'))).push(
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(
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
        ),
      ),
    );
    await h.settle();
    final button = find.bySemanticsLabel('Pistes et sous-titres');
    for (var i = 0; i < 20 && button.evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.byType(TracksPanel), findsOneWidget);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(TracksPanel), findsNothing);
    expect(find.byType(PlayerScreen), findsOneWidget);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsNothing);
    expect(find.text('RACINE'), findsOneWidget);
    await h.close();
  });

  testWidgets('addons : action principale focalisée d\'emblée', (t) async {
    final h = AppHarness(t);
    await h.pump(const AddonsScreen());
    final f = FocusManager.instance.primaryFocus!;
    expect(f.context!.findAncestorWidgetOfExactType<FilledButton>(), isNotNull);
    await h.close();
  });

  testWidgets('addons : la mémoire du focus rend le focus à l\'addon', (
    t,
  ) async {
    final h = AppHarness(t);
    await h.pump(
      const AddonsScreen(),
      extra: [
        focusMemoryProvider.overrideWith(_Mem.new),
        addonsProvider.overrideWith(_TwoAddons.new),
      ],
    );
    final f = FocusManager.instance.primaryFocus!;
    expect(f.context!.findAncestorWidgetOfExactType<FilledButton>(), isNull);
    expect(f.context!.findAncestorWidgetOfExactType<Switch>(), isNotNull);
    // Le focus est dans la tuile du second addon, pas du premier.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('second')),
        matching: find.byWidgetPredicate((w) => w is Switch),
      ),
      findsOneWidget,
    );
    final tileOfFocus = f.context!.findAncestorWidgetOfExactType<Card>()!;
    expect(
      find.descendant(
        of: find.byWidget(tileOfFocus),
        matching: find.text('Addon second'),
      ),
      findsOneWidget,
    );
    await h.close();
  });

  testWidgets('sélecteur de profil : premier profil focalisé sans mémoire', (
    t,
  ) async {
    final h = AppHarness(t);
    await h.pump(const ProfilePickerScreen());
    final f = FocusManager.instance.primaryFocus!;
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-default')),
        matching: find.byWidgetPredicate((w) => w is Focus),
      ),
      findsWidgets,
    );
    expect(f.hasPrimaryFocus, isTrue);
    await h.close();
  });
}

class _Mem extends FocusMemory {
  @override
  Map<String, Map<String, String>> build() => {
    addonsRouteKey: {'': 'second'},
  };
}

class _TwoAddons extends AddonsController {
  @override
  Future<List<InstalledAddon>> build() async => [
    for (final id in ['first', 'second'])
      InstalledAddon(
        id: id,
        manifest: AddonManifest(
          id: id,
          version: '1.0.0',
          name: 'Addon $id',
          types: const ['movie'],
          resources: const [AddonResource('catalog')],
          catalogs: const [],
          transportUrl: Uri.parse('https://$id.example.com/manifest.json'),
        ),
        position: id == 'first' ? 0 : 1,
        enabled: true,
      ),
  ];
}
