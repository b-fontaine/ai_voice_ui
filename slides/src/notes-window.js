// Fenêtre de notes orateur (touche N) : une page à part, à placer sur le
// second écran, qui suit la présentation. Les deux fenêtres se parlent par un
// BroadcastChannel (même origine, aucun serveur) :
//   deck  → notes : { type: 'slide', … } à chaque changement de slide
//   notes → deck  : { type: 'hello' } à l'ouverture, { type: 'nav', dir } pour
//                   piloter la présentation depuis la fenêtre de notes
//                   (dir : 'right', 'down', 'left' ou 'up')

import { slideLabel } from './slide-label.js';

export const NOTES_CHANNEL = 'genesis-canvas-notes';

const titleOf = (slide) =>
  slide?.querySelector('h1, h2')?.textContent.replace(/\s+/g, ' ').trim() ?? '';

export function setupNotesWindow(deck, { advance, back, down, up }) {
  // Les aperçus de la vue orateur reveal (touche S) et l'export PDF chargent
  // aussi la présentation : ils ne doivent ni émettre ni piloter.
  const enabled =
    'BroadcastChannel' in window && !/receiver|print-pdf/i.test(window.location.search);
  if (!enabled) return { open: () => {} };

  const channel = new BroadcastChannel(NOTES_CHANNEL);
  const moves = { right: advance, down, left: back, up };

  const publish = () => {
    const slide = deck.getCurrentSlide();
    if (!slide) return;
    const { h, v } = deck.getIndices(slide);
    const stack = deck.getHorizontalSlides()[h];
    // → : slide principale suivante ; ↓ : slide suivante du débranchement.
    const right = deck.getSlide(h + 1);
    const below = stack?.classList.contains('stack') ? deck.getSlide(h, v + 1) : undefined;
    channel.postMessage({
      type: 'slide',
      label: slideLabel(deck, slide),
      total: deck.getHorizontalSlides().length,
      eyebrow: slide.querySelector('.eyebrow, .chapter-num')?.textContent.trim() ?? '',
      title: titleOf(slide),
      notes: deck.getSlideNotes(slide) ?? '',
      next: titleOf(right),
      down: below ? `${slideLabel(deck, below)} · ${titleOf(below)}` : '',
    });
  };

  channel.onmessage = ({ data }) => {
    if (data?.type === 'hello') publish();
    else if (data?.type === 'nav') moves[data.dir]?.();
  };

  deck.on('ready', publish);
  deck.on('slidechanged', publish);

  const open = () => {
    const win = window.open(
      new URL('notes.html', window.location.href).href,
      'genesis-canvas-notes',
      'popup,width=1200,height=820',
    );
    win?.focus();
    publish();
  };

  return { open };
}
