# Lumio — ajout d'addons simplifié (cycle 2)

Demande utilisateur : « L'ajout des addons doit être facile, simple ».

Déjà livré au cycle 1 : écran unique (coller, aperçu, « Installer »), appairage par téléphone (QR), assistant de premier lancement.

## Ajouts de ce cycle
1. **Liens d'installation** : `stremio://<hôte>/<chemin>/manifest.json` et `lumio://install?url=<url encodée>` ouvrent Lumio sur l'écran d'ajout prérempli (aperçu, l'utilisateur confirme « Installer »). `stremio://` est converti en `https://` (même hôte et chemin). Android : filtres d'intention `VIEW` pour les schémas `stremio` et `lumio` (catégories BROWSABLE/DEFAULT) ; desktop : schéma `lumio://` enregistré quand la plateforme le permet (sinon collage). Si Stremio est installé, Android laisse l'utilisateur choisir.
2. **Partage Android** : intention `SEND` `text/plain` → si le texte contient une URL d'addon (http(s) ou stremio://), écran d'ajout prérempli.
3. **Presse-papiers** : à l'ouverture de l'écran d'ajout, si le presse-papiers contient une URL d'addon plausible (se termine par `manifest.json` ou schéma `stremio://`), proposer « Utiliser le lien copié » (jamais de préremplissage silencieux d'une URL inattendue).

## Règles
- Aucune installation automatique : toujours l'aperçu puis « Installer » ; garde d'URL et confirmation réseau privé inchangées.
- Profil enfant : l'écran d'ajout reste protégé par le PIN parent.
- Aucun addon suggéré ; aucune URL journalisée (redactUrl).
- `lumio://install` n'accepte qu'un paramètre `url` http(s)/stremio, taille ≤ 2 048.
