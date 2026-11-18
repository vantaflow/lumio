import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/party_client.dart';
import 'package:lumio/config.dart';
import 'package:lumio/features/party/party_session.dart';

/// Client des salles ; nul (fonction masquée) sans `partyServerUrl` valide.
final partyClientProvider = Provider<PartyClient?>((ref) {
  if (partyServerUrl.isEmpty) return null;
  try {
    return PartyClient(partyServerUrl);
  } on PartyException {
    return null;
  }
});

/// Salle active, partagée entre l'écran de salle et le lecteur (qui y branche
/// son contrôleur). Nulle hors salle.
final partySessionProvider = StateProvider<PartySession?>((ref) => null);
