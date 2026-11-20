# Installation

## Télécharger l'APK (recommandé)

Page de téléchargement : <https://vantaflow.github.io/lumio/>. Sinon, prenez
l'APK de la [dernière release](https://github.com/vantaflow/lumio/releases/latest) :

| Appareil | Fichier |
|---|---|
| Box et TV Android 32 bits (la plupart des box Google TV d'entrée de gamme) | `lumio-armeabi-v7a.apk` |
| Téléphones, tablettes et box 64 bits | `lumio-arm64-v8a.apk` |

1. Copiez l'APK sur l'appareil : application **Downloader** (saisir l'adresse
   du fichier), clé USB, ou `adb install`.
2. Ouvrez le fichier et autorisez l'installation depuis cette source
   (« Sources inconnues » / « Installer des applications inconnues »).
3. Vérification facultative : comparez la somme SHA-256 du fichier avec
   `SHA256SUMS.txt` de la release (`shasum -a 256 lumio-*.apk`).

Les APK sont signés avec la clé de release de Lumio : une version signée par
une autre clé (par exemple une version de test) ne s'installe pas par-dessus ;
il faut alors désinstaller la précédente, ce qui efface ses données (faites
d'abord une sauvegarde locale dans les Réglages).

## Construire depuis les sources

## Android et Android TV

Prérequis : voir [developpement.md](developpement.md) (Flutter 3.41.5, JDK 17,
Android SDK).

```sh
cd app
flutter pub get
flutter build apk --release --target-platform android-arm      # box 32 bits
# ou, pour un appareil 64 bits :
flutter build apk --release --target-platform android-arm64
```

L'APK est produit dans `app/build/app/outputs/flutter-apk/app-release.apk`.

### Installer par adb

Activez les options pour développeurs et le débogage réseau sur l'appareil,
puis :

```sh
adb connect <IP-de-la-box>:5555
adb -s <IP-de-la-box>:5555 install -r app/build/app/outputs/flutter-apk/app-release.apk
```

### Installer sans adb

Copiez l'APK sur l'appareil (clé USB, partage réseau, application de
téléchargement) et ouvrez-le ; autorisez l'installation d'applications
d'origine inconnue si le système le demande.

## Android TV box

La cible de test est une box Android 14 32 bits (armeabi-v7a) avec 2 Go de RAM.
Le script `scripts/box-smoke.sh` construit, installe et vérifie que
l'application démarre (voir [developpement.md](developpement.md)). L'application
déclare l'entrée de lanceur TV (Leanback).

## Mises à jour

L'accueil affiche une bannière quand une release plus récente existe. Elle lit
`update.json`, publié avec chaque release
(`https://github.com/vantaflow/lumio/releases/latest/download/update.json`) :
`{version, apk, sha256, apks: {<abi>: {apk, sha256}}}`. L'APK proposé est celui
de l'architecture de l'appareil ; le téléchargement s'ouvre dans le navigateur
et l'installation se fait par-dessus l'application existante (mêmes données).

## Publier une version (mainteneur)

1. Mettre à jour `version:` dans `app/pubspec.yaml` et ajouter la section
   `## [X.Y.Z]` au `CHANGELOG.md`.
2. `git tag vX.Y.Z && git push origin vX.Y.Z` : la workflow `release.yml` lance
   les tests, construit et signe les deux APK, vérifie la signature, puis crée
   la release (APK, `SHA256SUMS.txt`, `update.json`).
3. La clé de signature n'est jamais dans le dépôt : secrets GitHub
   `LUMIO_KEYSTORE_BASE64`, `LUMIO_KEYSTORE_PASSWORD`, `LUMIO_KEY_PASSWORD`,
   `LUMIO_KEY_ALIAS`. En local, `app/android/key.properties` (ignoré par git)
   avec `storeFile`, `storePassword`, `keyPassword`, `keyAlias` ; sans clé, le
   build retombe sur la clé de debug. **Perdre la clé empêche toute mise à
   jour des appareils déjà installés** : la sauvegarder hors ligne.
