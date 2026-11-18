# Vérification finale (18 novembre 2026)

Vérification des suites automatiques et de la documentation. Les essais sur la
box Android TV n'ont **pas** été faits : la box était injoignable et le disque
du poste de build était sous le seuil de sécurité, donc aucun APK n'a été
construit.

## Résultats

| Contrôle | Commande | Résultat |
|---|---|---|
| Cœur Dart | `cd packages/lumio_core && dart analyze && dart test` | aucun problème, 486 tests verts |
| Application | `cd app && flutter analyze && flutter test` | aucun problème, 704 tests verts |
| Backend | `cd backend && npx tsc --noEmit && npx vitest run` | types valides, 83 tests verts (4 fichiers) |
| Licences | `bash scripts/check-licenses.sh` | 171 dépendances vérifiées, toutes autorisées |
| Test du contrôle de licences | `bash scripts/test-check-licenses.sh` | OK |
| Test du script d'endurance | `bash scripts/test-endurance.sh` | OK (cas : plantage, stable, box injoignable) |

## Non vérifié

À faire quand la box est joignable et que le disque le permet.

- **Sur la box** : temps de démarrage du lecteur, débit torrent (critère 1080p),
  endurance de 8 h, test d'intégration du parcours TV.
- **Bureau** : constructions macOS et Windows.
- **Services réels** : Trakt, Simkl, Jellyfin, cast DLNA sur une vraie TV,
  déploiement du backend (comptes, synchronisation, appairage, salles).

## Commandes à lancer plus tard

```sh
# Disque et construction (box 32 bits)
bash scripts/disk-guard.sh
bash scripts/box-smoke.sh                    # construit, installe, attend LUMIO_READY

# Parcours TV sur la box
cd app && flutter test integration_test/tv_flow_test.dart -d <IP-de-la-box>:5555

# Endurance 8 h : construire avec --dart-define=LUMIO_DEBUG_LOOP=1, puis
caffeinate -i scripts/endurance.sh 8         # code 0 = verdict OK

# Temps du lecteur et débit torrent : voir docs/rapports/2026-11-18-lecteur.md
# et docs/rapports/2026-11-18-torrents.md pour les protocoles de mesure.

# Bureau
cd app && flutter build macos --release      # sur un Mac
cd app && flutter build windows --release    # sur Windows

# Backend, après avoir suivi docs/backend.md
cd backend && npx wrangler d1 migrations apply lumio --remote && npx wrangler deploy
```
