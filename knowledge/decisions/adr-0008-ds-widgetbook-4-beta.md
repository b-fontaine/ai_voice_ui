---
id: adr-0008-ds-widgetbook-4-beta
title: "ADR-0008 — Widgetbook 4.0 bêta adopté dès maintenant"
tags: [adr, decision, widgetbook, beta, design-system]
status: opinion
updated: 2026-10-28
sources: [https://pub.dev/api/packages/widgetbook, https://docs.widgetbook.io/~v4/whats-new-in-v4]
links: [ds-widgetbook-4-beta, ds-widgetbook-4-setup, ds-widgetbook-4-risks, ds-widgetbook-4-genui, ds-widgetbook-versions, ds-widgetbook-4-spike]
---
# ADR-0008 — Widgetbook 4.0.0-beta.14, version épinglée exacte

- **Statut :** acceptée le 2026-10-28.
- **Décideur :** le porteur du projet (« Maintenant »), **contre la recommandation de l'assistant**, qui conseillait d'attendre la stable.
- **Raison du porteur :** le projet est une **démonstration pour un talk Flutter GenUI**, où l'avance de phase est assumée.

## Contexte (vérifié le 2026-10-28)
- La stable est 3.25.0. La préversion est **4.0.0-beta.14** (2026-09-11), compatible Flutter 3.47 : les exemples officiels v4 ciblent `flutter: ^3.47.0`. Aucune date de GA n'est annoncée [[ds-widgetbook-4-risks]].
- La v4 apporte les Stories, Scenarios et Args générés, ainsi que `testWidgetbook` avec des scénarios et de l'accessibilité **en local, sans Cloud**. Cela rejoint [[adr-0006-ds-no-widgetbook-cloud]].
- **Argument fort pour le talk :** la doc v4 a une section **GenUI**, qui fait correspondre `CatalogItem` ↔ composant et rejoue des surfaces A2UI en cache [[ds-widgetbook-4-genui]].

## Décision
- `widgetbook: 4.0.0-beta.14`, version **exacte** sans `^`, avec `build_runner`. On n'ajoute ni `widgetbook_generator`, ni `widgetbook_annotation`, ni `widgetbook_test` [[ds-widgetbook-4-setup]].
- La télémétrie du builder est désactivée dans `build.yaml`.
- Les notes 3.x restent dans la base comme référence.

## Risques retenus et mesures
- **API cassante entre bêtas :** version épinglée. Chaque montée fait l'objet d'une PR dédiée, après lecture du changelog.
- **#2044 `MaterialThemeAddon` incompatible avec `material_ui`** ([[adr-0004-ds-visual-base-m3]]) : on utilise `ThemeAddon<T>` générique, comme le conseille le mainteneur.
- **#1984 :** l'état peut fuir entre stories quand un `BlocProvider` est injecté par `setup`. Les composants du DS sont sans Bloc ; les stories de features utilisent des Blocs frais par story. À vérifier pendant le spike.
- **#1797 :** pas de stratégie d'URL `path` ni de liens profonds fiables. Pour la démo, on navigue depuis l'accueil.
- **Guide de migration IA en partie périmé :** on part de zéro en v4, sans migrer de code 3.x.

## Résultat du spike (2026-10-28)
Décision **maintenue** : la beta.14 tient sous Flutter 3.47.8 avec `material_ui` (web, Wasm, Linux). Le #1984 n'est pas reproduit et le #1797 n'affecte pas la stratégie hash. Cinq contournements sont à appliquer (`appBuilder` material_ui, imports des stories, marge, règles a11y desktop, scénarios Light/Dark explicites) : [[ds-widgetbook-4-spike]].

## Quand réexaminer
- Sortie de la 4.0.0 stable : passer à `^4.0.0`.
- Une bêta casse la démo et aucun contournement n'existe avant la date du talk : repli possible sur la 3.25.0, avec les notes 3.x.
