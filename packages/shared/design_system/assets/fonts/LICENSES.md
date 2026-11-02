# Licences et empreintes des polices

Source épinglée : dépôt `github.com/google/fonts`, commit `6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec`. Récupération le 2026-11-02.

| Fichier | Licence | Source | SHA-256 |
|---|---|---|---|
| `SpaceGrotesk-Variable.ttf` | SIL Open Font License 1.1 (Copyright 2020 The Space Grotesk Project Authors) | https://raw.githubusercontent.com/google/fonts/6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf | `acad6de1fc93436f5c0f1f4137751ef04f1aea3063e7036535970ffcfbd79f72` |
| `JetBrainsMono-Variable.ttf` | SIL Open Font License 1.1 (Copyright 2020 The JetBrains Mono Project Authors) | https://raw.githubusercontent.com/google/fonts/6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf | `48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda` |
| `OFL-SpaceGrotesk.txt` | texte de la licence ci-dessus | https://raw.githubusercontent.com/google/fonts/6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec/ofl/spacegrotesk/OFL.txt | `564ce565c371c5e5bbf286006565a7c9aa55a9f56e7ca58d56e05d649dd61a72` |
| `OFL-JetBrainsMono.txt` | texte de la licence ci-dessus | https://raw.githubusercontent.com/google/fonts/6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec/ofl/jetbrainsmono/OFL.txt | `b2fe5e8987594e9ffd1d2ca52a2f5d73eb8335243893c5d6254b5ad69269591d` |
| `DejaVuSans.ttf` | Licence Bitstream Vera / DejaVu (redistribution libre, modifications renommées) | DejaVu Fonts 2.37, paquet Debian `fonts-dejavu-core` 2.37-8build1 (copie de `testing/real_fonts/fonts/DejaVuSans.ttf`) | `b4c632e3cdf9acc7f28758fb5a323c8524d7fc6660d46904d9b6cbe2809c419c` |
| `LICENSE-DejaVu.txt` | texte du paquet Debian | copie de `testing/real_fonts/fonts/LICENSE-DejaVu.txt` | `63d3ba759d12804c5b31a9d5940d855c1820d1f5999e6b0872eb1c7ff045fbc9` |

Les fichiers sont redistribués sans modification.

## Nom de police réservé

Aucune des deux licences OFL ne déclare de « Reserved Font Name » : la ligne de
copyright de chacune (première ligne du fichier) n'en porte pas. Une instance
statique dérivée des fichiers variables (repli prévu au plan si le rendu des
graisses échouait) serait donc permise sous l'OFL 1.1, sous réserve de
conserver la licence.

Les licences des trois polices (deux OFL et DejaVu) sont enregistrées dans le `LicenseRegistry` par
`registerSceneFontLicenses()` (`lib/src/scene_fonts.dart`).
