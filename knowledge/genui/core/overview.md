---
id: genui-overview
title: genui — statut, versions et paquets (oct. 2026)
tags: [genui, flutter, versions, alpha]
status: verified
updated: 2026-10-29
sources: [https://pub.dev/packages/genui, https://pub.dev/packages/genui_a2a, https://pub.dev/packages/a2ui_core, https://docs.flutter.dev/ai/genui/get-started, https://github.com/flutter/genui/blob/main/packages/genui/CHANGELOG.md]
links: [genui-architecture, genui-a2ui-overview, genui-migration-from-0-7, genui-migration-0-10, proto-a2ui-pointer, ma-package-versions]
---
# genui : SDK Flutter d'UI générative, en alpha

`genui` (éditeur vérifié `labs.flutter.dev`, BSD-3) laisse un LLM composer une UI Flutter à partir d'un **catalogue** de widgets approuvés, en parlant le protocole **A2UI v0.9**. La doc officielle (Flutter 3.47, maj 2026-09-29) dit : « The `genui` package is in alpha and is likely to change. »

## Versions observées sur pub.dev le 2026-10-26

| Paquet | Version | Publiée | Rôle |
|---|---|---|---|
| `genui` | 0.10.4 | 2026-09-29 | moteur, catalogue, widgets |
| `genui_a2a` | 0.10.1 | 2026-07-20 | connecteur vers un agent A2A distant |
| `a2ui_core` | 0.3.0 | 2026-10-19 | cœur Dart du protocole (genui 0.10.4 dépend de `^0.1.0`) |
| `json_schema_builder` | 0.1.7 | 2026-09-01 | schémas des `CatalogItem` |
| `genai_primitives` | 0.2.4 | 2026-07-16 | `ChatMessage`, `TextPart`, `DataPart` |
| `a2ui_flutter` / `a2ui_agent` | 0.0.1-wip | 08–09/2026 | futur remplaçant modulaire |

Plateformes détectées par pub.dev : Android, iOS, macOS, web. Windows/Linux non listés.

## Trajectoire
- Le CHANGELOG `main` (0.10.6, non publiée) annonce une refonte en paquets modulaires : `a2ui_core`, `a2ui_agent`, `a2ui_flutter`.
- 0.10.6 intègre une copie de `a2ui_core` exportée par `package:genui/a2ui_core.dart`.

⚠️ Pièges
- Ne pas mélanger les versions de `a2ui_core` : depuis 0.10.6, les types venant de `package:a2ui_core` ne sont plus acceptés par genui.
- Épingler la version exacte (`genui: 0.10.4`) : chaque mineure casse l'API.
- Linux desktop : genui 0.10.4 dépend d'`audioplayers` 6.8.1 ; `audioplayers_linux` exige les en-têtes GStreamer (`libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev`), sinon `flutter build linux` échoue (`pkg-config gstreamer-1.0` introuvable). Observé le 2026-10-29 (Flutter 3.47.8, Ubuntu x86_64). pub.dev ne liste pas Linux, mais la cause observée est cette dépendance système ; une fois GStreamer installé, une surface A2UI v0.9 avec liaison de données est rendue sous Linux (observé le 2026-10-29). Après un échec de configuration CMake, `flutter clean` est nécessaire (cache d'installation corrompu).
- Une isolation derrière une interface maison (port/adaptateur) est recommandée (opinion).
