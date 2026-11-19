import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/phone/lan_address.dart';

InternetAddress _a(String s) => InternetAddress(s);

void main() {
  test('choisit le Wi-Fi, jamais un VPN ni le mobile', () {
    final pick = pickLanAddress([
      ('tun0', [_a('10.8.0.2')]),
      ('rmnet_data0', [_a('10.20.30.40')]),
      ('wlan0', [_a('192.168.0.45'), _a('fe80::1')]),
    ]);
    expect(pick?.address, '192.168.0.45');
  });

  test('Ethernet accepté, Wi-Fi préféré', () {
    expect(
      pickLanAddress([
        ('eth0', [_a('192.168.1.9')]),
        ('wlan0', [_a('192.168.1.10')]),
      ])?.address,
      '192.168.1.10',
    );
    expect(
      pickLanAddress([
        ('eth0', [_a('172.16.4.2')]),
      ])?.address,
      '172.16.4.2',
    );
  });

  test('macOS : en0 accepté, utun refusé', () {
    expect(
      pickLanAddress([
        ('utun3', [_a('10.9.0.1')]),
        ('en0', [_a('192.168.0.7')]),
      ])?.address,
      '192.168.0.7',
    );
  });

  test('adresse publique, locale au lien ou absente : rien', () {
    expect(
      pickLanAddress([
        ('wlan0', [_a('8.8.8.8')]),
      ]),
      isNull,
    );
    expect(
      pickLanAddress([
        ('wlan0', [_a('169.254.1.1')]),
      ]),
      isNull,
    );
    expect(
      pickLanAddress([
        ('wlan0', [_a('fe80::1')]),
      ]),
      isNull,
    );
    expect(
      pickLanAddress([
        ('ppp0', [_a('192.168.0.2')]),
      ]),
      isNull,
    );
    expect(pickLanAddress(const []), isNull);
  });
}
