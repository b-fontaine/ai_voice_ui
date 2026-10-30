# Polices des tests de hauteur de cellule

Fixtures de test uniquement : elles ne sont déclarées dans aucun `pubspec.yaml`
(ni `flutter: fonts:` ni `assets:`) et ne sont donc pas embarquées dans
l'application.

Elles servent à `test/ui/cell_height_real_fonts_test.dart`, qui vérifie que le
contenu de l'acte 2 tient dans une cellule de 936 × 250 px. Avec la police de
test par défaut (Ahem), toutes les lignes ont la même hauteur et un
débordement dû au repli d'un glyphe (« ★ ») n'apparaît pas. Les deux polices
reproduisent le rendu de la capture de la boucle sous Linux :

- `NotoSans-Regular.ttf` : texte courant (paquet Debian `fonts-noto-core`
  20201225-2build1) ;
- `DejaVuSans.ttf` : repli du glyphe « ★ » (paquet `fonts-dejavu-core`
  2.37-8build1).

Copies octet pour octet des fichiers système, afin que le test soit hermétique
(CI, poste du porteur). Licences : `LICENSES.md`, `LICENSE-NotoSans.txt`,
`LICENSE-DejaVu.txt`.
