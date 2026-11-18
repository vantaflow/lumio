/** Page compagnon d'appairage : HTML minimal, sans script ni ressource externe. */

export type PairPageState = 'form' | 'sent' | 'expired' | 'toolarge';

export const PAIR_PAGE_CSP =
  "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'";

const MESSAGES: Record<PairPageState, string> = {
  form: '',
  sent: 'Envoyé. Vous pouvez retourner sur la télé.',
  expired: 'Ce code est expiré ou déjà utilisé. Affichez un nouveau code sur la télé.',
  toolarge: 'Texte trop long. Envoyez uniquement un lien ou un code court.',
};

// `code` est déjà validé (^[A-Z2-9]{6}$) par l'appelant : aucune valeur utilisateur
// n'est injectée ailleurs, et le contenu envoyé n'est jamais renvoyé.
export function pairPage(code: string, state: PairPageState): string {
  const msg = MESSAGES[state];
  const showForm = state === 'form' || state === 'toolarge';
  return `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Lumio · Saisir depuis le téléphone</title>
<style>
body{margin:0;padding:24px 16px;background:#0e1116;color:#f3f5f7;font:16px/1.5 system-ui,sans-serif}
main{max-width:480px;margin:0 auto}
h1{font-size:24px;margin:0 0 8px}
p{color:#a9b2bf;margin:0 0 16px}
label{display:block;font-weight:600;margin-bottom:8px;color:#f3f5f7}
input[type=text]{box-sizing:border-box;width:100%;min-height:48px;padding:12px;border-radius:10px;border:1px solid #3a4452;background:#161b22;color:#f3f5f7;font-size:16px}
button{margin-top:16px;min-height:48px;width:100%;border:0;border-radius:999px;background:#ffb84d;color:#1a1100;font-size:16px;font-weight:700}
.msg{padding:12px;border-radius:10px;background:#1f2630;color:#f3f5f7}
.code{font-family:ui-monospace,monospace;letter-spacing:2px;color:#ffb84d}
</style>
</head>
<body>
<main>
<h1>Lumio</h1>
<p>Code <span class="code">${code}</span></p>
${msg ? `<p class="msg" role="status">${msg}</p>` : ''}${
    showForm
      ? `<form method="post" action="/pair/${code}" autocomplete="off">
<label for="payload">Lien ou texte à envoyer à la télé</label>
<input id="payload" name="payload" type="text" inputmode="url" autocapitalize="off" autocorrect="off" spellcheck="false" required maxlength="4000">
<button type="submit">Envoyer</button>
</form>`
      : ''
  }
</main>
</body>
</html>`;
}
