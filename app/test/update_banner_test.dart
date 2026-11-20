import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/config.dart';
import 'package:lumio/features/update/update_banner.dart';
import 'package:lumio_core/lumio_core.dart';

class _Fetcher implements HttpFetcher {
  int calls = 0;

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    calls++;
    return FetchResponse(
      status: 200,
      body: utf8.encode(
        jsonEncode({
          'version': '2.0.0',
          'apk': 'https://example.org/lumio.apk',
          'sha256': 'a' * 64,
        }),
      ),
    );
  }
}

Widget _wrap(Widget banner) => MaterialApp(
  home: Scaffold(body: Column(children: [banner])),
);

void main() {
  testWidgets('désactivé (URL vide) : aucune bannière, aucun appel réseau', (
    tester,
  ) async {
    final f = _Fetcher();
    await tester.pumpWidget(
      _wrap(
        UpdateBanner(
          manifestUrl: '',
          fetcher: f,
          currentVersion: () async => '1.0.0',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
    expect(f.calls, 0);
  });

  testWidgets(
    'mise à jour disponible : bannière avec la version, ouvre l\'APK, fermable',
    (tester) async {
      Uri? opened;
      await tester.pumpWidget(
        _wrap(
          UpdateBanner(
            manifestUrl: 'https://example.org/update.json',
            fetcher: _Fetcher(),
            currentVersion: () async => '1.0.0',
            supportedAbis: () async => const [],
            openUrl: (u) async => opened = u,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('2.0.0'), findsOneWidget);

      await tester.tap(find.text('Télécharger'));
      expect(opened, Uri.parse('https://example.org/lumio.apk'));

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsNothing);
    },
  );

  testWidgets('déjà à jour : aucune bannière', (tester) async {
    final f = _Fetcher();
    await tester.pumpWidget(
      _wrap(
        UpdateBanner(
          manifestUrl: 'https://example.org/update.json',
          fetcher: f,
          currentVersion: () async => '2.0.0',
          supportedAbis: () async => const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(f.calls, 1);
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets(
    'manifeste multi-ABI : ouvre l\'APK de l\'architecture de la box',
    (tester) async {
      Uri? opened;
      await tester.pumpWidget(
        _wrap(
          UpdateBanner(
            manifestUrl: 'https://example.org/update.json',
            fetcher: _MultiFetcher(),
            currentVersion: () async => '1.0.0',
            supportedAbis: () async => ['armeabi-v7a'],
            openUrl: (u) async => opened = u,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Télécharger'));
      expect(opened, Uri.parse('https://example.org/lumio-armeabi-v7a.apk'));
    },
  );

  test('config : manifeste de mise à jour sur la dernière release GitHub', () {
    expect(
      updateManifestUrl,
      'https://github.com/vantaflow/lumio/releases/latest/download/update.json',
    );
  });
}

class _MultiFetcher implements HttpFetcher {
  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async => FetchResponse(
    status: 200,
    body: utf8.encode(
      jsonEncode({
        'version': '2.0.0',
        'apk': 'https://example.org/lumio-armeabi-v7a.apk',
        'sha256': 'a' * 64,
        'apks': {
          'arm64-v8a': {
            'apk': 'https://example.org/lumio-arm64-v8a.apk',
            'sha256': 'b' * 64,
          },
          'armeabi-v7a': {
            'apk': 'https://example.org/lumio-armeabi-v7a.apk',
            'sha256': 'a' * 64,
          },
        },
      }),
    ),
  );
}
