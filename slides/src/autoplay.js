// Affichage progressif automatique : en arrivant sur une slide, ses fragments
// apparaissent seuls, l'un après l'autre. Un appui sur « suivant » pendant
// l'enchaînement affiche tout d'un coup ; l'appui suivant change de slide.
// « Précédent » revient directement à la slide d'avant, entièrement affichée.
//
// Débranchements (piles verticales) : → passe à la slide principale suivante,
// même depuis le milieu d'un débranchement ; ↓ y entre puis avance dedans
// (en bas de la pile, ↓ rejoint la slide principale suivante) ; ↑ remonte ;
// ← revient à la slide principale précédente.
//
// Réglages par slide :
//   data-autoplay="off"        pas d'enchaînement (fragments au clic)
//   data-autoplay-step="1200"  délai entre deux fragments, en ms

const FIRST_DELAY_MS = 450; // laisse finir la transition de slide
const STEP_MS = 650;
const CODE_STEP_MS = 2200; // étapes de surlignage de code : le temps de lire

const RIGHT_KEYS = [39, 32, 34, 76]; // → espace PgDn L (N ouvre les notes)
const DOWN_KEYS = [40, 74]; // ↓ J
const LEFT_KEYS = [37, 33, 80, 72]; // ← PgUp P H
const UP_KEYS = [38, 75]; // ↑ K

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

  // Pendant l'affichage progressif, « avancer » affiche tout d'un coup.
  const forward = (move) => () => {
    if (hasHiddenFragments(deck.getCurrentSlide())) showAll();
    else move();
  };
  const backward = (move) => () => {
    stop();
    move();
  };

  const advance = forward(() => deck.right({ skipFragments: true }));
  const down = forward(() =>
    deck.availableRoutes().down
      ? deck.down({ skipFragments: true })
      : deck.right({ skipFragments: true }),
  );
  const back = backward(() => deck.left({ skipFragments: true }));
  const up = backward(() =>
    deck.availableRoutes().up
      ? deck.up({ skipFragments: true })
      : deck.left({ skipFragments: true }),
  );

  const keyboard = {};
  RIGHT_KEYS.forEach((k) => (keyboard[k] = advance));
  DOWN_KEYS.forEach((k) => (keyboard[k] = down));
  LEFT_KEYS.forEach((k) => (keyboard[k] = back));
  UP_KEYS.forEach((k) => (keyboard[k] = up));

  // Les flèches à l'écran suivent la même logique que le clavier.
  const CONTROLS = [
    ['.navigate-right', advance],
    ['.navigate-down', down],
    ['.navigate-left', back],
    ['.navigate-up', up],
  ];
  document.addEventListener(
    'click',
    (e) => {
      const hit = CONTROLS.find(([sel]) => e.target.closest?.(`.reveal .controls ${sel}`));
      if (!hit) return;
      e.preventDefault();
      e.stopPropagation();
      hit[1]();
    },
    true,
  );

  deck.on('ready', () => schedule(FIRST_DELAY_MS));
  deck.on('slidechanged', () => schedule(FIRST_DELAY_MS));
  deck.on('overviewshown', stop);
  deck.on('overviewhidden', () => schedule(FIRST_DELAY_MS));

  return { keyboard, advance, back, down, up };
}
