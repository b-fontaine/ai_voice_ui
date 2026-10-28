# Spike Widgetbook 4.0.0-beta.14 (2026-10-28)

Code jetable. Il sert à valider [ADR-0008](../../knowledge/decisions/adr-0008-ds-widgetbook-4-beta.md) avant de construire le design system.
Environnement : Flutter 3.47.8 stable, Dart 3.13.7, Linux x64, Chrome.

## Contenu
- `pubspec.yaml` : pub workspace racine.
- `packages/ds_spike` : mini DS sur `material_ui` 1.8.0, avec `DsButton` (constructeurs `.new` et `.tonal`), `DsTheme` (`fromSeed`, densité compacte) et la `ThemeExtension` `DsSpacing`.
- `widgetbook/` : catalogue `widgetbook: 4.0.0-beta.14` (version exacte), qui contient :
  - `lib/ds/ds_button.stories.dart` : deux `Meta` (`DsButton.new`, `DsButton.tonal`) ;
  - `lib/bloc_leak/` : `CounterBloc` et quatre stories pour l'issue #1984 ;
  - `lib/widgetbook.config.dart` : `appBuilder` `material_ui`, `ThemeAddon<m.ThemeData>`, règles a11y desktop, scénarios Light et Dark ;
  - `test/widgetbook_test.dart` : `testWidgetbook(config)`.

## Résultats
| # | Question | Résultat |
|---|---|---|
| 1 | La beta.14 compile-t-elle sous Flutter 3.47.8, dans un pub workspace ? | ✅ `pub get` résout. `build_runner build` : 40 s à froid (dont 30 s de compilation AOT des builders). `flutter build web` : 73 s ; `--wasm` : 76 s ; `linux` : 33 s. |
| 2 | `MaterialThemeAddon` accepte-t-il le `ThemeData` de `material_ui` (#2044) ? | ❌ Confirmé à la compilation : il existe deux classes `ThemeData` distinctes. ✅ `ThemeAddon<m.ThemeData>` fonctionne, y compris la bascule Light/Dark dans l'UI (URL `&theme={name:Dark}`). |
| 2b | L'`appBuilder` par défaut convient-il ? | ❌ Il crée un `MaterialApp` de `flutter/material`, alors que les widgets `material_ui` cherchent leurs propres ancêtres. Il faut un `appBuilder` qui renvoie `m.MaterialApp(home: m.Material(child: …))`. |
| 3 | L'état d'un Bloc injecté par `setup` fuit-il entre stories sœurs (#1984) ? | ✅ **Non reproduit** en web avec beta.14, ni au clic dans l'arbre (0 → +3, puis sœur à 100, puis retour à 0), ni par changement de hash, ni avec ou sans `key`. Aucun scénario de fuite trouvé dans ce cadre. |
| 3b | Les liens profonds fonctionnent-ils (#1797) ? | ✅ Avec la stratégie d'URL par défaut (hash), `#/?path=…` et le rechargement de page fonctionnent. L'issue ne concerne que la stratégie `path`. |
| 4 | Que produit `testWidgetbook` ? | ✅ Un `testWidgets` par scénario, avec `build/.widgetbook/<Component>/<Story>/<Scenario>.png` et `.json` (modes, args, hash, sémantique, violations). Les violations ne font pas échouer les tests. |
| 4b | Les contrôles a11y sont-ils fiables ? | ⚠️ `MinTapTargetGuideline` **ignore les nœuds qui touchent le bord de la vue** (`isAtBoundary`). Comme le snapshot est cadré au plus près du contenu, un composant qui le remplit n'est jamais contrôlé. Sans marge, `text-contrast` produit aussi des faux positifs (ratio 1.01 sur un texte qui touche le bord). Correctif : une marge de 8 px dans l'`appBuilder`. Ensuite, la densité compacte (boutons de 40 px) viole les seuils 48 et 44 du jeu `recommended`, mais respecte WCAG 2.5.8 (24 px) : il faut un jeu de règles desktop. |
| 4c | Peut-on ajouter des scénarios globaux ? | ⚠️ Déclarer des `ScenarioDefinition` **supprime le scénario implicite « Default »**. On déclare donc « Light » et « Dark » explicitement : 14 tests et 14 snapshots pour 7 stories. |
| 4d | `testWidgetbook` tourne-t-il sous `--platform chrome` ? | ❌ « No tests ran », sans erreur, et le processus peut ne pas se terminer seul (prévoir un `timeout`). Il faut rester sur la VM. |

## Pièges relevés
- Le code généré est un `part` du fichier `*.stories.dart`. Il faut y importer **tous** les types des paramètres du widget (`IconData`, `Key`…) : `package:widgetbook/widgetbook.dart` n'exporte pas `flutter/widgets`.
- `textContrastGuideline` vient de `flutter_test`. Pour l'utiliser depuis `lib/`, déclarer `flutter_test` en `dependencies` (widgetbook en dépend déjà).
- Avertissement de build : les `CupertinoIcons` sont référencées sans que `cupertino_icons` soit déclaré. C'est sans effet visible ici ; ajouter `cupertino_icons` si des icônes manquent.
- Collision de nom `ThemeMode` : aucune, tant que `material_ui` est importé avec un préfixe (`as m`) et que `flutter/material` n'est pas importé.

## Vérification indépendante
Un agent vérificateur distinct a reproduit les points 1, 2, 2b, 4, 4b, 4c et 4d le 2026-10-28 : build, sonde #2044, 14 tests et 14 snapshots sans Default, exemption au bord avec ou sans marge, Chrome. Ni #1984 ni les temps de build n'ont été revérifiés.

## Reproduire
```bash
cd spikes/widgetbook4 && flutter pub get
cd widgetbook && dart run build_runner build
flutter test                       # snapshots dans build/.widgetbook
flutter build web && python3 -m http.server -d build/web 8765
```
