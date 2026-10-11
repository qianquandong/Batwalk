/* Batwalk · Gentle pixel engine (v2).
   64 × 64 logical canvas, nearest-neighbour. Every bat is built from the same
   part library (body, ears, wings, face, motif) with its own proportions,
   palette and props, then outlined and rim-shaded once, so the whole roster
   reads as one hand. Poses give idle / sleep / fly / pet / eat frames with the
   frame plan in PLAN — mirrored exactly by GeneratedFramePlan in BatwalkCore.
   Classic script: window.BatwalkPixel in a page, module.exports in Node.
   Export the app's frames with export_frames.js next to this file. */
(function (root) {
  'use strict';
  var W = 64, H = 64;

  // ---------------------------------------------------------------- grid
  function Grid() { this.p = []; for (var i = 0; i < W * H; i++) this.p.push(null); this.lineColor = '#2B1E1E'; }
  Grid.prototype.get = function (x, y) { return (x < 0 || y < 0 || x >= W || y >= H) ? null : this.p[y * W + x]; };
  Grid.prototype.set = function (x, y, c) { x = Math.round(x); y = Math.round(y); if (c !== undefined && x >= 0 && y >= 0 && x < W && y < H) this.p[y * W + x] = c; };
  Grid.prototype.rect = function (x, y, w, h, c) { for (var j = 0; j < h; j++) for (var i = 0; i < w; i++) this.set(x + i, y + j, c); };
  Grid.prototype.ell = function (cx, cy, rx, ry, c) {
    for (var y = Math.floor(cy - ry) - 1; y <= Math.ceil(cy + ry) + 1; y++)
      for (var x = Math.floor(cx - rx) - 1; x <= Math.ceil(cx + rx) + 1; x++) {
        var dx = (x + 0.5 - cx) / (rx + 0.5), dy = (y + 0.5 - cy) / (ry + 0.5);
        if (dx * dx + dy * dy <= 1) this.set(x, y, c);
      }
  };
  Grid.prototype.tri = function (ax, ay, bx, by, cx, cy, c) {
    var minX = Math.floor(Math.min(ax, bx, cx)), maxX = Math.ceil(Math.max(ax, bx, cx));
    var minY = Math.floor(Math.min(ay, by, cy)), maxY = Math.ceil(Math.max(ay, by, cy));
    var d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
    if (!d) return;
    for (var y = minY; y <= maxY; y++) for (var x = minX; x <= maxX; x++) {
      var px = x + 0.5, py = y + 0.5;
      var l1 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / d;
      var l2 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / d;
      var l3 = 1 - l1 - l2;
      if (l1 >= -0.02 && l2 >= -0.02 && l3 >= -0.02) this.set(x, y, c);
    }
  };
  Grid.prototype.line = function (x0, y0, x1, y1, c) {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    var dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, err = dx + dy;
    for (var n = 0; n < 200; n++) {
      this.set(x0, y0, c);
      if (x0 === x1 && y0 === y1) break;
      var e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  };
  /** 1-px line colour around every filled pixel (4-neighbour). */
  Grid.prototype.outline = function (c) {
    var add = [];
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
      if (this.get(x, y)) continue;
      if (this.get(x - 1, y) || this.get(x + 1, y) || this.get(x, y - 1) || this.get(x, y + 1)) add.push([x, y]);
    }
    for (var i = 0; i < add.length; i++) this.set(add[i][0], add[i][1], c);
  };
  /** Rim shade: a base colour touching the outline from below or the right darkens. */
  Grid.prototype.rim = function (pairs) {
    var line = this.lineColor, map = {};
    for (var i = 0; i < pairs.length; i++) if (pairs[i][0]) map[pairs[i][0]] = pairs[i][1];
    var out = [];
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
      var v = this.get(x, y);
      if (v && map[v] && (this.get(x, y + 1) === line || this.get(x + 1, y) === line)) out.push([x, y, map[v]]);
    }
    for (var k = 0; k < out.length; k++) this.set(out[k][0], out[k][1], out[k][2]);
  };
  /** SVG path per colour (row runs) — ~8 paths per sprite instead of ~1,500 rects. */
  Grid.prototype.paths = function () {
    var byColor = {}, order = [];
    for (var y = 0; y < H; y++) {
      var x = 0;
      while (x < W) {
        var c = this.get(x, y);
        if (!c) { x++; continue; }
        var start = x;
        while (x < W && this.get(x, y) === c) x++;
        if (!byColor[c]) { byColor[c] = []; order.push(c); }
        byColor[c].push('M' + start + ' ' + y + 'h' + (x - start) + 'v1h-' + (x - start) + 'z');
      }
    }
    return order.map(function (c) { return { fill: c, d: byColor[c].join('') }; });
  };
  Grid.prototype.count = function () { var n = 0; for (var i = 0; i < W * H; i++) if (this.p[i]) n++; return n; };

  // ---------------------------------------------------------------- colour
  function hexToRgb(h) { h = h.replace('#', ''); if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]; return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)]; }
  function rgbToHex(r, g, b) { function t(v) { v = Math.max(0, Math.min(255, Math.round(v))); return (v < 16 ? '0' : '') + v.toString(16); } return '#' + t(r) + t(g) + t(b); }
  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255; var max = Math.max(r, g, b), min = Math.min(r, g, b), h = 0, s = 0, l = (max + min) / 2;
    if (max !== min) { var d = max - min; s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      if (max === r) h = (g - b) / d + (g < b ? 6 : 0); else if (max === g) h = (b - r) / d + 2; else h = (r - g) / d + 4; h /= 6; }
    return [h, s, l];
  }
  function hslToRgb(h, s, l) {
    function f(p, q, t) { if (t < 0) t += 1; if (t > 1) t -= 1; if (t < 1 / 6) return p + (q - p) * 6 * t; if (t < 1 / 2) return q; if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6; return p; }
    if (s === 0) return [l * 255, l * 255, l * 255];
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    return [f(p, q, h + 1 / 3) * 255, f(p, q, h) * 255, f(p, q, h - 1 / 3) * 255];
  }
  function shift(hex, deg, satMul, lightAdd) {
    if (!hex || hex[0] !== '#') return hex;
    var c = hexToRgb(hex.length > 7 ? hex.substr(0, 7) : hex), hsl = rgbToHsl(c[0], c[1], c[2]);
    var h = (hsl[0] + deg / 360) % 1; if (h < 0) h += 1;
    var s = Math.max(0, Math.min(1, hsl[1] * (satMul || 1))), l = Math.max(0, Math.min(1, hsl[2] + (lightAdd || 0)));
    var o = hslToRgb(h, s, l); return rgbToHex(o[0], o[1], o[2]);
  }
  /** Shiny: a real second colourway where one is designed, else a hue spin that keeps outline and eyes. */
  function shinyPalette(P, spec) {
    if (spec.shiny) { var out = {}; for (var k in P) out[k] = P[k]; for (var j in spec.shiny) out[j] = spec.shiny[j]; return out; }
    var deg = spec.shinyShift === undefined ? 150 : spec.shinyShift, S = {};
    for (var key in P) S[key] = (key === 'line' || key === 'eye' || key === 'white') ? P[key] : shift(P[key], deg, 1, 0.02);
    return S;
  }

  // ---------------------------------------------------------------- parts
  /** Wing tip height for a pose: a number (px below the shoulder), or null when folded. */
  function wingTip(pose) {
    var w = pose.wings;
    if (typeof w === 'number') return w;
    if (w === 'up') return -14; if (w === 'mid') return -3; if (w === 'down') return 9;
    return null;
  }
  function wingsBack(c) {
    var g = c.g, P = c.P, tip = wingTip(c.pose), s;
    if (tip !== null) {
      for (s = -1; s <= 1; s += 2) {
        var sx = c.cx + s * (c.rx - 3), sy = c.cy - 1;
        var tx = c.cx + s * (c.rx + 16), ty = c.cy + tip;
        // the trailing edge drops with the wing so the down-stroke keeps a full membrane
        var mx = c.cx + s * (c.rx + 9), my = c.cy + 7 + Math.max(0, tip) * 0.5;
        g.tri(sx, sy - 3, tx, ty, mx, my, P.wing);
        g.tri(sx, sy - 3, mx, my, c.cx + s * (c.rx - 1), c.cy + 8, P.wing);
        // finger bone and scallops read as a bat wing even at 64 px
        g.line(sx, sy - 2, tx, ty, P.wingShade);
        g.ell(c.cx + s * (c.rx + 4), c.cy + 9 + Math.max(0, tip) * 0.25, 2, 2, null);
        g.ell(c.cx + s * (c.rx + 11), my + 1, 2, 2, null);
      }
      return;
    }
    if (c.spec.wings === 'cape' || c.spec.wings === 'hood') return; // drawn in front
    for (s = -1; s <= 1; s += 2) { // folded lobes behind the body
      g.ell(c.cx + s * (c.rx + 1), c.cy + 3, 4, 8, P.wing);
      g.ell(c.cx + s * (c.rx + 3), c.cy + 10, 2, 2, null);
    }
  }
  function wingsFront(c) {
    var g = c.g, P = c.P;
    if (wingTip(c.pose) !== null) return;
    var type = c.spec.wings;
    if (type === 'cape' || type === 'hood') {
      var top = type === 'hood' ? c.cy - c.ry * 0.25 : c.cy + c.ry * 0.15;
      for (var s = -1; s <= 1; s += 2) {
        g.ell(c.cx + s * (c.rx * 0.45), top + c.ry * 0.45, c.rx * 0.78, c.ry * 0.62, P.wing);
      }
      // the wings cross at the chest; scalloped hem; the belly peeks out on a hood
      g.ell(c.cx, c.cy + c.ry * 0.9, c.rx * 0.6, c.ry * 0.3, P.wing);
      for (var k = -1; k <= 1; k++) g.ell(c.cx + k * (c.rx * 0.7), c.cy + c.ry + 1, 2.5, 2, null);
      g.line(c.cx, top + c.ry * 0.45, c.cx, c.cy + c.ry - 2, P.wingShade);
      if (type === 'hood') g.ell(c.cx, c.cy + c.ry * 0.55, c.rx * 0.35, c.ry * 0.3, P.belly || P.base);
    }
  }
  function ears(c) {
    var g = c.g, P = c.P, e = c.spec.ears || {}, type = e.type || 'round', off = e.off || c.rx * 0.6, top = c.cy - c.ry;
    var tw = c.pose.earTwitch || 0;
    for (var s = -1; s <= 1; s += 2) {
      var bx = c.cx + s * off, twist = (s === 1 ? tw : 0);
      if (type === 'round') { g.ell(bx, top + 1 + twist, 5, 5, P.base); g.ell(bx, top + 1 + twist, 3, 3, P.ear); }
      else if (type === 'pointy' || type === 'tuft') {
        g.tri(bx - 4, top + 4, bx + 4, top + 4, bx + s * 3, top - 9 + twist, P.base);
        g.tri(bx - 2, top + 3, bx + 2, top + 3, bx + s * 2, top - 5 + twist, P.ear);
        if (type === 'tuft') { g.set(bx + s * 4, top - 10 + twist, P.base); g.set(bx + s * 5, top - 11 + twist, P.base); }
      }
      else if (type === 'long') {
        // Leaf-shaped bat ears that lean outward: wider at the base, pointed at the tip.
        for (var row = 0; row < 13; row++) {
          var yy = top + 3 - row + twist, lean = Math.round(row * 0.45), half = row < 2 ? 3 : Math.max(1, Math.round(3.2 - row * 0.2));
          g.rect(bx + s * lean - half, yy, half * 2 + 1, 1, P.base);
          if (row > 1 && row < 11 && half > 1) g.rect(bx + s * lean - (half - 1), yy, half * 2 - 1, 1, P.ear);
        }
        g.set(bx + s * 6, top - 10 + twist, P.base);
      }
      else if (type === 'giant') { g.ell(bx + s * 2, top - 3 + twist, 7, 8, P.base); g.ell(bx + s * 2, top - 2 + twist, 5, 6, P.ear); }
      else if (type === 'small') { g.ell(bx, top + 2 + twist, 3, 3, P.base); g.ell(bx, top + 2 + twist, 1.5, 1.5, P.ear); }
      else if (type === 'droop') { g.ell(bx + s * 3, top + 4 + twist, 4, 6, P.base); g.ell(bx + s * 3, top + 5 + twist, 2, 4, P.ear); }
    }
  }
  function body(c) {
    var g = c.g, P = c.P, shape = c.spec.body.shape || 'round';
    if (shape === 'fluffy' || shape === 'cloud') {
      for (var a = 0; a < 10; a++) { var t = a / 10 * Math.PI * 2; g.ell(c.cx + Math.cos(t) * c.rx * 0.85, c.cy + Math.sin(t) * c.ry * 0.85, 4, 4, P.base); }
    }
    g.ell(c.cx, c.cy, c.rx, c.ry, P.base);
    if (shape === 'squat') g.rect(c.cx - c.rx + 2, c.cy + c.ry - 2, c.rx * 2 - 4, 3, P.base);
    if (P.belly) g.ell(c.cx, c.cy + c.ry * 0.32, c.rx * 0.55, c.ry * 0.42, P.belly);
    g.ell(c.cx - c.rx * 0.45, c.cy - c.ry * 0.55, c.rx * 0.22, c.ry * 0.14, P.light); // soft top-left highlight
  }
  function face(c) {
    var g = c.g, P = c.P, f = c.spec.face || {}, pose = c.pose;
    var eyeY = Math.round(c.cy - c.ry * 0.12), ex = Math.round(c.rx * 0.42);
    var eyes = pose.eyes || f.eyes || 'open';
    for (var s = -1; s <= 1; s += 2) {
      var x = c.cx + s * ex + (pose.look || 0);
      if (eyes === 'open') { g.rect(x - 1, eyeY - 2, 3, 4, P.eye); g.set(x - 1, eyeY - 2, P.white); }
      else if (eyes === 'half') { g.rect(x - 1, eyeY, 3, 2, P.eye); g.rect(x - 1, eyeY - 1, 3, 1, P.shade); }
      else if (eyes === 'closed') { g.set(x - 1, eyeY, P.eye); g.set(x, eyeY + 1, P.eye); g.set(x + 1, eyeY, P.eye); }
      else if (eyes === 'happy') { g.set(x - 1, eyeY + 1, P.eye); g.set(x, eyeY, P.eye); g.set(x + 1, eyeY + 1, P.eye); }
      else if (eyes === 'dot') { g.rect(x, eyeY - 1, 2, 2, P.eye); }
      else if (eyes === 'glint') { g.rect(x - 1, eyeY - 1, 3, 3, P.eye); g.set(x, eyeY, P.acc); }
      if (pose.blush || f.cheeks) g.rect(x + (s < 0 ? -4 : 2), eyeY + 3, 2, 1, P.cheek || '#E89A9A');
    }
    var my = eyeY + 4, mouth = pose.mouth || f.mouth || 'smile';
    if (f.nose === 'pig') { g.rect(c.cx - 2, my - 1, 5, 3, P.cheek || '#E8A0A0'); g.set(c.cx - 1, my, P.line); g.set(c.cx + 1, my, P.line); my += 3; }
    if (f.nose === 'snout') { g.ell(c.cx, my + 1, 6, 4, P.shade); g.ell(c.cx, my, 5, 3, P.base); g.set(c.cx - 2, my, P.line); g.set(c.cx + 2, my, P.line); my += 3; }
    if (f.nose === 'tube') { g.rect(c.cx - 4, my - 2, 2, 4, P.ear); g.rect(c.cx + 3, my - 2, 2, 4, P.ear); g.set(c.cx - 3, my - 3, P.line); g.set(c.cx + 4, my - 3, P.line); }
    if (f.nose === 'leaf') { g.tri(c.cx - 3, my + 1, c.cx + 3, my + 1, c.cx, my - 4, P.ear); }
    if (mouth === 'smile') { g.set(c.cx - 1, my, P.line); g.set(c.cx, my + 1, P.line); g.set(c.cx + 1, my, P.line); }
    else if (mouth === 'w') { g.set(c.cx - 2, my, P.line); g.set(c.cx - 1, my + 1, P.line); g.set(c.cx, my, P.line); g.set(c.cx + 1, my + 1, P.line); g.set(c.cx + 2, my, P.line); }
    else if (mouth === 'open') { g.rect(c.cx - 1, my, 3, 2, '#5A2A2A'); g.set(c.cx, my + 1, '#E88A9A'); }
    else if (mouth === 'chew') { var side = pose.chewSide || 1; g.rect(c.cx - 1, my + 1, 3, 1, P.line); g.ell(c.cx + side * (ex + 1), eyeY + 3, 3, 2, P.light); }
    else if (mouth === 'small') { g.set(c.cx, my, P.line); }
    else if (mouth === 'honk') { g.rect(c.cx - 2, my, 4, 2, '#5A2A2A'); }
    if (f.fangs && mouth !== 'open') { g.set(c.cx - 2, my + 1, P.white); g.set(c.cx + 2, my + 1, P.white); }
    if (f.tongue) { g.rect(c.cx, my + 1, 1, 6, '#F28AB0'); g.rect(c.cx + 1, my + 5, 3, 1, '#F28AB0'); }
    if (f.mask) { g.rect(c.cx - ex - 3, eyeY - 3, ex * 2 + 7, 6, f.mask); g.rect(c.cx - ex - 1, eyeY - 2, 3, 4, P.eye); g.rect(c.cx + ex - 1, eyeY - 2, 3, 4, P.eye); g.set(c.cx - ex - 1, eyeY - 2, P.white); g.set(c.cx + ex - 1, eyeY - 2, P.white); }
    if (f.chinMask) { g.ell(c.cx, my + 2, ex + 3, 3, f.chinMask); }
  }
  function feet(c) {
    if (c.pose.lift) return;
    var y = Math.round(c.cy + c.ry);
    c.g.rect(c.cx - 4, y, 2, 1, c.P.line); c.g.rect(c.cx + 3, y, 2, 1, c.P.line);
  }
  // particles are drawn after the outline so they stay crisp and self-contained
  function heart(g, x, y, col) { g.set(x - 1, y, col); g.set(x + 1, y, col); g.rect(x - 2, y + 1, 5, 1, col); g.rect(x - 1, y + 2, 3, 1, col); g.set(x, y + 3, col); }
  function zee(g, x, y, big, col) { if (big) { g.rect(x, y, 4, 1, col); g.set(x + 2, y + 1, col); g.set(x + 1, y + 2, col); g.rect(x, y + 3, 4, 1, col); } else { g.rect(x, y, 3, 1, col); g.set(x + 1, y + 1, col); g.rect(x, y + 2, 3, 1, col); } }
  function strawberry(g, x, y, bite) {
    var red = '#D9534F', seed = '#F7E7A6', leaf = '#6FA85A', line = '#3A1E1E';
    g.ell(x, y + 1, 3, 3, red); if (bite) g.ell(x + 3, y + 1, 2, 2, null);
    g.set(x - 1, y + 1, seed); g.set(x + 1, y + 2, seed); g.set(x, y + 3, seed);
    g.tri(x - 3, y - 2, x + 3, y - 2, x, y - 4, leaf); g.rect(x - 2, y - 2, 5, 1, leaf);
    for (var dy = -4; dy <= 4; dy++) for (var dx = -4; dx <= 4; dx++) { var px = x + dx, py = y + dy; if (!g.get(px, py) && (g.get(px - 1, py) || g.get(px + 1, py) || g.get(px, py - 1) || g.get(px, py + 1))) { var n = [g.get(px - 1, py), g.get(px + 1, py), g.get(px, py - 1), g.get(px, py + 1)]; if (n.indexOf(red) >= 0 || n.indexOf(leaf) >= 0 || n.indexOf(seed) >= 0) g.set(px, py, line); } }
  }
  function sparkle(g, x, y, col) { g.set(x, y - 1, col); g.set(x - 1, y, col); g.set(x, y, col); g.set(x + 1, y, col); g.set(x, y + 1, col); }
  function particles(c) {
    var g = c.g, p = c.pose, i;
    if (p.z) for (i = 0; i < p.z.length; i++) zee(g, p.z[i][0], p.z[i][1], p.z[i][2], '#F4F0E2');
    if (p.hearts) for (i = 0; i < p.hearts.length; i++) heart(g, p.hearts[i][0], p.hearts[i][1], '#E8A0A8');
    if (p.fruit) strawberry(g, p.fruit[0], p.fruit[1], p.fruit[2]);
    if (p.sparkles) for (i = 0; i < p.sparkles.length; i++) sparkle(g, p.sparkles[i][0], p.sparkles[i][1], '#EFE2B6');
  }

  // ---------------------------------------------------------------- bat
  function drawBat(spec, pose, shiny) {
    pose = pose || {};
    var g = new Grid(), P = shiny ? shinyPalette(spec.pal, spec) : spec.pal;
    P = Object.assign({ eye: '#2A1E1E', white: '#FFFFFF' }, P);
    if (!P.wing) P.wing = P.shade; if (!P.wingShade) P.wingShade = P.line; if (!P.light) P.light = P.base;
    g.lineColor = P.line;
    var lift = pose.lift || 0;
    var c = { g: g, P: P, spec: spec, pose: pose,
      cx: 32 + (pose.dx || 0), cy: 37 + (pose.dy || 0) - lift,
      rx: spec.body.rx + (pose.sx || 0), ry: spec.body.ry + (pose.sy || 0) };
    if (spec.back) spec.back(c);
    wingsBack(c);
    ears(c);
    body(c);
    if (spec.front) spec.front(c);
    wingsFront(c);
    face(c);
    if (spec.motif) spec.motif(c);
    feet(c);
    g.outline(P.line);
    g.rim([[P.base, P.shade], [P.wing, P.wingShade], [P.belly, P.shade], [P.acc, P.accShade || P.shade]]);
    particles(c);
    return g;
  }

  // ---------------------------------------------------------------- poses
  // Each action is a list of frames; PLAN gives their durations and the rest
  // on frame 0 after an ambient cycle. The Swift player mirrors PLAN exactly.
  function idlePoses() {
    var dy = [0, -1, -1, 0, 1, 1, 0, 0], sy = [0, 0, 0, 0, -1, -1, 0, 0];
    return dy.map(function (d, i) {
      var p = { dy: d, sy: sy[i], sx: sy[i] ? 1 : 0 };
      if (i === 2) p.earTwitch = 1;   // one ear perks at the top of the breath
      if (i === 5) p.eyes = 'closed'; // a blink on the way down
      return p;
    });
  }
  function sleepPoses() {
    var sy = [-2, -2, -1, -1, 0, -1, -1, -2];
    return sy.map(function (s, f) {
      var z = [];
      if (f <= 5) z.push([44, 16 - 2 * f, f >= 3]);
      if (f >= 3) z.push([48, 17 - 2 * (f - 3), f >= 6]);
      if (f >= 6) z.push([44, 16 - 2 * (f - 6), false]);
      return { eyes: 'closed', mouth: 'small', sy: s, sx: 1, z: z };
    });
  }
  function flyPoses() {
    var tips = [-14, -9, -3, 4, 10, 3], lift = [5, 7, 8, 8, 7, 6];
    return tips.map(function (t, f) {
      return { wings: t, lift: lift[f], eyes: 'open', mouth: f === 3 ? 'open' : 'smile', sy: f === 0 ? -1 : 0 };
    });
  }
  function petPoses() {
    var dy = [0, -1, -2, -2, -1, 0, 0, 0], sy = [0, 1, 1, 0, 0, 0, 0, 0];
    return dy.map(function (d, f) {
      var hearts = [];
      if (f <= 4) hearts.push([50, 20 - 3 * f]);
      if (f >= 2 && f <= 6) hearts.push([13, 22 - 3 * (f - 2)]);
      if (f >= 4) hearts.push([34, 13 - 2 * (f - 4)]);
      return { eyes: 'happy', mouth: 'w', blush: true, dy: d, sy: sy[f], sx: sy[f] ? 1 : 0, hearts: hearts };
    });
  }
  var EAT = [
    { eyes: 'open', mouth: 'open', fruit: [54, 40, false] },
    { eyes: 'open', mouth: 'open', fruit: [49, 40, false], dx: 1 },
    { eyes: 'open', mouth: 'open', fruit: [44, 40, false], dx: 1 },
    { eyes: 'closed', mouth: 'chew', chewSide: 1, fruit: [40, 41, true], sx: 1, sy: -1 },
    { eyes: 'closed', mouth: 'chew', chewSide: -1, sx: 1, sy: -1 },
    { eyes: 'closed', mouth: 'chew', chewSide: 1, sx: 1 },
    { eyes: 'closed', mouth: 'small', sy: -1, dy: 1 },
    { eyes: 'happy', mouth: 'w', blush: true, sparkles: [[48, 24], [16, 28]] }
  ];
  var POSES = { idle: idlePoses(), sleep: sleepPoses(), fly: flyPoses(), pet: petPoses(), eat: EAT };
  /** Frame plan: seconds per frame, then rest on frame 0 (ambient actions only).
      Must match GeneratedFramePlan in Packages/BatwalkCore (BatAnimation.swift). */
  var PLAN = {
    idle: { seconds: [0.6, 0.14, 0.14, 0.14, 0.14, 0.14, 0.14, 0.2], rest: 1.6 },
    sleep: { seconds: [0.32, 0.32, 0.32, 0.32, 0.32, 0.32, 0.32, 0.32], rest: 0.8 },
    fly: { seconds: [0.1, 0.1, 0.1, 0.1, 0.1, 0.1], rest: 0 },
    pet: { seconds: [0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12], rest: 0 },
    eat: { seconds: [0.18, 0.14, 0.14, 0.22, 0.2, 0.2, 0.22, 0.3], rest: 0 }
  };
  var TIMING = {};
  for (var act in PLAN) TIMING[act] = PLAN[act].seconds;
  function moodPose(mood) {
    if (mood === 'sleeping') return POSES.sleep[0];
    if (mood === 'drowsy') return { eyes: 'half', mouth: 'small', sy: -1 };
    if (mood === 'happy') return POSES.pet[0];
    if (mood === 'eating') return POSES.eat[1];
    if (mood === 'playing') return POSES.fly[1];
    return POSES.idle[0];
  }

  // ---------------------------------------------------------------- roster
  function pal(base, shade, light, line, ear, belly, extra) {
    var p = { base: base, shade: shade, light: light, line: line, ear: ear, belly: belly };
    if (extra) for (var k in extra) p[k] = extra[k];
    return p;
  }
  var SPECIES = [
    { id: 'mochi', number: 1, name: 'Mochi Bat', rarity: 'common', free: true,
      pal: pal('#E2A26C', '#B9784A', '#F3C79A', '#4A2C22', '#F2B4A4', '#F7E4CB', { cheek: '#EFA0A0' }),
      body: { rx: 12, ry: 11 }, ears: { type: 'round', off: 7 }, wings: 'fold',
      shiny: { base: '#F2CFE0', shade: '#C98FB0', light: '#FBE7F0', ear: '#F7A9C4', belly: '#FFF5F8', wing: '#C98FB0' } },
    { id: 'cocoa', number: 2, name: 'Cocoa Bat', rarity: 'common', free: true,
      pal: pal('#6E4130', '#4B2A1D', '#8D5C44', '#2A1510', '#C9917A', '#DEB692', { wing: '#54301F', wingShade: '#3A2015', cheek: '#C97A6A' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'small', off: 7 }, wings: 'cape', face: { eyes: 'half', mouth: 'small' },
      shiny: { base: '#8FBFA0', shade: '#5E8E70', light: '#B6DCC2', ear: '#F2C9B8', belly: '#EAF5E6', wing: '#6FA083', wingShade: '#4C7560' } },
    { id: 'long-ear', number: 3, name: 'Long Ear Bat', rarity: 'common', free: true,
      pal: pal('#E9CDBA', '#C7A48E', '#F8EADF', '#4A2E2E', '#F2A6B9', '#FBF2EA', { cheek: '#EFA3A3', wing: '#CFAE9A' }),
      body: { rx: 11, ry: 10 }, ears: { type: 'long', off: 5 }, wings: 'fold', face: { mouth: 'w' },
      shiny: { base: '#C9B7E8', shade: '#9E88C9', light: '#E5DBF7', ear: '#F2C0D9', belly: '#F4F0FB', wing: '#AE9AD4' } },
    { id: 'fruit', number: 4, name: 'Fruit Bat', rarity: 'common',
      pal: pal('#F0A24F', '#C87A2C', '#F8CA92', '#4A2A14', '#F7C9A0', '#FBE3C4', { cheek: '#F09A8A', acc: '#A8C86A', accShade: '#6E9A42' }),
      body: { rx: 13, ry: 11 }, ears: { type: 'round', off: 8 }, wings: 'fold', face: { cheeks: true, mouth: 'open' },
      motif: function (c) { c.g.ell(c.cx + 2, c.cy + 7, 3, 3.5, c.P.acc); c.g.set(c.cx + 2, c.cy + 3, c.P.line); } },
    { id: 'cave', number: 5, name: 'Cave Bat', rarity: 'common',
      pal: pal('#5B556E', '#403B52', '#7A7490', '#221E2E', '#A79DBF', '#B9B2CC', { wing: '#4A4460', wingShade: '#2E2A3E' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'pointy', off: 6 }, wings: 'hood', face: { eyes: 'dot', mouth: 'small' } },
    { id: 'sleepy', number: 6, name: 'Sleepy Bat', rarity: 'common',
      pal: pal('#B8A6DB', '#8E7BB8', '#D6CAEE', '#3A2E52', '#F2C4D6', '#EDE6F7', { acc: '#6C7CBF', accShade: '#4E5C96' }),
      body: { rx: 12, ry: 11 }, ears: { type: 'round', off: 7 }, wings: 'fold', face: { eyes: 'half', mouth: 'small' },
      motif: function (c) { var g = c.g, t = c.cy - c.ry; g.tri(c.cx - 9, t + 3, c.cx + 7, t + 3, c.cx + 11, t - 9, c.P.acc); g.rect(c.cx - 10, t + 2, 18, 2, '#F4F0E2'); g.ell(c.cx + 12, t - 9, 2, 2, '#F4F0E2'); } },
    { id: 'dust', number: 7, name: 'Dust Bat', rarity: 'common',
      pal: pal('#B3AFA7', '#86827A', '#D4D0C8', '#3B3833', '#E8C9C0', '#E2DFD8', { wing: '#9C988F' }),
      body: { rx: 12, ry: 11, shape: 'fluffy' }, ears: { type: 'tuft', off: 6 }, wings: 'fold', face: { eyes: 'dot', mouth: 'w' },
      motif: function (c) { c.g.set(c.cx - 17, c.cy + 9, c.P.shade); c.g.set(c.cx + 17, c.cy + 10, c.P.shade); c.g.set(c.cx - 15, c.cy + 12, c.P.shade); } },
    { id: 'pebble', number: 8, name: 'Pebble Bat', rarity: 'common',
      pal: pal('#8F8C87', '#67645F', '#B0ADA7', '#2F2D2A', '#C9B6B0', null, { wing: '#7A776F' }),
      body: { rx: 13, ry: 9, shape: 'squat' }, ears: { type: 'small', off: 8 }, wings: 'fold', face: { eyes: 'closed', mouth: 'small' },
      motif: function (c) { var g = c.g; g.ell(c.cx - 5, c.cy + 4, 1.5, 1, c.P.shade); g.ell(c.cx + 6, c.cy + 2, 1, 1, c.P.shade); g.ell(c.cx + 1, c.cy + 7, 1, 1, c.P.shade); } },
    { id: 'strawberry', number: 9, name: 'Strawberry Bat', rarity: 'uncommon',
      pal: pal('#D94F4F', '#A83636', '#EC8A86', '#4A1A1A', '#F7B8B0', null, { acc: '#6FA85A', accShade: '#4E7F3E', cheek: '#F2A0A0', wing: '#B53F3F' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'round', off: 7 }, wings: 'fold', face: { cheeks: true, mouth: 'w' },
      motif: function (c) { var g = c.g, t = c.cy - c.ry; for (var i = -2; i <= 2; i++) g.tri(c.cx + i * 4 - 3, t + 2, c.cx + i * 4 + 3, t + 2, c.cx + i * 4, t - 4, c.P.acc);
        var seeds = [[-6, 2], [-2, 6], [4, 3], [7, 7], [1, 10], [-7, 8]]; for (var s = 0; s < seeds.length; s++) g.set(c.cx + seeds[s][0], c.cy + seeds[s][1] - 4, '#F7E7A6'); } },
    { id: 'blossom', number: 10, name: 'Blossom Bat', rarity: 'uncommon',
      pal: pal('#F2B6C8', '#D388A3', '#FAD8E3', '#5A2E3E', '#FBE3EC', '#FDF0F5', { acc: '#F7D0DE', accShade: '#E39AB7', cheek: '#EE8FA6' }),
      body: { rx: 11, ry: 11 }, ears: { type: 'round', off: 7 }, wings: 'fold', face: { mouth: 'smile' },
      back: function (c) { var g = c.g, t = c.cy - c.ry + 2; for (var a = 0; a < 5; a++) { var th = -Math.PI / 2 + (a - 2) * 0.55; g.ell(c.cx + Math.cos(th) * 13, t + 2 + Math.sin(th) * 8, 3.5, 3.5, c.P.acc); } g.ell(c.cx, t - 5, 2, 2, '#F2C94C'); } },
    { id: 'moss', number: 11, name: 'Moss Bat', rarity: 'uncommon',
      pal: pal('#7F9A5A', '#5A7340', '#A3BC7C', '#2E3A1E', '#C9A47A', '#C8D7A6', { acc: '#A8D070', accShade: '#6FA042', wing: '#6B5A3E', wingShade: '#4A3C28' }),
      body: { rx: 12, ry: 11 }, ears: { type: 'droop', off: 6 }, wings: 'fold', face: { eyes: 'dot', mouth: 'small' },
      motif: function (c) { var g = c.g, t = c.cy - c.ry; g.rect(c.cx, t - 5, 1, 6, c.P.acc); g.ell(c.cx - 3, t - 5, 2.5, 1.5, c.P.acc); g.ell(c.cx + 3, t - 7, 2.5, 1.5, c.P.acc); } },
    { id: 'sunset', number: 12, name: 'Sunset Bat', rarity: 'uncommon',
      pal: pal('#F29A4B', '#C96A2A', '#F8C28A', '#4A2235', '#F7C8A0', '#FBD9A8', { wing: '#7B4FA8', wingShade: '#53327A', cheek: '#F08A8A' }),
      body: { rx: 12, ry: 11 }, ears: { type: 'pointy', off: 6 }, wings: 'fold', face: { mouth: 'open' },
      motif: function (c) { var g = c.g; g.rect(c.cx - 9, c.cy + 2, 18, 1, '#F6C06A'); g.rect(c.cx - 8, c.cy + 5, 16, 1, '#E886A0'); } },
    { id: 'snow', number: 13, name: 'Snow Bat', rarity: 'uncommon',
      pal: pal('#EEF4FA', '#B9D1E6', '#FFFFFF', '#3A4A66', '#BFE0F7', null, { acc: '#7FB2E0', cheek: '#C9D9F2', wing: '#D4E4F2' }),
      body: { rx: 12, ry: 11 }, ears: { type: 'round', off: 7 }, wings: 'fold', face: { cheeks: true, mouth: 'smile' },
      motif: function (c) { var g = c.g; sparkle(g, c.cx - 6, c.cy + 5, c.P.acc); sparkle(g, c.cx + 5, c.cy + 2, c.P.acc); g.set(c.cx + 1, c.cy + 9, c.P.acc); } },
    { id: 'cloud', number: 14, name: 'Cloud Bat', rarity: 'uncommon',
      pal: pal('#EAEDF1', '#BCC5D1', '#FFFFFF', '#3F4652', '#E8D0DA', null, { wing: '#D5DCE5', cheek: '#E7C3CC' }),
      body: { rx: 12, ry: 10, shape: 'cloud' }, ears: { type: 'small', off: 7 }, wings: 'fold', face: { eyes: 'half', mouth: 'smile', cheeks: true } },
    { id: 'moonwing', number: 15, name: 'Moonwing', rarity: 'rare',
      pal: pal('#3B4A9C', '#263173', '#5B6CC4', '#141A3F', '#8EA2E8', '#B9C5F2', { acc: '#F2E3A6', accShade: '#CBB973', wing: '#2E3A80', wingShade: '#1C2457' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'pointy', off: 6 }, wings: 'fold', face: { eyes: 'glint', mouth: 'smile' },
      motif: function (c) { var g = c.g, t = c.cy - c.ry; g.ell(c.cx, t + 5, 3, 3, c.P.acc); g.ell(c.cx + 1.5, t + 4.5, 2.5, 2.5, c.P.base); g.set(c.cx - 9, c.cy + 2, c.P.acc); g.set(c.cx + 9, c.cy + 6, c.P.acc); } },
    { id: 'golden', number: 16, name: 'Golden Bat', rarity: 'rare',
      pal: pal('#E8BB4D', '#B88A2A', '#F6DA8E', '#4A3410', '#F7D7A0', '#F9E8BE', { acc: '#F8E08A', accShade: '#C9A83E', cheek: '#F0B080' }),
      body: { rx: 12, ry: 11 }, ears: { type: 'pointy', off: 6 }, wings: 'fold', face: { mouth: 'smile', eyes: 'glint' },
      motif: function (c) { var g = c.g, t = c.cy - c.ry; g.rect(c.cx - 5, t - 1, 10, 3, c.P.acc); g.tri(c.cx - 5, t - 1, c.cx - 1, t - 1, c.cx - 4, t - 6, c.P.acc); g.tri(c.cx - 2, t - 1, c.cx + 2, t - 1, c.cx, t - 7, c.P.acc); g.tri(c.cx + 1, t - 1, c.cx + 5, t - 1, c.cx + 4, t - 6, c.P.acc); sparkle(g, c.cx + 15, c.cy - 8, c.P.acc); } },
    { id: 'crystal', number: 17, name: 'Crystal Bat', rarity: 'rare',
      pal: pal('#91B8E8', '#6185C9', '#C3DBF5', '#2A3A66', '#C9D9FF', '#DCE9FF', { acc: '#D9E6FF', accShade: '#8FA8E0', wing: '#7A9BE0', wingShade: '#4E6BB0' }),
      body: { rx: 12, ry: 11 }, ears: { type: 'pointy', off: 6 }, wings: 'fold', face: { mouth: 'small', eyes: 'glint' },
      motif: function (c) { var g = c.g, t = c.cy - c.ry; g.tri(c.cx - 2, t + 1, c.cx + 2, t + 1, c.cx, t - 7, c.P.acc); g.tri(c.cx - 14, c.cy + 3, c.cx - 10, c.cy + 1, c.cx - 15, c.cy - 5, c.P.acc); g.tri(c.cx + 10, c.cy + 1, c.cx + 14, c.cy + 3, c.cx + 15, c.cy - 5, c.P.acc); } },
    { id: 'vampire', number: 18, name: 'Vampire Bat', rarity: 'rare',
      pal: pal('#3C3045', '#261D2E', '#584A63', '#140E18', '#C97A8A', '#F2E6E6', { wing: '#B23A3A', wingShade: '#7A2424', acc: '#B23A3A', accShade: '#7A2424', cheek: '#C97A8A' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'pointy', off: 6 }, wings: 'cape', face: { mouth: 'smile', fangs: true, eyes: 'glint' },
      front: function (c) { var g = c.g, t = c.cy - c.ry; g.tri(c.cx - 11, c.cy - 1, c.cx - 3, c.cy + 1, c.cx - 9, t + 5, c.P.acc); g.tri(c.cx + 11, c.cy - 1, c.cx + 3, c.cy + 1, c.cx + 9, t + 5, c.P.acc); } },
    { id: 'galaxy', number: 19, name: 'Galaxy Bat', rarity: 'legendary',
      pal: pal('#2E2860', '#1C1840', '#4A4290', '#0E0B24', '#8A7FD6', null, { acc: '#F2E3A6', accShade: '#F2E3A6', wing: '#241F52', wingShade: '#15123A', cheek: '#8A7FD6' }),
      body: { rx: 13, ry: 12 }, ears: { type: 'pointy', off: 7 }, wings: 'fold', face: { mouth: 'smile', eyes: 'glint' },
      motif: function (c) { var g = c.g, st = [[-7, 1], [3, -3], [8, 5], [-3, 7], [6, 9], [-9, 8]]; for (var i = 0; i < st.length; i++) { var x = c.cx + st[i][0], y = c.cy + st[i][1]; if (i % 2) sparkle(g, x, y, c.P.acc); else g.set(x, y, '#9FD3FF'); } sparkle(g, c.cx + 18, c.cy - 10, c.P.acc); g.set(c.cx - 18, c.cy - 6, '#9FD3FF'); } },
    { id: 'eclipse', number: 20, name: 'Eclipse Bat', rarity: 'legendary',
      pal: pal('#262028', '#151016', '#3C343F', '#070507', '#5C4A5E', null, { acc: '#E7C45B', accShade: '#B8942E', wing: '#1E181F', wingShade: '#0E0B0F', cheek: '#5C4A5E' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'pointy', off: 6 }, wings: 'fold', face: { mouth: 'small', eyes: 'glint' },
      back: function (c) { var g = c.g, t = c.cy - c.ry; g.ell(c.cx, t - 7, 11, 3, c.P.acc); g.ell(c.cx, t - 7, 9, 1.5, null); } },
    // Oddball Bats (#21–32, content wave 2)
    { id: 'bumblebee', number: 21, name: 'Bumblebee Bat', rarity: 'common', wave: 2,
      pal: pal('#CFA063', '#9E6F38', '#E8C28F', '#3F2A14', '#F2B8B0', '#F2D9B0', { cheek: '#F0A0A0' }),
      body: { rx: 9, ry: 8 }, ears: { type: 'round', off: 5 }, wings: 'fold', face: { nose: 'pig', mouth: 'small' } },
    { id: 'sticky', number: 22, name: 'Sticky Bat', rarity: 'common', wave: 2,
      pal: pal('#8E6C4C', '#664A30', '#B08A66', '#2E1E12', '#F2B8B0', '#D9BF9C', { acc: '#7FB069', accShade: '#52803F', cheek: '#E8A0A0' }),
      body: { rx: 11, ry: 11 }, ears: { type: 'small', off: 7 }, wings: 'fold', face: { mouth: 'smile' },
      front: function (c) { var g = c.g; g.ell(c.cx - 14, c.cy + 2, 3, 9, c.P.acc); g.ell(c.cx + 14, c.cy + 2, 3, 9, c.P.acc); g.ell(c.cx - 13, c.cy - 6, 2, 2, '#F2A7B8'); g.ell(c.cx + 13, c.cy - 6, 2, 2, '#F2A7B8'); } },
    { id: 'marshmallow', number: 23, name: 'Marshmallow Bat', rarity: 'uncommon', wave: 2,
      pal: pal('#F7F3EC', '#CFC6B8', '#FFFFFF', '#4A3A2E', '#F2C94C', null, { acc: '#F2C94C', accShade: '#C9A22E', cheek: '#F0C0B0', wing: '#E9E2D6' }),
      body: { rx: 12, ry: 12, shape: 'fluffy' }, ears: { type: 'round', off: 7 }, wings: 'fold', face: { nose: 'leaf', mouth: 'small', cheeks: true } },
    { id: 'honk', number: 24, name: 'Honk Bat', rarity: 'uncommon', wave: 2,
      pal: pal('#C9A079', '#9A7350', '#E2C4A2', '#3F2A1A', '#E8B0A0', '#E8D4B8', { cheek: '#E09090' }),
      body: { rx: 13, ry: 12 }, ears: { type: 'round', off: 8 }, wings: 'fold', face: { nose: 'snout', mouth: 'honk' } },
    { id: 'ember', number: 25, name: 'Ember Bat', rarity: 'uncommon', wave: 2,
      pal: pal('#F27C2A', '#C4541A', '#F8A66A', '#3A1A0E', '#F7C09A', '#F9D0A0', { wing: '#2B2B2B', wingShade: '#111111', cheek: '#F0A080' }),
      body: { rx: 11, ry: 11 }, ears: { type: 'pointy', off: 6 }, wings: 'fold', face: { mouth: 'smile', cheeks: true } },
    { id: 'nectar', number: 26, name: 'Nectar Bat', rarity: 'uncommon', wave: 2,
      pal: pal('#B98EBD', '#8C6392', '#D6B5DA', '#3E2A44', '#F2B8CC', '#E9D6EC', { acc: '#F2C94C', cheek: '#E89AB0' }),
      body: { rx: 11, ry: 11 }, ears: { type: 'long', off: 5 }, wings: 'fold', face: { eyes: 'half', mouth: 'small', tongue: true },
      motif: function (c) { var g = c.g; g.ell(c.cx + 15, c.cy + 12, 3, 2, '#F28AB0'); g.set(c.cx + 15, c.cy + 12, c.P.acc); } },
    { id: 'tube-nose', number: 27, name: 'Tube-Nose Bat', rarity: 'uncommon', wave: 2,
      pal: pal('#8E7D58', '#67593B', '#B0A078', '#2E2816', '#E8C9A0', '#D9C9A0', { wing: '#7A6A48', cheek: '#D9A080' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'round', off: 7 }, wings: 'fold', face: { nose: 'tube', eyes: 'half', mouth: 'small' },
      motif: function (c) { var g = c.g; g.set(c.cx - 15, c.cy + 2, '#F2C94C'); g.set(c.cx + 15, c.cy + 4, '#F2C94C'); g.set(c.cx - 16, c.cy + 7, '#F2C94C'); g.set(c.cx + 16, c.cy + 8, '#F2C94C'); } },
    { id: 'polka', number: 28, name: 'Polka Bat', rarity: 'rare', wave: 2,
      pal: pal('#2E2B36', '#1A1820', '#48444F', '#0A090D', '#F2A7C9', null, { wing: '#24222B', wingShade: '#141317', cheek: '#C97A95' }),
      body: { rx: 11, ry: 11 }, ears: { type: 'giant', off: 7 }, wings: 'fold', face: { mouth: 'smile', eyes: 'glint' },
      motif: function (c) { var g = c.g; g.ell(c.cx - 5, c.cy + 2, 2, 2, '#F4F0E2'); g.ell(c.cx + 5, c.cy + 2, 2, 2, '#F4F0E2'); g.ell(c.cx, c.cy + 8, 2, 2, '#F4F0E2'); } },
    { id: 'wrinkle', number: 29, name: 'Wrinkle Bat', rarity: 'rare', wave: 2,
      pal: pal('#8E7C6E', '#66574B', '#B09E90', '#2E2620', '#D9B8A8', null, { cheek: '#C99080' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'pointy', off: 6 }, wings: 'fold', face: { eyes: 'dot', mouth: 'small', chinMask: '#EDE5DA' },
      motif: function (c) { var g = c.g; g.rect(c.cx - 7, c.cy - 7, 4, 1, c.P.shade); g.rect(c.cx + 3, c.cy - 7, 4, 1, c.P.shade); g.rect(c.cx - 2, c.cy - 9, 4, 1, c.P.shade); } },
    { id: 'walker', number: 30, name: 'Walker Bat', rarity: 'rare', wave: 2,
      pal: pal('#8F6B4C', '#664A30', '#B08C6A', '#2E1E12', '#E8B8A0', '#D9BF9C', { wing: '#6E5238', wingShade: '#4A3522', cheek: '#E09A8A' }),
      body: { rx: 11, ry: 10 }, ears: { type: 'pointy', off: 6 }, wings: 'fold', face: { mouth: 'w', eyes: 'open' },
      motif: function (c) { var g = c.g, y = c.cy + c.ry; g.rect(c.cx - 6, y - 1, 3, 4, c.P.shade); g.rect(c.cx + 4, y - 1, 3, 4, c.P.shade); g.rect(c.cx - 7, y + 3, 4, 1, c.P.shade); g.rect(c.cx + 4, y + 3, 4, 1, c.P.shade); } },
    { id: 'fox', number: 31, name: 'Fox Bat', rarity: 'rare', wave: 2,
      pal: pal('#D9853C', '#A85E24', '#F0A86A', '#3E2210', '#F2C0A0', '#F7E2C8', { wing: '#4A2E22', wingShade: '#2E1C14', acc: '#F2C14E', accShade: '#C9962E', cheek: '#E89A8A' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'pointy', off: 7 }, wings: 'cape', face: { mouth: 'small', eyes: 'glint' },
      motif: function (c) { var g = c.g, t = c.cy - c.ry; g.ell(c.cx, t + 1, 8, 4, c.P.acc); g.tri(c.cx - 4, t + 1, c.cx + 4, t + 1, c.cx, t - 6, c.P.acc); } },
    { id: 'ghost', number: 32, name: 'Ghost Bat', rarity: 'legendary', wave: 2,
      pal: pal('#E9EBF4', '#BFC6DD', '#FFFFFF', '#5A6080', '#DDE0F2', null, { wing: '#D4D9EC', wingShade: '#A9B1CC', cheek: '#D6C9E6', eye: '#4C5278' }),
      body: { rx: 12, ry: 12 }, ears: { type: 'giant', off: 6 }, wings: 'fold', face: { mouth: 'smile', eyes: 'open' },
      shinyShift: 190,
      motif: function (c) { var g = c.g; sparkle(g, c.cx - 17, c.cy - 4, '#EFE2B6'); sparkle(g, c.cx + 17, c.cy + 2, '#EFE2B6'); } }
  ];
  var byId = {};
  for (var i = 0; i < SPECIES.length; i++) byId[SPECIES[i].id] = SPECIES[i];

  // ---------------------------------------------------------------- eggs
  var EGGS = {
    starter: { base: '#F2E6C8', shade: '#D9C39A', light: '#FBF5E6', line: '#5A4A30', dots: '#E0CFA6' },
    tiny:    { base: '#CDB9E8', shade: '#A48DCC', light: '#E6DBF6', line: '#3E3058', dots: '#E9DEF7' },
    forest:  { base: '#9BC27E', shade: '#6F9A52', light: '#C3DEAE', line: '#2E4A22', dots: '#5F8A4A' },
    moon:    { base: '#4A5AA6', shade: '#303E7F', light: '#7484C9', line: '#161C44', dots: '#F2E3A6' },
    crystal: { base: '#A6DCE6', shade: '#6FB4C4', light: '#DDF5F8', line: '#245060', dots: '#FFFFFF' }
  };
  function drawEgg(type, state, frame) {
    var g = new Grid(), P = EGGS[type] || EGGS.tiny; g.lineColor = P.line;
    var cx = 32, cy = 38, rx = 11, ry = 14, shear = 0;
    if (state === 'shaking') shear = (frame % 2 ? 1 : -1) * 0.1;
    if (state === 'rattling') shear = (frame % 2 ? 1 : -1) * 0.18;
    function sx(y) { return cx + Math.round((y - cy) * shear); }
    for (var y = cy - ry; y <= cy + ry; y++) {
      var t = (y - cy) / ry, w = rx * Math.sqrt(Math.max(0, 1 - t * t)) * (t < 0 ? 0.78 + 0.22 * (1 + t) : 1);
      g.rect(Math.round(sx(y) - w), y, Math.round(w * 2) + 1, 1, P.base);
    }
    g.ell(sx(cy - 7) - 4, cy - 7, 2, 3, P.light);
    if (type === 'starter' || type === 'tiny') { var d = [[-5, -3], [4, -6], [6, 3], [-3, 6], [1, 10], [-7, 2]]; for (var i = 0; i < d.length; i++) g.set(sx(cy + d[i][1]) + d[i][0], cy + d[i][1], P.dots); }
    if (type === 'forest') { g.line(sx(cy - 6) + 2, cy - 6, sx(cy + 8) - 3, cy + 8, P.dots); g.line(sx(cy - 1) + 1, cy - 1, sx(cy + 1) + 6, cy + 1, P.dots); g.line(sx(cy + 3) - 1, cy + 3, sx(cy + 5) - 7, cy + 5, P.dots); }
    if (type === 'moon') { g.ell(sx(cy - 2) + 2, cy - 2, 4, 4, P.dots); g.ell(sx(cy - 3) + 4, cy - 3, 3.5, 3.5, P.base); g.set(sx(cy + 6) - 5, cy + 6, P.dots); g.set(sx(cy + 8) + 4, cy + 8, P.dots); g.set(sx(cy - 9) - 2, cy - 9, P.dots); }
    if (type === 'crystal') { g.line(sx(cy - 10), cy - 10, sx(cy + 2) - 7, cy + 2, P.light); g.line(sx(cy - 10), cy - 10, sx(cy + 2) + 7, cy + 2, P.light); g.line(sx(cy + 2) - 7, cy + 2, sx(cy + 12), cy + 12, P.light); g.line(sx(cy + 2) + 7, cy + 2, sx(cy + 12), cy + 12, P.light); sparkle(g, sx(cy - 4) + 5, cy - 4, P.dots); }
    g.outline(P.line);
    g.rim([[P.base, P.shade]]);
    var cracks = state === 'cracked' ? 1 : state === 'rattling' ? 2 : state === 'ready' ? 3 : 0;
    if (cracks >= 1) { var ax = sx(cy - 9) + 5; g.line(ax, cy - 9, ax - 3, cy - 5, P.line); g.line(ax - 3, cy - 5, ax + 1, cy - 2, P.line); g.line(ax + 1, cy - 2, ax - 2, cy + 2, P.line); }
    if (cracks >= 2) { var bx = sx(cy + 1) - 7; g.line(bx, cy + 1, bx + 3, cy + 4, P.line); g.line(bx + 3, cy + 4, bx + 1, cy + 8, P.line); }
    if (cracks >= 3) { var glow = '#EFE2B6'; g.line(sx(cy - 2) - 3, cy - 2, sx(cy + 1) + 2, cy + 1, P.line); g.line(sx(cy + 1) + 2, cy + 1, sx(cy + 4) - 1, cy + 4, P.line); g.line(sx(cy + 4) - 1, cy + 4, sx(cy + 7) + 4, cy + 7, P.line);
      // light leaks: a bright pixel beside each crack
      for (var yy = cy - 9; yy <= cy + 8; yy++) for (var xx = cx - 11; xx <= cx + 11; xx++) if (g.get(xx, yy) === P.line && g.get(xx + 1, yy) === P.base) g.set(xx + 1, yy, glow);
      sparkle(g, cx - 18, cy - 8, glow); sparkle(g, cx + 18, cy - 12, glow); sparkle(g, cx + 16, cy + 9, glow); g.set(cx - 17, cy + 6, glow); }
    if (state === 'rattling') { var m = frame % 2 ? 1 : -1; g.rect(cx + m * 16, cy - 2, 1, 3, P.shade); g.rect(cx + m * 18, cy + 3, 1, 3, P.shade); }
    return g;
  }

  // ---------------------------------------------------------------- api
  var api = {
    W: W, H: H, Grid: Grid, SPECIES: SPECIES, species: function (id) { return byId[id]; },
    POSES: POSES, PLAN: PLAN, TIMING: TIMING, EGGS: EGGS,
    ACTIONS: ['idle', 'sleep', 'fly', 'pet', 'eat'],
    drawBat: drawBat, drawEgg: drawEgg, moodPose: moodPose, shinyPalette: shinyPalette,
    /** Convenience for artboards: SVG paths for a species in a mood (or an explicit pose). */
    bat: function (id, mood, shiny, pose) { var s = byId[id]; if (!s) return []; return drawBat(s, pose || moodPose(mood || 'awake'), !!shiny).paths(); },
    /** Every frame of an action: { index, seconds, grid, paths }. */
    frameGrids: function (id, action, shiny) {
      var s = byId[id], out = []; if (!s) return out;
      var poses = POSES[action] || POSES.idle, plan = PLAN[action] || PLAN.idle;
      for (var f = 0; f < poses.length; f++) out.push({ index: f, seconds: plan.seconds[f], grid: drawBat(s, poses[f], !!shiny) });
      return out;
    },
    frames: function (id, action, shiny) {
      return api.frameGrids(id, action, shiny).map(function (fr) { return { index: fr.index, seconds: fr.seconds, paths: fr.grid.paths() }; });
    },
    egg: function (type, state, frame) { return drawEgg(type, state, frame || 0).paths(); }
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.BatwalkPixel = api;
})(typeof window !== 'undefined' ? window : this);
