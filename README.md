# Lumio

Client média libre, multi-plateformes, compatible avec le protocole d'addons
de Stremio. Lumio est **Android uniquement** (Android TV et téléphone),
sans synchronisation ni compte.

> **Statut : toutes les phases du plan sont réalisées, la validation sur
> appareil reste à faire.** Les suites automatiques sont vertes (voir
> [le rapport de vérification](docs/rapports/2026-11-18-verification-finale.md)),
> mais les essais sur la box Android TV et les services réels (Trakt, Jellyfin,
> DLNA, serveur des salles de watch-party déployé) n'ont pas
> encore été vérifiés. Aucune version publiée n'est disponible pour l'instant.

Lumio est un projet indépendant, **non affilié à Stremio**. « Compatible avec
le protocole d'addons » décrit uniquement l'interopérabilité technique.

## Fonctionnalités

- **Addons** : protocole d'addons (catalogues, fiches, flux, sous-titres),
  agrégation de plusieurs addons. L'ajout depuis un téléphone sera fait plus
  tard par une page web servie par la box.
- **Lecture** : lecteur plein écran pensé pour la télécommande (D-pad) et la
  souris, pistes, sous-titres, reprise, épisode suivant.
- **Torrents** : moteur intégré (libtorrent), lecture de magnets en streaming,
  cache disque, confidentialité réseau (VPN requis ou avertissement).
- **Sources locales** : dossiers locaux et Jellyfin.
- **Profils** : profils avec code PIN et contrôle parental.
- **Sauvegarde** : export et import locaux d'un fichier (adresses d'addons
  chiffrées par phrase secrète) ; import depuis Stremio. Pas de synchronisation
  ni de compte.
- **Qualité des sources** : santé des addons, tri et dédoublonnage des flux,
  basculement automatique vers une autre source.
- **Suivi** : Trakt (seul), calendrier des sorties.
- **Partage** : cast DLNA, watch-party.

Lumio **ne fournit, ne suggère et ne recherche aucune source** : aucun addon
n'est préinstallé, aucun scraper n'est inclus. Voir
[l'avertissement](docs/AVERTISSEMENT.md).

## Avancement

Le détail est dans la [feuille de route](docs/feuille-de-route.md). Le plan
compte 41 tâches (numérotées de 1 à 43, les tâches 32 et 33 ayant été
retirées) ; toutes sont réalisées.

| Phase | Contenu | État |
|---|---|---|
| 0 — Socle | Monorepo et CI, addons simulés, backend de comptes, mises à jour, spike torrents | Terminée |
| 1 — MVP | Protocole d'addons, lecteur, focus TV, profils, accueil, recherche, torrents | Terminée |
| 2 — « En mieux » | Synchronisation, chiffrement, import Stremio, confidentialité, santé et tri des sources | Terminée |
| 3 — Extensions | Dossiers locaux, Jellyfin, Trakt, Simkl, calendrier, DLNA, watch-party | Terminée |
| Validation sur appareil | Box Android TV, bureau, services réels | À faire |

## Captures d'écran

À venir, quand l'interface existera.

## Installation rapide

Il n'y a pas encore de version publiée. Pour construire l'APK Android à partir
des sources :

```sh
git clone <url-du-dépôt> lumio && cd lumio/app
flutter pub get
flutter build apk --release --target-platform android-arm
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Détails dans [docs/installation.md](docs/installation.md).

## Configuration

Les réglages de construction sont des constantes dans `app/lib/config.dart`.
Toutes sont vides par défaut ; vide signifie que la fonction concernée est
désactivée ou masquée et que rien n'est envoyé.

| Constante | Rôle |
|---|---|
| `partyServerUrl` (`--dart-define=PARTY_SERVER_URL=…`) | URL https du serveur des salles de watch-party ; vide = watch-party masquée |
| `traktClientId` (`--dart-define=TRAKT_CLIENT_ID=…`) | Application Trakt publique (identifiant par défaut fourni, pas de secret requis) |
| `traktClientSecret` (`--dart-define=TRAKT_CLIENT_SECRET=…`) | Facultatif ; n'est envoyé que s'il est renseigné |
| `updateManifestUrl` | Manifeste de mise à jour `{version, apk, sha256}` ; vide = pas de bannière |

## Serveur des salles de watch-party

`backend/` ne contient que le Worker des salles (Durable Object), sans compte.
Il est optionnel (détail dans [docs/backend.md](docs/backend.md)) :

1. Créer le KV `RATE` et remplacer l'identifiant factice de
   `backend/wrangler.jsonc`.
2. `cd backend && npx wrangler deploy`.
3. Compiler l'application avec `--dart-define=PARTY_SERVER_URL=https://…`.

## Limites connues

- Les flux HLS ne peuvent pas être diffusés par cast DLNA.
- Sans clé TMDB, certaines fiches n'ont pas d'affiche.
- Un profil enfant ne voit que les titres dont la classification est connue :
  les séries Jellyfin sans classement sont masquées.
- Pas de reconnexion automatique à Jellyfin si la session expire.
- La signature de l'APK de test est celle de débogage.
- Non validé sur appareil : voir le
  [rapport de vérification](docs/rapports/2026-11-18-verification-finale.md).

## Documentation

- [Architecture](docs/architecture.md)
- [Compatibilité avec les addons](docs/compatibilite-addons.md)
- [Installation](docs/installation.md)
- [Développement](docs/developpement.md)
- [Serveur des salles](docs/backend.md)
- [Sécurité](docs/securite.md) et [SECURITY.md](SECURITY.md)
- [Torrents et confidentialité](docs/torrents-et-confidentialite.md)
- [Feuille de route](docs/feuille-de-route.md)
- [Vérification finale](docs/rapports/2026-11-18-verification-finale.md)
- [Avertissement](docs/AVERTISSEMENT.md)
- [Contribuer](CONTRIBUTING.md) et [journal des modifications](CHANGELOG.md)

## Licence

Lumio est distribué sous licence GNU GPL-3.0, voir [LICENSE](LICENSE). La
dépendance au moteur de torrents (GPL-3.0) impose cette licence.

## Avertissement légal

Lumio ne fournit ni n'héberge aucun contenu ni aucun addon. Vous êtes
responsable des sources que vous ajoutez et du respect du droit d'auteur dans
votre pays. Voir [docs/AVERTISSEMENT.md](docs/AVERTISSEMENT.md).

---

## English summary

Lumio is a free (GPL-3.0), cross-platform media client compatible with the
Stremio addon protocol, Android only (Android TV and phone), no sync and no
account (Flutter). Features: addon aggregation, built-in torrent streaming
(libtorrent), local folders, Jellyfin, profiles with PIN and parental control,
local backup, Stremio import, torrent
privacy (VPN), addon health and source ranking with fallback, Trakt,
release calendar, DLNA cast, watch-party.

**Status: all planned phases are done; device validation is pending** (Android
TV box runs, real third-party services). No release yet.

Lumio ships no addon and no content, includes no scraper, and is not affiliated
with Stremio. You are responsible for the sources you add and for complying
with copyright law in your country. Documentation is in French, see `docs/`.
