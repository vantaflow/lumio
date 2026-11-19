// Page web servie par la box : HTML, CSS et JS embarqués (aucune ressource
// externe, aucun `innerHTML`, aucun style en ligne), maquettes M05a (Ajouter),
// M05b (Régler) et M05c (Mes addons). Deux onglets en bas seulement ; chaque
// écran dit quoi faire ensuite, sans jargon. Textes en français et en anglais ;
// la langue est celle de l'application.

String phoneIndexHtml(String lang) {
  final l = lang == 'en' ? 'en' : 'fr';
  return _html.replaceFirst('{{LANG}}', l);
}

const phoneCss = r'''
*{box-sizing:border-box}
@font-face{font-family:'Manrope';src:url(/fonts/manrope.ttf) format('truetype');font-weight:200 800;font-display:swap}
@font-face{font-family:'Bricolage Grotesque';src:url(/fonts/bricolage.ttf) format('truetype');font-weight:200 800;font-display:swap}
html,body{margin:0;background:#0E1116}
body{color:#F3F5F7;font-family:'Manrope',system-ui,sans-serif;font-size:16px;-webkit-text-size-adjust:100%}
.ph{max-width:480px;min-height:100vh;margin:0 auto;padding:20px 20px 150px;display:flex;flex-direction:column;gap:14px}
.hd{font-family:'Bricolage Grotesque','Manrope',system-ui,sans-serif;font-weight:700;margin:0}
.sm{font-size:14px;color:#A9B2BF;line-height:1.45}
label.l{font-size:14px;color:#F3F5F7;font-weight:600;line-height:1.4}
.in{height:52px;width:100%;border-radius:12px;background:#161B22;border:2px solid #3A4452;padding:0 14px;font:inherit;font-size:15px;color:#F3F5F7}
.in::placeholder{color:#A9B2BF;opacity:1}
.in:focus-visible,.hl:focus-visible,.bt:focus-visible,.ib:focus-visible,.lk:focus-visible,.sw:focus-visible,.chp:focus-visible,.tab:focus-visible,.gh:focus-visible,.bk:focus-visible,.tg:focus-visible{outline:3px solid #FFB84D;outline-offset:2px}
.bt{height:52px;border-radius:26px;border:0;font-family:inherit;font-size:16px;font-weight:700;cursor:pointer;width:100%}
.bt:disabled{opacity:.5;cursor:default}
.b2{background:#2A3340;color:#F3F5F7}
.b1{background:#FFB84D;color:#1A1100}
.bd{background:#FF7A70;color:#1A1100}
.row{display:flex;gap:10px}
.lk{display:inline-flex;align-items:center;gap:6px;color:#4FD1C5;font-weight:700;font-size:14px;text-decoration:none;min-height:44px}
.col{display:flex;flex-direction:column;gap:14px}
.hidden{display:none!important}
.h22{font-size:22px}.h26{font-size:26px}
.mt4{margin-top:4px}.mt8{margin-top:8px}
.lst{list-style:none;margin:0;padding:0}
.top{display:flex;align-items:center;justify-content:space-between;gap:10px}
.brand{display:flex;align-items:center;gap:10px}
.on-tv{display:inline-flex;align-items:center;gap:6px;font-size:13px;color:#5BD68A;font-weight:600}
.dot{width:8px;height:8px;border-radius:4px;background:#5BD68A;flex:none;display:inline-block}
.dot.am{background:#FFB84D}.dot.rd{background:#FF7A70}.dot.gr{background:#7E8896}
.sch{height:44px;border-radius:12px;background:#161B22;border:2px solid #2A3340;padding:0 12px 0 40px;width:100%;font:inherit;font-size:15px;color:#F3F5F7}
.sch::placeholder{color:#A9B2BF;opacity:1}
.sw0{position:relative}
.sw0 svg{position:absolute;left:12px;top:13px}
.chips{display:flex;gap:8px;overflow-x:auto;padding-bottom:4px;scrollbar-width:none}
.chp{height:40px;border-radius:20px;padding:0 14px;border:0;background:#1C222B;color:#F3F5F7;font:inherit;font-size:14px;font-weight:600;white-space:nowrap;cursor:pointer;flex:none}
.chp.on{background:#FFB84D;color:#1A1100;font-weight:700}
.card{border-radius:16px;background:#161B22;padding:12px;display:flex;flex-direction:column;gap:10px}
.ar{display:flex;align-items:center;gap:12px;min-height:48px}
.ar.off .nm{opacity:.55}
.lg{position:relative;overflow:hidden;width:44px;height:44px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:20px;color:#0E1116;font-family:'Bricolage Grotesque',system-ui,sans-serif;flex:none}
.lg img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;background:#0E1116}
.nm{font-weight:700;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tx{flex:1;min-width:0}
.d1{font-size:14px;color:#A9B2BF;line-height:1.35;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.bdg{color:#5BD68A;font-size:13px;font-weight:700;flex:none}
.cb{height:40px;width:auto;padding:0 16px;font-size:14px;flex:none}
.gh{background:none;border:2px dashed #3A4452;border-radius:16px;color:#F3F5F7;height:52px;font:600 15px 'Manrope',system-ui,sans-serif;width:100%;cursor:pointer}
.pn{border-radius:16px;background:#161B22;border:2px solid #FFB84D;padding:14px;display:flex;flex-direction:column;gap:12px}
.ib{height:40px;padding:0 14px;border-radius:20px;background:#1C222B;border:0;color:#F3F5F7;font:600 13px 'Manrope',system-ui,sans-serif;cursor:pointer}
.ib:disabled{opacity:.35;cursor:default}
.ib.dg{color:#FF7A70}
.ib.md{background:#2A3340}
.acts{display:flex;gap:8px;flex-wrap:wrap}
.tg{width:44px;height:26px;border-radius:13px;position:relative;flex:none;border:0;background:#3A4452;cursor:pointer;padding:0}
.tg i{position:absolute;top:3px;left:3px;width:20px;height:20px;border-radius:10px;background:#F3F5F7;transition:left .15s}
.tg[aria-checked=true]{background:#FFB84D}
.tg[aria-checked=true] i{left:21px}
.st{display:flex;gap:14px}
.n{width:32px;height:32px;border-radius:16px;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:15px;flex:none;background:#2A3340;color:#F3F5F7}
.st.act .n{background:#FFB84D;color:#1A1100}
.st.done .n{background:#5BD68A;color:#0E1116}
.stt{font-weight:700}
.bk{width:40px;height:40px;border-radius:20px;background:#1C222B;border:0;display:flex;align-items:center;justify-content:center;cursor:pointer;padding:0;flex:none}
.msg{border-radius:14px;padding:12px 14px;font-size:14px;line-height:1.4;background:#2A3340}
.msg.ok{border:2px solid #5BD68A}
.msg.er{border:2px solid #FF7A70}
.msg.wt{border:2px solid #FFB84D}
.toast{position:fixed;left:20px;right:20px;bottom:80px;max-width:440px;margin:0 auto;z-index:5}
.nav{position:fixed;left:0;right:0;bottom:0;height:64px;border-top:1px solid #1C222B;background:#0B0E12;display:flex;z-index:4}
.tab{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;font:600 12px 'Manrope',system-ui,sans-serif;color:#A9B2BF;background:none;border:0;cursor:pointer}
.tab svg{stroke:#A9B2BF}
.tab.on{color:#FFB84D}
.tab.on svg{stroke:#FFB84D}
.code{letter-spacing:6px;text-align:center;font-size:24px}
.hl{background:none;border:0;color:#FFB84D;font:700 14px 'Manrope',system-ui,sans-serif;cursor:pointer;min-height:44px;padding:0 4px}
.tkc{font-family:'Bricolage Grotesque','Manrope',system-ui,sans-serif;font-weight:700;font-size:40px;letter-spacing:6px;background:#0E1116;border-radius:14px;padding:12px 18px;text-align:center}
.ctr{align-items:center;text-align:center}
.lka{display:inline-flex;align-items:center;justify-content:center;text-decoration:none;height:40px;padding:0 14px;border-radius:20px;background:#2A3340;color:#F3F5F7;font:600 13px 'Manrope',system-ui,sans-serif}
.lka:focus-visible{outline:3px solid #FFB84D;outline-offset:2px}
.tkhid{position:fixed;left:-1000px;opacity:0}
.hn{font-weight:700;color:#F3F5F7}
.nt{color:#5BD68A;font-size:14px;line-height:1.4}
@media (prefers-reduced-motion:reduce){.tg i{transition:none}}
''';

const phoneJs = r'''
(function () {
  'use strict';
  var T = {
    fr: {
      onTv: 'Connecté à votre TV',
      addTitle: 'Ajouter un addon',
      addHelp: 'Choisissez un addon, appuyez sur Installer, puis confirmez sur la TV.',
      search: 'Chercher un addon',
      haveLink: "J'ai déjà un lien d'addon",
      linkTitle: "Installer avec un lien",
      linkHelp: "Collez le lien de l'addon (il commence par https:// ou stremio://). La TV vous demandera de confirmer.",
      linkLabel: "Lien de l'addon",
      browse: 'Chercher des addons sur stremio-addons.net',
      browseHint: 'Sur ce site, appuyez sur « Copier le lien », puis revenez ici.',
      pasteHint: 'Appuyez longuement dans le champ, puis choisissez « Coller ».',
      sendTv: 'Installer sur la TV',
      close: 'Fermer',
      catMore: 'Plus…',
      catRefresh: 'Actualiser',
      catLoadMore: 'Voir plus',
      catInstalled: 'Installé',
      catOffline: 'Pas de connexion : voici la dernière liste enregistrée.',
      catFallback: 'Liste réduite : le site des addons ne répond pas pour le moment.',
      catEmpty: 'Aucun addon ne correspond.',
      catLoadError: "La liste des addons n'est pas disponible pour le moment. Réessayez dans un instant.",
      install: 'Installer',
      setup: 'Régler',
      change: 'Changer les réglages',
      cfgBefore: "Régler avant d'installer",
      cfgIntro: "Cet addon a besoin de quelques choix (langue, catalogues…). Trois étapes :",
      s1: 'Ouvrez la page de réglage',
      s1d: "Elle s'ouvre dans un nouvel onglet.",
      reopen: 'Rouvrir la page ↗',
      s2: 'Faites vos choix, puis copiez le lien',
      s3: 'Revenez ici et collez-le',
      cfgLabel: "Lien de l'addon réglé",
      cfgHint: 'Lumio reconnaît les liens stremio:// et https://…/manifest.json.',
      mineTitle: 'Mes addons',
      mineHelp: "Le premier de la liste est consulté en premier pour trouver une vidéo.",
      none: "Vous n'avez pas encore d'addon. Allez dans « Ajouter » pour en choisir un.",
      up: 'Monter',
      down: 'Descendre',
      del: 'Supprimer',
      cancel: 'Annuler',
      confirmDel: 'Supprimer « {n} » ?',
      enabled: 'Activé',
      disabled: 'Désactivé',
      broken: 'Illisible : supprimez-le puis réinstallez-le',
      reliable: 'Fonctionne bien',
      slow: 'Lent',
      failing: 'Ne répond pas',
      unknown: 'Pas encore testé',
      loginTitle: 'Code de sécurité',
      loginHelp: 'Saisissez le code à 6 chiffres affiché sur la TV.',
      loginBtn: 'Se connecter',
      badCode: 'Ce code est incorrect. Regardez le code affiché sur la TV.',
      locked: 'Trop d’essais. Attendez {s} secondes, puis saisissez le nouveau code affiché sur la TV.',
      waiting: 'Regardez la TV : confirmez l’installation de {n}.',
      waitingLink: 'Regardez la TV : confirmez l’installation.',
      installed: '{n} est installé. Retrouvez-le dans « Mes addons ».',
      installedNoName: 'Addon installé. Retrouvez-le dans « Mes addons ».',
      failed: "L'installation n'a pas marché. Vérifiez le lien, puis réessayez.",
      cancelled: "Vous avez refusé sur la TV : rien n'a été installé.",
      expired: "La TV n'a pas reçu de confirmation à temps. Appuyez de nouveau sur Installer.",
      invalidLink: "Ce lien ne ressemble pas à un lien d'addon. Il commence par https:// ou stremio:// et finit souvent par manifest.json.",
      emptyLink: "Collez d'abord le lien de l'addon.",
      closed: "La connexion avec la TV est coupée. Sur la TV, ouvrez « Gérer depuis le téléphone » et scannez à nouveau le code.",
      generic: 'Un problème est survenu. Réessayez dans un instant.',
      rate: 'Un peu de patience : réessayez dans quelques secondes.',
      notCfg: "Cet addon n'a pas de page de réglage : appuyez sur Installer.",
      tabTrakt: 'Trakt',
      helpBtn: 'Aide',
      s2d: 'Sur la page de réglage, touchez « Copier le lien » (ou « Install », ou « Copy link » si la page est en anglais).',
      s2tip: "Si « Install » est un simple lien qui ne copie rien : appui long dessus, puis « Copier l'adresse du lien ».",
      keyNote: 'Votre clé reste chiffrée sur la TV : elle ne revient jamais sur ce téléphone.',
      tvConfirm: "Après « Installer sur la TV », regardez la TV et confirmez : rien n'est installé sans votre accord. Le lien reste sur la TV, chiffré.",
      mineReplace: "Si vous réglez un addon à nouveau, le nouveau lien remplace l'ancien : vous n'en gardez qu'un seul.",
      traktTitle: 'Trakt',
      traktHelp: "Enregistrez vos lectures sur votre compte Trakt. Le code se saisit sur trakt.tv ; aucun jeton n'est jamais envoyé à ce téléphone.",
      traktOn: 'Connecté à Trakt',
      traktOnHelp: 'Vos lectures sont enregistrées sur votre compte.',
      traktDisc: 'Déconnecter',
      traktDiscAsk: 'Déconnecter Trakt ? Vos lectures ne seront plus enregistrées.',
      traktNot: 'Non connecté',
      traktNotHelp: "Touchez le bouton : un code s'affiche ici.",
      traktConnect: 'Connecter Trakt',
      traktEnter: 'Saisissez ce code sur trakt.tv/activate',
      traktCopy: 'Copier le code',
      traktOpen: 'Ouvrir trakt.tv',
      traktWaiting: 'En attente de votre autorisation…',
      traktOff: "Trakt n'est pas configuré dans cette version de Lumio : rien n'est envoyé.",
      traktBlocked: "Profil enfant : un parent doit d'abord autoriser le suivi sur la TV (Réglages › Suivi).",
      traktDenied: "Autorisation refusée sur Trakt. Touchez « Connecter Trakt » pour réessayer.",
      traktExpired: 'Le code a expiré. Touchez « Connecter Trakt » pour en obtenir un nouveau.',
      traktUnavailable: "Trakt est injoignable pour le moment. Réessayez dans un instant.",
      traktDone: 'Trakt est connecté.',
      traktSteps: 'Étapes',
      tk1: 'Touchez « Connecter Trakt » : un code s’affiche.',
      tk2: 'Ouvrez trakt.tv/activate (le bouton ci-dessous).',
      tk3: 'Saisissez le code.',
      tk4: 'Acceptez sur Trakt : tout se met à jour ici et sur la TV.',
      copied: 'Code copié.',
      helpTitle: 'Aide',
      helpIntro: 'Des guides pas à pas, sans jargon.',
      hAdd: 'Ajouter un addon', hAdd1: 'Touchez « Ajouter ».', hAdd2: 'Choisissez un addon et touchez « Installer » (ou collez un lien).', hAdd3: 'Regardez la TV et confirmez.',
      hSet: 'Régler un addon', hSet1: 'Touchez « Régler » sur la fiche de l’addon : sa page de réglage s’ouvre.', hSet2: 'Faites vos choix, puis touchez « Copier le lien » (ou « Install », ou « Copy link »).', hSet3: 'Si « Install » est un lien qui ne copie rien : appui long dessus, puis « Copier l’adresse du lien ».', hSet4: 'Revenez ici, collez le lien et touchez « Installer sur la TV ».', hSet5: 'Confirmez sur la TV.',
      hPortal: 'Le portail du téléphone', hPortal1: 'La TV et le téléphone sont sur le même Wi-Fi.', hPortal2: 'Gardez l’écran « Gérer depuis le téléphone » ouvert sur la TV.', hPortal3: 'Si la connexion est coupée, scannez de nouveau le code de la TV.',
      hTrakt: 'Trakt', hProf: 'Profils et code PIN', hProf1: 'Ils se règlent sur la TV : Réglages › Profils › Gérer les profils.', hProf2: 'Le code PIN parent protège les profils verrouillés.',
      hSubs: 'Sous-titres', hSubs1: 'Pendant la lecture, ouvrez « Pistes et sous-titres » sur la TV.', hSubs2: 'Réglages › Lecture : choisissez la langue préférée.',
      tabAdd: 'Ajouter',
      tabMine: 'Mes addons',
      back: 'Retour',
      types: { movie: 'Films', series: 'Séries', anime: 'Anime', tv: 'TV', channel: 'Chaînes', other: 'Autre' }
    },
    en: {
      onTv: 'Connected to your TV',
      addTitle: 'Add an addon',
      addHelp: 'Pick an addon, tap Install, then confirm on the TV.',
      search: 'Search addons',
      haveLink: 'I already have an addon link',
      linkTitle: 'Install with a link',
      linkHelp: 'Paste the addon link (it starts with https:// or stremio://). The TV will ask you to confirm.',
      linkLabel: 'Addon link',
      browse: 'Find addons on stremio-addons.net',
      browseHint: 'On that site, tap “Copy link”, then come back here.',
      pasteHint: 'Long-press in the field, then choose “Paste”.',
      sendTv: 'Install on the TV',
      close: 'Close',
      catMore: 'More…',
      catRefresh: 'Refresh',
      catLoadMore: 'Show more',
      catInstalled: 'Installed',
      catOffline: 'No connection: here is the last saved list.',
      catFallback: 'Short list: the addon website is not answering right now.',
      catEmpty: 'No addon matches.',
      catLoadError: 'The addon list is not available right now. Try again in a moment.',
      install: 'Install',
      setup: 'Set up',
      change: 'Change settings',
      cfgBefore: 'Set up before installing',
      cfgIntro: 'This addon needs a few choices (language, catalogues…). Three steps:',
      s1: 'Open the setup page',
      s1d: 'It opens in a new tab.',
      reopen: 'Reopen the page ↗',
      s2: 'Make your choices, then copy the link',
      s3: 'Come back here and paste it',
      cfgLabel: 'Link of the set-up addon',
      cfgHint: 'Lumio understands stremio:// and https://…/manifest.json links.',
      mineTitle: 'My addons',
      mineHelp: 'The first one in the list is asked first to find a video.',
      none: 'You have no addon yet. Go to “Add” to pick one.',
      up: 'Move up',
      down: 'Move down',
      del: 'Delete',
      cancel: 'Cancel',
      confirmDel: 'Delete “{n}”?',
      enabled: 'On',
      disabled: 'Off',
      broken: 'Unreadable: delete it, then install it again',
      reliable: 'Working well',
      slow: 'Slow',
      failing: 'Not answering',
      unknown: 'Not tested yet',
      loginTitle: 'Security code',
      loginHelp: 'Enter the 6-digit code shown on the TV.',
      loginBtn: 'Sign in',
      badCode: 'That code is wrong. Check the code shown on the TV.',
      locked: 'Too many tries. Wait {s} seconds, then enter the new code shown on the TV.',
      waiting: 'Look at the TV: confirm the installation of {n}.',
      waitingLink: 'Look at the TV: confirm the installation.',
      installed: '{n} is installed. Find it in “My addons”.',
      installedNoName: 'Addon installed. Find it in “My addons”.',
      failed: 'The installation did not work. Check the link, then try again.',
      cancelled: 'You declined on the TV: nothing was installed.',
      expired: 'The TV did not get a confirmation in time. Tap Install again.',
      invalidLink: 'That does not look like an addon link. It starts with https:// or stremio:// and often ends with manifest.json.',
      emptyLink: 'Paste the addon link first.',
      closed: 'The connection with the TV was lost. On the TV, open “Manage from your phone” and scan the code again.',
      generic: 'Something went wrong. Try again in a moment.',
      rate: 'Please wait a few seconds and try again.',
      notCfg: 'This addon has no setup page: tap Install.',
      tabTrakt: 'Trakt',
      helpBtn: 'Help',
      s2d: 'On the setup page, tap “Copy link” (or “Install”, or “Copy link” if the page is in English).',
      s2tip: 'If “Install” is a plain link that copies nothing: long-press it, then “Copy link address”.',
      keyNote: 'Your key stays encrypted on the TV: it never comes back to this phone.',
      tvConfirm: 'After “Install on the TV”, look at the TV and confirm: nothing is installed without your approval. The link stays on the TV, encrypted.',
      mineReplace: 'If you set an addon up again, the new link replaces the old one: you keep only one.',
      traktTitle: 'Trakt',
      traktHelp: 'Save your viewing on your Trakt account. The code is entered on trakt.tv; no token is ever sent to this phone.',
      traktOn: 'Connected to Trakt',
      traktOnHelp: 'Your viewing is saved on your account.',
      traktDisc: 'Disconnect',
      traktDiscAsk: 'Disconnect Trakt? Your viewing will no longer be saved.',
      traktNot: 'Not connected',
      traktNotHelp: 'Tap the button: a code is shown here.',
      traktConnect: 'Connect Trakt',
      traktEnter: 'Enter this code on trakt.tv/activate',
      traktCopy: 'Copy the code',
      traktOpen: 'Open trakt.tv',
      traktWaiting: 'Waiting for your approval…',
      traktOff: 'Trakt is not set up in this version of Lumio: nothing is sent.',
      traktBlocked: 'Child profile: a parent must first allow tracking on the TV (Settings › Tracking).',
      traktDenied: 'Approval refused on Trakt. Tap “Connect Trakt” to try again.',
      traktExpired: 'The code expired. Tap “Connect Trakt” to get a new one.',
      traktUnavailable: 'Trakt cannot be reached right now. Try again in a moment.',
      traktDone: 'Trakt is connected.',
      traktSteps: 'Steps',
      tk1: 'Tap “Connect Trakt”: a code is shown.',
      tk2: 'Open trakt.tv/activate (the button below).',
      tk3: 'Enter the code.',
      tk4: 'Accept on Trakt: everything updates here and on the TV.',
      copied: 'Code copied.',
      helpTitle: 'Help',
      helpIntro: 'Step-by-step guides, no jargon.',
      hAdd: 'Add an addon', hAdd1: 'Tap “Add”.', hAdd2: 'Pick an addon and tap “Install” (or paste a link).', hAdd3: 'Look at the TV and confirm.',
      hSet: 'Set up an addon', hSet1: 'Tap “Set up” on the addon card: its setup page opens.', hSet2: 'Make your choices, then tap “Copy link” (or “Install”).', hSet3: 'If “Install” is a link that copies nothing: long-press it, then “Copy link address”.', hSet4: 'Come back here, paste the link and tap “Install on the TV”.', hSet5: 'Confirm on the TV.',
      hPortal: 'The phone portal', hPortal1: 'The TV and the phone are on the same Wi-Fi.', hPortal2: 'Keep the “Manage from your phone” screen open on the TV.', hPortal3: 'If the connection drops, scan the TV code again.',
      hTrakt: 'Trakt', hProf: 'Profiles and PIN', hProf1: 'They are set up on the TV: Settings › Profiles › Manage profiles.', hProf2: 'The parent PIN protects locked profiles.',
      hSubs: 'Subtitles', hSubs1: 'During playback, open “Tracks and subtitles” on the TV.', hSubs2: 'Settings › Playback: pick the preferred language.',
      tabAdd: 'Add',
      tabMine: 'My addons',
      back: 'Back',
      types: { movie: 'Movies', series: 'Series', anime: 'Anime', tv: 'TV', channel: 'Channels', other: 'Other' }
    }
  };
  var lang = document.documentElement.lang === 'en' ? 'en' : 'fr';
  var t = T[lang];
  var COLORS = ['#4FD1C5', '#FFB84D', '#FF7A70', '#7AA2FF', '#5BD68A'];
  var csrf = '';
  var addons = [];
  var confirming = null;
  var catalog = [];
  var deepAddon = null, deepRef = null;
  var cat = { chip: 'official', more: null, page: 1, hasMore: false, chips: [], moreList: [], busy: false };
  var replaces = null;
  var pollTimer = null;
  var query = '';
  var $ = function (id) { return document.getElementById(id); };

  function fmt(s, o) {
    return s.replace(/\{(\w+)\}/g, function (_, k) { return o[k]; });
  }
  function i18n() {
    var nodes = document.querySelectorAll('[data-t]');
    for (var i = 0; i < nodes.length; i++) nodes[i].textContent = t[nodes[i].getAttribute('data-t')];
    var ph = document.querySelectorAll('[data-p]');
    for (var j = 0; j < ph.length; j++) ph[j].setAttribute('placeholder', t[ph[j].getAttribute('data-p')]);
    var al = document.querySelectorAll('[data-a]');
    for (var k = 0; k < al.length; k++) al[k].setAttribute('aria-label', t[al[k].getAttribute('data-a')]);
    document.title = 'Lumio';
  }

  function api(method, path, body) {
    var h = {};
    var o = { method: method, headers: h, credentials: 'same-origin', cache: 'no-store' };
    if (body !== undefined) { h['Content-Type'] = 'application/json'; o.body = JSON.stringify(body); }
    if (method !== 'GET' && csrf) h['X-CSRF-Token'] = csrf;
    return fetch(path, o).then(function (r) {
      return r.text().then(function (txt) {
        var j = {};
        try { j = txt ? JSON.parse(txt) : {}; } catch (e) { j = {}; }
        return { status: r.status, json: j, retry: r.headers.get('Retry-After') };
      });
    });
  }

  function show(id, on) { $(id).classList.toggle('hidden', !on); }
  function banner(kind, text) {
    var b = $('msg');
    b.className = 'msg toast ' + kind;
    b.textContent = text;
    b.classList.remove('hidden');
  }
  function clearBanner() { $('msg').classList.add('hidden'); $('msg').textContent = ''; }

  function showLogin(err) {
    show('login', true); show('main', false); show('nav', false); show('ontv', false); show('helpbtn', false);
    var e = $('lerr');
    e.textContent = err || '';
    e.classList.toggle('hidden', !err);
  }
  function showMain() { show('login', false); show('main', true); show('nav', true); show('ontv', true); show('helpbtn', true); selectTab(currentTab); }
  function closed() { stopPoll(); showMain(); banner('er', t.closed); }

  // --- onglets et écrans ---
  var currentTab = 'add';
  function selectTab(name) {
    currentTab = name;
    show('v-cfg', false);
    show('v-add', name === 'add');
    show('v-mine', name === 'mine');
    show('v-trakt', name === 'trakt');
    show('v-help', name === 'help');
    tkStop();
    $('tab-add').classList.toggle('on', name === 'add');
    $('tab-mine').classList.toggle('on', name === 'mine');
    $('tab-trakt').classList.toggle('on', name === 'trakt');
    $('tab-trakt').setAttribute('aria-current', name === 'trakt' ? 'page' : 'false');
    if (name === 'trakt') tkLoad();
    $('tab-add').setAttribute('aria-current', name === 'add' ? 'page' : 'false');
    $('tab-mine').setAttribute('aria-current', name === 'mine' ? 'page' : 'false');
    window.scrollTo(0, 0);
  }

  function login(code) {
    return api('POST', '/api/login', { code: code }).then(function (r) {
      if (r.status === 200) { csrf = r.json.csrf; clearBanner(); showMain(); loadCatalog(false, false); openDeepAddon(); return loadList(); }
      if (r.status === 429) {
        var s = parseInt(r.retry || '60', 10);
        showLogin(r.json.error === 'locked' ? fmt(t.locked, { s: s }) : t.rate);
      } else if (r.status === 401) showLogin(t.badCode);
      else showLogin(t.generic);
    }, closed);
  }

  function boot() {
    i18n();
    renderHelp();
    var ma = /[#&]addon=([A-Za-z0-9._-]{1,80})/.exec(location.hash);
    if (ma) deepAddon = ma[1];
    var mr = /[#&]reconf=([0-9a-f]{12})/.exec(location.hash);
    if (mr) deepRef = mr[1];
    var m = /(?:^|[#&])c=(\d{6})/.exec(location.hash);
    if (m) {
      try { history.replaceState(null, '', location.pathname); } catch (e) { location.hash = ''; }
      login(m[1]);
      return;
    }
    api('GET', '/api/session').then(function (r) {
      if (r.status === 200) { csrf = r.json.csrf; showMain(); loadCatalog(false, false); loadList(); openDeepAddon(); } else showLogin('');
    }, function () { showLogin(''); });
  }

  // --- Mes addons ---
  function colorOf(name) {
    var n = 0;
    for (var i = 0; i < name.length; i++) n += name.charCodeAt(i);
    return COLORS[n % COLORS.length];
  }
  function loadList() {
    return api('GET', '/api/addons').then(function (r) {
      if (r.status === 401) { showLogin(''); return; }
      if (r.status !== 200) { banner('er', t.generic); return; }
      addons = r.json.addons || [];
      render();
      openDeepRef();
    }, closed);
  }
  function render() {
    var list = $('list');
    while (list.firstChild) list.removeChild(list.firstChild);
    $('none').classList.toggle('hidden', addons.length > 0);
    var tpl = $('row-tpl');
    addons.forEach(function (a, i) {
      var li = tpl.content.firstElementChild.cloneNode(true);
      var q = function (c) { return li.querySelector('.' + c); };
      var lg = q('lg');
      lg.textContent = (a.name || '?').charAt(0).toUpperCase();
      lg.style.background = colorOf(a.name || '?');
      q('nm').textContent = a.name;
      var word, dotc;
      if (a.broken) { word = t.broken; dotc = 'rd'; }
      else if (!a.enabled) { word = t.disabled; dotc = 'gr'; }
      else if (a.health === 'reliable') { word = t.reliable; dotc = ''; }
      else if (a.health === 'slow') { word = t.slow; dotc = 'am'; }
      else if (a.health === 'failing') { word = t.failing; dotc = 'rd'; }
      else { word = t.unknown; dotc = 'gr'; }
      q('dot').className = 'dot ' + dotc;
      q('sub').textContent = word;
      li.querySelector('.ar').classList.toggle('off', !a.enabled);
      var up = q('up'), dn = q('down'), del = q('del'), sw = q('sw');
      up.textContent = '↑ ' + t.up;
      dn.textContent = '↓ ' + t.down;
      del.textContent = t.del;
      up.setAttribute('aria-label', t.up + ' : ' + a.name);
      dn.setAttribute('aria-label', t.down + ' : ' + a.name);
      del.setAttribute('aria-label', t.del + ' : ' + a.name);
      up.disabled = i === 0;
      dn.disabled = i === addons.length - 1;
      sw.setAttribute('aria-checked', a.enabled ? 'true' : 'false');
      sw.setAttribute('aria-label', a.name + ' · ' + (a.enabled ? t.enabled : t.disabled));
      up.addEventListener('click', function () { act('POST', a.id + '/move', { delta: -1 }); });
      dn.addEventListener('click', function () { act('POST', a.id + '/move', { delta: 1 }); });
      sw.addEventListener('click', function () { act('POST', a.id + '/enabled', { enabled: !a.enabled }); });
      del.addEventListener('click', function () { confirming = a.id; render(); });
      var rc = q('rc');
      rc.textContent = t.change;
      rc.setAttribute('aria-label', t.change + ' : ' + a.name);
      rc.classList.toggle('hidden', !!a.broken || a.configurable === false);
      rc.addEventListener('click', function () { openConfig('/api/addons/' + a.id + '/reconfigure', a.name, a.id); });
      var cf = q('cf');
      if (confirming === a.id) {
        cf.classList.remove('hidden');
        q('cft').textContent = fmt(t.confirmDel, { n: a.name });
        q('cn').textContent = t.cancel;
        q('cy').textContent = t.del;
        q('cn').addEventListener('click', function () { confirming = null; render(); });
        q('cy').addEventListener('click', function () { confirming = null; act('DELETE', a.id); });
      }
      list.appendChild(li);
    });
  }
  function act(method, path, body) {
    api(method, '/api/addons/' + path, body).then(function (r) {
      if (r.status === 401) { showLogin(''); return; }
      if (r.status === 429) { banner('er', t.rate); return; }
      if (r.status >= 400 && r.status !== 404) banner('er', t.generic);
      loadList();
      if (method === 'DELETE') loadCatalog(false, false);
    }, closed);
  }

  // --- Ajouter : catalogue ---
  function catQuery(page, refresh) {
    var q = '?page=' + page;
    if (cat.more) q += '&more=' + encodeURIComponent(cat.more);
    else q += '&chip=' + encodeURIComponent(cat.chip);
    if (refresh) q += '&refresh=1';
    return q;
  }
  function loadCatalog(refresh, append) {
    if (cat.busy) return Promise.resolve();
    cat.busy = true;
    var page = append ? cat.page + 1 : 1;
    return api('GET', '/api/catalog' + catQuery(page, refresh)).then(function (r) {
      cat.busy = false;
      if (r.status === 401) { showLogin(''); return; }
      if (r.status !== 200) { $('catmsg').textContent = t.catLoadError; show('catmsg', true); return; }
      var j = r.json;
      cat.chips = j.chips || [];
      cat.moreList = j.more || [];
      cat.page = j.page || 1;
      cat.hasMore = !!j.hasMore;
      cat.moreLabel = j.moreLabel || null;
      cat.note = j.note || null;
      catalog = append ? catalog.concat(j.items || []) : (j.items || []);
      show('catmsg', false);
      renderCatalog();
    }, function () { cat.busy = false; closed(); });
  }
  // Lien du QR de la TV : réglage d'un addon précis du catalogue.
  function openDeepAddon() {
    if (!deepAddon) return;
    var slug = deepAddon;
    deepAddon = null;
    api('GET', '/api/catalog/one?slug=' + encodeURIComponent(slug)).then(function (r) {
      if (r.status === 401) { showLogin(''); return; }
      var it = r.json && r.json.item;
      if (r.status !== 200 || !it) { banner('er', t.catLoadError); return; }
      openConfig('/api/catalog/' + it.id + '/configure', it.name, null);
    }, closed);
  }
  // Lien du QR de la TV : changer les réglages d'un addon installé.
  function openDeepRef() {
    if (!deepRef) return;
    for (var i = 0; i < addons.length; i++) {
      if (addons[i].ref === deepRef) {
        var a = addons[i];
        deepRef = null;
        openConfig('/api/addons/' + a.id + '/reconfigure', a.name, a.id);
        return;
      }
    }
    deepRef = null;
  }
  function chipBtn(label, on, fn, key) {
    var b = document.createElement('button');
    b.type = 'button';
    b.className = 'chp' + (on ? ' on' : '');
    b.textContent = label;
    if (on) b.setAttribute('aria-pressed', 'true');
    b.addEventListener('click', fn);
    if (key) b.setAttribute('data-k', key);
    return b;
  }
  function buildCard(c) {
    var tpl = $('cat-tpl');
    var li = tpl.content.firstElementChild.cloneNode(true);
    var q = function (k) { return li.querySelector('.' + k); };
    var lg = q('lg');
    lg.textContent = (c.name || '?').charAt(0).toUpperCase();
    lg.style.background = colorOf(c.name || '?');
    if (c.logo) {
      var im = document.createElement('img');
      im.alt = '';
      im.referrerPolicy = 'no-referrer';
      im.loading = 'lazy';
      im.addEventListener('error', function () { if (im.parentNode) im.parentNode.removeChild(im); });
      im.src = c.logo;
      lg.appendChild(im);
    }
    q('nm').textContent = c.name;
    q('d1').textContent = c.description || c.meta || '';
    q('d1').classList.toggle('hidden', !(c.description || c.meta));
    q('bdg').textContent = t.catInstalled;
    q('bdg').classList.toggle('hidden', !c.installed);
    var b = q('cb');
    b.classList.toggle('hidden', !!c.installed);
    if (c.setup) {
      b.textContent = t.setup;
      b.classList.add('b2');
      b.setAttribute('aria-label', t.setup + ' : ' + c.name);
      b.addEventListener('click', function () { openConfig('/api/catalog/' + c.id + '/configure', c.name, null); });
    } else {
      b.textContent = t.install;
      b.classList.add('b1');
      b.setAttribute('aria-label', t.install + ' : ' + c.name);
      b.addEventListener('click', function () { installCat(c); });
    }
    return li;
  }
  function renderCatalog() {
    var ch = $('chips');
    while (ch.firstChild) ch.removeChild(ch.firstChild);
    cat.chips.forEach(function (c) {
      ch.appendChild(chipBtn(c.label, !cat.more && cat.chip === c.id, function () {
        cat.chip = c.id; cat.more = null; show('morelist', false); loadCatalog(false, false);
      }, c.id));
    });
    ch.appendChild(chipBtn(cat.more && cat.moreLabel ? cat.moreLabel : t.catMore, !!cat.more, function () {
      $('morelist').classList.toggle('hidden');
    }, 'more'));
    ch.appendChild(chipBtn(t.catRefresh, false, function () { loadCatalog(true, false); }, 'refresh'));
    var ml = $('morelist');
    while (ml.firstChild) ml.removeChild(ml.firstChild);
    cat.moreList.forEach(function (c) {
      ml.appendChild(chipBtn(c.label, cat.more === c.id, function () {
        cat.more = c.id; show('morelist', false); loadCatalog(false, false);
      }, c.id));
    });
    var note = $('catnote');
    note.textContent = cat.note === 'offline' ? t.catOffline : (cat.note === 'fallback' ? t.catFallback : '');
    note.classList.toggle('hidden', !cat.note);
    var list = $('cat');
    while (list.firstChild) list.removeChild(list.firstChild);
    var shown = 0;
    catalog.forEach(function (c) {
      var hay = ((c.name || '') + ' ' + (c.description || '')).toLowerCase();
      if (query && hay.indexOf(query) < 0) return;
      shown++;
      list.appendChild(buildCard(c));
    });
    $('catnone').classList.toggle('hidden', shown > 0);
    var lm = $('catmore');
    lm.textContent = t.catLoadMore;
    lm.classList.toggle('hidden', !cat.hasMore);
  }
  function installCat(c) {
    clearBanner();
    api('POST', '/api/catalog/' + c.id + '/install', {}).then(function (r) {
      if (r.status === 202) { banner('wt', fmt(t.waiting, { n: c.name })); poll(r.json.request); return; }
      if (r.status === 401) { showLogin(''); return; }
      if (r.status === 409) { openConfig('/api/catalog/' + c.id + '/configure', c.name, null); return; }
      banner('er', r.status === 429 ? t.rate : t.generic);
    }, closed);
  }

  // --- Régler (écran dédié en 3 étapes) ---
  var cfgUrl = null;
  function setSteps() {
    var has = $('cu').value.trim().length > 0;
    var s1 = $('s1'), s2 = $('s2'), s3 = $('s3');
    s1.className = 'st done';
    s2.className = 'st ' + (has ? 'done' : 'act');
    s3.className = 'st ' + (has ? 'act' : '');
    $('s1n').textContent = '✓';
    $('s2n').textContent = has ? '✓' : '2';
  }
  function openConfig(path, name, rep) {
    clearBanner();
    api('POST', path, {}).then(function (r) {
      if (r.status === 401) { showLogin(''); return; }
      var u = r.json && r.json.url;
      if (r.status !== 200 || typeof u !== 'string' || !/^https?:\/\//i.test(u)) {
        banner('er', r.status === 404 ? t.notCfg : (r.status === 429 ? t.rate : t.generic));
        return;
      }
      replaces = rep;
      cfgUrl = u;
      $('cfgt').textContent = name;
      $('cfglink').setAttribute('href', u);
      $('cu').value = '';
      setSteps();
      show('v-add', false); show('v-mine', false); show('v-trakt', false); show('v-help', false); show('v-cfg', true);
      window.scrollTo(0, 0);
      // Ouverture automatique ; si le navigateur la bloque, « Rouvrir la page ».
      try { window.open(u, '_blank', 'noopener,noreferrer'); } catch (e) { /* bloqué */ }
    }, closed);
  }
  function sendCfg() {
    var v = $('cu').value.trim();
    if (!v) { banner('er', t.emptyLink); $('cu').focus(); return; }
    $('csend').disabled = true;
    var body = { link: v };
    if (replaces) body.replaces = replaces;
    api('POST', '/api/add', body).then(function (r) {
      $('csend').disabled = false;
      if (r.status === 202) { banner('wt', t.waitingLink); selectTab(replaces ? 'mine' : 'add'); $('cu').value = ''; poll(r.json.request); return; }
      if (r.status === 401) { showLogin(''); return; }
      banner('er', r.status === 400 ? t.invalidLink : (r.status === 429 ? t.rate : t.generic));
    }, function () { $('csend').disabled = false; closed(); });
  }


  // --- Trakt : la TV fait tout, le téléphone montre le code ---
  var tkTimer = null;
  function tkStop() { if (tkTimer) { clearTimeout(tkTimer); tkTimer = null; } }
  function tkRender(j) {
    var on = !!j.configured, conn = on && !!j.connected, wait = on && !j.connected && !!j.pending;
    show('tk-off', !on);
    show('tk-on', conn);
    show('tk-wait', wait);
    show('tk-idle', on && !j.connected && !j.pending && !j.blocked);
    show('tk-blocked', on && !j.connected && !!j.blocked);
    $('tk-code').textContent = wait && j.code ? j.code : '';
    var u = j.url;
    if (wait && typeof u === 'string' && /^https:\/\//i.test(u)) $('tk-open').setAttribute('href', u);
    var key = j.failure === 'denied' ? 'traktDenied' : j.failure === 'expired' ? 'traktExpired' : (j.failure === 'unavailable' ? 'traktUnavailable' : null);
    var f = $('tk-fail');
    f.textContent = key ? t[key] : '';
    f.classList.toggle('hidden', !key || conn || wait);
    show('tk-cf', false);
    if (wait && currentTab === 'trakt') {
      tkStop();
      tkTimer = setTimeout(tkLoad, 2500);
    }
  }
  function tkLoad() {
    return api('GET', '/api/trakt').then(function (r) {
      if (r.status === 401) { showLogin(''); return; }
      if (r.status !== 200) { banner('er', t.generic); return; }
      var wasWaiting = !$('tk-wait').classList.contains('hidden');
      tkRender(r.json);
      if (wasWaiting && r.json.connected) banner('ok', t.traktDone);
    }, closed);
  }
  function tkConnect() {
    $('tk-connect').disabled = true;
    api('POST', '/api/trakt/connect', {}).then(function (r) {
      $('tk-connect').disabled = false;
      if (r.status === 401) { showLogin(''); return; }
      if (r.status !== 200) { banner('er', r.status === 429 ? t.rate : t.generic); return; }
      tkRender(r.json);
    }, function () { $('tk-connect').disabled = false; closed(); });
  }
  function tkDisconnect() {
    api('POST', '/api/trakt/disconnect', {}).then(function (r) {
      if (r.status === 401) { showLogin(''); return; }
      if (r.status !== 200) { banner('er', t.generic); return; }
      tkRender(r.json);
    }, closed);
  }
  function copyText(v) {
    try {
      if (navigator.clipboard && window.isSecureContext) { navigator.clipboard.writeText(v); banner('ok', t.copied); return; }
    } catch (e) { /* repli ci-dessous */ }
    var i = document.createElement('input');
    i.value = v; i.className = 'tkhid';
    document.body.appendChild(i);
    i.select();
    try { document.execCommand('copy'); banner('ok', t.copied); } catch (e) { /* rien */ }
    document.body.removeChild(i);
  }

  // --- Aide (guides pas à pas) ---
  var HELP = [
    ['hAdd', ['hAdd1', 'hAdd2', 'hAdd3']],
    ['hSet', ['hSet1', 'hSet2', 'hSet3', 'hSet4', 'hSet5'], 'keyNote'],
    ['hPortal', ['hPortal1', 'hPortal2', 'hPortal3']],
    ['hTrakt', ['tk1', 'tk2', 'tk3', 'tk4']],
    ['hProf', ['hProf1', 'hProf2']],
    ['hSubs', ['hSubs1', 'hSubs2']]
  ];
  function renderHelp() {
    var box = $('helplist');
    for (var i = 0; i < HELP.length; i++) {
      var g = HELP[i];
      var card = document.createElement('div');
      card.className = 'card';
      var h = document.createElement('h2');
      h.className = 'hd h22';
      h.textContent = t[g[0]];
      card.appendChild(h);
      for (var k = 0; k < g[1].length; k++) {
        var row = document.createElement('div');
        row.className = 'st';
        var n = document.createElement('div');
        n.className = 'n';
        n.textContent = String(k + 1);
        var tx = document.createElement('div');
        tx.className = 'sm';
        tx.textContent = t[g[1][k]];
        row.appendChild(n); row.appendChild(tx);
        card.appendChild(row);
      }
      if (g[2]) {
        var note = document.createElement('div');
        note.className = 'nt';
        note.textContent = t[g[2]];
        card.appendChild(note);
      }
      box.appendChild(card);
    }
  }

  // --- Installation par lien ---
  function stopPoll() { if (pollTimer) { clearTimeout(pollTimer); pollTimer = null; } }
  function poll(id) {
    stopPoll();
    pollTimer = setTimeout(function () {
      api('GET', '/api/add/' + id).then(function (r) {
        if (r.status === 401) { showLogin(''); return; }
        var s = r.json.state;
        if (r.status !== 200 || s === 'waiting') { poll(id); return; }
        $('send').disabled = false;
        if (s === 'installed') {
          banner('ok', r.json.name ? fmt(t.installed, { n: r.json.name }) : t.installedNoName);
          $('u').value = '';
          show('linkbox', false);
          loadList();
          loadCatalog(false, false);
        } else banner('er', t[s] || t.failed);
      }, closed);
    }, 1500);
  }
  function send() {
    var v = $('u').value.trim();
    if (!v) { banner('er', t.emptyLink); $('u').focus(); return; }
    $('send').disabled = true;
    api('POST', '/api/add', { link: v }).then(function (r) {
      if (r.status === 202) { banner('wt', t.waitingLink); poll(r.json.request); return; }
      $('send').disabled = false;
      if (r.status === 401) { showLogin(''); return; }
      banner('er', r.status === 400 ? t.invalidLink : (r.status === 429 ? t.rate : t.generic));
    }, function () { $('send').disabled = false; closed(); });
  }

  $('send').addEventListener('click', send);
  $('csend').addEventListener('click', sendCfg);
  $('cback').addEventListener('click', function () { selectTab(currentTab); });
  $('cu').addEventListener('input', setSteps);
  $('cu').addEventListener('keydown', function (e) { if (e.key === 'Enter') sendCfg(); });
  $('catmore').addEventListener('click', function () { loadCatalog(false, true); });
  $('have').addEventListener('click', function () {
    var box = $('linkbox');
    box.classList.toggle('hidden');
    if (!box.classList.contains('hidden')) { $('u').focus(); }
  });
  $('lclose').addEventListener('click', function () { show('linkbox', false); });
  $('u').addEventListener('keydown', function (e) { if (e.key === 'Enter') send(); });
  $('q').addEventListener('input', function () { query = $('q').value.trim().toLowerCase(); renderCatalog(); });
  $('tab-add').addEventListener('click', function () { selectTab('add'); });
  $('tab-trakt').addEventListener('click', function () { selectTab('trakt'); });
  $('helpbtn').addEventListener('click', function () { selectTab('help'); });
  $('hback').addEventListener('click', function () { selectTab('add'); });
  $('tk-connect').addEventListener('click', tkConnect);
  $('tk-disc').addEventListener('click', function () { show('tk-cf', true); });
  $('tk-cn').addEventListener('click', function () { show('tk-cf', false); });
  $('tk-cy').addEventListener('click', tkDisconnect);
  $('tk-copy').addEventListener('click', function () { copyText($('tk-code').textContent); });
  $('tab-mine').addEventListener('click', function () { selectTab('mine'); loadList(); });
  $('lform').addEventListener('submit', function (e) {
    e.preventDefault();
    var c = $('code').value.replace(/\D/g, '');
    if (c.length !== 6) { showLogin(t.badCode); return; }
    login(c);
  });
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden && !$('main').classList.contains('hidden')) loadList();
  });
  boot();
})();
''';

const _html = r'''<!doctype html>
<html lang="{{LANG}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Lumio</title>
<link rel="stylesheet" href="/app.css">
</head>
<body>
<div class="ph">
<div class="top"><div class="brand"><svg width="28" height="28" viewBox="0 0 72 72" aria-hidden="true"><circle cx="36" cy="36" r="30" fill="none" stroke="#FFB84D" stroke-width="9"/><circle cx="36" cy="36" r="10" fill="#4FD1C5"/></svg><span class="hd h22">Lumio</span></div>
<div class="row"><button type="button" class="hl hidden" id="helpbtn" data-t="helpBtn"></button><span class="on-tv hidden" id="ontv"><span class="dot" aria-hidden="true"></span><span data-t="onTv"></span></span></div></div>
<div id="msg" class="msg toast hidden" role="status" aria-live="polite"></div>
<section id="login" class="col hidden">
<div><h1 class="hd h26" data-t="loginTitle"></h1><div class="sm mt4" data-t="loginHelp"></div></div>
<form id="lform" class="col" autocomplete="off">
<label class="l" for="code" data-t="loginTitle"></label>
<input class="in code" id="code" name="code" type="text" inputmode="numeric" pattern="[0-9]*" maxlength="9" autocomplete="one-time-code" autocapitalize="none" spellcheck="false" placeholder="000 000">
<div id="lerr" class="msg er hidden" role="alert"></div>
<button class="bt b1" type="submit" data-t="loginBtn"></button>
</form>
</section>
<section id="main" class="col hidden">
<div id="v-add" class="col">
<div><h1 class="hd h26" data-t="addTitle"></h1><p class="sm mt4" data-t="addHelp"></p></div>
<div class="sw0"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7E8896" stroke-width="2" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg><input class="sch" id="q" type="search" autocomplete="off" autocapitalize="none" spellcheck="false" data-p="search" data-a="search"></div>
<div id="chips" class="chips" role="group"></div>
<div id="morelist" class="chips hidden" role="group"></div>
<div id="catnote" class="msg wt hidden" role="status"></div>
<div id="catmsg" class="msg er hidden" role="alert"></div>
<div id="catnone" class="sm hidden" data-t="catEmpty"></div>
<ul id="cat" class="col lst"></ul>
<button class="bt b2 hidden" id="catmore" type="button"></button>
<button class="gh" id="have" type="button" data-t="haveLink"></button>
<div id="linkbox" class="pn hidden"><h2 class="hd h22" data-t="linkTitle"></h2><div class="sm" data-t="linkHelp"></div>
<label class="l" for="u" data-t="linkLabel"></label>
<input class="in" id="u" type="text" inputmode="url" autocapitalize="none" autocomplete="off" autocorrect="off" spellcheck="false" maxlength="2048" placeholder="https://…/manifest.json">
<div class="sm" data-t="pasteHint"></div>
<button class="bt b1" id="send" type="button" data-t="sendTv"></button>
<div class="sm" data-t="tvConfirm"></div>
<a class="lk" href="https://stremio-addons.net" target="_blank" rel="noopener noreferrer"><span data-t="browse"></span></a>
<div class="sm" data-t="browseHint"></div>
<button class="bt b2" id="lclose" type="button" data-t="close"></button></div>
</div>
<div id="v-cfg" class="col hidden">
<div class="row"><button class="bk" id="cback" type="button" data-a="back"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#F3F5F7" stroke-width="2.2" aria-hidden="true"><path d="M15 5l-7 7 7 7"/></svg></button><div><div class="sm" data-t="cfgBefore"></div><h1 class="hd h22" id="cfgt"></h1></div></div>
<p class="sm" data-t="cfgIntro"></p>
<div class="st done" id="s1"><div class="n" id="s1n">✓</div><div class="f1"><div class="stt" data-t="s1"></div><div class="sm" data-t="s1d"></div><a class="lk" id="cfglink" href="about:blank" target="_blank" rel="noopener noreferrer"><span data-t="reopen"></span></a></div></div>
<div class="st act" id="s2"><div class="n" id="s2n">2</div><div class="f1"><div class="stt" data-t="s2"></div><div class="sm" data-t="s2d"></div></div></div>
<div class="st" id="s3"><div class="n">3</div><div class="f1"><div class="stt" data-t="s3"></div>
<label class="l sm mt8" for="cu" data-t="cfgLabel"></label>
<input class="in" id="cu" type="text" inputmode="url" autocapitalize="none" autocomplete="off" autocorrect="off" spellcheck="false" maxlength="2048" placeholder="stremio://…/manifest.json">
<div class="sm mt4" data-t="cfgHint"></div></div></div>
<div class="sm" data-t="s2tip"></div>
<button class="bt b1" id="csend" type="button" data-t="sendTv"></button>
<div class="sm" data-t="tvConfirm"></div>
<div class="nt" data-t="keyNote"></div>
</div>
<div id="v-mine" class="col hidden">
<div><h1 class="hd h26" data-t="mineTitle"></h1><p class="sm mt4" data-t="mineHelp"></p></div>
<div id="none" class="sm hidden" data-t="none"></div>
<ul id="list" class="col lst"></ul>
<div class="sm" data-t="mineReplace"></div>
</div>
<div id="v-trakt" class="col hidden">
<div><h1 class="hd h26" data-t="traktTitle"></h1><p class="sm mt4" data-t="traktHelp"></p></div>
<div id="tk-fail" class="msg er hidden" role="alert"></div>
<div id="tk-off" class="msg wt hidden" data-t="traktOff"></div>
<div id="tk-blocked" class="msg wt hidden" data-t="traktBlocked"></div>
<div id="tk-on" class="card hidden"><div class="ar"><span class="dot" aria-hidden="true"></span><div class="tx"><div class="nm" data-t="traktOn"></div><div class="sm" data-t="traktOnHelp"></div></div></div>
<button type="button" class="ib dg" id="tk-disc" data-t="traktDisc"></button>
<div id="tk-cf" class="cf hidden col" role="alertdialog"><div data-t="traktDiscAsk"></div><button type="button" class="bt bd" id="tk-cy" data-t="traktDisc"></button><button type="button" class="bt b2" id="tk-cn" data-t="cancel"></button></div></div>
<div id="tk-idle" class="card hidden"><div class="nm" data-t="traktNot"></div><div class="sm" data-t="traktNotHelp"></div>
<button type="button" class="bt b1" id="tk-connect" data-t="traktConnect"></button></div>
<div id="tk-wait" class="card ctr hidden"><div class="sm" data-t="traktEnter"></div><div id="tk-code" class="tkc"></div>
<div class="row"><button type="button" class="ib md" id="tk-copy" data-t="traktCopy"></button><a class="lka" id="tk-open" href="https://trakt.tv/activate" target="_blank" rel="noopener noreferrer" data-t="traktOpen"></a></div>
<div class="sm"><span class="dot am" aria-hidden="true"></span> <span data-t="traktWaiting"></span></div></div>
<div class="card"><div class="hn" data-t="traktSteps"></div>
<div class="st"><div class="n">1</div><div class="sm" data-t="tk1"></div></div>
<div class="st"><div class="n">2</div><div class="sm" data-t="tk2"></div></div>
<div class="st"><div class="n">3</div><div class="sm" data-t="tk3"></div></div>
<div class="st"><div class="n">4</div><div class="sm" data-t="tk4"></div></div></div>
</div>
<div id="v-help" class="col hidden">
<div class="row"><button class="bk" id="hback" type="button" data-a="back"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#F3F5F7" stroke-width="2.2" aria-hidden="true"><path d="M15 5l-7 7 7 7"/></svg></button><div><h1 class="hd h26" data-t="helpTitle"></h1><div class="sm" data-t="helpIntro"></div></div></div>
<div id="helplist" class="col"></div>
</div>
</section>
</div>
<nav id="nav" class="nav hidden" aria-label="Lumio">
<button class="tab on" id="tab-add" type="button"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke-width="2" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg><span data-t="tabAdd"></span></button>
<button class="tab" id="tab-mine" type="button"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke-width="2" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h10"/></svg><span data-t="tabMine"></span></button>
<button class="tab" id="tab-trakt" type="button"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke-width="2" aria-hidden="true"><path d="M3 17l6-6 4 4 8-8"/></svg><span data-t="tabTrakt"></span></button>
</nav>
<template id="cat-tpl"><li class="card"><div class="ar"><div class="lg" aria-hidden="true"></div><div class="tx"><div class="nm"></div><div class="d1"></div></div><span class="bdg hidden"></span><button type="button" class="bt cb"></button></div></li></template>
<template id="row-tpl"><li class="card"><div class="ar"><div class="lg" aria-hidden="true"></div><div class="tx"><div class="nm"></div><div class="sm"><span class="dot"></span> <span class="sub"></span></div></div>
<button type="button" class="tg sw" role="switch" aria-checked="true"><i aria-hidden="true"></i></button></div>
<div class="acts"><button type="button" class="ib up"></button><button type="button" class="ib down"></button><button type="button" class="ib md rc"></button><button type="button" class="ib dg del"></button></div>
<div class="cf hidden col" role="alertdialog"><div class="cft"></div><button type="button" class="bt bd cy"></button><button type="button" class="bt b2 cn"></button></div></li></template>
<script src="/app.js"></script>
</body>
</html>
''';
