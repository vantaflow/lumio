# Test fonctionnel global sur l'émulateur TV (2026-11-19)

Émulateur Google TV Android 14 (x86, traduction ARM, 1920x1080), APK release android-arm, fenêtre scrcpy sous les yeux de l'utilisateur. Contenu légal uniquement. Passe INCOMPLÈTE (contexte épuisé) : ce qui est fait et ce qui reste est indiqué étape par étape.

## Addon de test (jamais embarqué)
`~/lumio-build/test-addon` sur la machine IA (port 7012) : `./run.sh start | stop | status`. Manifest « Films libres (test) » : catalogue de 5 films Blender (Sintel, Big Buck Bunny, Tears of Steel, Elephants Dream, Cosmos Laundromat), ressources catalog, meta, stream, subtitles, types movie et series, préfixe `tt`. Pour TOUT identifiant `tt…` (film, ou série avec saison:épisode) il renvoie un flux https de test « Flux de test (contenu libre) » (MP4 Blender, archive.org / download.blender.org) et deux sous-titres libres (Sintel EN/FR, durian.blender.org). Installé par « Par lien » (http://10.0.2.2:7012/manifest.json) : la confirmation « Adresse locale » apparaît bien.

## Résultats par étape
| Étape | Résultat |
|---|---|
| A. Premier lancement, onboarding (langue, profil, sources) | OK. Accueil atteint ; « 1 addon installé » affiché à l'étape 3. |
| B. Catalogue intégré, badge, installation directe | Partiel : installation directe de Marvel depuis le catalogue OK (dialogue « Choisir une instance », fiche, puis aperçu « Par lien », puis Installer : deux confirmations). Cinemeta et OpenSubtitles v3 absents du catalogue (défaut consigné). Badge « Installé » vu sur le portail. |
| C. Paramétrage | OK de bout en bout, deux côtés (voir ci-dessous). |
| D. Fonctionnement : catalogues, fiche, flux | OK : rangées de l'addon de test et de Marvel sur l'accueil ; fiche d'un titre Marvel (Captain America) avec le flux de test du bon groupe (« ADDON · Films libres (test) · Santé : bonne », « Direct »). Fiche pauvre (pas de synopsis) quand aucun addon meta n'existe. |
| E. Lecture | OK sur le fond : démarrage, temps qui avance (durée 14:48), ±10 s, barre, commandes. L'image est noire sur les captures de l'émulateur (rendu logiciel) : non vérifiable ici. Panneau Pistes : non atteint (la première touche ne fait que réveiller les commandes, qui se masquent en 3 s). |
| F. Sous-titres | NON FAIT (à tester sur la vraie box). |
| G. Favoris | NON FAIT. |
| H. Reprise | Partiel : le titre apparaît dans « Continuer à regarder » avec barre et bouton « Reprendre », « Reprise à 1:06 » proposé au 2e lancement. DÉFAUT : affiche et titre remplacés par l'identifiant brut `tt0458339`. Force-stop et fin de lecture : NON FAIT. |
| I. Surveillance | Pas de plantage ni FATAL. Erreurs « Failed to decode image » dans logcat (une affiche non décodable, sans effet visible). Émulateur très lent (images jusqu'à 20 s au démarrage) : les captures retardent sur les touches. |

## C. Paramétrage : avis
Parcours testé dans la vraie fenêtre Chrome (portail) et sur la TV : TV, Réglages, « Gérer depuis le téléphone » (adresse et code à 6 chiffres) ; portail : connexion, catalogue, fiche, « Configurer » ouvre la page /configure de l'addon (Torrentio, uniquement pour tester le formulaire, jamais pour lire ; retiré ensuite), l'onglet donne le lien produit (bouton INSTALL, lien stremio://), retour sur le portail, collage, « Envoyer à la TV », « En attente de confirmation sur la TV… », aperçu sur la TV, Installer, bandeau vert « Installé ». Environ 9 étapes dont 3 changements d'écran : c'est long mais chaque étape est guidée et la sécurité (confirmation sur la TV) est préservée. Points de confusion : (1) le panneau « Configurer » reste ouvert après l'envoi et le formulaire principal ajoute un doublon au lieu de remplacer ; (2) deux boutons « Envoyer à la TV » sur la même page ; (3) la TV affiche le lien brut tronqué ; (4) la carte de la TV s'appelle « Gérer depuis le téléphone » mais ouvre « Ajouter un addon ». Piste de simplification : fermer le panneau et vider le champ après succès, remplacer automatiquement un addon de même hôte, un seul bouton d'envoi. Une reconfiguration de Marvel (3 catalogues sur 6, lien construit comme la page le ferait) envoyée avec `replaces` a bien remplacé l'addon.

## Défauts et corrections
1. Portail inaccessible depuis un navigateur (ERR_EMPTY_RESPONSE) : limite de 4 connexions par adresse. CORRIGÉ (commit 5dd9052) : 8 par adresse, 24 au total, la plus ancienne connexion de la même adresse est fermée pour servir la nouvelle, idleTimeout 5 s, protection contre les connexions lentes conservée ; tests : 6 connexions keep-alive puis une 7e servie, éviction de la plus ancienne ; spec mise à jour. Revérifié sur l'émulateur : 8 requêtes parallèles = 8 x 200, puis une 9e = 200.
2. « Continuer » affiche l'identifiant brut. Cause trouvée (progression sans titre ni affiche), correctif décrit dans AUDIT-UI, NON fait.
3. Autres défauts de présentation : voir `docs/design/AUDIT-UI.md`, section « Test global sur l'émulateur ».

Note de conduite : pendant le test, un addon Torrentio a été installé sur l'émulateur (confirmations de la TV partagées avec le test du portail de l'utilisateur) ; il a été supprimé à chaque fois et n'a servi à aucune lecture.

## Limites et reste à faire
Sous-titres (F), favoris (G), reprise après force-stop et fin de lecture (H), séries multi-saisons, « épisode suivant », anime, plusieurs films récents/anciens issus de Cinemeta (non installé : pas de catalogue grand public sans lui), défilement en rafales. Ne se vérifie que sur la vraie box : image vidéo, fluidité, sous-titres rendus sur l'image, HEVC.
