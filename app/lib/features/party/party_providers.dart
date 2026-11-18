import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/party_client.dart';
import 'package:lumio/data/sync_providers.dart';
import 'package:lumio/features/party/party_session.dart';

/// Client des salles ; nul (fonction masquée) sans `backendUrl` valide.
final partyClientProvider = Provider<PartyClient?>((ref) {
  final api = ref.watch(syncApiClientProvider);
  return api == null ? null : PartyClient(api);
});

/// Salle active, partagée entre l'écran de salle et le lecteur (qui y branche
/// son contrôleur). Nulle hors salle.
final partySessionProvider = StateProvider<PartySession?>((ref) => null);
