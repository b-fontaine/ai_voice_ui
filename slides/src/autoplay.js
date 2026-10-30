// Affichage progressif automatique : en arrivant sur une slide, ses fragments
// apparaissent seuls, l'un après l'autre. Un appui sur « suivant » pendant
// l'enchaînement affiche tout d'un coup ; l'appui suivant change de slide.
// « Précédent » revient directement à la slide d'avant, entièrement affichée.
//
// Réglages par slide :
//   data-autoplay="off"        pas d'enchaînement (fragments au clic)
//   data-autoplay-step="1200"  délai entre deux fragments, en ms

const FIRST_DELAY_MS = 450; // laisse finir la transition de slide
const STEP_MS = 650;
const CODE_STEP_MS = 2200; // étapes de surlignage de code : le temps de lire

const NEXT_KEYS = [39, 40, 32, 34, 76, 74]; // → ↓ espace PgDn L J (N ouvre les notes)
const PREV_KEYS = [37, 38, 33, 80, 72, 75]; // ← ↑ PgUp P H K

export function setupAutoplay(deck) {
  // Les aperçus de la vue orateur reçoivent l'état de la fenêtre principale :
  // ils ne doivent pas jouer les fragments eux-mêmes.
  const enabled = !/receiver|print-pdf/i.test(window.location.search);
  let timer = null;

  const stop = () => {
    clearTimeout(timer);
    timer = null;
  };

  const hasHiddenFragments = (slide) =>
    !!slide?.querySelector('.fragment:not(.visible)');

  const stepDelay = (slide) => {
    const custom = Number(slide.dataset.autoplayStep);
    if (custom > 0) return custom;
    const next = slide.querySelector('.fragment:not(.visible)');
    return next?.closest('pre') ? CODE_STEP_MS : STEP_MS;
  };

  const schedule = (delay) => {
    stop();
    const slide = deck.getCurrentSlide();
    if (!enabled || !slide || slide.dataset.autoplay === 'off') return;
    if (deck.isOverview() || !hasHiddenFragments(slide)) return;
    timer = setTimeout(() => {
      if (deck.getCurrentSlide() !== slide) return;
      deck.nextFragment();
      schedule(stepDelay(slide));
    }, delay);
  };

  const showAll = () => {
    stop();
    while (deck.nextFragment()) {
      /* affiche le fragment suivant */
    }
  };

  const advance = () => {
    if (hasHiddenFragments(deck.getCurrentSlide())) showAll();
    else deck.next({ skipFragments: true });
  };

  const back = () => {
    stop();
    deck.prev({ skipFragments: true });
  };

  const keyboard = {};
  NEXT_KEYS.forEach((k) => (keyboard[k] = advance));
  PREV_KEYS.forEach((k) => (keyboard[k] = back));

  // Les flèches à l'écran suivent la même logique que le clavier.
  document.addEventListener(
    'click',
    (e) => {
      const next = e.target.closest?.('.reveal .controls .navigate-right');
      const prev = e.target.closest?.('.reveal .controls .navigate-left');
      if (!next && !prev) return;
      e.preventDefault();
      e.stopPropagation();
      next ? advance() : back();
    },
    true,
  );

  deck.on('ready', () => schedule(FIRST_DELAY_MS));
  deck.on('slidechanged', () => schedule(FIRST_DELAY_MS));
  deck.on('overviewshown', stop);
  deck.on('overviewhidden', () => schedule(FIRST_DELAY_MS));

  return { keyboard, advance, back };
}
