# genesis_widgetbook

Catalogue [Widgetbook](https://docs.widgetbook.io/~v4) (4.0.0-beta.14) des briques du design system et des six composants du catalogue A2UI `genesis` de Genesis Canvas. C'est un outil de développement : l'app `genesis_canvas` ne dépend pas de ce paquet, et aucun service Widgetbook Cloud n'est utilisé (adr-0006).

## Contenu

- `lib/ds/` : stories des briques `DsStatusChip`, `DsSkeleton` et `DsNeutralState` (le squelette n'est couvert qu'ici, une seule fois).
- `lib/genesis/` : une story par composant du contrat (`KeyIndicator`, `TrendChart`, `ReviewSentiment`, `ReleaseChecklist`, `ActionBar`, `CrashList`), en trois états : `Data` (exemple complet du contrat), `NoData` (surface créée, aucune donnée) et `Neutral` (données invalides, RG-10). L'hôte `GenesisSurfaceHost` crée un `SurfaceController(catalogs: [genesisCatalog()])` et lui rejoue les messages A2UI de l'exemple : le rendu est celui du vrai catalogue, sans simulacre.
- `assets/examples/` : copies des exemples de `contracts/a2ui/genesis/v1/examples/`. Flutter ne peut pas empaqueter un asset hors du paquet ; `test/examples_assets_test.dart` échoue si une copie diffère de l'original. Après une modification du contrat, recopier le fichier concerné.
- Thème de scène seul (RG-09), deux cellules réelles du canevas (620×302 et 940×302), animations coupées pour des captures stables.

## Lancer

```sh
cd apps/genesis_widgetbook
flutter run -d chrome
```

Le dossier `web/` est versionné. Il n'y a pas de dossier `linux/` : pour une exécution en fenêtre de bureau, générer le runner localement avec `flutter create --platforms=linux .` (non versionné), puis `flutter run -d linux`.

## Régénérer le code

Les fichiers `*.stories.g.dart`, `components.g.dart` et `widgetbook.config.dart` sont générés et versionnés (ils sont contrôlés par `dart format` et `flutter analyze`). Après avoir ajouté ou modifié une story :

```sh
dart run build_runner build
```

Un composant d'une story porte le nom du type de son constructeur : c'est pourquoi les six classes de `lib/genesis/genesis_components.dart` portent les noms des composants du contrat.

## Tests

```sh
flutter test
```

`test/widgetbook_test.dart` compare les composants du catalogue à `GenesisContract.components` plus les trois briques, puis lance `testWidgetbook` : un PNG et un JSON (arbre de sémantique, violations d'accessibilité) par scénario dans `build/.widgetbook/<Composant>/<Story>/<Cellule>.{png,json}` (dossier ignoré par git). Ces captures ne sont pas comparées à une référence. `test/genesis_surface_host_test.dart` vérifie que l'hôte affiche bien les textes du contrat.

## Construire le site web statique

```sh
tool/build_widgetbook.sh [BASE_HREF]
```

`BASE_HREF` (défaut `/`, doit commencer et finir par `/`) est le chemin de publication, par exemple `/ai_voice_ui/` pour GitHub Pages. La sortie est `build/web`, à servir par n'importe quel hébergeur statique (voir la note `ds-widgetbook-publish-web` de `knowledge/`). Le script n'est jamais appelé par la porte `tools/loop/gate.sh`.

## Jetons du design system

Les jetons (couleurs, typographie, espacements) viennent de `packages/shared/design_system`, qui les génère avec `tool/build_tokens.sh` (Node requis à ce seul moment). Voir `packages/shared/design_system/tool/build_tokens.sh`.
