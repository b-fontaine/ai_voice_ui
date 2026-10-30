import { startDeck } from './deck.js';

// Chaque fichier src/sections/NN-*.html contient une ou plusieurs <section>.
// L'ordre de la présentation est l'ordre alphabétique des noms de fichiers.
const sections = import.meta.glob('./sections/*.html', {
  query: '?raw',
  import: 'default',
  eager: true,
});

const html = Object.keys(sections)
  .sort()
  .map((path) => `<!-- ${path} -->\n${sections[path]}`)
  .join('\n');

document.querySelector('.reveal .slides').innerHTML = html;

const deck = startDeck();

// Accès console (débogage, QA visuelle) : Reveal.slide(h, v, f), etc.
window.Reveal = deck;
