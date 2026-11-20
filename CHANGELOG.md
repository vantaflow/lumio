# Journal des modifications

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
## [Non publié]

## [1.0.0] - 2026-11-20

Première version publiée : client média Android TV et téléphone compatible avec
le protocole d'addons, torrents intégrés (TorrServer), dossiers locaux,
Jellyfin, profils avec code PIN et contrôle parental, sauvegarde locale,
import Stremio, suivi Trakt, calendrier des sorties, DLNA, Watch party et
portail « Gérer depuis le téléphone ».

### Ajouté
- APK signés avec la clé de release de Lumio, un par architecture :
  `armeabi-v7a` (box 32 bits) et `arm64-v8a` (téléphones, box 64 bits).
- Mises à jour : la bannière de l'accueil compare la version installée à
  celle de la dernière release (`update.json`) et ouvre le téléchargement de
  l'APK adapté à l'architecture de l'appareil.
- Page de téléchargement : <https://vantaflow.github.io/lumio/>.

Les installations de test (signées avec la clé de développement) ne peuvent
pas être mises à jour par-dessus : Android refuse un APK signé avec une autre
clé. Désinstaller Lumio efface ses données (addons, profils, progression) ;
faire une sauvegarde locale avant.

### Retiré (2026-11-20)
- Option VPN : réglage « VPN requis » et interface VPN, carte d'état VPN,
  coupe-circuit des torrents, surveillance du réseau pendant la lecture,
  avertissement d'adresse IP avant le premier torrent, rappel « Aucun VPN
  détecté » et messages associés (fr et en). Les torrents démarrent
  directement ; les anciens réglages stockés sont ignorés. Le cycle « VPN
  WireGuard intégré » est annulé. Le rail des Réglages affiche « Torrents ».
  Le portail du téléphone reste refusé sur une interface VPN ou mobile
  (protection du portail, inchangée).

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
