# Contribuer à Lumio

Merci de votre intérêt. Lumio est en développement actif ; avant un gros
changement, ouvrez d'abord une issue pour en discuter.

## Règles du projet

- Aucun addon préinstallé ou suggéré, aucun scraper, aucune recherche de
  sources dans le client. Les contributions qui vont dans ce sens seront
  refusées.
- Aucun nom, logo ou visuel proche de Stremio.
- Les URL d'addons et les jetons sont des secrets : jamais en clair dans les
  journaux (`redactUrl`), la base locale ou le serveur.
- Licence GPL-3.0 ; aucune dépendance AGPL (`scripts/check-licenses.sh`).

## Mise en route

Voir [docs/developpement.md](docs/developpement.md) : prérequis, commandes de
test des trois paquets, scripts.

## Flux de travail

1. Créez une branche à partir de la branche principale.
2. Écrivez d'abord le test qui échoue, puis le code.
3. Lancez les tests et l'analyse des paquets modifiés (`dart analyze
   --fatal-infos`, `flutter analyze --fatal-infos`, `dart format`).
4. Commits en français, au format `type: description` (`feat`, `fix`, `test`,
   `docs`, `chore`), avec une portée facultative : `feat(core): …`.
5. Ouvrez une pull request en remplissant le modèle ; la CI doit passer.

## Contenus de test

N'utilisez que des contenus libres de droits dans les tests, exemples et
captures (par exemple les films de la Blender Foundation).

## Sécurité

Pour une faille, suivez [SECURITY.md](SECURITY.md), pas d'issue publique.
