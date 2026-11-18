import 'dart:convert';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test('UTF-8 strict et BOM UTF-8', () {
    expect(
      decodeSubtitleBytes(utf8.encode('Où êtes-vous ?')),
      'Où êtes-vous ?',
    );
    expect(decodeSubtitleBytes([0xEF, 0xBB, 0xBF, ...utf8.encode('é')]), 'é');
  });

  test('UTF-16 LE et BE avec BOM', () {
    expect(decodeSubtitleBytes([0xFF, 0xFE, 0x61, 0x00, 0xE9, 0x00]), 'aé');
    expect(decodeSubtitleBytes([0xFE, 0xFF, 0x00, 0x61, 0x00, 0xE9]), 'aé');
  });

  test('Windows-1256 arabe', () {
    // "مرحبا" en Windows-1256.
    final bytes = [0xE3, 0xD1, 0xCD, 0xC8, 0xC7];
    final srt = [
      ...ascii.encode('1\n00:00:01,000 --> 00:00:02,000\n'),
      ...bytes,
      0x0A,
    ];
    expect(decodeSubtitleBytes(srt), contains('مرحبا'));
  });

  test('Windows-1252 français', () {
    expect(decodeSubtitleBytes([0x43, 0x61, 0x66, 0xE9, 0x20, 0x92]), 'Café ’');
  });

  test('binaires rejetés', () {
    expect(
      () => decodeSubtitleBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]),
      throwsA(isA<SubtitleDecodeException>()),
    );
    expect(
      () => decodeSubtitleBytes([0x50, 0x4B, 0x03, 0x04, 1]),
      throwsA(isA<SubtitleDecodeException>()),
    );
    expect(
      () => decodeSubtitleBytes([0xFF, 0xD8, 0xFF, 0xE0]),
      throwsA(isA<SubtitleDecodeException>()),
    );
    expect(
      () => decodeSubtitleBytes([0x61, 0x00, 0x62]),
      throwsA(isA<SubtitleDecodeException>()),
    );
  });
}
