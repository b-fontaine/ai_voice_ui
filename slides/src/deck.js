import Reveal from 'reveal.js';
import Notes from 'reveal.js/plugin/notes/notes.esm.js';
import Highlight from 'reveal.js/plugin/highlight/highlight.esm.js';
import Zoom from 'reveal.js/plugin/zoom/zoom.esm.js';

import 'reveal.js/dist/reset.css';
import 'reveal.js/dist/reveal.css';

// Polices auto-hébergées (aucun appel réseau : la présentation marche hors ligne).
import '@fontsource/orbitron/latin-500.css';
import '@fontsource/orbitron/latin-700.css';
import '@fontsource/orbitron/latin-900.css';
import '@fontsource/rajdhani/latin-500.css';
import '@fontsource/rajdhani/latin-600.css';
import '@fontsource/rajdhani/latin-700.css';
import '@fontsource/jetbrains-mono/latin-400.css';
import '@fontsource/jetbrains-mono/latin-700.css';

import './theme/jarvis.css';
import './theme/components.css';
import './theme/code.css';

import { startHud } from './background/hud.js';
import { setupAutoplay } from './autoplay.js';

/** Taille logique des slides (16:9). Reveal met à l'échelle pour l'écran. */
export const SLIDE_WIDTH = 1600;
export const SLIDE_HEIGHT = 900;

export function startDeck(options = {}) {
  const deck = new Reveal({
    width: SLIDE_WIDTH,
    height: SLIDE_HEIGHT,
    margin: 0.06,
    minScale: 0.2,
    maxScale: 2.0,
    hash: true,
    slideNumber: 'c/t',
    showSlideNumber: 'all',
    controls: true,
    controlsTutorial: false,
    progress: true,
    center: true,
    navigationMode: 'linear',
    transition: 'fade',
    transitionSpeed: 'default',
    backgroundTransition: 'fade',
    plugins: [Notes, Highlight, Zoom],
    ...options,
  });

  const hud = startHud(document.getElementById('hud-bg'));

  const syncHud = (slide) => {
    if (!slide) return;
    hud.setIntensity(slide.dataset.hud ?? 'normal');
    document.body.dataset.hud = slide.dataset.hud ?? 'normal';
  };

  deck.on('ready', (e) => syncHud(e.currentSlide));
  deck.on('slidechanged', (e) => {
    syncHud(e.currentSlide);
    hud.pulse();
  });
  deck.on('fragmentshown', () => hud.pulse(0.35));

  const autoplay = setupAutoplay(deck);
  deck.initialize({ keyboard: autoplay.keyboard });
  return deck;
}
