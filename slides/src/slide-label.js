// Numéro affiché d'une slide : « 23 » pour une slide principale, « 23.4 » pour
// la 4e slide du débranchement (pile verticale) qui part de la slide 23.
export function slideLabel(deck, slide) {
  const { h, v } = deck.getIndices(slide);
  return v > 0 ? `${h + 1}.${v}` : `${h + 1}`;
}
