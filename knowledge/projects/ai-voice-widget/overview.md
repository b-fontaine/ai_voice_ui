---
id: proj-avw-overview
title: ai_voice_widget — vue d'ensemble
tags: [project, flutter, realtime-voice, genui]
status: verified
updated: 2026-10-26
sources: ["~/septeo/ai_voice_widget (analyse locale du code, 2026-10-26)"]
links: [proj-avw-voice-runners, proj-avw-genui-bridge, proj-avw-risks, di-setup-versions, di-named-implementations, bloc-sealed-freezed, perf-web-multi-view, arch-clean-flutter-layers, test-bloc-test]
---
# ai_voice_widget

Widget Flutter voix-à-voix temps réel, publié sur pub.dev et embarqué sur le web : build Flutter web en mode multi-view, servi par jsDelivr et enveloppé en libs npm React/Vue.

- **Workspace pub :** `package/` (le cœur) et `web/_flutter/` (l'hôte multi-view). SDK `^3.9.2`.
- **Couches :** clean archi dans `package/lib/src/{data,domain,presentation}`. Pas de FSD.
- **Chaîne d'appel :** `AiVoiceWidget` → `AiVoiceWidgetBloc` → `AiVoiceWidgetInteractor` (relais, point de mock) → `VoiceAi` (orchestrateur du domaine) → `IAiRunner`.
- **DI :** get_it + injectable, `@Named('gemini'|'openai')`, `@LazySingleton(as: IAiRunner)`, `@disposeMethod`.
- **État :** BLoC, events/states `@freezed` en union scellée. États : idle, recording, processing, speaking, error.
- **Dépendances clés :** `flutter_bloc ^9.1.1`, `flutter_webrtc ^1.3.1`, `firebase_ai ^3.9.0`, `genui ^0.7.0`, `genui_firebase_ai`, `genui_a2ui`, `flutter_soloud`, `record`, `bdd_widget_test ^2.1.3`, `mocktail`.
- **Pont web :** `MultiViewApp`. Chaque vue lit `ui_web.views.getInitialData(viewId)` avec les clés `apiKey`, `prompt`, `aiModel`.
- **Docs internes :** `agent-os/standards/flutter/` (bloc-freezed, domain-orchestrator, injectable-di, interactor-layer). `.prompt_history/openai_realtime_*` contient des retours d'expérience WebRTC.
- **Tests :** faibles. Un test du runner OpenAI (mocktail), le BDD est configuré mais vide, aucun test de BLoC, aucune CI.
