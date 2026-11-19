// Page web servie par la box : HTML, CSS et JS embarqués (aucune ressource
// externe, aucun `innerHTML`), maquette M04. Les textes sont en français et
// en anglais ; la langue est celle de l'application.

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
.ph{max-width:480px;min-height:100vh;margin:0 auto;padding:24px 20px;display:flex;flex-direction:column;gap:16px}
.hd{font-family:'Bricolage Grotesque','Manrope',system-ui,sans-serif;font-weight:700;margin:0}
.sm{font-size:14px;color:#A9B2BF;line-height:1.4}
label.l{font-size:14px;color:#F3F5F7;font-weight:600;line-height:1.4}
.in{height:52px;width:100%;border-radius:14px;background:#161B22;border:2px solid #3A4452;padding:0 14px;font:inherit;font-size:15px;color:#F3F5F7}
.in::placeholder{color:#A9B2BF;opacity:1}
.in:focus-visible,.bt:focus-visible,.ib:focus-visible,.lk:focus-visible,.sw:focus-visible{outline:3px solid #FFB84D;outline-offset:2px}
.bt{height:52px;border-radius:26px;border:0;font-family:inherit;font-size:16px;font-weight:700;cursor:pointer}
.bt:disabled{opacity:.5;cursor:default}
.b2{background:#2A3340;color:#F3F5F7}
.b1{background:#FFB84D;color:#1A1100}
.row{display:flex;gap:10px}
.lk{display:flex;align-items:center;justify-content:space-between;height:56px;border-radius:14px;background:#161B22;padding:0 16px;color:#F3F5F7;text-decoration:none;font-weight:600}
.card{border-radius:14px;background:#161B22;padding:0 12px}
.ar{display:flex;align-items:center;gap:12px;min-height:64px}
.ar.off .nm{opacity:.55}
.lg{width:40px;height:40px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-weight:700;color:#0E1116;font-family:'Bricolage Grotesque',system-ui,sans-serif;flex:none}
.nm{font-weight:700;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tx{flex:1;min-width:0}
.ib{width:44px;height:44px;border-radius:22px;background:#2A3340;border:0;display:flex;align-items:center;justify-content:center;flex:none;cursor:pointer;padding:0}
.ib:disabled{opacity:.35;cursor:default}
.ib svg{width:18px;height:18px}
.ct{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:0 0 12px;font-size:14px;color:#A9B2BF}
.sw{display:flex;align-items:center;gap:10px;border:0;background:none;color:inherit;font:inherit;font-size:14px;padding:0;cursor:pointer;min-height:44px}
.sw i{width:44px;height:26px;border-radius:13px;background:#3A4452;position:relative;flex:none}
.sw i:after{content:'';position:absolute;top:3px;left:3px;width:20px;height:20px;border-radius:10px;background:#F3F5F7;transition:left .15s}
.sw[aria-checked=true] i{background:#FFB84D}
.sw[aria-checked=true] i:after{left:21px}
.cf{display:flex;flex-direction:column;gap:10px;padding:12px 0}
.cf .bt{height:44px;font-size:15px}
.bd{background:#FF7A70;color:#1A1100}
.msg{border-radius:14px;padding:12px 14px;font-size:14px;line-height:1.4;background:#161B22}
.msg.ok{border:2px solid #5BD68A}
.msg.er{border:2px solid #FF7A70}
.msg.wt{border:2px solid #FFB84D}
.brand{display:flex;align-items:center;gap:10px}
.hidden{display:none!important}
.col{display:flex;flex-direction:column;gap:16px}
.h22{font-size:22px}.h26{font-size:26px}.h20{font-size:20px;margin:8px 0 0}
.mt4{margin-top:4px}.f1{flex:1}.f2{flex:2}
.lst{list-style:none;margin:0;padding:0}
.foot{margin-top:auto}
.ph>section{flex:1}
.ty{text-align:right}
.code{letter-spacing:6px;text-align:center;font-size:24px}
@media (prefers-reduced-motion:reduce){.sw i:after{transition:none}}
''';

const phoneJs = r'''
(function () {
  'use strict';
  var T = {
    fr: {
      brand: 'Lumio · votre TV',
      addTitle: 'Ajouter un addon',
      addHelp: "Collez le lien : l'aperçu s'affiche, vous confirmez sur la TV.",
      linkLabel: "Lien de l'addon",
      paste: 'Coller',
      pasteHint: 'Appuyez longuement dans le champ, puis choisissez Coller.',
      send: 'Envoyer à la TV',
      browse: 'Parcourir stremio-addons.net',
      browseHint: 'Sur le site, « Copier le lien » puis revenez ici.',
      mine: 'Mes addons · ordre de priorité',
      none: "Aucun addon installé pour l'instant.",
      up: 'Monter',
      down: 'Descendre',
      del: 'Supprimer',
      cancel: 'Annuler',
      confirmDel: 'Supprimer « {n} » ?',
      enabled: 'Activé',
      disabled: 'Désactivé',
      broken: 'Illisible',
      reliable: 'Bonne santé',
      slow: 'Lente',
      failing: 'Hors ligne',
      unknown: 'Santé inconnue',
      connected: 'Connecté à {h} · la page se ferme quand vous quittez l’écran sur la TV.',
      loginTitle: 'Code de sécurité',
      loginHelp: 'Saisissez le code à 6 chiffres affiché sur la TV.',
      loginBtn: 'Se connecter',
      badCode: 'Code incorrect. Regardez le code affiché sur la TV.',
      locked: 'Trop d’essais. Réessayez dans {s} s avec le nouveau code affiché sur la TV.',
      waiting: 'En attente de confirmation sur la TV…',
      installed: 'Installé : {n}. Retrouvez-le dans la liste ci-dessous.',
      installedNoName: 'Addon installé.',
      failed: "L'installation n'a pas abouti. Vérifiez le lien et réessayez.",
      cancelled: 'Annulé sur la TV.',
      expired: 'Pas de confirmation sur la TV : demande expirée.',
      invalidLink: "Ce lien n'est pas un lien d'addon (https://…/manifest.json ou stremio://…).",
      emptyLink: "Collez d'abord le lien de l'addon.",
      closed: "La TV a fermé la page. Rouvrez « Depuis le téléphone » sur la TV, puis rescannez le code.",
      generic: 'Une erreur est survenue. Réessayez.',
      rate: 'Trop de requêtes, patientez un instant.',
      types: { movie: 'Films', series: 'Séries', anime: 'Anime', tv: 'TV', channel: 'Chaînes', other: 'Autre' }
    },
    en: {
      brand: 'Lumio · your TV',
      addTitle: 'Add an addon',
      addHelp: 'Paste the link: the preview shows on the TV and you confirm there.',
      linkLabel: 'Addon link',
      paste: 'Paste',
      pasteHint: 'Long-press in the field, then choose Paste.',
      send: 'Send to the TV',
      browse: 'Browse stremio-addons.net',
      browseHint: 'On the site, tap “Copy link”, then come back here.',
      mine: 'My addons · priority order',
      none: 'No addon installed yet.',
      up: 'Move up',
      down: 'Move down',
      del: 'Delete',
      cancel: 'Cancel',
      confirmDel: 'Delete “{n}”?',
      enabled: 'Enabled',
      disabled: 'Disabled',
      broken: 'Unreadable',
      reliable: 'Healthy',
      slow: 'Slow',
      failing: 'Offline',
      unknown: 'Health unknown',
      connected: 'Connected to {h} · the page closes when you leave the screen on the TV.',
      loginTitle: 'Security code',
      loginHelp: 'Enter the 6-digit code shown on the TV.',
      loginBtn: 'Sign in',
      badCode: 'Wrong code. Check the code shown on the TV.',
      locked: 'Too many attempts. Try again in {s} s with the new code shown on the TV.',
      waiting: 'Waiting for confirmation on the TV…',
      installed: 'Installed: {n}. You will find it in the list below.',
      installedNoName: 'Addon installed.',
      failed: "The installation did not complete. Check the link and try again.",
      cancelled: 'Cancelled on the TV.',
      expired: 'No confirmation on the TV: request expired.',
      invalidLink: 'That is not an addon link (https://…/manifest.json or stremio://…).',
      emptyLink: 'Paste the addon link first.',
      closed: 'The TV closed the page. Reopen “From your phone” on the TV, then scan the code again.',
      generic: 'Something went wrong. Try again.',
      rate: 'Too many requests, wait a moment.',
      types: { movie: 'Movies', series: 'Series', anime: 'Anime', tv: 'TV', channel: 'Channels', other: 'Other' }
    }
  };
  var lang = document.documentElement.lang === 'en' ? 'en' : 'fr';
  var t = T[lang];
  var COLORS = ['#4FD1C5', '#FFB84D', '#FF7A70', '#7AA2FF', '#5BD68A'];
  var csrf = '';
  var addons = [];
  var confirming = null;
  var pollTimer = null;
  var $ = function (id) { return document.getElementById(id); };

  function fmt(s, o) {
    return s.replace(/\{(\w+)\}/g, function (_, k) { return o[k]; });
  }
  function i18n() {
    var nodes = document.querySelectorAll('[data-t]');
    for (var i = 0; i < nodes.length; i++) nodes[i].textContent = t[nodes[i].getAttribute('data-t')];
    $('u').setAttribute('placeholder', 'https://…/manifest.json');
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
    b.className = 'msg ' + kind;
    b.textContent = text;
    b.classList.remove('hidden');
  }
  function clearBanner() { $('msg').classList.add('hidden'); $('msg').textContent = ''; }

  function showLogin(err) {
    show('login', true); show('main', false);
    var e = $('lerr');
    e.textContent = err || '';
    e.classList.toggle('hidden', !err);
  }
  function showMain() { show('login', false); show('main', true); }
  function closed() { stopPoll(); showMain(); banner('er', t.closed); }

  function login(code) {
    return api('POST', '/api/login', { code: code }).then(function (r) {
      if (r.status === 200) { csrf = r.json.csrf; clearBanner(); showMain(); return loadList(); }
      if (r.status === 429) {
        var s = parseInt(r.retry || '60', 10);
        showLogin(r.json.error === 'locked' ? fmt(t.locked, { s: s }) : t.rate);
      } else if (r.status === 401) showLogin(t.badCode);
      else showLogin(t.generic);
    }, closed);
  }

  function boot() {
    i18n();
    $('host').textContent = fmt(t.connected, { h: location.hostname });
    var m = /(?:^|[#&])c=(\d{6})/.exec(location.hash);
    if (m) {
      try { history.replaceState(null, '', location.pathname); } catch (e) { location.hash = ''; }
      login(m[1]);
      return;
    }
    api('GET', '/api/session').then(function (r) {
      if (r.status === 200) { csrf = r.json.csrf; showMain(); loadList(); } else showLogin('');
    }, function () { showLogin(''); });
  }

  // --- liste ---
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
    }, closed);
  }
  function typesLabel(a) {
    var out = [];
    for (var i = 0; i < a.types.length; i++) out.push(t.types[a.types[i]] || a.types[i]);
    return out.join(' · ');
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
      var sub = a.broken ? t.broken : (t[a.health] || t.unknown);
      q('sub').textContent = sub;
      q('ty').textContent = typesLabel(a);
      li.classList.toggle('off', !a.enabled);
      var up = q('up'), dn = q('down'), del = q('del'), sw = q('sw');
      up.setAttribute('aria-label', t.up + ' : ' + a.name);
      dn.setAttribute('aria-label', t.down + ' : ' + a.name);
      del.setAttribute('aria-label', t.del + ' : ' + a.name);
      up.disabled = i === 0;
      dn.disabled = i === addons.length - 1;
      sw.setAttribute('aria-checked', a.enabled ? 'true' : 'false');
      sw.setAttribute('aria-label', a.name + ' · ' + t.enabled);
      q('swt').textContent = a.enabled ? t.enabled : t.disabled;
      up.addEventListener('click', function () { act('POST', a.id + '/move', { delta: -1 }); });
      dn.addEventListener('click', function () { act('POST', a.id + '/move', { delta: 1 }); });
      sw.addEventListener('click', function () { act('POST', a.id + '/enabled', { enabled: !a.enabled }); });
      del.addEventListener('click', function () { confirming = a.id; render(); });
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
    }, closed);
  }

  // --- ajout ---
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
          loadList();
        } else banner(s === 'cancelled' ? 'er' : 'er', t[s] || t.failed);
      }, closed);
    }, 1500);
  }
  function send() {
    var v = $('u').value.trim();
    if (!v) { banner('er', t.emptyLink); $('u').focus(); return; }
    $('send').disabled = true;
    api('POST', '/api/add', { link: v }).then(function (r) {
      if (r.status === 202) { banner('wt', t.waiting); poll(r.json.request); return; }
      $('send').disabled = false;
      if (r.status === 401) { showLogin(''); return; }
      banner('er', r.status === 400 ? t.invalidLink : (r.status === 429 ? t.rate : t.generic));
    }, function () { $('send').disabled = false; closed(); });
  }
  function paste() {
    if (navigator.clipboard && navigator.clipboard.readText) {
      navigator.clipboard.readText().then(function (x) { $('u').value = (x || '').trim(); $('u').focus(); },
        function () { banner('wt', t.pasteHint); $('u').focus(); });
    } else { banner('wt', t.pasteHint); $('u').focus(); }
  }

  $('send').addEventListener('click', send);
  $('paste').addEventListener('click', paste);
  $('u').addEventListener('keydown', function (e) { if (e.key === 'Enter') send(); });
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
<div class="brand"><svg width="28" height="28" viewBox="0 0 72 72" aria-hidden="true"><circle cx="36" cy="36" r="30" fill="none" stroke="#FFB84D" stroke-width="9"/><circle cx="36" cy="36" r="10" fill="#4FD1C5"/></svg><span class="hd h22" data-t="brand">Lumio</span></div>
<div id="msg" class="msg hidden" role="status" aria-live="polite"></div>
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
<div><h1 class="hd h26" data-t="addTitle"></h1><div class="sm mt4" data-t="addHelp"></div></div>
<label class="l" for="u" data-t="linkLabel"></label>
<input class="in" id="u" type="text" inputmode="url" autocapitalize="none" autocomplete="off" autocorrect="off" spellcheck="false" maxlength="2048" placeholder="https://…/manifest.json">
<div class="row"><button class="bt b2 f1" id="paste" type="button" data-t="paste"></button><button class="bt b1 f2" id="send" type="button" data-t="send"></button></div>
<a class="lk" href="https://stremio-addons.net" target="_blank" rel="noopener noreferrer"><span data-t="browse"></span><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#A9B2BF" stroke-width="2.5" aria-hidden="true"><path d="M7 17L17 7M9 7h8v8"/></svg></a>
<div class="sm" data-t="browseHint"></div>
<h2 class="hd h20" data-t="mine"></h2>
<div id="none" class="sm hidden" data-t="none"></div>
<ul id="list" class="col lst"></ul>
<div class="sm foot" id="host"></div>
</section>
</div>
<template id="row-tpl"><li class="card"><div class="ar"><div class="lg" aria-hidden="true"></div><div class="tx"><div class="nm"></div><div class="sm sub"></div></div>
<button type="button" class="ib up"><svg viewBox="0 0 24 24" fill="none" stroke="#F3F5F7" stroke-width="2.5" aria-hidden="true"><path d="M6 15l6-6 6 6"/></svg></button>
<button type="button" class="ib down"><svg viewBox="0 0 24 24" fill="none" stroke="#F3F5F7" stroke-width="2.5" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg></button>
<button type="button" class="ib del"><svg viewBox="0 0 24 24" fill="none" stroke="#FF7A70" stroke-width="2.5" aria-hidden="true"><path d="M5 7h14M10 7V5h4v2M7 7l1 13h8l1-13"/></svg></button></div>
<div class="ct"><button type="button" class="sw" role="switch" aria-checked="true"><i aria-hidden="true"></i><span class="swt"></span></button><span class="ty"></span></div>
<div class="cf hidden" role="alertdialog"><div class="cft"></div><button type="button" class="bt bd cy"></button><button type="button" class="bt b2 cn"></button></div></li></template>
<script src="/app.js"></script>
</body>
</html>
''';
