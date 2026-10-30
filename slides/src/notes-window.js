// Fenêtre de notes orateur (touche N) : une page à part, à placer sur le
// second écran, qui suit la présentation. Les deux fenêtres se parlent par un
// BroadcastChannel (même origine, aucun serveur) :
//   deck  → notes : { type: 'slide', … } à chaque changement de slide
//   notes → deck  : { type: 'hello' } à l'ouverture, { type: 'nav', dir } pour
//                   piloter la présentation depuis la fenêtre de notes

export const NOTES_CHANNEL = 'genesis-canvas-notes';

const titleOf = (slide) =>
  slide?.querySelector('h1, h2')?.textContent.replace(/\s+/g, ' ').trim() ?? '';

export function setupNotesWindow(deck, { advance, back }) {
  // Les aperçus de la vue orateur reveal (touche S) et l'export PDF chargent
  // aussi la présentation : ils ne doivent ni émettre ni piloter.
  const enabled =
    'BroadcastChannel' in window && !/receiver|print-pdf/i.test(window.location.search);
  if (!enabled) return { open: () => {} };

  const channel = new BroadcastChannel(NOTES_CHANNEL);

  const publish = () => {
    const slides = deck.getSlides();
    const slide = deck.getCurrentSlide();
    const index = slides.indexOf(slide);
    if (index < 0) return;
    channel.postMessage({
      type: 'slide',
      index,
      total: slides.length,
      eyebrow: slide.querySelector('.eyebrow, .chapter-num')?.textContent.trim() ?? '',
      title: titleOf(slide),
      notes: deck.getSlideNotes(slide) ?? '',
      next: titleOf(slides[index + 1]),
    });
  };

  channel.onmessage = ({ data }) => {
    if (data?.type === 'hello') publish();
    else if (data?.type === 'nav') (data.dir === 'prev' ? back : advance)();
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
