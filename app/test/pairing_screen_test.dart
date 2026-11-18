import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/pairing_client.dart';
import 'package:lumio/features/pairing/pairing_screen.dart';
import 'package:lumio/features/addons/add_addon_dialog.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _FakeClient extends PairingClient {
  _FakeClient(this.stream) : super('https://api.example');
  final Stream<String> stream;
  int created = 0;

  @override
  Future<PairSession> create() async {
    created++;
    return PairSession(
      code: 'KR74PQ',
      pollToken: 't',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Stream<String> waitPayload(PairSession s) => stream;
}

Widget _app(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: LumioTheme.dark(), home: child),
    );

void main() {
  testWidgets('affiche code groupé et QR puis renvoie le payload', (t) async {
    final ctrl = StreamController<String>();
    final client = _FakeClient(ctrl.stream);
    String? result;
    await t.pumpWidget(
      _app(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => result = await Navigator.of(ctx).push(
              MaterialPageRoute<String>(
                builder: (_) => PairingScreen(client: client),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('KR7-4PQ'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    ctrl.add('https://x.example/manifest.json');
    await t.pumpAndSettle();
    expect(result, 'https://x.example/manifest.json');
  });

  testWidgets('expiration : propose un nouveau code', (t) async {
    final ctrl = StreamController<String>();
    final client = _FakeClient(ctrl.stream);
    await t.pumpWidget(_app(PairingScreen(client: client)));
    await t.pump();
    ctrl.addError(const PairingException(PairingErrorCode.expired));
    await t.pump();
    expect(find.text('Ce code a expiré.'), findsOneWidget);
    expect(find.text('Nouveau code'), findsOneWidget);
    await t.tap(find.text('Nouveau code'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
    expect(client.created, 2);
  });

  testWidgets("bouton d'appairage masqué sans backend", (t) async {
    await t.pumpWidget(
      _app(
        const AddAddonDialog(),
        overrides: [pairingClientProvider.overrideWithValue(null)],
      ),
    );
    expect(find.text('Saisir depuis mon téléphone'), findsNothing);
    expect(find.text('Coller'), findsOneWidget);
  });

  testWidgets("bouton d'appairage visible avec backend", (t) async {
    await t.pumpWidget(
      _app(
        const AddAddonDialog(),
        overrides: [
          pairingClientProvider.overrideWithValue(
            PairingClient('https://api.example'),
          ),
        ],
      ),
    );
    expect(find.text('Saisir depuis mon téléphone'), findsOneWidget);
  });
}
