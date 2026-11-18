# Lumio

Client média libre, multi-plateformes, compatible avec le protocole d'addons
de Stremio. Lumio vise Android TV et Android en priorité, puis macOS et
Windows, avec le même code Flutter.

> **Statut : toutes les phases du plan sont réalisées, la validation sur
> appareil reste à faire.** Les suites automatiques sont vertes (voir
> [le rapport de vérification](docs/rapports/2026-11-18-verification-finale.md)),
> mais les essais sur la box Android TV, les constructions macOS et Windows et
> les services réels (Trakt, Simkl, Jellyfin, DLNA, backend déployé) n'ont pas
> encore été vérifiés. Aucune version publiée n'est disponible pour l'instant.

Lumio est un projet indépendant, **non affilié à Stremio**. « Compatible avec
le protocole d'addons » décrit uniquement l'interopérabilité technique.

## Fonctionnalités

- **Addons** : protocole d'addons (catalogues, fiches, flux, sous-titres),
  agrégation de plusieurs addons, appairage depuis un téléphone.
- **Lecture** : lecteur plein écran pensé pour la télécommande (D-pad) et la
  souris, pistes, sous-titres, reprise, épisode suivant.
- **Torrents** : moteur intégré (libtorrent), lecture de magnets en streaming,
  cache disque, confidentialité réseau (VPN requis ou avertissement).
- **Sources locales** : dossiers locaux et Jellyfin.
- **Profils** : profils avec code PIN et contrôle parental.
- **Synchronisation** : serveur auto-hébergeable, secrets (addons) chiffrés de
  bout en bout côté client ; sauvegarde et restauration locales ; import depuis
  Stremio.
- **Qualité des sources** : santé des addons, tri et dédoublonnage des flux,
  basculement automatique vers une autre source.
- **Suivi** : Trakt, Simkl, calendrier des sorties.
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
| `backendUrl` | URL https du backend (appairage mobile, synchronisation, salons de watch-party) |
| `traktClientId`, `traktClientSecret` | Application Trakt (suivi) |
| `simklClientId` | Application Simkl (suivi) |
| `updateManifestUrl` | Manifeste de mise à jour `{version, apk, sha256}` ; vide = pas de bannière |

## Déploiement du backend

Le backend est optionnel. Étapes (détail dans [docs/backend.md](docs/backend.md)) :

1. Créer la base D1, le KV et déclarer le Durable Object ; remplacer les
   identifiants factices de `backend/wrangler.jsonc`.
2. `cd backend && npx wrangler d1 migrations apply lumio --remote`
3. Brancher un expéditeur d'e-mail (implémentation de `EmailSender`, passée à
   `createApp`) : sans lui, personne ne reçoit de jeton de connexion.
4. `npx wrangler deploy`, puis renseigner `backendUrl` dans `config.dart`.

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
- [Backend](docs/backend.md)
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
Stremio addon protocol, aimed at Android TV, Android, macOS and Windows
(Flutter). Features: addon aggregation, built-in torrent streaming
(libtorrent), local folders, Jellyfin, profiles with PIN and parental control,
self-hostable end-to-end-encrypted sync, backup, Stremio import, torrent
privacy (VPN), addon health and source ranking with fallback, Trakt/Simkl,
release calendar, DLNA cast, watch-party.

**Status: all planned phases are done; device validation is pending** (Android
TV box runs, desktop builds, real third-party services). No release yet.

Lumio ships no addon and no content, includes no scraper, and is not affiliated
with Stremio. You are responsible for the sources you add and for complying
with copyright law in your country. Documentation is in French, see `docs/`.
