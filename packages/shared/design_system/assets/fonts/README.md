# Polices embarquées du design system

Polices de la scène Genesis Canvas (spec 017, U11), déclarées dans le
`pubspec.yaml` du paquet `shared_design_system` et embarquées dans l'app :

- `SpaceGrotesk-Variable.ttf` : famille `Space Grotesk`, texte courant et
  titres ; fichier **variable**, axe `wght` de 300 à 700 (valeur par défaut 300) ;
- `JetBrainsMono-Variable.ttf` : famille `JetBrains Mono`, données, verdicts
  et libellés ; fichier **variable**, axe `wght` de 100 à 800 (valeur par défaut 400) ;
- `DejaVuSans.ttf` : famille `DejaVu Sans`, repli des glyphes absents des deux
  autres (✓ ▲ ▶ ↺ ◆ ★ et l'espace fine insécable U+202F), statique.

Les familles sont nommées **en clair avec le préfixe de paquet** dans le code
(`SceneFonts.sans`, `.mono`, `.fallback`) : Flutter les déclare ainsi dans le
`FontManifest.json` de l'app. Aucun téléchargement à la construction.

## Source épinglée

Dépôt `github.com/google/fonts`, commit `6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec` (2026-11-02) :
https://raw.githubusercontent.com/google/fonts/6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec/ofl/spacegrotesk/ et https://raw.githubusercontent.com/google/fonts/6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec/ofl/jetbrainsmono/ (`SpaceGrotesk[wght].ttf`,
`JetBrainsMono[wght].ttf`, `OFL.txt`). Les crochets du nom d'origine sont
retirés des fichiers ici (`%5B` et `%5D` dans l'URL).

## Empreintes SHA-256

```
acad6de1fc93436f5c0f1f4137751ef04f1aea3063e7036535970ffcfbd79f72  SpaceGrotesk-Variable.ttf
48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda  JetBrainsMono-Variable.ttf
b4c632e3cdf9acc7f28758fb5a323c8524d7fc6660d46904d9b6cbe2809c419c  DejaVuSans.ttf
564ce565c371c5e5bbf286006565a7c9aa55a9f56e7ca58d56e05d649dd61a72  OFL-SpaceGrotesk.txt
b2fe5e8987594e9ffd1d2ca52a2f5d73eb8335243893c5d6254b5ad69269591d  OFL-JetBrainsMono.txt
63d3ba759d12804c5b31a9d5940d855c1820d1f5999e6b0872eb1c7ff045fbc9  LICENSE-DejaVu.txt
```

`test/scene_fonts_test.dart` recalcule ces empreintes. Licences et nom de
police réservé : `LICENSES.md`.
