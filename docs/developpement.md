# Développement

## Prérequis

- Flutter 3.41.5 (Dart 3.11), identique à la CI.
- Node 24 pour le backend.
- JDK 17 et Android SDK pour les builds Android : définir `ANDROID_HOME` et
  `JAVA_HOME` (JDK 17).
- `adb` pour installer sur un appareil.
- Python 3 pour `scripts/check-licenses.sh`.

Adaptez les chemins à votre machine, par exemple :

```sh
export ANDROID_HOME=<chemin-du-SDK-Android>
export JAVA_HOME=<chemin-du-JDK-17>
```

## Tests

Les trois paquets se testent séparément.

```sh
# Cœur Dart
cd packages/lumio_core && dart pub get && dart analyze --fatal-infos && dart test

# Application Flutter
cd app && flutter pub get \
  && dart format --output=none --set-exit-if-changed lib test \
  && flutter analyze --fatal-infos && flutter test

# Backend
cd backend && npm ci && npx vitest run && npm run typecheck
```

## Scripts

- `scripts/disk-guard.sh` : refuse de continuer sous 80 Go libres
  (`LUMIO_MIN_FREE_GB` pour changer le seuil). À lancer avant un build.
- `scripts/check-licenses.sh` : vérifie la licence de toutes les dépendances
  Dart (transitives comprises). Une dépendance AGPL, de licence inconnue ou
  absente de `scripts/licenses-allow.txt` fait échouer le script en la nommant.
  `scripts/test-check-licenses.sh` teste ce contrôle.
- `scripts/box-smoke.sh` : construit l'APK release, l'installe sur la box,
  lance l'application et attend la ligne `LUMIO_READY` dans logcat. Variables :
  - `LUMIO_BOX` : adresse adb de la box, par exemple `<IP-de-la-box>:5555`
    (une valeur par défaut propre à la machine du mainteneur existe dans le
    script, remplacez-la) ;
  - `LUMIO_SMOKE_TIMEOUT` : délai en secondes (60 par défaut) ;
  - `LUMIO_BUILD_ARGS` : options de build supplémentaires, par exemple
    `--dart-define=LUMIO_DEBUG_TORRENT=1` pour l'écran de debug des torrents.

```sh
LUMIO_BOX=<IP-de-la-box>:5555 bash scripts/box-smoke.sh
```

## Conventions

- Commits en français, format `type: description` ou `type(portée): …`
  (`feat`, `fix`, `test`, `docs`, `chore`).
- Développement guidé par les tests : écrire le test qui échoue, puis le code.
- Ne jamais journaliser une URL d'addon ni un jeton : utiliser `redactUrl`.
- Aucune dépendance AGPL ; toute nouvelle dépendance doit passer
  `check-licenses.sh`.
- Ne pas commiter les dossiers `build/`.

## Intégration continue

`.github/workflows/ci.yml` s'exécute à chaque push et pull request :
- `core` : analyse et tests de `lumio_core` ;
- `app` : format, analyse, tests et build APK release 32 bits ;
- `backend` : typecheck et tests vitest du serveur des salles (actif dès que
  `backend/package-lock.json` existe) ;
- `licenses` : contrôle des licences.
