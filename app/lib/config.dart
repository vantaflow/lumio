/// URL du manifeste de mise à jour (`{version, apk, sha256}`).
/// Vide = vérification désactivée : la bannière n'apparaît jamais.
const updateManifestUrl = '';

/// URL du backend Lumio (Worker : appairage mobile, synchro, salons).
/// Vide = fonctions en ligne masquées (bouton « Saisir depuis mon téléphone »
/// absent). Doit être en https (http accepté seulement pour localhost).
const backendUrl = '';

/// Identifiants de l'application Trakt (https://trakt.tv/oauth/applications).
/// Vides = suivi Trakt « non configuré » : rien n'est envoyé.
const traktClientId = '';
const traktClientSecret = '';

/// Identifiant de l'application Simkl (https://simkl.com/settings/developer/).
/// Vide = suivi Simkl « non configuré » : rien n'est envoyé.
const simklClientId = '';
