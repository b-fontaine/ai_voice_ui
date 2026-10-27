---
id: ma-package-versions
title: Versions de packages observées (2026-10-26)
tags: [multi-agent, versions, pub.dev, dependencies]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/genui, https://pub.dev/packages/genui_a2a, https://pub.dev/packages/a2ui_core, https://pub.dev/packages/firebase_ai, https://pub.dev/packages/a2a, https://pub.dev/packages/mcp_dart, https://pub.dev/packages/flutter_webrtc, https://github.com/a2aproject/A2A/releases]
links: [ma-flutter-event-bus, genui-a2ui-security, ma-otel-genai-spans, proto-a2a-dart-sdk, genui-overview, bloc-packages-versions, perf-audio-packages, proto-mcp-dart-sdks]
---
# Versions relevées le 2026-10-26 (API pub.dev et releases GitHub)

**Flutter / Dart (pub.dev) :**

| Package | Version | Publiée | Note |
|---|---|---|---|
| `genui` | 0.10.4 | 2026-09-29 | dépend de `a2ui_core ^0.1.0` (donc pas de 0.3.0) |
| `a2ui_core` | 0.3.0 | 2026-10-19 | cœur du protocole A2UI en Dart |
| `genui_a2ui` | 0.7.0 | 2026-02-07 | **discontinued**, remplacé par `genui_a2a` 0.10.1 (`genui ^0.10.0`) |
| `genui_firebase_ai` / `genui_google_generative_ai` | 0.7.1 | 2026-05-04 | **discontinued**, dépendent de `genui ^0.7.0` : incompatibles avec 0.10 |
| `firebase_ai` | 5.1.0 | 2026-10-23 | Gemini Live via Firebase AI Logic |
| `flutter_webrtc` | 1.6.3 | 2026-10-26 | |
| `openai_dart` | 11.0.1 | 2026-10-11 | non officiel ; support GPT-Live non vérifié |
| `googleai_dart` | 13.0.0 | 2026-09-16 | non officiel |
| `a2a` | 4.3.1 | 2026-08-07 | |
| `mcp_dart` | 2.4.3 | 2026-10-14 | |
| `dart_mcp` | 0.5.2 | 2026-06-29 | |
| `flutter_bloc` / `bloc` | 9.1.1 / 9.2.1 | 2025-05-02 / 2026-05-12 | |
| `rxdart` | 0.28.0 | 2024-06-14 | |
| `opentelemetry` | 0.18.11+1 | 2026-10-14 | **déprécié**, ré-exporte `opentelemetry_wk` (0.18.11) |

**Backend / SDK agents (GitHub releases) :**
- `openai-agents-python` : v0.24.0 ;
- `@openai/agents` / `@openai/agents-realtime` (JS) : 0.21.0 (2026-10-20) ;
- `google/adk-python` : v2.13.0 ;
- spécification A2A : v1.0.1 (2026-05-28) ;
- `a2ui` (Python) : `a2ui-agent-sdk` v0.9.0, `a2ui-adk` v0.1.0.

⚠️ Info datée : revérifier avant tout ajout dans un `pubspec.yaml`. Les packages `genui_*` en 0.7.x sont marqués *discontinued* sur pub.dev et leur contrainte `genui ^0.7.0` exclut `genui` 0.10.x.
