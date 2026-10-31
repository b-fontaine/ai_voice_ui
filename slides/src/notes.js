// Fenêtre de notes orateur : reçoit la slide courante de la présentation
// (voir notes-window.js) et peut la piloter au clavier.
import '@fontsource/orbitron/latin-700.css';
import '@fontsource/rajdhani/latin-500.css';
import '@fontsource/rajdhani/latin-700.css';
import '@fontsource/jetbrains-mono/latin-400.css';

import './theme/jarvis.css';
import './theme/notes.css';

import { NOTES_CHANNEL } from './notes-window.js';

const $ = (id) => document.getElementById(id);
const channel = new BroadcastChannel(NOTES_CHANNEL);

// Une ligne de notes = un paragraphe ; les ids de sources [xxx] sont atténués.
const renderNotes = (html) =>
  html
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => `<p>${line.replace(/\[([^\]\s]+)\]/g, '<span class="np-ref">[$1]</span>')}</p>`)
    .join('') || '<p class="np-hint">Pas de notes pour cette slide.</p>';

channel.onmessage = ({ data }) => {
  if (data?.type !== 'slide') return;
  $('np-counter').textContent = `${data.index + 1} / ${data.total}`;
  $('np-eyebrow').textContent = data.eyebrow;
  $('np-title').textContent = data.title || 'Slide sans titre';
  $('np-notes').innerHTML = renderNotes(data.notes);
  $('np-notes').scrollTop = 0;
  $('np-next').textContent = data.next || 'Fin de la présentation';
  document.title = `${data.index + 1}/${data.total} · ${data.title} — Notes`;
};
channel.postMessage({ type: 'hello' });

// Chrono depuis l'ouverture de la fenêtre, et heure courante.
let start = performance.now();
const pad = (n) => String(n).padStart(2, '0');
const tick = () => {
  const s = Math.floor((performance.now() - start) / 1000);
  $('np-timer').textContent = `${pad(Math.floor(s / 60))}:${pad(s % 60)}`;
  const now = new Date();
  $('np-time').textContent = `${pad(now.getHours())}:${pad(now.getMinutes())}`;
};
const resetTimer = () => {
  start = performance.now();
  tick();
};
setInterval(tick, 1000);
tick();
$('np-timer').addEventListener('click', resetTimer);

// Taille du texte, mémorisée pour ce navigateur.
const SIZE_KEY = 'genesis-notes-size';
let size = 30;
try {
  size = Number(localStorage.getItem(SIZE_KEY)) || size;
} catch {
  /* stockage indisponible : taille par défaut */
}
const applySize = () => {
  document.documentElement.style.setProperty('--np-size', `${size}px`);
  try {
    localStorage.setItem(SIZE_KEY, String(size));
  } catch {
    /* stockage indisponible : la taille ne sera pas mémorisée */
  }
};
applySize();

const nav = (dir) => channel.postMessage({ type: 'nav', dir });

document.addEventListener('keydown', (e) => {
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  switch (e.key) {
    case 'ArrowRight':
    case 'ArrowDown':
    case 'PageDown':
    case ' ':
      nav('next');
      break;
    case 'ArrowLeft':
    case 'ArrowUp':
    case 'PageUp':
      nav('prev');
      break;
    case '+':
    case '=':
      size = Math.min(size + 2, 64);
      applySize();
      break;
    case '-':
      size = Math.max(size - 2, 16);
      applySize();
      break;
    case 't':
    case 'T':
      resetTimer();
      break;
    default:
      return;
  }
  e.preventDefault();
});
