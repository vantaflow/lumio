# Page web servie par la box (cycle 3b)

Depuis son téléphone, sur le Wi-Fi de la maison et sans serveur externe, l'utilisateur envoie un lien d'addon à la TV et gère ses addons (ordre, activation, suppression). Maquettes : TV09 (onglet « Depuis le téléphone »), M04 (page téléphone 390 px), carte « Gérer depuis le téléphone » du rail des Réglages (TV10).

## Décisions
- Serveur : `dart:io` `HttpServer` (le proxy local n'utilise pas `shelf` ; aucune dépendance ajoutée). Code dans `app/lib/features/phone/`.
- Cycle de vie : démarré quand l'onglet « Depuis le téléphone » est affiché (ou pendant qu'une demande du téléphone attend la confirmation sur la TV), arrêté dès qu'il est quitté, à la sortie de l'écran et après 10 min sans requête. Bouton « Relancer » après un arrêt pour inactivité.
- Adresse : IPv4 privée d'une interface Wi-Fi/Ethernet (`wlan*`, `eth*`, `en*`), jamais VPN (`tun`, `utun`, `ppp`, `wg`, `ipsec`) ni mobile (`rmnet`, `ccmni`, `pdp`). On lie l'adresse précise, jamais 0.0.0.0. Port 8790, sinon port libre choisi par le système.
- Flux d'ajout : le téléphone envoie le lien ; la TV passe sur « Par lien » avec l'aperçu existant (`AddonRepository.preview`, `UrlGuard`, confirmation d'adresse privée, `install` + `SecretStore`) ; la TV confirme ; la page affiche « En attente de confirmation sur la TV » puis le résultat. `stremio://` est converti par `parseInstallLink`.
- Gestion : liste, monter/descendre, activer/désactiver, supprimer, via `AddonsController` (opérations existantes du dépôt d'addons).

## Menaces et parades
| Menace | Parade |
|---|---|
| Voisin du Wi-Fi qui devine l'accès | Code à 6 chiffres `Random.secure`, nouveau à chaque ouverture, affiché sur la TV ; sans cookie de session valide toute route `/api` répond 401 |
| Force brute du code | 5 essais faux → verrou 60 s (429), le code est renouvelé au verrouillage ; comparaison à temps constant ; au plus 3 verrouillages par ouverture du serveur, puis arrêt et message « Trop d'essais » avec Relancer sur la TV (le verrou ne peut pas bloquer indéfiniment l'usager : il relance et reçoit un nouveau code) |
| Code fuité dans les journaux / Referer | Le code est dans le fragment du QR (`#c=`), jamais envoyé au serveur ; la page l'efface de l'adresse après lecture ; `Referrer-Policy: no-referrer` |
| Vol / usage du cookie | Cookie `HttpOnly; SameSite=Strict`, jeton aléatoire 256 bits ; session invalidée à l'arrêt du serveur |
| CSRF depuis un autre site | Jeton anti-CSRF (en-tête `X-CSRF-Token`, temps constant) sur toute écriture, `Origin` obligatoire et égal à l'hôte, `Content-Type: application/json` obligatoire |
| DNS rebinding | En-tête `Host` doit être exactement `ip:port` lié ; sinon 421 |
| Déni de service / mémoire | Corps limité à 16 Kio (413), 60 requêtes par 10 s et par adresse (429), une seule demande d'ajout en attente, arrêt après 10 min d'inactivité |
| Serveur gardé vivant | Le délai d'inactivité n'est relancé que par une requête authentifiée (un GET de page ou une requête sans session ne le prolonge pas) ; le serveur s'arrête quand l'application passe en arrière-plan (pause/masquage) et quand un autre écran pleine page est poussé par-dessus (par exemple un second écran « Ajouter un addon » ouvert par un lien d'installation), puis reprend au retour si l'onglet téléphone est actif ; les dialogues ne comptent pas |
| Connexions lentes (slowloris) | Délai TOTAL de lecture du corps de 5 s (408 et fermeture, y compris corps chunké sans `Content-Length`) ; 16 connexions actives au plus, 4 par adresse (au-delà : fermeture immédiate) ; `idleTimeout` de 15 s sur les connexions inactives |
| Entrée numérique inattendue | `delta` doit être l'entier 1 ou -1 (`1.0`, texte, etc. : 400, jamais 500) |
| Fuite des URL d'addons | Aucune URL d'addon ni de logo dans les réponses ni les journaux ; identifiant opaque par addon (HMAC de l'identifiant avec un secret de session) ; le logo est remplacé par l'initiale colorée ; erreurs génériques sans l'adresse envoyée |
| SSRF via le lien envoyé | Réutilisation intégrale du flux existant (`UrlGuard`, confirmation sur la TV pour les adresses privées) |
| Injection / XSS dans la page | Aucun `innerHTML` avec des données ; `textContent` uniquement ; CSP `default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'` ; `nosniff`, `frame-ancestors 'none'` |
| Installation sans le propriétaire | Le téléphone ne peut qu'envoyer un lien ; seule la TV installe |

## Page téléphone
HTML/CSS/JS embarqués dans l'app (`/`, `/app.css`, `/app.js`), sans ressource externe, fidèle à M04, vrais boutons et labels, `aria-live` pour l'état, français/anglais selon la langue de l'app. Lien « Parcourir stremio-addons.net » vers le site dans le navigateur du téléphone. Page de saisie manuelle du code si le fragment est absent.

## TV
Onglet TV09 : QR local (`qr_flutter`) de `http://IP:port/#c=CODE`, IP:port, code « 482 913 », état (en attente / téléphone connecté / verrouillé / arrêté / pas de réseau local). Carte « Gérer depuis le téléphone » en bas du rail des Réglages : ouvre l'écran Ajouter un addon sur l'onglet téléphone.

## Limites assumées
HTTP en clair sur le réseau local (pas de certificat de confiance possible sur une box) ; le code et le cookie transitent donc en clair sur le Wi-Fi de la maison, d'où le renouvellement du code et la durée de vie courte du serveur.

## Catalogue d'addons : analyse des pages (revue de sécurité)
| Menace | Parade |
|---|---|
| Page ou collection de repli altérée (type inattendu) | Lecture typée tolérante de `addonscollection.json` : un champ de mauvais type est ignoré, une entrée illisible est écartée ; le service rattrape toute erreur d'analyse du repli |
| Réglages ou adresses d'un bloc voisin attribués à une instance | Chaque instance est bornée à son objet JSON (comptage d'accolades hors chaînes) ; pas de repli « tous les `manifestUrl` de la page » si un tableau d'instances existe ; repli sans tableau accepté seulement pour une adresse unique, sinon rien n'est proposé ; l'écran de choix affiche domaine et chemin court |
| Analyse coûteuse sur le fil de l'interface | Analyse dans `Isolate.run` ; pages de liste plafonnées à 512 Kio (fiches : 2 Mio) ; analyse des cartes en une seule passe (page sans `</a>` : moins de 2 s) |
