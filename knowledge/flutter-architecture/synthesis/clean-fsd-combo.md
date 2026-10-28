---
id: arch-clean-fsd-combo
title: Combiner Clean Architecture et FSD (proposition)
tags: [clean-architecture, fsd, synthesis, multi-agent]
status: opinion
updated: 2026-10-28
sources: [https://feature-sliced.design/docs/reference/layers, https://docs.flutter.dev/app-architecture/guide]
links: [arch-fsd-layers, arch-clean-flutter-layers, arch-fsd-dart-mapping, arch-recommended-structure, arch-recommended-dependency-rules, proj-avw-genui-bridge]
---
# FSD découpe verticalement, Clean découpe chaque slice

- **Axe vertical (FSD) :** les couches `app > pages > widgets > features > entities > shared`. Une slice n'importe que des slices **strictement plus basses**, et jamais une sœur.
- **Axe horizontal (Clean) :** à l'intérieur d'une slice, `ui → model(state → domain) ← api`. Le domaine est pur Dart, et les repositories abstraits vivent dans `model/domain`.

| Segment FSD | Contenu Clean |
|---|---|
| `ui/` | pages, widgets, `BlocBuilder` |
| `model/state/` | Bloc (= ViewModel ; Cubit exclu, `bloc-no-cubit`), états `freezed` |
| `model/domain/` | entités locales, interfaces de repository, use-cases si justifiés, failures |
| `api/` | services (transport), DTO, mappers, implémentations des repositories |

**Le problème de l'orchestrateur :** il coordonne l'agent voix et l'agent GenUI. Or deux features ne peuvent pas s'importer, et `processes` est déprécié. Solution par **inversion de dépendance** :
1. `entities/agent` (pur Dart) définit les ports `VoiceAgentPort`, `UiAgentPort` et les modèles `AgentEvent`, `ToolCall`, `AgentIntent`.
2. Les features `voice_agent` et `genui_agent` **implémentent** ces ports.
3. La feature `orchestrator` ne dépend **que des ports**. Elle route les intentions et les tool calls, par exemple `show_screen` → `UiAgentPort.render`.
4. La couche `app` (DI racine) relie les ports à leurs implémentations.

On obtient le pont voix → GenUI d'ai_voice_widget (`proj-avw-genui-bridge`) sans couplage direct entre features.

**Correspondance Septeo :**
- l'Interactor devient un use-case de `model/domain` ;
- l'orchestrateur du domaine (`VoiceAi` dans ai_voice_widget, `proj-avw-overview`) devient une feature d'orchestration qui ne dépend que des ports.

⚠️ Pièges
- Ne pas en faire trop : appliquer « pages first » (`arch-fsd-pages-first`) et ne pas créer de use-case « pass-through ».
- Les ports `entities/agent` ne doivent pas suivre la forme d'un fournisseur (OpenAI ou Gemini).
