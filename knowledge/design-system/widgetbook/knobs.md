---
id: ds-widgetbook-knobs
title: Widgetbook 3.x — knobs (context.knobs)
tags: [widgetbook, knobs, use-case, design-system]
status: verified
updated: 2026-10-28
sources: [https://docs.widgetbook.io/knobs/overview]
links: [ds-widgetbook-versions, ds-widgetbook-cloud-multi-snapshot, ds-widgetbook-4-beta]
---
# Les knobs modifient à chaud les paramètres d'un use case

> Référence Widgetbook 3.x. Le projet utilise la 4.0 bêta ([[adr-0008-ds-widgetbook-4-beta]]) : voir [[ds-widgetbook-4-args-addons]].

On y accède par `context.knobs`, un getter qui renvoie un builder.
- Chaque knob **exige un `label`**, unique au sein du use case.
- `initialValue` et `description` sont optionnels. `description` sert de documentation dans l'app.
- Un knob nullable sans `initialValue` vaut `null` par défaut.

## Types fournis
`boolean`, `int.input` / `int.slider`, `double.input` / `double.slider`, `string`, `duration`, `dateTime`, `color`, `iterable.segmented`, `object.dropdown` / `object.segmented`.

Chacun a sa variante `OrNull` : `booleanOrNull`, `stringOrNull`, `intOrNull.slider`, `objectOrNull.dropdown`…

Chaque type a aussi une classe `*KnobConfig` (`BooleanKnobConfig`, `StringKnobConfig`…) qui sert aux multi-snapshots de Widgetbook Cloud.

```dart
@widgetbook.UseCase(name: 'Primary', type: DsButton)
Widget primaryButton(BuildContext context) => DsButton(
  label: context.knobs.string(label: 'Libellé', initialValue: 'Valider'),
  size: context.knobs.object.dropdown(
      label: 'Taille', options: DsButtonSize.values,
      labelBuilder: (s) => s.name),
  loading: context.knobs.boolean(label: 'Chargement'),
  onPressed: context.knobs.boolean(label: 'Désactivé') ? null : () {},
);
```

## Bonnes pratiques (opinion)
- Un knob pour chaque paramètre **public** du composant. Les états (désactivé, chargement, erreur) sont des knobs booléens.
- Exposer les **variantes** sous forme d'enum, avec `object.dropdown` ou `segmented`, plutôt que d'écrire un use case par variante.
- Créer un use case séparé pour chaque **état métier** qui mérite une revue visuelle : vide, liste longue, texte très long.

## ⚠️ Pièges
- La doc a une coquille : les knobs int nullables y sont libellés `int.input`.
