---
id: ds-widgetbook-4-stories
title: Widgetbook 4.0 bêta — stories générées (*.stories.dart, Meta, $Story)
tags: [widgetbook, stories, codegen, beta, design-system]
status: verified
updated: 2026-10-28
sources: [https://github.com/widgetbook/widgetbook/blob/v4/docs/stories/code-generation.mdx, https://github.com/widgetbook/widgetbook/pull/1931, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/framework/story.dart, https://github.com/widgetbook/widgetbook/blob/v4/docs/args/overview.mdx, https://github.com/widgetbook/widgetbook/blob/v4/examples/full_example/lib/components/custom_card.stories.dart, https://github.com/widgetbook/widgetbook/blob/v4/docs/documentation/doc-blocks.mdx, https://docs.widgetbook.io/~v4/whats-new-in-v4, https://docs.widgetbook.io/~v4/quick-start]
links: [ds-widgetbook-4-setup, ds-widgetbook-4-args-addons, ds-widgetbook-4-testing, ds-widgetbook-knobs, ds-component-api]
---
# Un fichier `*.stories.dart` = un `Meta` const + des variables `$Story`

API 4.0.0-beta.14 au 2026-10-28. Équivalences v3 → v4 : `@UseCase` → story (`_Story`), `context.knobs` → args typés (`_Args`).

## Déclaration
- Le fichier contient `part '<nom>.stories.g.dart';` et `const meta = Meta(MonWidget.new);`. `Meta` prend en positionnel un **tear-off de constructeur** et doit être `const`.
- Le générateur produit `_Args`, `_Story`, `_Scenario`, `_Defaults` et `_Component`, plus un registre global `components.g.dart` à la racine de `lib`.
- Chaque story est une variable top-level préfixée par `$`. Son nom sans le `$` devient le nom affiché, sauf si `name:` est fourni. Le nom `'Docs'` est **interdit** (assert).
- `Meta(W.new, argsType: X.new)` : args personnalisés. Un `builder` devient alors obligatoire, par story ou via `_Defaults`.
- `ComponentMeta` (facultatif, **un seul par fichier**) porte `name`, `path` et `docsBuilder`.
- **Plusieurs constructeurs :** un `Meta` par constructeur (`const iconMeta = Meta(MyButton.icon);`). Les types générés sont alors préfixés en PascalCase : `_IconStory`, `_IconArgs`, `_IconDefaults`, `_IconScenario`.
- `_Defaults(setup: (context, child, args) => ..., builder: (context, args) => ...)` : valeurs partagées. Une seule par variante, reconnue par son **type** et non par son nom.

## Signature de `Story` (beta.14)
`Story({String? name, designLink, setup = defaultSetup, modes, required args, required builder, scenarios = const [], excludeFromTests = false})`. Le `_Story` généré fournit un builder par défaut quand `Meta` cible le widget sans `argsType`.

## Paramètres requis
- `Arg.fixed(valeur)` fige une valeur sans contrôle dans l'UI (callbacks, enfants).
- `_Args.fixed(...)` prend directement les valeurs brutes (scénarios, ou une `_Story`).
- Un paramètre requis non primitif et sans défaut devient `required Arg<Type>`. Un `_Story()` sans args ne compile donc pas (déduction, cohérente avec le TODO du template de la CLI). Exemple typique : `onPressed: Arg.fixed(() {})`.

## Exemple officiel (full_example, branche v4, copie fidèle)
```dart
part 'custom_card.stories.g.dart';

const meta = Meta(CustomCard.new);

final $Default = _Story(
  name: 'Default',
  args: _Args(
    child: Arg.fixed(
      const Text('This is a custom card'),
    ),
  ),
);
```

## Documentation intégrée
`defaultDocsBuilder()` renvoie `[ComponentNameDocBlock(), DartCommentDocBlock(), StoriesDocBlock()]`. `StoriesDocBlock` a une hauteur fixe de 500 px par défaut : la régler avec `height:` ou la supprimer avec `.unconstrained()`. Personnalisation : `ComponentMeta(docsBuilder: (blocks) => blocks.replaceFirst<DartCommentDocBlock>(...))`.

## ⚠️ Pièges
- **Changement cassant de la beta.7 (PR #1931) :** `Meta<MyWidget>()` et `MetaWithArgs<MyWidget, MyArgs>()` n'existent plus. Les exemples et billets antérieurs à la beta.7 ne compilent pas.
