/// Navigation à la télécommande dans la page de configuration d'un addon : la
/// WebView n'reçoit pas le D-pad d'Android TV, ce script déplace le focus au
/// plus proche voisin et renvoie à Flutter ce qu'il faut faire (clavier TV,
/// liste de choix). Aucun réseau, aucune donnée de la page n'est journalisée.
const configureDpadScript = r"""(function () {
  if (window.__lumioNav) return;
  var SEL = 'a[href],button,input:not([type=hidden]),select,textarea,summary,[role=button],[role=checkbox],[role=switch],[tabindex]:not([tabindex="-1"]),label[for]';
  var st = document.createElement('style');
  st.textContent = ':focus{outline:4px solid #FFB84D !important;outline-offset:2px !important}';
  (document.head || document.documentElement).appendChild(st);
  function visible(el) {
    if (el.disabled) return false;
    var r = el.getBoundingClientRect();
    if (r.width < 4 || r.height < 4) return false;
    var cs = getComputedStyle(el);
    return cs.visibility !== 'hidden' && cs.display !== 'none' && cs.pointerEvents !== 'none';
  }
  function cands() {
    var out = [];
    var all = document.querySelectorAll(SEL);
    for (var i = 0; i < all.length; i++) if (visible(all[i])) out.push(all[i]);
    return out;
  }
  function center(r) { return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }
  window.__lumioNav = function (dir) {
    var list = cands();
    var cur = document.activeElement;
    if (!cur || cur === document.body || list.indexOf(cur) < 0) {
      var first = null;
      for (var i = 0; i < list.length; i++) {
        var r0 = list[i].getBoundingClientRect();
        if (r0.bottom > 0 && r0.top < innerHeight) {
          if (!first || r0.top < first.getBoundingClientRect().top) first = list[i];
        }
      }
      first = first || list[0];
      if (!first) return 'none';
      first.focus({ preventScroll: true });
      first.scrollIntoView({ block: 'nearest' });
      return 'ok';
    }
    var cr = cur.getBoundingClientRect();
    var c = center(cr);
    var best = null, bestScore = 1e12;
    for (var j = 0; j < list.length; j++) {
      var el = list[j];
      if (el === cur) continue;
      var r = el.getBoundingClientRect();
      var p = center(r);
      var dx = p.x - c.x, dy = p.y - c.y, prim, sec;
      if (dir === 'down') { if (r.top < cr.bottom - 2 && dy <= 0) continue; prim = dy; sec = Math.abs(dx); }
      else if (dir === 'up') { if (r.bottom > cr.top + 2 && dy >= 0) continue; prim = -dy; sec = Math.abs(dx); }
      else if (dir === 'right') { if (r.left < cr.right - 2 && dx <= 0) continue; prim = dx; sec = Math.abs(dy); }
      else { if (r.right > cr.left + 2 && dx >= 0) continue; prim = -dx; sec = Math.abs(dy); }
      if (prim <= 0) continue;
      var score = prim + sec * 2.5;
      if (score < bestScore) { bestScore = score; best = el; }
    }
    if (best) {
      best.focus({ preventScroll: true });
      best.scrollIntoView({ block: 'nearest', inline: 'nearest' });
      return 'ok';
    }
    if (dir === 'down' || dir === 'up') {
      var before = window.scrollY;
      window.scrollBy(0, dir === 'down' ? 320 : -320);
      if (window.scrollY !== before) return 'scrolled';
    }
    return 'edge';
  };
  // Action sur l'élément ciblé : renvoie ce que Flutter doit faire.
  window.__lumioOk = function () {
    var el = document.activeElement;
    if (!el || el === document.body) return JSON.stringify({ k: 'none' });
    var tag = el.tagName.toLowerCase();
    if (tag === 'select') {
      var opts = [];
      for (var i = 0; i < el.options.length; i++) opts.push(el.options[i].text);
      return JSON.stringify({ k: 'select', options: opts, index: el.selectedIndex });
    }
    if (tag === 'textarea' || (tag === 'input' && /^(text|search|url|email|tel|password|number|)$/i.test(el.type || ''))) {
      return JSON.stringify({ k: 'text', value: el.value || '', label: el.getAttribute('aria-label') || el.placeholder || '', secret: el.type === 'password' });
    }
    el.click();
    return JSON.stringify({ k: 'clicked' });
  };
  function fire(el, name) { el.dispatchEvent(new Event(name, { bubbles: true })); }
  window.__lumioSetText = function (v) {
    var el = document.activeElement;
    if (!el) return;
    var proto = el.tagName.toLowerCase() === 'textarea' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
    setter.call(el, v);
    fire(el, 'input');
    fire(el, 'change');
  };
  window.__lumioSetSelect = function (i) {
    var el = document.activeElement;
    if (!el || el.tagName.toLowerCase() !== 'select') return;
    el.selectedIndex = i;
    fire(el, 'input');
    fire(el, 'change');
  };
})();
""";
