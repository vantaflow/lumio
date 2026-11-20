# Journal des modifications

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Aucune version n'est encore publiée.

## [Non publié]

### Corrigé (2026-11-20)
- « Reprendre » relance le flux effectivement regardé (même addon, même
  torrent infoHash+fileIdx ou même lien), à la position enregistrée ; si ce
  flux n'existe plus, repli sur le meilleur flux avec un message. La
  progression mémorise l'identité non sensible du flux (migration de base v13) ;
  jamais l'URL.

### Modifié (2026-11-18)
- Android uniquement : cibles macOS, Windows et jobs CI desktop retirés.
- Plus de synchronisation ni de compte : écrans Compte et phrase secrète,
  client de synchro, appairage par le serveur retirés ; migration de base v11
  (suppression de la file d'envoi et de ses déclencheurs).
- Suivi Trakt seul (Simkl retiré), sans client_secret obligatoire.
- `backend/` réduit au serveur des salles de watch-party, sans compte.

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
