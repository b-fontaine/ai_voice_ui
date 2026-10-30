/**
 * Fond animé « HUD Jarvis » : un canvas plein écran, derrière reveal.js.
 *
 * Couches (de l'arrière vers l'avant) :
 *   1. maillage hexagonal (pré-rendu une fois par redimensionnement) ;
 *   2. anneaux concentriques avec graduations et arcs, qui tournent à des
 *      vitesses différentes, plus un petit « réacteur » secondaire en coin ;
 *   3. balayage radar (secteur dégradé qui tourne) ;
 *   4. particules / flux de données qui partent du centre ;
 *   5. voile radial qui assombrit le centre pour préserver la lisibilité.
 * Les scanlines sont en CSS (body::after, voir theme/jarvis.css).
 *
 * Performance : requestAnimationFrame, devicePixelRatio plafonné à 1,5,
 * pause quand l'onglet est caché, une seule image fixe si
 * prefers-reduced-motion: reduce.
 *
 * Intensité : chaque <section> peut porter data-hud="low" | "off" | "high"
 * (défaut "normal"). deck.js appelle setIntensity() à chaque changement de
 * slide et pulse() pour une onde discrète.
 */

const COLORS = {
  cyan: [0, 229, 255],
  cyanSoft: [79, 195, 247],
  amber: [255, 179, 0],
  bg: [3, 8, 16],
};

const INTENSITY = { off: 0, low: 0.35, normal: 1, high: 1.35 };
const MAX_DPR = 1.5;

const rgba = ([r, g, b], a) => `rgba(${r},${g},${b},${a})`;
const TAU = Math.PI * 2;

export function startHud(canvas) {
  const noop = { setIntensity() {}, pulse() {}, stop() {} };
  if (!canvas || !canvas.getContext) return noop;
  const ctx = canvas.getContext('2d', { alpha: false });
  if (!ctx) return noop;

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  let w = 0;
  let h = 0;
  let dpr = 1;
  let hexLayer = null;
  let rafId = 0;
  let last = 0;
  let t = 0;
  let intensity = 1;
  let targetIntensity = 1;
  let pulse = 0;
  let particles = [];

  // ---- Anneaux : rayon relatif, vitesse (rad/s), style -------------------
  const rings = [
    { r: 0.18, speed: 0.12, kind: 'ticks', ticks: 120, len: 0.012, alpha: 0.5 },
    { r: 0.215, speed: -0.25, kind: 'arcs', arcs: [[0, 0.9], [1.2, 2.1], [3.3, 4.6], [5.0, 5.7]], width: 3, alpha: 0.55 },
    { r: 0.26, speed: 0.05, kind: 'dashes', dash: [2, 10], width: 1.5, alpha: 0.45 },
    { r: 0.31, speed: -0.08, kind: 'ticks', ticks: 72, len: 0.02, major: 6, alpha: 0.45 },
    { r: 0.36, speed: 0.16, kind: 'arcs', arcs: [[0.3, 1.6], [2.4, 2.9], [4.1, 5.9]], width: 1.5, alpha: 0.4, color: 'amber' },
    { r: 0.43, speed: -0.035, kind: 'dashes', dash: [30, 14, 4, 14], width: 1, alpha: 0.35 },
    { r: 0.52, speed: 0.02, kind: 'ticks', ticks: 180, len: 0.008, major: 15, alpha: 0.3 },
  ];

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, MAX_DPR);
    w = window.innerWidth;
    h = window.innerHeight;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    hexLayer = buildHexLayer();
    particles = Array.from({ length: Math.round(Math.min(90, (w * h) / 22000)) }, () => spawn(true));
    if (reducedMotion.matches) drawFrame(0);
  }

  // ---- Maillage hexagonal pré-rendu ----------------------------------------
  function buildHexLayer() {
    const off = document.createElement('canvas');
    off.width = canvas.width;
    off.height = canvas.height;
    const c = off.getContext('2d');
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    const size = 34;
    const hw = Math.sqrt(3) * size;
    const vh = 1.5 * size;
    c.lineWidth = 1;
    const cx = w / 2;
    const cy = h / 2;
    const maxD = Math.hypot(cx, cy);
    for (let row = -1, y = 0; y < h + size; row++, y = row * vh) {
      for (let col = -1; col * hw < w + hw; col++) {
        const x = col * hw + (row % 2 ? hw / 2 : 0);
        // Plus visible vers les bords, presque invisible au centre.
        const d = Math.hypot(x - cx, y - cy) / maxD;
        const a = 0.015 + 0.075 * d * d;
        c.strokeStyle = rgba(COLORS.cyanSoft, a);
        c.beginPath();
        for (let i = 0; i < 6; i++) {
          const ang = Math.PI / 6 + (i * Math.PI) / 3;
          const px = x + size * Math.cos(ang);
          const py = y + size * Math.sin(ang);
          if (i === 0) c.moveTo(px, py);
          else c.lineTo(px, py);
        }
        c.closePath();
        c.stroke();
      }
    }
    return off;
  }

  // ---- Particules : flux de données radiaux ---------------------------------
  function spawn(initial = false) {
    const ang = Math.random() * TAU;
    const min = Math.min(w, h);
    return {
      ang,
      r: (initial ? 0.12 + Math.random() * 0.5 : 0.12 + Math.random() * 0.04) * min,
      v: (18 + Math.random() * 46) * (min / 900),
      size: Math.random() < 0.15 ? 2.2 : 1.2,
      trail: 8 + Math.random() * 22,
      amber: Math.random() < 0.12,
    };
  }

  // ---- Dessin ---------------------------------------------------------------
  function drawRing(cx, cy, base, ring, rot, k) {
    const r = ring.r * base * (1 + pulse * 0.025);
    const col = ring.color === 'amber' ? COLORS.amber : COLORS.cyan;
    const a = ring.alpha * k;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(rot);
    ctx.strokeStyle = rgba(col, a);
    if (ring.kind === 'ticks') {
      const len = ring.len * base;
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let i = 0; i < ring.ticks; i++) {
        const ang = (i / ring.ticks) * TAU;
        const major = ring.major && i % ring.major === 0;
        const l = major ? len * 2.2 : len;
        ctx.moveTo(Math.cos(ang) * r, Math.sin(ang) * r);
        ctx.lineTo(Math.cos(ang) * (r - l), Math.sin(ang) * (r - l));
      }
      ctx.stroke();
      ctx.beginPath();
      ctx.lineWidth = 1;
      ctx.strokeStyle = rgba(col, a * 0.6);
      ctx.arc(0, 0, r, 0, TAU);
      ctx.stroke();
    } else if (ring.kind === 'arcs') {
      ctx.lineWidth = ring.width;
      ctx.lineCap = 'round';
      for (const [s, e] of ring.arcs) {
        ctx.beginPath();
        ctx.arc(0, 0, r, s, e);
        ctx.stroke();
      }
    } else {
      ctx.lineWidth = ring.width;
      ctx.setLineDash(ring.dash);
      ctx.beginPath();
      ctx.arc(0, 0, r, 0, TAU);
      ctx.stroke();
      ctx.setLineDash([]);
    }
    ctx.restore();
  }

  function drawRadar(cx, cy, base, rot, k) {
    const r = 0.52 * base;
    const sweep = 0.9;
    if (typeof ctx.createConicGradient === 'function') {
      const g = ctx.createConicGradient(rot - sweep, cx, cy);
      const span = sweep / TAU;
      g.addColorStop(0, rgba(COLORS.cyan, 0));
      g.addColorStop(span, rgba(COLORS.cyan, 0.09 * k));
      g.addColorStop(span + 0.0001, rgba(COLORS.cyan, 0));
      g.addColorStop(1, rgba(COLORS.cyan, 0));
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, r, rot - sweep, rot);
      ctx.closePath();
      ctx.fill();
    }
    // Ligne de tête du balayage.
    ctx.strokeStyle = rgba(COLORS.cyan, 0.28 * k);
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(rot) * r, cy + Math.sin(rot) * r);
    ctx.stroke();
  }

  function drawParticles(cx, cy, base, dt, k) {
    const maxR = 0.62 * base;
    ctx.lineCap = 'round';
    for (let i = 0; i < particles.length; i++) {
      const p = particles[i];
      p.r += p.v * dt * (1 + pulse * 2);
      if (p.r > maxR) {
        particles[i] = spawn();
        continue;
      }
      const fade = Math.sin(Math.min(1, p.r / maxR) * Math.PI);
      const a = 0.55 * fade * k;
      const cos = Math.cos(p.ang);
      const sin = Math.sin(p.ang);
      ctx.strokeStyle = rgba(p.amber ? COLORS.amber : COLORS.cyan, a);
      ctx.lineWidth = p.size;
      ctx.beginPath();
      ctx.moveTo(cx + cos * p.r, cy + sin * p.r);
      ctx.lineTo(cx + cos * (p.r - p.trail), cy + sin * (p.r - p.trail));
      ctx.stroke();
    }
  }

  function drawFrame(dt) {
    const k = intensity;
    ctx.fillStyle = rgba(COLORS.bg, 1);
    ctx.fillRect(0, 0, w, h);

    // Lueur de fond.
    const cx = w / 2;
    const cy = h / 2;
    const base = Math.min(w, h) * 1.25;
    const glow = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(w, h) * 0.75);
    glow.addColorStop(0, rgba([6, 30, 52], 0.9));
    glow.addColorStop(1, rgba(COLORS.bg, 0));
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, w, h);

    if (k <= 0.001) return;

    ctx.globalAlpha = Math.min(1, k);
    if (hexLayer) ctx.drawImage(hexLayer, 0, 0, w, h);
    ctx.globalAlpha = 1;

    for (const ring of rings) drawRing(cx, cy, base, ring, t * ring.speed, k * (1 + pulse * 0.6));
    drawRadar(cx, cy, base, t * 0.45, k);
    drawParticles(cx, cy, base, dt, k);

    // Petit réacteur secondaire en bas à droite.
    const sx = w - Math.min(w, h) * 0.13;
    const sy = h - Math.min(w, h) * 0.15;
    const sb = Math.min(w, h) * 0.35;
    drawRing(sx, sy, sb, rings[0], -t * 0.4, k * 0.9);
    drawRing(sx, sy, sb, rings[1], t * 0.6, k * 0.9);
    drawRing(sx, sy, sb, rings[4], -t * 0.3, k * 0.9);

    // Onde de pulse au changement de slide.
    if (pulse > 0.01) {
      ctx.strokeStyle = rgba(COLORS.cyan, 0.35 * pulse * k);
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(cx, cy, base * (0.62 - 0.45 * pulse), 0, TAU);
      ctx.stroke();
    }

    // Voile central : le texte des slides reste lisible.
    const veil = ctx.createRadialGradient(cx, cy, 0, cx, cy, base * 0.42);
    veil.addColorStop(0, rgba(COLORS.bg, 0.78));
    veil.addColorStop(0.6, rgba(COLORS.bg, 0.55));
    veil.addColorStop(1, rgba(COLORS.bg, 0));
    ctx.fillStyle = veil;
    ctx.fillRect(0, 0, w, h);
  }

  function loop(now) {
    const dt = last ? Math.min(0.05, (now - last) / 1000) : 0;
    last = now;
    t += dt;
    intensity += (targetIntensity - intensity) * Math.min(1, dt * 3);
    pulse = Math.max(0, pulse - dt * 1.2);
    drawFrame(dt);
    rafId = requestAnimationFrame(loop);
  }

  function start() {
    if (rafId || reducedMotion.matches || document.hidden) return;
    last = 0;
    rafId = requestAnimationFrame(loop);
  }

  function stop() {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = 0;
  }

  document.addEventListener('visibilitychange', () => (document.hidden ? stop() : start()));
  reducedMotion.addEventListener?.('change', () => {
    if (reducedMotion.matches) {
      stop();
      drawFrame(0);
    } else start();
  });
  window.addEventListener('resize', resize);

  t = 12; // décale la phase de départ pour une première image déjà « vivante »
  resize();
  start();

  return {
    /** 'off' | 'low' | 'normal' | 'high' */
    setIntensity(level) {
      targetIntensity = INTENSITY[level] ?? INTENSITY.normal;
      if (reducedMotion.matches) {
        intensity = targetIntensity;
        drawFrame(0);
      }
    },
    /** Onde discrète, par exemple au changement de slide. */
    pulse(strength = 1) {
      if (!reducedMotion.matches) pulse = Math.max(pulse, strength);
    },
    stop,
  };
}
