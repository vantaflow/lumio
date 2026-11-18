# Lumio

Client média libre, multi-plateformes, compatible avec le protocole d'addons
de Stremio. Lumio vise Android TV et Android en priorité, puis macOS et
Windows, avec le même code Flutter.

> **Statut : en développement.** Lumio n'est pas encore utilisable au
> quotidien : il n'existe pas encore d'interface de navigation ni de lecteur.
> Ce dépôt contient aujourd'hui les fondations (cœur du protocole d'addons,
> moteur de torrents validé sur une box Android TV, squelette du serveur de
> comptes). Aucune version publiée n'est disponible pour l'instant.

Lumio est un projet indépendant, **non affilié à Stremio**. « Compatible avec
le protocole d'addons » décrit uniquement l'interopérabilité technique.

## Ce que Lumio veut être

- Un client média qui parle le protocole d'addons (catalogues, fiches, flux,
  sous-titres) et agrège plusieurs addons.
- Un lecteur plein écran pensé pour la télécommande (D-pad) et la souris.
- Un moteur de torrents intégré (libtorrent) pour lire des magnets en
  streaming.
- De l'IPTV (listes M3U et Xtream, guide des programmes XMLTV).
- Des dossiers locaux et Jellyfin comme sources.
- Des profils avec contrôle parental.
- Une synchronisation auto-hébergeable, avec chiffrement des secrets côté
  client.
- Trakt, Simkl, calendrier des sorties, cast DLNA, watch-party.

Lumio **ne fournit, ne suggère et ne recherche aucune source** : aucun addon
n'est préinstallé, aucun scraper n'est inclus. Voir
[l'avertissement](docs/AVERTISSEMENT.md).

## Avancement

Le détail est dans la [feuille de route](docs/feuille-de-route.md). Le plan
compte 43 tâches ; les tâches 1 à 6 sont terminées.

| Phase | Contenu | Tâches | État |
|---|---|---|---|
| 0 — Socle | Monorepo et CI, addons simulés, backend de comptes, mises à jour, spike du moteur de torrents | 1 à 5 | Terminée |
| 1 — MVP | Protocole d'addons, agrégation, lecteur, focus TV, profils, accueil, recherche, torrents de bout en bout | 6 à 26 | En cours (tâche 6 faite, 7 à 26 à venir) |
| 2 — « En mieux » | Synchronisation, chiffrement, import Stremio, confidentialité des torrents, IPTV, santé des addons | 27 à 35 | À venir |
| 3 — Extensions | Dossiers locaux, Jellyfin, Trakt, Simkl, calendrier, DLNA, watch-party, vérification finale | 36 à 43 | À venir |

## Ce qui existe aujourd'hui

- Monorepo (`app/`, `packages/lumio_core/`, `backend/`) et intégration
  continue.
- Cœur Dart : lecture et validation des manifests d'addons, client d'addons
  (catalogues, fiches, flux, sous-titres bruts), normalisation des URL
  d'addons, garde SSRF, récupérateur HTTP sécurisé, vérification des mises à
  jour, `redactUrl` pour les journaux.
- Interface `TorrentEngine` et adaptateur `libtorrent_flutter`, validés par un
  essai sur une box Android TV 32 bits (voir
  [le rapport](docs/rapports/2026-11-18-spike-0.6.md)).
- Serveur de comptes (Cloudflare Worker) : connexion par jeton à usage unique
  envoyé par e-mail, sessions, limitation de débit.
- Banc de tests : serveur d'addons simulé et corpus de manifests.

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

## Documentation

- [Architecture](docs/architecture.md)
- [Compatibilité avec les addons](docs/compatibilite-addons.md)
- [Installation](docs/installation.md)
- [Développement](docs/developpement.md)
- [Backend](docs/backend.md)
- [Sécurité](docs/securite.md) et [SECURITY.md](SECURITY.md)
- [Torrents et confidentialité](docs/torrents-et-confidentialite.md)
- [Feuille de route](docs/feuille-de-route.md)
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
(Flutter). Planned features: addon aggregation, built-in torrent streaming
(libtorrent), IPTV (M3U/Xtream/XMLTV), local folders, Jellyfin, profiles with
parental control, self-hostable end-to-end-encrypted sync, Trakt/Simkl.

**Status: under development, no release yet.** Done so far (tasks 1 to 6 of 43):
monorepo and CI, fake addon server, magic-token auth backend, update checker
and hardened HTTP fetcher, torrent engine spike validated on an Android TV box,
addon protocol core with an SSRF guard. Everything else is planned.

Lumio ships no addon and no content, includes no scraper, and is not affiliated
with Stremio. You are responsible for the sources you add and for complying
with copyright law in your country. Documentation is in French, see `docs/`.
