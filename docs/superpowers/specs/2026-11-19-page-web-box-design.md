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
| Force brute du code | 5 essais faux → verrou 60 s (429), le code est renouvelé au verrouillage ; comparaison à temps constant |
| Code fuité dans les journaux / Referer | Le code est dans le fragment du QR (`#c=`), jamais envoyé au serveur ; la page l'efface de l'adresse après lecture ; `Referrer-Policy: no-referrer` |
| Vol / usage du cookie | Cookie `HttpOnly; SameSite=Strict`, jeton aléatoire 256 bits ; session invalidée à l'arrêt du serveur |
| CSRF depuis un autre site | Jeton anti-CSRF (en-tête `X-CSRF-Token`, temps constant) sur toute écriture, `Origin` obligatoire et égal à l'hôte, `Content-Type: application/json` obligatoire |
| DNS rebinding | En-tête `Host` doit être exactement `ip:port` lié ; sinon 421 |
| Déni de service / mémoire | Corps limité à 16 Kio (413), 60 requêtes par 10 s et par adresse (429), une seule demande d'ajout en attente, arrêt après 10 min d'inactivité |
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
