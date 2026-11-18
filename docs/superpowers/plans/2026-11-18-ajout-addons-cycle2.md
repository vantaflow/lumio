# Ajout d'addons simplifié — plan (cycle 2)

**Spec :** `docs/superpowers/specs/2026-11-18-ajout-addons-design-cycle2.md`. Contraintes globales identiques au cycle 1 (`docs/superpowers/plans/2026-11-18-lumio.md`).

### Task 1: Analyse des liens d'installation (lumio_core)
- Create `packages/lumio_core/lib/src/addons/install_link.dart` : `Uri? parseInstallLink(String input)` → URL https du manifest ou null. Règles de la spec (stremio:// → https://, lumio://install?url=…, http(s) brut finissant par manifest.json, taille ≤ 2 048, schémas autres refusés). Tests : stremio://h/a/manifest.json → https://h/a/manifest.json ; lumio://install?url=… ; javascript:/file:/ftp: → null ; texte avec URL entourée de mots → URL extraite ; URL sans manifest.json → `normalizeAddonUrl` appliqué.
### Task 2: Liens profonds, partage et presse-papiers (app)
- Android : filtres d'intention VIEW (stremio, lumio) et SEND text/plain dans `AndroidManifest.xml` ; réception via `app_links` (liens) et `receive_sharing_intent` ou canal maison (partage) — choisir le paquet maintenu disponible dans le cache pub, sinon MethodChannel minimal dans `MainActivity`.
- `InstallLinkHandler` : à réception (démarrage ou en cours), si profil enfant → PIN parent ; ouvrir le dialogue d'ajout prérempli (aperçu, « Installer » à confirmer).
- Dialogue d'ajout : proposition « Utiliser le lien copié » si le presse-papiers contient un lien d'installation plausible.
- Tests widget : lien reçu → dialogue prérempli sans installation automatique ; profil enfant → PIN demandé ; presse-papiers → bouton proposé ; texte partagé avec URL → prérempli. Chaînes fr/en.
