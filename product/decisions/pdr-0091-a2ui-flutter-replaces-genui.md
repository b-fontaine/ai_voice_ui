---
id: pdr-0091-a2ui-flutter-replaces-genui
title: "PDR-0091 — Le rendu A2UI passe de genui 0.10.4 à a2ui_core 0.6.0 et a2ui_flutter 0.2.0"
area: decisions
status: proposed
updated: 2026-11-10
sources: [https://github.com/a2ui-project/a2ui/issues/3297, https://github.com/a2ui-project/a2ui/blob/main/.agents/skills/a2ui-migration/references/dart_genui_to_1_0.md, https://pub.dev/packages/a2ui_core, https://pub.dev/packages/a2ui_flutter, knowledge:genui-migration-to-a2ui, knowledge:genui-migration-0-10]
links: [pdr-0018-a2ui-v09-genui-0-10-4, pdr-0010-pinned-experimental-versions, pdr-0047-go-and-tool-versions-pinned, pdr-0053-client-side-a2ui-validation-from-007, pdr-0028-linux-demo-machine, p-ar-stack, p-ar-frontend, p-ar-frontend-screen, p-ar-replay, genui-migration-to-a2ui, genui-migration-0-10, genui-overview]
tags: [pdr, decision, a2ui, genui, versions]
decision_status: proposée
decided_on: 2026-11-10
decided_by: "À décider par Benoît FONTAINE (porteur) ; proposée par l'équipe A2UI dans une pull request de migration"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0091 — a2ui_core et a2ui_flutter à la place de genui

> **En bref.** Proposition : le canevas rend l'A2UI avec `a2ui_core` **0.6.0** et `a2ui_flutter` **0.2.0**, figés exactement, à la place de `genui` 0.10.4, que ses mainteneurs remplacent par ces paquets. Le protocole ne change pas : `"version": "v0.9"` exactement. Si elle est acceptée, elle remplace la partie « genui 0.10.4 figé » de [pdr-0018](pdr-0018-a2ui-v09-genui-0-10-4.md) ; la partie protocole de pdr-0018 reste en vigueur.

Part de l'assistant : aucune. La proposition et la migration viennent de l'équipe A2UI (pull request externe) ; le porteur décide en l'acceptant ou en la refusant.

## Contexte
- `genui` est remplacé par trois paquets publiés par le projet A2UI : `a2ui_core` (messages, `MessageProcessor`, data model), `a2ui_flutter` (`A2uiSurface`, `ComponentImplementation`) et `a2ui_agent` (prompts, inutile ici). L'équipe A2UI migre les dépendants de genui (issue a2ui-project/a2ui#3297) [genui-migration-to-a2ui].
- La note [genui-migration-0-10] prévoyait déjà ce redécoupage et une nouvelle migration.
- `a2ui_flutter` 0.2.0 exige `a2ui_core` ^0.6.0 : les paquets qui importaient `a2ui_core` 0.1.1 directement (`shared/core`, `entities/session`, `features/replay`, `features/voice_session`) suivent.

## Hypothèses
- ✅ `a2ui_core` 0.6.0 lit et applique les messages v0.9 du contrat `genesis` (suites `flutter test` de tous les paquets du workspace vertes, 2026-11-10).
- ⚠️ Hypothèse non confirmée : la démo au micro se comporte comme avant (voix, rejeu, capture). Seule une répétition complète par le porteur le confirme ; la migration n'a été vérifiée que par l'analyse et les tests.

## Options
1. **`a2ui_core` 0.6.0 + `a2ui_flutter` 0.2.0, protocole v0.9** (proposée)
2. Rester sur `genui` 0.10.4 jusqu'après le talk

## Décision
- Dépendances figées sans `^` (pdr-0010) : `a2ui_core: 0.6.0`, `a2ui_flutter: 0.2.0` ; `genui` retiré de tous les `pubspec.yaml` du workspace.
- Le protocole reste A2UI v0.9 (pdr-0018). `A2uiDecoder` refuse toute autre `version`, car `a2ui_core` 0.6.0 lit aussi `"v0.9.1"` et `"1.0"`.
- Correspondances : `SurfaceController` → `MessageProcessor<ComponentImplementation>` ; `Surface` → `A2uiSurface` ; `Catalog`/`CatalogItem` → `CatalogImplementation`/`ComponentImplementation` ; `A2uiMessage` → `AgentToRendererMessage` ; les erreurs du moteur arrivent sur `model.onError` au lieu de `onSubmit`.

## Raisons
- genui n'évolue plus ; ses mainteneurs orientent vers `a2ui_core` et `a2ui_flutter`.
- Le contrat, les fixtures et le protocole ne changent pas : le panneau montre les mêmes messages (pdr-0008).
- Le build Linux n'a plus besoin des en-têtes GStreamer : `audioplayers_linux` et `url_launcher_linux` venaient de genui.

## Options écartées
- **Rester sur genui 0.10.4** : possible à court terme (le paquet reste résoluble), mais toute correction future du rendu A2UI se fera dans `a2ui_flutter`.

## Conséquences
- [p-ar-stack](../architecture/stack.md), [p-ar-frontend](../architecture/frontend.md), [p-ar-frontend-screen](../architecture/frontend-screen.md), [p-ar-replay](../architecture/replay.md) : moteur et versions mis à jour.
- Comportements qui changent avec le moteur : `updateComponents` avec `components: []`, ou une enveloppe avec une clé inconnue, est refusé au décodage ; le message d'erreur du moteur sur `stderr` devient « Erreur du moteur A2UI : … » ; le data model copie les valeurs reçues au lieu de les garder par référence.
- À l'acceptation : passer pdr-0018 à « précisée par pdr-0091 » pour sa partie genui (pdr-0047 et pdr-0090 citent aussi genui 0.10.4).

## Réexaminer si
- La répétition révèle un écart de rendu ou de comportement avec genui 0.10.4.
- Le projet passe à A2UI v1.0 : `a2ui_core` le lit déjà, mais il faut migrer le contrat, l'orchestrateur et les agents ensemble.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-10 | Proposée avec la pull request de migration | Équipe A2UI |

Pas d'archive brute.
