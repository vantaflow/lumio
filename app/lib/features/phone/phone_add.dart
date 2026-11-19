import 'dart:math';

import 'package:flutter/foundation.dart';

/// État d'une demande d'ajout envoyée depuis le téléphone.
enum PhoneAddState { waiting, installed, failed, cancelled, expired }

/// Demande d'ajout. [url] est secrète : elle ne quitte jamais la TV (jamais
/// renvoyée au téléphone, jamais journalisée).
class PhoneAddRequest {
  PhoneAddRequest(this.id, this.url, this.createdAt);

  final String id;
  final Uri url;
  final DateTime createdAt;
  PhoneAddState state = PhoneAddState.waiting;

  /// Nom de l'addon installé (affiché sur la page, c'est tout).
  String? name;
}

/// Pont entre la page du téléphone et l'écran de la TV : le téléphone dépose
/// un lien, la TV l'affiche avec l'aperçu existant, confirme l'installation et
/// rapporte le résultat.
class PhoneAddCoordinator {
  PhoneAddCoordinator({
    DateTime Function()? now,
    Random? random,
    this.ttl = const Duration(minutes: 5),
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  final DateTime Function() _now;
  final Random _random;
  final Duration ttl;
  final _all = <String, PhoneAddRequest>{};

  /// Demande en attente de confirmation sur la TV (au plus une).
  final ValueNotifier<PhoneAddRequest?> pending = ValueNotifier(null);

  String _newId() => List.generate(
    12,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  /// Nouvelle demande ; remplace (et annule) celle qui attendait.
  PhoneAddRequest submit(Uri url) {
    final old = pending.value;
    if (old != null) resolve(old.id, PhoneAddState.cancelled);
    final r = PhoneAddRequest(_newId(), url, _now());
    _all[r.id] = r;
    while (_all.length > 20) {
      _all.remove(_all.keys.first);
    }
    pending.value = r;
    return r;
  }

  void resolve(String id, PhoneAddState state, {String? name}) {
    final r = _all[id];
    if (r == null || r.state != PhoneAddState.waiting) return;
    r.state = state;
    r.name = name;
    if (pending.value?.id == id) pending.value = null;
  }

  /// Annule la demande en attente (la TV a quitté le flux).
  void cancelPending() {
    final p = pending.value;
    if (p != null) resolve(p.id, PhoneAddState.cancelled);
  }

  PhoneAddRequest? lookup(String id) {
    final r = _all[id];
    if (r != null &&
        r.state == PhoneAddState.waiting &&
        _now().difference(r.createdAt) > ttl) {
      resolve(id, PhoneAddState.expired);
    }
    return r;
  }

  void dispose() => pending.dispose();
}
