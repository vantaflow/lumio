import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/playback_report.dart';
import 'package:lumio/player/player_controller.dart';
import 'package:lumio_core/lumio_core.dart';

void main() {
  group('explainFailure', () {
    test('403 cite le code', () {
      expect(explainFailure('x', httpStatus: 403), contains('403'));
      expect(
        explainFailure('x', httpStatus: 403),
        contains('La source a répondu'),
      );
    });
    test('un statut de succès (206, 200) n\'est jamais une erreur', () {
      for (final ok in [200, 206, 302]) {
        final m = explainFailure(TimeoutException('stall'), httpStatus: ok);
        expect(m, contains('Délai dépassé'));
        expect(m, isNot(contains('La source a répondu')));
      }
    });
    test('délai dépassé', () {
      expect(explainFailure(TimeoutException('t')), contains('Délai dépassé'));
      expect(
        explainFailure('tcp: Connection timed out'),
        contains('Délai dépassé'),
      );
    });
    test('format non pris en charge', () {
      expect(
        explainFailure('Failed to recognize file format.'),
        contains('Format non pris en charge'),
      );
    });
    test('code HTTP lu dans le message du moteur', () {
      expect(explainFailure('HTTP error 404 Not Found'), contains('404'));
    });
    test('réseau coupé', () {
      expect(
        explainFailure(const SocketException('Failed host lookup')),
        contains('réseau'),
      );
    });
    test('ne contient jamais d\'URL', () {
      final m = explainFailure(
        'Failed to open https://h.example/secret/token.m3u8 (HTTP error 500)',
      );
      expect(m, isNot(contains('http')));
      expect(m, isNot(contains('secret')));
    });
  });

  test('source refusée et erreurs de redirection : messages précis', () {
    expect(
      explainFailure('x', refused: true),
      'Source refusée pour des raisons de sécurité.',
    );
    expect(
      explainFailure(const UnsafeUrlException('réseau privé')),
      contains('refusée pour des raisons de sécurité'),
    );
    expect(
      explainFailure(const TooManyRedirectsException(5)),
      contains('redirige'),
    );
    expect(
      explainFailure(const ResponseTooLargeException(1)),
      contains('volumineuse'),
    );
  });

  test('journal LUMIO_PLAYER sans URL', () {
    final r = PlaybackReport(
      source: 'HLS',
      viaProxy: true,
      firstFrameMs: 1200,
      url: Uri.parse('https://h.example/secret/a.m3u8'),
    );
    final line = r.toLogLine();
    expect(line, startsWith('LUMIO_PLAYER '));
    expect(line, contains('1200'));
    expect(line, isNot(contains('secret')));
    expect(line, contains('https://h.example/***'));
    // Garde de compilation : lumio_core reste importable ici.
    expect(redactUrl('https://a/b'), 'https://a/***');
  });
}
