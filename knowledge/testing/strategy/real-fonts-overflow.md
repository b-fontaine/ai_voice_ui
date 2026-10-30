---
id: test-flutter-real-fonts-overflow
title: La police de test Ahem masque les débordements dus au repli de glyphes
tags: [flutter, widget-test, fonts, overflow, layout]
status: verified
updated: 2026-10-30
sources: [https://api.flutter.dev/flutter/services/FontLoader-class.html]
links: [test-mock-boundaries-only, test-golden-alchemist]
---
# Un test de widget en police Ahem ne voit pas le débordement d'une cellule qui s'affiche trop haute sur la vraie police

Les tests de widget Flutter rendent le texte avec **Ahem** (carrés pleins, hauteur de ligne = corps). Un glyphe absent de la police principale (par exemple « ★ ») est rendu par une police de **repli** dont l'ascendante et la descendante peuvent être plus grandes : la ligne devient plus haute que sa hauteur nominale. Ahem ne reproduit pas ce repli.

Cas vécu (Flutter 3.47, Linux) : une cellule de 250 px de haut, texte de 24 px, dont deux lignes portent « ★ », débordait de **2 px** dans l'application (bande « BOTTOM OVERFLOWED BY 2.0 PIXELS » sur la capture) alors que tous les tests passaient.

**Parade.** Un test dédié charge les polices réelles avec `FontLoader` (police principale et police de repli) avant de monter le widget à la **géométrie exacte** de la cellule, puis vérifie qu'aucune exception de débordement n'est levée.

```dart
final loader = FontLoader('Noto')..addFont(rootBundleOrFile('NotoSans-Regular.ttf'));
await loader.load();
// ThemeData(fontFamily: 'Noto', fontFamilyFallback: ['DejaVu']) puis pumpWidget à la taille de la cellule.
```

- **Rouge de contrôle** : rétablir temporairement l'ancien espacement doit faire échouer le test ; sinon il ne protège rien.
- **Hermétique** : versionner les fichiers de police dans les fixtures de test (avec leur licence) ; ne pas lire `/usr/share/fonts`, absent d'une autre machine ou de la CI, où le test échouerait.

⚠️ Pièges
- Les fixtures de polices ne doivent pas être déclarées comme assets de l'application.
- Une police système différente donne un rendu différent : figer les fichiers, pas la famille.
