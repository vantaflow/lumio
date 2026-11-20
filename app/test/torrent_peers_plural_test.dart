import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/l10n/app_localizations_en.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';

void main() {
  test('nombre de sources accordé en français', () {
    final l = AppLocalizationsFr();
    expect(l.torrentPeers(0), '0 source');
    expect(l.torrentPeers(1), '1 source');
    expect(l.torrentPeers(12), '12 sources');
  });

  test('peer count agrees in English', () {
    final l = AppLocalizationsEn();
    expect(l.torrentPeers(0), '0 sources');
    expect(l.torrentPeers(1), '1 source');
    expect(l.torrentPeers(12), '12 sources');
  });
}
