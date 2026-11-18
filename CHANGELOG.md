# Journal des modifications

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Aucune version n'est encore publiée.

## [Non publié]

### Ajouté
- Tâche 1 : monorepo (`app`, `packages/lumio_core`, `backend`), application
  Flutter, intégration continue, garde-fous (`disk-guard`, `check-licenses`,
  `box-smoke`), licence GPL-3.0.
- Tâche 2 : serveur d'addons simulé et corpus de manifests pour les tests.
- Tâche 3 : backend Worker avec comptes par jeton à usage unique envoyé par
  e-mail, sessions, rotation du jeton de rafraîchissement et limitation de
  débit.
- Tâche 4 : vérificateur de mises à jour (version et empreinte SHA-256) et
  récupérateur HTTP sécurisé avec contrôle des redirections.
- Tâche 5 : interface `TorrentEngine`, adaptateur `libtorrent_flutter` 1.7.5 et
  spike validé sur une box Android TV 32 bits (rapport dans `docs/rapports/`).
- Tâche 6 : cœur du protocole d'addons (manifest, client, normalisation des
  URL) et garde SSRF.
- Tâches 7 à 31, 34 à 42 : agrégation, lecteur, profils, accueil, recherche,
  torrents, synchronisation chiffrée, import Stremio, confidentialité, santé
  des addons, dossiers locaux, Jellyfin, Trakt, Simkl, calendrier, DLNA,
  watch-party.
- Tâche 43 : vérification finale et documentation
  ([rapport](docs/rapports/2026-11-18-verification-finale.md)).
- Documentation du projet.
