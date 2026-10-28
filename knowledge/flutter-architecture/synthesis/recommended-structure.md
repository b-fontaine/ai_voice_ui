---
id: arch-recommended-structure
title: Gabarit d'arborescence pour une app Flutter multi-agents
tags: [architecture, folder-structure, workspace, multi-agent, fsd, clean-architecture]
status: opinion
updated: 2026-10-28
sources: [https://dart.dev/tools/pub/workspaces, https://docs.flutter.dev/app-architecture/case-study]
links: [arch-clean-fsd-combo, arch-recommended-dependency-rules, arch-pub-workspaces, arch-compass-structure, proj-avw-overview, proj-sk-overview, di-micro-packages, bloc-no-cubit, ds-package-structure]
---
# Workspace pub découpé selon FSD, slices internes en Clean

Gabarit générique : les noms entre `<...>` sont à remplacer par ceux du projet.

```
<repo>/                           # pubspec racine : workspace + melos
├── apps/<app>/                   # [app + pages + widgets] Flutter
│   └── lib/
│       ├── app/{di,router,theme,bootstrap}/   # main_{dev,staging,prod}.dart à côté
│       ├── pages/<page>/{ui,model}/
│       └── widgets/<shell>/                   # ex. shell : voix + surface GenUI
├── packages/
│   ├── features/
│   │   ├── <orchestrator>/       # routage intentions/tool calls, sur les ports uniquement
│   │   ├── <voice_agent>/        # un package par agent (ex. OpenAI / Gemini Live)
│   │   │   └── lib/{<voice_agent>.dart, src/{ui,model/{state,domain},api/{<provider>},config}}
│   │   └── <ui_agent>/           # ex. genui + A2UI, catalogue de widgets
│   ├── entities/                 # pur Dart : slices agent/, session/, user/
│   │   └── lib/{entities.dart, src/agent/{agent_event,tool_call,ports}.dart}
│   └── shared/
│       ├── core/                 # Result, failures, logging, env/config, clock
│       ├── realtime_transport/   # WebRTC/WebSocket génériques, audio I/O
│       └── design_system/        # DS*, thème, Widgetbook (comme saaster)
├── testing/                      # package de fakes partagés (style Compass)
└── tools/arch_lints/             # plugin analyzer maison (optionnel)
```

**Choix :**
- `pages` et `widgets` restent dans l'app (pages first). On les extrait en packages seulement si une 2ᵉ app (web multi-view, cf. `proj-avw-overview`) les réutilise.
- Un package par agent :
  - frontière vérifiée par le pubspec ;
  - codegen (`freezed`, `injectable`) localisé ;
  - tests isolés.
- `realtime_transport` dans `shared` : aucun métier, réutilisable par d'autres agents.
- DI : chaque package expose son module (micro-package injectable, à vérifier dans le domaine `di-`). L'app compose le tout et relie les ports dans `app/di`.
- Clés éphémères : l'`api` de l'agent vocal les récupère via un service backend, jamais depuis une clé longue durée côté client (`proj-avw-risks`).
- Un fichier de librairie par package avec des `export ... show`, et tout le reste dans `lib/src/`.

⚠️ Pièges
- Ne pas recopier la double structure de saaster (`lib/ui` vs `features/` décrit dans CLAUDE.md, `proj-sk-overview`). Une seule convention, documentée et vérifiée par lint.
