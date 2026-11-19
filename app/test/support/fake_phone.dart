import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumio/features/phone/lan_address.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_server.dart';

/// Adresse du réseau local factice (192.168.0.45).
class FakeLan implements LanAddressSource {
  const FakeLan([this.addr = '192.168.0.45']);
  final String? addr;
  @override
  Future<InternetAddress?> current() async =>
      addr == null ? null : InternetAddress(addr!);
}

/// Serveur du téléphone factice : aucun socket, état pilotable.
class FakePhoneSession implements PhoneSession {
  FakePhoneSession({PhoneServerState? initial, this.startState})
    : _state = ValueNotifier(initial ?? const PhoneServerState());

  final ValueNotifier<PhoneServerState> _state;
  final PhoneAddCoordinator _adds = PhoneAddCoordinator();
  final events = <String>[];

  /// État après `start()` ; par défaut, l'écoute normale.
  final PhoneServerState? startState;

  @override
  ValueListenable<PhoneServerState> get state => _state;

  @override
  PhoneAddCoordinator get adds => _adds;

  void set(PhoneServerState s) => _state.value = s;

  @override
  Future<void> start() async {
    events.add('start');
    _state.value =
        startState ??
        const PhoneServerState(
          status: PhoneServerStatus.listening,
          host: '192.168.0.45',
          port: 8790,
          code: '482913',
        );
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    _adds.cancelPending();
    _state.value = const PhoneServerState();
  }

  @override
  void dispose() => events.add('dispose');
}
