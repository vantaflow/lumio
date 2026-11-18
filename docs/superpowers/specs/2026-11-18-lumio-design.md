# Lumio — conception (cycle 1)

> Run autopilot, conception auto-approuvée (l'utilisateur a demandé « termine ce projet sans poser de question »).
> Besoin détaillé, exigences EF/ENF, hypothèses H-n et 44 stories : `~/Projects/plans/plan-client-media/PLAN.md` et `stories/`.
> Spike lecteur : `~/Projects/lumio-spike/RAPPORT-0.3.md`.

## Intention
Un client média personnel, multi-plateformes, qui parle le protocole d'addons Stremio et va plus loin : IPTV (M3U/Xtream + EPG), dossiers locaux, Jellyfin, profils avec contrôle parental, synchronisation auto-hébergeable, Trakt/Simkl, santé des addons et choix automatique de la meilleure source, moteur de torrents intégré comme Stremio.

## Objectifs
- Couvrir toutes les exigences EF-1 à EF-22 et ENF-1 à ENF-5 du plan.
- Cible principale : Android / Android TV (box de test 32 bits armeabi-v7a, 2 Go). Desktop macOS/Windows : même code Flutter.
- Accueil < 2 s (cache chaud), lecture de fichier direct < 3 s, import M3U 50 000 entrées < 15 s sur la box.

## Non-objectifs
- iOS / tvOS. Magasin d'addons. Hébergement de contenu.
- Déploiement Cloudflare, publication, push : non demandés dans ce run.

## Anti-objectifs (échec même si « ça marche »)
- Un addon pré-installé ou suggéré ; un scraper ou une recherche de sources dans le client.
- Un nom, un logo ou des visuels proches de Stremio.
- Des URL d'addons (souvent porteuses de clés) en clair dans SQLite, les journaux ou le serveur.

## Contraintes
- Build uniquement sur le Mac (pas de Xcode complet → pas de build macOS ; pas de Windows). Box joignable en `adb` à `192.168.0.43:5555`.
- Disque du Mac : garder ≥ 80 Go libres ; nettoyer les dossiers `build/` après usage.
- Aucune fenêtre visible sur le Mac : tests `dart test` / `flutter test` en mode headless ; essais d'interface sur la box.
- Contenus de test libres de droits uniquement.

## Approches considérées

### Moteur de torrents
| Approche | Pour | Contre |
|---|---|---|
| **`libtorrent_flutter` (libtorrent 2.x en FFI, serveur HTTP de streaming intégré, binaires précompilés)** | Moteur de référence, streaming par priorité de pièces, cache glissant, limites de débit, Android/desktop | GPL-3.0 ; liaison à une interface réseau non exposée |
| `dtorrent_task_v2` (pur Dart) | Aucun natif, licence permissive | Performances incertaines sur une box 32 bits, maturité moindre |
| `torrserver_flutter` (TorrServer Go en sous-processus) | Éprouvé | GPL-3.0, processus externe à gérer |

**Retenu : `libtorrent_flutter`**, derrière une interface `TorrentEngine` pour pouvoir basculer sur `dtorrent_task_v2`. Conséquence : Lumio est sous licence **GPL-3.0** (projet personnel, aucune gêne).

### Lecture HLS (échec TLS de libmpv)
| Approche | Retenu |
|---|---|
| **Proxy HTTP local en Dart** (requêtes HTTPS faites par Dart, servies à libmpv sur 127.0.0.1, réécriture des playlists HLS, en-têtes imposés par les addons) | **Oui** |
| Reconstruire libmpv avec OpenSSL | Non : maintenance lourde |
| Ne rien faire | Non : bloque l'IPTV |

### Architecture du code
| Approche | Retenu |
|---|---|
| **Monorepo : `packages/lumio_core` (Dart pur, testable sans Flutter) + `app/` (Flutter) + `backend/` (Workers)** | **Oui** : le cœur protocolaire et les parseurs se testent vite et sans appareil |
| Une seule application Flutter | Non : tests plus lents, couplage UI/logique |

## Conception

### Dépôt
```
packages/lumio_core/   Dart pur : protocole d'addons, agrégation, tri/dédoublonnage, santé, M3U/Xtream, XMLTV,
                       règles de progression, profils/classification, modèles de synchro, chiffrement, import Stremio
app/                   Flutter : UI (Riverpod), lecteur media_kit, base locale drift (SQLite + FTS5),
                       proxy HTTP local, moteur de torrents, stockage sécurisé, intégrations (Jellyfin, Trakt, Simkl, DLNA)
backend/               Cloudflare Worker (Hono + D1 + KV + Durable Objects), tests vitest + Miniflare
docs/                  specs, plans, rapports
```

### Client
- **État** : Riverpod. **Navigation** : go_router. **Base locale** : drift (SQLite, FTS5 pour la recherche de chaînes). **Secrets** : flutter_secure_storage (URL d'addons, jetons).
- **Lecteur** : media_kit (libmpv) ; options libmpv réglées au démarrage ; flux HLS et flux à en-têtes passent par le proxy local.
- **Proxy local** (`shelf`) : `GET /p?u=<url>&h=<en-têtes>` relaie en flux avec plages d'octets ; pour une playlist `.m3u8`, réécrit chaque URI vers le proxy.
- **Torrents** : `TorrentEngine` → `libtorrent_flutter` (`addMagnet`, `getFiles`, `startStream` → URL `http://127.0.0.1:PORT/stream/...`), cache glissant (`maxCacheBytes`, défaut 1,5 Go sur TV), limites de débit, avertissement IP. Liaison VPN : détection de l'interface active et arrêt du moteur si l'interface choisie tombe (kill switch applicatif), faute d'option native.
- **Focus TV** : composants `Focusable*` maison au-dessus de `FocusTraversalGroup`, mémoire de focus par route.
- **Intégrations** : Jellyfin (API REST), Trakt et Simkl (flux d'appareil OAuth ; identifiants d'application dans la configuration, fonctions désactivées tant qu'ils manquent), TMDB optionnel (clé de l'utilisateur), DLNA/UPnP pour le cast (Dart pur).

### Cœur `lumio_core`
- **Addons** : modèles `Manifest`, `MetaPreview`, `Meta`, `Stream`, `Subtitle` ; client avec délais, nouvelle tentative, validation stricte ; agrégation concurrente isolée par addon ; garde SSRF (http/https, refus localhost/IP privées sauf confirmation, limite de taille et de redirections).
- **Sources** : normalisation (qualité, langue, taille, seeders), signature de dédoublonnage, tri par préférences de profil et fiabilité mesurée.
- **Parseurs** : M3U/Xtream en flux, XMLTV en flux (.gz), conçus pour tourner dans un isolate.

### Backend
- Hono sur Workers ; D1 : `users`, `sessions`, `sync_items(user_id, kind, key, payload, version, deleted)`, `pair_codes` ; KV : limitation de débit ; Durable Objects : salles de watch-party.
- Connexion par lien magique ; l'envoi d'e-mail passe par une interface `EmailSender` (journal en dev, Cloudflare Email Service en prod).
- Synchronisation : version **attribuée par le serveur** (compteur monotone par utilisateur), suppressions en tombstones, `GET /sync?since=v` / `POST /sync`. La progression de lecture : la plus récente gagne. Les secrets arrivent **déjà chiffrés** par le client (AES-GCM, clé dérivée d'une phrase secrète par Argon2id/PBKDF2) : le serveur ne les lit pas.

## Ce qui reste au constructeur
Le détail des écrans, l'ordre fin des tâches (suivant l'ordre de développement du plan), les choix de paquets secondaires, consignés en Rulings.

## Écarts assumés par rapport au plan
- Builds macOS/Windows non produits dans ce run (Xcode incomplet, pas de Windows) : code partagé, vérifié par les tests.
- Envoi réel des e-mails, clés Trakt/Simkl/TMDB et déploiement : à fournir ensuite ; tout est testé avec des doubles.
- Liaison à une interface réseau : arrêt applicatif si le VPN tombe, pas de liaison native (non exposée par la bibliothèque).

## Amendement du 2026-11-18 — retrait de l'IPTV
Décision de l'utilisateur : **Lumio n'a pas d'IPTV**. Retirés du périmètre : listes M3U/Xtream, chaînes en direct, guide EPG/XMLTV (EF-10, stories 5.1 et 5.2), le badge de source « IPTV », l'entrée « liste M3U » de l'assistant et l'écran « TV en direct ». Le proxy HTTP local reste (flux HLS et en-têtes imposés par les addons).

## Amendement du 2026-11-18 — Android seul, sans synchronisation, Trakt seul
Décisions de l'utilisateur, qui l'emportent sur le reste de ce document :
- **Android uniquement** (Android TV et téléphone) : plus de cibles macOS, Windows ni Linux.
- **Pas de synchronisation ni de compte** : retirés le serveur de comptes (lien magique, `EmailSender`, D1 `users`/`sessions`/`sync_items`/`pair_codes`), `GET/POST /sync`, la phrase secrète de synchronisation et l'appairage par le serveur. Les adresses d'addons restent chiffrées localement (`SecretStore`) ; la sauvegarde/import de fichier reste. L'ajout d'addons depuis un téléphone sera refait plus tard par une page web servie par la box.
- **Suivi avec Trakt seul** : Simkl retiré. L'application Trakt est publique : le flux par code d'appareil n'exige pas de `client_secret`.
- **Watch-party conservée**, mais sans compte : `backend/` ne garde que le Worker et le Durable Object des salles (salle anonyme : identifiant de 128 bits, code de 8 caractères, clé d'hôte, expiration 6 h, limites de taille et de débit conservées). Adresse du serveur configurable (`PARTY_SERVER_URL`), watch-party masquée si elle est vide.
