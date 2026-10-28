---
id: ds-widgetbook-4-risks
title: Widgetbook 4.0 bêta — risques (cadence, doc, migration IA, issues ouvertes)
tags: [widgetbook, beta, risks, migration, bloc, design-system]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/api/packages/widgetbook, https://docs.widgetbook.io/~v4/llms.txt, https://docs.widgetbook.io/~v4/whats-new-in-v4, https://docs.widgetbook.io/~v4/v4-migration, https://raw.githubusercontent.com/widgetbook/widgetbook/refs/heads/v4/docs/assets/guides/v4-migration/prompt.md, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/CHANGELOG.md, https://github.com/widgetbook/widgetbook/pull/2022, https://github.com/widgetbook/widgetbook/issues/1984, https://github.com/widgetbook/widgetbook/issues/1797, https://github.com/widgetbook/widgetbook/issues/2044]
links: [adr-0008-ds-widgetbook-4-beta, ds-widgetbook-4-setup, ds-widgetbook-4-args-addons, bloc-providers-selector, ds-widgetbook-publish-web, ds-widgetbook-4-spike]
---
# La v4 est une bêta active sans date de GA : épingler, relire, contourner

Relevé au 2026-10-28.

## Cadence et état
- Bêtas sur pub.dev : beta.1 (2026-02-25), beta.2 (03-06), beta.3 (03-31), beta.4 (06-13), beta.6 à beta.8 (22-25 juin), beta.9 (07-02), beta.10 (07-08), beta.11 (08-01), beta.12 (08-25), beta.13 (08-28), beta.14 (09-11). La première alpha date du 2023-12-23.
- La beta.5 a été sautée volontairement, pour aligner les numéros de `widgetbook` et `widgetbook_cli`.
- Aucune bêta depuis environ 7 semaines. La section « Unreleased » du CHANGELOG contient déjà #2042 (commit du 2026-10-12) : une beta.15 est probable, mais pas publiée.
- Aucune date de 4.0 stable trouvée. whats-new annonce seulement une tarification Cloud « before general availability » (non vérifié au-delà).
- Le développement se fait sur la branche `v4`. `main` en est encore à 3.25.0. La PR #2022 a passé les exemples v4 à `flutter: ^3.47.0`.
- Pas de changement cassant après la beta.9. La beta.7 (Meta) et la beta.4 (`scenarioConfig`) l'étaient.

## Documentation
- Doc v4 : `https://docs.widgetbook.io/~v4/…` (`/v4` et `/next` renvoient 404). Elle a son propre `llms.txt` (`/~v4/llms.txt`) et chaque page existe en `.md` (suffixe).
- Elle affiche un avertissement : l'API peut casser dans des versions mineures.

## Guide de migration assisté par IA
Le guide v4 recommande de migrer avec un agent IA : un prompt (`docs/assets/guides/v4-migration/prompt.md`) à compléter avec 3 à 5 stories écrites à la main. La voie manuelle passe par `widgetbook init`. Ce prompt est **en partie périmé** par rapport à beta.14 :
- il utilise `Config(scenarios: …)`, alors que c'est `scenarioConfig: ScenarioConfig(definitions: …)` depuis beta.4 ;
- il écrit `BooleanArg` au lieu de `BoolArg`, `SegmentedArgStyle` au lieu de `SegmentedSingleArgStyle`, `SingleArg([...])` au lieu de `SingleArg(value, values:)` ;
- il donne `LocaleAddon(supportedLocales, localizationsDelegates)`, alors que les delegates sont un positionnel **optionnel**.
D'autres écarts ne sont pas exclus : le prompt n'a pas été relu ligne à ligne.

## Issues ouvertes notables
Elles n'ont pas d'étiquette v4 : le tri v3/v4 a été fait à la main.
- **#1984** (**non reproduit** par le spike du 2026-10-28 en beta.14 web : [[ds-widgetbook-4-spike]]) : si `setup` injecte un `BlocProvider`, passer d'une story sœur à l'autre peut garder l'état de la story précédente (beta.10/11). Les correctifs #1994 et #2012 ne règlent pas ce cas, et la PR #2020 a été fermée. **Impact direct** pour une app en Bloc uniquement ([[bloc-providers-selector]]).
- **#1797** (le spike confirme que la stratégie hash par défaut gère `#/?path=…` et le rechargement) : la stratégie d'URL « path » n'est pas supportée : un rechargement ou un lien profond renvoie à l'accueil, en `flutter run -d chrome` comme en `flutter build web` ([[ds-widgetbook-publish-web]]).
- **#2043 :** `TimeDilationAddon` ralentit aussi l'interface de Widgetbook.
- **#2041 :** `NullableDoubleArg` ne borne pas `initialValue` entre min et max.
- **#2044 :** `MaterialThemeAddon` est incompatible avec `material_ui`. Contournement : `ThemeAddon<T>` ([[ds-widgetbook-4-args-addons]]).
- #1747 (`MaterialThemeAddon` casse hover/pressed) vise la 3.19.0. Sa pertinence en v4 n'est pas confirmée.

## Mesures (opinion)
- Épingler exactement `4.0.0-beta.14` (package et CLI). Chaque montée se fait dans une PR dédiée, après lecture du CHANGELOG ([[adr-0008-ds-widgetbook-4-beta]]).
- Relire toute sortie d'agent produite à partir du prompt de migration. Les signatures font foi : [[ds-widgetbook-4-args-addons]].
- #1984 : les composants du DS n'ont pas de Bloc. Les stories de features créent un Bloc frais par story, dans le widget hôte plutôt que via `setup`, avec des fakes aux frontières. Contournement non vérifié : à valider pendant le spike.
- #1797 : publier le catalogue web avec la stratégie d'URL par défaut, et ne pas promettre de liens profonds stables.
- Repli : la 3.25.0 stable ([[ds-widgetbook-versions]]), si une bêta bloque une livraison.
