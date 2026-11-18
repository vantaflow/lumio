# Installation

Il n'y a pas encore de version publiée de Lumio. Cette page décrit comment
construire et installer l'application à partir des sources. Une page de
téléchargement sera ajoutée avec la première version.

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

## macOS et Windows

Le code est partagé et l'intégration continue compile les deux cibles, mais
aucune version desktop n'est publiée ni testée sur machine réelle à ce stade.

## Mises à jour

Un vérificateur de mises à jour existe dans le cœur (manifeste de version avec
empreinte SHA-256). Son câblage dans l'interface et l'hébergement du manifeste
restent à faire.
