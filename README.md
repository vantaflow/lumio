# Lumio

Client média libre (GPL-3.0) pour Android TV, Android, macOS et Windows,
compatible avec le protocole d'addons. Lumio ne fournit, ne suggère et ne
recherche aucune source : l'utilisateur ajoute lui-même ses addons.

## Structure

- `app/` : application Flutter (Android, macOS, Windows), couches `ui` / `data`.
- `packages/lumio_core/` : logique métier pure Dart, testable sans Flutter.
- `scripts/` : garde-fous (`disk-guard.sh`, `check-licenses.sh`, `box-smoke.sh`).
- `docs/` : spécification et plans.

## Mise en route

Prérequis : Flutter 3.41.5, JDK 17, Android SDK (`ANDROID_HOME`).

```sh
cd packages/lumio_core && dart pub get && dart test
cd app && flutter pub get && flutter analyze && flutter test
```

Build Android pour la box (armeabi-v7a) :

```sh
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
bash scripts/disk-guard.sh && bash scripts/box-smoke.sh
```

`box-smoke.sh` construit l'APK release, l'installe sur la box
(`LUMIO_BOX`, défaut `192.168.0.43:5555`) et attend la ligne `LUMIO_READY`.

## Garde-fous

- `scripts/disk-guard.sh` : refuse tout build sous 80 Go libres.
- `scripts/check-licenses.sh` : échoue en nommant toute dépendance AGPL ou dont
  la licence n'est pas dans `scripts/licenses-allow.txt`.
- Les URL d'addons et jetons passent par `SecretStore` et `redactUrl` pour
  toute journalisation.

## Licence

GPL-3.0, voir `LICENSE`.
