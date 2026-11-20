/// URL du manifeste de mise à jour (`{version, apk, sha256, apks?}`), publié
/// comme asset de chaque release GitHub (l'URL `latest` redirige vers la plus
/// récente). Vide = vérification désactivée : la bannière n'apparaît jamais.
const updateManifestUrl =
    'https://github.com/vantaflow/lumio/releases/latest/download/update.json';

/// Adresse du serveur des salles de Watch party (Worker Cloudflare, sans
/// compte). Vide = Watch party masquée. https obligatoire (http accepté
/// seulement pour localhost) ; `--dart-define=PARTY_SERVER_URL=https://...`.
const partyServerUrl = String.fromEnvironment('PARTY_SERVER_URL');

/// Identifiant de l'application Trakt (https://trakt.tv/oauth/applications).
/// C'est une application publique : l'identifiant n'est pas un secret. Il peut
/// être remplacé à la compilation (`--dart-define=TRAKT_CLIENT_ID=...`).
/// Vide = suivi Trakt « non configuré » : rien n'est envoyé.
const traktClientId = String.fromEnvironment(
  'TRAKT_CLIENT_ID',
  defaultValue: 'L6UakaCWI9VuQZevNkAOzKV77d4ob9XRnfLZOPds9Bs',
);

/// Secret de l'application Trakt : facultatif (le flux par code d'appareil
/// n'en a pas besoin). Vide = aucun champ `client_secret` n'est envoyé.
const traktClientSecret = String.fromEnvironment('TRAKT_CLIENT_SECRET');
